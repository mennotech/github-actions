#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates GitHub Action structure and configuration.

.DESCRIPTION
    Checks that each action directory has a valid action.yml file with required fields
    and proper structure for GitHub Actions.

.EXAMPLE
    Validate-ActionStructure.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating GitHub Action structure..." -ForegroundColor Yellow
    
    # Find all action directories (containing action.yml)
    $actionFiles = Get-ChildItem -Path "." -Name "action.yml" -Recurse | Where-Object {
        $_ -notmatch '\\\.git\\'
    }
    
    Write-Host "Found $($actionFiles.Count) action.yml files" -ForegroundColor Gray
    
    if ($actionFiles.Count -eq 0) {
        Write-Host "[Warning] No action.yml files found" -ForegroundColor Yellow
        return
    }
    
    $hasErrors = $false
    
    foreach ($actionFile in $actionFiles) {
        $actionPath = Split-Path $actionFile
        $actionName = Split-Path $actionPath -Leaf
        
        Write-Host "`nValidating action: $actionName" -ForegroundColor Cyan
        
        try {
            # Load and parse the YAML
            $content = Get-Content -Path $actionFile -Raw
            $yaml = ConvertFrom-Yaml $content
            
            # Check required fields
            $requiredFields = @('name', 'description', 'runs')
            foreach ($field in $requiredFields) {
                if (-not $yaml.$field) {
                    Write-Host "[ERROR] Missing required field '$field' in $actionFile" -ForegroundColor Red
                    $hasErrors = $true
                } else {
                    Write-Host "[OK] Field '$field' present" -ForegroundColor Green
                }
            }
            
            # Check runs configuration
            if ($yaml.runs) {
                if (-not $yaml.runs.using) {
                    Write-Host "[ERROR] Missing 'using' in runs configuration" -ForegroundColor Red
                    $hasErrors = $true
                } else {
                    Write-Host "[OK] Runs using: $($yaml.runs.using)" -ForegroundColor Green
                }
                
                if ($yaml.runs.using -eq 'composite') {
                    if (-not $yaml.runs.steps) {
                        Write-Host "[ERROR] Composite action missing 'steps'" -ForegroundColor Red
                        $hasErrors = $true
                    } else {
                        Write-Host "[OK] Composite steps: $($yaml.runs.steps.Count)" -ForegroundColor Green
                    }
                }
            }
            
            # Check for corresponding PowerShell script
            $expectedScript = Join-Path $actionPath "*.ps1"
            $scriptFiles = Get-ChildItem -Path $expectedScript -File
            if ($scriptFiles.Count -eq 0) {
                Write-Host "[Warning] No PowerShell script found in $actionPath" -ForegroundColor Yellow
            } else {
                Write-Host "[OK] PowerShell scripts: $($scriptFiles.Count)" -ForegroundColor Green
            }
            
        } catch {
            Write-Host "[ERROR] Failed to parse $actionFile : $_" -ForegroundColor Red
            $hasErrors = $true
        }
    }
    
    if ($hasErrors) {
        Write-Host "`n[ERROR] Action structure validation failed" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n[OK] All actions have valid structure" -ForegroundColor Green
    }
    
} catch {
    Write-Error "Failed to validate action structure: $_"
    exit 1
}

# Helper function to parse YAML (simplified)
function ConvertFrom-Yaml {
    param([string]$Content)
    
    # This is a simplified YAML parser - in practice you'd use a proper YAML module
    # For GitHub Actions validation, we mainly care about top-level keys
    $result = @{}
    
    $lines = $Content -split "`n"
    $inRuns = $false
    
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match '^name:\s*(.+)$') {
            $result.name = $matches[1].Trim('"''')
        }
        elseif ($line -match '^description:\s*(.+)$') {
            $result.description = $matches[1].Trim('"''')
        }
        elseif ($line -match '^runs:\s*$') {
            $result.runs = @{}
            $inRuns = $true
        }
        elseif ($inRuns -and $line -match '^\s+using:\s*(.+)$') {
            $result.runs.using = $matches[1].Trim('"''')
        }
        elseif ($inRuns -and $line -match '^\s+steps:\s*$') {
            $result.runs.steps = @(1) # Just indicate steps exist
        }
    }
    
    return $result
}