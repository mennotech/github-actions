#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates YAML syntax in the repository.

.DESCRIPTION
    Uses yamllint to validate all YAML files in the repository for syntax errors.

.EXAMPLE
    Validate-YAMLSyntax.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating YAML syntax..." -ForegroundColor Yellow
    
    # Find all YAML files
    $yamlFiles = Get-ChildItem -Path "." -Include "*.yml", "*.yaml" -Recurse | Where-Object {
        $_.FullName -notmatch '\\\.git\\'
    }
    
    Write-Host "Found $($yamlFiles.Count) YAML files to validate" -ForegroundColor Gray
    
    if ($yamlFiles.Count -eq 0) {
        Write-Host "[Warning] No YAML files found to validate" -ForegroundColor Yellow
        return
    }
    
    # Check if yamllint is available
    $yamllint = Get-Command yamllint -ErrorAction SilentlyContinue
    if (-not $yamllint) {
        Write-Host "Installing yamllint..." -ForegroundColor Gray
        pip install yamllint
    }
    
    $hasErrors = $false
    
    foreach ($file in $yamlFiles) {
        Write-Host "Validating: $($file.FullName)" -ForegroundColor Gray
        $result = yamllint $file.FullName 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] $($file.Name)" -ForegroundColor Green
        } else {
            Write-Host "[ERROR] $($file.Name):" -ForegroundColor Red
            Write-Host $result -ForegroundColor Red
            $hasErrors = $true
        }
    }
    
    if ($hasErrors) {
        Write-Host "`n[ERROR] YAML validation failed" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n[OK] All YAML files passed syntax validation" -ForegroundColor Green
    }
    
} catch {
    Write-Error "Failed to validate YAML syntax: $_"
    exit 1
}