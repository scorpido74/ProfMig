<#
.SYNOPSIS
    Authenticode-signs a generated ProfMig runtime package.

.DESCRIPTION
    Signs executable PowerShell files in an existing ProfMig runtime package.

    Source files in the development repository are never modified. Signing is
    performed only against the generated runtime package.

    The signing certificate must:
    - Be available in the CurrentUser certificate store.
    - Have an accessible private key.
    - Be valid for Code Signing.

    Hardware-backed certificates, including YubiKey PIV certificates, are
    supported through the Windows certificate provider.

.PARAMETER PackagePath
    Path to the generated ProfMig runtime package.

.PARAMETER CertificateThumbprint
    Thumbprint of the Code Signing certificate in Cert:\CurrentUser\My.
#>

[CmdletBinding()]
param (
    [string]$PackagePath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$CertificateThumbprint
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

$NormalizedThumbprint = (
    $CertificateThumbprint -replace '\s', ''
).ToUpperInvariant()

$Certificate = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object {
        $_.Thumbprint -eq $NormalizedThumbprint
    } |
    Select-Object -First 1

if ($null -eq $Certificate) {
    throw "Signing certificate was not found: $NormalizedThumbprint"
}

if (-not $Certificate.HasPrivateKey) {
    throw 'Signing certificate does not have an accessible private key.'
}

$CodeSigningOid = '1.3.6.1.5.5.7.3.3'

$HasCodeSigningEku = @(
    $Certificate.Extensions |
        Where-Object {
            $_.Oid.Value -eq '2.5.29.37'
        } |
        ForEach-Object {
            $_.EnhancedKeyUsages |
                Where-Object {
                    $_.Value -eq $CodeSigningOid
                }
        }
).Count -gt 0

if (-not $HasCodeSigningEku) {
    throw 'Certificate is not valid for Code Signing.'
}

$FilesToSign = @(
    Get-ChildItem `
        -LiteralPath $PackageRoot `
        -Recurse `
        -File |
    Where-Object {
        $_.Extension -in @('.ps1', '.psm1')
    } |
    Sort-Object FullName
)

if ($FilesToSign.Count -eq 0) {
    throw 'No executable PowerShell files were found in the package.'
}

Write-Host 'Signing ProfMig runtime package...'
Write-Host "Package:     $PackageRoot"
Write-Host "Certificate: $($Certificate.Subject)"
Write-Host "Thumbprint:  $($Certificate.Thumbprint)"
Write-Host "Files:       $($FilesToSign.Count)"
Write-Host ''

foreach ($File in $FilesToSign) {

    $RelativePath = $File.FullName.Substring(
        $PackageRoot.Length
    ).TrimStart('\')

    Write-Host "Signing: $RelativePath"

    $Result = Set-AuthenticodeSignature `
        -LiteralPath $File.FullName `
        -Certificate $Certificate `
        -HashAlgorithm SHA256

    if ($Result.Status -ne 'Valid') {

        throw (
            "Signing failed for '$RelativePath'. " +
            "Status: $($Result.Status). " +
            "Message: $($Result.StatusMessage)"
        )
    }
}

Write-Host ''
Write-Host 'ProfMig package signing completed successfully.'
Write-Host "Signed files: $($FilesToSign.Count)"
