#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies code signing action results.

.DESCRIPTION
    Verifies that PowerShell files were properly signed by the code signing action and 
    checks that certificates were cleaned up if requested.

.PARAMETER TestPath
    The path containing files that should have been signed. Defaults to "test-scripts".

.PARAMETER TestCertThumbprint
    The thumbprint of the test certificate to check for cleanup.

.EXAMPLE
    Verify-CodeSigningResults.ps1 -TestPath "test-scripts" -TestCertThumbprint "ABC123..."
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestPath = "test-scripts",
    
    [Parameter()]
    [string]$TestCertThumbprint
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
        
        if ($sig.Status -in @('Valid', 'UnknownError') -and $sig.SignerCertificate -and (-not $TestCertThumbprint -or $sig.SignerCertificate.Thumbprint -eq $TestCertThumbprint)) {
            $signedCount++
        }
    }
    
    if ($signedCount -eq $files.Count) {
        Write-Host "[OK] All PowerShell files successfully signed ($signedCount/$($files.Count))" -ForegroundColor Green
    } else {
        throw "Only $signedCount out of $($files.Count) files were successfully signed"
    }
    
    # Verify certificate was cleaned up if thumbprint provided
    if ($TestCertThumbprint) {
        $cert = Get-ChildItem "Cert:\CurrentUser\My\$TestCertThumbprint" -ErrorAction SilentlyContinue
        if ($cert) {
            Write-Warning "Certificate was not cleaned up as expected"
        } else {
            Write-Host "[OK] Certificate was properly cleaned up" -ForegroundColor Green
        }
    }
    
} catch {
    Write-Error "Code signing verification failed: $_"
    exit 1
}