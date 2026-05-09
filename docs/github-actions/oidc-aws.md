---
title: OIDC → AWS (no static keys)
status: stub
---

# OIDC → AWS (no static keys)

!!! note "Stub page"
    GitHub Actions assuming an AWS role via OIDC. The trust policy people get wrong.

## Planned content

- IAM identity provider creation (one-time per account)
- IAM role with sub-claim conditions: branch, environment, tag, PR
- `aws-actions/configure-aws-credentials` invocation
- Common 'Not authorized' debugging — what to check
