#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up the integration test environment with complete project structure.

.DESCRIPTION
    Creates a reusable test fixture for action tests and the integration workflow.

.PARAMETER ProjectPath
    The path where the test fixture should be created.

.PARAMETER Scenario
    Selects which fixture to create.

.EXAMPLE
    Setup-IntegrationTestEnvironment.ps1 -Scenario Integration -ProjectPath "test-project"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectPath = 'test-project',

    [Parameter()]
    [ValidateSet('Integration', 'Signing', 'Deployment')]
    [string]$Scenario = 'Integration'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-TestDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Write-TestFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $directory = Split-Path -Path $Path -Parent
    if ($directory) {
        New-TestDirectory -Path $directory
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function New-SigningFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    New-TestDirectory -Path $Path
    New-TestDirectory -Path (Join-Path $Path 'subdir')

    Write-TestFile -Path (Join-Path $Path 'test1.ps1') -Content @'
# Test PowerShell script 1
Write-Host "Hello from test script 1"
'@
    Write-TestFile -Path (Join-Path $Path 'test2.ps1') -Content @'
# Test PowerShell script 2
Write-Host "Hello from test script 2"
'@
    Write-TestFile -Path (Join-Path $Path 'TestModule.psm1') -Content @'
function Test-Function {
    Write-Host "Hello from test function"
}
'@
    Write-TestFile -Path (Join-Path $Path 'subdir\test3.ps1') -Content @'
# Test PowerShell script in subdirectory
Write-Host "Hello from subdirectory script"
'@
    Write-TestFile -Path (Join-Path $Path 'readme.txt') -Content 'This is not a PowerShell file'
}

function New-DeploymentFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    New-TestDirectory -Path $Path
    New-TestDirectory -Path (Join-Path $Path '.git')
    New-TestDirectory -Path (Join-Path $Path '.github')
    New-TestDirectory -Path (Join-Path $Path 'scripts')

    Write-TestFile -Path (Join-Path $Path 'main.ps1') -Content 'Write-Host "Main script content"'
    Write-TestFile -Path (Join-Path $Path 'config.txt') -Content 'Configuration content'
    Write-TestFile -Path (Join-Path $Path 'scripts\subscript.ps1') -Content 'Write-Host "Subscript content"'
    Write-TestFile -Path (Join-Path $Path '.git\config') -Content 'Git file'
    Write-TestFile -Path (Join-Path $Path '.github\workflow.yml') -Content 'name: test-workflow'
    Write-TestFile -Path (Join-Path $Path 'test.crt') -Content 'Certificate file'
    Write-TestFile -Path (Join-Path $Path 'Config.json') -Content '{"name":"test-config"}'
}

function New-IntegrationFixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    New-TestDirectory -Path $Path
    New-TestDirectory -Path (Join-Path $Path 'scripts')
    New-TestDirectory -Path (Join-Path $Path '.git')
    New-TestDirectory -Path (Join-Path $Path '.github')

    Write-TestFile -Path (Join-Path $Path 'main.ps1') -Content @'
#!/usr/bin/env pwsh
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Message = "Hello from main script!"
)

Write-Host $Message -ForegroundColor Green
Write-Host "Script executed successfully" -ForegroundColor Cyan
'@
    Write-TestFile -Path (Join-Path $Path 'scripts\TestUtils.psm1') -Content @'
function Get-TestInfo {
    [CmdletBinding()]
    param()

    return @{
        Version = "1.0.0"
        Name = "Integration Test Module"
        Author = "Mennotech GitHub Actions"
    }
}

function Invoke-TestFunction {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$InputText = "Default test input"
    )

    Write-Host "Test function called with: $InputText" -ForegroundColor Yellow
    return "Processed: $InputText"
}

Export-ModuleMember -Function Get-TestInfo, Invoke-TestFunction
'@
    Write-TestFile -Path (Join-Path $Path 'scripts\helper.ps1') -Content @'
Import-Module "$PSScriptRoot\TestUtils.psm1" -Force

Write-Host "Helper script starting..." -ForegroundColor Cyan

$info = Get-TestInfo
Write-Host "Module info: $($info.Name) v$($info.Version)" -ForegroundColor Gray

$result = Invoke-TestFunction -InputText "Integration test data"
Write-Host "Function result: $result" -ForegroundColor Gray

Write-Host "Helper script completed successfully" -ForegroundColor Green
'@
    Write-TestFile -Path (Join-Path $Path 'scripts\TestUtils.psd1') -Content @'
@{
    RootModule = 'TestUtils.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'a1b2c3d4-e5f6-4321-8765-fedcba987654'
    Author = 'Integration Test'
    CompanyName = 'Mennotech'
    Copyright = 'Copyright (c) 2026 Mennotech. All rights reserved.'
    Description = 'Test module for integration testing GitHub Actions'
    FunctionsToExport = @('Get-TestInfo', 'Invoke-TestFunction')
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
}
'@
    Write-TestFile -Path (Join-Path $Path 'config.txt') -Content 'This is a configuration file for the test application'
    Write-TestFile -Path (Join-Path $Path 'README.md') -Content 'README for the test project'
    Write-TestFile -Path (Join-Path $Path '.git\config') -Content 'Git config file'
    Write-TestFile -Path (Join-Path $Path '.github\test.yml') -Content 'name: integration-test'
    Write-TestFile -Path (Join-Path $Path 'test.crt') -Content 'Certificate file'
    Write-TestFile -Path (Join-Path $Path 'Config.json') -Content '{"app":"integration-test"}'
}

try {
    Write-Host "Setting up test fixture for scenario: $Scenario" -ForegroundColor Cyan

    if (Test-Path $ProjectPath) {
        Remove-Item -Path $ProjectPath -Recurse -Force
    }

    switch ($Scenario) {
        'Signing' {
            New-SigningFixture -Path $ProjectPath
        }
        'Deployment' {
            New-DeploymentFixture -Path $ProjectPath
        }
        'Integration' {
            New-IntegrationFixture -Path $ProjectPath
        }
    }

    Write-Host "[OK] Test fixture created at $ProjectPath" -ForegroundColor Green
} catch {
    Write-Error "Failed to setup integration test environment: $_"
    exit 1
}