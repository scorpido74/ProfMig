<#
.SYNOPSIS
    Creates a SHA-256 integrity manifest for a ProfMig runtime package.

.DESCRIPTION
    Calculates SHA-256 hashes for all release files in a generated ProfMig
    runtime package.

    Runtime output directories and the manifest itself are excluded.

    The manifest complements Authenticode signing by providing integrity
    verification for all package files, including configuration files,
    profiles, application definitions and other non-PowerShell content.

.PARAMETER PackagePath
    Path to the generated ProfMig runtime package.
#>

[CmdletBinding()]
param (
    [string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $PackagePath = Join-Path $RepositoryRoot 'dist\ProfMig'
}

$PackageRoot = [System.IO.Path]::GetFullPath($PackagePath)

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "ProfMig package was not found: $PackageRoot"
}

$ManifestPath = Join-Path $PackageRoot 'ProfMig-SHA256.txt'

$Files = @(
    Get-ChildItem `
        -LiteralPath $PackageRoot `
        -Recurse `
        -File |
    Where-Object {
        $_.FullName -ne $ManifestPath -and
        $_.FullName -notlike (Join-Path $PackageRoot 'Logs\*') -and
        $_.FullName -notlike (Join-Path $PackageRoot 'Reports\*')
    } |
    Sort-Object FullName
)

if ($Files.Count -eq 0) {
    throw 'No release files were found in the ProfMig package.'
}

$ManifestLines = @(
    '# ProfMig SHA-256 Release Manifest'
    "# Generated: $((Get-Date).ToUniversalTime().ToString('o'))"
    "# Files: $($Files.Count)"
    '#'
)

foreach ($File in $Files) {

    $RelativePath = $File.FullName.Substring(
        $PackageRoot.Length
    ).TrimStart('\')

    $Hash = Get-FileHash `
        -LiteralPath $File.FullName `
        -Algorithm SHA256

    $ManifestLines += (
        '{0} *{1}' -f $Hash.Hash, $RelativePath
    )
}

Set-Content `
    -LiteralPath $ManifestPath `
    -Value $ManifestLines `
    -Encoding UTF8

Write-Host 'ProfMig SHA-256 manifest created successfully.'
Write-Host "Package:  $PackageRoot"
Write-Host "Files:    $($Files.Count)"
Write-Host "Manifest: $ManifestPath"
