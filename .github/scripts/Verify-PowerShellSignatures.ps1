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

.PARAMETER AllowUntrustedRoot
    Accept signatures with status UnknownError only when the signer thumbprint
    matches the expected certificate and the status message indicates an
    untrusted root.

.PARAMETER ExpectCertificateCleanup
    Validates that the expected certificate thumbprint is no longer present.

.EXAMPLE
    Verify-PowerShellSignatures.ps1 -Path "test-scripts" -ExpectedThumbprint $env:TEST_CERT_THUMBPRINT

.EXAMPLE
    Verify-PowerShellSignatures.ps1 -Path "test-scripts" -ExpectedThumbprint $env:TEST_CERT_THUMBPRINT -AllowUntrustedRoot
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
    [string[]]$AcceptedStatuses = @('Valid'),

    [Parameter()]
    [switch]$AllowUntrustedRoot,

    [Parameter()]
    [switch]$ExpectCertificateCleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-TargetFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
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
        return [System.IO.FileInfo[]]@($files)
    }

    return [System.IO.FileInfo[]]@($files | Where-Object {
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

    if ($AllowUntrustedRoot -and -not $ExpectedThumbprint) {
        throw 'AllowUntrustedRoot requires ExpectedThumbprint so the signer thumbprint can be verified'
    }

    $files = Get-TargetFile -SearchPath $Path -Patterns $IncludePatterns -ExcludedDirectories $ExcludeDirs
    if ($files.Count -eq 0) {
        throw "No matching PowerShell files found in $Path"
    }

    $signedCount = 0
    $untrustedRootMessagePattern = 'terminated in a root certificate which is not trusted by the trust provider'

    foreach ($file in $files) {
        $sig = Get-AuthenticodeSignature -FilePath $file.FullName
        $signerThumbprint = if ($sig.SignerCertificate) { $sig.SignerCertificate.Thumbprint } else { 'None' }
        Write-Host "File: $($file.FullName)" -ForegroundColor Gray
        Write-Host "  Status: $($sig.Status)" -ForegroundColor Gray
        Write-Host "  Signer Thumbprint: $signerThumbprint" -ForegroundColor Gray

        $isAcceptedStatus = $sig.Status -in $AcceptedStatuses
        if (
            -not $isAcceptedStatus -and
            $AllowUntrustedRoot -and
            $sig.Status -eq 'UnknownError' -and
            $sig.StatusMessage -match $untrustedRootMessagePattern -and
            $sig.SignerCertificate -and
            $ExpectedThumbprint -and
            $sig.SignerCertificate.Thumbprint -eq $ExpectedThumbprint
        ) {
            $isAcceptedStatus = $true
        }

        if (
            $isAcceptedStatus -and
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