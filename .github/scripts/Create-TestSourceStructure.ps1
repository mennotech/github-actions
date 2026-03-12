#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates test source directory structure for deployment testing.

.DESCRIPTION
    Creates a directory structure with various file types including files that should
    be deployed and files that should be excluded from deployment.

.PARAMETER SourcePath
    The path where the test source structure should be created. Defaults to "test-source".

.EXAMPLE
    Create-TestSourceStructure.ps1 -SourcePath "test-source"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourcePath = "test-source"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Creating test source directory structure..." -ForegroundColor Cyan
    
    # Create source directory with various file types
    New-Item -ItemType Directory -Path $SourcePath -Force | Out-Null
    New-Item -ItemType Directory -Path "$SourcePath\.git" -Force | Out-Null
    New-Item -ItemType Directory -Path "$SourcePath\.github" -Force | Out-Null
    New-Item -ItemType Directory -Path "$SourcePath\scripts" -Force | Out-Null
    
    # Create files to deploy
    "Main script content" | Out-File -FilePath "$SourcePath\main.ps1" -Encoding UTF8
    "Configuration content" | Out-File -FilePath "$SourcePath\config.txt" -Encoding UTF8
    "Subscript content" | Out-File -FilePath "$SourcePath\scripts\subscript.ps1" -Encoding UTF8
    
    # Create files that should be excluded
    "Git file" | Out-File -FilePath "$SourcePath\.git\config" -Encoding UTF8
    "GitHub workflow" | Out-File -FilePath "$SourcePath\.github\workflow.yml" -Encoding UTF8
    "Certificate file" | Out-File -FilePath "$SourcePath\test.crt" -Encoding UTF8
    "Config JSON" | Out-File -FilePath "$SourcePath\Config.json" -Encoding UTF8
    
    Write-Host "[OK] Test source structure created" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to create test source structure: $_"
    exit 1
}