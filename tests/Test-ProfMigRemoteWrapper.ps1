<#
.SYNOPSIS
    Regression tests for the generic ProfMig remote execution wrapper.

.DESCRIPTION
    Validates the vendor-neutral remote deployment example introduced in
    Sprint 5.6.

    The test builds a temporary ProfMig runtime package and verifies that the
    remote wrapper:

    - Locates and starts the ProfMig runtime.
    - Preserves ProfMig process exit codes.
    - Supports non-interactive execution.
    - Works independently of the current working directory.
    - Supports execution from a 32-bit management process.
    - Ensures ProfMig executes through 64-bit Windows PowerShell.
    - Resolves the native Program Files directory from a 32-bit process.
    - Returns a predictable result when the ProfMig runtime is missing.

    No real migration is performed by these tests.
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# -----------------------------------------------------------------------------
# Test paths
# -----------------------------------------------------------------------------

$RepositoryRoot = Split-Path `
    -Parent (Split-Path -Parent $PSCommandPath)

$BuildScriptPath = Join-Path `
    $RepositoryRoot `
    'build\New-ProfMigPackage.ps1'

$WrapperPath = Join-Path `
    $RepositoryRoot `
    'examples\remote-deployment\Invoke-ProfMigRemote.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Remote-Wrapper-Test-' + [guid]::NewGuid().ToString('N'))

$RuntimePath = Join-Path `
    $TestRoot `
    'ProfMig'

$PassedTests = 0
$FailedTests = 0


# -----------------------------------------------------------------------------
# Test result helper
# -----------------------------------------------------------------------------

function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [string]$Details
    )

    if ($Passed) {

        $script:PassedTests++

        Write-Host (
            '[PASS] ' + $Name
        ) -ForegroundColor Green
    }
    else {

        $script:FailedTests++

        Write-Host (
            '[FAIL] ' + $Name
        ) -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host ('       ' + $Details)
        }
    }
}


# -----------------------------------------------------------------------------
# Remote wrapper execution helper
# -----------------------------------------------------------------------------

function Invoke-RemoteWrapper {

    param (
        [Parameter(Mandatory)]
        [string]$PowerShellPath,

        [string[]]$Arguments = @(),

        [string]$WorkingDirectory,

        [string]$RuntimeOverride,

        [switch]$UseDefaultInstallPath
    )

    $WrapperArguments = @(
        '-NoProfile'
        '-NonInteractive'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $WrapperPath
    )

    if (-not $UseDefaultInstallPath) {

        $EffectiveRuntimePath = $RuntimePath

        if (-not [string]::IsNullOrWhiteSpace($RuntimeOverride)) {
            $EffectiveRuntimePath = $RuntimeOverride
        }

        $WrapperArguments += @(
            '-InstallPath'
            $EffectiveRuntimePath
        )
    }

    $WrapperArguments += $Arguments

    $PreviousLocation = Get-Location
    $PreviousErrorActionPreference = $ErrorActionPreference

    try {

        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            Set-Location -LiteralPath $WorkingDirectory
        }

        $ErrorActionPreference = 'Continue'

        $Output = @(
            & $PowerShellPath @WrapperArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {

        $ErrorActionPreference = $PreviousErrorActionPreference

        Set-Location `
            -LiteralPath $PreviousLocation.Path
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = $Output
        Text     = ($Output -join [Environment]::NewLine)
    }
}


try {

    Write-Host ''
    Write-Host 'ProfMig Remote Wrapper Tests'
    Write-Host '============================'
    Write-Host ''


    # -------------------------------------------------------------------------
    # Validate test prerequisites
    # -------------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $BuildScriptPath -PathType Leaf)) {
        throw "Build script not found: $BuildScriptPath"
    }

    if (-not (Test-Path -LiteralPath $WrapperPath -PathType Leaf)) {
        throw "Remote wrapper not found: $WrapperPath"
    }


    # -------------------------------------------------------------------------
    # Build isolated runtime package
    # -------------------------------------------------------------------------

    Write-Host 'Preparing temporary ProfMig runtime...'

    $null = New-Item `
        -ItemType Directory `
        -Path $TestRoot `
        -Force

    & $BuildScriptPath `
        -OutputPath $RuntimePath

    if (-not (Test-Path -LiteralPath $RuntimePath -PathType Container)) {
        throw 'Temporary ProfMig runtime was not created.'
    }

    $RuntimeEntryPoint = Join-Path `
        $RuntimePath `
        'src\ProfMig.ps1'

    if (-not (Test-Path -LiteralPath $RuntimeEntryPoint -PathType Leaf)) {
        throw 'Temporary ProfMig runtime does not contain ProfMig.ps1.'
    }

    Write-Host ''


    # -------------------------------------------------------------------------
    # Test 1 - Configuration error propagation
    # -------------------------------------------------------------------------

    Write-Host 'Test: ConfigurationError propagation'

    $PowerShell64 = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'

    $Result = Invoke-RemoteWrapper `
        -PowerShellPath $PowerShell64

    Write-TestResult `
        -Name 'ConfigurationError exit code 3 is returned unchanged' `
        -Passed ($Result.ExitCode -eq 3) `
        -Details $Result.Text


    # -------------------------------------------------------------------------
    # Test 2 - Validation error propagation
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: ValidationError propagation'

    $InvalidProfileArguments = @(
        '-SourceSid'
        'S-1-5-21-999999999-999999999-999999999-1001'
        '-DestinationSid'
        'S-1-5-21-999999999-999999999-999999999-1002'
    )

    $Result = Invoke-RemoteWrapper `
        -PowerShellPath $PowerShell64 `
        -Arguments $InvalidProfileArguments

    Write-TestResult `
        -Name 'ValidationError exit code 4 is returned unchanged' `
        -Passed ($Result.ExitCode -eq 4) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'ProfMig reaches profile validation through wrapper' `
        -Passed (
            $Result.Text -match 'ProfileNotFound'
        ) `
        -Details $Result.Text


    # -------------------------------------------------------------------------
    # Test 3 - Working-directory independence
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: working-directory independence'

    $Result = Invoke-RemoteWrapper `
        -PowerShellPath $PowerShell64 `
        -Arguments $InvalidProfileArguments `
        -WorkingDirectory ([System.IO.Path]::GetTempPath())

    Write-TestResult `
        -Name 'Wrapper works from an unrelated working directory' `
        -Passed ($Result.ExitCode -eq 4) `
        -Details $Result.Text


    # -------------------------------------------------------------------------
    # Test 4 - 32-bit management process
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: 32-bit management process'

    if ([Environment]::Is64BitOperatingSystem) {

        $PowerShell32 = Join-Path `
            $env:SystemRoot `
            'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'

        if (Test-Path -LiteralPath $PowerShell32 -PathType Leaf) {

            $Result = Invoke-RemoteWrapper `
                -PowerShellPath $PowerShell32 `
                -Arguments $InvalidProfileArguments

            Write-TestResult `
                -Name '32-bit wrapper launches ProfMig through 64-bit PowerShell' `
                -Passed (
                    $Result.ExitCode -eq 4 -and
                    $Result.Text -match 'ProfileNotFound'
                ) `
                -Details $Result.Text
        }
        else {

            Write-TestResult `
                -Name '32-bit Windows PowerShell is available for validation' `
                -Passed $false `
                -Details "Not found: $PowerShell32"
        }
    }
    else {

        Write-TestResult `
            -Name '64-bit operating system is available for 32-bit wrapper test' `
            -Passed $false `
            -Details 'ProfMig requires a 64-bit Windows operating system.'
    }


        # -------------------------------------------------------------------------
    # Test 5 - Native Program Files resolution from 32-bit process
    #
    # No InstallPath is supplied. The wrapper must resolve the native
    # 64-bit Program Files directory itself.
    #
    # Two valid situations are supported:
    #
    # 1. ProfMig is installed in the default location.
    #    The wrapper must find and start it. With no migration identifiers,
    #    ProfMig returns ConfigurationError exit code 3.
    #
    # 2. ProfMig is not installed in the default location.
    #    The wrapper must return exit code 99 and report the native
    #    C:\Program Files\ProfMig runtime path.
    #
    # In both situations the test proves that a 32-bit management process
    # resolves the native Program Files directory rather than
    # Program Files (x86).
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: 32-bit default installation path'

    if ([Environment]::Is64BitOperatingSystem) {

        $PowerShell32 = Join-Path `
            $env:SystemRoot `
            'SysWOW64\WindowsPowerShell\v1.0\powershell.exe'

        if (Test-Path -LiteralPath $PowerShell32 -PathType Leaf) {

            if ([string]::IsNullOrWhiteSpace($env:ProgramW6432)) {
                throw 'ProgramW6432 is not available on this 64-bit system.'
            }

            $ExpectedInstallPath = Join-Path `
                $env:ProgramW6432 `
                'ProfMig'

            $ExpectedRuntimePath = Join-Path `
                $ExpectedInstallPath `
                'src\ProfMig.ps1'

            $Result = Invoke-RemoteWrapper `
                -PowerShellPath $PowerShell32 `
                -UseDefaultInstallPath

            if (
                Test-Path `
                    -LiteralPath $ExpectedRuntimePath `
                    -PathType Leaf
            ) {

                # A runtime exists in the native default location.
                # Reaching ProfMig and receiving ConfigurationError 3 proves
                # that the wrapper resolved and started that runtime.

                $PathResolutionPassed = (
                    $Result.ExitCode -eq 3 -and
                    $Result.Text -match 'MissingProfileIdentifiers'
                )

                $PathResolutionDetails = $Result.Text
            }
            else {

                # No runtime exists in the native default location.
                # The wrapper must report the exact native runtime path.

                $PathResolutionPassed = (
                    $Result.ExitCode -eq 99 -and
                    $Result.Text -match [regex]::Escape(
                        $ExpectedRuntimePath
                    )
                )

                $PathResolutionDetails = $Result.Text
            }

            Write-TestResult `
                -Name '32-bit wrapper resolves native Program Files as default install path' `
                -Passed $PathResolutionPassed `
                -Details $PathResolutionDetails
        }
        else {

            Write-TestResult `
                -Name '32-bit Windows PowerShell is available for default path validation' `
                -Passed $false `
                -Details "Not found: $PowerShell32"
        }
    }
    else {

        Write-TestResult `
            -Name '64-bit operating system is available for default path validation' `
            -Passed $false `
            -Details 'ProfMig requires a 64-bit Windows operating system.'
    }


    # -------------------------------------------------------------------------
    # Test 6 - Missing runtime
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: missing runtime'

    $MissingRuntime = Join-Path `
        $TestRoot `
        'MissingProfMig'

    $Result = Invoke-RemoteWrapper `
        -PowerShellPath $PowerShell64 `
        -RuntimeOverride $MissingRuntime

    Write-TestResult `
        -Name 'Missing ProfMig runtime returns exit code 99' `
        -Passed ($Result.ExitCode -eq 99) `
        -Details $Result.Text


    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'ProfMig Remote Wrapper Test Summary'
    Write-Host '==================================='
    Write-Host "Passed: $PassedTests"
    Write-Host "Failed: $FailedTests"

    if ($FailedTests -gt 0) {
        exit 1
    }

    Write-Host ''
    Write-Host (
        'PASS: ProfMig remote wrapper validation completed successfully.'
    ) -ForegroundColor Green

    exit 0
}
catch {

    Write-Host ''
    Write-Host (
        'FATAL: Remote wrapper test execution failed: ' +
        $_.Exception.Message
    ) -ForegroundColor Red

    exit 1
}
finally {

    if (Test-Path -LiteralPath $TestRoot) {

        try {

            Remove-Item `
                -LiteralPath $TestRoot `
                -Recurse `
                -Force
        }
        catch {

            Write-Warning (
                'Unable to remove temporary remote wrapper test directory: ' +
                $TestRoot
            )
        }
    }
}