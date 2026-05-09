---
title: Python — multi-stage with uv
status: stub
tags:
  - docker
  - python
---

# Python — multi-stage with uv

!!! note "Stub page"
    Small, reproducible Python images using uv for dependency install.

## Planned content

- Builder stage: uv sync into /app/.venv
- Runtime stage: distroless or python:slim with non-root user
- Cache mounts for uv cache
- When to vendor wheels vs install at build
