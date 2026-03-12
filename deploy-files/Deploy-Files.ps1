#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy files to target directory using robocopy.

.DESCRIPTION
    This script mirrors the source directory to a destination directory,
    excluding development-related folders and files. It includes permission
    checking and proper error handling for robocopy operations.

.PARAMETER SourcePath
    Source directory to copy from. Defaults to current directory.

.PARAMETER DestinationPath
    Target directory to copy to.

.PARAMETER ExcludeDirs
    Directories to exclude from the copy operation.

.PARAMETER ExcludeFiles
    Files to exclude from the copy operation.

.PARAMETER RobocopyOptions
    Additional options to pass to robocopy.

.PARAMETER TestOnly
    Perform a dry run to list files that would be copied without actually copying them. Return 1 if differences are found, 0 if no differences.

.EXAMPLE
    Deploy-Scripts.ps1 -DestinationPath "C:\Scripts\exchange-apply-address-book-policy"
    
.EXAMPLE
    Deploy-Scripts.ps1 -SourcePath "." -DestinationPath "C:\Scripts\MyApp" -ExcludeDirs @(".git", ".github")
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$SourcePath = $PWD,
    
    [Parameter()]
    [string]$DestinationPath = ($env:DESTINATION_PATH ? $env:DESTINATION_PATH : (throw "DestinationPath parameter is required. Provide DESTINATION_PATH environment variable or use -DestinationPath parameter.")),
    
    [Parameter()]
    [string[]]$ExcludeDirs = ($env:EXCLUDE_DIRS ? $env:EXCLUDE_DIRS -split ',' : @(".git", ".github", "_work", "logs")),
    
    [Parameter()]
    [string[]]$ExcludeFiles = ($env:EXCLUDE_FILES ? $env:EXCLUDE_FILES -split ',' : @("*.crt", "Config.json")),

    [Parameter()]
    [string[]]$RobocopyOptions = ($env:ROBOCOPY_OPTIONS ? $env:ROBOCOPY_OPTIONS -split ',' : @(
        "/R:2",    # Retry 2 times on failed copies
        "/W:2",    # Wait 2 seconds between retries
        "/NDL",    # Don't log directory names
        "/NFL",    # Don't log file names (reduces noise)
        "/NP"      # Don't show progress percentage
    )),
    
    [Parameter()]
    [switch]$TestOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Starting deployment process..." -ForegroundColor Cyan
    Write-Host "  Source: $SourcePath" -ForegroundColor Gray
    Write-Host "  Destination: $DestinationPath" -ForegroundColor Gray

    # Resolve source path
    $resolvedSource = Resolve-Path $SourcePath -ErrorAction Stop
    Write-Host "  Resolved Source: $($resolvedSource.Path)" -ForegroundColor Gray

    # Create destination directory if it doesn't exist
    if (!(Test-Path $DestinationPath)) { 
        Write-Host "Creating destination directory: $DestinationPath" -ForegroundColor Yellow
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Host "Destination directory created" -ForegroundColor Green
        } catch {
            throw "Failed to create destination directory '$DestinationPath': $_"
        }
    } else {
        Write-Host "Destination directory exists" -ForegroundColor Green
    }

    Write-Host "Testing write permissions to destination..." -ForegroundColor Yellow
    try {
        $testFile = Join-Path $DestinationPath "permission_test_$(Get-Random).tmp"
        "test" | Out-File -FilePath $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        Write-Host "Write permissions verified" -ForegroundColor Green
    } catch {
        throw "No write permissions to destination directory '$DestinationPath': $_"
    }

    Write-Host "Deploying files..." -ForegroundColor Yellow

    # Build robocopy command
    $robocopyArgs = @(
        $resolvedSource.Path,
        $DestinationPath,
        "/MIR"  # Mirror directory tree
    )

    # Add excluded directories
    if ($ExcludeDirs.Count -gt 0) {
        $robocopyArgs += "/XD"
        $robocopyArgs += $ExcludeDirs
        Write-Host "  Excluding directories: $($ExcludeDirs -join ', ')" -ForegroundColor Gray
    }

    # Add excluded files
    if ($ExcludeFiles.Count -gt 0) {
        $robocopyArgs += "/XF"
        $robocopyArgs += $ExcludeFiles
        Write-Host "  Excluding files: $($ExcludeFiles -join ', ')" -ForegroundColor Gray
    }

    # Add additional robocopy options
    $robocopyArgs += $RobocopyOptions
    if ($RobocopyOptions.Count -gt 0) {
        Write-Host "  Additional robocopy options: $($RobocopyOptions -join ' ')" -ForegroundColor Gray
    }

    # Add test-only option
    if ($TestOnly) {
        $robocopyArgs += "/L"  # List only - don't copy
    }

    Write-Host "Executing: robocopy $($robocopyArgs -join ' ')" -ForegroundColor Gray

    # Execute robocopy
    $startTime = Get-Date
    robocopy @robocopyArgs
    $exitCode = $LASTEXITCODE
    $duration = (Get-Date) - $startTime

    Write-Host "Robocopy completed in $([math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor Gray
    Write-Host "Robocopy exit code: $exitCode" -ForegroundColor Gray

    # Interpret robocopy exit codes
    $interpretation = switch ($exitCode) {
        0 { "No files copied (nothing to do)" }
        1 { "All files copied successfully" }
        2 { "Extra files or directories detected and handled" }
        3 { "Some files copied, some extra files detected" }
        4 { "Some mismatched files or directories detected" }
        5 { "Some files copied, some mismatched files detected" }
        6 { "Additional files and mismatched files exist" }  
        7 { "Files copied, additional and mismatched files exist" }
        8 { "Several files did not copy" }
        default { "Error occurred during copy operation" }
    }

    # Determine result color based on exit code
    $resultColor = if ($exitCode -eq 0 -or $exitCode -eq 1) { 'Green' }
                   elseif ($exitCode -le 3) { 'Yellow' }
                   else { 'Red' }
    
    Write-Host "Result: $interpretation" -ForegroundColor $resultColor

    if ($TestOnly) {
        # Ignore exit codes 0 and 2 as they indicate no differences found, or only extra files whichmay be configuration files we don't want to overwrite
        if ($exitCode -eq 0 -OR $exitCode -eq 2) {
            Write-Host "No differences found - deployment is up to date" -ForegroundColor Green
            exit 0
        } else {
            Write-Host "Differences found - deployment is not up to date" -ForegroundColor Red
            exit 1
        }
    }

    # Handle errors
    if ($exitCode -ge 8) { 
        throw "Robocopy failed with exit code $exitCode. $interpretation"
    }

    Write-Host "Deployment completed successfully" -ForegroundColor Green
    # Force exit with code 0 to avoid any issues with robocopy's non-zero exit codes on certain conditions
    exit 0

} catch {
    Write-Error "Deployment failed: $_"
    exit 1
}