<#
.SYNOPSIS
    Validates the ProfMig runtime packaging process.

.DESCRIPTION
    Builds a clean ProfMig runtime package in a temporary location and
    validates the runtime structure, deployment script, uninstall script and
    package isolation requirements.

    The test does not perform a profile migration.
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path -Parent $PSScriptRoot

$BuildScript = Join-Path `
    $RepositoryRoot `
    'build\New-ProfMigPackage.ps1'

$DeploymentScript = Join-Path `
    $RepositoryRoot `
    'build\Deploy-ProfMig.ps1'

$UninstallScript = Join-Path `
    $RepositoryRoot `
    'build\Uninstall-ProfMig.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Package-Test-' + [guid]::NewGuid().ToString('N'))

$PackageRoot = Join-Path `
    $TestRoot `
    'ProfMig'

try {

    Write-Host '=== ProfMig Packaging Test ==='
    Write-Host "Temporary package: $PackageRoot"
    Write-Host ''

    if (-not (Test-Path -LiteralPath $BuildScript -PathType Leaf)) {
        throw "Packaging script was not found: $BuildScript"
    }

    if (-not (Test-Path -LiteralPath $DeploymentScript -PathType Leaf)) {
        throw "Deployment script was not found: $DeploymentScript"
    }

    if (-not (Test-Path -LiteralPath $UninstallScript -PathType Leaf)) {
        throw "Uninstall script was not found: $UninstallScript"
    }

    # -------------------------------------------------------------------------
    # Build package
    # -------------------------------------------------------------------------

    & $BuildScript -OutputPath $PackageRoot

    # -------------------------------------------------------------------------
    # Validate required runtime structure
    # -------------------------------------------------------------------------

    $RequiredPaths = @(
        'Deploy-ProfMig.ps1'
        'Uninstall-ProfMig.ps1'
        'Start-ProfMig.bat'
        'LICENSE'
        'ProfMig.Build.psd1'
        'src\ProfMig.ps1'
        'src\Config.psd1'
        'src\Modules'
        'src\Applications'
        'src\Profiles'
        'Logs'
        'Reports'
    )

    foreach ($RelativePath in $RequiredPaths) {

        $Path = Join-Path `
            $PackageRoot `
            $RelativePath

        if (-not (Test-Path -LiteralPath $Path)) {
            throw "Required package component is missing: $RelativePath"
        }
    }

    # -------------------------------------------------------------------------
    # Validate deployment script
    # -------------------------------------------------------------------------

    $PackagedDeploymentScript = Join-Path `
        $PackageRoot `
        'Deploy-ProfMig.ps1'

    $SourceDeploymentHash = (
        Get-FileHash `
            -LiteralPath $DeploymentScript `
            -Algorithm SHA256
    ).Hash

    $PackagedDeploymentHash = (
        Get-FileHash `
            -LiteralPath $PackagedDeploymentScript `
            -Algorithm SHA256
    ).Hash

    if ($SourceDeploymentHash -ne $PackagedDeploymentHash) {

        throw (
            'Packaged deployment script does not match ' +
            'build\Deploy-ProfMig.ps1.'
        )
    }

    # -------------------------------------------------------------------------
    # Validate uninstall script
    # -------------------------------------------------------------------------

    $PackagedUninstallScript = Join-Path `
        $PackageRoot `
        'Uninstall-ProfMig.ps1'

    $SourceUninstallHash = (
        Get-FileHash `
            -LiteralPath $UninstallScript `
            -Algorithm SHA256
    ).Hash

    $PackagedUninstallHash = (
        Get-FileHash `
            -LiteralPath $PackagedUninstallScript `
            -Algorithm SHA256
    ).Hash

    if ($SourceUninstallHash -ne $PackagedUninstallHash) {

        throw (
            'Packaged uninstall script does not match ' +
            'build\Uninstall-ProfMig.ps1.'
        )
    }

    # -------------------------------------------------------------------------
    # Validate build metadata
    # -------------------------------------------------------------------------

    $BuildMetadataPath = Join-Path `
        $PackageRoot `
        'ProfMig.Build.psd1'

    $BuildMetadata = Import-PowerShellDataFile `
        -LiteralPath $BuildMetadataPath

    if ([string]::IsNullOrWhiteSpace([string]$BuildMetadata.Name)) {
        throw 'Package build metadata does not contain a name.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$BuildMetadata.Version)) {
        throw 'Package build metadata does not contain a version.'
    }

    if ([string]::IsNullOrWhiteSpace([string]$BuildMetadata.Build)) {
        throw 'Package build metadata does not contain a build identifier.'
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

        if (
            -not (
                Test-Path `
                    -LiteralPath $PackagedModule `
                    -PathType Leaf
            )
        ) {
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

    foreach ($SourceApplication in $SourceApplications) {

        $PackagedApplication = Join-Path `
            (Join-Path $PackageRoot 'src\Applications') `
            $SourceApplication.Name

        if (
            -not (
                Test-Path `
                    -LiteralPath $PackagedApplication `
                    -PathType Leaf
            )
        ) {
            throw (
                'Application definition is missing: ' +
                $SourceApplication.Name
            )
        }
    }

    # -------------------------------------------------------------------------
    # Validate migration profiles
    # -------------------------------------------------------------------------

    $SourceProfiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $RepositoryRoot 'src\Profiles') `
            -Filter '*.psd1' `
            -File
    )

    $PackageProfiles = @(
        Get-ChildItem `
            -LiteralPath (Join-Path $PackageRoot 'src\Profiles') `
            -Filter '*.psd1' `
            -File
    )

    if ($PackageProfiles.Count -ne $SourceProfiles.Count) {

        throw (
            'Migration profile count mismatch. Source: ' +
            $SourceProfiles.Count +
            ', Package: ' +
            $PackageProfiles.Count
        )
    }

    foreach ($SourceProfile in $SourceProfiles) {

        $PackagedProfile = Join-Path `
            (Join-Path $PackageRoot 'src\Profiles') `
            $SourceProfile.Name

        if (
            -not (
                Test-Path `
                    -LiteralPath $PackagedProfile `
                    -PathType Leaf
            )
        ) {
            throw "Migration profile is missing: $($SourceProfile.Name)"
        }
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
    Write-Host 'Deployment script validated:       Yes'
    Write-Host 'Uninstall script validated:        Yes'
    Write-Host "Package version validated:         $($BuildMetadata.Version)"
    Write-Host "Modules validated:                 $($PackageModules.Count)"
    Write-Host "Application definitions validated: $($PackageApplications.Count)"
    Write-Host "Migration profiles validated:      $($PackageProfiles.Count)"

    exit 0
}
catch {

    Write-Error (
        'FAIL: ProfMig packaging validation failed: ' +
        $_.Exception.Message
    )

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