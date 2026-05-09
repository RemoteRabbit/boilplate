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
	$(RUN) mkdocs serve -a 0.0.0.0:$(PORT)

.PHONY: build
build: install ## Build the static site into ./site (strict mode + htmlproofer).
	$(RUN) mkdocs build --strict

.PHONY: links
links: ## Run lychee link checker against docs/ and README. Requires lychee in PATH.
	@command -v lychee >/dev/null 2>&1 || { \
		echo "error: 'lychee' is not installed."; \
		echo "       install it from https://lychee.cli.rs/installation/"; \
		exit 1; \
	}
	lychee --config lychee.toml --cache --max-cache-age 7d 'docs/**/*.md' README.md

# ---- quality ---------------------------------------------------------------

.PHONY: lint
lint: install ## Run ruff lint.
	$(RUN) ruff check .

.PHONY: format
format: install ## Format Python files with ruff.
	$(RUN) ruff format .
	$(RUN) ruff check --fix .

.PHONY: hooks
hooks: install ## Install pre-commit git hooks.
	$(RUN) pre-commit install

.PHONY: pre-commit
pre-commit: install ## Run all pre-commit hooks against every file.
	$(RUN) pre-commit run --all-files

# ---- terraform / opentofu --------------------------------------------------

.PHONY: tf-fmt
tf-fmt: ## Format all Terraform / OpenTofu files in-tree.
	@command -v terraform >/dev/null 2>&1 && terraform fmt -recursive terragrunt || \
		(command -v tofu >/dev/null 2>&1 && tofu fmt -recursive terragrunt) || \
		(echo "neither terraform nor tofu is installed" >&2; exit 1)

.PHONY: tg-fmt
tg-fmt: ## Format all Terragrunt HCL files in-tree.
	@command -v terragrunt >/dev/null 2>&1 || (echo "terragrunt is not installed" >&2; exit 1)
	terragrunt hcl format

# ---- housekeeping ----------------------------------------------------------

.PHONY: clean
clean: ## Remove build artifacts and the virtualenv.
	rm -rf site $(VENV) .ruff_cache .cache

.PHONY: clean-site
clean-site: ## Remove only the built site.
	rm -rf site
