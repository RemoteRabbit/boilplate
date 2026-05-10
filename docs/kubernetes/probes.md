---
title: Probes done right
description: Liveness, readiness, and startup probes done right — common mistakes and fixes.
status: stub
tags:
  - kubernetes
---

# Probes done right

!!! note "Stub page"
    The single most misunderstood K8s feature. Liveness ≠ readiness ≠ startup.

## Planned content

- Startup probe: when your app is slow to boot
- Readiness probe: 'should I receive traffic?'
- Liveness probe: 'should I be killed?' (and when NOT to use it)
- Common anti-patterns (DB checks in liveness, etc.)
