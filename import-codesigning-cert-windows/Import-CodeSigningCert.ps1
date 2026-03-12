#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Import code-signing certificate from environment variables into the certificate store.

.DESCRIPTION
    This script imports a PFX certificate from base64-encoded environment variables
    into the CurrentUser\My certificate store for code signing operations.

.PARAMETER PfxBase64
    Base64-encoded PFX certificate data. If not provided, reads from CODESIGN_PFX_BASE64 environment variable.

.PARAMETER PfxPassword
    Password for the PFX certificate. If not provided, reads from CODESIGN_PFX_PASSWORD environment variable.

.EXAMPLE
    Import-CodeSigningCertificate.ps1

.EXAMPLE
    Import-CodeSigningCertificate.ps1 -PfxBase64 "base64data..." -PfxPassword "password"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PfxBase64 = $env:CODESIGN_PFX_BASE64,

    [Parameter()]
    [System.Security.SecureString]$PfxPassword = (ConvertTo-SecureString $env:CODESIGN_PFX_PASSWORD -AsPlainText -Force)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    # Validate required parameters
    if ([string]::IsNullOrWhiteSpace($PfxBase64)) {
        throw "Missing required parameter: PfxBase64 or environment variable CODESIGN_PFX_BASE64"
    }
    if (-not $PfxPassword) {
        throw "Missing required parameter: PfxPassword or environment variable CODESIGN_PFX_PASSWORD"
    }

    Write-Host "Importing code-signing certificate..."

    # Create temporary file for the PFX
    $pfxPath = Join-Path $PSScriptRoot "codesign.pfx"
    Write-Host "Writing PFX to temporary file: $pfxPath"

    try {
        [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($PfxBase64))
    } catch {
        throw "Failed to decode base64 PFX data: $_"
    }

    # Import certificate into CurrentUser\My for this runner session/job
    Write-Host "Importing certificate into Cert:\CurrentUser\My..."
    $null = Import-PfxCertificate -FilePath $pfxPath -Password $PfxPassword -CertStoreLocation Cert:\CurrentUser\My

    # Confirm certificate is available for code signing
    $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
    if (-not $cert) {
        throw "No code-signing certificate found in Cert:\CurrentUser\My after import."
    }

    Write-Host "Successfully loaded code signing certificate:" -ForegroundColor Green
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
    Write-Host "  Valid From: $($cert.NotBefore)" -ForegroundColor Gray
    Write-Host "  Valid Until: $($cert.NotAfter)" -ForegroundColor Gray

    # Store thumbprint for other scripts to use
    $env:IMPORTED_CERT_THUMBPRINT = $cert.Thumbprint
    Write-Output "Certificate thumbprint: $($cert.Thumbprint)"

    # Clean up temporary file
    if (Test-Path $pfxPath) {
        Remove-Item $pfxPath -Force
        Write-Host "Cleaned up temporary PFX file" -ForegroundColor Gray
    }

} catch {
    Write-Error "Failed to import code-signing certificate"
    exit 1
}
