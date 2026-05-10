---
title: Postgres schema conventions
description: Postgres naming, schema, and constraint conventions for long-lived databases.
status: stub
tags:
  - data
  - postgres
---

# Postgres schema conventions

!!! note "Stub page"
    Column, naming, and typing conventions you set on day one and never revisit.

## Planned content

- Primary keys: UUID v7 vs identity vs serial — when each wins
- Audit columns: created_at / updated_at / created_by + trigger
- Soft delete: deleted_at vs separate archive table
- Naming: snake_case, plural tables, FK suffix
