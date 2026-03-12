#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a test certificate for import certificate action testing.

.DESCRIPTION
    Creates a self-signed certificate, exports it to PFX format, and sets environment variables
    for use in GitHub Actions workflow testing.

.EXAMPLE
    Create-TestCertificateForImport.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating test certificate for validation..." -ForegroundColor Cyan
    
    # Create a self-signed certificate for testing
    $cert = New-SelfSignedCertificate -Subject "CN=TestCert" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
    
    # Export to PFX with password
    $password = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
    $pfxPath = "$env:TEMP\test.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password
    
    # Convert to base64
    $pfxBytes = [IO.File]::ReadAllBytes($pfxPath)
    $pfxBase64 = [Convert]::ToBase64String($pfxBytes)
    
    # Set environment variables for the test
    Write-Output "TEST_PFX_BASE64=$pfxBase64" >> $env:GITHUB_ENV
    Write-Output "TEST_PFX_PASSWORD=TestPassword123!" >> $env:GITHUB_ENV
    
    # Clean up cert from store and file
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    Remove-Item $pfxPath -Force
    
    Write-Host "[OK] Test certificate created and exported" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test certificate for import: $_"
    exit 1
}