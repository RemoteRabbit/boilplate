---
title: Remote state backends
description: Azure Storage backend configuration for Terraform / OpenTofu — blob lease locking, OIDC auth from CI, and the bootstrap pattern.
tags:
  - terraform
  - azure
---

# Remote state backends

The **`azurerm`** backend stores Terraform state as a blob in an Azure Storage
container. State locking is automatic via blob leases (no separate lock table
like AWS DynamoDB), and encryption-at-rest is on by default.

!!! tip "Use Azure AD auth, not storage keys"
    Setting `use_azuread_auth = true` makes the backend authenticate with your
    Azure AD identity (CLI or workload identity) instead of a shared storage
    account key. Pair it with the **Storage Blob Data Contributor** role on
    the container.

## Minimal backend block

```hcl
terraform {
  required_version = ">= 1.3"

  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateprod001"     # globally unique, 3–24 lowercase
    container_name       = "tfstate"
    key                  = "platform/network.tfstate"

    use_azuread_auth = true                     # AAD instead of access keys
    subscription_id  = "00000000-0000-0000-0000-000000000000"
    tenant_id        = "11111111-1111-1111-1111-111111111111"
  }
}
```

!!! note "Locking"
    The azurerm backend acquires a blob lease on the state object for the
    duration of any operation that mutates state. If a previous run crashed,
    break the lease with
    `az storage blob lease break --container-name tfstate --blob-name platform/network.tfstate --account-name tfstateprod001 --auth-mode login`.

## OIDC from GitHub Actions

Federated credentials let CI authenticate without a long-lived secret. Set
`use_oidc = true` in the backend and export `ARM_USE_OIDC=true` in the
workflow; `azurerm` picks up `ACTIONS_ID_TOKEN_REQUEST_TOKEN` /
`ACTIONS_ID_TOKEN_REQUEST_URL` automatically.

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateprod001"
    container_name       = "tfstate"
    key                  = "platform/network.tfstate"

    use_azuread_auth = true
    use_oidc         = true
    subscription_id  = "00000000-0000-0000-0000-000000000000"
    tenant_id        = "11111111-1111-1111-1111-111111111111"
    client_id        = "22222222-2222-2222-2222-222222222222"
  }
}
```

```yaml
# .github/workflows/terraform.yml
permissions:
  id-token: write   # required for OIDC
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    env:
      ARM_USE_OIDC:       "true"
      ARM_CLIENT_ID:      ${{ vars.AZURE_CLIENT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      ARM_TENANT_ID:      ${{ vars.AZURE_TENANT_ID }}
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan
```

## RBAC required on the state container

The identity running Terraform needs **data-plane** access on the blob
container — control-plane roles like *Contributor* are not enough when
`use_azuread_auth = true`.

```hcl
resource "azurerm_role_assignment" "tfstate_writer" {
  scope                = azurerm_storage_container.tfstate.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.ci.object_id
}
```

| Role                              | Why                                 |
| --------------------------------- | ----------------------------------- |
| Storage Blob Data Contributor     | Read / write state blobs and leases |
| Storage Blob Data Reader          | `terraform plan -refresh-only` only |

## Bootstrap pattern

You can't store the state of the storage account *in* the storage account
itself. Solve it with a one-shot bootstrap module that runs against **local**
state, then migrate it.

```hcl
# bootstrap/main.tf  — apply with local state, then `terraform state push`.
terraform {
  required_version = ">= 1.3"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "tfstate" {
  name     = "tfstate-rg"
  location = "eastus"
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "tfstateprod001"
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  account_kind                    = "StorageV2"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false        # force AAD auth
  allow_nested_items_to_be_public = false

  blob_properties {
    versioning_enabled  = true                   # recover overwritten state
    change_feed_enabled = true
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id
  container_access_type = "private"
}
```

Workflow:

1. `cd bootstrap && terraform init && terraform apply` (local state).
2. Add the `backend "azurerm"` block to the bootstrap module.
3. `terraform init -migrate-state` — Terraform copies the local state into
    the new container.
4. Commit; never apply the bootstrap module from CI again.

!!! warning "Protect the storage account"
    Enable blob versioning, soft delete (≥ 30 days), and a resource lock
    (`azurerm_management_lock` with `lock_level = "CanNotDelete"`). Losing
    state for a production environment is *much* harder to recover from than
    losing infrastructure.

---

## References

- [Terraform: azurerm backend](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [OpenTofu: azurerm backend](https://opentofu.org/docs/language/settings/backends/azurerm/)
- [Microsoft Learn: Store Terraform state in Azure Storage](https://learn.microsoft.com/en-us/azure/developer/terraform/store-state-in-azure-storage)
- [Microsoft Learn: GitHub Actions OIDC for Azure](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure)
- [Azure Storage Blob Data Contributor role](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage#storage-blob-data-contributor)
