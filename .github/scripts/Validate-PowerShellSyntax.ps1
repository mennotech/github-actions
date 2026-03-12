#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validates PowerShell syntax across the repository.

.DESCRIPTION
    Checks all PowerShell files (.ps1, .psm1, .psd1) for syntax errors using PowerShell's parser.

.EXAMPLE
    Validate-PowerShellSyntax.ps1
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating PowerShell syntax..." -ForegroundColor Yellow
    
    # Find all PowerShell files
    $psFiles = Get-ChildItem -Path "." -Include "*.ps1", "*.psm1", "*.psd1" -Recurse | Where-Object {
        $_.FullName -notmatch '\\\.git\\'
    }
    
    Write-Host "Found $($psFiles.Count) PowerShell files to validate" -ForegroundColor Gray
    
    if ($psFiles.Count -eq 0) {
        Write-Host "[Warning] No PowerShell files found to validate" -ForegroundColor Yellow
        return
    }
    
    $hasErrors = $false
    $errorCount = 0
    $warningCount = 0
    
    foreach ($file in $psFiles) {
        Write-Host "Validating: $($file.Name)" -ForegroundColor Gray
        
        try {
            # Parse the PowerShell file
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $file.FullName, [ref]$tokens, [ref]$errors
            )
            
            if ($errors.Count -eq 0) {
                Write-Host "[OK] $($file.Name) - syntax valid" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] $($file.Name) has syntax errors:" -ForegroundColor Red
                foreach ($one_error in $errors) {
                    Write-Host "  Line $($one_error.Extent.StartLineNumber): $($one_error.Message)" -ForegroundColor Red
                    $errorCount++
                }
                $hasErrors = $true
            }
            
            # Check for common PowerShell best practices
            $content = Get-Content -Path $file.FullName -Raw
            
            # Check for CmdletBinding on functions
            if ($content -match 'function\s+\w+' -and $content -notmatch '\[CmdletBinding\(\)\]') {
                Write-Host "[Warning] $($file.Name): Consider adding [CmdletBinding()] to functions" -ForegroundColor Yellow
                $warningCount++
            }
            
            # Check for proper error handling
            if ($content -notmatch '\$ErrorActionPreference') {
                Write-Host "[Warning] $($file.Name): Consider setting ErrorActionPreference" -ForegroundColor Yellow
                $warningCount++
            }
            
        } catch {
            Write-Host "[ERROR] $($file.Name): Failed to parse - $_" -ForegroundColor Red
            $hasErrors = $true
            $errorCount++
        }
    }
    
    Write-Host "`nValidation Summary:" -ForegroundColor Cyan
    Write-Host "  PowerShell files: $($psFiles.Count)" -ForegroundColor Gray
    Write-Host "  Syntax errors: $errorCount" -ForegroundColor Gray
    Write-Host "  Warnings: $warningCount" -ForegroundColor Gray
    
    if ($hasErrors) {
        Write-Host "`n[ERROR] PowerShell syntax validation failed" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "`n[OK] All PowerShell files passed syntax validation" -ForegroundColor Green
        if ($warningCount -gt 0) {
            Write-Host "Note: $warningCount warnings found (non-blocking)" -ForegroundColor Yellow
        }
    }
    
} catch {
    Write-Error "Failed to validate PowerShell syntax: $_"
    exit 1
}