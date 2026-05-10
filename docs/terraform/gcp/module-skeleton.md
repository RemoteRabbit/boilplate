---
title: Module skeleton
description: Opinionated layout for a reusable Terraform/OpenTofu module targeting the google + google-beta providers.
tags:
  - terraform
  - gcp
---

# Module skeleton

A minimal, opinionated layout for a reusable GCP module. Targets
**Terraform ≥ 1.3** / **OpenTofu ≥ 1.6** and the **google / google-beta**
providers ≥ 6.0.

```text
modules/gcs-bucket/
├── README.md
├── versions.tf
├── providers.tf          # provider configuration aliases (google-beta)
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── examples/
│   └── basic/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── tests/
    └── basic.tftest.hcl
```

!!! tip "Configure providers *outside* the module"
    A module should declare *required* providers in `versions.tf` but not
    `provider {}` blocks. The root module owns auth, project, and region.
    The exception is provider aliases (e.g. `google-beta`), which the module
    can require but the caller must pass via `providers = { ... }`.

---

## `versions.tf`

```hcl
terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 6.0, < 7.0"
    }
  }
}
```

## `variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID the bucket lives in."
  type        = string
}

variable "name" {
  description = "Bucket name (must be globally unique)."
  type        = string
}

variable "location" {
  description = "Bucket location (region or multi-region). Defaults to US-CENTRAL1."
  type        = string
  default     = "US-CENTRAL1"
}

variable "labels" {
  description = "Additional labels to merge over the module defaults."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Deployment environment (dev/stg/prod)."
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: dev, stg, prod."
  }
}
```

## `locals.tf`

```hcl
locals {
  default_labels = {
    managed_by  = "terraform"
    module      = "gcs-bucket"
    environment = var.environment
  }

  labels = merge(local.default_labels, var.labels)
}
```

## `main.tf`

```hcl
resource "google_storage_bucket" "this" {
  project                     = var.project_id
  name                        = var.name
  location                    = var.location
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  labels = local.labels
}
```

## `outputs.tf`

```hcl
output "name" {
  description = "Name of the bucket."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "Self-link of the bucket."
  value       = google_storage_bucket.this.self_link
}
```

---

## `examples/basic/main.tf`

```hcl
terraform {
  required_version = ">= 1.3"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

module "bucket" {
  source = "../.."

  project_id  = var.project_id
  name        = "${var.project_id}-example"
  environment = "dev"

  labels = {
    owner       = "platform"
    cost_center = "infra"
  }
}

variable "project_id" { type = string }

output "bucket_url" { value = module.bucket.url }
```

---

## Native tests

Terraform `*.tftest.hcl` files run with `terraform test`. They support pure
plan-only assertions (fast, no resources created) and full apply runs.

```hcl
# tests/basic.tftest.hcl

variables {
  project_id  = "acme-platform-test"
  environment = "dev"
}

run "plan_basic" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = module.bucket.name == "acme-platform-test-example"
    error_message = "Bucket name was not derived from project_id."
  }
}

run "labels_merged" {
  command = plan

  module {
    source = "./examples/basic"
  }

  assert {
    condition     = lookup(module.bucket.labels, "managed_by", "") == "terraform"
    error_message = "Default label managed_by=terraform was not applied."
  }
}
```

Run with:

```bash
terraform init
terraform test
```

---

## README structure

Generate the inputs/outputs tables from source, never hand-maintain them:

```bash
terraform-docs markdown table --output-file README.md --output-mode inject .
```

Recommended sections (in order): **Purpose**, **Usage** (smallest possible
example), **Inputs** (auto), **Outputs** (auto), **Providers** (auto),
**Requirements** (auto).

---

## References

- [Terraform: Module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [Terraform: Tests](https://developer.hashicorp.com/terraform/language/tests)
- [Terraform Registry: google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Registry: google-beta provider](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs)
- [terraform-docs](https://terraform-docs.io/)
