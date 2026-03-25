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
    $uri = "https://api.github.com/repos/$Owner/$Repo/actions/runs?event=repository_dispatch&per_page=50"
    $runsResponse = Invoke-RestMethod -Method Get -Uri $uri -Headers $headers

    $selectedRun = $null
    if ($null -ne $runsResponse.workflow_runs) {
        $selectedRun = $runsResponse.workflow_runs |
            Where-Object { $_.created_at -ge $DispatchedAt } |
            Sort-Object -Property created_at -Descending |
            Select-Object -First 1
    }

    if ($null -ne $selectedRun) {
        $foundRun = $true
        $runId = [string]$selectedRun.id
        $runName = [string]$selectedRun.name
        $runStatus = [string]$selectedRun.status
        $runConclusion = if ($null -eq $selectedRun.conclusion) { 'null' } else { [string]$selectedRun.conclusion }
        $runUrl = [string]$selectedRun.html_url

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
