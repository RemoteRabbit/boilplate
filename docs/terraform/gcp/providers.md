---
title: Provider configuration
description: Sensible defaults for the google and google-beta providers — pinning, project/region/zone, user_project_override, ADC vs Workload Identity Federation, aliases, and impersonation.
tags:
  - terraform
  - gcp
---

# Provider configuration

GCP provider boilerplate that you'll repeat in almost every stack. Targets
the **google** and **google-beta** providers ≥ 6.0 with **Terraform ≥ 1.3**
or **OpenTofu ≥ 1.6**.

---

## Pin in `required_providers`

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

!!! tip "Pin both `google` and `google-beta` to the same version range"
    The two providers ship in lockstep. Mixing versions across them produces
    confusing schema drift.

## Default `google` and `google-beta` providers

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
```

Setting `project`, `region`, and `zone` here means resource blocks don't have
to repeat them. Resources can still override per-resource.

## `user_project_override` and `billing_project`

Some APIs (notably anything fronted by Service Usage, BigQuery, or
"requester-pays" buckets) bill the **caller's** project, not the resource's
project. Set both fields when your auth identity lives in a different
project from the resources you're managing:

```hcl
provider "google" {
  project               = var.project_id
  region                = var.region
  user_project_override = true
  billing_project       = var.billing_project_id
}
```

`user_project_override = true` tells the provider to send
`X-Goog-User-Project: <billing_project>` with each request.

---

## Authentication

### Local development — Application Default Credentials

```bash
gcloud auth application-default login
gcloud config set project acme-platform-dev
```

The provider picks up ADC automatically. No `credentials = ...` argument,
no JSON key on disk.

### CI — Workload Identity Federation (no keys)

In CI, exchange the runner's OIDC token for a short-lived Google token. With
GitHub Actions:

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  apply:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github
          service_account: tf-deployer@acme-platform-prod.iam.gserviceaccount.com
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init
      - run: terraform apply -auto-approve
```

The `auth` action writes credentials to a path in `GOOGLE_APPLICATION_CREDENTIALS`,
and the google provider transparently picks them up.

!!! warning "Don't ship JSON service-account keys"
    Static SA keys are the #1 source of GCP credential leaks. Use ADC
    locally and Workload Identity Federation in CI. See the
    [IAM bindings page](iam-policies.md#workload-identity-federation-for-github-actions)
    for the WIF resource setup.

---

## Provider aliases for multi-project

When one stack manages resources across projects (e.g. shared VPC host +
service projects), declare an aliased provider per project:

```hcl
provider "google" {
  alias   = "host"
  project = var.host_project_id
  region  = var.region
}

provider "google" {
  alias   = "svc_app"
  project = var.app_project_id
  region  = var.region
}

resource "google_compute_subnetwork" "app" {
  provider      = google.host
  name          = "app-subnet"
  ip_cidr_range = "10.10.0.0/20"
  region        = var.region
  network       = google_compute_network.shared.id
}

resource "google_compute_instance" "api" {
  provider     = google.svc_app
  name         = "api"
  machine_type = "e2-medium"
  zone         = var.zone
  # ...
}
```

Modules accept aliased providers via the `providers` argument:

```hcl
module "shared_vpc" {
  source = "./modules/shared-vpc"

  providers = {
    google = google.host
  }

  # ...
}
```

---

## Impersonate a service account

Useful when your human/CI identity has only `roles/iam.serviceAccountTokenCreator`
on a deploy SA, and the deploy SA holds the actual resource permissions:

```hcl
provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = "tf-deploy-prod@acme-platform-prod.iam.gserviceaccount.com"
}
```

Combine with aliases for per-environment impersonation in a single stack:

```hcl
provider "google" {
  alias                       = "prod"
  project                     = "acme-platform-prod"
  region                      = "us-central1"
  impersonate_service_account = "tf-deploy-prod@acme-platform-prod.iam.gserviceaccount.com"
}

provider "google" {
  alias                       = "stg"
  project                     = "acme-platform-stg"
  region                      = "us-central1"
  impersonate_service_account = "tf-deploy-stg@acme-platform-stg.iam.gserviceaccount.com"
}
```

The caller (you, or the CI SA) only needs `roles/iam.serviceAccountTokenCreator`
on each deploy SA — nothing else.

---

## References

- [Terraform Registry: google provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Terraform Registry: google-beta provider](https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs)
- [google provider: Authentication](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#authentication)
- [GCP: Application Default Credentials](https://cloud.google.com/docs/authentication/application-default-credentials)
- [GCP: Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GCP: Service account impersonation](https://cloud.google.com/iam/docs/service-account-impersonation)
- [google-github-actions/auth](https://github.com/google-github-actions/auth)
