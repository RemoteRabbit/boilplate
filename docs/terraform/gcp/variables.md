---
title: Common variables
description: Reusable, well-validated Terraform / OpenTofu variable blocks for GCP — project, region, zone, labels, CIDRs, machine type, and more.
tags:
  - terraform
  - gcp
---

# Common variables

Drop-in `variable` blocks for the **google** and **google-beta** providers, with
`type`, `description`, sensible defaults, and `validation` rules. They work
with **Terraform ≥ 1.3** and **OpenTofu ≥ 1.6** and the **google provider ≥ 6.0**.

!!! tip "Conventions used on this page"
    - All variables have a `description`.
    - `error_message` is a complete sentence ending in a period.
    - Defaults are only set when there's a safe, common choice.
    - Optional values are typed `string` with `default = null` and
      `nullable = true` rather than empty strings, so missing values are explicit.

---

## Project ID

GCP project IDs must start with a lowercase letter, be 6–30 characters long,
and contain only lowercase letters, digits, and hyphens.

```hcl
variable "project_id" {
  description = "GCP project ID (e.g. acme-platform-prod). 6–30 chars, lowercase letter start."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must start with a lowercase letter, be 6–30 chars, and contain only lowercase letters, digits, or hyphens (no trailing hyphen)."
  }
}
```

## Region

```hcl
variable "region" {
  description = "GCP region to deploy regional resources into (e.g. us-central1)."
  type        = string
  default     = "us-central1"

  validation {
    condition     = can(regex("^(asia|australia|europe|me|northamerica|southamerica|us|africa)-[a-z]+[0-9]+$", var.region))
    error_message = "region must look like a valid GCP region (e.g. us-central1, europe-west4, asia-southeast1)."
  }
}
```

## Zone

```hcl
variable "zone" {
  description = "GCP zone for zonal resources (e.g. us-central1-a). Must belong to var.region."
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = can(regex("^(asia|australia|europe|me|northamerica|southamerica|us|africa)-[a-z]+[0-9]+-[a-z]$", var.zone))
    error_message = "zone must look like a valid GCP zone (e.g. us-central1-a, europe-west4-b)."
  }
}
```

## Environment

```hcl
variable "environment" {
  description = "Deployment environment. Used in resource names, labels, and conditional logic."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: dev, stg, prod."
  }
}
```

## Project / application name

A short naming prefix used for resources — distinct from the GCP `project_id`.

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

## Labels (with required keys)

!!! warning "GCP label rules"
    GCP labels are **lowercase only** and limited to letters, digits, hyphens,
    and underscores. Keys must start with a lowercase letter; values may be
    empty. Maximum length is 63 characters for both keys and values, and a
    resource may have at most 64 labels.

```hcl
variable "labels" {
  description = "Labels applied to every labelable resource. Must include owner, environment, and cost_center."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k in ["owner", "environment", "cost_center"] : contains(keys(var.labels), k)
    ])
    error_message = "labels must include the keys: owner, environment, cost_center."
  }

  validation {
    condition     = alltrue([for k in keys(var.labels) : can(regex("^[a-z][a-z0-9_-]{0,62}$", k))])
    error_message = "Every label key must start with a lowercase letter and contain only lowercase letters, digits, hyphens, or underscores (≤63 chars)."
  }

  validation {
    condition     = alltrue([for v in values(var.labels) : can(regex("^[a-z0-9_-]{0,63}$", v))])
    error_message = "Every label value must be lowercase letters, digits, hyphens, or underscores only (≤63 chars)."
  }
}
```

## CIDR block

```hcl
variable "network_cidr" {
  description = "IPv4 CIDR block for the VPC subnet primary range. Must be a /16–/29 RFC 1918 range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.network_cidr))
    error_message = "network_cidr must be a valid IPv4 CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.network_cidr)[1]) >= 16 && tonumber(split("/", var.network_cidr)[1]) <= 29
    error_message = "network_cidr prefix length must be between /16 and /29."
  }
}
```

### List of CIDRs (allowlist)

```hcl
variable "allowed_cidrs" {
  description = "Source CIDR blocks allowed to reach the service. Use [\"0.0.0.0/0\"] only deliberately."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.allowed_cidrs : can(cidrnetmask(c))])
    error_message = "Every entry in allowed_cidrs must be a valid IPv4 CIDR block."
  }
}
```

## Machine type

```hcl
variable "machine_type" {
  description = "Compute Engine machine type, e.g. e2-medium or n2-standard-4."
  type        = string
  default     = "e2-medium"

  validation {
    condition     = can(regex("^(([a-z][0-9][a-z]?)-(micro|small|medium|standard|highmem|highcpu|megamem|ultramem)(-[0-9]+)?|custom-[0-9]+-[0-9]+)$", var.machine_type))
    error_message = "machine_type must look like a valid Compute Engine type (e.g. e2-medium, n2-standard-4, c3-highcpu-8)."
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

## Service account email

```hcl
variable "service_account_email" {
  description = "Email of an existing service account, e.g. deployer@my-project.iam.gserviceaccount.com."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]@[a-z][a-z0-9-]{4,28}[a-z0-9]\\.iam\\.gserviceaccount\\.com$", var.service_account_email))
    error_message = "service_account_email must be a valid GCP service account email of the form NAME@PROJECT_ID.iam.gserviceaccount.com."
  }
}
```

## Optional KMS key (nullable)

Prefer `null` over `""` so "unset" is explicit:

```hcl
variable "kms_key_name" {
  description = "Optional Cloud KMS CryptoKey resource ID. When null, Google-managed encryption keys are used."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.kms_key_name == null || can(regex("^projects/[a-z][a-z0-9-]{4,28}[a-z0-9]/locations/[a-z0-9-]+/keyRings/[a-zA-Z0-9_-]+/cryptoKeys/[a-zA-Z0-9_-]+$", var.kms_key_name))
    error_message = "kms_key_name must be null or a fully-qualified CryptoKey resource ID (projects/.../locations/.../keyRings/.../cryptoKeys/...)."
  }
}
```

## Boolean feature flag

```hcl
variable "enable_logging" {
  description = "Whether to enable verbose access logging. Disable in cost-sensitive environments."
  type        = bool
  default     = true
}
```

## Object with optional attributes (Cloud Logging)

Uses `optional()` from Terraform 1.3+ / OpenTofu so consumers only specify what
they care about. Cloud Logging custom retention is between 1 and 3650 days.

```hcl
variable "logging" {
  description = "Cloud Logging configuration for a log bucket. Any field not specified falls back to defaults."
  type = object({
    enabled          = optional(bool, true)
    retention_days   = optional(number, 30)
    log_bucket_name  = optional(string)
    location         = optional(string, "global")
  })
  default = {}

  validation {
    condition     = var.logging.retention_days >= 1 && var.logging.retention_days <= 3650
    error_message = "logging.retention_days must be between 1 and 3650 (Cloud Logging custom retention range)."
  }
}
```

## Map of subnets

```hcl
variable "subnets" {
  description = "Map of subnet name to its primary CIDR range and region."
  type = map(object({
    ip_cidr_range = string
    region        = string
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrnetmask(s.ip_cidr_range))])
    error_message = "Every subnets[*].ip_cidr_range must be a valid IPv4 CIDR block."
  }

  validation {
    condition = alltrue([
      for s in values(var.subnets) :
      can(regex("^(asia|australia|europe|me|northamerica|southamerica|us|africa)-[a-z]+[0-9]+$", s.region))
    ])
    error_message = "Every subnets[*].region must look like a valid GCP region (e.g. us-central1)."
  }
}
```

## Secrets / sensitive values

!!! warning "Never commit secret values"
    Provide via `TF_VAR_*` env vars, Secret Manager, or a `.auto.tfvars` file
    that is `.gitignore`-d. The validation below only enforces a minimum length.

```hcl
variable "db_password" {
  description = "Cloud SQL admin password. Provide via TF_VAR_db_password or Secret Manager — do not commit."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "db_password must be at least 16 characters."
  }
}
```

---

## References

- [Terraform: Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform Registry: google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Registry: google-beta provider](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs)
- [GCP: Project IDs](https://cloud.google.com/resource-manager/docs/creating-managing-projects#identifying_projects)
- [GCP: Regions and zones](https://cloud.google.com/compute/docs/regions-zones)
- [GCP: Labels requirements](https://cloud.google.com/resource-manager/docs/creating-managing-labels#requirements)
- [GCP: Machine types](https://cloud.google.com/compute/docs/machine-resource)
