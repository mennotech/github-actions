#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates test PowerShell files for code signing action testing.

.DESCRIPTION
    Creates a directory structure with various PowerShell files and non-PowerShell files
    to test the code signing action behavior.

.PARAMETER TestPath
    The path where test files should be created. Defaults to "test-scripts".

.EXAMPLE
    Create-TestPowerShellFilesForSigning.ps1 -TestPath "test-scripts"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$TestPath = "test-scripts"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating test PowerShell files..." -ForegroundColor Cyan
    
    # Create test directory structure
    New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$TestPath\subdir" -Force | Out-Null
    
    # Create test .ps1 files
    "# Test PowerShell script 1`nWrite-Host 'Hello from test script 1'" | Out-File -FilePath "$TestPath\test1.ps1" -Encoding UTF8
    
    "# Test PowerShell script 2`nWrite-Host 'Hello from test script 2'" | Out-File -FilePath "$TestPath\test2.ps1" -Encoding UTF8
    
    "# Test PowerShell module`nfunction Test-Function { Write-Host 'Hello from test function' }" | Out-File -FilePath "$TestPath\TestModule.psm1" -Encoding UTF8
    
    "# Test PowerShell script in subdirectory`nWrite-Host 'Hello from subdirectory script'" | Out-File -FilePath "$TestPath\subdir\test3.ps1" -Encoding UTF8
    
    # Create non-PowerShell file that should be ignored
    "This is not a PowerShell file" | Out-File -FilePath "$TestPath\readme.txt" -Encoding UTF8
    
    Write-Host "[OK] Test PowerShell files created" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test PowerShell files for signing: $_"
    exit 1
}