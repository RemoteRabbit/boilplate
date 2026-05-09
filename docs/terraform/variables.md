---
title: Common variables
description: Reusable, well-validated Terraform / OpenTofu variable blocks for environment, region, tags, CIDRs, naming, and more.
tags:
  - terraform
---

# Common variables

Drop-in `variable` blocks with `type`, `description`, sensible defaults, and
`validation` rules. They work with **Terraform ≥ 1.3** and **OpenTofu ≥ 1.6**.

!!! tip "Conventions used on this page"
    - All variables have a `description`.
    - `error_message` is a complete sentence ending in a period.
    - Defaults are only set when there's a safe, common choice.
    - Optional values are typed `string` with `default = null` and
      `nullable = true` rather than empty strings, so missing values are explicit.

---

# AWS

## Region

```hcl
variable "aws_region" {
  description = "AWS region to deploy into (e.g. us-east-1)."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^(af|ap|ca|eu|me|sa|us|us-gov|cn)-[a-z]+-[0-9]+$", var.aws_region))
    error_message = "aws_region must look like a valid AWS region code (e.g. us-east-1, eu-west-2, ap-southeast-1)."
  }
}
```

## Account ID

```hcl
variable "aws_account_id" {
  type        = string
  description = "The AWS account ID (12-digit number)."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "The aws_account_id must be exactly 12 digits (0-9), with no spaces, dashes, or other characters."
  }
}
```

!!! note "Hard character limit"
    AWS account IDs are always exactly 12 numeric digits — anchoring with ^...$ rejects accidental whitespace or extra characters.

!!! note "Why not number type"
    Keep them as string, not number — leading zeros are valid in account IDs and number would strip them.

## List of Account IDs

```hcl
variable "aws_account_ids" {
  type        = list(string)
  description = "A list of AWS account IDs (each a 12-digit number)."

  validation {
    condition     = alltrue([for id in var.aws_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "Each entry in aws_account_ids must be exactly 12 digits (0-9)."
  }
}
```

!!! note "Hard character limit"
    AWS account IDs are always exactly 12 numeric digits — anchoring with ^...$ rejects accidental whitespace or extra characters.

!!! note "Why not number type"
    Keep them as string, not number — leading zeros are valid in account IDs and number would strip them.

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
governance / cost-allocation tags.

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
    condition     = alltrue([for v in values(var.tags) : length(v) > 0 && length(v) <= 256])
    error_message = "Every tag value must be a non-empty string of at most 256 characters."
  }
}
```

## CIDR block

```hcl
variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC. Must be a /16–/28 RFC 1918 range."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block (e.g. 10.0.0.0/16)."
  }

  validation {
    condition     = tonumber(split("/", var.vpc_cidr)[1]) >= 16 && tonumber(split("/", var.vpc_cidr)[1]) <= 28
    error_message = "vpc_cidr prefix length must be between /16 and /28."
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

## Instance type

```hcl
variable "instance_type" {
  description = "EC2 instance type, e.g. t3.micro or m6i.large."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]+\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like a valid EC2 instance type (family.size, e.g. t3.micro)."
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

## Email address

```hcl
variable "contact_email" {
  description = "Operational contact email used for alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.contact_email))
    error_message = "contact_email must be a valid email address."
  }
}
```

## Optional string (nullable)

Prefer `null` over `""` so "unset" is explicit:

```hcl
variable "kms_key_arn" {
  description = "Optional KMS key ARN for encryption. When null, an AWS-managed key is used."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-zA-Z-]*:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", var.kms_key_arn))
    error_message = "kms_key_arn must be null or a valid KMS key ARN."
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

## Numeric range

```hcl
variable "desired_capacity" {
  description = "Desired number of instances in the autoscaling group (1–100)."
  type        = number
  default     = 2

  validation {
    condition     = var.desired_capacity >= 1 && var.desired_capacity <= 100 && floor(var.desired_capacity) == var.desired_capacity
    error_message = "desired_capacity must be an integer between 1 and 100."
  }
}
```

## Object with optional attributes

Uses `optional()` from Terraform 1.3+ / OpenTofu so consumers only specify what
they care about:

```hcl
variable "logging" {
  description = "Logging configuration. Any field not specified falls back to defaults."
  type = object({
    enabled            = optional(bool, true)
    retention_in_days  = optional(number, 30)
    log_group_name     = optional(string)
  })
  default = {}

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.logging.retention_in_days)
    error_message = "logging.retention_in_days must be a CloudWatch-supported retention value."
  }
}
```

## Map of objects

```hcl
variable "subnets" {
  description = "Map of subnet name to its CIDR and AZ suffix (a/b/c)."
  type = map(object({
    cidr = string
    az   = string
  }))
  default = {}

  validation {
    condition     = alltrue([for s in values(var.subnets) : can(cidrnetmask(s.cidr))])
    error_message = "Every subnets[*].cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = alltrue([for s in values(var.subnets) : contains(["a", "b", "c", "d", "e", "f"], s.az)])
    error_message = "Every subnets[*].az must be one of: a, b, c, d, e, f."
  }
}
```

## Secrets / sensitive values

!!! warning "Never commit secret values"
    Provide via `TF_VAR_*` env vars, a secrets manager, or a `.auto.tfvars` file
    that is `.gitignore`-d. The validation below only enforces a minimum length.

```hcl
variable "db_password" {
  description = "Database admin password. Provide via TF_VAR_db_password or a secrets manager — do not commit."
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
- [Terraform: Custom Validation Rules](https://developer.hashicorp.com/terraform/language/values/variables#custom-validation-rules)
- [OpenTofu: Variables](https://opentofu.org/docs/language/values/variables/)
