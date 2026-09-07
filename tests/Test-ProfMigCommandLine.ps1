<#
.SYNOPSIS
    Regression tests for ProfMig command-line and silent-mode validation.

.DESCRIPTION
    Verifies that invalid unattended command-line combinations are rejected
    before a migration can start and that ProfMig returns predictable process
    exit codes.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProfMigPath = Join-Path $ProjectRoot 'src\ProfMig.ps1'

$PassedCount = 0
$FailedCount = 0


function Invoke-ProfMigCliTest {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [int]$ExpectedExitCode
    )

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ProfMigPath `
        @Arguments *> $null

    $actualExitCode = $LASTEXITCODE

    if ($actualExitCode -eq $ExpectedExitCode) {

        $script:PassedCount++

        Write-Host (
            '[PASS] {0} - Exit code {1}' -f
            $Name,
            $actualExitCode
        ) -ForegroundColor Green
    }
    else {

        $script:FailedCount++

        Write-Host (
            '[FAIL] {0} - Expected {1}, got {2}' -f
            $Name,
            $ExpectedExitCode,
            $actualExitCode
        ) -ForegroundColor Red
    }
}


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Command-Line Tests'
Write-Host '========================================'


Invoke-ProfMigCliTest `
    -Name 'Silent mode without profile identifiers' `
    -Arguments @(
        '-Silent'
    ) `
    -ExpectedExitCode 3


Invoke-ProfMigCliTest `
    -Name 'Silent mode with incomplete SID parameters' `
    -Arguments @(
        '-Silent'
        '-SourceSid'
        'S-1-5-21-1000'
    ) `
    -ExpectedExitCode 3


Invoke-ProfMigCliTest `
    -Name 'Silent mode with mixed profile identifiers' `
    -Arguments @(
        '-Silent'
        '-SourceSid'
        'S-1-5-21-1000'
        '-DestinationSid'
        'S-1-5-21-2000'
        '-SourceProfilePath'
        'C:\Users\Test'
    ) `
    -ExpectedExitCode 3


Invoke-ProfMigCliTest `
    -Name 'Silent mode with unknown profile SID' `
    -Arguments @(
        '-Silent'
        '-SourceSid'
        'S-1-5-21-999999999-999999999-999999999-9999'
        '-DestinationSid'
        'S-1-5-21-888888888-888888888-888888888-8888'
    ) `
    -ExpectedExitCode 4


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Command-Line Test Summary'
Write-Host '========================================'

Write-Host "Passed : $PassedCount"
Write-Host "Failed : $FailedCount"

if ($FailedCount -eq 0) {

    Write-Host 'RESULT : PASSED' -ForegroundColor Green
    exit 0
}

Write-Host 'RESULT : FAILED' -ForegroundColor Red
exit 1