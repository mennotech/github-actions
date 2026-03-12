#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests deployed application functionality in integration tests.

.DESCRIPTION
    Executes the deployed PowerShell scripts to verify they work correctly
    after the complete signing and deployment workflow.

.PARAMETER DeployPath
    The path where the application was deployed. Defaults to "C:\temp\integration-test-deploy".

.EXAMPLE
    Test-DeployedApplication.ps1 -DeployPath "C:\temp\integration-test-deploy"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DeployPath = "C:\temp\integration-test-deploy"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Testing deployed application functionality..." -ForegroundColor Cyan
    
    # Test main.ps1 execution
    Write-Host "Testing main.ps1..." -ForegroundColor Yellow
    try {
        & "$DeployPath\main.ps1" -Message "Integration test execution"
        Write-Host "[OK] main.ps1 executed successfully" -ForegroundColor Green
    } catch {
        throw "Failed to execute main.ps1: $_"
    }
    
    # Test helper script with module import
    Write-Host "Testing helper.ps1 with module import..." -ForegroundColor Yellow
    try {
        & "$DeployPath\scripts\helper.ps1"
        Write-Host "[OK] helper.ps1 executed successfully" -ForegroundColor Green
    } catch {
        throw "Failed to execute helper.ps1: $_"
    }
    
    Write-Host "[OK] All deployed scripts execute correctly" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to test deployed application: $_"
    exit 1
}