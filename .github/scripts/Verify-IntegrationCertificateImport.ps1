#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies certificate import for integration testing.

.DESCRIPTION
    Verifies that a certificate was properly imported and that environment variables are set correctly.

.PARAMETER CertificateThumbprint
    The thumbprint of the imported certificate.

.EXAMPLE
    Verify-IntegrationCertificateImport.ps1 -CertificateThumbprint "ABC123..."
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CertificateThumbprint
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Verifying certificate was imported..." -ForegroundColor Yellow
    
    Write-Host "Imported certificate thumbprint: $CertificateThumbprint" -ForegroundColor Gray
    
    if (-not $CertificateThumbprint) {
        throw "No certificate thumbprint returned from import action"
    }
    
    # Verify environment variable is set
    if ($env:IMPORTED_CERT_THUMBPRINT -ne $CertificateThumbprint) {
        throw "IMPORTED_CERT_THUMBPRINT environment variable not set correctly"
    }
    
    # Verify certificate exists and has code signing capability
    $cert = Get-ChildItem "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        throw "Certificate not found in certificate store"
    }

    $tempCerPath = Join-Path $env:TEMP "$CertificateThumbprint.cer"
    try {
        Export-Certificate -Cert $cert -FilePath $tempCerPath -Force | Out-Null
        Import-Certificate -FilePath $tempCerPath -CertStoreLocation "Cert:\CurrentUser\Root" | Out-Null
        Import-Certificate -FilePath $tempCerPath -CertStoreLocation "Cert:\CurrentUser\TrustedPublisher" | Out-Null
    } finally {
        if (Test-Path $tempCerPath) {
            Remove-Item $tempCerPath -Force
        }
    }

    Write-Host "[OK] Certificate trusted for test signing" -ForegroundColor Green
    
    Write-Host "[OK] Certificate import verified successfully" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to verify certificate import: $_"
    exit 1
}