#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies deployment results and cleans up test directories.

.DESCRIPTION
    Checks that expected files were deployed and excluded files were not deployed.
    Can also verify that deployed PowerShell files remain signed.

.PARAMETER DestinationPath
    The path where files were deployed. Defaults to "C:\temp\deploy-test".

.PARAMETER ExpectedFiles
    Files that must exist after deployment.

.PARAMETER ExcludedFiles
    Files that must not exist after deployment.

.PARAMETER VerifySignatures
    Verifies signatures on deployed PowerShell files.

.PARAMETER ExpectedThumbprint
    Expected thumbprint for deployed PowerShell file signatures.

.PARAMETER CleanupDestination
    Removes the destination directory after verification.

.EXAMPLE
    Verify-DeploymentResults.ps1 -DestinationPath "C:\temp\deploy-test"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DestinationPath = 'C:\temp\deploy-test',

    [Parameter()]
    [string[]]$ExpectedFiles = @(
        'main.ps1',
        'config.txt',
        'scripts\subscript.ps1'
    ),

    [Parameter()]
    [string[]]$ExcludedFiles = @(
        '.git\config',
        '.github\workflow.yml',
        'test.crt',
        'Config.json'
    ),

    [Parameter()]
    [switch]$VerifySignatures,

    [Parameter()]
    [string]$ExpectedThumbprint,

    [Parameter()]
    [string[]]$SignaturePatterns = @('*.ps1', '*.psm1', '*.psd1'),

    [Parameter()]
    [string[]]$SignatureExcludeDirs = @('.git', '.github'),

    [Parameter()]
    [switch]$CleanupDestination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DeploySignatureFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string[]]$Patterns,

        [Parameter()]
        [string[]]$ExcludedDirectories = @()
    )

    $files = foreach ($pattern in $Patterns) {
        Get-ChildItem -Path $Path -Filter $pattern -File -Recurse
    }

    return @($files | Where-Object {
        $fullPath = $_.FullName
        foreach ($excludedDirectory in $ExcludedDirectories) {
            if ($fullPath -match [regex]::Escape("\\$excludedDirectory\\")) {
                return $false
            }
        }

        return $true
    })
}

try {
    Write-Host "Verifying deployment results..." -ForegroundColor Yellow

    $deployedCount = 0
    foreach ($expectedFile in $ExpectedFiles) {
        $fullPath = Join-Path $DestinationPath $expectedFile
        if (Test-Path $fullPath) {
            Write-Host "[OK] Found: $expectedFile" -ForegroundColor Green
            $deployedCount++
        } else {
            Write-Host "[ERROR] Missing: $expectedFile" -ForegroundColor Red
        }
    }

    $properlyExcluded = 0
    foreach ($excludedFile in $ExcludedFiles) {
        $fullPath = Join-Path $DestinationPath $excludedFile
        if (-not (Test-Path $fullPath)) {
            Write-Host "[OK] Properly excluded: $excludedFile" -ForegroundColor Green
            $properlyExcluded++
        } else {
            Write-Host "[ERROR] Should have been excluded: $excludedFile" -ForegroundColor Red
        }
    }

    Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
    Write-Host "  Expected files deployed: $deployedCount/$($ExpectedFiles.Count)" -ForegroundColor Gray
    Write-Host "  Files properly excluded: $properlyExcluded/$($ExcludedFiles.Count)" -ForegroundColor Gray

    if ($deployedCount -ne $ExpectedFiles.Count -or $properlyExcluded -ne $ExcludedFiles.Count) {
        throw 'Deploy action test failed: not all files handled correctly'
    }

    if ($VerifySignatures) {
        $signatureFiles = Get-DeploySignatureFiles -Path $DestinationPath -Patterns $SignaturePatterns -ExcludedDirectories $SignatureExcludeDirs
        if ($signatureFiles.Count -eq 0) {
            throw 'No deployed PowerShell files found for signature verification'
        }

        foreach ($file in $signatureFiles) {
            $signature = Get-AuthenticodeSignature -FilePath $file.FullName
            if (
                $signature.Status -notin @('Valid', 'UnknownError') -or
                -not $signature.SignerCertificate -or
                ($ExpectedThumbprint -and $signature.SignerCertificate.Thumbprint -ne $ExpectedThumbprint)
            ) {
                throw "Invalid signature found on deployed file: $($file.FullName)"
            }
        }

        Write-Host "[OK] Deployed PowerShell files retained valid signatures" -ForegroundColor Green
    }

    Write-Host "[OK] Deploy action test passed" -ForegroundColor Green

    if ($CleanupDestination -and (Test-Path $DestinationPath)) {
        Remove-Item $DestinationPath -Recurse -Force
        Write-Host "[OK] Test deployment directory cleaned up" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to verify deployment results: $_"
    exit 1
}