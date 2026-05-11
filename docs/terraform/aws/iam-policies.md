---
title: IAM policy patterns
description: Least-privilege IAM trust and resource policy snippets: GitHub Actions OIDC, cross-account assume-role with ExternalId, S3 TLS-only and encryption-required bucket policies, and a separated KMS key policy.
tags:
  - terraform
  - aws
---

# IAM policy patterns

Copy-pastable least-privilege policies for the things you wire up on every
project: CI/CD federation, cross-account access, locked-down S3 buckets, and
KMS keys with a clean Admin / Use / Grant split.

!!! tip "Prefer `aws_iam_policy_document`"
    Generating JSON via `data "aws_iam_policy_document"` keeps interpolation
    safe (no string-quoting bugs), surfaces typos at `plan` time, and lets you
    reuse statement blocks. Hand-written JSON is fine for small static
    documents.

---

## GitHub Actions OIDC trust

Federate GitHub Actions into AWS without long-lived access keys. The trust
policy below scopes the role to a specific repository, branch (`main`), and
deployment environment (`prod`).

```hcl
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    sid     = "GitHubActionsOIDC"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Repo + ref + environment scoping. Every condition narrows the trust.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:acme-co/platform:ref:refs/heads/main",
        "repo:acme-co/platform:environment:prod",
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = "github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json
}
```

!!! warning "Always pin `sub`, never just `repo:*`"
    A trust policy that only checks `token.actions.githubusercontent.com:aud`
    grants every GitHub Actions workflow on the planet permission to assume
    the role. The `sub` claim must be pinned to your repo plus a branch, tag,
    or environment.

You also need the OIDC provider itself once per account:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub publishes thumbprints: let AWS pick them up automatically since
  # the 2023-07 change. An empty list works on current provider versions.
  thumbprint_list = []
}
```

---

## Cross-account `sts:AssumeRole` with `ExternalId`

Classic third-party / cross-account access. The `ExternalId` defends against
the [confused-deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html)
when the trusted account is shared.

```hcl
variable "trusted_account_id" {
  type        = string
  description = "12-digit AWS account ID allowed to assume this role."
}

variable "external_id" {
  type        = string
  description = "Shared secret presented by the trusted principal on AssumeRole."
  sensitive   = true
}

data "aws_iam_policy_document" "cross_account_trust" {
  statement {
    sid     = "CrossAccountAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.trusted_account_id}:root"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }

    # Optional: require MFA for human users assuming the role.
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "cross_account" {
  name               = "acme-readonly-from-partner"
  assume_role_policy = data.aws_iam_policy_document.cross_account_trust.json
}
```

The rendered JSON looks like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CrossAccountAssumeRole",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": { "AWS": "arn:aws:iam::222233334444:root" },
      "Condition": {
        "StringEquals": { "sts:ExternalId": "REDACTED" },
        "Bool":         { "aws:MultiFactorAuthPresent": "true" }
      }
    }
  ]
}
```

---

## S3 bucket policy: TLS-only + require encrypted PUTs

Two statements every S3 bucket should carry: deny any request that wasn't
made over HTTPS, and deny any `PutObject` that doesn't ask for server-side
encryption.

```hcl
data "aws_iam_policy_document" "bucket_hardening" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid     = "DenyUnencryptedPut"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms", "AES256"]
    }
  }

  statement {
    sid     = "DenyMissingEncryptionHeader"
    effect  = "Deny"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["true"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket_hardening.json
}
```

!!! note "Two statements for the encryption check"
    `StringNotEquals` only fires when the header is *present and wrong*. To
    also catch requests that omit the header entirely you need the second
    `Null`-conditioned statement.

---

## KMS key policy: Admin / Use / Grant separation

A common mistake is granting `kms:*` to the root principal and calling it a
day. Splitting the policy into three roles: **administer**, **use**, and
**grant**. Makes audits actually possible.

```hcl
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "kms_key" {
  # 1) Root account retains break-glass control over the key.
  statement {
    sid     = "EnableIAMUserPermissions"
    effect  = "Allow"
    actions = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  # 2) Admins: rotate, schedule deletion, edit policy. NO data plane.
  statement {
    sid    = "KeyAdministration"
    effect = "Allow"

    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.key_admin_role_arns
    }
  }

  # 3) Users: encrypt/decrypt data, but cannot change the key itself.
  statement {
    sid    = "KeyUsage"
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.key_user_role_arns
    }
  }

  # 4) Grants: AWS services (RDS, EBS, etc.) need to create grants on behalf
  #    of users. Scoped with ViaService so an Allow on kms:CreateGrant alone
  #    can't be used outside the integrated services.
  statement {
    sid    = "AllowAttachmentOfPersistentResources"
    effect = "Allow"

    actions = [
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]

    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = var.key_user_role_arns
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_kms_key" "this" {
  description             = "App data encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_key.json
}
```

!!! warning "Don't drop the root statement"
    AWS will let you save a key policy without the root principal: and then
    nobody can edit it again. The "EnableIAMUserPermissions" statement is
    your one and only break-glass. Keep it.

---

## References

- [AWS: Configuring OIDC for GitHub Actions](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [AWS: The confused deputy problem and ExternalId](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html)
- [AWS: Bucket policy examples: require HTTPS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/example-bucket-policies.html#example-bucket-policies-secure-transport)
- [AWS: Protecting data with SSE-KMS](https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html)
- [AWS: Key policies in AWS KMS](https://docs.aws.amazon.com/kms/latest/developerguide/key-policies.html)
- [Terraform: `aws_iam_policy_document` data source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document)
