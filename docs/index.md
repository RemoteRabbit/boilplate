---
title: boilplate
description: Copy-paste-ready boilerplate for Terraform, GitHub Actions, containers, Kubernetes, and more.
hide:
  - navigation
---

# boilplate

**Copy-paste-ready boilerplate for the things you keep rewriting.**

This site collects small, opinionated, well-validated snippets you can drop
straight into a project. Everything here is designed to be:

- **Self-contained** — copy a single block and it works.
- **Validated** — variables come with `validation` blocks, types, and sane defaults.
- **Cited** — links back to the upstream docs so you can verify behavior.

---

## Sections

<div class="grid cards" markdown>

- :material-terraform:{ .lg .middle } **Terraform / OpenTofu**

    ---

    Variables, modules, backends, providers, IAM patterns, and Terragrunt.

    [:octicons-arrow-right-24: Browse](terraform/index.md)

- :material-github:{ .lg .middle } **GitHub Actions**

    ---

    Reusable workflows, OIDC, container builds, releases.

    [:octicons-arrow-right-24: Browse](github-actions/index.md)

- :material-docker:{ .lg .middle } **Containers**

    ---

    Multi-stage Dockerfiles, distroless, dev compose stacks.

    [:octicons-arrow-right-24: Browse](containers/index.md)

- :material-kubernetes:{ .lg .middle } **Kubernetes**

    ---

    Deployment baseline, probes, scaling, RBAC, Helm.

    [:octicons-arrow-right-24: Browse](kubernetes/index.md)

- :material-api:{ .lg .middle } **API / Backend**

    ---

    Service skeletons, RFC 7807 errors, pagination, OpenAPI.

    [:octicons-arrow-right-24: Browse](api/index.md)

- :material-database:{ .lg .middle } **Data**

    ---

    Postgres conventions, Alembic, dbt, Airflow.

    [:octicons-arrow-right-24: Browse](data/index.md)

- :material-chart-line:{ .lg .middle } **Observability**

    ---

    Structured logging, OpenTelemetry, Prometheus.

    [:octicons-arrow-right-24: Browse](observability/index.md)

- :material-broom:{ .lg .middle } **Repo hygiene**

    ---

    `.gitignore`, `.editorconfig`, pre-commit, Makefile patterns.

    [:octicons-arrow-right-24: Browse](hygiene/index.md)

</div>

---

!!! note "About the name"
    The repo name `boilplate` is an intentional typo. Don't @ me.
