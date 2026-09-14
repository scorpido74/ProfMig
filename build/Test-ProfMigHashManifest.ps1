<#
.SYNOPSIS
    Validates a ProfMig SHA-256 release manifest.

.DESCRIPTION
    Verifies the integrity and completeness of a ProfMig runtime package
    against ProfMig-SHA256.txt.

    Validation fails when:
    - A file hash does not match.
    - A manifest file is missing from the package.
    - An unexpected file exists in the package.

    Runtime output directories Logs and Reports are excluded.

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
$ManifestPath = Join-Path $PackageRoot 'ProfMig-SHA256.txt'

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "ProfMig package was not found: $PackageRoot"
}

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "ProfMig SHA-256 manifest was not found: $ManifestPath"
}

$ManifestEntries = @{}

foreach ($Line in Get-Content -LiteralPath $ManifestPath) {

    if ([string]::IsNullOrWhiteSpace($Line)) {
        continue
    }

    if ($Line.StartsWith('#')) {
        continue
    }

    if ($Line -notmatch '^([A-Fa-f0-9]{64}) \*(.+)$') {
        throw "Invalid manifest entry: $Line"
    }

    $Hash = $Matches[1].ToUpperInvariant()
    $RelativePath = $Matches[2]

    if ($ManifestEntries.ContainsKey($RelativePath)) {
        throw "Duplicate manifest entry: $RelativePath"
    }

    $ManifestEntries[$RelativePath] = $Hash
}

if ($ManifestEntries.Count -eq 0) {
    throw 'SHA-256 manifest contains no file entries.'
}

$PackageFiles = @(
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

$Failures = @()

Write-Host 'Validating ProfMig SHA-256 manifest...'
Write-Host "Package:  $PackageRoot"
Write-Host "Manifest: $ManifestPath"
Write-Host "Files:    $($PackageFiles.Count)"
Write-Host ''

foreach ($RelativePath in ($ManifestEntries.Keys | Sort-Object)) {

    $ExpectedHash = $ManifestEntries[$RelativePath]
    $FilePath = Join-Path $PackageRoot $RelativePath

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {

        Write-Host "[FAIL] $RelativePath - Missing"

        $Failures += [PSCustomObject]@{
            File   = $RelativePath
            Status = 'Missing'
        }

        continue
    }

    $ActualHash = (
        Get-FileHash `
            -LiteralPath $FilePath `
            -Algorithm SHA256
    ).Hash.ToUpperInvariant()

    if ($ActualHash -ne $ExpectedHash) {

        Write-Host "[FAIL] $RelativePath - HashMismatch"

        $Failures += [PSCustomObject]@{
            File   = $RelativePath
            Status = 'HashMismatch'
        }

        continue
    }

    Write-Host "[PASS] $RelativePath"
}

foreach ($File in $PackageFiles) {

    $RelativePath = $File.FullName.Substring(
        $PackageRoot.Length
    ).TrimStart('\')

    if (-not $ManifestEntries.ContainsKey($RelativePath)) {

        Write-Host "[FAIL] $RelativePath - Unexpected"

        $Failures += [PSCustomObject]@{
            File   = $RelativePath
            Status = 'Unexpected'
        }
    }
}

Write-Host ''

if ($Failures.Count -gt 0) {

    Write-Host 'SHA-256 manifest validation failed.'
    Write-Host ''

    $Failures |
        Format-Table File, Status -AutoSize

    throw (
        "$($Failures.Count) package integrity " +
        'validation failure(s) detected.'
    )
}

Write-Host 'ProfMig SHA-256 manifest validation completed successfully.'
Write-Host "Valid files: $($ManifestEntries.Count)/$($ManifestEntries.Count)"
