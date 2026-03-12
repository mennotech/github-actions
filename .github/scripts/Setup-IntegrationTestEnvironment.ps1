#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sets up the integration test environment with complete project structure.

.DESCRIPTION
    Creates a complete test project structure with PowerShell files, module files,
    configuration files, and files to be excluded from deployment.

.PARAMETER ProjectPath
    The path where the test project should be created. Defaults to "test-project".

.EXAMPLE
    Setup-IntegrationTestEnvironment.ps1 -ProjectPath "test-project"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ProjectPath = "test-project"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    Write-Host "Setting up integration test environment..." -ForegroundColor Cyan
    
    # Create test project structure  
    New-Item -ItemType Directory -Path $ProjectPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$ProjectPath\scripts" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ProjectPath\.git" -Force | Out-Null
    New-Item -ItemType Directory -Path "$ProjectPath\.github" -Force | Out-Null
    
    # Create PowerShell files to sign and deploy - main.ps1
    $mainScript = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Main application script for integration test.
.DESCRIPTION
    This is a test script that demonstrates the complete signing and deployment workflow.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Message = "Hello from main script!"
)

Write-Host $Message -ForegroundColor Green
Write-Host "Script executed successfully" -ForegroundColor Cyan
'@
    Set-Content -Path "$ProjectPath\main.ps1" -Value $mainScript -Encoding UTF8

    # Create TestUtils.psm1 module
    $moduleScript = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Utility functions module for integration test.
#>

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
    Set-Content -Path "$ProjectPath\scripts\TestUtils.psm1" -Value $moduleScript -Encoding UTF8

    # Create helper.ps1 script
    $helperScript = @'
#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Helper script for the integration test project.
#>

# Import the test utilities
Import-Module "$PSScriptRoot\TestUtils.psm1" -Force

Write-Host "Helper script starting..." -ForegroundColor Cyan

# Use the module functions
$info = Get-TestInfo
Write-Host "Module info: $($info.Name) v$($info.Version)" -ForegroundColor Gray

$result = Invoke-TestFunction -InputText "Integration test data"
Write-Host "Function result: $result" -ForegroundColor Gray

Write-Host "Helper script completed successfully" -ForegroundColor Green
'@
    Set-Content -Path "$ProjectPath\scripts\helper.ps1" -Value $helperScript -Encoding UTF8

    # Create module manifest
    $manifestScript = @'
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
    Set-Content -Path "$ProjectPath\scripts\TestUtils.psd1" -Value $manifestScript -Encoding UTF8

    # Create files that should be deployed but not signed
    "This is a configuration file for the test application" | Out-File -FilePath "$ProjectPath\config.txt" -Encoding UTF8
    "README for the test project" | Out-File -FilePath "$ProjectPath\README.md" -Encoding UTF8
    
    # Create files that should be excluded from deployment
    "Git config file" | Out-File -FilePath "$ProjectPath\.git\config" -Encoding UTF8
    "GitHub workflow" | Out-File -FilePath "$ProjectPath\.github\test.yml" -Encoding UTF8
    "Certificate file" | Out-File -FilePath "$ProjectPath\test.crt" -Encoding UTF8
    
    Write-Host "[OK] Test project structure created" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to setup integration test environment: $_"
    exit 1
}