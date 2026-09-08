<#
.SYNOPSIS
    Creates the ProfMig source package for Microsoft Intune Win32 deployment.

.DESCRIPTION
    Builds a validated ProfMig runtime package using the standard ProfMig
    package builder and verifies that the resulting package contains the
    components required for Microsoft Intune Win32 deployment.

    This script does not create the .intunewin file itself. The generated
    directory is intended to be processed with the Microsoft Win32 Content
    Prep Tool.

.PARAMETER OutputPath
    Directory in which the Intune source package is created.

    Default:
    <repository>\dist\Intune\ProfMig
#>

[CmdletBinding()]
param (
    [string]$OutputPath = (
        Join-Path $PSScriptRoot '..\..\dist\Intune\ProfMig'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..\..')
).Path

$PackageBuilder = Join-Path `
    $RepositoryRoot `
    'build\New-ProfMigPackage.ps1'

$DetectionScript = Join-Path `
    $PSScriptRoot `
    'Detect-ProfMig.ps1'

$ResolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)

if (-not (Test-Path -LiteralPath $PackageBuilder -PathType Leaf)) {
    throw "ProfMig package builder not found: $PackageBuilder"
}

if (-not (Test-Path -LiteralPath $DetectionScript -PathType Leaf)) {
    throw "Intune detection script not found: $DetectionScript"
}

Write-Host 'Creating ProfMig Intune source package...'
Write-Host "Output: $ResolvedOutputPath"
Write-Host ''

& $PackageBuilder `
    -OutputPath $ResolvedOutputPath

if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "ProfMig package builder failed with exit code $LASTEXITCODE."
}

$RequiredPaths = @(
    (Join-Path $ResolvedOutputPath 'Deploy-ProfMig.ps1')
    (Join-Path $ResolvedOutputPath 'Uninstall-ProfMig.ps1')
    (Join-Path $ResolvedOutputPath 'ProfMig.Build.psd1')
    (Join-Path $ResolvedOutputPath 'Start-ProfMig.bat')
    (Join-Path $ResolvedOutputPath 'src\ProfMig.ps1')
    (Join-Path $ResolvedOutputPath 'src\Config.psd1')
    (Join-Path $ResolvedOutputPath 'src\Modules')
    (Join-Path $ResolvedOutputPath 'src\Applications')
    (Join-Path $ResolvedOutputPath 'src\Profiles')
)

foreach ($RequiredPath in $RequiredPaths) {

    if (-not (Test-Path -LiteralPath $RequiredPath)) {
        throw "Required Intune package component missing: $RequiredPath"
    }
}

$MetadataPath = Join-Path `
    $ResolvedOutputPath `
    'ProfMig.Build.psd1'

$Metadata = Import-PowerShellDataFile `
    -LiteralPath $MetadataPath

if (
    -not $Metadata.ContainsKey('Name') -or
    [string]$Metadata.Name -ne 'ProfMig'
) {
    throw 'Generated package contains invalid ProfMig build metadata.'
}

if (
    -not $Metadata.ContainsKey('Version') -or
    [string]::IsNullOrWhiteSpace([string]$Metadata.Version)
) {
    throw 'Generated package does not contain a valid ProfMig version.'
}

Write-Host ''
Write-Host 'ProfMig Intune source package created successfully.'
Write-Host "Version: $($Metadata.Version)"
Write-Host "Source:  $ResolvedOutputPath"
Write-Host ''
Write-Host 'Intune install command:'
Write-Host (
    'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass ' +
    '-File .\Deploy-ProfMig.ps1'
)
Write-Host ''
Write-Host 'Intune uninstall command:'
Write-Host (
    'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass ' +
    '-File .\Uninstall-ProfMig.ps1'
)
