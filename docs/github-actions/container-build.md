---
title: Container build & push
description: Build and push container images with cache, multi-arch, and SBOM via GitHub Actions.
status: stub
tags:
  - github-actions
  - docker
---

# Container build & push

!!! note "Stub page"
    Build a multi-arch image, push to GHCR, sign with cosign.

## Planned content

- `docker/setup-buildx-action` + `docker/build-push-action` with cache
- Multi-arch via `platforms: linux/amd64,linux/arm64` + QEMU
- GHCR auth via `GITHUB_TOKEN`
- Cosign keyless signing
