#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies deployment results and cleans up test directories.

.DESCRIPTION
    Checks that expected files were deployed and excluded files were not deployed.
    Cleans up the test deployment directory.

.PARAMETER DestinationPath
    The path where files were deployed. Defaults to "C:\temp\deploy-test".

.EXAMPLE
    Verify-DeploymentResults.ps1 -DestinationPath "C:\temp\deploy-test"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DestinationPath = "C:\temp\deploy-test"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Verifying deployment results..." -ForegroundColor Yellow
    
    # Check that expected files were deployed
    $expectedFiles = @(
        "main.ps1",
        "config.txt", 
        "scripts\subscript.ps1"
    )
    
    $deployedCount = 0
    foreach ($expectedFile in $expectedFiles) {
        $fullPath = Join-Path $DestinationPath $expectedFile
        if (Test-Path $fullPath) {
            Write-Host "[OK] Found: $expectedFile" -ForegroundColor Green
            $deployedCount++
        } else {
            Write-Host "[ERROR] Missing: $expectedFile" -ForegroundColor Red
        }
    }
    
    # Check that excluded files were NOT deployed  
    $excludedFiles = @(
        ".git\config",
        ".github\workflow.yml",
        "test.crt",
        "Config.json"
    )
    
    $properlyExcluded = 0
    foreach ($excludedFile in $excludedFiles) {
        $fullPath = Join-Path $DestinationPath $excludedFile
        if (-not (Test-Path $fullPath)) {
            Write-Host "[OK] Properly excluded: $excludedFile" -ForegroundColor Green
            $properlyExcluded++
        } else {
            Write-Host "[ERROR] Should have been excluded: $excludedFile" -ForegroundColor Red
        }
    }
    
    # Summary
    Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
    Write-Host "  Expected files deployed: $deployedCount/$($expectedFiles.Count)" -ForegroundColor Gray
    Write-Host "  Files properly excluded: $properlyExcluded/$($excludedFiles.Count)" -ForegroundColor Gray
    
    if ($deployedCount -eq $expectedFiles.Count -and $properlyExcluded -eq $excludedFiles.Count) {
        Write-Host "[OK] Deploy action test passed" -ForegroundColor Green
    } else {
        throw "Deploy action test failed: not all files handled correctly"
    }
    
    # Clean up
    if (Test-Path $DestinationPath) {
        Remove-Item $DestinationPath -Recurse -Force
        Write-Host "[OK] Test deployment directory cleaned up" -ForegroundColor Green
    }
    
} catch {
    Write-Error "Failed to verify deployment results: $_"
    exit 1
}