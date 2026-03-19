# mennotech/github-actions

> **Reusable GitHub Actions** for code signing, deployment, and DevOps workflows

Central repository containing Mennotech maintained reusable GitHub Actions. These actions are designed to be consumed by workflows in [`mennotech/github-workflows`](https://github.com/mennotech/github-workflows) and other repositories using the standard marketplace pattern.

> **Recommended consumption path**
>
> Most application repositories should use [`mennotech/github-workflows`](https://github.com/mennotech/github-workflows), not this repository directly.
> The reusable workflows are where Mennotech intends to provide sane orchestration defaults, safety guardrails, and upgrade guidance.
> Direct `mennotech/github-actions` usage is supported for advanced callers building custom workflows who are prepared to manage exclusions, ordering, and security settings explicitly.

## Repository Architecture

This repository is part of a three-tier DevOps architecture:

### 🔧 [mennotech/github-actions](https://github.com/mennotech/github-actions) *(This Repository)*
**Purpose**: Low-level reusable actions for specific tasks
- ✅ **Atomic Actions**: Certificate import, code signing, file deployment
- ✅ **Cross-Platform Support**: Windows (current), Linux/macOS (planned)
- ✅ **Advanced Building Blocks**: `uses: mennotech/github-actions/action-name@v1`
- ✅ **Single Responsibility**: Each action performs one specific task

### 🔄 [mennotech/github-workflows](https://github.com/mennotech/github-workflows)
**Purpose**: Complete workflow templates that orchestrate actions
- ✅ **End-to-End Pipelines**: Build → Sign → Test → Deploy workflows
- ✅ **Reusable Workflows**: `uses: mennotech/github-workflows/.github/workflows/deploy.yml@v1`
- ✅ **Best Practices**: Security, error handling, rollback strategies
- ✅ **Composition**: Combines multiple github-actions into complete DevOps flows

### 📦 Individual Application Repositories
**Purpose**: Your actual applications and scripts that need DevOps support
- ✅ **Business Logic**: Your PowerShell scripts, applications, configurations
- ✅ **Workflow Usage**: Consume workflows from `mennotech/github-workflows`
- ✅ **Simple Configuration**: Just specify deployment paths and requirements
- ✅ **Focus on Code**: Let the workflows handle the DevOps complexity

### When to Use What?

| Need | Repository | Example |
|------|------------|---------|
| **Default choice for applications** | mennotech/github-workflows | Build, sign, test, and deploy with sane defaults |
| **Advanced low-level composition** | mennotech/github-actions | Build a custom workflow when you need direct control |
| **Custom orchestration** | Build your own | Use github-actions as building blocks if you know what you are doing |

## Quick Start

### Recommended: Use `mennotech/github-workflows`

For most repositories, consume the reusable workflow layer and keep application-specific settings there:

```yaml
jobs:
  deploy:
    uses: mennotech/github-workflows/sign-and-deploy-windows@v1
    secrets: inherit
    with:
      destination_path: "C:\\Scripts\\MyApp"
      exclude_dirs: "logs"
      exclude_files: "*.crt,Config.json"
```

### Advanced: Use `mennotech/github-actions` Directly

Use the low-level actions in this repository directly only when you need custom orchestration and are prepared to manage exclusions, security settings, and step ordering yourself.

```yaml
# In your workflow file
steps:
  - name: Import Code-Signing Certificate
    uses: mennotech/github-actions/import-codesigning-cert-windows@v1
    with:
      pfx_base64: ${{ secrets.CODESIGN_PFX_BASE64 }}
      pfx_password: ${{ secrets.CODESIGN_PFX_PASSWORD }}

  - name: Sign PowerShell Files
    uses: mennotech/github-actions/codesign-files-windows@v1
    with:
      recurse: true
      cleanup_certificate: true

  - name: Deploy Files
    uses: mennotech/github-actions/deploy-files-windows@v1
    with:
      destination_path: "C:\\Scripts\\MyApp"
      exclude_dirs: ".github,logs"
      exclude_files: "*.crt,Config.json"
```

## Available Actions

### Platform-Specific Actions (Windows)
> **Migration Complete**: Actions have been renamed with `-windows` suffix to support future cross-platform expansion.

| Action | Purpose | Documentation |
|--------|---------|---------------|
| [`import-codesigning-cert-windows`](./import-codesigning-cert-windows/) | Import PFX certificate into Windows certificate store | [📖 Details](./import-codesigning-cert-windows/action.yml) |
| [`codesign-files-windows`](./codesign-files-windows/) | Sign PowerShell files with code-signing certificate | [📖 Details](./codesign-files-windows/action.yml) |
| [`deploy-files-windows`](./deploy-files-windows/) | Deploy files using robocopy with smart exclusions | [📖 Details](./deploy-files-windows/action.yml) |

### Future Cross-Platform Actions
| Action | Platform | Purpose | Status |
|--------|----------|---------|---------|
| `import-codesigning-cert-linux` | Linux | File-based certificate handling | 🔮 Planned |
| `codesign-files-linux` | Linux | Using osslsigncode/jsign | 🔮 Planned |
| `deploy-files` | All | Cross-platform with auto-detection | 🔮 Future |

## Platform Requirements

- **Current**: Windows self-hosted runners
- **Future**: Linux/macOS actions will be added alongside Windows actions  
- **Dependencies**: PowerShell 7+ (Windows), Bash/Python (Linux/macOS - future)
- **Certificate Store**: Windows Certificate Store (current), file-based certificates (future)

## Development

For contributors and maintainers:

- **📋 [Development Instructions](.github/INSTRUCTIONS.md)** - Detailed guidelines for PowerShell conventions, action development patterns, security practices, testing procedures, and release workflow
- **📝 [Changelog](./CHANGELOG.md)** - User-facing history of released changes
- **🚀 [Release Guide](./RELEASE.md)** - Maintainer checklist for tagging and publishing releases

## Security Notes

These actions execute entirely within the caller’s workflow context (runners, permissions, secrets).

**Excluded Files and Folders**: Only `.git` is excluded automatically (starting in v1.1.0), so direct callers should explicitly pass exclusions such as `.github`, `logs`, `*.crt`, and any generated output directories or files they do not want processed.

**Certificate Management**: Always use `cleanup_certificate: true` when signing files to prevent certificate persistence on self-hosted runners.

**Explicit Deployment Exclusions**: `deploy-files-windows` now treats `exclude_dirs` and `exclude_files` as additional caller-controlled exclusions. Only `.git` is enforced automatically. If you do not provide your own exclusions, robocopy mirrors everything else in the source tree into the destination, including CI and runner artifacts you may not want in production. Common examples to exclude explicitly are `.github`, `logs`, and `_work`, plus any environment-specific config or generated output directories.

## Example Usage

See [**📄 Example Usage**](./EXAMPLE_USAGE.md) for recommended `github-workflows` consumption patterns, advanced direct action usage guidance, and migration notes.

---

**License**: [MIT](./LICENSE) | **Maintainer**: Mennotech
