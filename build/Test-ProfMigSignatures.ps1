<#
.SYNOPSIS
    Validates Authenticode signatures in a ProfMig runtime package.

.DESCRIPTION
    Verifies that all executable PowerShell files in a generated ProfMig
    runtime package have a valid Authenticode signature.

    The validation is intended for release verification and automated
    deployment pipelines.

    Any missing, invalid, tampered or unsigned executable PowerShell file
    causes validation to fail.

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

$Files = @(
    Get-ChildItem `
        -LiteralPath $PackageRoot `
        -Recurse `
        -File |
    Where-Object {
        $_.Extension -in @('.ps1', '.psm1')
    } |
    Sort-Object FullName
)

if ($Files.Count -eq 0) {
    throw 'No executable PowerShell files were found in the package.'
}

Write-Host 'Validating ProfMig Authenticode signatures...'
Write-Host "Package: $PackageRoot"
Write-Host "Files:   $($Files.Count)"
Write-Host ''

$Failures = @()

foreach ($File in $Files) {

    $RelativePath = $File.FullName.Substring(
        $PackageRoot.Length
    ).TrimStart('\')

    $Signature = Get-AuthenticodeSignature `
        -LiteralPath $File.FullName

    if ($Signature.Status -eq 'Valid') {

        Write-Host "[PASS] $RelativePath"
    }
    else {

        Write-Host (
            "[FAIL] $RelativePath - $($Signature.Status)"
        )

        $Failures += [PSCustomObject]@{
            File          = $RelativePath
            Status        = $Signature.Status
            StatusMessage = $Signature.StatusMessage
        }
    }
}

Write-Host ''

if ($Failures.Count -gt 0) {

    Write-Host 'Signature validation failed.'
    Write-Host ''

    $Failures |
        Format-Table File, Status, StatusMessage -AutoSize

    throw (
        "$($Failures.Count) of $($Files.Count) " +
        'PowerShell files failed signature validation.'
    )
}

Write-Host 'ProfMig signature validation completed successfully.'
Write-Host "Valid signatures: $($Files.Count)/$($Files.Count)"
