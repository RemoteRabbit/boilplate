---
title: Terragrunt
description: Modern Terragrunt patterns aligned with the 0.66+/1.0 release line.
tags:
  - terragrunt
  - terraform
---

# Terragrunt

[Terragrunt](https://terragrunt.gruntwork.io/) is a thin orchestration layer that
sits on top of Terraform / OpenTofu. It does not replace HCL modules — you still
write modules the same way — it just removes the copy-paste involved in wiring
the same module into many environments.

## What it adds on top of Terraform / OpenTofu

- **DRY remote state** — one `remote_state` block at the root generates the
  `backend "s3" {}` for every unit, with the state key derived from the unit's
  path on disk.
- **DRY provider blocks** — one `generate "provider"` block writes a
  `provider.tf` into every working directory, so units don't repeat
  `provider "aws" { region = ... }` boilerplate.
- **Dependency graph** — `dependency "vpc" { config_path = "../vpc" }` lets one
  unit consume another unit's outputs without manual `terraform_remote_state`
  data sources, and Terragrunt sequences applies in topological order.
- **`run --all`** (formerly `run-all`) — plan/apply/destroy across every unit
  under a directory, respecting the dependency graph.
- **OpenTofu support** — set `terraform_binary = "tofu"` in `terraform_binary`
  or via the `TG_TF_PATH` env var to drive `tofu` instead of `terraform`.

## When to use it

Reach for Terragrunt when you have:

- More than one environment (dev / staging / prod) of the same stack.
- Many small units (vpc, eks, rds, …) that share state-bucket layout, providers,
  and tagging.
- A platform team that wants `cd live/prod && terragrunt run --all plan` to be
  the daily driver.

Skip it for a single-environment, single-state-file project — a plain
`terraform` root with a backend block is simpler.

!!! tip "OpenTofu users"
    Everything on the child pages works with OpenTofu. Set
    `terraform_binary = "tofu"` in your `root.hcl` `terraform` block, or export
    `TG_TF_PATH=tofu`.

## Migration from legacy patterns

If you're coming from older Terragrunt:

- The root config file is now conventionally **`root.hcl`**, not a root-level
  `terragrunt.hcl`. Units reference it with
  `find_in_parent_folders("root.hcl")`. The legacy implicit lookup of a parent
  `terragrunt.hcl` is deprecated and emits a warning.
- The old **`_envcommon/`** directory pattern (one HCL file per module shared
  across envs) is replaced by explicit `include "env" { path = ... }` blocks
  reading an `env.hcl` via `read_terragrunt_config`.
- `run-all` is now `run --all`. `terragrunt-include-dir` flags are now
  `--queue-include-dir`.

## Pages

<div class="grid cards" markdown>

- :material-file-tree:{ .lg .middle } **[root.hcl + env.hcl + unit pattern](root-config.md)**

    ---

    The modern 3-file layout: shared root config, per-environment locals, and
    thin per-unit `terragrunt.hcl` files.

- :material-layers-triple:{ .lg .middle } **[Explicit stacks](stacks.md)**

    ---

    Define an app-shaped bundle (vpc + eks + rds + queue) once in a
    `terragrunt.stack.hcl`, instantiate it per environment.

</div>

## References

- [Terragrunt docs home](https://docs.terragrunt.com/getting-started/quick-start/)
- [Migrating to `root.hcl`](https://terragrunt.gruntwork.io/docs/migrate/migrating-from-root-terragrunt-hcl/)
- [CLI reference](https://terragrunt.gruntwork.io/docs/reference/cli-options/)
