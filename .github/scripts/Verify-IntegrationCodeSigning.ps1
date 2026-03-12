#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies code signing results for integration testing.

.DESCRIPTION
    Checks that all PowerShell files in the test project were properly signed with valid signatures.

.PARAMETER ProjectPath
    The path to the test project. Defaults to "test-project".

.EXAMPLE
    Verify-IntegrationCodeSigning.ps1 -ProjectPath "test-project"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectPath = "test-project"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Verifying PowerShell files were signed..." -ForegroundColor Yellow
    
    # Find all PowerShell files that should have been signed
    $psFiles = Get-ChildItem -Path $ProjectPath -Include "*.ps1", "*.psm1", "*.psd1" -Recurse | Where-Object {
        $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\\.github\\'
    }
    
    Write-Host "Found $($psFiles.Count) PowerShell files to verify" -ForegroundColor Gray
    
    $signedCount = 0
    $validCount = 0
    
    foreach ($file in $psFiles) {
        $sig = Get-AuthenticodeSignature -FilePath $file.FullName
        Write-Host "File: $($file.Name)" -ForegroundColor Gray
        Write-Host "  Status: $($sig.Status)" -ForegroundColor Gray
        Write-Host "  Signer: $($sig.SignerCertificate.Subject)" -ForegroundColor Gray
        
        if ($sig.Status -ne 'NotSigned') {
            $signedCount++
        }
        if ($sig.Status -eq 'Valid') {
            $validCount++
        }
    }
    
    Write-Host "`nSigning Summary:" -ForegroundColor Cyan
    Write-Host "  PowerShell files found: $($psFiles.Count)" -ForegroundColor Gray
    Write-Host "  Files signed: $signedCount" -ForegroundColor Gray  
    Write-Host "  Valid signatures: $validCount" -ForegroundColor Gray
    
    if ($validCount -eq $psFiles.Count -and $psFiles.Count -gt 0) {
        Write-Host "[OK] All PowerShell files successfully signed with valid signatures" -ForegroundColor Green
    } else {
        throw "Code signing failed: Expected $($psFiles.Count) valid signatures, got $validCount"
    }
    
} catch {
    Write-Error "Failed to verify code signing results: $_"
    exit 1
}