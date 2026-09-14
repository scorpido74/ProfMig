<#
.SYNOPSIS
    Validates ProfMig process exit codes for remote execution.

.DESCRIPTION
    Verifies that representative ProfMig result categories are returned to
    the calling process as predictable Windows process exit codes.

    The complete Get-ProfMigExitCode mapping is covered by the existing
    Milestone 3 recovery tests. This test focuses on process-level behaviour
    relevant to RMM and remote management tooling.

.NOTES
    Project : ProfMig
    Sprint  : 5.6 - RMM & Remote Deployment
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProfMigPath = Join-Path $ProjectRoot 'src\ProfMig.ps1'

$Passed = 0
$Failed = 0


function Invoke-ExitCodeTest {

    [CmdletBinding()]
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

    $ActualExitCode = $LASTEXITCODE

    if ($ActualExitCode -eq $ExpectedExitCode) {

        Write-Host (
            '[PASS] {0} - Exit code {1}' -f
            $Name,
            $ActualExitCode
        )

        $script:Passed++
    }
    else {

        Write-Host (
            '[FAIL] {0} - Expected {1}, received {2}' -f
            $Name,
            $ExpectedExitCode,
            $ActualExitCode
        )

        $script:Failed++
    }
}


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Exit-Code Tests'
Write-Host '========================================'


# ---------------------------------------------------------------------------
# Test 1 - Successful process
# ---------------------------------------------------------------------------

Invoke-ExitCodeTest `
    -Name 'Successful version command' `
    -Arguments @(
        '-Version'
    ) `
    -ExpectedExitCode 0


# ---------------------------------------------------------------------------
# Test 2 - Configuration error
# ---------------------------------------------------------------------------

Invoke-ExitCodeTest `
    -Name 'Configuration error' `
    -Arguments @(
        '-Silent'
    ) `
    -ExpectedExitCode 3


# ---------------------------------------------------------------------------
# Test 3 - Validation error
# ---------------------------------------------------------------------------

Invoke-ExitCodeTest `
    -Name 'Validation error' `
    -Arguments @(
        '-Silent'
        '-SourceSid'
        'S-1-5-21-999999999-999999999-999999999-9998'
        '-DestinationSid'
        'S-1-5-21-999999999-999999999-999999999-9999'
    ) `
    -ExpectedExitCode 4


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Exit-Code Summary'
Write-Host '========================================'
Write-Host "Passed : $Passed"
Write-Host "Failed : $Failed"

if ($Failed -eq 0) {

    Write-Host 'RESULT : PASSED'
    exit 0
}

Write-Host 'RESULT : FAILED'
exit 1
