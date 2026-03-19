#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sign PowerShell files with code-signing certificate and optionally clean up.

.DESCRIPTION
    This script signs all PowerShell files (.ps1, .psm1, .psd1) using a code-signing certificate.
    Can target a specific certificate by thumbprint and automatically clean it up after signing.

.PARAMETER Path
    Root path to search for PowerShell files. Defaults to current directory.

.PARAMETER TimestampServer
    URL of the timestamp server for timestamping signatures.
    Default is http://timestamp.digicert.com

.PARAMETER Recurse
    Search for files recursively in subdirectories.

.PARAMETER FileMatch
    Array of file patterns to match for signing. Default is *.ps1, *.psm1, *.psd1

.PARAMETER CertThumbprint
    Specific certificate thumbprint to use. If not provided, uses IMPORTED_CERT_THUMBPRINT environment variable or any available code-signing certificate.

.PARAMETER CleanupCertificate
    Remove the certificate from the certificate store after signing.

.PARAMETER TestOnly
    Perform a dry run to list files that would be signed without actually signing them. Return 1 if differences are found, 0 if no differences.

.PARAMETER FailOnInvalid
    When testing signatures, throw an error if any files have invalid signatures.

.EXAMPLE
    Sign-PowerShellFiles.ps1 -CleanupCertificate

.EXAMPLE
    Sign-PowerShellFiles.ps1 -Path "C:\Scripts" -CertThumbprint "ABC123..." -CleanupCertificate
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = $env:GITHUB_WORKSPACE ? $env:GITHUB_WORKSPACE : ".",

    [Parameter()]
    [string]$TimestampServer = ($env:TIMESTAMP_SERVER) ? $env:TIMESTAMP_SERVER : "http://timestamp.digicert.com",

    [Parameter()]
    [switch]$Recurse,

    [Parameter()]
    [string[]]$FileMatch = @("*.ps1", "*.psm1", "*.psd1"),

    [Parameter()]
    [string[]]$ExcludeDirs = @(),

    [Parameter()]
    [string]$CertThumbprint = $env:IMPORTED_CERT_THUMBPRINT,

    [Parameter()]
    [switch]$CleanupCertificate,

    [Parameter()]
    [switch]$TestOnly,

    [Parameter()]
    [switch]$FailOnInvalid
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\shared\GitHubActions.Common.psm1') -Force

$FileMatch = Get-StringArrayParameterFromEnvironment -BoundParameters $PSBoundParameters -ParameterName 'FileMatch' -EnvironmentVariableName 'FILE_MATCH' -CurrentValue $FileMatch
$ExcludeDirs = Get-StringArrayParameterFromEnvironment -BoundParameters $PSBoundParameters -ParameterName 'ExcludeDirs' -EnvironmentVariableName 'EXCLUDE_DIRS' -CurrentValue $ExcludeDirs


#region Helper Functions

function Get-CodeSigningCertificate {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$CertThumbprint
    )

    if ($CertThumbprint) {
        $cert = Get-ChildItem Cert:\CurrentUser\My\$CertThumbprint -ErrorAction SilentlyContinue
        if (-not $cert) {
            throw "Certificate with thumbprint $CertThumbprint not found in Cert:\CurrentUser\My"
        }
    } else {
        $cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
        if (-not $cert) {
            throw "No code-signing certificate available in Cert:\CurrentUser\My"
        }
    }

    Write-Host "Using certificate: $($cert.Subject) (Thumbprint: $($cert.Thumbprint))" -ForegroundColor Gray
    return $cert
}

function Test-PathMatchesExcludedDirectory {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [string[]]$ExcludeDirs = @()
    )

    # Normalize paths to use forward slashes for consistent comparison
    # This only affects the comparison logic and does not change any actual file paths used elsewhere
    $normalizedRelativePath = $RelativePath.Replace([System.IO.Path]::DirectorySeparatorChar, '/')
    $pathSegments = $normalizedRelativePath -split '/'

    foreach ($excludeDir in $ExcludeDirs) {
        $normalizedExcludeDir = $excludeDir.Trim().Replace([System.IO.Path]::DirectorySeparatorChar, '/').Trim('/')
        if ([string]::IsNullOrWhiteSpace($normalizedExcludeDir)) {
            continue
        }

        if ($normalizedRelativePath -eq $normalizedExcludeDir -or $normalizedRelativePath.StartsWith("$normalizedExcludeDir/")) {
            return $excludeDir
        }

        if ($pathSegments -contains $normalizedExcludeDir) {
            return $excludeDir
        }
    }

    return $null
}

function Find-PowerShellFile {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [array]$FileMatch = @("*.ps1", "*.psm1", "*.psd1"),

        [Parameter()]
        [string[]]$ExcludeDirs = @()
    )

    $searchParams = @{
        Path = $Path
        File = $true
    }
    if ($Recurse) {
        $searchParams.Recurse = $true
    }

    $resolvedPath = (Resolve-Path $Path).Path

    [string[]]$effectiveExcludeDirs = Get-EffectiveExcludeDirList -ExcludeDirs $ExcludeDirs

    Write-Host "Searching for PowerShell files in: $resolvedPath" -ForegroundColor Gray
    if ($effectiveExcludeDirs.Count -gt 0) {
        Write-Host "  Excluding directories: $($effectiveExcludeDirs -join ', ')" -ForegroundColor Gray
    }

    $files = foreach ($pattern in $FileMatch) {
        Get-ChildItem @searchParams -Filter $pattern | Where-Object {
            $filePath = $_.FullName
            $relativePath = [System.IO.Path]::GetRelativePath($resolvedPath, $filePath)
            $matchedExcludeDir = Test-PathMatchesExcludedDirectory -RelativePath $relativePath -ExcludeDirs $effectiveExcludeDirs
            if ($matchedExcludeDir) {
                Write-Host "Excluding file in directory '$matchedExcludeDir': $relativePath" -ForegroundColor Yellow
                return $false
            }

            return $true
        }
    }
    $files = [System.IO.FileInfo[]]@($files)

    if ($files.Count -eq 0) {
        throw "No PowerShell files found to sign in path: $Path"
    }

    Write-Host "Found $($files.Count) PowerShell file(s)" -ForegroundColor Gray
    return [System.IO.FileInfo[]]$files
}

function Test-PowerShellFileSignature {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files,

        [Parameter()]
        [switch]$FailOnInvalid
    )

    $validSignatures = @()
    $invalidSignatures = @()

    foreach ($file in $Files) {
        try {
            $sig = Get-AuthenticodeSignature -FilePath $file.FullName

            if ($sig.Status -eq 'Valid') {
                Write-Host "$($file.Name)" -ForegroundColor Green
                $validSignatures += [PSCustomObject]@{
                    File = $file.FullName
                    Status = $sig.Status
                    SignerCertificate = $sig.SignerCertificate.Subject
                    TimeStamperCertificate = if ($sig.TimeStamperCertificate) { $sig.TimeStamperCertificate.Subject } else { "None" }
                }
            } else {
                Write-Warning "$($file.Name) - Status: $($sig.Status)"
                if ($sig.StatusMessage) {
                    Write-Warning "    Message: $($sig.StatusMessage)"
                }

                $invalidSignatures += [PSCustomObject]@{
                    File = $file.FullName
                    Status = $sig.Status
                    Message = $sig.StatusMessage
                    SignerCertificate = if ($sig.SignerCertificate) { $sig.SignerCertificate.Subject } else { "None" }
                }
            }
        } catch {
            Write-Warning "Error checking $($file.Name): $_"
            $invalidSignatures += [PSCustomObject]@{
                File = $file.FullName
                Status = "Error"
                Message = $_.Exception.Message
                SignerCertificate = "None"
            }
        }
    }

    Write-Host "`nSignature Verification Summary:" -ForegroundColor Cyan
    Write-Host "  Total files checked: $($Files.Count)" -ForegroundColor Gray
    Write-Host "  Valid signatures: $($validSignatures.Count)" -ForegroundColor Green
    Write-Host "  Invalid/Missing signatures: $($invalidSignatures.Count)" -ForegroundColor $(if ($invalidSignatures.Count -gt 0) { 'Red' } else { 'Gray' })

    if ($invalidSignatures.Count -gt 0 -AND $FailOnInvalid) {
        throw "Signature verification failed: $($invalidSignatures.Count) files have invalid or missing signatures"
    } elseif ($invalidSignatures.Count -eq 0) {
        Write-Host "All PowerShell files have valid signatures" -ForegroundColor Green
    } else {
        Write-Host "Some PowerShell files are unsigned or have invalid signatures" -ForegroundColor Yellow
    }

    if ($validSignatures.Count -gt 0) {
        Write-Host "`nValid Signature Details:" -ForegroundColor Gray
        $validSignatures | ForEach-Object {
            Write-Host "  $(Split-Path $_.File -Leaf): $($_.SignerCertificate)" -ForegroundColor Gray
        }
    }

    return @{
        ValidSignatures = $validSignatures
        InvalidSignatures = $invalidSignatures
        TotalFiles = $Files.Count
    }
}

function Invoke-PowerShellFileSigning {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileInfo[]]$Files,

        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter()]
        [string]$TimestampServer = "http://timestamp.digicert.com"
    )

    $acceptableStatuses = @('Valid', 'UnknownError')

    $signedCount = 0
    $failedCount = 0

    foreach ($file in $Files) {
        try {
            Write-Host "Signing: $($file.Name)" -ForegroundColor Yellow

            $sig = Set-AuthenticodeSignature -FilePath $file.FullName -Certificate $Certificate -TimestampServer $TimestampServer

            if ($sig.Status -in $acceptableStatuses -and $sig.SignerCertificate -and $sig.SignerCertificate.Thumbprint -eq $Certificate.Thumbprint) {
                Write-Host "  Success" -ForegroundColor Green
                $signedCount++
            } else {
                Write-Warning "  Failed - Status: $($sig.Status), Message: $($sig.StatusMessage)"
                $failedCount++
            }
        } catch {
            Write-Warning "  Exception signing $($file.Name): $_"
            $failedCount++
        }
    }

    # Summary
    Write-Host "`nSigning Summary:" -ForegroundColor Cyan
    Write-Host "  Successfully signed: $signedCount files" -ForegroundColor Green
    Write-Host "  Failed to sign: $failedCount files" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Gray' })

    if ($failedCount -gt 0) {
        throw "Failed to sign $failedCount out of $($Files.Count) PowerShell files"
    }

    Write-Host "All PowerShell files signed successfully" -ForegroundColor Green

    return @{
        SignedCount = $signedCount
        FailedCount = $failedCount
        TotalFiles = $Files.Count
    }
}

#endregion

$cert = $null
$exitCode = 0

try {
    Write-Host "Starting PowerShell file signing process..." -ForegroundColor Cyan

    $files = Find-PowerShellFile -Path $Path -Recurse:$Recurse -FileMatch $FileMatch -ExcludeDirs $ExcludeDirs

    if ($TestOnly) {
        $signatureResults = Test-PowerShellFileSignature -Files $files -FailOnInvalid:$FailOnInvalid
        if ($signatureResults.InvalidSignatures.Count -gt 0) {
            Write-Host "Test mode detected unsigned or invalid files" -ForegroundColor Yellow
            $exitCode = 1
        } else {
            Write-Host "Test mode confirmed all matching files are already signed" -ForegroundColor Green
        }
    } else {
        $cert = Get-CodeSigningCertificate -CertThumbprint $CertThumbprint
        $null = Invoke-PowerShellFileSigning -Files $files -Certificate $cert -TimestampServer $TimestampServer
    }

} catch {
    $exitCode = 1
    Write-Host "PowerShell file signing failed: $_" -ForegroundColor Red
} finally {
    if ($CleanupCertificate -and $cert) {
        try {
            Write-Host "Cleaning up certificate: $($cert.Thumbprint)" -ForegroundColor Yellow
            Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
            Write-Host "Certificate removed successfully" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to remove certificate: $_"
        }
    }

    Write-Host "PowerShell file signing process completed." -ForegroundColor Cyan
    exit $exitCode
}
