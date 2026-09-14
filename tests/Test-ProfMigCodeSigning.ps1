<#
.SYNOPSIS
    Runs ProfMig Sprint 5.7 code-signing and integrity regression tests.

.DESCRIPTION
    Validates the ProfMig release security tooling without requiring access
    to the signing private key.

    Tests:
    - Valid signed package passes Authenticode validation.
    - Modified signed PowerShell code is rejected.
    - Valid SHA-256 manifest passes validation.
    - Modified package content is rejected.
    - Missing package content is rejected.
    - Unexpected package content is rejected.

    The existing signed package under dist\ProfMig is used as the trusted
    test source.

    All destructive tests are performed against isolated temporary copies.
    The original runtime package is never modified.

.PARAMETER PackagePath
    Path to an existing signed ProfMig runtime package containing a valid
    ProfMig-SHA256.txt manifest.
#>

[CmdletBinding()]
param (
    [string]$PackagePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# -----------------------------------------------------------------------------
# Resolve paths
# -----------------------------------------------------------------------------

$RepositoryRoot = (
    Resolve-Path (Join-Path $PSScriptRoot '..')
).Path

if ([string]::IsNullOrWhiteSpace($PackagePath)) {
    $PackagePath = Join-Path $RepositoryRoot 'dist\ProfMig'
}

$PackageRoot = [System.IO.Path]::GetFullPath($PackagePath)

$SignatureValidator = Join-Path `
    $RepositoryRoot `
    'build\Test-ProfMigSignatures.ps1'

$HashValidator = Join-Path `
    $RepositoryRoot `
    'build\Test-ProfMigHashManifest.ps1'

# -----------------------------------------------------------------------------
# Validate prerequisites
# -----------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $PackageRoot -PathType Container)) {
    throw "ProfMig package was not found: $PackageRoot"
}

if (-not (Test-Path -LiteralPath $SignatureValidator -PathType Leaf)) {
    throw "Signature validator was not found: $SignatureValidator"
}

if (-not (Test-Path -LiteralPath $HashValidator -PathType Leaf)) {
    throw "Hash validator was not found: $HashValidator"
}

$ManifestPath = Join-Path `
    $PackageRoot `
    'ProfMig-SHA256.txt'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "ProfMig SHA-256 manifest was not found: $ManifestPath"
}

# -----------------------------------------------------------------------------
# Test result handling
# -----------------------------------------------------------------------------

$Passed = 0
$Failed = 0

function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Success
    )

    if ($Success) {

        Write-Host "[PASS] $Name"
        $script:Passed++
    }
    else {

        Write-Host "[FAIL] $Name"
        $script:Failed++
    }
}

Write-Host 'Running ProfMig Sprint 5.7 security regression tests...'
Write-Host ''

# -----------------------------------------------------------------------------
# Test 1 - Valid Authenticode package
# -----------------------------------------------------------------------------

$Accepted = $true

try {

    & $SignatureValidator `
        -PackagePath $PackageRoot *> $null
}
catch {

    $Accepted = $false
}

Write-TestResult `
    -Name 'Valid Authenticode package accepted' `
    -Success $Accepted

# -----------------------------------------------------------------------------
# Test 2 - Tampered signed PowerShell file
# -----------------------------------------------------------------------------

$SignatureTamperRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-Signature-Test-' + [guid]::NewGuid().ToString('N'))

try {

    Copy-Item `
        -LiteralPath $PackageRoot `
        -Destination $SignatureTamperRoot `
        -Recurse

    $TamperedModule = Join-Path `
        $SignatureTamperRoot `
        'src\Modules\ProfMig.Core.psm1'

    if (-not (Test-Path -LiteralPath $TamperedModule -PathType Leaf)) {
        throw "Tamper test module was not found: $TamperedModule"
    }

    $Content = Get-Content `
        -LiteralPath $TamperedModule `
        -Raw

    Set-Content `
        -LiteralPath $TamperedModule `
        -Value ("# Sprint 5.7 Authenticode tamper test`r`n" + $Content) `
        -Encoding UTF8 `
        -NoNewline

    $Rejected = $false

    try {

        & $SignatureValidator `
            -PackagePath $SignatureTamperRoot *> $null
    }
    catch {

        $Rejected = $true
    }

    Write-TestResult `
        -Name 'Tampered Authenticode file rejected' `
        -Success $Rejected
}
finally {

    Remove-Item `
        -LiteralPath $SignatureTamperRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Test 3 - Valid SHA-256 manifest
# -----------------------------------------------------------------------------

$Accepted = $true

try {

    & $HashValidator `
        -PackagePath $PackageRoot *> $null
}
catch {

    $Accepted = $false
}

Write-TestResult `
    -Name 'Valid SHA-256 manifest accepted' `
    -Success $Accepted

# -----------------------------------------------------------------------------
# Test 4 - Modified package file
# -----------------------------------------------------------------------------

$ModifiedRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-Modified-Test-' + [guid]::NewGuid().ToString('N'))

try {

    Copy-Item `
        -LiteralPath $PackageRoot `
        -Destination $ModifiedRoot `
        -Recurse

    $ModifiedFile = Join-Path `
        $ModifiedRoot `
        'src\Config.psd1'

    if (-not (Test-Path -LiteralPath $ModifiedFile -PathType Leaf)) {
        throw "Manifest test file was not found: $ModifiedFile"
    }

    Add-Content `
        -LiteralPath $ModifiedFile `
        -Value "`n# Sprint 5.7 manifest tamper test"

    $Rejected = $false

    try {

        & $HashValidator `
            -PackagePath $ModifiedRoot *> $null
    }
    catch {

        $Rejected = $true
    }

    Write-TestResult `
        -Name 'Modified package file detected' `
        -Success $Rejected
}
finally {

    Remove-Item `
        -LiteralPath $ModifiedRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Test 5 - Missing package file
# -----------------------------------------------------------------------------

$MissingRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-Missing-Test-' + [guid]::NewGuid().ToString('N'))

try {

    Copy-Item `
        -LiteralPath $PackageRoot `
        -Destination $MissingRoot `
        -Recurse

    $MissingFile = Join-Path `
        $MissingRoot `
        'src\Profiles\Standard.psd1'

    if (-not (Test-Path -LiteralPath $MissingFile -PathType Leaf)) {
        throw "Manifest test file was not found: $MissingFile"
    }

    Remove-Item `
        -LiteralPath $MissingFile `
        -Force

    $Rejected = $false

    try {

        & $HashValidator `
            -PackagePath $MissingRoot *> $null
    }
    catch {

        $Rejected = $true
    }

    Write-TestResult `
        -Name 'Missing package file detected' `
        -Success $Rejected
}
finally {

    Remove-Item `
        -LiteralPath $MissingRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Test 6 - Unexpected package file
# -----------------------------------------------------------------------------

$UnexpectedRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-Unexpected-Test-' + [guid]::NewGuid().ToString('N'))

try {

    Copy-Item `
        -LiteralPath $PackageRoot `
        -Destination $UnexpectedRoot `
        -Recurse

    $UnexpectedFile = Join-Path `
        $UnexpectedRoot `
        'Unexpected.txt'

    Set-Content `
        -LiteralPath $UnexpectedFile `
        -Value 'Unexpected ProfMig release content' `
        -Encoding UTF8

    $Rejected = $false

    try {

        & $HashValidator `
            -PackagePath $UnexpectedRoot *> $null
    }
    catch {

        $Rejected = $true
    }

    Write-TestResult `
        -Name 'Unexpected package file detected' `
        -Success $Rejected
}
finally {

    Remove-Item `
        -LiteralPath $UnexpectedRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# Results
# -----------------------------------------------------------------------------

Write-Host ''
Write-Host '========================================'
Write-Host 'Sprint 5.7 security regression results'
Write-Host '========================================'
Write-Host "Passed: $Passed"
Write-Host "Failed: $Failed"

if ($Failed -gt 0) {

    throw (
        "$Failed Sprint 5.7 security regression test(s) failed."
    )
}

Write-Host ''
Write-Host 'All Sprint 5.7 security regression tests passed.'