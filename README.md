# boilplate

A personal stash of copy-paste-ready snippets for things I keep rewriting —
Terraform/Terragrunt, GitHub Actions, containers, Kubernetes, Postgres, and so
on. Built primarily for me, but published in case anyone else finds bits of it
useful:

**<https://remoterabbit.github.io/boilplate/>**

> The repo name is an intentional typo. Don't @ me.
>
> Stub pages exist for sections I haven't written up yet. They'll get filled
> in as I need them.

## Layout

| Path                         | What it is                                                                                                     |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `docs/`                      | Markdown content for the site (front-matter has `title`, `description`, `tags`).                               |
| `zensical.toml`              | [Zensical](https://zensical.org/) site configuration (the new SSG by the Material team).                       |
| `pyproject.toml` / `uv.lock` | Python project + locked deps (managed by [`uv`](https://docs.astral.sh/uv)).                                   |
| `.pre-commit-config.yaml`    | [pre-commit](https://pre-commit.com/) hooks (hygiene + `zensical build` + lychee).                             |
| `lychee.toml`                | [lychee](https://lychee.cli.rs/) link-checker config (used by pre-commit and CI).                              |
| `.editorconfig`              | Whitespace defaults across editors.                                                                            |
| `Makefile`                   | Convenience targets — run `make help`.                                                                         |
| `terragrunt/`                | Working Terragrunt example referenced by the docs *(WIP — being modernized)*.                                  |
| `.github/workflows/`         | `ci.yml` (PR checks), `deploy.yml` (Pages deploy on push to `main`), `links.yml` (lychee on PR + weekly cron). |

## Local development

Requires [`uv`](https://docs.astral.sh/uv/getting-started/installation/) (which
manages Python versions and the virtual env). Everything else goes through the
Makefile:

```sh
make install      # uv sync — create .venv and install deps
make hooks        # install pre-commit git hooks (one-time)
make serve        # live-reload dev server at http://localhost:8000
make build        # build site into ./site
make links        # run lychee link checker locally
make md-lint      # markdownlint-cli2 (requires npx)
make md-fmt       # markdownlint-cli2 --fix
make pre-commit   # run all pre-commit hooks against every file
make clean        # nuke ./site, ./.venv, caches
```

## Deployment

Pushes to `main` that touch `docs/`, `zensical.toml`, `pyproject.toml`, or
`uv.lock` trigger [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml),
which runs `zensical build` and publishes the result via GitHub Pages.

One-time setup in the repo settings:

1. **Settings → Pages → Build and deployment → Source**: *GitHub Actions*.

## Adding new boilerplate

1. Add a Markdown file under `docs/<topic>/`.
2. Reference it in the `nav` block in [`zensical.toml`](zensical.toml).
3. Add front-matter, including `tags:` (block-style YAML — flow-style
   `[a, b]` collides with Zensical's reference-link parser):

   ```yaml
   ---
   title: Something useful
   description: One-liner that shows in <head> and search results.
   tags:
     - terraform
     - aws
   ---
   ```

4. Open a PR. CI runs pre-commit + the build; merging to `main` deploys.

## A note on Zensical

This site originally ran on [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/);
it now runs on [Zensical](https://zensical.org/), the team's new SSG. Zensical
is currently alpha, so the dependency is pinned to an exact version
(see [`pyproject.toml`](pyproject.toml)) and bumped deliberately.
