<#
.SYNOPSIS
    Creates a deterministic ProfMig runtime package.

.DESCRIPTION
    Builds a clean ProfMig runtime directory from the development repository.

    Development files, tests, existing logs, reports and backup data are not
    included in the package.

    The generated package contains the ProfMig deployment script and is
    intended to be suitable for local execution and unattended deployment
    through management platforms such as RMM.
#>

[CmdletBinding()]
param (
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\dist\ProfMig')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SourceRoot = Join-Path $RepositoryRoot 'src'
$PackageRoot = [System.IO.Path]::GetFullPath($OutputPath)

$DeploymentScriptPath = Join-Path `
    $RepositoryRoot `
    'build\Deploy-ProfMig.ps1'

# -----------------------------------------------------------------------------
# Resolve build information
# -----------------------------------------------------------------------------

$ConfigurationPath = Join-Path `
    $SourceRoot `
    'Config.psd1'

$Configuration = Import-PowerShellDataFile `
    -LiteralPath $ConfigurationPath

$ProfMigVersion = [string]$Configuration.Application.Version
$ProfMigBuild = [string]$Configuration.Application.Build

if ([string]::IsNullOrWhiteSpace($ProfMigVersion)) {
    throw 'ProfMig version is missing from Config.psd1.'
}

if ([string]::IsNullOrWhiteSpace($ProfMigBuild)) {
    throw 'ProfMig build identifier is missing from Config.psd1.'
}

$GitCommit = 'Unknown'
$GitDirty = $null

try {

    $ResolvedGitCommit = (
        git -C $RepositoryRoot rev-parse HEAD 2>$null
    )

    if (-not [string]::IsNullOrWhiteSpace($ResolvedGitCommit)) {
        $GitCommit = [string]$ResolvedGitCommit.Trim()
    }

    $GitStatus = @(
        git -C $RepositoryRoot status --porcelain 2>$null
    )

    $GitDirty = ($GitStatus.Count -gt 0)
}
catch {

    # Package creation remains possible when Git is unavailable.

    $GitCommit = 'Unknown'
    $GitDirty = $null
}

$BuildTimestamp = (Get-Date).ToUniversalTime().ToString('o')

Write-Host 'Creating ProfMig runtime package...'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Package:    $PackageRoot"
Write-Host "Version:    $ProfMigVersion"
Write-Host "Build:      $ProfMigBuild"
Write-Host "Git commit: $GitCommit"
Write-Host "Git dirty:  $GitDirty"

# -----------------------------------------------------------------------------
# Validate required runtime source files
# -----------------------------------------------------------------------------

$RequiredPaths = @(
    (Join-Path $RepositoryRoot 'Start-ProfMig.bat')
    (Join-Path $RepositoryRoot 'LICENSE')
    $DeploymentScriptPath
    (Join-Path $SourceRoot 'ProfMig.ps1')
    (Join-Path $SourceRoot 'Config.psd1')
    (Join-Path $SourceRoot 'Modules')
    (Join-Path $SourceRoot 'Applications')
    (Join-Path $SourceRoot 'Profiles')
)

foreach ($Path in $RequiredPaths) {

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Required runtime component was not found: $Path"
    }
}

# -----------------------------------------------------------------------------
# Ensure the output directory cannot resolve to a source directory
# -----------------------------------------------------------------------------

$ProtectedPaths = @(
    $RepositoryRoot
    $SourceRoot
)

foreach ($ProtectedPath in $ProtectedPaths) {

    if (
        $PackageRoot.TrimEnd('\') -eq
        $ProtectedPath.TrimEnd('\')
    ) {

        throw (
            'Package output path may not overwrite source directory: ' +
            $PackageRoot
        )
    }
}

# -----------------------------------------------------------------------------
# Create clean package
# -----------------------------------------------------------------------------

if (Test-Path -LiteralPath $PackageRoot) {

    Write-Host 'Removing previous package...'

    Remove-Item `
        -LiteralPath $PackageRoot `
        -Recurse `
        -Force
}

$null = New-Item `
    -ItemType Directory `
    -Path $PackageRoot `
    -Force

$PackageSourceRoot = Join-Path `
    $PackageRoot `
    'src'

$null = New-Item `
    -ItemType Directory `
    -Path $PackageSourceRoot `
    -Force

$null = New-Item `
    -ItemType Directory `
    -Path (Join-Path $PackageRoot 'Logs') `
    -Force

$null = New-Item `
    -ItemType Directory `
    -Path (Join-Path $PackageRoot 'Reports') `
    -Force

# -----------------------------------------------------------------------------
# Copy runtime files
# -----------------------------------------------------------------------------

Copy-Item `
    -LiteralPath (Join-Path $RepositoryRoot 'Start-ProfMig.bat') `
    -Destination $PackageRoot

Copy-Item `
    -LiteralPath (Join-Path $RepositoryRoot 'LICENSE') `
    -Destination $PackageRoot

Copy-Item `
    -LiteralPath $DeploymentScriptPath `
    -Destination (Join-Path $PackageRoot 'Deploy-ProfMig.ps1')

Copy-Item `
    -LiteralPath (Join-Path $SourceRoot 'ProfMig.ps1') `
    -Destination $PackageSourceRoot

Copy-Item `
    -LiteralPath (Join-Path $SourceRoot 'Config.psd1') `
    -Destination $PackageSourceRoot

Copy-Item `
    -LiteralPath (Join-Path $SourceRoot 'Modules') `
    -Destination $PackageSourceRoot `
    -Recurse

Copy-Item `
    -LiteralPath (Join-Path $SourceRoot 'Applications') `
    -Destination $PackageSourceRoot `
    -Recurse

Copy-Item `
    -LiteralPath (Join-Path $SourceRoot 'Profiles') `
    -Destination $PackageSourceRoot `
    -Recurse

# -----------------------------------------------------------------------------
# Generate package build metadata
# -----------------------------------------------------------------------------

$BuildMetadataPath = Join-Path `
    $PackageRoot `
    'ProfMig.Build.psd1'

$BuildMetadata = @"
@{
    Name      = '$($Configuration.Application.Name)'
    Version   = '$ProfMigVersion'
    Build     = '$ProfMigBuild'
    GitCommit = '$GitCommit'
    GitDirty  = `$$GitDirty
    BuiltAt   = '$BuildTimestamp'
}
"@

Set-Content `
    -LiteralPath $BuildMetadataPath `
    -Value $BuildMetadata `
    -Encoding UTF8

# -----------------------------------------------------------------------------
# Validate generated package
# -----------------------------------------------------------------------------

$PackageRequiredPaths = @(
    (Join-Path $PackageRoot 'Deploy-ProfMig.ps1')
    (Join-Path $PackageRoot 'Start-ProfMig.bat')
    (Join-Path $PackageRoot 'LICENSE')
    (Join-Path $PackageRoot 'ProfMig.Build.psd1')
    (Join-Path $PackageSourceRoot 'ProfMig.ps1')
    (Join-Path $PackageSourceRoot 'Config.psd1')
    (Join-Path $PackageSourceRoot 'Modules')
    (Join-Path $PackageSourceRoot 'Applications')
    (Join-Path $PackageSourceRoot 'Profiles')
    (Join-Path $PackageRoot 'Logs')
    (Join-Path $PackageRoot 'Reports')
)

foreach ($Path in $PackageRequiredPaths) {

    if (-not (Test-Path -LiteralPath $Path)) {

        throw (
            'Generated package validation failed. Missing: ' +
            $Path
        )
    }
}

# -----------------------------------------------------------------------------
# Validate package isolation
# -----------------------------------------------------------------------------

$ForbiddenNames = @(
    '.git'
    '.github'
    'tests'
    'docs'
    'Backup'
    'TestData'
)

foreach ($ForbiddenName in $ForbiddenNames) {

    $ForbiddenItems = @(
        Get-ChildItem `
            -LiteralPath $PackageRoot `
            -Recurse `
            -Force |
        Where-Object {
            $_.Name -eq $ForbiddenName
        }
    )

    if ($ForbiddenItems.Count -gt 0) {

        throw (
            'Generated package contains development-only component: ' +
            $ForbiddenName
        )
    }
}

# -----------------------------------------------------------------------------
# Validate runtime output directories
# -----------------------------------------------------------------------------

$UnexpectedRuntimeOutput = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $PackageRoot 'Logs') `
        -File `
        -Recurse

    Get-ChildItem `
        -LiteralPath (Join-Path $PackageRoot 'Reports') `
        -File `
        -Recurse
)

if ($UnexpectedRuntimeOutput.Count -gt 0) {
    throw 'Generated package contains existing runtime output.'
}

# -----------------------------------------------------------------------------
# Collect package statistics
# -----------------------------------------------------------------------------

$ModuleCount = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $PackageSourceRoot 'Modules') `
        -Filter '*.psm1' `
        -File
).Count

$ApplicationDefinitionCount = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $PackageSourceRoot 'Applications') `
        -File
).Count

$MigrationProfileCount = @(
    Get-ChildItem `
        -LiteralPath (Join-Path $PackageSourceRoot 'Profiles') `
        -Filter '*.psd1' `
        -File
).Count

$PackageFileCount = @(
    Get-ChildItem `
        -LiteralPath $PackageRoot `
        -File `
        -Recurse
).Count

Write-Host ''
Write-Host 'ProfMig runtime package created successfully.'
Write-Host "Files:                   $PackageFileCount"
Write-Host "Modules:                 $ModuleCount"
Write-Host "Application definitions: $ApplicationDefinitionCount"
Write-Host "Migration profiles:      $MigrationProfileCount"
Write-Host 'Deployment script:       included'
Write-Host "Location:                $PackageRoot"