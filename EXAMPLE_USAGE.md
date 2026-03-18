# Example Usage for Mennotech GitHub Actions & Workflows

This document demonstrates the **correct separation of responsibilities** when using Mennotech’s GitHub Actions and reusable workflows.

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

---

## Example: Application Repository (✅ owns parameters)

This is what a **final script or application repository** should contain.

The application repository:
- Chooses deployment paths
- Chooses exclusions
- Chooses triggers
- Does **not** implement signing or deployment logic

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
``