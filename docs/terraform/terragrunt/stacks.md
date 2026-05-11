---
title: Explicit stacks (terragrunt.stack.hcl)
description: Define a recurring infra pattern once, instantiate it per environment with terragrunt.stack.hcl.
tags:
  - terragrunt
  - terraform
---

# Explicit stacks (terragrunt.stack.hcl)

The **stacks** feature (Terragrunt 0.66+, stable in the 1.0 line) lets you
declare a bundle of related units: e.g. *vpc + eks + rds + sqs*: in a single
`terragrunt.stack.hcl` file and instantiate it anywhere you want. It replaces
the traditional pattern of copy-pasting 5–10 unit folders per new environment
or tenant.

## When to use stacks

Use a stack when you have a **recurring shape** of infrastructure:

- "Every customer gets a vpc, an EKS cluster, an RDS, and a Redis."
- "Every region we expand into gets the same 6-unit foothold."
- "Each preview environment is the same app + db + queue."

Stick with raw units (the [3-file pattern](root-config.md)) when each
environment is genuinely bespoke or you only have one or two of them.

## Syntax: `terragrunt.stack.hcl`

```hcl
# live/dev/us-east-1/terragrunt.stack.hcl

unit "vpc" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//units/vpc?ref=v0.7.0"
  path   = "vpc"

  values = {
    cidr_block = "10.20.0.0/16"
    azs        = ["us-east-1a", "us-east-1b", "us-east-1c"]
  }
}

unit "eks" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//units/eks?ref=v0.7.0"
  path   = "eks"

  values = {
    cluster_name    = "core"
    cluster_version = "1.30"
  }
}

# A nested stack: a stack that pulls in its own units/stacks.
stack "service" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//stacks/service?ref=v0.7.0"
  path   = "svc-checkout"

  values = {
    name        = "checkout"
    image       = "ghcr.io/acme/checkout:1.4.2"
    db_instance = "db.t4g.medium"
  }
}
```

- **`unit`** generates one Terragrunt unit (one state file).
- **`stack`** recursively expands another `terragrunt.stack.hcl`, useful for
  composing larger patterns from smaller ones.
- **`source`** is anything Terragrunt can fetch (git, https, local path).
- **`path`** is the directory under `.terragrunt-stack/` (or in-place; see
  below) where the unit/stack will be materialised.
- **`values`** is an arbitrary HCL object passed to the unit at generation
  time.

## Consuming `values` in a unit

The unit pulled in by `source` is a normal `terragrunt.hcl` that reads
`values.x` to populate `inputs`:

```hcl
# infrastructure-catalog/units/vpc/terragrunt.hcl

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "git::git@github.com:acme/tf-modules.git//vpc?ref=v1.4.0"
}

inputs = {
  name       = "core"
  cidr_block = values.cidr_block
  azs        = values.azs
}
```

`values` is a top-level identifier inside a unit reached via a stack: that's
how `terragrunt.stack.hcl` plumbs configuration in without each unit needing
its own per-environment HCL file.

## The catalog-repo pattern

The proven layout is two repos:

```text
infrastructure-catalog/        # versioned, tagged
  units/
    vpc/terragrunt.hcl
    eks/terragrunt.hcl
    rds/terragrunt.hcl
  stacks/
    service/terragrunt.stack.hcl

infrastructure-live/           # the deployable repo
  live/
    root.hcl
    dev/
      env.hcl
      us-east-1/
        terragrunt.stack.hcl   # references catalog at ref=v0.7.0
    prod/
      env.hcl
      us-east-1/
        terragrunt.stack.hcl   # references catalog at ref=v0.6.3
```

The live repo only contains `root.hcl`, `env.hcl`, and one
`terragrunt.stack.hcl` per environment. Promotion from dev to prod is a single
ref bump.

!!! tip "Pin the catalog ref"
    Always pin `source = "...?ref=v0.7.0"`. Tracking `main` re-fetches on every
    `generate` and silently changes generated units across runs.

## Generating and running

```bash
# Materialise units defined by every terragrunt.stack.hcl in the tree.
terragrunt stack generate

# Generate, then plan/apply across the whole stack.
terragrunt stack run plan
terragrunt stack run apply
```

`terragrunt stack generate` walks each `terragrunt.stack.hcl` and writes the
resolved units into a sibling **`.terragrunt-stack/`** directory:

```text
live/dev/us-east-1/
  terragrunt.stack.hcl
  .terragrunt-stack/
    vpc/
      terragrunt.hcl
    eks/
      terragrunt.hcl
    svc-checkout/
      ...
```

The `.terragrunt-stack/` directory is **generated**; add it to `.gitignore` and
treat it the way you'd treat `.terraform/`. State for each generated unit lives
in your S3 backend exactly as if you'd authored the units by hand.

`terragrunt stack run <cmd>` is equivalent to `cd .terragrunt-stack && terragrunt run --all <cmd>`,
respecting `dependency` blocks across the generated units.

## In-place migration: `no_dot_terragrunt_stack`

If you're converting an existing tree of hand-written units into a stack
without breaking everyone's `cd live/dev/us-east-1/vpc` muscle memory, set:

```hcl
# terragrunt.stack.hcl
no_dot_terragrunt_stack = true

unit "vpc" {
  source = "..."
  path   = "vpc"   # written directly under live/dev/us-east-1/vpc/
  values = { ... }
}
```

With `no_dot_terragrunt_stack = true`, generated units land at `path` directly
(no `.terragrunt-stack/` prefix). This is the recommended path for converting
an existing 3-file repo to stacks one environment at a time.

!!! warning "Don't hand-edit generated files"
    Anything under `.terragrunt-stack/` (or under the in-place `path` when
    `no_dot_terragrunt_stack = true`) is overwritten on the next
    `terragrunt stack generate`. Make changes in the catalog repo or in
    `terragrunt.stack.hcl`'s `values`, never in the generated `terragrunt.hcl`.

## References

- [Stacks overview](https://terragrunt.gruntwork.io/docs/features/stacks/)
- [`terragrunt.stack.hcl` reference](https://docs.terragrunt.com/reference/config-blocks-and-attributes/#stack)
- [`terragrunt stack` CLI](https://terragrunt.gruntwork.io/docs/reference/cli/commands/stack/run/)
- [Infrastructure catalog pattern](https://terragrunt.gruntwork.io/docs/features/catalog/)
