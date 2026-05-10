---
title: Module skeleton
description: Opinionated layout for a reusable AWS Terraform / OpenTofu module — file structure, version pinning, default_tags, terraform-docs, native tftest, and pre-commit-terraform.
tags:
  - terraform
  - aws
---

# Module skeleton

A predictable layout for a reusable AWS module. Drop these files into a new
repo and you have a module that lints, formats, generates docs, and self-tests
out of the box.

!!! tip "One module, one job"
    A module is a unit of *reuse*, not a unit of *deployment*. Keep modules
    focused (one VPC, one bucket-with-policy, one ALB), and let the consuming
    root configuration glue them together.

---

## Directory layout

```text
terraform-aws-<name>/
├── README.md              # Generated header + manual content + terraform-docs block
├── main.tf                # Resources
├── variables.tf           # Inputs (with descriptions, types, validation)
├── outputs.tf             # Outputs (with descriptions)
├── locals.tf              # Computed values, naming, tag merging
├── versions.tf            # required_version + required_providers
├── examples/
│   └── basic/
│       ├── main.tf        # Smallest working invocation
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
├── tests/
│   └── basic.tftest.hcl   # Native `terraform test` cases
├── .terraform-docs.yml    # terraform-docs config
├── .tflint.hcl            # tflint ruleset
└── .pre-commit-config.yaml
```

---

## `versions.tf`

Always pin the Terraform CLI floor and every provider you use. Use the
pessimistic constraint (`~>`) so consumers stay on a known-good major.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.60, < 6.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
```

!!! note "Modules don't configure providers"
    A reusable module declares the providers it *requires* but does not
    instantiate them. The root module owns `provider "aws" { ... }` so the
    same module can be used in any region or account.

---

## `default_tags` and the tag-merge pattern

Let consumers set baseline tags on the provider, then merge module-specific
tags in `locals.tf` so they show up on every resource.

```hcl
# In the consuming root module:
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

```hcl
# locals.tf (inside the module)
locals {
  name = "${var.project}-${var.environment}-${var.name}"

  tags = merge(
    var.tags,
    {
      Name      = local.name
      Module    = "terraform-aws-${var.name}"
    },
  )
}
```

`default_tags` from the provider apply to every taggable resource
automatically, so the module only needs to set tags it specifically owns
(like `Name`).

---

## `examples/basic/main.tf`

Every example is a real root module not a snippet. CI should
`terraform init && terraform validate` every example on every PR.

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

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Owner       = "example"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

module "bucket" {
  source = "../.."

  project     = "demo"
  environment = "dev"
  name        = "logs"
}

output "bucket_arn" {
  value = module.bucket.bucket_arn
}
```

---

## Native testing with `tftest.hcl`

Terraform 1.6 introduced a built-in test runner. Each `run` block is a plan
or apply against the module under test, with `assert` blocks that fail the
build if the contract drifts.

```hcl
# tests/basic.tftest.hcl

variables {
  project     = "demo"
  environment = "dev"
  name        = "logs"
}

run "plan_defaults" {
  command = plan

  assert {
    condition     = output.bucket_name == "demo-dev-logs"
    error_message = "Bucket name should follow <project>-<environment>-<name>."
  }
}

run "apply_basic" {
  command = apply

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = can(regex("^arn:aws:s3:::", run.apply_basic.bucket_arn))
    error_message = "bucket_arn should be a real S3 ARN after apply."
  }
}
```

Run locally:

```bash
terraform init
terraform test
```

!!! tip "Mock the provider for fast tests"
    Use `mock_provider "aws" {}` blocks in your `.tftest.hcl` to run pure
    plan-time assertions without ever touching AWS. Reserve real `apply` runs
    for an integration job that has credentials.

---

## `README.md` with terraform-docs markers

Generate the inputs / outputs / providers tables automatically so they never
go stale.

````markdown
# terraform-aws-logs

A bucket-with-policy module for application access logs.

## Usage

```hcl
module "logs" {
  source = "git::https://github.com/acme-co/terraform-aws-logs.git?ref=v1.0.0"

  project     = "acme"
  environment = "prod"
  name        = "app-logs"
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
````

`.terraform-docs.yml`:

```yaml
formatter: markdown table

sections:
  show:
    - requirements
    - providers
    - inputs
    - outputs

output:
  file: README.md
  mode: inject
  template: |-
    <!-- BEGIN_TF_DOCS -->
    {{ .Content }}
    <!-- END_TF_DOCS -->

sort:
  enabled: true
  by: required
```

Then `terraform-docs .` rewrites the markers in place.

---

## `pre-commit-terraform`

Add the [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
hooks so every commit gets formatted, validated, linted, and re-documented:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
```

Install once per checkout:

```bash
pre-commit install
pre-commit run --all-files
```

| Hook                 | What it does                                                         |
| -------------------- | -------------------------------------------------------------------- |
| `terraform_fmt`      | `terraform fmt -recursive` canonical whitespace and key alignment.   |
| `terraform_validate` | `terraform validate` against every module and example.               |
| `terraform_tflint`   | Provider-aware linter; catches deprecated arguments and bad AMI IDs. |
| `terraform_docs`     | Regenerates the inputs / outputs table inside the README markers.    |

---

## References

- [Terraform: Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Terraform: Tests (`terraform test`)](https://developer.hashicorp.com/terraform/language/tests)
- [AWS provider: `default_tags`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#default_tags)
- [terraform-docs](https://terraform-docs.io/)
- [tflint AWS ruleset](https://github.com/terraform-linters/tflint-ruleset-aws)
- [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
