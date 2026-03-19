<#
.SYNOPSIS
    Shared PowerShell helpers for mennotech GitHub Actions.

.DESCRIPTION
    Provides common helper functions used by multiple reusable GitHub Actions in this
    repository. The helpers centralize repeated parameter and exclusion handling so
    action scripts stay consistent and easier to maintain.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
    Resolves a string array parameter from bound values or an environment variable.

.DESCRIPTION
    Returns the current parameter value when the caller bound that parameter
    explicitly. Otherwise, reads the specified environment variable, splits its
    contents into an array, trims whitespace, and removes empty entries.

.PARAMETER BoundParameters
    The current script or function PSBoundParameters hashtable.

.PARAMETER ParameterName
    The name of the parameter to check in BoundParameters.

.PARAMETER EnvironmentVariableName
    The environment variable to read when the parameter was not explicitly bound.

.PARAMETER CurrentValue
    The current parameter value to preserve when the parameter was explicitly bound
    or when the environment variable is not set.

.PARAMETER Delimiter
    The delimiter used to split the environment variable value. Defaults to a comma.

.EXAMPLE
    Get-StringArrayParameterFromEnvironment -BoundParameters $PSBoundParameters -ParameterName 'ExcludeDirs' -EnvironmentVariableName 'EXCLUDE_DIRS' -CurrentValue $ExcludeDirs

.EXAMPLE
    Get-StringArrayParameterFromEnvironment -BoundParameters $PSBoundParameters -ParameterName 'FileMatch' -EnvironmentVariableName 'FILE_MATCH' -CurrentValue $FileMatch -Delimiter ';'
#>
function Get-StringArrayParameterFromEnvironment {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters,

        [Parameter(Mandatory)]
        [string]$ParameterName,

        [Parameter(Mandatory)]
        [string]$EnvironmentVariableName,

        [Parameter()]
        [string[]]$CurrentValue = @(),

        [Parameter()]
        [string]$Delimiter = ','
    )

    if ($BoundParameters.ContainsKey($ParameterName)) {
        return [string[]]$CurrentValue
    }

    $environmentValue = [System.Environment]::GetEnvironmentVariable($EnvironmentVariableName)
    if ($null -eq $environmentValue) {
        return [string[]]$CurrentValue
    }

    if ([string]::IsNullOrWhiteSpace($environmentValue)) {
        return [string[]]@()
    }

    $resolvedValues = [System.Collections.Generic.List[string]]::new()
    foreach ($value in $environmentValue -split $Delimiter) {
        $trimmedValue = $value.Trim()
        if (-not [string]::IsNullOrWhiteSpace($trimmedValue)) {
            $resolvedValues.Add($trimmedValue)
        }
    }

    return [string[]]$resolvedValues
}

<#
.SYNOPSIS
    Combines mandatory and caller-provided excluded directories into a normalized list.

.DESCRIPTION
    Produces a case-insensitive unique list of directory exclusions. Values are
    trimmed, blank entries are discarded, and mandatory exclusions are always added
    before optional exclusions.

.PARAMETER ExcludeDirs
    Additional directories supplied by the caller.

.PARAMETER MandatoryExcludeDirs
    Directories that must always be excluded. Defaults to .git.

.EXAMPLE
    Get-EffectiveExcludeDirList -ExcludeDirs @('.github', 'logs')

.EXAMPLE
    Get-EffectiveExcludeDirList -ExcludeDirs @('Logs', 'logs') -MandatoryExcludeDirs @('.git', '_work')
#>
function Get-EffectiveExcludeDirList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string[]]$ExcludeDirs = @(),

        [Parameter()]
        [string[]]$MandatoryExcludeDirs = @('.git')
    )

    $effectiveExcludeDirs = [System.Collections.Generic.List[string]]::new()

    foreach ($excludeDir in @($MandatoryExcludeDirs) + @($ExcludeDirs)) {
        if ($null -eq $excludeDir) {
            continue
        }

        $normalizedExcludeDir = $excludeDir.Trim()
        if ([string]::IsNullOrWhiteSpace($normalizedExcludeDir)) {
            continue
        }

        $alreadyIncluded = $effectiveExcludeDirs | Where-Object {
            $_.Equals($normalizedExcludeDir, [System.StringComparison]::OrdinalIgnoreCase)
        }

        if (-not $alreadyIncluded) {
            $effectiveExcludeDirs.Add($normalizedExcludeDir)
        }
    }

    return [string[]]$effectiveExcludeDirs
}

Export-ModuleMember -Function Get-StringArrayParameterFromEnvironment, Get-EffectiveExcludeDirList