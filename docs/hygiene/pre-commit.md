---
title: pre-commit configs
description: Starter .pre-commit-config.yaml with general, language-specific, and project-local hooks.
tags:
  - hygiene
  - pre-commit
---

# pre-commit configs

[pre-commit](https://pre-commit.com/) runs hooks on staged files before each
commit. Pin every repo by `rev:` so hook versions are reproducible.

```bash
uv tool install pre-commit       # or: pipx install pre-commit
pre-commit install                # install the git hook
pre-commit install --hook-type commit-msg   # for commit-msg hooks
pre-commit run --all-files        # run against the whole repo
pre-commit autoupdate             # bump rev pins to latest tags
```

## General hooks

The `pre-commit-hooks` repo gives you the boring, universal stuff.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-added-large-files
        args: [--maxkb=500]
      - id: mixed-line-ending
        args: [--fix=lf]
      - id: check-yaml
        args: [--unsafe]   # allow !!python/name: tags (MkDocs Material, etc.)
      - id: check-toml
      - id: check-json
```

## Spelling

```yaml
  - repo: https://github.com/codespell-project/codespell
    rev: v2.3.0
    hooks:
      - id: codespell
        additional_dependencies: ["tomli"]
```

Configure in `pyproject.toml`:

```toml
[tool.codespell]
skip = "*.lock,./site,./.venv"
ignore-words-list = "te,nd"
```

## Conventional commits

Enforce [Conventional Commits](https://www.conventionalcommits.org/) on the
commit message itself.

```yaml
  - repo: https://github.com/compilerla/conventional-pre-commit
    rev: v3.6.0
    hooks:
      - id: conventional-pre-commit
        stages: [commit-msg]
        args: [feat, fix, chore, docs, refactor, test, ci, build, perf, style, ops]
```

## Snippet sync

[`pre-commit-snippets`](https://github.com/RemoteRabbit/pre-commit-snippets)
keeps shared markdown blocks in sync from a central snippet repo. Wrap a region
in your docs with `<!-- SNIPPET-START: name -->` / `<!-- SNIPPET-END -->`
markers and the hook replaces the contents with `name.md` from the configured
snippet repo on every commit.

```yaml
  - repo: https://github.com/RemoteRabbit/pre-commit-snippets
    rev: v1.0.4
    hooks:
      - id: snippet-sync
```

Then add `.pre-commit-snippets-config.yaml` at the repo root:

```yaml
snippet_repo: https://github.com/your-org/snippets.git
snippet_branch: main
snippet_subdir: snippets
snippet_ext: .md
cache_path: .snippet-hashes.json
target_files:
  - README.md
  - docs/CONTRIBUTING.md
```

In any `target_files`:

```markdown
# My Project

<!-- SNIPPET-START: license-notice -->
This block is replaced with the contents of `license-notice.md` from the snippet repo.
<!-- SNIPPET-END -->
```

!!! tip "Why use it"
    Useful when you have boilerplate (license blurbs, contributing guides,
    security policy) that should be identical across many repos. The hook
    auto-stages updated files, so drift is caught at commit time.

## Python (ruff + mypy)

```yaml
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.7.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.13.0
    hooks:
      - id: mypy
        additional_dependencies: ["types-requests"]
```

## Terraform / OpenTofu

```yaml
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.1
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
      - id: terraform_docs
        args:
          - --hook-config=--path-to-file=README.md
          - --hook-config=--add-to-existing-file=true
          - --hook-config=--create-file-if-not-exist=true
```

## Local hooks

For project-specific checks that don't warrant their own repo:

```yaml
  - repo: local
    hooks:
      - id: zensical-build
        name: zensical build
        entry: uv run zensical build
        language: system
        pass_filenames: false
        files: ^(docs/|zensical\.toml|pyproject\.toml)

      - id: lychee
        name: lychee link check
        entry: lychee --config lychee.toml --cache --max-cache-age 7d --no-progress
        language: system
        pass_filenames: true
        files: \.md$
```

!!! warning "`language: system` requires the binary on PATH"
    `system` hooks won't be installed for you: make sure `uv`, `lychee`, etc.
    are available in CI and locally, or use `language: python` /
    `language: docker` / `language: golang` to let pre-commit manage them.

## References

- [pre-commit homepage](https://pre-commit.com/)
- [pre-commit-hooks](https://github.com/pre-commit/pre-commit-hooks)
- [pre-commit-snippets](https://github.com/RemoteRabbit/pre-commit-snippets)
- [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform)
- [Conventional Commits](https://www.conventionalcommits.org/)
