#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Polls a repository for a repository_dispatch workflow run and waits for completion.

.DESCRIPTION
    Queries the GitHub Actions runs API for repository_dispatch runs created at or
    after a specified timestamp. Waits until a matching run appears and reaches
    a completed status or a timeout is reached.

    Writes run_id, run_url, conclusion, and timed_out to GITHUB_OUTPUT.

.PARAMETER Token
    GitHub token (or GitHub App token) with Actions: read on the target
    repository. Defaults to POLL_TOKEN environment variable.

.PARAMETER Owner
    Target organization or user account. Defaults to OWNER environment variable.

.PARAMETER Repo
    Target repository name (without owner prefix). Defaults to REPO environment
    variable.

.PARAMETER DispatchedAt
    ISO 8601 UTC timestamp. Only runs created at or after this time are
    considered. Defaults to DISPATCHED_AT environment variable.

.PARAMETER TimeoutSeconds
    Maximum number of seconds to wait for the run to appear and complete.
    Defaults to TIMEOUT_SECONDS environment variable or 1200.

.PARAMETER PollIntervalSeconds
    Number of seconds between polling attempts. Defaults to
    POLL_INTERVAL_SECONDS environment variable or 20.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Token = $env:POLL_TOKEN,

    [Parameter()]
    [string]$Owner = $env:OWNER,

    [Parameter()]
    [string]$Repo = $env:REPO,

    [Parameter()]
    [string]$DispatchedAt = $env:DISPATCHED_AT,

    [Parameter()]
    [int]$TimeoutSeconds = $(if ($env:TIMEOUT_SECONDS) { [int]$env:TIMEOUT_SECONDS } else { 1200 }),

    [Parameter()]
    [int]$PollIntervalSeconds = $(if ($env:POLL_INTERVAL_SECONDS) { [int]$env:POLL_INTERVAL_SECONDS } else { 20 })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Validate required inputs
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Missing required input: 'token' (or environment variable POLL_TOKEN)"
}
if ([string]::IsNullOrWhiteSpace($Owner)) {
    throw "Missing required input: 'owner' (or environment variable OWNER)"
}
if ([string]::IsNullOrWhiteSpace($Repo)) {
    throw "Missing required input: 'repo' (or environment variable REPO)"
}
if ([string]::IsNullOrWhiteSpace($DispatchedAt)) {
    throw "Missing required input: 'dispatched_at' (or environment variable DISPATCHED_AT)"
}
if ($TimeoutSeconds -le 0) {
    throw "Input 'timeout_seconds' must be greater than 0 (got $TimeoutSeconds)"
}
if ($PollIntervalSeconds -le 0) {
    throw "Input 'poll_interval_seconds' must be greater than 0 (got $PollIntervalSeconds)"
}

# Parse DispatchedAt as UTC DateTime — fail fast if not valid ISO 8601
$dispatchedAtUtc = $null
try {
    $dispatchedAtUtc = [System.DateTimeOffset]::Parse(
        $DispatchedAt,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
        [System.Globalization.DateTimeStyles]::AdjustToUniversal
    ).UtcDateTime
}
catch {
    throw "Input 'dispatched_at' is not a valid ISO 8601 timestamp: '$DispatchedAt'. Error: $($_.Exception.Message)"
}

$timeoutAt = (Get-Date).ToUniversalTime().AddSeconds($TimeoutSeconds)
$foundRun = $false
$runFinished = $false
$runId = ''
$runUrl = ''
$conclusion = ''

$headers = @{
    Accept                 = 'application/vnd.github+json'
    Authorization          = "Bearer $Token"
    'X-GitHub-Api-Version' = '2022-11-28'
}

while ((Get-Date).ToUniversalTime() -lt $timeoutAt) {
    if ([string]::IsNullOrEmpty($runId)) {
        # Search for the matching run, paging until we pass dispatched_at
        $selectedRun = $null
        $page = 1
        :pageLoop while ($true) {
            $uri = "https://api.github.com/repos/$Owner/$Repo/actions/runs?event=repository_dispatch&per_page=100&page=$page"
            $runsResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
            $runs = $runsResponse.workflow_runs
            if ($null -eq $runs -or $runs.Count -eq 0) {
                break pageLoop
            }

            # GitHub returns runs in descending created_at order by default
            foreach ($run in $runs) {
                $runCreatedAt = [System.DateTimeOffset]::Parse(
                    $run.created_at,
                    [System.Globalization.CultureInfo]::InvariantCulture,
                    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor
                    [System.Globalization.DateTimeStyles]::AdjustToUniversal
                ).UtcDateTime

                if ($runCreatedAt -ge $dispatchedAtUtc) {
                    # Runs are descending; each successive match is older, so the
                    # last assignment will be the earliest run after dispatch.
                    $selectedRun = $run
                }
                else {
                    # Once we reach a run older than dispatched_at, stop paging
                    break pageLoop
                }
            }

            $page++
        }

        if ($null -ne $selectedRun) {
            $foundRun = $true
            $runId = [string]$selectedRun.id
            $runUrl = [string]$selectedRun.html_url
            $runName = [string]$selectedRun.name
            $runStatus = [string]$selectedRun.status
            $runConclusion = if ($null -eq $selectedRun.conclusion) { 'null' } else { [string]$selectedRun.conclusion }

            Write-Host "Run found: id=$runId name=$runName status=$runStatus conclusion=$runConclusion"
            Write-Host "Run URL: $runUrl"

            if ($runStatus -eq 'completed') {
                $runFinished = $true
                $conclusion = $runConclusion
                break
            }
        }
        else {
            $remaining = [int][Math]::Ceiling(($timeoutAt - (Get-Date).ToUniversalTime()).TotalSeconds)
            Write-Host "No run found yet for $Owner/$Repo; waiting ${PollIntervalSeconds}s (${remaining}s remaining)"
        }
    }
    else {
        # Run already identified — poll the single-run endpoint until it completes
        $uri = "https://api.github.com/repos/$Owner/$Repo/actions/runs/$runId"
        $run = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
        $runStatus = [string]$run.status
        $runConclusion = if ($null -eq $run.conclusion) { 'null' } else { [string]$run.conclusion }

        Write-Host "Polling run ${runId}: status=$runStatus conclusion=$runConclusion"

        if ($runStatus -eq 'completed') {
            $runFinished = $true
            $conclusion = $runConclusion
            break
        }
    }

    Start-Sleep -Seconds $PollIntervalSeconds
}

$timedOut = 'false'
if (-not $foundRun) {
    Write-Host "Timed out waiting for a matching run to appear for $Owner/$Repo"
    $timedOut = 'true'
}
elseif (-not $runFinished) {
    Write-Host "Timed out waiting for run $runId to complete for $Owner/$Repo"
    $timedOut = 'true'
}

"run_id=$runId" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
"run_url=$runUrl" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
"conclusion=$conclusion" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
"timed_out=$timedOut" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
