#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies PowerShell file signatures and certificate cleanup.

.DESCRIPTION
    Checks that all PowerShell files in the specified path have valid signatures
    and verifies that the test certificate was properly cleaned up.

.PARAMETER TestPath
    The path containing PowerShell files to verify. Defaults to "test-scripts".

.PARAMETER TestCertThumbprint
    The thumbprint of the test certificate (from environment variable).

.EXAMPLE
    Verify-PowerShellSignatures.ps1 -TestPath "test-scripts" -TestCertThumbprint $env:TEST_CERT_THUMBPRINT
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestPath = "test-scripts",
    
    [Parameter()]
    [string]$TestCertThumbprint = $env:TEST_CERT_THUMBPRINT
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Verifying PowerShell file signatures..." -ForegroundColor Yellow
    
    $files = Get-ChildItem -Path $TestPath -Include "*.ps1", "*.psm1" -Recurse
    $signedCount = 0
    
    foreach ($file in $files) {
        $sig = Get-AuthenticodeSignature -FilePath $file.FullName
        Write-Host "File: $($file.Name), Status: $($sig.Status)" -ForegroundColor Gray
        
        if ($sig.Status -eq 'Valid') {
            $signedCount++
        }
    }
    
    if ($signedCount -eq $files.Count) {
        Write-Host "[OK] All PowerShell files successfully signed ($signedCount/$($files.Count))" -ForegroundColor Green
    } else {
        throw "Only $signedCount out of $($files.Count) files were successfully signed"
    }
    
    # Verify certificate was cleaned up (should fail to find it)
    if ($TestCertThumbprint) {
        $cert = Get-ChildItem "Cert:\CurrentUser\My\$TestCertThumbprint" -ErrorAction SilentlyContinue
        if ($cert) {
            Write-Warning "Certificate was not cleaned up as expected"
        } else {
            Write-Host "[OK] Certificate was properly cleaned up" -ForegroundColor Green
        }
    }
    
} catch {
    Write-Error "Failed to verify PowerShell signatures: $_"
    exit 1
}