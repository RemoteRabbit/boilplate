---
title: Remote state backends
description: GCS backend configuration for Terraform/OpenTofu: versioning, encryption, automatic locking, bootstrap, and Workload Identity Federation auth from CI.
tags:
  - terraform
  - gcp
---

# Remote state backends

The `gcs` backend stores Terraform state in a Google Cloud Storage bucket.
State **locking is automatic**: GCS uses object generations to coordinate
concurrent writers, so there is no DynamoDB-equivalent table to provision.

!!! tip "Pick a single regional bucket per state"
    Use a regional (not multi-region) bucket close to where you run plans,
    enable **Object Versioning**, **Uniform bucket-level access**, and either
    a Google-managed key or a CMEK. One bucket can hold many state files;
    use `prefix` to namespace them.

---

## Minimal `backend "gcs"` block

```hcl
terraform {
  required_version = ">= 1.3"

  backend "gcs" {
    bucket = "acme-tfstate-prod"
    prefix = "platform/network"
  }
}
```

State will be stored as `gs://acme-tfstate-prod/platform/network/default.tfstate`
(per-workspace files live alongside it).

## Customer-managed encryption (CMEK)

```hcl
terraform {
  backend "gcs" {
    bucket          = "acme-tfstate-prod"
    prefix          = "platform/network"
    encryption_key  = "projects/acme-sec/locations/us/keyRings/tfstate/cryptoKeys/state"
  }
}
```

If `encryption_key` is omitted, GCS encrypts state with Google-managed keys.
Either is fine, pick CMEK only when policy demands it.

## State versioning

GCS *bucket* Object Versioning gives you point-in-time recovery for state.
Enable it on the bucket itself, not via the backend block:

```hcl
resource "google_storage_bucket" "tfstate" {
  name                        = "acme-tfstate-prod"
  location                    = "US-CENTRAL1"
  project                     = "acme-shared"
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}
```

## Locking

There is **nothing to configure**. The `gcs` backend uses GCS object
generation preconditions to acquire/release a `.tflock` object atomically.
Concurrent `terraform apply` runs will block with `Error acquiring the state
lock` until the holder finishes (or you `terraform force-unlock`).

---

## Bootstrap pattern (chicken-and-egg)

You can't store the state of the bucket *in* the bucket on first apply.
Standard pattern:

1. **Apply once locally** with the default `local` backend to create the
   state bucket (and KMS key, if any).
2. Add the `backend "gcs"` block.
3. Run `terraform init -migrate-state` to push `terraform.tfstate` into GCS.
4. Commit and delete the local `terraform.tfstate*` files.

```hcl
# bootstrap/main.tf: run with local state, ONCE per org
terraform {
  required_version = ">= 1.3"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "tfstate" {
  name                        = "${var.project_id}-tfstate"
  location                    = upper(var.region)
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning { enabled = true }
}

output "backend_hcl" {
  value = <<-EOT
    terraform {
      backend "gcs" {
        bucket = "${google_storage_bucket.tfstate.name}"
        prefix = "REPLACE_ME"
      }
    }
  EOT
}
```

Then in any downstream stack:

```bash
terraform init -migrate-state
```

---

## Workload Identity Federation (GitHub Actions auth)

Don't ship long-lived JSON service-account keys. Use **Workload Identity
Federation** so GitHub Actions exchanges its OIDC token for short-lived
Google credentials.

```hcl
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-pool"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Hard scope tokens to your org/repo so a fork can't impersonate you.
  attribute_condition = "assertion.repository_owner == 'acme-co'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "tf_deployer" {
  project      = var.project_id
  account_id   = "tf-deployer"
  display_name = "Terraform deployer (GitHub Actions)"
}

# Allow only main-branch runs of acme-co/infra to impersonate the SA.
resource "google_service_account_iam_member" "tf_deployer_wif" {
  service_account_id = google_service_account.tf_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/acme-co/infra"
}
```

GitHub Actions workflow:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github
          service_account: tf-deployer@acme-platform-prod.iam.gserviceaccount.com
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform plan
```

The deployer SA needs `roles/storage.objectAdmin` (or finer) on the state
bucket and whatever roles are required to manage your resources.

---

## References

- [Terraform: gcs backend](https://developer.hashicorp.com/terraform/language/backend/gcs)
- [GCS: Object Versioning](https://cloud.google.com/storage/docs/object-versioning)
- [GCS: Customer-managed encryption keys](https://cloud.google.com/storage/docs/encryption/customer-managed-keys)
- [GCP: Workload Identity Federation overview](https://cloud.google.com/iam/docs/workload-identity-federation)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
