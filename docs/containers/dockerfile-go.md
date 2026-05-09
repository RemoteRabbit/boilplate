---
title: Go — static binary, distroless
status: stub
---

# Go — static binary, distroless

!!! note "Stub page"
    Single-binary Go services in a tiny image.

## Planned content

- `CGO_ENABLED=0`, `-trimpath`, `-ldflags=-s -w`
- Distroless static or scratch base
- Build cache mounts (`--mount=type=cache,target=/root/.cache/go-build`)
