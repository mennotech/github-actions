#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Converts a newline-separated list of org/repo strings into a compact JSON
    array suitable for use as a GitHub Actions matrix strategy.

.DESCRIPTION
    Reads the DOWNSTREAM_REPOS environment variable (or the DownstreamRepos
    parameter), splits by newline, trims whitespace, discards blank lines, and
    emits a compact JSON array of {owner, repo} objects to GITHUB_OUTPUT.

    Each entry must be in the form "owner/repo". The owner is the first
    path segment and the repo name is the last path segment.

.PARAMETER DownstreamRepos
    Newline-separated list of org/repo strings.
    Defaults to the DOWNSTREAM_REPOS environment variable.

.EXAMPLE
    Build-RepoMatrix.ps1
    # Reads $env:DOWNSTREAM_REPOS and writes matrix=... to $env:GITHUB_OUTPUT

.EXAMPLE
    $env:DOWNSTREAM_REPOS = "myorg/repo-a`nmyorg/repo-b"
    Build-RepoMatrix.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DownstreamRepos = $env:DOWNSTREAM_REPOS
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$matrix = @()

if (-not [string]::IsNullOrWhiteSpace($DownstreamRepos)) {
    foreach ($line in ($DownstreamRepos -split "`r?`n")) {
        $repo = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($repo)) {
            continue
        }

        $parts = $repo -split '/'
        if ($parts.Count -ne 2 -or
            [string]::IsNullOrWhiteSpace($parts[0]) -or
            [string]::IsNullOrWhiteSpace($parts[1])) {
            throw "Invalid downstream repo entry '$repo'. Expected format 'owner/repo'."
        }

        $owner = $parts[0]
        $name  = $parts[1]

        $matrix += [pscustomobject]@{
            owner = $owner
            repo  = $name
        }
    }
}

$matrixJson = ConvertTo-Json -InputObject @($matrix) -Compress -Depth 3
"matrix=$matrixJson" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
