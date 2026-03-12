#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies certificate import action results.

.DESCRIPTION
    Verifies that a certificate was properly imported by the import action and cleans up afterward.

.PARAMETER CertificateThumbprint
    The thumbprint of the imported certificate (from action output).

.EXAMPLE
    Verify-CertificateImportAction.ps1 -CertificateThumbprint "ABC123..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
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
    Write-Error "Certificate import verification failed: $_"
    exit 1
}