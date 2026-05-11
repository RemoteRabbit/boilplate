---
title: Azure
description: Azure-specific Terraform snippets: variables, modules, backends, providers, RBAC.
tags:
  - terraform
  - azure
---

# Azure

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

    azurerm provider defaults: `features {}`, OIDC auth, multi-subscription aliases.

- :material-shield-key:{ .lg .middle } **[RBAC role assignments](iam-policies.md)**

    ---

    Built-in and custom roles, scopes, and federated CI identities.

</div>
