---
title: Style Guide
description: Conventions for Terraform / OpenTofu modules ~ variables, validation messages, modules, file layout, tagging, and more.
tags:
  - terraform
---

# Style Guide

Conventions we follow across every Terraform / OpenTofu module in this repo. Apply these to all new code and bring
existing code in line as you touch it.

## Variables

```hcl
variable "project_id" { # (1)!
  description = "Project ID (e.g. acme-platform-prod). 6–30 chars, lowercase letter start." # (2)!
  type        = string # (3)!

  validation { # (4)!
    condition = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id)) # (5)!
    error_message = <<-EOT
      Variable `project_id` must start with a lowercase letter, be 6–30 chars, and contain only lowercase
      letters, digits, or hyphens (no trailing hyphen).
    EOT
    # (6)!
  }
}
```

1. Variable names should be short but as descriptive of their purpose as possible. They should also always be
lowercase with only letters and underscores.
2. All variables should have a description with detail of what it is and its purpose. If required use `<<-EOT` to allow
for multiline detailed descriptions.
3. Be explicit when it comes to variable types. If it is a map or object be diligent with marking that in the type along
with its internal types.
4. All variables should have at least one level of validation. Even if it is a simple variable that is always set in a
vars file. Typos and mistakes happen. Validation catches that ahead of time.
5. Create a condition that is as strict to the type and desired state of the variable without it becoming its own
project to manage. Strict enough to catch real mistakes, loose enough not to require updating every time the
upstream naming rules shift.
6. See [Validation messages](#validation-messages) below.

## Validation messages

Treat validation `error_message` strings like user-facing copy and like variable `description` fields:

- **Start with a capital letter.** Begin with a real word (e.g. `Variable`, `Value`, `Argument`) rather than a
  lowercase identifier or backticked token.
- **End with a period.** Write complete sentences, not fragments.
- **Name the offending variable.** Reference it explicitly (`` Variable `project_id` `` …) so the failure is obvious
  in plan/apply output.
- **State the rule, not the regex.** Describe the constraint in plain English (length, allowed characters, allowed
  values) instead of pasting the pattern.
- **Suggest a fix when possible.** If the valid set is small, list it (e.g. `Must be one of: dev, stg, prd.`).

This matches the [HashiCorp style guide](https://developer.hashicorp.com/terraform/language/style#error-messages)
and is enforced by [`tflint`](https://github.com/terraform-linters/tflint)'s `terraform_documented_variables` and
related rules.

### Multi-line messages

Keep every line at or under **120 characters**. When a message would otherwise overflow, switch to an indented
heredoc (`<<-EOT`); the same form you use for long `description` fields:

```hcl
variable "project_id" {
  description = <<-EOT
    Project ID (e.g. acme-platform-prod). 6–30 chars, lowercase letter start.
    EOT
  type        = string

  validation {
    condition = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = <<-EOT
      Variable `project_id` is invalid. It must:
        - start with a lowercase letter,
        - be 6–30 characters long,
        - contain only lowercase letters, digits, or hyphens, and
        - not end with a hyphen.
    EOT
  }
}
```

Two gotchas to be aware of:

- Terraform still enforces the "full sentence" rule on the **rendered** string and so it must start with an uppercase
  letter and end with `.` or `?` (see [hashicorp/terraform#24214](https://github.com/hashicorp/terraform/issues/24214)).
- `terraform fmt` has a long-standing bug ([hashicorp/terraform#34877](https://github.com/hashicorp/terraform/issues/34877))
  where indented heredocs that contain multi-line `${ ... }` interpolations get reformatted incorrectly. Keep any
  interpolation on a single line inside the heredoc to avoid it.

## Outputs

Every output should have a `description`, mark `sensitive = true` when the value contains credentials or other
secrets, and expose attributes rather than entire resource objects so consumers don't depend on provider-internal
fields.

<!-- TODO: Add in an example and also bring up in newer versions you can add type and pre-conditions  -->

## Locals

Use `locals` for values that are derived, repeated, or computed from variables and data sources. Reach for a
variable when callers need to override the value; reach for a local when the module owns it. Keep names short and
descriptive (`common_tags`, `name_prefix`).

## Resources

- Use `this` as the resource name when a module manages a single instance of that resource type. Otherwise pick a
  short descriptive name (`primary`, `replica`, `web`).
- Prefer `for_each` over `count` so resource addresses stay stable when the input set changes.
- Add `lifecycle` blocks (`prevent_destroy`, `ignore_changes`, `create_before_destroy`) deliberately, with a comment
  explaining why.

## Modules

- **Pin every `source`.** Use a registry version constraint (`version = "~> 5.2"`) or a git ref pinned to a tag or
  commit SHA. Never reference `main` / `master` / `latest`.
- **DRY the pin with a variable or local.** Newer Terraform / OpenTofu allow static references in `module.source`
  and `module.version`, so when the same module is called many times it's good practice to centralize the ref:

    ```hcl
    locals {
      # Bump this once to roll every caller forward.
      vpc_module_ref = "git::https://github.com/acme/terraform-aws-vpc.git?ref=v1.4.2"
      modules = {
        "s3" = "~> 3.2"
      }
    }

    module "vpc_primary" {
      source = local.vpc_module_ref
      # ...
    }

    module "s3_assets" {
      source  = "example.registry.com/aws/s3"
      version = local.modules.s3
      # ...
    }
    ```

- One logical concern per module. If a module's variables describe two unrelated systems, split it.
- Every module ships with a `README.md` (generated by [`terraform-docs`](https://terraform-docs.io/)), an `examples/`
  directory, and a `versions.tf`.

## File layout

A module's root directory should follow a predictable layout so contributors know where to look:

- `main.tf`: primary resources
- `variables.tf`: inputs
- `outputs.tf`: outputs
- `versions.tf`: `terraform { required_version, required_providers }`
- `locals.tf`: derived values (when non-trivial)
- `data.tf`: data sources (when non-trivial)
- `providers.tf`: provider configuration (root modules only)

When `main.tf` grows beyond a few hundred lines, split by resource group (e.g. `network.tf`, `iam.tf`) rather than
by resource type.

## Provider & version pinning

Every module declares a `versions.tf` that pins the Terraform / OpenTofu version and every provider with `~>` so
patch and minor updates flow in but breaking changes don't:

```hcl
terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}
```

## Tags and labels

A common tag set is required on every taggable resource. Define it once in a local and merge it in:

```hcl
locals {
  common_tags = {
    environment = var.environment
    owner       = var.owner
    cost_center = var.cost_center
    managed_by  = "terraform"
  }
}
```

Per-resource tags merge on top: `tags = merge(local.common_tags, { Name = "..." })`.

If the provider allows for it utilize their default tags in the provider block to apply good defaults across the board
automatically.

## Naming convention

Resource names rendered into the cloud provider follow `${project}-${environment}-${component}` (e.g.
`acme-prd-vpc`). Respect provider-specific length and character limits; encode them as `validation` blocks on the
input variables that feed into the name.

## Comments

- Use `#` for all comments (HCL convention).
  - Terraform does allow a couple older comment block strategies for backwards compatibility but steer away from
    those as the preferred standard is `#` per-line.
- Document the *why*, not the *what*. The code already says what it does.
- Doc comments belong above the block they describe.
- Never commit commented-out code; delete it and rely on git history.
  - Exceptions can be made for known *temporary* blocks or examples but should be used sparingly.

## Sensitive data

- Never commit secrets, even encrypted, to the repo.
- Mark sensitive variables and outputs with `sensitive = true`.
- Pull secrets from the cloud's secret manager via a data source at apply time; don't pass them in as plain `tfvars`.

## `count` vs `for_each`

Default to `for_each` over a map or set. Resource addresses stay stable when the input changes. Reserve `count`
for the on/off toggle pattern (`count = var.enabled ? 1 : 0`).

## Dynamic blocks

Use `dynamic` blocks sparingly. They obscure the resource shape; prefer explicit, repeated blocks unless the
contents are truly variable in number. When you do use one, keep the iterator name short and the body small. One should
first see if a block using `for_each` can do the task first.

## State and backends

- Remote backend is required for every root module: no local state checked in.
- State locking must be enabled (S3 native locking, blob lease for AzureRM, GCS native locking).
- Never run `terraform state` mutation commands from CI; do them locally with explicit review.

## Testing

- Use `terraform test` for module contract tests (input → expected plan / output).
- Run `terraform plan` on every PR and post the output as a check.
- For modules with side effects worth verifying end-to-end, add a [Terratest](https://terratest.gruntwork.io/) suite
  under `test/`.

## Formatting and linting

Run these against every change, both locally and in CI:

- `terraform fmt -recursive`: formatting (non-negotiable).
- `terraform validate`: syntax and type checks.
- [`tflint`](https://github.com/terraform-linters/tflint) with the relevant cloud ruleset.
- [`trivy config`](https://aquasecurity.github.io/trivy/) or [`checkov`](https://www.checkov.io/): security scanning.
- [`terraform-docs`](https://terraform-docs.io/): keep module READMEs in sync.
  - There is a known bug with `terraform-docs` if you are using local or variable for module source and or versions.

## Pre-commit hooks

Wire the above into [`pre-commit`](https://pre-commit.com/) so they run on every commit:

- `terraform_fmt`
- `terraform_validate`
- `terraform_tflint`
- `terraform_trivy` (or `terraform_checkov`)
- `terraform_docs`
