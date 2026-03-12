# GitHub Actions Development Instructions

> **Repository Purpose**: `mennotech/github-actions` contains reusable GitHub Actions for code signing, deployment, and related DevOps workflows. Actions are consumed by workflows in `mennotech/github-workflows` using the standard marketplace pattern: `uses: mennotech/github-actions/action-name@v1`.

## Table of Contents

- [Repository Architecture](#repository-architecture)
- [Action Development Standards](#action-development-standards)
- [PowerShell Script Conventions](#powershell-script-conventions)
- [action.yml Development Patterns](#actionyml-development-patterns)
- [Security Guidelines](#security-guidelines)
- [Testing and Validation](#testing-and-validation)
- [Development Workflow](#development-workflow)
- [Existing Actions](#existing-actions)

---

## Repository Architecture

### Structure
```
mennotech/github-actions/
├── .github/
│   └── INSTRUCTIONS.md              # This file
├── import-codesigning-cert-windows/  
│   ├── action.yml                   # Action definition
│   └── Import-CodeSigningCert.ps1   # Script
├── codesign-files-windows/          
│   ├── action.yml                   # Action definition
│   └── CodeSign-Files.ps1           # Script
...
└── README.md
```

**Future Cross-Platform Structure:**
```
mennotech/github-actions/
├── import-codesigning-cert-windows/  # Current Windows implementation
├── import-codesigning-cert-linux/    # Future - Linux implementation
├── codesign-files-windows/           # Current Windows implementation
├── codesign-files-linux/             # Future - Linux implementation
```

### Relationship to mennotech/github-workflows
- **This repo (github-actions)**: Reusable action definitions and PowerShell implementation
- **github-workflows**: Workflow orchestration consuming these actions
- **Consumption pattern**: `uses: mennotech/github-actions/action-name@v1`

### Target Platform
- **Current**: Windows self-hosted runners with PowerShell 7+
- **Future**: Cross-platform support (Windows, Linux, macOS)
- **Certificate operations**: Platform-specific (Windows Certificate Store, file-based PEM/PFX)
- **Dependencies**: Platform-specific implementations (PowerShell, Bash, Python)
- **Migration**: See [Cross-Platform Migration Guide](CROSS_PLATFORM_MIGRATION.md)


## Action Development Standards

### File Organization

#### Single-Platform Actions
Each action must contain:
1. **`action.yml`** - GitHub Action definition mapping inputs to environment variables
2. **`ActionName.ps1`** - PowerShell implementation with dual input support
3. **Documentation** - Comprehensive help blocks and examples

### Naming Conventions

#### Cross-Platform
- **Platform-specific actions**: `action-name-platform` (e.g., `codesign-files-windows`, `codesign-files-linux`)
- **Implementation files**:
  - Windows: `ActionName.ps1` (PascalCase)
  - Linux/macOS: `action_name.sh` (snake_case)
  - Python: `action_name.py` (snake_case)

### Versioning Strategy
- **Semantic versioning** with git tags: `v1.0.0`, `v1.2.3`
- **Major version refs**: `v1`, `v2` (automatically updated)
- **Breaking changes**: Increment major version
- **New features**: Increment minor version
- **Bug fixes**: Increment patch version

---

## PowerShell Script Conventions

### Required Headers
```powershell
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Brief description of script purpose

.DESCRIPTION
    Detailed description of functionality

.PARAMETER ParameterName
    Description of each parameter

.EXAMPLE
    ScriptName.ps1 -Parameter "value"
#>

[CmdletBinding()]
param(
    # Parameters with dual support (direct + environment variables)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

### Dual Input Pattern
**CRITICAL**: All scripts must support both direct parameters and environment variables:

```powershell
param(
    [Parameter()]
    [string]$InputValue = $env:INPUT_VALUE,
    
    [Parameter()]
    [string]$RequiredParam = $env:REQUIRED_PARAM ? $env:REQUIRED_PARAM : (throw "Required parameter missing")
)
```

This pattern enables:
- **Local testing**: `.\Script.ps1 -InputValue "test"`
- **Action usage**: Environment variables set by action.yml
- **Direct CI usage**: Environment variables in workflow steps

### Error Handling Standards
```powershell
try {
    # Main script logic
    Write-Host "Operation completed successfully" -ForegroundColor Green
    exit 0
} catch {
    Write-Error "Operation failed: $_"
    exit 1
} finally {
    # Cleanup (certificates, temp files, etc.)
}
```

### Logging Conventions
```powershell
Write-Host "Starting operation..." -ForegroundColor Cyan          # Section headers
Write-Host "  Detail information" -ForegroundColor Gray           # Details/context  
Write-Host "Operation successful" -ForegroundColor Green          # Success
Write-Host "Warning message" -ForegroundColor Yellow              # Warnings
Write-Error "Error occurred"                                      # Errors (with exit 1)
```

### Common Patterns

#### Path Resolution
```powershell
$Path = $env:GITHUB_WORKSPACE ? $env:GITHUB_WORKSPACE : "."
$resolvedPath = Resolve-Path $Path -ErrorAction Stop
```

#### Array Environment Variables
```powershell
[string[]]$ExcludeDirs = $env:EXCLUDE_DIRS ? $env:EXCLUDE_DIRS -split ',' : @(".git", ".github")
```

#### TestOnly Pattern
```powershell
[Parameter()]
[switch]$TestOnly

# In script logic:
if ($TestOnly) {
    Write-Host "TEST MODE: Would perform operation" -ForegroundColor Yellow
    # Return exit code based on what would happen
    exit $wouldNeedChanges ? 1 : 0
}
```

---

## action.yml Development Patterns

### Basic Structure
```yaml
name: 'Action Name'
description: 'Brief description matching PowerShell synopsis'
inputs:
  input_name:
    description: 'Description matching PowerShell parameter help'
    required: false
    default: 'default-value'
runs:
  using: 'composite'
  steps:
    - shell: pwsh
      env:
        INPUT_NAME: ${{ inputs.input_name }}
      run: ${{ github.action_path }}/ScriptName.ps1
```

### Input Mapping Rules
1. **Action input names**: Use snake_case (`pfx_base64`, `timestamp_server`)
2. **Environment variables**: Prefix with `INPUT_` → `INPUT_PFX_BASE64`
3. **PowerShell parameters**: Match exactly → `$env:INPUT_PFX_BASE64`

### Required vs Optional Inputs
```yaml
inputs:
  # Required input (script will throw if missing)
  destination_path:
    description: 'Target directory for deployment'
    required: true
    
  # Optional with default (matches PowerShell default)  
  timestamp_server:
    description: 'URL for signature timestamping'
    required: false
    default: 'http://timestamp.digicert.com'
    
  # Switch parameter (boolean)
  recurse:
    description: 'Search subdirectories recursively'
    required: false
    default: 'false'
```

### Array Inputs
```yaml
inputs:
  exclude_dirs:
    description: 'Comma-separated list of directories to exclude'
    required: false
    default: '.git,.github,_work,logs'
```

---

## Security Guidelines

### Certificate Handling (CRITICAL)
1. **Import certificates to CurrentUser\My only** (not LocalMachine)
2. **Always clean up certificates** after use via `-CleanupCertificate` switch
3. **Use thumbprint tracking** via `$env:IMPORTED_CERT_THUMBPRINT`
4. **Self-hosted runners** persist certificates between jobs - cleanup is mandatory

#### Secure Certificate Workflow
```powershell
# Import step sets environment variable
$env:IMPORTED_CERT_THUMBPRINT = $cert.Thumbprint

# Sign step uses specific certificate and cleans up
CodeSign-Files.ps1 -CertThumbprint $env:IMPORTED_CERT_THUMBPRINT -CleanupCertificate
```

### Secrets Management
- **PFX certificates**: Store as base64 in repository secrets
- **Passwords**: Use GitHub encrypted secrets, convert to SecureString
- **No hardcoded secrets** in PowerShell scripts or action.yml files

### File System Security
```powershell
# Temporary files MUST be cleaned up
$tempFile = Join-Path $PSScriptRoot "temp_$(Get-Random).tmp"
try {
    # Use temp file
} finally {
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
}
```

---

## Testing and Validation

### Local Testing
1. **PowerShell script testing**:
   ```powershell
   # Test with direct parameters
   .\Import-CodeSigningCertificate.ps1 -PfxBase64 "test-data" -PfxPassword (ConvertTo-SecureString "pass" -AsPlainText -Force)
   
   # Test with environment variables (simulates action)
   $env:INPUT_PFX_BASE64 = "test-data"
   $env:INPUT_PFX_PASSWORD = "test-pass"
   .\Import-CodeSigningCertificate.ps1
   ```

2. **Action validation**: Use VS Code GitHub Actions extension or `actionlint`

### Test-Only Modes
All actions support dry-run testing:
```powershell
# Test what would be signed
.\CodeSign-Files.ps1 -TestOnly

# Test what would be deployed  
.\Deploy-Files.ps1 -TestOnly

# Validate existing signatures
.\CodeSign-Files.ps1 -TestOnly -FailOnInvalid
```

### Integration Testing
Create test workflows in `.github/workflows/test-*.yml`:
```yaml
name: Test Action
on:
  push:
    paths: ['action-name/**']
jobs:
  test:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./action-name
        with:
          input_value: "test"
```

---

## Development Workflow

### Adding New Actions
1. **Create action directory** with kebab-case name
2. **Implement PowerShell script** following conventions above
3. **Create action.yml** mapping inputs to environment variables
4. **Test locally** with both parameter and environment variable modes
5. **Add integration test** workflow
6. **Update this documentation** with new action details

### Making Changes
1. **Test locally first** - ensure dual input pattern works  
2. **Increment version appropriately** - patch for fixes, minor for features, major for breaking changes
3. **Update action.yml if needed** - new inputs, changed defaults, etc.
4. **Test in consuming workflow** before releasing

### Release Process  
1. **Commit changes** to main branch
2. **Create git tag**: `git tag v1.2.3 && git push origin v1.2.3`
3. **Update major version ref**: `git tag -f v1 && git push -f origin v1`
4. **Test in mennotech/github-workflows** with new version

---

## Existing Actions

### Current Windows Actions

#### import-codesigning-cert-windows
**Purpose**: Import PFX certificate from secrets into Windows certificate store
**Dependencies**: None
**Outputs**: `IMPORTED_CERT_THUMBPRINT` environment variable
**Script**: `Import-CodeSigningCert.ps1` (renamed from `Import-CodeSigningCertificate.ps1`)

```yaml
uses: mennotech/github-actions/import-codesigning-cert-windows@v1
with:
  pfx_base64: ${{ secrets.CODESIGN_PFX_BASE64 }}
  pfx_password: ${{ secrets.CODESIGN_PFX_PASSWORD }}
```

#### codesign-files-windows  
**Purpose**: Sign PowerShell files with imported certificate
**Dependencies**: Requires certificate (typically from import-codesigning-cert-windows)
**Security**: Auto-cleanup via `cleanup_certificate: true`

```yaml
uses: mennotech/github-actions/codesign-files-windows@v1
with:
  timestamp_server: "http://timestamp.digicert.com"
  recurse: true
  cleanup_certificate: true
```

#### deploy-files-windows
**Purpose**: Deploy files using robocopy with intelligent exclusions
**Dependencies**: None (standalone)
**Features**: Permission validation, dry-run testing, robocopy exit code interpretation

```yaml
uses: mennotech/github-actions/deploy-files-windows@v1
with:
  destination_path: "C:\\Scripts\\MyApp"
  exclude_dirs: ".git,.github,_work,logs"
  exclude_files: "*.crt,Config.json"
```

### Future Cross-Platform Actions

#### Linux Actions (Planned)
- **import-codesigning-cert-linux** - File-based certificate handling
- **codesign-files-linux** - Using `osslsigncode` or `jsign` for Authenticode signing
- **deploy-files** - Cross-platform deployment with auto-detection (single action for all OS)

#### macOS Actions (Future)
- **import-codesigning-cert-macos** - Keychain integration
- **codesign-files-macos** - Using native `codesign` command


---

## Troubleshooting

### Common Issues
| Issue | Solution |
|-------|----------|
| "Parameter missing" error | Check environment variable mapping in action.yml |
| Certificate not found | Ensure import-codesigning-cert runs first and outputs thumbprint |
| Permission denied (deploy) | Verify target directory permissions and runner access |
| PowerShell execution policy | Self-hosted runners may need `Set-ExecutionPolicy RemoteSigned` |

### Debug Mode
Enable detailed output by setting `$VerbosePreference = 'Continue'` in scripts or using `-Verbose` parameter.

---

*Last updated: March 12, 2026*