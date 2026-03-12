# mennotech/github-actions

> **Reusable GitHub Actions** for code signing, deployment, and DevOps workflows

Central repository containing Mennotech's reusable GitHub Actions. These actions are designed to be consumed by workflows in [`mennotech/github-workflows`](https://github.com/mennotech/github-workflows) and other repositories using the standard marketplace pattern.

## Quick Start

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

## Security Notes

⚠️ **Certificate Management**: Always use `cleanup_certificate: true` when signing files to prevent certificate persistence on self-hosted runners.

## Example Usage

See [**📄 Example Usage**](./EXAMPLE_USAGE.md) for complete workflow examples and migration guidance from inline PowerShell scripts.

---

**License**: [MIT](./LICENSE) | **Maintainer**: Mennotech
