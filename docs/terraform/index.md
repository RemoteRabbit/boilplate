---
title: Terraform / OpenTofu
---

# Terraform / OpenTofu

Snippets here work with both [Terraform](https://developer.hashicorp.com/terraform)
≥ 1.3 and [OpenTofu](https://opentofu.org/) ≥ 1.6 unless noted otherwise.

## Pages

<div class="grid cards" markdown>

- :material-variable:{ .lg .middle } **[Common variables](variables.md)**

    ---

    Typed, validated `variable` blocks: environment, region, tags, CIDRs,
    instance type, FQDN, optionals, objects, secrets.

- :material-folder-multiple:{ .lg .middle } **[Module skeleton](module-skeleton.md)**

    ---

    Opinionated layout for a reusable module.

- :material-database-export:{ .lg .middle } **[Backends](backends.md)**

    ---

    Remote state backends with locking and encryption.

- :material-cog:{ .lg .middle } **[Provider configuration](providers.md)**

    ---

    Sensible defaults for AWS, GCP, Azure providers.

- :material-shield-key:{ .lg .middle } **[IAM policy patterns](iam-policies.md)**

    ---

    Least-privilege snippets you copy more than you'd like to admit.

</div>
