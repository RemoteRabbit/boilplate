---
title: Remote state backends
description: S3 remote state for Terraform / OpenTofu with native S3 locking, KMS encryption, versioning, and a bootstrap pattern for the chicken-and-egg state bucket.
tags:
  - terraform
  - aws
---

# Remote state backends

A production-ready remote state setup on AWS with **S3 native locking**
(`use_lockfile`, Terraform 1.10+), **server-side encryption with KMS**, and
**bucket versioning** so you can recover from a corrupted or accidentally
truncated state file.

!!! tip "Skip DynamoDB on new projects"
    As of Terraform **1.10**, the S3 backend supports a native `.tflock` file
    in the same bucket via `use_lockfile = true`. New projects no longer need a
    DynamoDB lock table. The legacy option is still documented at the bottom
    of this page for existing setups.

---

## Backend block

A complete `backend "s3"` block with native locking and KMS encryption:

```hcl
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "acme-tfstate-prod-us-east-1"
    key          = "platform/network/terraform.tfstate"
    region       = "us-east-1"

    # Native S3 locking (Terraform 1.10+). No DynamoDB table required.
    use_lockfile = true

    # SSE-KMS with a customer-managed key.
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:111122223333:key/aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"

    # Optional: assume a deploy role from CI/CD.
    assume_role = {
      role_arn     = "arn:aws:iam::111122223333:role/terraform-deploy"
      session_name = "terraform"
    }
  }
}
```

!!! note "Pick a deterministic state key"
    The `key` is the path of the state file inside the bucket. Use a stable
    layout like `<system>/<component>/<env>/terraform.tfstate` so renaming a
    workspace never silently creates a fresh state file.

---

## Partial configuration (recommended)

Hard-coding the bucket name, region, and key in `backend "s3"` makes a module
hard to reuse across environments. Leave the block empty and pass the values
at `init` time with `-backend-config`:

```hcl
terraform {
  required_version = ">= 1.10.0"
  backend "s3" {}
}
```

Then in CI / the repo root, per environment:

```bash
terraform init \
  -backend-config="bucket=acme-tfstate-prod-us-east-1" \
  -backend-config="key=platform/network/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="kms_key_id=arn:aws:kms:us-east-1:111122223333:key/aaaa..." \
  -backend-config="use_lockfile=true" \
  -backend-config="encrypt=true"
```

Or with a per-env file:

```bash
terraform init -backend-config=envs/prod/backend.hcl
```

```hcl
# envs/prod/backend.hcl
bucket       = "acme-tfstate-prod-us-east-1"
key          = "platform/network/terraform.tfstate"
region       = "us-east-1"
kms_key_id   = "arn:aws:kms:us-east-1:111122223333:key/aaaa..."
use_lockfile = true
encrypt      = true
```

---

## Bootstrapping the state bucket (chicken-and-egg)

The state bucket itself can't live in the state file it stores. The
conventional fix is a small **bootstrap module** that:

1. Runs once with a *local* backend.
2. Creates the bucket, KMS key, and (optionally) the legacy DynamoDB table.
3. Is then re-initialised with the new S3 backend, so it manages itself going
   forward.

```hcl
# bootstrap/main.tf
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_kms_key" "tfstate" {
  description             = "Encrypts Terraform state in S3"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/tfstate"
  target_key_id = aws_kms_key.tfstate.key_id
}

resource "aws_s3_bucket" "tfstate" {
  bucket = var.bucket_name

  # Belt and braces: never let someone delete this by accident.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

After the first `terraform apply` with a local backend, add the
`backend "s3" {}` block, run:

```bash
terraform init -migrate-state
```

…and Terraform will copy the local state into the bucket it just created. If
the bootstrap module needs to manage *its own* state going forward, also
import the bucket and KMS key into the new state though many teams treat
the bootstrap state as a one-shot artifact and check it into a private
repository instead.

!!! warning "`prevent_destroy` is mandatory here"
    Losing the state bucket means rebuilding every state file from scratch.
    Combine `prevent_destroy = true` with bucket versioning and an MFA-delete
    policy in production.

---

## Legacy: S3 + DynamoDB locking

If you're on Terraform < 1.10, or your org still mandates a DynamoDB lock
table, the classic configuration looks like this:

```hcl
terraform {
  backend "s3" {
    bucket         = "acme-tfstate-prod-us-east-1"
    key            = "platform/network/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:111122223333:key/aaaa..."
    dynamodb_table = "terraform-locks"
  }
}
```

The lock table needs a single string hash key named `LockID`:

```hcl
resource "aws_dynamodb_table" "tflocks" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
```

!!! tip "Migrating off DynamoDB"
    On Terraform 1.10+ you can set both `use_lockfile = true` and
    `dynamodb_table = "..."` during a transition window, then drop the
    DynamoDB table once every workspace has been re-initialised.

---

## References

- [Terraform: S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform 1.10 release notes: S3 native locking](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
- [OpenTofu: S3 backend](https://opentofu.org/docs/language/settings/backends/s3/)
- [AWS: Protecting data with server-side encryption (SSE-KMS)](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)
- [AWS: Using versioning in S3 buckets](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html)
