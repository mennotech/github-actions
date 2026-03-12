#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cleans up after integration tests.

.DESCRIPTION
    Removes test files, directories, and imported certificates after integration testing.

.PARAMETER TestPath
    The path to test artifacts to clean up. Defaults to "test-project".

.PARAMETER DeployPath
    The path to the deployed integration test output.

.EXAMPLE
    Cleanup-IntegrationTest.ps1 -TestPath "test-project"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestPath = 'test-project',

    [Parameter()]
    [string]$DeployPath = 'C:\temp\integration-test-deploy'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Cleaning up integration test resources..." -ForegroundColor Yellow
    
    # Clean up imported certificates if any
    if ($env:IMPORTED_CERT_THUMBPRINT) {
        Write-Host "Removing imported test certificate: $env:IMPORTED_CERT_THUMBPRINT" -ForegroundColor Gray
        $stores = @(
            "Cert:\CurrentUser\My",
            "Cert:\CurrentUser\TrustedPublisher",
            "Cert:\CurrentUser\Root"
        )

        $removed = $false
        foreach ($storePath in $stores) {
            $cert = Get-ChildItem -Path $storePath -ErrorAction SilentlyContinue | Where-Object { $_.Thumbprint -eq $env:IMPORTED_CERT_THUMBPRINT }
            if ($cert) {
                $cert | Remove-Item -Force
                $removed = $true
                Write-Host "[OK] Certificate removed from $storePath" -ForegroundColor Green
            }
        }

        if (-not $removed) {
            Write-Host "[Warning] Certificate not found in configured stores" -ForegroundColor Yellow
        }
        $env:IMPORTED_CERT_THUMBPRINT = $null
    }
    
    $pathsToRemove = @($TestPath, $DeployPath)
    foreach ($pathToRemove in $pathsToRemove) {
        if (Test-Path $pathToRemove) {
            Write-Host "Removing test directory: $pathToRemove" -ForegroundColor Gray
            Remove-Item -Path $pathToRemove -Recurse -Force
            Write-Host "[OK] Test directory removed" -ForegroundColor Green
        } else {
            Write-Host "[Info] Test directory not found: $pathToRemove" -ForegroundColor Gray
        }
    }

    # Remove any .pfx files in current directory
    $pfxFiles = Get-ChildItem -Path "." -Filter "*.pfx" -File
    if ($pfxFiles) {
        Write-Host "Removing .pfx certificate files..." -ForegroundColor Gray
        $pfxFiles | Remove-Item -Force
        Write-Host "[OK] Removed $($pfxFiles.Count) .pfx files" -ForegroundColor Green
    }
    
    # Remove any other temporary test files
    $tempFiles = @("test-cert.pfx", "test-output.txt", "integration-results.json")
    foreach ($tempFile in $tempFiles) {
        if (Test-Path $tempFile) {
            Remove-Item -Path $tempFile -Force
            Write-Host "[OK] Removed temporary file: $tempFile" -ForegroundColor Green
        }
    }
    
    Write-Host "[OK] Integration test cleanup completed successfully" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to clean up integration test resources: $_"
    exit 1
}