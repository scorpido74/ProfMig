<#
.SYNOPSIS
    Validates ProfMig uninstall and reinstall behavior.

.DESCRIPTION
    Builds a ProfMig runtime package and validates the uninstall lifecycle
    using temporary installation directories.

    The tests cover:
    - Normal uninstall with persistent data preservation
    - Reinstall after a preserved-data uninstall
    - Complete uninstall with -RemoveData
    - Protection against uninstalling an unrelated directory
    - Uninstall of a non-existent installation

    No user profile migration is performed.
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path -Parent $PSScriptRoot

$BuildScript = Join-Path `
    $RepositoryRoot `
    'build\New-ProfMigPackage.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Uninstall-Test-' + [guid]::NewGuid().ToString('N'))

$PackageRoot = Join-Path `
    $TestRoot `
    'Package'

$InstallRoot = Join-Path `
    $TestRoot `
    'Installed'

$SafetyRoot = Join-Path `
    $TestRoot `
    'Safety'

$Passed = 0
$Failed = 0

function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Success,

        [string]$Details
    )

    if ($Success) {

        $script:Passed++

        Write-Host (
            '[PASS] ' +
            $Name
        )
    }
    else {

        $script:Failed++

        Write-Host (
            '[FAIL] ' +
            $Name
        )

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host "       $Details"
        }
    }
}

function Invoke-TestPowerShell {

    param (
        [Parameter(Mandatory)]
        [string]$ScriptPath,

        [string[]]$Arguments = @()
    )

    $PowerShellArguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $ScriptPath
    )

    $PowerShellArguments += $Arguments

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {

        $ErrorActionPreference = 'Continue'

        $Output = @(
            & powershell.exe @PowerShellArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {

        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = $Output
    }
}

try {

    Write-Host '=== ProfMig Uninstall Test ==='
    Write-Host "Temporary root: $TestRoot"
    Write-Host ''

    # -------------------------------------------------------------------------
    # Build runtime package
    # -------------------------------------------------------------------------

    & $BuildScript `
        -OutputPath $PackageRoot

    $DeployScript = Join-Path `
        $PackageRoot `
        'Deploy-ProfMig.ps1'

    $UninstallScript = Join-Path `
        $PackageRoot `
        'Uninstall-ProfMig.ps1'

    if (-not (Test-Path -LiteralPath $DeployScript -PathType Leaf)) {
        throw 'Packaged deployment script was not found.'
    }

    if (-not (Test-Path -LiteralPath $UninstallScript -PathType Leaf)) {
        throw 'Packaged uninstall script was not found.'
    }

    # -------------------------------------------------------------------------
    # Test 1 - Clean deployment
    # -------------------------------------------------------------------------

    $DeployResult = Invoke-TestPowerShell `
        -ScriptPath $DeployScript `
        -Arguments @(
            '-InstallPath'
            $InstallRoot
        )

    Write-TestResult `
        -Name 'Clean deployment succeeds' `
        -Success ($DeployResult.ExitCode -eq 0) `
        -Details (
            'Expected exit code 0, actual: ' +
            $DeployResult.ExitCode
        )

    # -------------------------------------------------------------------------
    # Create persistent test data
    # -------------------------------------------------------------------------

    $LogFile = Join-Path `
        $InstallRoot `
        'Logs\preserve.log'

    $ReportFile = Join-Path `
        $InstallRoot `
        'Reports\preserve.txt'

    $BackupDirectory = Join-Path `
        $InstallRoot `
        'Backup'

    $BackupFile = Join-Path `
        $BackupDirectory `
        'preserve.bak'

    if (
        -not (
            Test-Path `
                -LiteralPath $BackupDirectory `
                -PathType Container
        )
    ) {

        $null = New-Item `
            -ItemType Directory `
            -Path $BackupDirectory `
            -Force
    }

    Set-Content `
        -LiteralPath $LogFile `
        -Value 'Persistent ProfMig log'

    Set-Content `
        -LiteralPath $ReportFile `
        -Value 'Persistent ProfMig report'

    Set-Content `
        -LiteralPath $BackupFile `
        -Value 'Persistent ProfMig backup'

    # -------------------------------------------------------------------------
    # Test 2 - Normal uninstall
    # -------------------------------------------------------------------------

    $InstalledUninstallScript = Join-Path `
        $InstallRoot `
        'Uninstall-ProfMig.ps1'

    $UninstallResult = Invoke-TestPowerShell `
        -ScriptPath $InstalledUninstallScript `
        -Arguments @(
            '-InstallPath'
            $InstallRoot
        )

    Write-TestResult `
        -Name 'Normal uninstall succeeds' `
        -Success ($UninstallResult.ExitCode -eq 0) `
        -Details (
            'Expected exit code 0, actual: ' +
            $UninstallResult.ExitCode
        )

    $RuntimeRemoved = (
        -not (
            Test-Path `
                -LiteralPath (Join-Path $InstallRoot 'src\ProfMig.ps1')
        )
    ) -and (
        -not (
            Test-Path `
                -LiteralPath (
                    Join-Path $InstallRoot 'ProfMig.Build.psd1'
                )
        )
    )

    Write-TestResult `
        -Name 'Normal uninstall removes ProfMig runtime' `
        -Success $RuntimeRemoved

    $PersistentDataPreserved = (
        Test-Path -LiteralPath $LogFile -PathType Leaf
    ) -and (
        Test-Path -LiteralPath $ReportFile -PathType Leaf
    ) -and (
        Test-Path -LiteralPath $BackupFile -PathType Leaf
    )

    Write-TestResult `
        -Name 'Normal uninstall preserves persistent data' `
        -Success $PersistentDataPreserved

    # -------------------------------------------------------------------------
    # Test 3 - Reinstall with preserved data
    # -------------------------------------------------------------------------

    $ReinstallResult = Invoke-TestPowerShell `
        -ScriptPath $DeployScript `
        -Arguments @(
            '-InstallPath'
            $InstallRoot
        )

    Write-TestResult `
        -Name 'Reinstall after preserved-data uninstall succeeds' `
        -Success ($ReinstallResult.ExitCode -eq 0) `
        -Details (
            'Expected exit code 0, actual: ' +
            $ReinstallResult.ExitCode
        )

    $RuntimeRestored = (
        Test-Path `
            -LiteralPath (Join-Path $InstallRoot 'src\ProfMig.ps1') `
            -PathType Leaf
    ) -and (
        Test-Path `
            -LiteralPath (Join-Path $InstallRoot 'ProfMig.Build.psd1') `
            -PathType Leaf
    )

    Write-TestResult `
        -Name 'Reinstall restores ProfMig runtime' `
        -Success $RuntimeRestored

    $PersistentDataStillPresent = (
        Test-Path -LiteralPath $LogFile -PathType Leaf
    ) -and (
        Test-Path -LiteralPath $ReportFile -PathType Leaf
    ) -and (
        Test-Path -LiteralPath $BackupFile -PathType Leaf
    )

    Write-TestResult `
        -Name 'Reinstall retains persistent data' `
        -Success $PersistentDataStillPresent

    # -------------------------------------------------------------------------
    # Test 4 - Complete uninstall
    # -------------------------------------------------------------------------

    $InstalledUninstallScript = Join-Path `
        $InstallRoot `
        'Uninstall-ProfMig.ps1'

    $CompleteUninstallResult = Invoke-TestPowerShell `
        -ScriptPath $InstalledUninstallScript `
        -Arguments @(
            '-InstallPath'
            $InstallRoot
            '-RemoveData'
        )

    Write-TestResult `
        -Name 'Complete uninstall succeeds' `
        -Success ($CompleteUninstallResult.ExitCode -eq 0) `
        -Details (
            'Expected exit code 0, actual: ' +
            $CompleteUninstallResult.ExitCode
        )

    Write-TestResult `
        -Name 'Complete uninstall removes installation directory' `
        -Success (
            -not (
                Test-Path `
                    -LiteralPath $InstallRoot
            )
        )

    # -------------------------------------------------------------------------
    # Test 5 - Safety protection
    # -------------------------------------------------------------------------

    $null = New-Item `
        -ItemType Directory `
        -Path $SafetyRoot `
        -Force

    $SafetyFile = Join-Path `
        $SafetyRoot `
        'DO-NOT-DELETE.txt'

    Set-Content `
        -LiteralPath $SafetyFile `
        -Value 'This file must survive.'

    $SafetyResult = Invoke-TestPowerShell `
        -ScriptPath $UninstallScript `
        -Arguments @(
            '-InstallPath'
            $SafetyRoot
        )

    Write-TestResult `
        -Name 'Uninstall rejects unrelated directory' `
        -Success ($SafetyResult.ExitCode -eq 3) `
        -Details (
            'Expected exit code 3, actual: ' +
            $SafetyResult.ExitCode
        )

    Write-TestResult `
        -Name 'Rejected directory remains untouched' `
        -Success (
            Test-Path `
                -LiteralPath $SafetyFile `
                -PathType Leaf
        )

    # -------------------------------------------------------------------------
    # Test 6 - Non-existent installation
    # -------------------------------------------------------------------------

    $MissingInstallPath = Join-Path `
        $TestRoot `
        'DoesNotExist'

    $MissingResult = Invoke-TestPowerShell `
        -ScriptPath $UninstallScript `
        -Arguments @(
            '-InstallPath'
            $MissingInstallPath
        )

    Write-TestResult `
        -Name 'Missing installation is idempotent' `
        -Success ($MissingResult.ExitCode -eq 0) `
        -Details (
            'Expected exit code 0, actual: ' +
            $MissingResult.ExitCode
        )

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host '=== Test Summary ==='
    Write-Host "Passed: $Passed"
    Write-Host "Failed: $Failed"

    if ($Failed -gt 0) {
        exit 1
    }

    Write-Host ''
    Write-Host 'PASS: ProfMig uninstall validation completed successfully.'

    exit 0
}
catch {

    Write-Error (
        'FAIL: ProfMig uninstall validation failed: ' +
        $_.Exception.Message
    )

    exit 1
}
finally {

    if (Test-Path -LiteralPath $TestRoot) {

        Remove-Item `
            -LiteralPath $TestRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}