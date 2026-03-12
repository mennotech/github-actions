#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a test certificate for GitHub Actions testing.

.DESCRIPTION
    Creates a self-signed certificate for testing certificate import functionality,
    exports it to PFX format, converts to base64, and sets GitHub environment variables.

.EXAMPLE
    Create-TestCertificate.ps1
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
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
    
    # Convert to base64
    $pfxBytes = [IO.File]::ReadAllBytes($pfxPath)
    $pfxBase64 = [Convert]::ToBase64String($pfxBytes)
    
    # Set environment variables for the test
    "TEST_PFX_BASE64=$pfxBase64" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    "TEST_PFX_PASSWORD=TestPassword123!" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    
    # Clean up cert from store and file
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    Remove-Item $pfxPath -Force
    
    Write-Host "[OK] Test certificate created and exported" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test certificate: $_"
    exit 1
}