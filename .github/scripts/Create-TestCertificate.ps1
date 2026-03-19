#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates a test certificate for GitHub Actions testing.

.DESCRIPTION
    Creates a self-signed certificate for test workflows. The certificate can either
    be exported to PFX and written to GitHub environment variables, or kept imported
    in the CurrentUser certificate store for signing tests.

.PARAMETER Mode
    Selects whether the certificate should be exported to PFX or kept imported in
    the certificate store.

.PARAMETER Subject
    Subject used for the test certificate.

.PARAMETER Password
    Password used when exporting the certificate to PFX.

.PARAMETER ValidDays
    Number of days the certificate should remain valid.

.PARAMETER Base64EnvVarName
    Environment variable name used for exported base64 PFX content.

.PARAMETER PasswordEnvVarName
    Environment variable name used for the exported PFX password.

.PARAMETER ThumbprintEnvVarName
    Environment variable name used for the certificate thumbprint.

.PARAMETER ImportedThumbprintEnvVarName
    Environment variable name used for the imported certificate thumbprint.

.PARAMETER TrustForVerification
    Also trust the generated test certificate in the CurrentUser TrustedPublisher
    and Root stores so post-signing verification runs with a trusted chain.

.EXAMPLE
    Create-TestCertificate.ps1 -Mode ExportPfx

.EXAMPLE
    Create-TestCertificate.ps1 -Mode ImportToStore -Subject "CN=TestCodeSignCert"

.EXAMPLE
    Create-TestCertificate.ps1 -Mode ImportToStore -Subject "CN=TestCodeSignCert" -TrustForVerification
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet('ExportPfx', 'ImportToStore')]
    [string]$Mode = 'ExportPfx',

    [Parameter()]
    [string]$Subject = 'CN=TestCert',

    [Parameter()]
    [string]$Password = 'TestPassword123!',

    [Parameter()]
    [int]$ValidDays = 1,

    [Parameter()]
    [string]$Base64EnvVarName = 'TEST_PFX_BASE64',

    [Parameter()]
    [string]$PasswordEnvVarName = 'TEST_PFX_PASSWORD',

    [Parameter()]
    [string]$ThumbprintEnvVarName = 'TEST_CERT_THUMBPRINT',

    [Parameter()]
    [string]$ImportedThumbprintEnvVarName = 'IMPORTED_CERT_THUMBPRINT',

    [Parameter()]
    [switch]$TrustForVerification
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Set-TestEnvironmentVariable {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($PSCmdlet.ShouldProcess($Name, 'Set test environment variable')) {
        if ($env:GITHUB_ENV) {
            "$Name=$Value" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding UTF8
        } else {
            Set-Item -Path "Env:$Name" -Value $Value
        }

        Write-Host "  Set environment variable: $Name" -ForegroundColor Gray
    }
}

function Set-TestOutput {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Value
    )

    if ($env:GITHUB_OUTPUT -and $PSCmdlet.ShouldProcess($Name, 'Set test step output')) {
        "$Name=$Value" | Out-File -FilePath $env:GITHUB_OUTPUT -Append -Encoding UTF8
        Write-Host "  Set step output: $Name" -ForegroundColor Gray
    }
}

function Add-TestCertificateTrust {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,

        [Parameter(Mandatory)]
        [ValidateSet('TrustedPublisher', 'Root')]
        [string]$StoreName
    )

    if (-not $PSCmdlet.ShouldProcess($StoreName, 'Trust test certificate for verification')) {
        return
    }

    $storeNameEnum = [System.Enum]::Parse([System.Security.Cryptography.X509Certificates.StoreName], $StoreName)
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        $storeNameEnum,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    )

    try {
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

        $existingCertificate = $store.Certificates | Where-Object {
            $_.Thumbprint -eq $Certificate.Thumbprint
        }

        if ($existingCertificate) {
            Write-Host "  Certificate already present in CurrentUser\\$StoreName" -ForegroundColor Gray
            return
        }

        $store.Add($Certificate)
        Write-Host "  Added certificate to CurrentUser\\$StoreName" -ForegroundColor Gray
    } finally {
        $store.Close()
    }
}

try {
    Write-Host "Creating test certificate in mode: $Mode" -ForegroundColor Cyan

    if (-not $PSCmdlet.ShouldProcess($Subject, 'Create test certificate')) {
        return
    }

    $certificateParams = @{
        Subject = $Subject
        CertStoreLocation = 'Cert:\CurrentUser\My'
        KeyUsage = 'DigitalSignature'
        Type = 'CodeSigningCert'
        NotAfter = (Get-Date).AddDays($ValidDays)
    }
    $cert = New-SelfSignedCertificate @certificateParams

    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray

    if ($Mode -eq 'ExportPfx') {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $pfxPath = Join-Path $env:TEMP "test-certificate-$([guid]::NewGuid()).pfx"

        if ($PSCmdlet.ShouldProcess($pfxPath, 'Export test certificate to PFX')) {
            Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
        }

        $pfxBytes = [IO.File]::ReadAllBytes($pfxPath)
        $pfxBase64 = [Convert]::ToBase64String($pfxBytes)

        Set-TestEnvironmentVariable -Name $Base64EnvVarName -Value $pfxBase64
        Set-TestEnvironmentVariable -Name $PasswordEnvVarName -Value $Password
        Set-TestOutput -Name 'pfx_base64' -Value $pfxBase64
        Set-TestOutput -Name 'pfx_password' -Value $Password

        if ($PSCmdlet.ShouldProcess($cert.Thumbprint, 'Remove exported test certificate from store')) {
            Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
        }
        if ($PSCmdlet.ShouldProcess($pfxPath, 'Remove temporary PFX file')) {
            Remove-Item $pfxPath -Force
        }

        Write-Host "[OK] Test certificate created, exported, and removed from store" -ForegroundColor Green
    } else {
        if ($TrustForVerification) {
            Add-TestCertificateTrust -Certificate $cert -StoreName 'TrustedPublisher'
            Add-TestCertificateTrust -Certificate $cert -StoreName 'Root'
        }

        Set-TestEnvironmentVariable -Name $ThumbprintEnvVarName -Value $cert.Thumbprint
        Set-TestEnvironmentVariable -Name $ImportedThumbprintEnvVarName -Value $cert.Thumbprint
        Set-TestOutput -Name 'certificate_thumbprint' -Value $cert.Thumbprint
        Set-TestOutput -Name 'imported_certificate_thumbprint' -Value $cert.Thumbprint

        if ($TrustForVerification) {
            Write-Host "[OK] Test certificate created, trusted for verification, and left imported for signing" -ForegroundColor Green
        } else {
            Write-Host "[OK] Test certificate created and left imported for signing" -ForegroundColor Green
        }
    }
} catch {
    Write-Error "Failed to create test certificate: $_"
    exit 1
}