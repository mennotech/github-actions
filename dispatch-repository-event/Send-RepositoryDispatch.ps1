#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sends a repository_dispatch event to a GitHub repository.

.DESCRIPTION
    Posts a repository_dispatch event to the GitHub API and writes the HTTP
    status code and a boolean success flag to GITHUB_OUTPUT.

    Requires a token with Contents: write permission on the target repository.

.PARAMETER Token
    GitHub token (or GitHub App token) with Contents: write on the target
    repository. Defaults to the DISPATCH_TOKEN environment variable.

.PARAMETER Owner
    Target organization or user account. Defaults to the OWNER environment
    variable.

.PARAMETER Repo
    Target repository name (without the owner prefix). Defaults to the REPO
    environment variable.

.PARAMETER EventType
    The repository_dispatch event type string (max 100 chars). Defaults to the
    EVENT_TYPE environment variable.

.PARAMETER ClientPayload
    JSON object string to send as client_payload. Must be valid JSON.
    Defaults to the CLIENT_PAYLOAD environment variable, or '{}' if unset.

.EXAMPLE
    Send-RepositoryDispatch.ps1
    # Reads all inputs from environment variables

.EXAMPLE
    Send-RepositoryDispatch.ps1 -Owner myorg -Repo myrepo -EventType deploy
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Token = $env:DISPATCH_TOKEN,

    [Parameter()]
    [string]$Owner = $env:OWNER,

    [Parameter()]
    [string]$Repo = $env:REPO,

    [Parameter()]
    [string]$EventType = $env:EVENT_TYPE,

    [Parameter()]
    [string]$ClientPayload = $(
        if ($env:CLIENT_PAYLOAD) { $env:CLIENT_PAYLOAD } else { '{}' }
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Validate required inputs
if ([string]::IsNullOrWhiteSpace($Token)) {
    throw "Missing required input: 'token' (or environment variable DISPATCH_TOKEN)"
}
if ([string]::IsNullOrWhiteSpace($Owner)) {
    throw "Missing required input: 'owner' (or environment variable OWNER)"
}
if ([string]::IsNullOrWhiteSpace($Repo)) {
    throw "Missing required input: 'repo' (or environment variable REPO)"
}
if ([string]::IsNullOrWhiteSpace($EventType)) {
    throw "Missing required input: 'event_type' (or environment variable EVENT_TYPE)"
}
if ($EventType.Length -gt 100) {
    throw "Input 'event_type' must not exceed 100 characters (got $($EventType.Length))"
}

try {
    $clientPayloadObject = $ClientPayload | ConvertFrom-Json -Depth 100
}
catch {
    throw "Input 'client_payload' must be valid JSON. Error: $($_.Exception.Message)"
}

if ($clientPayloadObject -isnot [PSCustomObject]) {
    $receivedType = if ($null -eq $clientPayloadObject) { 'null' } else { $clientPayloadObject.GetType().Name }
    throw "Input 'client_payload' must be a JSON object (e.g., '{}/{}'), not a $receivedType"
}

$requestBody = @{
    event_type     = $EventType
    client_payload = $clientPayloadObject
} | ConvertTo-Json -Compress -Depth 100

$headers = @{
    Accept                 = 'application/vnd.github+json'
    Authorization          = "Bearer $Token"
    'X-GitHub-Api-Version' = '2022-11-28'
}

$uri = "https://api.github.com/repos/$Owner/$Repo/dispatches"
$iwrParams = @{
    Method      = 'Post'
    Uri         = $uri
    Headers     = $headers
    Body        = $requestBody
    ContentType = 'application/json'
}
$response = Invoke-WebRequest @iwrParams -SkipHttpErrorCheck
$statusCode = [int]$response.StatusCode

"status_code=$statusCode" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append

if ($statusCode -eq 204) {
    Write-Host "Dispatch accepted (HTTP 204) for $Owner/$Repo"
    'success=true' | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
}
else {
    Write-Host "Dispatch FAILED (HTTP $statusCode) for $Owner/${Repo}:"
    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        Write-Host $response.Content
    }
    'success=false' | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8NoBOM -Append
}
