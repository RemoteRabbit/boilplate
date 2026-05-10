# Contributing

This is primarily a personal stash of boilerplate I keep rewriting, published
in the small chance someone else finds it useful.

PRs are welcome but not actively solicited. If you spot a bug or want to add a
snippet, feel free to open an issue or PR just keep in mind I'll prioritize
based on whether I'd use it myself.

## Local setup

See [README.md](README.md) it covers `uv`, `make install`, and the local
dev loop.

## Conventions

- **Conventional Commits** for commit messages (enforced via `pre-commit` on
  the `commit-msg` hook). Allowed types are configured in
  [`.pre-commit-config.yaml`](.pre-commit-config.yaml).
- **Run `make pre-commit`** before pushing. CI runs the same hooks plus a
  strict Zensical build.
- **Snippets should be self-contained** copy a single block and it works.
  Cite the upstream docs at the bottom of every page.
- **Validate variables**. New Terraform variable blocks should follow the
  pattern in [`docs/terraform/aws/variables.md`](docs/terraform/aws/variables.md):
  type, description, sensible default (or `nullable = true`), and a
  `validation` block with a complete-sentence `error_message`.

## Reporting issues

Open a GitHub issue with:

- The page URL or path
- What's wrong (typo, broken link, outdated example, missing context)
- Optionally a suggested fix

## License

By contributing you agree your changes will be released under the project's
[GPL-3.0 license](LICENSE).
