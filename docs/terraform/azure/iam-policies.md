---
title: RBAC role assignments
description: Azure RBAC patterns for Terraform: built-in role assignments, custom role definitions, and federated CI identities (OIDC) for GitHub Actions.
tags:
  - terraform
  - azure
---

# RBAC role assignments

Azure doesn't have AWS-style IAM policies. Permissions are expressed as
**role definitions** (a list of allowed/denied actions) bound to a
**principal** at a **scope** (management group, subscription, resource group,
or resource). The binding itself is an `azurerm_role_assignment`.

!!! tip "Prefer built-in roles"
    Microsoft maintains 200+ [built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles).
    Reach for a custom role only when no built-in role fits: custom roles
    are scoped to one tenant and harder to audit.

## Built-in role assignment

Assign a built-in role at any scope. The trio (`scope`,
`role_definition_name`, `principal_id`) uniquely identifies the assignment.

### Subscription scope

```hcl
data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "platform_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azuread_group.platform_team.object_id
}
```

### Resource-group scope

```hcl
resource "azurerm_role_assignment" "rg_contributor" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.app_deployer.object_id
}
```

### Resource scope (managed identity → Key Vault)

```hcl
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${var.project}-${var.environment}"
  resource_group_name = azurerm_resource_group.app.name
  location            = azurerm_resource_group.app.location
}

resource "azurerm_role_assignment" "app_kv_secrets" {
  scope                = azurerm_key_vault.app.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
```

!!! note "principal_type"
    For service principals or managed identities created in the same apply,
    set `principal_type = "ServicePrincipal"` to skip the AAD propagation
    poll and avoid `PrincipalNotFound` errors on first run.

## Custom role definition

When a built-in role is too broad, define a custom one. List only the
control-plane operations you need; use `data_actions` for data-plane
operations on storage / Key Vault / etc.

```hcl
data "azurerm_subscription" "current" {}

resource "azurerm_role_definition" "vm_operator" {
  name        = "VM Operator (start/stop)"
  scope       = data.azurerm_subscription.current.id
  description = "Start, stop, restart, and view VMs. No create/delete/modify."

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/instanceView/read",
    ]
    not_actions = []
  }

  assignable_scopes = [
    data.azurerm_subscription.current.id,
  ]
}

resource "azurerm_role_assignment" "ops_team_vm_operator" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = azurerm_role_definition.vm_operator.role_definition_resource_id
  principal_id       = azuread_group.ops_team.object_id
}
```

!!! warning "Use `role_definition_resource_id`"
    `role_definition_id` on the role definition is a tenant-scoped GUID;
    role *assignments* need the full resource ID (which embeds the scope).
    Always reference `role_definition_resource_id` when wiring them up.

## Federated CI: GitHub Actions → Azure (OIDC)

Federated identity credentials let a GitHub Actions workflow assume an Entra
ID app registration without storing a client secret. The flow:

1. Create an app registration + service principal.
2. Add a federated identity credential that trusts a specific
    `repo:owner/name:ref:refs/heads/main` subject.
3. Assign the SP an Azure role at the right scope.
4. In CI, set `ARM_USE_OIDC=true` and `ARM_CLIENT_ID/_TENANT_ID/_SUBSCRIPTION_ID`.

```hcl
terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    azuread = { source = "hashicorp/azuread", version = "~> 3.0" }
  }
}

# 1. App + SP for the CI pipeline
resource "azuread_application" "ci" {
  display_name = "github-${var.project}-${var.environment}"
}

resource "azuread_service_principal" "ci" {
  client_id = azuread_application.ci.client_id
}

# 2. Trust GitHub's OIDC issuer for a specific repo + ref
resource "azuread_application_federated_identity_credential" "ci_main" {
  application_id = azuread_application.ci.id
  display_name   = "github-main"
  description    = "Trust GitHub Actions on main branch"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:my-org/${var.project}:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "ci_pr" {
  application_id = azuread_application.ci.id
  display_name   = "github-pull-request"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:my-org/${var.project}:pull_request"
}

# 3. Grant the SP rights on the target subscription
resource "azurerm_role_assignment" "ci_contributor" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ci.object_id
  principal_type       = "ServicePrincipal"
}

# Plus blob data access for the tfstate container
resource "azurerm_role_assignment" "ci_tfstate" {
  scope                = azurerm_storage_container.tfstate.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.ci.object_id
  principal_type       = "ServicePrincipal"
}

output "github_actions_env" {
  description = "Copy these into your GitHub repo as Variables (not Secrets)."
  value = {
    AZURE_CLIENT_ID       = azuread_application.ci.client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_subscription.current.subscription_id
  }
}
```

!!! tip "Subject claim format"
    `subject` is matched literally, there is no glob support. Add one
    federated credential per ref pattern you want to trust:

    | Use case            | Subject                                          |
    | ------------------- | ------------------------------------------------ |
    | Branch              | `repo:org/repo:ref:refs/heads/main`              |
    | Tag                 | `repo:org/repo:ref:refs/tags/v1.2.3`             |
    | Pull request        | `repo:org/repo:pull_request`                     |
    | GitHub environment  | `repo:org/repo:environment:production`           |

## Service principal for non-OIDC CI

Where federated identity isn't available (self-hosted runners on legacy
networks, third-party CI without OIDC), fall back to a client secret stored
in your secret manager. Rotate it on a schedule.

```hcl
resource "azuread_application" "ci_legacy" {
  display_name = "ci-${var.project}-legacy"
}

resource "azuread_service_principal" "ci_legacy" {
  client_id = azuread_application.ci_legacy.client_id
}

resource "azuread_application_password" "ci_legacy" {
  application_id = azuread_application.ci_legacy.id
  display_name   = "rotation-2026-q2"
  end_date       = "2026-08-01T00:00:00Z"
}

resource "azurerm_role_assignment" "ci_legacy_contributor" {
  scope                = azurerm_resource_group.app.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.ci_legacy.object_id
  principal_type       = "ServicePrincipal"
}
```

---

## References

- [azurerm_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)
- [azurerm_role_definition](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition)
- [azuread_application_federated_identity_credential](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential)
- [Microsoft Learn: Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Microsoft Learn: Built-in roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Microsoft Learn: Workload identity federation](https://learn.microsoft.com/en-us/entra/workload-id/workload-identity-federation)
- [GitHub Docs: Configuring OIDC in Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
