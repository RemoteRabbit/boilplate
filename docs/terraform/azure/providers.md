---
title: Provider configuration
description: Sensible azurerm + azuread provider defaults for Terraform / OpenTofu — features block, OIDC auth from CI, multi-subscription aliases, and ARM environment variables.
tags:
  - terraform
  - azure
---

# Provider configuration

Drop-in `provider "azurerm"` blocks for the most common shapes: local
developer auth via Azure CLI, OIDC from CI, and multi-subscription aliases.
Targets **azurerm ≥ 4.0** and **azuread ≥ 3.0**.

!!! note "`features {}` is mandatory"
    The empty `features {}` block is required even when you don't override
    anything — `terraform validate` will fail without it. Use it to control
    destroy-time behaviours like Key Vault soft-delete recovery and resource
    group force-delete.

## `required_providers`

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
  }
}
```

## Baseline `provider "azurerm"` block

```hcl
provider "azurerm" {
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  features {
    key_vault {
      purge_soft_delete_on_destroy               = false
      purge_soft_deleted_secrets_on_destroy      = false
      recover_soft_deleted_key_vaults            = true
      recover_soft_deleted_secrets               = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }

    log_analytics_workspace {
      permanently_delete_on_destroy = false
    }

    storage {
      data_plane_available = true
    }
  }
}
```

!!! tip "Recover, don't purge"
    Defaults set above prefer **recovery** over **purge** for Key Vault and
    Log Analytics. Accidental destroys are recoverable; flip the flags only
    in ephemeral environments where you want a clean tear-down.

## `azuread` provider

```hcl
provider "azuread" {
  tenant_id = var.tenant_id
}
```

## Authentication

The provider tries auth methods in this order: **environment variables →
managed identity → OIDC → CLI**. Pick exactly one method per environment so
behaviour stays predictable.

### Local development — Azure CLI

```bash
az login
az account set --subscription "<your-subscription-id>"
```

```hcl
provider "azurerm" {
  features {}
  # subscription_id is read from the CLI context if omitted.
  use_cli = true   # default — shown for clarity
}
```

### CI — GitHub Actions OIDC

```hcl
provider "azurerm" {
  features {}

  use_oidc        = true
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  client_id       = var.client_id
}
```

```yaml
# .github/workflows/terraform.yml
permissions:
  id-token: write
  contents: read

jobs:
  apply:
    runs-on: ubuntu-latest
    env:
      ARM_USE_OIDC:        "true"
      ARM_CLIENT_ID:       ${{ vars.AZURE_CLIENT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID:       ${{ vars.AZURE_TENANT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform apply -auto-approve
```

### Self-hosted runners — Managed Identity

```hcl
provider "azurerm" {
  features {}
  use_msi         = true
  subscription_id = var.subscription_id
}
```

### Service principal + secret (legacy)

```bash
export ARM_CLIENT_ID="…"
export ARM_CLIENT_SECRET="…"   # rotate via Key Vault, never commit
export ARM_SUBSCRIPTION_ID="…"
export ARM_TENANT_ID="…"
```

```hcl
provider "azurerm" {
  features {}
  # All four IDs are read from ARM_* env vars.
}
```

## Multi-subscription aliases

Terraform supports multiple instances of the same provider via `alias`. Use
this to provision shared resources (DNS, Log Analytics) in one subscription
while everything else lives in a workload subscription.

```hcl
provider "azurerm" {
  alias           = "workload"
  features {}
  subscription_id = var.workload_subscription_id
}

provider "azurerm" {
  alias           = "shared"
  features {}
  subscription_id = var.shared_subscription_id
}

# Workload-subscription resource (default-ish — pick the alias explicitly)
resource "azurerm_resource_group" "app" {
  provider = azurerm.workload
  name     = "rg-app-prod"
  location = "eastus"
}

# Shared DNS zone lives in the platform subscription
resource "azurerm_dns_a_record" "api" {
  provider            = azurerm.shared
  name                = "api"
  zone_name           = "example.com"
  resource_group_name = "rg-shared-dns"
  ttl                 = 300
  records             = [azurerm_public_ip.api.ip_address]
}
```

!!! warning "Pass aliases into modules explicitly"
    A child module that uses an aliased provider must declare it in its own
    `required_providers` and you must wire it up via `providers = { ... }`
    on the `module` call:

    ```hcl
    module "dns" {
      source = "./modules/dns"
      providers = {
        azurerm = azurerm.shared
      }
    }
    ```

## ARM environment variables (reference)

| Variable                   | Purpose                                                |
| -------------------------- | ------------------------------------------------------ |
| `ARM_SUBSCRIPTION_ID`      | Default subscription (overrides CLI context).          |
| `ARM_TENANT_ID`            | Entra ID tenant.                                       |
| `ARM_CLIENT_ID`            | Service principal / app registration client ID.        |
| `ARM_CLIENT_SECRET`        | SP secret (avoid; prefer OIDC or MSI).                 |
| `ARM_USE_OIDC`             | `true` to use OIDC token from CI.                      |
| `ARM_OIDC_TOKEN_FILE_PATH` | Path to a file containing the OIDC token (Kubernetes). |
| `ARM_USE_MSI`              | `true` to use the runner's managed identity.           |
| `ARM_USE_CLI`              | `true` to use the Azure CLI session (default locally). |
| `ARM_ENVIRONMENT`          | `public`, `usgovernment`, `china`, `german`.           |

---

## References

- [azurerm provider reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [azurerm `features {}` block](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/features-block)
- [azurerm authentication overview](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli)
- [azurerm OIDC from GitHub Actions](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_oidc)
- [azuread provider reference](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs)
- [Terraform: Provider configuration](https://developer.hashicorp.com/terraform/language/providers/configuration)
- [Terraform: Multiple provider instances (`alias`)](https://developer.hashicorp.com/terraform/language/providers/configuration#alias-multiple-provider-configurations)
- [Microsoft Learn: Authenticate Terraform to Azure](https://learn.microsoft.com/en-us/azure/developer/terraform/authenticate-to-azure)
