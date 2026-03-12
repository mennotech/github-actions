# Example Usage for mennotech/github-workflows

This demonstrates how to consume the actions from `mennotech/github-actions` in your workflow repository.

## Sign and Deploy Workflow

```yaml
name: Sign and Deploy

on:
  workflow_dispatch:
  push:
    branches: [ "main" ]

permissions:
  contents: read

jobs:
  sign_and_deploy:
    name: Sign scripts and deploy (Windows)
    runs-on:
      group: SCS Domain Controllers
      labels: [self-hosted, windows]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Import Code-Signing Certificate
        uses: mennotech/github-actions/import-codesigning-cert-windows@v1
        with:
          pfx_base64: ${{ secrets.CODESIGN_PFX_BASE64 }}
          pfx_password: ${{ secrets.CODESIGN_PFX_PASSWORD }}

      - name: Sign PowerShell Files
        uses: mennotech/github-actions/codesign-files-windows@v1
        with:
          timestamp_server: "http://timestamp.digicert.com"
          recurse: true
          cleanup_certificate: true  # SECURITY: Remove certificate after signing

      - name: Validate Script Signatures
        uses: mennotech/github-actions/codesign-files-windows@v1
        with:
          test_only: true
          fail_on_invalid: true
          recurse: true

      - name: Deploy Scripts
        uses: mennotech/github-actions/deploy-files-windows@v1
        with:
          destination_path: "C:\\Scripts\\exchange-apply-address-book-policy"
          exclude_dirs: ".git,.github,_work,logs"
          exclude_files: "*.crt,Config.json"

      - name: Validate Deployment
        uses: mennotech/github-actions/deploy-files-windows@v1
        with:
          destination_path: "C:\\Scripts\\exchange-apply-address-book-policy"
          exclude_dirs: ".git,.github,_work,logs"
          exclude_files: "*.crt,Config.json"
          test_only: true
```

## Migration from Old Pattern

**Before** (refactoring-this-deploy.yml):
```yaml
- name: Import Code-Signing certificate
  shell: pwsh
  env:
    CODESIGN_PFX_BASE64: ${{ secrets.CODESIGN_PFX_BASE64 }}
    CODESIGN_PFX_PASSWORD: ${{ secrets.CODESIGN_PFX_PASSWORD }}
  run: .\.github\scripts\Import-CodeSigningCertificate.ps1

- name: Sign PowerShell files
  shell: pwsh
  env:
    TIMESTAMP_SERVER: "http://timestamp.digicert.com"
  run: .\.github\scripts\Sign-PowerShellFiles.ps1 -Recurse -CleanupCertificate
```

**After** (using platform-specific actions):
```yaml
- name: Import Code-Signing Certificate  
  uses: mennotech/github-actions/import-codesigning-cert-windows@v1
  with:
    pfx_base64: ${{ secrets.CODESIGN_PFX_BASE64 }}
    pfx_password: ${{ secrets.CODESIGN_PFX_PASSWORD }}

- name: Sign PowerShell Files
  uses: mennotech/github-actions/codesign-files-windows@v1
  with:
    timestamp_server: "http://timestamp.digicert.com"
    recurse: true
    cleanup_certificate: true
```