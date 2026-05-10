---
title: Module skeleton
description: Opinionated layout for a reusable Azure Terraform / OpenTofu module — file structure, version pinning, naming conventions, terraform-docs, native tftest, and pre-commit-terraform.
tags:
  - terraform
  - azure
---

# Module skeleton

A predictable layout for a reusable Azure module. Drop these files into a new
repo and you have a module that lints, formats, generates docs, and self-tests
out of the box.

!!! tip "One module, one job"
    A module is a unit of *reuse*, not a unit of *deployment*. Keep modules
    focused (one VNet, one Storage account, one App Service plan), and let
    the consuming root configuration glue them together.

---

## Directory layout

```text
terraform-azurerm-<name>/
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
├── .tflint.hcl            # tflint ruleset (azurerm plugin)
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }

    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
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
    instantiate them. The root module owns
    `provider "azurerm" { features {} ... }` so the same module can be used
    in any subscription, tenant, or region.

---

## Naming conventions and tag merging

Azure has per-resource naming rules (length, allowed chars, sometimes
globally unique). Centralise the pattern in `locals.tf`:

```hcl
# locals.tf
locals {
  # <project>-<environment>-<name>, e.g. acme-prod-app
  name_prefix = "${var.project}-${var.environment}-${var.name}"

  # Resource-type abbreviations follow Microsoft's CAF guidance. # codespell:ignore CAF
  rg_name      = "rg-${local.name_prefix}"
  vnet_name    = "vnet-${local.name_prefix}"
  kv_name      = substr(replace("kv${var.project}${var.environment}${var.name}", "-", ""), 0, 24)

  tags = merge(
    var.tags,
    {
      Module      = "terraform-azurerm-${var.name}"
      Environment = var.environment
      Project     = var.project
    },
  )
}
```

```hcl
# main.tf
resource "azurerm_resource_group" "this" {
  name     = local.rg_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = var.address_space
  tags                = local.tags
}
```

!!! warning "Tags don't auto-propagate on Azure"
    Unlike AWS `default_tags`, the azurerm provider has no global tag
    injection. Apply `local.tags` (or pass `var.tags` through) on **every**
    taggable resource, or use Azure Policy `inheritTagsFromResourceGroup`
    at the subscription scope.

---

## `examples/basic/main.tf`

Every example is a real root module, not a snippet. CI should
`terraform init && terraform validate` every example on every PR.

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  type = string
}

module "network" {
  source = "../.."

  project     = "demo"
  environment = "dev"
  name        = "core"
  location    = "eastus"

  address_space = ["10.10.0.0/16"]

  tags = {
    Owner       = "platform"
    Environment = "dev"
    CostCenter  = "0001"
  }
}

output "vnet_id" {
  value = module.network.vnet_id
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
  name        = "core"
  location    = "eastus"
  address_space = ["10.10.0.0/16"]
  tags = {
    Owner       = "platform"
    Environment = "dev"
    CostCenter  = "0001"
  }
}

run "plan_defaults" {
  command = plan

  assert {
    condition     = output.resource_group_name == "rg-demo-dev-core"
    error_message = "Resource group should follow rg-<project>-<environment>-<name>."
  }
}

run "apply_basic" {
  command = apply

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/", run.apply_basic.vnet_id))
    error_message = "vnet_id should be a real Azure resource ID after apply."
  }
}
```

Run locally:

```bash
terraform init
terraform test
```

!!! tip "Mock the provider for fast tests"
    Use `mock_provider "azurerm" {}` blocks in your `.tftest.hcl` to run
    pure plan-time assertions without ever touching Azure. Reserve real
    `apply` runs for an integration job that has credentials.

---

## `README.md` with terraform-docs markers

Generate the inputs / outputs / providers tables automatically so they never
go stale.

````markdown
# terraform-azurerm-network

A VNet + subnet module for the platform team.

## Usage

```hcl
module "network" {
  source = "git::https://github.com/acme-co/terraform-azurerm-network.git?ref=v1.0.0"

  project     = "acme"
  environment = "prod"
  name        = "core"
  location    = "eastus"

  address_space = ["10.0.0.0/16"]
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
        args:
          - --args=--enable-plugin=azurerm
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
| `terraform_fmt`      | `terraform fmt -recursive`, canonical whitespace and key alignment.  |
| `terraform_validate` | `terraform validate` against every module and example.               |
| `terraform_tflint`   | Provider-aware linter; catches deprecated arguments and bad VM SKUs. |
| `terraform_docs`     | Regenerates the inputs / outputs table inside the README markers.    |

---

## References

- [Terraform: Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Terraform: Tests (`terraform test`)](https://developer.hashicorp.com/terraform/language/tests)
- [Microsoft Learn: Cloud Adoption Framework — naming conventions](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming)
- [Microsoft Learn: Recommended abbreviations for Azure resource types](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations)
- [azurerm provider reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [terraform-docs](https://terraform-docs.io/)
- [tflint azurerm ruleset](https://github.com/terraform-linters/tflint-ruleset-azurerm)
- [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
