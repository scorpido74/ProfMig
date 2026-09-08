<#
.SYNOPSIS
    Creates the ProfMig Microsoft Intune Win32 package.

.DESCRIPTION
    Builds and validates the ProfMig runtime package and optionally creates
    the final Microsoft Intune Win32 .intunewin package by using the Microsoft
    Win32 Content Prep Tool.

    The Microsoft Win32 Content Prep Tool is an external build dependency and
    is not included in the ProfMig repository.

.PARAMETER OutputPath
    Directory in which the Intune source package is created.

.PARAMETER PackageOutputPath
    Directory in which the final .intunewin package is created.

.PARAMETER IntuneWinAppUtilPath
    Path to Microsoft's IntuneWinAppUtil.exe.

.PARAMETER SourceOnly
    Creates and validates only the Intune source package without generating
    the final .intunewin package.
#>

[CmdletBinding()]
param (
    [string]$OutputPath = (
        Join-Path $PSScriptRoot '..\..\dist\Intune\ProfMig'
    ),

    [string]$PackageOutputPath = (
        Join-Path $PSScriptRoot '..\..\dist\Intune\Package'
    ),

    [string]$IntuneWinAppUtilPath = (
        Join-Path $PSScriptRoot '..\Tools\IntuneWinAppUtil.exe'
    ),

    [switch]$SourceOnly
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

$ResolvedPackageOutputPath = [System.IO.Path]::GetFullPath(
    $PackageOutputPath
)

$ResolvedIntuneWinAppUtilPath = [System.IO.Path]::GetFullPath(
    $IntuneWinAppUtilPath
)

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

$ProfMigVersion = [string]$Metadata.Version

Write-Host ''
Write-Host 'ProfMig Intune source package created successfully.'
Write-Host "Version: $ProfMigVersion"
Write-Host "Source:  $ResolvedOutputPath"

if ($SourceOnly) {

    Write-Host ''
    Write-Host 'Source-only build requested.'
    Write-Host 'Skipping .intunewin creation.'

    exit 0
}

if (
    -not (
        Test-Path `
            -LiteralPath $ResolvedIntuneWinAppUtilPath `
            -PathType Leaf
    )
) {
    throw (
        'Microsoft Win32 Content Prep Tool not found: ' +
        $ResolvedIntuneWinAppUtilPath
    )
}

Write-Host ''
Write-Host 'Creating Microsoft Intune Win32 package...'
Write-Host "Tool:   $ResolvedIntuneWinAppUtilPath"
Write-Host "Output: $ResolvedPackageOutputPath"

if (Test-Path -LiteralPath $ResolvedPackageOutputPath) {

    Remove-Item `
        -LiteralPath $ResolvedPackageOutputPath `
        -Recurse `
        -Force
}

New-Item `
    -ItemType Directory `
    -Path $ResolvedPackageOutputPath `
    -Force | Out-Null

& $ResolvedIntuneWinAppUtilPath `
    -c $ResolvedOutputPath `
    -s 'Deploy-ProfMig.ps1' `
    -o $ResolvedPackageOutputPath `
    -q

$ContentPrepExitCode = $LASTEXITCODE

if ($ContentPrepExitCode -ne 0) {
    throw (
        'Microsoft Win32 Content Prep Tool failed with exit code ' +
        $ContentPrepExitCode +
        '.'
    )
}

$GeneratedPackagePath = Join-Path `
    $ResolvedPackageOutputPath `
    'Deploy-ProfMig.intunewin'

if (-not (Test-Path -LiteralPath $GeneratedPackagePath -PathType Leaf)) {
    throw (
        'Expected Intune Win32 package was not generated: ' +
        $GeneratedPackagePath
    )
}

$FinalPackageName = 'ProfMig-{0}.intunewin' -f $ProfMigVersion

$FinalPackagePath = Join-Path `
    $ResolvedPackageOutputPath `
    $FinalPackageName

Move-Item `
    -LiteralPath $GeneratedPackagePath `
    -Destination $FinalPackagePath `
    -Force

$FinalPackage = Get-Item `
    -LiteralPath $FinalPackagePath

if ($FinalPackage.Length -le 0) {
    throw "Generated Intune package is empty: $FinalPackagePath"
}

Write-Host ''
Write-Host 'ProfMig Intune Win32 package created successfully.'
Write-Host "Version: $ProfMigVersion"
Write-Host "Package: $FinalPackagePath"
Write-Host (
    'Size:    {0:N2} MB' -f ($FinalPackage.Length / 1MB)
)

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

Write-Host ''
Write-Host 'Intune detection script:'
Write-Host $DetectionScript

Write-Host ''
Write-Host 'Expected version:'
Write-Host $ProfMigVersion
