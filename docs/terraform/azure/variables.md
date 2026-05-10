---
title: Common variables
description: Reusable, well-validated Terraform / OpenTofu variable blocks for Azure — location, subscription, tenant, resource groups, tags, CIDRs, VM sizes, and more.
tags:
  - terraform
  - azure
---

# Common variables

Drop-in `variable` blocks for the **azurerm** provider with `type`,
`description`, sensible defaults, and `validation` rules. They work with
**Terraform ≥ 1.3**, **OpenTofu ≥ 1.6**, and **azurerm ≥ 4.0**.

!!! tip "Conventions used on this page"
    - All variables have a `description`.
    - `error_message` is a complete sentence ending in a period.
    - Defaults are only set when there's a safe, common choice.
    - Optional values are typed `string` with `default = null` and
      `nullable = true` rather than empty strings, so missing values are explicit.

---

# Azure

## Location

```hcl
variable "location" {
  description = "Azure region to deploy into (e.g. eastus, westeurope, northeurope)."
  type        = string
  default     = "eastus"

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*[0-9]*$", var.location))
    error_message = "location must be a lowercase Azure region short name (e.g. eastus, westeurope, australiaeast)."
  }
}
```

!!! tip "Discover valid regions"
    Run `az account list-locations -o table --query "[].name"` to see the
    regions enabled for your subscription.

## Subscription ID

```hcl linenums="1" hl_lines="2 6"
variable "subscription_id" {
  type        = string # (1)!
  description = "The Azure subscription ID (UUID)."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id)) # (2)!
    error_message = "subscription_id must be a valid GUID (8-4-4-4-12 hex digits)."
  }
}
```

1. Always a string. Azure subscription IDs are GUIDs, not numbers.
2. Anchored `^...$` rejects accidental whitespace or partial matches.

## Tenant ID

```hcl
variable "tenant_id" {
  description = "The Microsoft Entra ID (Azure AD) tenant ID (UUID)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a valid GUID (8-4-4-4-12 hex digits)."
  }
}
```

## Resource group name

```hcl
variable "resource_group_name" {
  description = "Name of the Azure Resource Group. 1–90 chars; letters, digits, underscores, parentheses, hyphens, periods. Cannot end with a period."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_().-]{1,89}[a-zA-Z0-9_()-]$", var.resource_group_name))
    error_message = "resource_group_name must be 1–90 characters of letters, digits, underscores, parentheses, hyphens, or periods, and must not end with a period."
  }
}
```

## Environment

```hcl
variable "environment" {
  description = "Deployment environment. Used in resource names, tags, and conditional logic."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: dev, stg, prod."
  }
}
```

## Project / application name

```hcl
variable "project" {
  description = "Short project identifier used as a prefix for resource names. Lowercase letters, digits, and hyphens only; 2–24 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,23}$", var.project))
    error_message = "project must start with a lowercase letter and contain only lowercase letters, digits, or hyphens (2–24 chars)."
  }
}
```

## Tags (with required keys)

Validates the map *and* enforces that specific keys are present — useful for
governance / cost-allocation tags. Tags on Azure are case-sensitive, max 512
chars per value (256 for storage), and limited to 50 per resource.

```hcl
variable "tags" {
  description = "Tags applied to every resource. Must include Owner, Environment, and CostCenter."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in ["Owner", "Environment", "CostCenter"] : contains(keys(var.tags), k)
    ])
    error_message = "tags must include the keys: Owner, Environment, CostCenter."
  }

  validation {
    condition     = length(var.tags) <= 50
    error_message = "Azure resources accept at most 50 tags."
  }

  validation {
    condition     = alltrue([for v in values(var.tags) : length(v) > 0 && length(v) <= 256])
    error_message = "Every tag value must be a non-empty string of at most 256 characters."
  }
}
```

## Address space (VNet)

```hcl
variable "address_space" {
  description = "IPv4 CIDR blocks assigned to the virtual network. Each entry must be a valid CIDR."
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.address_space) > 0
    error_message = "address_space must contain at least one CIDR block."
  }

  validation {
    condition     = alltrue([for c in var.address_space : can(cidrnetmask(c))])
    error_message = "Every entry in address_space must be a valid IPv4 CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = alltrue([for c in var.address_space : tonumber(split("/", c)[1]) >= 8 && tonumber(split("/", c)[1]) <= 29])
    error_message = "Each address_space prefix length must be between /8 and /29."
  }
}
```

## VM size

```hcl
variable "vm_size" {
  description = "Azure VM SKU, e.g. Standard_D2s_v5 or Standard_B2ms."
  type        = string
  default     = "Standard_D2s_v5"

  validation {
    condition     = can(regex("^(Standard|Basic)_[A-Z]+[0-9]+[a-z]*(_v[0-9]+)?$", var.vm_size))
    error_message = "vm_size must look like a valid Azure VM SKU (e.g. Standard_D2s_v5, Standard_B2ms)."
  }
}
```

## Domain name

```hcl
variable "domain_name" {
  description = "Fully qualified domain name (e.g. api.example.com). Lowercase, no trailing dot."
  type        = string

  validation {
    condition     = can(regex("^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,}$", var.domain_name))
    error_message = "domain_name must be a lowercase FQDN such as api.example.com (no trailing dot)."
  }
}
```

## Optional string (nullable)

Prefer `null` over `""` so "unset" is explicit:

```hcl
variable "key_vault_id" {
  description = "Optional Key Vault resource ID for CMK encryption. When null, a platform-managed key is used."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.key_vault_id == null || can(regex("^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/Microsoft.KeyVault/vaults/[^/]+$", var.key_vault_id))
    error_message = "key_vault_id must be null or a valid Key Vault resource ID."
  }
}
```

## Boolean feature flag

```hcl
variable "enable_diagnostics" {
  description = "Whether to send platform logs to Log Analytics. Disable in cost-sensitive environments."
  type        = bool
  default     = true
}
```

## Object with optional attributes (Log Analytics retention)

Uses `optional()` from Terraform 1.3+ / OpenTofu so consumers only specify what
they care about:

```hcl
variable "log_analytics" {
  description = "Log Analytics workspace configuration. Any field not specified falls back to defaults."
  type = object({
    enabled           = optional(bool, true)
    sku               = optional(string, "PerGB2018")
    retention_in_days = optional(number, 30)
    workspace_name    = optional(string)
  })
  default = {}

  validation {
    condition     = var.log_analytics.retention_in_days >= 30 && var.log_analytics.retention_in_days <= 730
    error_message = "log_analytics.retention_in_days must be between 30 and 730 (Log Analytics workspace limits)."
  }

  validation {
    condition     = contains(["Free", "PerNode", "Premium", "Standard", "Standalone", "Unlimited", "CapacityReservation", "PerGB2018"], var.log_analytics.sku)
    error_message = "log_analytics.sku must be a valid Log Analytics SKU (PerGB2018 is recommended)."
  }
}
```

## Map of subnets

```hcl
variable "subnets" {
  description = "Map of subnet name to its CIDR address prefixes."
  type = map(object({
    address_prefixes = list(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for s in values(var.subnets) : length(s.address_prefixes) > 0
    ])
    error_message = "Every subnets[*].address_prefixes must contain at least one CIDR block."
  }

  validation {
    condition = alltrue(flatten([
      for s in values(var.subnets) : [for c in s.address_prefixes : can(cidrnetmask(c))]
    ]))
    error_message = "Every entry in subnets[*].address_prefixes must be a valid IPv4 CIDR block."
  }
}
```

## Secrets / sensitive values

!!! warning "Never commit secret values"
    Provide via `TF_VAR_*` env vars, Azure Key Vault references, or a
    `.auto.tfvars` file that is `.gitignore`-d. The validation below only
    enforces a minimum length and Azure SQL complexity rules.

```hcl
variable "sql_admin_password" {
  description = "Azure SQL administrator password. Provide via TF_VAR_sql_admin_password or Key Vault — do not commit."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.sql_admin_password) >= 16
    error_message = "sql_admin_password must be at least 16 characters."
  }

  validation {
    condition = (
      can(regex("[A-Z]", var.sql_admin_password)) &&
      can(regex("[a-z]", var.sql_admin_password)) &&
      can(regex("[0-9]", var.sql_admin_password)) &&
      can(regex("[^A-Za-z0-9]", var.sql_admin_password))
    )
    error_message = "sql_admin_password must contain uppercase, lowercase, digit, and non-alphanumeric characters (Azure SQL complexity rule)."
  }
}
```

---

## References

- [Terraform: Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform: Custom Validation Rules](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [OpenTofu: Variables](https://opentofu.org/docs/language/values/variables/)
- [Microsoft Learn: azurerm provider](https://learn.microsoft.com/en-us/azure/developer/terraform/overview)
- [azurerm provider reference](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure resource naming rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules)
- [Azure VM sizes](https://learn.microsoft.com/en-us/azure/virtual-machines/sizes)
