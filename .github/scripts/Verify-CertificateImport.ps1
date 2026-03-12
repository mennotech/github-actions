#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies that a certificate was imported correctly.

.DESCRIPTION
    Checks that the imported certificate exists in the certificate store and cleans it up.

.PARAMETER CertificateThumbprint
    The thumbprint of the certificate to verify.

.EXAMPLE
    Verify-CertificateImport.ps1 -CertificateThumbprint "ABC123..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CertificateThumbprint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Verifying certificate import..." -ForegroundColor Yellow
    
    if (-not $CertificateThumbprint) {
        throw "No certificate thumbprint provided"
    }
    
    Write-Host "Certificate thumbprint: $CertificateThumbprint" -ForegroundColor Gray
    
    # Verify certificate exists in store
    $cert = Get-ChildItem "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        throw "Certificate not found in certificate store"
    }
    
    Write-Host "[OK] Certificate successfully imported and verified" -ForegroundColor Green
    
    # Clean up test certificate
    Remove-Item "Cert:\CurrentUser\My\$CertificateThumbprint" -Force
    Write-Host "[OK] Test certificate cleaned up" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to verify certificate import: $_"
    exit 1
}