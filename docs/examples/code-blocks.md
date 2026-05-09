---
title: Code block features
description: Live demo of every code-block feature available on this site — syntax highlighting, titles, line numbers, line highlighting, annotations, diffs, tabs.
---

# Code block features

A live tour of every code-block feature the site supports. Use this page as a
reference when authoring boilerplate. Delete it whenever you don't want it
anymore — it lives at [`docs/examples/code-blocks.md`][src] and is referenced
in `nav:` only.

---

## 1. Plain syntax highlighting

A normal fenced block with a language hint:

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment must be one of: dev, stg, prod."
  }
}
```

````markdown
```hcl
variable "environment" {
  type = string
  ...
}
```
````

Pygments handles every common language. Some samples:

```python
from pydantic import BaseModel, Field

class User(BaseModel):
    id: int
    email: str = Field(pattern=r"^[^@]+@[^@]+$")
```

```go
func Healthz(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    _, _ = w.Write([]byte(`{"status":"ok"}`))
}
```

```sql
SELECT id, email, created_at
FROM users
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 50;
```

```dockerfile
FROM python:3.12-slim AS runtime
COPY --from=builder /app/.venv /app/.venv
USER 1000:1000
ENTRYPOINT ["/app/.venv/bin/uvicorn", "app:app"]
```

---

## 2. Title (filename) header

Add `title="..."` to put a header bar above the block:

```hcl title="variables.tf"
variable "project" {
  description = "Short project identifier."
  type        = string
}
```

````markdown
```hcl title="variables.tf"
variable "project" { … }
```
````

---

## 3. Line numbers

Add `linenums="1"` (the number is the starting line):

```python title="app/main.py" linenums="1"
from fastapi import FastAPI

app = FastAPI()


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}
```

Click any line number to copy a permalink to that exact line.

---

## 4. Highlighted lines

Add `hl_lines="3 5-7"` to subtly highlight a single line and a range:

```hcl title="main.tf" linenums="1" hl_lines="3 5-7"
resource "aws_s3_bucket" "logs" {
  bucket        = "${var.project}-logs"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
```

````markdown
```hcl title="main.tf" linenums="1" hl_lines="3 5-7"
…
```
````

---

## 5. Code annotations (numbered popovers)

The single most useful feature for boilerplate. Two things are required:

1. The fence must use the **brace header** form with `.annotate` added:
   ` ``` { .hcl .annotate title="vpc.tf" linenums="1" } `
2. Inside the code, drop `# (1)!` (or `// (1)!`, `-- (1)!`,
   `<!-- (1)! -->`, etc.) on whichever line you want to annotate, then add a
   numbered list immediately after the closing fence.

Each list item becomes a popover anchored to that line.

``` { .hcl .annotate title="vpc.tf" linenums="1" hl_lines="6" }
variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation { # (1)!
    condition     = can(cidrnetmask(var.vpc_cidr)) # (2)!
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}
```

1. Custom validation runs at `terraform plan` time. Multiple `validation`
    blocks per variable are allowed and evaluated independently.
2. The `can()` wrapper turns a parse exception into `false`, which is what
    `condition` expects. Without it, an invalid CIDR would crash the plan
    instead of producing a clean error message.

Annotation popovers support **full Markdown** — bold, links, lists, even
nested code:

``` { .python .annotate title="settings.py" linenums="1" }
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(  # (1)!
        env_file=".env",
        env_prefix="APP_",
        case_sensitive=False,
    )

    database_url: str  # (2)!
    log_level: str = "INFO"
```

1. `model_config` replaces the old `class Config:` style in pydantic v2.
    See the [pydantic-settings docs](https://docs.pydantic.dev/latest/concepts/pydantic_settings/)
    for every option.

2. No default → required. Set it via the environment:

    ```bash
    export APP_DATABASE_URL=postgresql://localhost/app
    ```

    Or in `.env`:

    ```dotenv
    APP_DATABASE_URL=postgresql://localhost/app
    ```

---

## 6. Diff highlighting

```diff title="patch.diff"
- resource "aws_s3_bucket" "logs" {
-   bucket = "${var.project}-logs"
- }
+ resource "aws_s3_bucket" "logs" {
+   bucket        = "${var.project}-${var.environment}-logs"
+   force_destroy = var.environment != "prod"
+ }
```

````markdown
```diff title="patch.diff"
- old line
+ new line
```
````

---

## 7. Tabbed alternatives — same problem, different stacks

Powered by `pymdownx.tabbed`. Great for "do X in Python / Go / Node" pages.

=== "Python"

    ```python title="logger.py"
    import logging
    import structlog

    structlog.configure(
        processors=[
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.JSONRenderer(),
        ],
    )
    log = structlog.get_logger()
    log.info("user.login", user_id=42)
    ```

=== "Go"

    ```go title="logger.go"
    import (
        "log/slog"
        "os"
    )

    var log = slog.New(slog.NewJSONHandler(os.Stdout, nil))

    func main() {
        log.Info("user.login", "user_id", 42)
    }
    ```

=== "Node"

    ```ts title="logger.ts"
    import pino from "pino";

    const log = pino();
    log.info({ user_id: 42 }, "user.login");
    ```

````markdown
=== "Python"

    ```python
    …
    ```

=== "Go"

    ```go
    …
    ```
````

---

## 8. Inline code & keyboard shortcuts

Inline code: `terraform apply -auto-approve` is `monospace inline`.

Keyboard chords via `pymdownx.keys`: press ++ctrl+c++ to copy, ++cmd+shift+p++
on macOS for the command palette.

---

## 9. Admonitions / callouts

These pair well with code blocks for context:

!!! tip "Use `can()` for validations"
    Wrap any function that might raise with `can()` so a malformed input
    becomes a clean validation error instead of a stack trace.

!!! warning "Don't commit `*.tfvars`"
    They almost always contain environment-specific secrets or account IDs.

!!! danger "`terraform destroy` in prod"
    No undo. Always run `terraform plan -destroy` first and review the output.

??? note "Collapsible — click me"
    Use `???` instead of `!!!` to make a collapsible block. Useful for long
    appendices that aren't needed by default.

    ```hcl
    # any markdown / code works inside
    ```

---

## 10. Combining everything

``` { .hcl .annotate title="modules/s3-bucket/main.tf" linenums="1" hl_lines="9-12" }
resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name # (1)!

  tags = merge(var.tags, {
    Name = local.bucket_name
  })
}

resource "aws_s3_bucket_public_access_block" "this" { # (2)!
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" { # (3)!
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}
```

1. Compose the bucket name from `local`s rather than inlining the format
    string everywhere. Keep the naming logic in one place.

2. **Always** attach a public-access block. AWS makes this opt-in per bucket,
    and the default leaves you exposed if a misconfigured policy slips
    through.

3. Server-side encryption is now on by default for new buckets, but pinning
    the algorithm explicitly makes intent clear and lets you use a customer
    KMS key when `var.kms_key_arn` is set.
