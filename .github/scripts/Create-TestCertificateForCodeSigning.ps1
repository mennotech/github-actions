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
    
    # Store thumbprint in environment for cleanup
    Write-Output "TEST_CERT_THUMBPRINT=$($cert.Thumbprint)" >> $env:GITHUB_ENV
    Write-Output "IMPORTED_CERT_THUMBPRINT=$($cert.Thumbprint)" >> $env:GITHUB_ENV
    
    Write-Host "[OK] Test certificate created with thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test certificate for code signing: $_"
    exit 1
}