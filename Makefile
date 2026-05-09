# boilplate — local dev convenience targets
# Run `make help` to see what's available.
#
# All Python work is done through `uv`, which manages the .venv automatically.
# Install uv: https://docs.astral.sh/uv/getting-started/installation/

UV         ?= uv
PORT       ?= 8000
VENV       := .venv
RUN        := $(UV) run

.DEFAULT_GOAL := help

# ---- meta ------------------------------------------------------------------

.PHONY: help
help: ## Show this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: \033[36mmake <target>\033[0m\n\nTargets:\n"} \
		/^[a-zA-Z0-9_.-]+:.*##/ { printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

.PHONY: check-uv
check-uv:
	@command -v $(UV) >/dev/null 2>&1 || { \
		echo "error: 'uv' is not installed."; \
		echo "       install it from https://docs.astral.sh/uv/getting-started/installation/"; \
		exit 1; \
	}

# ---- environment -----------------------------------------------------------

$(VENV): pyproject.toml
	$(UV) sync
	@touch $(VENV)

.PHONY: install
install: check-uv $(VENV) ## Create .venv and install all dependencies (incl. dev).

.PHONY: lock
lock: check-uv ## Refresh uv.lock from pyproject.toml.
	$(UV) lock

.PHONY: upgrade
upgrade: check-uv ## Upgrade all dependencies to the latest allowed versions.
	$(UV) lock --upgrade
	$(UV) sync

# ---- docs ------------------------------------------------------------------

.PHONY: serve
serve: install ## Run the docs site locally with live reload (http://localhost:$(PORT)).
	$(RUN) zensical serve -a 0.0.0.0:$(PORT)

.PHONY: build
build: install ## Build the static site into ./site (strict mode).
	$(RUN) zensical build --strict

.PHONY: links
links: ## Run lychee link checker against docs/ and README. Requires lychee in PATH.
	@command -v lychee >/dev/null 2>&1 || { \
		echo "error: 'lychee' is not installed."; \
		echo "       install it from https://lychee.cli.rs/installation/"; \
		exit 1; \
	}
	lychee --config lychee.toml --cache --max-cache-age 7d 'docs/**/*.md' README.md

# ---- quality ---------------------------------------------------------------

.PHONY: md-lint
md-lint: ## Lint Markdown with markdownlint-cli2 (uses .markdownlint.yaml). Requires npx.
	@command -v npx >/dev/null 2>&1 || { \
		echo "error: 'npx' is not installed (install Node.js)."; \
		exit 1; \
	}
	npx --yes markdownlint-cli2 "docs/**/*.md" "README.md"

.PHONY: md-fmt
md-fmt: ## Auto-fix Markdown with markdownlint-cli2 --fix (safe with MkDocs Material syntax).
	@command -v npx >/dev/null 2>&1 || { \
		echo "error: 'npx' is not installed (install Node.js)."; \
		exit 1; \
	}
	npx --yes markdownlint-cli2 --fix "docs/**/*.md" "README.md"

.PHONY: hooks
hooks: install ## Install pre-commit git hooks.
	$(RUN) pre-commit install

.PHONY: pre-commit
pre-commit: install ## Run all pre-commit hooks against every file.
	$(RUN) pre-commit run --all-files

# ---- housekeeping ----------------------------------------------------------

.PHONY: clean
clean: ## Remove build artifacts and the virtualenv.
	rm -rf site $(VENV) .ruff_cache .cache

.PHONY: clean-site
clean-site: ## Remove only the built site.
	rm -rf site
