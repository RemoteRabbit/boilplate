---
title: GCP
description: GCP-specific Terraform snippets: variables, modules, backends, providers, IAM.
tags:
  - terraform
  - gcp
---

# GCP

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

    google provider defaults: project/region, user_project_override, WIF auth, impersonation aliases.

- :material-shield-key:{ .lg .middle } **[IAM policy patterns](iam-policies.md)**

    ---

    Least-privilege snippets you copy more than you'd like to admit.

</div>
