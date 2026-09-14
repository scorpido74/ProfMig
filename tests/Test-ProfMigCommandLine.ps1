<#
.SYNOPSIS
    Regression tests for ProfMig command-line and silent-mode validation.

.DESCRIPTION
    Verifies that invalid unattended command-line combinations are rejected
    before a migration can start and that ProfMig returns predictable process
    exit codes.

    Silent-mode tests are executed using non-interactive PowerShell to validate
    unattended execution for remote management scenarios.
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
        -NonInteractive `
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


# ---------------------------------------------------------------------------
# Test 1 - Silent mode requires profile identifiers
# ---------------------------------------------------------------------------

Invoke-ProfMigCliTest `
    -Name 'Silent mode without profile identifiers' `
    -Arguments @(
        '-Silent'
    ) `
    -ExpectedExitCode 3


# ---------------------------------------------------------------------------
# Test 2 - SID mode requires source and destination
# ---------------------------------------------------------------------------

Invoke-ProfMigCliTest `
    -Name 'Silent mode with incomplete SID parameters' `
    -Arguments @(
        '-Silent'
        '-SourceSid'
        'S-1-5-21-1000'
    ) `
    -ExpectedExitCode 3


# ---------------------------------------------------------------------------
# Test 3 - Profile-path mode requires source and destination
# ---------------------------------------------------------------------------

Invoke-ProfMigCliTest `
    -Name 'Silent mode with incomplete profile-path parameters' `
    -Arguments @(
        '-Silent'
        '-SourceProfilePath'
        'C:\Users\Test'
    ) `
    -ExpectedExitCode 3


# ---------------------------------------------------------------------------
# Test 4 - SID and profile-path modes cannot be mixed
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Test 5 - Profile-path mode cannot contain SID identifiers
# ---------------------------------------------------------------------------

Invoke-ProfMigCliTest `
    -Name 'Silent mode with mixed path and SID identifiers' `
    -Arguments @(
        '-Silent'
        '-SourceProfilePath'
        'C:\Users\Test'
        '-DestinationProfilePath'
        'C:\Users\Test2'
        '-DestinationSid'
        'S-1-5-21-2000'
    ) `
    -ExpectedExitCode 3


# ---------------------------------------------------------------------------
# Test 6 - Unknown profile SIDs are rejected
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Test 7 - Unknown profile paths are rejected
# ---------------------------------------------------------------------------

Invoke-ProfMigCliTest `
    -Name 'Silent mode with unknown profile paths' `
    -Arguments @(
        '-Silent'
        '-SourceProfilePath'
        'C:\ProfMig-Does-Not-Exist-Source'
        '-DestinationProfilePath'
        'C:\ProfMig-Does-Not-Exist-Destination'
    ) `
    -ExpectedExitCode 4


# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

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