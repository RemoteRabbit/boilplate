---
title: Useful Commands
description: A collection of nice, helpful Terraform / OpenTofu commands for everyday work.
tags:
  - terraform
---

# Useful Commands

A grab-bag of Terraform / OpenTofu commands worth keeping handy. Most work identically with `tofu` swapped in for
`terraform`. Use the one your project standardises on.

## Init

Standard init.

```bash
terraform init
```

Re-pull modules and providers without touching backend config.

```bash
terraform init -upgrade
```

Re-configure the backend (e.g. switching workspaces / accounts).

```bash
terraform init -reconfigure
```

Migrate state to a newly-changed backend without prompting.

```bash
terraform init -migrate-state
```

## Plan

Plan to a file you can review and apply atomically.

```bash
terraform plan -out=tfplan
```

Target a single resource (use sparingly: it bypasses dependency tracking).

```bash
terraform plan -target=aws_s3_bucket.assets
```

Plan with a specific tfvars file (per-environment workflow).

```bash
terraform plan -var-file=envs/prod.tfvars
```

### Generate import commands from a plan

Useful when you need to adopt a pile of pre-existing real-world resources into a fresh state file in bulk. The
command below scans plan output for `will be created` lines and emits a `terraform import` template for each.
You still have to fill in `RESOURCE_ID` (the cloud-provider ID) for every line before running them:

```bash
terraform plan -no-color -var-file=<vars-file-name>.tfvars \
  | grep "will be created" \
  | sed "s/.*# \(.*\) will be created/terraform import -lock=false -var-file=<vars-file-name>.tfvars '\1' RESOURCE_ID/"
```

## Apply

Apply a saved plan: no surprises between plan and apply.

```bash
terraform apply tfplan
```

Auto-approve (CI only, never local).

```bash
terraform apply -auto-approve
```

Replace a resource that has drifted or is corrupt.

```bash
terraform apply -replace=aws_instance.web
```

## State inspection

List every resource Terraform manages.

```bash
terraform state list
```

Show the full attributes of one resource.

```bash
terraform state show aws_s3_bucket.assets
```

Pull the raw state JSON (great for grep / jq).

```bash
terraform state pull | jq '.resources[] | select(.type=="aws_iam_role")'
```

## State surgery

!!! warning "State mutation is destructive"
    Always back up state before running anything below. Never run these from CI.

Back up state first.

```bash
terraform state pull > backup.tfstate
```

Rename a resource address after a refactor (no destroy/create).

```bash
terraform state mv aws_s3_bucket.old aws_s3_bucket.new
```

Move a resource into a module.

```bash
terraform state mv aws_s3_bucket.assets module.assets.aws_s3_bucket.this
```

Forget a resource without destroying the real-world object.

```bash
terraform state rm aws_s3_bucket.assets
```

Adopt an existing real-world resource into state.

```bash
terraform import aws_s3_bucket.assets my-existing-bucket
```

## Refactoring with `moved` blocks

Prefer `moved {}` blocks in code over `terraform state mv` whenever possible: they're versioned, reviewable,
and run automatically for every collaborator.

```hcl
moved {
  from = aws_s3_bucket.old
  to   = aws_s3_bucket.new
}
```

## Drift detection

Detect drift without applying. Exit code 2 means changes are pending.

```bash
terraform plan -detailed-exitcode
```

Refresh state against real-world resources without planning changes.

```bash
terraform apply -refresh-only
```

## Outputs

Print all outputs.

```bash
terraform output
```

Get a single output as raw text (script-friendly).

```bash
terraform output -raw bucket_name
```

Get all outputs as JSON.

```bash
terraform output -json | jq
```

## Formatting & validation

Format every `.tf` file under cwd.

```bash
terraform fmt -recursive
```

Check formatting without changing files (use in CI).

```bash
terraform fmt -check -recursive
```

Validate syntax and types.

```bash
terraform validate
```

## Workspaces

List workspaces.

```bash
terraform workspace list
```

Create a new workspace.

```bash
terraform workspace new dev
```

Switch to a workspace.

```bash
terraform workspace select prod
```

Show the current workspace.

```bash
terraform workspace show
```

## Graph & dependency inspection

Render the dependency graph as Graphviz DOT.

```bash
terraform graph | dot -Tsvg > graph.svg
```

Show the providers a config / state requires.

```bash
terraform providers
```

Dump every provider's schema as JSON.

```bash
terraform providers schema -json | jq
```

## Modules

Refresh installed modules without re-initialising the backend.

```bash
terraform get -update
```

## Console

Interactive REPL for evaluating expressions against state and config.

```bash
terraform console
```

Inside the console:

```text
> jsonencode(var.tags)
> [for s in aws_subnet.private : s.cidr_block]
```

## Testing

Run native module tests under `tests/`.

```bash
terraform test
```

Filter to a single test file.

```bash
terraform test -filter=tests/basic.tftest.hcl
```

## OpenTofu-only

State encryption (built-in, no third-party tooling required).

```bash
tofu init -encryption=...
```

Early-evaluation: variables in backend / module source blocks.

```bash
tofu plan
```

## Cleanup

Remove the local `.terraform` directory and lockfile.

```bash
rm -rf .terraform .terraform.lock.hcl
```

Destroy every managed resource (read the plan twice).

```bash
terraform destroy
```
