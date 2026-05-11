---
title: Provider configuration
description: Production defaults for the AWS Terraform / OpenTofu provider: version pinning, default_tags, assume_role, retries, multi-region aliases, and OIDC for GitHub Actions.
tags:
  - terraform
  - aws
---

# Provider configuration

Sensible, production-grade defaults for the [AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest).
Drop these into your root module to get consistent tagging, friendly retries,
and federated credentials for CI/CD.

!!! note "Root module owns the provider"
    Reusable child modules declare provider *requirements* in `versions.tf`
    but never instantiate `provider "aws" { ... }`. Provider configuration
    lives in the root module so the same module can be reused across
    accounts, regions, and partitions.

---

## `required_providers` pinning

Pin the AWS provider to a major version with the pessimistic constraint so
new minors flow in but breaking changes don't:

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 6.0"
    }
  }
}
```

!!! tip "Commit the lockfile"
    `terraform init` writes `.terraform.lock.hcl` with checksums for every
    provider. Always commit it, it's the only thing keeping you from a
    silent supply-chain change.

---

## `default_tags`

Tags applied here are merged onto every taggable resource managed by this
provider instance. Stop sprinkling `tags = { ... }` across hundreds of
resources.

```hcl
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      CostCenter  = var.cost_center
      Repository  = "github.com/acme-co/platform"
    }
  }
}
```

!!! warning "Tag drift on `aws_autoscaling_group`"
    A handful of resources (notably `aws_autoscaling_group` and
    `aws_eks_node_group`) propagate tags through a different mechanism and
    can show up as drift on plan. Use `lifecycle { ignore_changes = [tag] }`
    or set the tags explicitly on those resources.

---

## `assume_role` with `external_id`

Run plans as a deploy role instead of a long-lived user. The `external_id`
is required when the trust policy on the target role enforces it (recommended
for any cross-account scenario).

```hcl
provider "aws" {
  region = "us-east-1"

  assume_role {
    role_arn     = "arn:aws:iam::111122223333:role/terraform-deploy"
    session_name = "terraform-${var.environment}"
    external_id  = var.external_id

    # Optional: cap the maximum permissions of the session, even if the
    # underlying role has more. Useful for plan-only sessions.
    # policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
  }
}
```

---

## Retry configuration

The default retry behaviour is conservative. For long applies that touch
hundreds of resources, the **adaptive** retry mode backs off intelligently
when AWS starts throttling.

```hcl
provider "aws" {
  region = "us-east-1"

  max_retries = 10
  retry_mode  = "adaptive" # one of: "standard" | "adaptive" | "legacy"
}
```

!!! tip "Pair with `-parallelism`"
    Adaptive retries help, but if you're hitting throttling regularly,
    consider lowering `terraform apply -parallelism=10` (default 10, but
    sometimes worth dropping further on heavy IAM/EC2 modules).

---

## Multi-region with provider aliases

Some resources are global (CloudFront, ACM certs for CloudFront, IAM) and
must be created in `us-east-1`. Define an aliased provider and pass it
explicitly to those modules.

```hcl
provider "aws" {
  region = var.region # e.g. eu-west-1
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ACM cert for a CloudFront distribution must live in us-east-1.
module "cdn_cert" {
  source  = "./modules/acm-cert"
  domain  = "www.example.com"

  providers = {
    aws = aws.us_east_1
  }
}
```

A child module that needs more than one provider declares the aliases it
expects in its own `versions.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.60, < 6.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
```

---

## OIDC + GitHub Actions (`assume_role_with_web_identity`)

Inside a GitHub Actions runner, exchange the workflow's OIDC token for AWS
credentials: no static keys, no `aws-actions/configure-aws-credentials`
env-var dance required by Terraform itself.

```hcl
provider "aws" {
  region = "us-east-1"

  assume_role_with_web_identity {
    role_arn                = "arn:aws:iam::111122223333:role/github-actions-deploy"
    session_name            = "gha-${var.github_run_id}"
    web_identity_token_file = "/var/run/secrets/github/token"
  }
}
```

In practice you'll keep using `aws-actions/configure-aws-credentials` to
fetch the token and write it to the env, then Terraform will pick it up
automatically because it reads the standard
`AWS_ROLE_ARN` / `AWS_WEB_IDENTITY_TOKEN_FILE` variables. The explicit block
above is useful when you need to assume *a different* role than the one the
action configured (for example, a per-env role).

A typical workflow step:

```yaml
# .github/workflows/deploy.yml
permissions:
  id-token: write     # required for OIDC
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::111122223333:role/github-actions-deploy
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.10.0

      - run: terraform init
      - run: terraform apply -auto-approve
```

See the matching trust policy in [IAM policy patterns → GitHub Actions OIDC](iam-policies.md#github-actions-oidc-trust).

---

## Putting it all together

A complete root-module provider block for a CI-driven, multi-region
deployment:

```hcl
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 6.0"
    }
  }
}

provider "aws" {
  region      = var.region
  max_retries = 10
  retry_mode  = "adaptive"

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-${var.environment}"
    external_id  = var.external_id
  }

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/acme-co/platform"
    }
  }
}

provider "aws" {
  alias       = "us_east_1"
  region      = "us-east-1"
  max_retries = 10
  retry_mode  = "adaptive"

  assume_role {
    role_arn     = var.deploy_role_arn
    session_name = "terraform-${var.environment}-use1"
    external_id  = var.external_id
  }

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "github.com/acme-co/platform"
    }
  }
}
```

---

## References

- [AWS provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS provider: `default_tags`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags-configuration-block)
- [AWS provider: `assume_role`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#assume_role-configuration-block)
- [AWS provider: `assume_role_with_web_identity`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#assume_role_with_web_identity-configuration-block)
- [AWS SDK retry behaviour (adaptive vs standard)](https://docs.aws.amazon.com/sdkref/latest/guide/feature-retry-behavior.html)
- [Terraform: Provider configuration](https://developer.hashicorp.com/terraform/language/providers/configuration)
- [Terraform: Multiple provider configurations (aliases)](https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations)
- [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)
