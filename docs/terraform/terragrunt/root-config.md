---
title: root.hcl + env.hcl + unit pattern
description: The modern 3-file Terragrunt layout — shared root, per-environment locals, thin per-unit configs.
tags:
  - terragrunt
  - terraform
---

# root.hcl + env.hcl + unit pattern

The current Gruntwork-recommended layout splits configuration into three files
that compose by location on disk:

1. **`root.hcl`** — one per repo, at the top of `live/`. Holds the remote-state
   backend, generated provider, and locals shared by every unit.
2. **`env.hcl`** — one per environment directory. Holds variables that differ
   per env (region, account ID, environment name).
3. **Unit `terragrunt.hcl`** — one per deployable unit. Includes `root` (and
   optionally `env`), points at a module `source`, and supplies `inputs`.

## Directory layout

```text
live/
  root.hcl
  dev/
    env.hcl
    us-east-1/
      vpc/
        terragrunt.hcl
      eks/
        terragrunt.hcl
  prod/
    env.hcl
    us-east-1/
      vpc/
        terragrunt.hcl
      eks/
        terragrunt.hcl
```

## 1. `root.hcl`

```hcl
# live/root.hcl
locals {
  # Pull the env.hcl that lives somewhere above the current unit.
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.env_vars.locals.account_id
  aws_region  = local.env_vars.locals.aws_region
  environment = local.env_vars.locals.environment

  default_tags = {
    Environment = local.environment
    ManagedBy   = "terragrunt"
    Repo        = "infra-live"
  }
}

# One S3 backend definition for every unit. The state key is derived from
# each unit's path under live/, so vpc/ and eks/ get separate state files
# automatically.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "acme-tfstate-${local.account_id}"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking, no DynamoDB table required
  }
}

# A provider.tf written into every working directory.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region              = "${local.aws_region}"
  allowed_account_ids = ["${local.account_id}"]

  default_tags {
    tags = ${jsonencode(local.default_tags)}
  }
}
EOF
}

terraform {
  # Drive OpenTofu instead of Terraform; remove this line for HashiCorp TF.
  # Equivalent to setting TG_TF_PATH=tofu in the environment.
}

# These inputs are merged into every unit's inputs.
inputs = {
  aws_region  = local.aws_region
  account_id  = local.account_id
  environment = local.environment
  tags        = local.default_tags
}
```

!!! note "S3 native locking"
    `use_lockfile = true` enables S3's conditional-write based locking
    (Terraform 1.10+ / OpenTofu 1.10+). You no longer need a DynamoDB table.
    Drop `dynamodb_table = ...` when you migrate.

## 2. `env.hcl`

```hcl
# live/dev/env.hcl
locals {
  environment = "dev"
  aws_region  = "us-east-1"
  account_id  = "111122223333"
}
```

```hcl
# live/prod/env.hcl
locals {
  environment = "prod"
  aws_region  = "us-east-1"
  account_id  = "999988887777"
}
```

Each env directory only differs in this one file. Anything env-specific that
several units need (alert email, Slack webhook ARN, VPC CIDR allocations) goes
here.

## 3. Unit `terragrunt.hcl`

```hcl
# live/dev/us-east-1/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "env" {
  path           = find_in_parent_folders("env.hcl")
  expose         = true
  merge_strategy = "no_merge"
}

terraform {
  source = "github.com/acme/tf-modules.git//vpc?ref=v1.4.0"
}

inputs = {
  name       = "core-${include.env.locals.environment}"
  cidr_block = "10.20.0.0/16"
  azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
```

```hcl
# live/dev/us-east-1/eks/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "vpc" {
  config_path = "../vpc"

  # Allow `terragrunt plan` before vpc has been applied.
  mock_outputs = {
    vpc_id             = "vpc-00000000"
    private_subnet_ids = ["subnet-aaa", "subnet-bbb", "subnet-ccc"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

terraform {
  source = "github.com/acme/tf-modules.git//eks?ref=v3.1.2"
}

inputs = {
  cluster_name    = "core"
  cluster_version = "1.30"
  vpc_id          = dependency.vpc.outputs.vpc_id
  subnet_ids      = dependency.vpc.outputs.private_subnet_ids
}
```

## Cross-unit dependencies

`dependency` blocks make one unit's outputs available to another. Terragrunt
sequences `run --all apply` so that `vpc` applies before `eks`. `mock_outputs`
lets `terragrunt plan` succeed for downstream units before upstream ones have
ever been applied — useful in CI on a fresh branch.

!!! tip "Scope the mocks"
    Always pair `mock_outputs` with `mock_outputs_allowed_terraform_commands`.
    Without it, `terragrunt apply` will happily apply against the mock values if
    the dependency hasn't been applied — which is almost never what you want.

!!! warning "Don't put `inputs` in `root.hcl` that depend on the unit"
    Locals like `path_relative_to_include()` are evaluated in the **including**
    unit's context, which is what you want. But anything in `root.hcl` `inputs`
    is merged into every unit, so keep it to genuinely global values
    (region, account, tags).

## References

- [Keep your Terragrunt config DRY](https://terragrunt.gruntwork.io/docs/features/keep-your-terragrunt-architecture-dry/)
- [`remote_state` block](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#remote_state)
- [`generate` block](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#generate)
- [`dependency` block](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#dependency)
- [Built-in functions (`find_in_parent_folders`, `read_terragrunt_config`, `path_relative_to_include`)](https://terragrunt.gruntwork.io/docs/reference/built-in-functions/)
