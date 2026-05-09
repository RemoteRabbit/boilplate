# boilplate

Copy-paste-ready boilerplate for the things I keep rewriting. Published as a
small docs site at:

**https://remoterabbit.github.io/boilplate/**

> The repo name is an intentional typo. Don't @ me.

## Layout

| Path                              | What it is                                                                          |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| `docs/`                           | Markdown content for the site.                                                      |
| `mkdocs.yml`                      | [MkDocs Material](https://squidfunk.github.io/mkdocs-material/) site configuration. |
| `pyproject.toml` / `uv.lock`      | Python project + locked dependencies (managed by [`uv`](https://docs.astral.sh/uv)).|
| `.pre-commit-config.yaml`         | [pre-commit](https://pre-commit.com/) hooks (ruff, hygiene, strict mkdocs build).   |
| `Makefile`                        | Convenience targets — run `make help`.                                              |
| `terragrunt/`                     | Working Terragrunt example referenced by the docs *(WIP — being modernized)*.       |
| `.github/workflows/`              | `ci.yml` (PR checks) and `deploy.yml` (Pages deploy on push to `main`).             |

## Local development

Requires [`uv`](https://docs.astral.sh/uv/getting-started/installation/) (which
manages Python versions and the virtual env for you). Everything else is wired
through the Makefile:

```sh
make install      # uv sync — create .venv and install deps
make hooks        # install pre-commit git hooks (one-time)
make serve        # live-reload dev server at http://localhost:8000
make build        # strict production build into ./site
make pre-commit   # run all pre-commit hooks against every file
make lint         # ruff lint
make format       # ruff format + autofix
make clean        # nuke ./site, ./.venv, caches
```

## Deployment

Pushes to `main` that touch `docs/`, `mkdocs.yml`, `pyproject.toml`, or
`uv.lock` trigger [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml),
which builds the site with `mkdocs build --strict` and publishes via GitHub Pages.

One-time setup in the repo settings:

1. **Settings → Pages → Build and deployment → Source**: *GitHub Actions*.

## Adding new boilerplate

1. Add a Markdown file under `docs/<topic>/`.
2. Reference it in the `nav:` block in [`mkdocs.yml`](mkdocs.yml).
3. Open a PR. CI runs pre-commit + a strict build; merging to `main` deploys.
