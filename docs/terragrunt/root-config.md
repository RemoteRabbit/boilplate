---
title: root.hcl + env.hcl + unit pattern
status: stub
---

# root.hcl + env.hcl + unit pattern

!!! note "Stub page"
    Current-best-practice 3-file layout: shared root, per-env locals, per-unit overrides.

## Planned content

- `root.hcl` with remote_state, generate provider, common locals
- `env.hcl` per environment (dev/stg/prod) with vars consumed via `read_terragrunt_config`
- Unit `terragrunt.hcl` with `include "root"`, `terraform { source }`, and `inputs`
- Working directory tree example
