---
title: Go — static binary, distroless
description: Multi-stage Dockerfile producing a static Go binary on a distroless runtime.
status: stub
tags:
  - docker
  - go
---

# Go — static binary, distroless

!!! note "Stub page"
    Single-binary Go services in a tiny image.

## Planned content

- `CGO_ENABLED=0`, `-trimpath`, `-ldflags=-s -w`
- Distroless static or scratch base
- Build cache mounts (`--mount=type=cache,target=/root/.cache/go-build`)
