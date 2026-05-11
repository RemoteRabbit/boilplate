---
title: IAM bindings & custom roles
description: GCP IAM in Terraform: additive vs authoritative bindings, custom roles, Workload Identity Federation for GitHub Actions, and service-account impersonation.
tags:
  - terraform
  - gcp
---

# IAM bindings & custom roles

GCP IAM in Terraform comes in **three flavours**, and picking the wrong one
will silently wipe other teams' access. Read this page before you reach for
`google_*_iam_policy`.

---

## `_iam_member` vs `_iam_binding` vs `_iam_policy`

| Resource family        | Scope                                       | Authoritative?     | Safe default?                         |
| ---------------------- | ------------------------------------------- | ------------------ | ------------------------------------- |
| `google_*_iam_member`  | Single (role, member) pair                  | No (additive)      | ✅ Yes                                |
| `google_*_iam_binding` | Whole role (all members for that one role)  | Yes (for the role) | ⚠️ Only if Terraform owns *that role* |
| `google_*_iam_policy`  | The entire resource's IAM policy            | Yes (total)        | ❌ Almost never                       |

!!! warning "`google_project_iam_policy` is destructive"
    `google_project_iam_policy` overwrites **every** binding on the project,
    including the default `roles/owner` granted to the project creator and
    any access set up by other tools. Use `google_project_iam_member` unless
    you have a deliberate reason not to.

### Additive (recommended default)

```hcl
resource "google_project_iam_member" "deployer_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.tf_deployer.email}"
}
```

### Authoritative on a single role

Use when Terraform is the source of truth for *who* holds a role:

```hcl
resource "google_project_iam_binding" "owners" {
  project = var.project_id
  role    = "roles/owner"

  members = [
    "group:platform-admins@acme.com",
  ]
}
```

Anything else previously holding `roles/owner` (a person, an SA, a Google
group) will be removed on the next apply.

### Authoritative on the whole project

```hcl
# Don't do this unless you really mean it.
data "google_iam_policy" "project" {
  binding {
    role    = "roles/owner"
    members = ["group:platform-admins@acme.com"]
  }
  binding {
    role    = "roles/viewer"
    members = ["group:engineers@acme.com"]
  }
}

resource "google_project_iam_policy" "project" {
  project     = var.project_id
  policy_data = data.google_iam_policy.project.policy_data
}
```

If you forget to include a binding here, it disappears.

!!! tip "Conditional bindings"
    Use `condition { ... }` on `_iam_member` to scope grants by time, request
    attribute, or resource name (CEL syntax). Great for "this SA can read
    only buckets prefixed `staging-`".

---

## Custom roles

When the predefined roles are too broad, define a custom role with the exact
permissions you need:

```hcl
resource "google_project_iam_custom_role" "state_reader" {
  project     = var.project_id
  role_id     = "tfstateReader"
  title       = "Terraform state reader"
  description = "Read-only access to Terraform state objects in GCS."
  stage       = "GA"

  permissions = [
    "storage.buckets.get",
    "storage.objects.get",
    "storage.objects.list",
  ]
}

resource "google_project_iam_member" "ci_state_reader" {
  project = var.project_id
  role    = google_project_iam_custom_role.state_reader.name
  member  = "serviceAccount:${google_service_account.ci_planner.email}"
}
```

Custom roles can also be defined at the organisation level
(`google_organization_iam_custom_role`) when the same role is reused across
many projects.

---

## Workload Identity Federation for GitHub Actions

Trade GitHub's OIDC token for a short-lived Google access token, no
service-account JSON keys.

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

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
    "attribute.environment"      = "assertion.environment"
  }

  # Reject tokens from forks or other orgs.
  attribute_condition = "assertion.repository_owner == 'acme-co'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "tf_deployer" {
  project      = var.project_id
  account_id   = "tf-deployer"
  display_name = "Terraform deployer"
}

# Only allow the acme-co/infra repo to impersonate this SA via WIF.
resource "google_service_account_iam_member" "tf_deployer_wif" {
  service_account_id = google_service_account.tf_deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/acme-co/infra"
}
```

The `principalSet://...` member maps to the `attribute.*` you mapped above.
Common variants:

| Scope                              | Member                                                                                              |
| ---------------------------------- | --------------------------------------------------------------------------------------------------- |
| Whole repo                         | `principalSet://iam.googleapis.com/POOL/attribute.repository/acme-co/infra`                         |
| One environment                    | `principalSet://iam.googleapis.com/POOL/attribute.environment/prod`                                 |
| One ref (e.g. `refs/heads/main`)   | `principalSet://iam.googleapis.com/POOL/attribute.ref/refs/heads/main`                              |

---

## Service-account impersonation pattern

Even with WIF, the cleanest pattern is:

1. CI authenticates as a **bootstrap SA** (or directly via WIF) with no
   resource permissions of its own.
2. CI then *impersonates* an **environment-specific deploy SA** that holds
   the project-level roles.

```hcl
resource "google_service_account" "deploy_prod" {
  project      = var.project_id
  account_id   = "tf-deploy-prod"
  display_name = "Terraform deploy SA (prod)"
}

# CI bootstrap SA can mint tokens for the prod deploy SA.
resource "google_service_account_iam_member" "ci_can_impersonate_prod" {
  service_account_id = google_service_account.deploy_prod.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.tf_deployer.email}"
}
```

Then point the provider at the impersonated SA:

```hcl
provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = google_service_account.deploy_prod.email
}
```

This gives you a clear, auditable boundary: WIF says *who's calling*, the
deploy SA says *what they can do*, and rotating one doesn't disturb the other.

---

## References

- [google_project_iam_*][gpi-resources]: member vs binding vs policy
- [google_project_iam_custom_role][gpi-custom-role]
- [google_iam_workload_identity_pool][wif-pool]
- [google_iam_workload_identity_pool_provider][wif-provider]
- [GCP: Workload Identity Federation with GitHub][wif-github]
- [GCP: Service account impersonation](https://cloud.google.com/iam/docs/service-account-impersonation)
- [GCP: Understanding custom roles](https://cloud.google.com/iam/docs/understanding-custom-roles)

[gpi-resources]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam
[gpi-custom-role]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_iam_custom_role
[wif-pool]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool
[wif-provider]: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iam_workload_identity_pool_provider
[wif-github]: https://cloud.google.com/iam/docs/workload-identity-federation-with-deployment-pipelines
