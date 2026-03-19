# Example Usage for Mennotech GitHub Actions & Workflows

> **Recommended for most consumers**
>
> Use `mennotech/github-workflows` as the default integration point.
> Use `mennotech/github-actions` directly only when you need low-level control and are comfortable managing exclusions, sequencing, and security behavior yourself.

> **Key principle**
>
> - **Application repositories own configuration** (paths, exclusions, environment-specific values)
> - **Workflow repositories own orchestration** (step order, guardrails, security defaults)
> - **Action repositories own mechanics** (how signing and deployment are implemented)

---

## Example: Application Repository (✅ owns parameters)

The application repository:
- Chooses deployment paths, exclusions, and triggers
- Does **not** implement signing or deployment logic
- Should normally consume `mennotech/github-workflows`, not raw `mennotech/github-actions`

> **Important upgrade note (v1.1.0+)**
>
> Only `.git` is excluded automatically. Pass `.github`, `logs`, `_work`, and any generated output folders explicitly.

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

Direct action consumption is for maintainers or advanced users who need custom orchestration.

If you use actions from this repository directly, you are responsible for:

- ordering the signing and deployment steps correctly
- passing explicit exclusions for repository-specific directories and generated output
- reviewing release notes for behavior changes that reusable workflows may otherwise absorb for you

### Certificate Handling Guidance

- Use `import-codesigning-cert-windows` to load a PFX into `CurrentUser\My`. Certificate cleanup is enabled by default (`cleanup_certificate: true`) so imported certificates do not persist on self-hosted runners.
- Production workflows should use trusted signing certificates and keep signature verification strict.
- Test workflows that use self-signed certificates may see `Get-AuthenticodeSignature` return `UnknownError` because the root is not trusted. In that narrow case, `codesign-files-windows` supports `allow_untrusted_root_in_test: true`, but only for test verification and only when you also pass the expected `cert_thumbprint`.
- Do not treat `allow_untrusted_root_in_test` as a general-purpose bypass.
