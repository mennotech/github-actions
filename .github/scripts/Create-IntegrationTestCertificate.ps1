#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates and exports a test certificate for integration testing.

.DESCRIPTION
    Creates a self-signed certificate for integration testing, exports it to PFX,
    converts to base64, and sets GitHub environment variables.

.EXAMPLE
    Create-IntegrationTestCertificate.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating test code-signing certificate..." -ForegroundColor Cyan
    
    # Create a self-signed certificate for code signing
    $cert = New-SelfSignedCertificate -Subject "CN=IntegrationTestCert,O=Mennotech,C=US" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert -NotAfter (Get-Date).AddDays(1)
    
    # Export to PFX with password  
    $password = ConvertTo-SecureString "IntegrationTest123!" -AsPlainText -Force
    $pfxPath = "$env:TEMP\integration-test.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $password | Out-Null
    
    # Convert to base64
    $pfxBytes = [IO.File]::ReadAllBytes($pfxPath)
    $pfxBase64 = [Convert]::ToBase64String($pfxBytes)
    
    # Clean up certificate from store (will be re-imported by action)
    Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    Remove-Item $pfxPath -Force
    
    # Output for next steps
    "PFX_BASE64=$pfxBase64" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    "PFX_PASSWORD=IntegrationTest123!" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
    
    Write-Host "[OK] Test certificate created and exported" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create integration test certificate: $_"
    exit 1
}