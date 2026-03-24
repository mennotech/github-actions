#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pester unit tests for shared/GitHubActions.Common.psm1.

.DESCRIPTION
    Covers ConvertTo-StringArray and Get-StringArrayParameterFromEnvironment,
    specifically the scalar/null-coercion paths that previously caused
    '.Count' to throw under Set-StrictMode -Version Latest when PowerShell
    silently unwrapped empty or single-element arrays returned via the pipeline.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitHubActions.Common.psm1') -Force

Describe 'ConvertTo-StringArray' {

    Context 'Null and blank inputs' {

        It 'Returns a string[] (not null) for $null' {
            $result = ConvertTo-StringArray -InputObject $null
            ($result -is [string[]]) | Should -Be $true
        }

        It 'Returns an empty array for $null — .Count must not throw' {
            $result = ConvertTo-StringArray -InputObject $null
            { $result.Count } | Should -Not -Throw
            $result.Count | Should -Be 0
        }

        It 'Returns an empty array for an empty string' {
            $result = ConvertTo-StringArray -InputObject ''
            ($result -is [string[]]) | Should -Be $true
            $result.Count | Should -Be 0
        }

        It 'Returns an empty array for a whitespace-only string' {
            $result = ConvertTo-StringArray -InputObject '   '
            ($result -is [string[]]) | Should -Be $true
            $result.Count | Should -Be 0
        }

        It 'Returns a string[] (not null) for an empty array' {
            $result = ConvertTo-StringArray -InputObject @()
            ($result -is [string[]]) | Should -Be $true
            $result.Count | Should -Be 0
        }
    }

    Context 'Single-item inputs (pipeline-unwrap regression)' {

        It 'Returns a string[] (not a bare string) for a single string' {
            $result = ConvertTo-StringArray -InputObject 'foo'
            ($result -is [string[]]) | Should -Be $true
        }

        It 'Returns a single-element array for a plain string — .Count must not throw' {
            $result = ConvertTo-StringArray -InputObject 'foo'
            { $result.Count } | Should -Not -Throw
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'foo'
        }

        It 'Trims whitespace from a single string' {
            $result = ConvertTo-StringArray -InputObject '  bar  '
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'bar'
        }

        It 'Returns a string[] (not a bare string) for a one-item array' {
            $result = ConvertTo-StringArray -InputObject @('only')
            ($result -is [string[]]) | Should -Be $true
        }

        It 'Returns a single-element array for a one-item array — .Count must not throw' {
            $result = ConvertTo-StringArray -InputObject @('only')
            { $result.Count } | Should -Not -Throw
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'only'
        }
    }

    Context 'Multi-item arrays' {

        It 'Preserves all non-blank items' {
            $result = ConvertTo-StringArray -InputObject @('a', 'b', 'c')
            $result.Count | Should -Be 3
        }

        It 'Discards blank entries from an array' {
            $result = ConvertTo-StringArray -InputObject @('a', '', '  ', 'b')
            $result.Count | Should -Be 2
            $result | Should -Contain 'a'
            $result | Should -Contain 'b'
        }

        It 'Discards null entries from an array' {
            $result = ConvertTo-StringArray -InputObject @('x', $null, 'y')
            $result.Count | Should -Be 2
        }

        It 'Trims whitespace from each item' {
            $result = ConvertTo-StringArray -InputObject @('  hello  ', '  world  ')
            $result[0] | Should -Be 'hello'
            $result[1] | Should -Be 'world'
        }
    }
}

Describe 'Get-StringArrayParameterFromEnvironment' {

    BeforeEach {
        [System.Environment]::SetEnvironmentVariable('TEST_VAR', $null)
    }

    AfterAll {
        [System.Environment]::SetEnvironmentVariable('TEST_VAR', $null)
    }

    Context 'Environment variable not set (regression: .Count must not throw)' {

        It 'Returns a string[] (not null) when env var is absent' {
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            ($result -is [string[]]) | Should -Be $true
        }

        It 'Returns empty array when env var is absent — .Count must not throw' {
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            { $result.Count } | Should -Not -Throw
            $result.Count | Should -Be 0
        }

        It 'Preserves CurrentValue when env var is absent and parameter was not bound' {
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @('existing')
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'existing'
        }
    }

    Context 'Environment variable is blank' {

        It 'Returns a string[] (not null) when env var is whitespace-only' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', '   ')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            ($result -is [string[]]) | Should -Be $true
            $result.Count | Should -Be 0
        }
    }

    Context 'Environment variable has a single value (pipeline-unwrap regression)' {

        It 'Returns a string[] (not a bare string) for a single env var value' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', '.git')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            ($result -is [string[]]) | Should -Be $true
        }

        It 'Returns a single-element array for one env var value — .Count must not throw' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', '.git')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            { $result.Count } | Should -Not -Throw
            $result.Count | Should -Be 1
            $result[0] | Should -Be '.git'
        }
    }

    Context 'Environment variable has multiple comma-separated values' {

        It 'Splits and trims all values' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', '.git, .github , logs')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            $result.Count | Should -Be 3
            $result | Should -Contain '.git'
            $result | Should -Contain '.github'
            $result | Should -Contain 'logs'
        }

        It 'Discards blank tokens between delimiters' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', 'a,,b,  ,c')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @()
            $result.Count | Should -Be 3
        }

        It 'Respects a custom delimiter' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', 'x;y;z')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{} `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @() `
                -Delimiter ';'
            $result.Count | Should -Be 3
        }
    }

    Context 'Bound parameter takes precedence over environment variable' {

        It 'Ignores env var when parameter is explicitly bound' {
            [System.Environment]::SetEnvironmentVariable('TEST_VAR', 'from-env')
            $result = Get-StringArrayParameterFromEnvironment `
                -BoundParameters @{ ExcludeDirs = @('from-param') } `
                -ParameterName 'ExcludeDirs' `
                -EnvironmentVariableName 'TEST_VAR' `
                -CurrentValue @('from-param')
            $result.Count | Should -Be 1
            $result[0] | Should -Be 'from-param'
        }
    }
}
