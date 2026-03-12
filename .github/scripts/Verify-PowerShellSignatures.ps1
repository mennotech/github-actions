#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verifies PowerShell file signatures and certificate cleanup.

.DESCRIPTION
    Checks that all matching PowerShell files in the specified path have accepted
    signatures and optionally verifies certificate cleanup.

.PARAMETER Path
    The path containing PowerShell files to verify. Defaults to "test-scripts".

.PARAMETER IncludePatterns
    File patterns used to select PowerShell files.

.PARAMETER ExcludeDirs
    Directory names to exclude from verification.

.PARAMETER ExpectedThumbprint
    Expected signing certificate thumbprint.

.PARAMETER AcceptedStatuses
    Signature statuses that are accepted as passing.

.PARAMETER ExpectCertificateCleanup
    Validates that the expected certificate thumbprint is no longer present.

.EXAMPLE
    Verify-PowerShellSignatures.ps1 -Path "test-scripts" -ExpectedThumbprint $env:TEST_CERT_THUMBPRINT
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = 'test-scripts',

    [Parameter()]
    [string[]]$IncludePatterns = @('*.ps1', '*.psm1', '*.psd1'),

    [Parameter()]
    [string[]]$ExcludeDirs = @(),

    [Parameter()]
    [string]$ExpectedThumbprint = $env:TEST_CERT_THUMBPRINT,

    [Parameter()]
    [string[]]$AcceptedStatuses = @('Valid', 'UnknownError'),

    [Parameter()]
    [switch]$ExpectCertificateCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TargetFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SearchPath,

        [Parameter(Mandatory)]
        [string[]]$Patterns,

        [Parameter()]
        [string[]]$ExcludedDirectories = @()
    )

    $files = foreach ($pattern in $Patterns) {
        Get-ChildItem -Path $SearchPath -Filter $pattern -File -Recurse
    }

    if ($ExcludedDirectories.Count -eq 0) {
        return @($files)
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
    Write-Host "Verifying PowerShell file signatures..." -ForegroundColor Yellow

    $files = Get-TargetFiles -SearchPath $Path -Patterns $IncludePatterns -ExcludedDirectories $ExcludeDirs
    if ($files.Count -eq 0) {
        throw "No matching PowerShell files found in $Path"
    }

    $signedCount = 0

    foreach ($file in $files) {
        $sig = Get-AuthenticodeSignature -FilePath $file.FullName
        $signerThumbprint = if ($sig.SignerCertificate) { $sig.SignerCertificate.Thumbprint } else { 'None' }
        Write-Host "File: $($file.FullName)" -ForegroundColor Gray
        Write-Host "  Status: $($sig.Status)" -ForegroundColor Gray
        Write-Host "  Signer Thumbprint: $signerThumbprint" -ForegroundColor Gray

        if (
            $sig.Status -in $AcceptedStatuses -and
            $sig.SignerCertificate -and
            (-not $ExpectedThumbprint -or $sig.SignerCertificate.Thumbprint -eq $ExpectedThumbprint)
        ) {
            $signedCount++
        }
    }

    if ($signedCount -eq $files.Count) {
        Write-Host "[OK] All PowerShell files successfully signed ($signedCount/$($files.Count))" -ForegroundColor Green
    } else {
        throw "Only $signedCount out of $($files.Count) files were successfully signed"
    }

    if ($ExpectCertificateCleanup -and $ExpectedThumbprint) {
        $cert = Get-ChildItem "Cert:\CurrentUser\My\$ExpectedThumbprint" -ErrorAction SilentlyContinue
        if ($cert) {
            throw "Certificate cleanup verification failed for thumbprint $ExpectedThumbprint"
        } else {
            Write-Host "[OK] Certificate was properly cleaned up" -ForegroundColor Green
        }
    }
} catch {
    Write-Error "Failed to verify PowerShell signatures: $_"
    exit 1
}