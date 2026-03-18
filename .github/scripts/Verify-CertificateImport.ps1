#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies that a certificate was imported correctly.

.DESCRIPTION
    Checks that the imported certificate exists in the certificate store. Can also
    validate the thumbprint against an environment variable and optionally clean up
    the certificate afterward.

.PARAMETER CertificateThumbprint
    The thumbprint of the certificate to verify.

.PARAMETER ExpectedEnvironmentVariableName
    Environment variable that should contain the same thumbprint.

.PARAMETER CleanupCertificate
    Removes the certificate from configured stores after verification.

.EXAMPLE
    Verify-CertificateImport.ps1 -CertificateThumbprint "ABC123..."
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$CertificateThumbprint,

    [Parameter()]
    [string]$ExpectedEnvironmentVariableName,

    [Parameter()]
    [switch]$CleanupCertificate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Remove-TestCertificate {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Thumbprint
    )

    $stores = @(
        'Cert:\CurrentUser\My',
        'Cert:\CurrentUser\TrustedPublisher',
        'Cert:\CurrentUser\Root'
    )

    $removed = $false
    foreach ($storePath in $stores) {
        $cert = Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue | Where-Object {
            $_.Thumbprint -eq $Thumbprint
        }

        if ($cert -and $PSCmdlet.ShouldProcess("$storePath\\$Thumbprint", 'Remove test certificate')) {
            $cert | Remove-Item -Force
            $removed = $true
            Write-Host "[OK] Certificate removed from $storePath" -ForegroundColor Green
        }
    }

    if (-not $removed) {
        Write-Host "[Warning] Certificate not found during cleanup" -ForegroundColor Yellow
    }
}

try {
    Write-Host "Verifying certificate import..." -ForegroundColor Yellow

    if (-not $CertificateThumbprint) {
        throw "No certificate thumbprint provided"
    }

    Write-Host "Certificate thumbprint: $CertificateThumbprint" -ForegroundColor Gray

    if ($ExpectedEnvironmentVariableName) {
        $expectedValue = [Environment]::GetEnvironmentVariable($ExpectedEnvironmentVariableName)
        if ($expectedValue -ne $CertificateThumbprint) {
            throw "$ExpectedEnvironmentVariableName environment variable not set correctly"
        }

        Write-Host "[OK] Environment variable $ExpectedEnvironmentVariableName matched the thumbprint" -ForegroundColor Green
    }

    $cert = Get-ChildItem "Cert:\CurrentUser\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
    if (-not $cert) {
        throw "Certificate not found in certificate store"
    }

    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "[OK] Certificate successfully imported and verified" -ForegroundColor Green

    if ($CleanupCertificate) {
        Remove-TestCertificate -Thumbprint $CertificateThumbprint
    }
} catch {
    Write-Error "Failed to verify certificate import: $_"
    exit 1
}