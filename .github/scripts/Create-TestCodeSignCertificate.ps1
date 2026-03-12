#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates and imports a test certificate for code signing.

.DESCRIPTION
    Creates a self-signed certificate for code signing and imports it into the certificate store.
    Sets environment variables with the certificate thumbprint for use by other workflow steps.

.EXAMPLE
    Create-TestCodeSignCertificate.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating and importing test certificate..." -ForegroundColor Cyan
    
    # Create a self-signed certificate for code signing
    $cert = New-SelfSignedCertificate -Subject "CN=TestCodeSignCert" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
    
    # Store thumbprint in environment for cleanup
    "TEST_CERT_THUMBPRINT=$($cert.Thumbprint)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    "IMPORTED_CERT_THUMBPRINT=$($cert.Thumbprint)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    
    Write-Host "[OK] Test certificate created with thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test code signing certificate: $_"
    exit 1
}