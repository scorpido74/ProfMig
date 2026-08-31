<#
.SYNOPSIS
    Validates the ProfMig runtime packaging process.

.DESCRIPTION
    Builds a clean ProfMig runtime package in a temporary location and
    validates the runtime structure and package isolation requirements.

    The test does not perform a profile migration.
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$BuildScript = Join-Path $RepositoryRoot 'build\New-ProfMigPackage.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Package-Test-' + [guid]::NewGuid().ToString('N'))

$PackageRoot = Join-Path $TestRoot 'ProfMig'

try {

    Write-Host '=== ProfMig Packaging Test ==='
    Write-Host "Temporary package: $PackageRoot"
    Write-Host ''

    if (-not (Test-Path -LiteralPath $BuildScript -PathType Leaf)) {
        throw "Packaging script was not found: $BuildScript"
    }

    # -------------------------------------------------------------------------
    # Build package
    # -------------------------------------------------------------------------

    & $BuildScript -OutputPath $PackageRoot

    # -------------------------------------------------------------------------
    # Validate required runtime structure
    # -------------------------------------------------------------------------

    $RequiredPaths = @(
        'Start-ProfMig.bat'
        'LICENSE'
        'src\ProfMig.ps1'
        'src\Config.psd1'
        'src\Modules'
        'src\Applications'
        'Logs'
        'Reports'
    )

    foreach ($RelativePath in $RequiredPaths) {

        $Path = Join-Path $PackageRoot $RelativePath

        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Required package component is missing: $RelativePath"
        }
    }

    # -------------------------------------------------------------------------
    # Validate required modules
    # -------------------------------------------------------------------------

    $SourceModules = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $RepositoryRoot 'src\Modules') `
            -Filter '*.psm1' `
            -File
    )

    $PackageModules = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $PackageRoot 'src\Modules') `
            -Filter '*.psm1' `
            -File
    )

    if ($PackageModules.Count -ne $SourceModules.Count) {
        throw (
            'Module count mismatch. Source: ' +
            $SourceModules.Count +
            ', Package: ' +
            $PackageModules.Count
        )
    }

    foreach ($SourceModule in $SourceModules) {

        $PackagedModule = Join-Path `
            (Join-Path $PackageRoot 'src\Modules') `
            $SourceModule.Name

        if (-not (Test-Path -LiteralPath $PackagedModule -PathType Leaf)) {
            throw "Runtime module is missing: $($SourceModule.Name)"
        }
    }

    # -------------------------------------------------------------------------
    # Validate application definitions
    # -------------------------------------------------------------------------

    $SourceApplications = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $RepositoryRoot 'src\Applications') `
            -File
    )

    $PackageApplications = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $PackageRoot 'src\Applications') `
            -File
    )

    if ($PackageApplications.Count -ne $SourceApplications.Count) {
        throw (
            'Application definition count mismatch. Source: ' +
            $SourceApplications.Count +
            ', Package: ' +
            $PackageApplications.Count
        )
    }

    # -------------------------------------------------------------------------
    # Validate empty runtime output directories
    # -------------------------------------------------------------------------

    $LogFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $PackageRoot 'Logs') `
            -File `
            -Recurse
    )

    $ReportFiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $PackageRoot 'Reports') `
            -File `
            -Recurse
    )

    if ($LogFiles.Count -ne 0) {
        throw 'Runtime package contains existing log files.'
    }

    if ($ReportFiles.Count -ne 0) {
        throw 'Runtime package contains existing report files.'
    }

    # -------------------------------------------------------------------------
    # Validate development-only content is excluded
    # -------------------------------------------------------------------------

    $ForbiddenNames = @(
        '.git'
        '.github'
        'tests'
        'docs'
        'Backup'
        'TestData'
    )

    foreach ($ForbiddenName in $ForbiddenNames) {

        $Found = @(
            Get-ChildItem `
                -LiteralPath $PackageRoot `
                -Recurse `
                -Force |
            Where-Object {
                $_.Name -eq $ForbiddenName
            }
        )

        if ($Found.Count -gt 0) {
            throw "Development-only component found: $ForbiddenName"
        }
    }

    Write-Host ''
    Write-Host 'PASS: ProfMig runtime package validation completed successfully.'
    Write-Host "Modules validated:                 $($PackageModules.Count)"
    Write-Host "Application definitions validated: $($PackageApplications.Count)"

    exit 0
}
catch {

    Write-Error "FAIL: ProfMig packaging validation failed: $($_.Exception.Message)"
    exit 1
}
finally {

    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item `
            -LiteralPath $TestRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}