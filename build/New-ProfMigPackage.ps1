<#
.SYNOPSIS
    Creates a deterministic ProfMig runtime package.

.DESCRIPTION
    Builds a clean ProfMig runtime directory from the development repository.

    Development files, tests, existing logs, reports and backup data are not
    included in the package.

    The generated package is intended to be suitable for local execution and
    later deployment through management platforms such as Intune and RMM.
#>

[CmdletBinding()]
param (
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\dist\ProfMig')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$SourceRoot     = Join-Path $RepositoryRoot 'src'
$PackageRoot    = [System.IO.Path]::GetFullPath($OutputPath)

Write-Host 'Creating ProfMig runtime package...'
Write-Host "Repository: $RepositoryRoot"
Write-Host "Package:    $PackageRoot"

# -----------------------------------------------------------------------------
# Validate required runtime source files
# -----------------------------------------------------------------------------

$RequiredPaths = @(
    (Join-Path $RepositoryRoot 'Start-ProfMig.bat')
    (Join-Path $RepositoryRoot 'LICENSE')
    (Join-Path $SourceRoot 'ProfMig.ps1')
    (Join-Path $SourceRoot 'Config.psd1')
    (Join-Path $SourceRoot 'Modules')
    (Join-Path $SourceRoot 'Applications')
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
    if ($PackageRoot.TrimEnd('\') -eq $ProtectedPath.TrimEnd('\')) {
        throw "Package output path may not overwrite source directory: $PackageRoot"
    }
}

# -----------------------------------------------------------------------------
# Create clean package
# -----------------------------------------------------------------------------

if (Test-Path -LiteralPath $PackageRoot) {
    Write-Host 'Removing previous package...'
    Remove-Item -LiteralPath $PackageRoot -Recurse -Force
}

$null = New-Item -ItemType Directory -Path $PackageRoot -Force

$PackageSourceRoot = Join-Path $PackageRoot 'src'

$null = New-Item -ItemType Directory -Path $PackageSourceRoot -Force
$null = New-Item -ItemType Directory -Path (Join-Path $PackageRoot 'Logs') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $PackageRoot 'Reports') -Force

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

# -----------------------------------------------------------------------------
# Validate generated package
# -----------------------------------------------------------------------------

$PackageRequiredPaths = @(
    (Join-Path $PackageRoot 'Start-ProfMig.bat')
    (Join-Path $PackageRoot 'LICENSE')
    (Join-Path $PackageSourceRoot 'ProfMig.ps1')
    (Join-Path $PackageSourceRoot 'Config.psd1')
    (Join-Path $PackageSourceRoot 'Modules')
    (Join-Path $PackageSourceRoot 'Applications')
    (Join-Path $PackageRoot 'Logs')
    (Join-Path $PackageRoot 'Reports')
)

foreach ($Path in $PackageRequiredPaths) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Generated package validation failed. Missing: $Path"
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
            "Generated package contains development-only component: " +
            $ForbiddenName
        )
    }
}

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
Write-Host "Location:                $PackageRoot"
