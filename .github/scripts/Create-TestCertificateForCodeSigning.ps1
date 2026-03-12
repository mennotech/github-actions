#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates and imports a test certificate for code signing action testing.

.DESCRIPTION
    Creates a self-signed certificate for code signing and imports it to the certificate store.
    Sets environment variables for later cleanup.

.EXAMPLE
    Create-TestCertificateForCodeSigning.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating and importing test certificate..." -ForegroundColor Cyan
    
    # Create a self-signed certificate for code signing
    $cert = New-SelfSignedCertificate -Subject "CN=TestCodeSignCert" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert

    $tempCerPath = Join-Path $env:TEMP "test-codesign-cert.cer"
    try {
        Export-Certificate -Cert $cert -FilePath $tempCerPath -Force | Out-Null
        Import-Certificate -FilePath $tempCerPath -CertStoreLocation "Cert:\CurrentUser\Root" | Out-Null
        Import-Certificate -FilePath $tempCerPath -CertStoreLocation "Cert:\CurrentUser\TrustedPublisher" | Out-Null
    } finally {
        if (Test-Path $tempCerPath) {
            Remove-Item $tempCerPath -Force
        }
    }
    
    # Store thumbprint in environment for cleanup
    Write-Output "TEST_CERT_THUMBPRINT=$($cert.Thumbprint)" >> $env:GITHUB_ENV
    Write-Output "IMPORTED_CERT_THUMBPRINT=$($cert.Thumbprint)" >> $env:GITHUB_ENV
    
    Write-Host "[OK] Test certificate created with thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test certificate for code signing: $_"
    exit 1
}