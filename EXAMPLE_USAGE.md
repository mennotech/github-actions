# Example Usage for Mennotech GitHub Actions & Workflows

This document demonstrates the **correct separation of responsibilities** when using Mennotech’s GitHub Actions and reusable workflows.

> **Recommended for most consumers**
>
> Use `mennotech/github-workflows` as the default integration point.
> That layer is where Mennotech intends to provide sane defaults, safer orchestration, and upgrade guidance for application repositories.
> Use `mennotech/github-actions` directly only when you need low-level control and are comfortable managing exclusions, sequencing, and security behavior yourself.

> **Key principle**
>
> - **Application repositories own configuration** (paths, exclusions, environment‑specific values)
> - **Workflow repositories own orchestration** (step order, guardrails, security defaults)
> - **Action repositories own mechanics** (how signing and deployment are implemented)

---

## Architecture Overview

| Layer | Repository | Responsibility |
|------|-----------|----------------|
| Application / Scripts | Your repo | Defines **what** is deployed and **where** |
| Reusable Workflows | `mennotech/github-workflows` | Defines **how** deployment happens |
| Composite Actions | `mennotech/github-actions` | Implements **low‑level mechanics** |

### Guidance

- Most application repositories should call `mennotech/github-workflows`
- Direct `mennotech/github-actions` usage is an advanced path for custom workflow authors
- If you consume actions directly, you are responsible for passing explicit exclusions and preserving safe defaults in your own workflow

---

## Example: Application Repository (✅ owns parameters)

This is what a **final script or application repository** should contain.

The application repository:
- Chooses deployment paths
- Chooses exclusions
- Chooses triggers
- Does **not** implement signing or deployment logic
- Should normally consume `mennotech/github-workflows`, not raw `mennotech/github-actions`

> **Important upgrade note**
>
> `deploy-files-windows` and `codesign-files-windows` no longer provide broad default exclusion lists.
> Only `.git` is excluded automatically, so application repositories should pass exclusions such as `.github`, `logs`, `_work`, and any generated output folders explicitly when needed.

### `.github/workflows/deploy.yml` (Application Repository)

```yaml
name: Sign and Deploy

on:
  workflow_dispatch:
  push:
    branches: ["main"]

permissions:
  contents: read

jobs:
  deploy:
    name: Sign and deploy application scripts
    uses: mennotech/github-workflows/sign-and-deploy-windows@v1
    secrets: inherit
    with:
      # Application-specific configuration
      destination_path: "C:\\Scripts\\exchange-apply-address-book-policy"
      exclude_dirs: ".git,.github,_work,logs"
      exclude_files: "*.crt,Config.json"

      # Optional overrides
      timestamp_server: "http://timestamp.digicert.com"
```

## Advanced: Direct `github-actions` Usage

Direct action consumption is supported, but it is intended for maintainers or advanced users who need custom orchestration.

If you use actions from this repository directly, you should assume responsibility for:

- ordering the signing and deployment steps correctly
- passing explicit exclusions for repository-specific directories and generated output
- enabling certificate cleanup and other security-sensitive options explicitly
- reviewing release notes for behavior changes that reusable workflows may otherwise absorb for you