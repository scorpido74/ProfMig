<#
.SYNOPSIS
    ProfMig main application entry point.

.DESCRIPTION
    Initializes the ProfMig configuration, core framework, logging,
    inventory engine and interactive menu.

    This script acts as the central entry point for ProfMig.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# -----------------------------------------------------------------------------
# Determine ProfMig paths
# -----------------------------------------------------------------------------

$SourceRoot  = Split-Path -Parent $PSCommandPath
$ProjectRoot = Split-Path -Parent $SourceRoot
$ModuleRoot  = Join-Path $SourceRoot 'Modules'
$ConfigPath  = Join-Path $SourceRoot 'Config.psd1'


try {

    # -------------------------------------------------------------------------
    # Load required ProfMig modules
    # -------------------------------------------------------------------------

    Import-Module (Join-Path $ModuleRoot 'ProfMig.ErrorHandling.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Configuration.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Core.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Logging.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.CopyEngine.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Verification.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Reporting.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Inventory.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Applications.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.AppMigration.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Browser.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Edge.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Chrome.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Outlook.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Validation.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Menu.psm1') -Force

    # -------------------------------------------------------------------------
    # Load configuration
    # -------------------------------------------------------------------------

    $Config = Import-ProfMigConfiguration -Path $ConfigPath

    if ($null -eq $Config) {

        throw (
            New-ProfMigException `
                -Message 'ProfMig configuration could not be loaded.' `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'ConfigurationUnavailable'
        )
    }

        # -------------------------------------------------------------------------
    # Resolve application definition folder
    # -------------------------------------------------------------------------

    if (
        $Config.Paths -and
        $Config.Paths.ApplicationDefinitions
    ) {
        $ApplicationDefinitionFolder = Join-Path `
            $SourceRoot `
            $Config.Paths.ApplicationDefinitions
    }
    else {
        $ApplicationDefinitionFolder = Join-Path `
            $SourceRoot `
            'Applications'
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $ApplicationDefinitionFolder `
                -PathType Container
        )
    ) {
        throw (
            New-ProfMigException `
                -Message (
                    'Application definition folder was not found: ' +
                    $ApplicationDefinitionFolder
                ) `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'ApplicationDefinitionFolderNotFound'
        )
    }


    # -------------------------------------------------------------------------
    # Initialize core framework
    # -------------------------------------------------------------------------

    $null = Initialize-ProfMig `
        -Configuration $Config

    # -------------------------------------------------------------------------
    # Load generic application definitions
    # -------------------------------------------------------------------------

    $ApplicationDefinitions = @(
        Get-ProfMigApplicationDefinitions `
            -Path $ApplicationDefinitionFolder
    )

    $InvalidApplicationDefinitions = @(
        $ApplicationDefinitions |
            Where-Object {
                -not $_.Valid
            }
    )

    if ($InvalidApplicationDefinitions.Count -gt 0) {

        $invalidFiles = @(
            $InvalidApplicationDefinitions |
                ForEach-Object {
                    $_.File
                }
        )

        throw (
            New-ProfMigException `
                -Message (
                    'One or more application definitions are invalid: ' +
                    ($invalidFiles -join ', ')
                ) `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'InvalidApplicationDefinitions'
        )
    }

    # -------------------------------------------------------------------------
    # Resolve report folder
    # -------------------------------------------------------------------------

    if ($Config.Paths -and $Config.Paths.Reports) {

        $ReportFolder = Join-Path `
            $ProjectRoot `
            $Config.Paths.Reports
    }
    else {

        $ReportFolder = Join-Path `
            $ProjectRoot `
            'Reports'
    }


        # -------------------------------------------------------------------------
    # Initialize logging
        # -------------------------------------------------------------------------

        if ($Config.Paths -and $Config.Paths.Logs) {

            $LogFolder = Join-Path `
                $ProjectRoot `
                $Config.Paths.Logs

        }
        else {

            $LogFolder = Join-Path `
                $ProjectRoot `
                'Logs'
        }

        Initialize-Logging `
            -LogFolder $LogFolder |
            Out-Null


        # -------------------------------------------------------------------------
    # Validate environment
        # -------------------------------------------------------------------------

        Test-ProfMigEnvironment

        # -------------------------------------------------------------------------
    # Display startup information
        # -------------------------------------------------------------------------

        Show-ProfMigBanner

        Write-Success 'Core Framework loaded successfully.'
        Write-Info 'Logging initialized.'
        Write-Info 'ProfMig startup completed.'

        Write-Info (
            'Generic application framework loaded. ' +
            "$($ApplicationDefinitions.Count) definition(s) available."
        )

    # -------------------------------------------------------------------------
    # Build Windows profile inventory
    # -------------------------------------------------------------------------

    Write-Info 'Starting profile inventory.'

    $Profiles = @(
        Get-UserProfiles `
            -ExcludedProfiles $Config.ExcludedProfiles
    )

    Write-Info "Profile inventory completed. $($Profiles.Count) profile(s) found."


    if ($Profiles.Count -eq 0) {
        throw (
            New-ProfMigException `
                -Message 'No Windows user profiles were found.' `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'NoUserProfilesFound'
        )
    }


    # -------------------------------------------------------------------------
    # Start interactive ProfMig menu
    # -------------------------------------------------------------------------

    Write-Info 'Starting interactive menu.'

    $null = Start-ProfMigMenu `
        -Configuration $Config `
        -Profiles $Profiles `
        -ReportFolder $ReportFolder `
        -ApplicationDefinitions $ApplicationDefinitions

    # -------------------------------------------------------------------------
    # Shutdown
    # -------------------------------------------------------------------------

    Write-Info 'ProfMig session completed.'

    Stop-ProfMig

}

catch {

    # -------------------------------------------------------------------------
    # Handle unhandled application error
    # -------------------------------------------------------------------------

    $caughtException = $_.Exception
    $profMigError = $null
    $exitCode = 99

    # Default classification for exceptions without ProfMig metadata.
    $category = 'UnexpectedError'
    $severity = 'Critical'
    $recoveryAction = 'Stop'
    $reason = 'UnhandledException'

    # -------------------------------------------------------------------------
    # Read ProfMig metadata when available
    # -------------------------------------------------------------------------

    if (
        $null -ne $caughtException.Data -and
        $caughtException.Data.Contains('ProfMigCategory')
    ) {
        $category = [string]$caughtException.Data['ProfMigCategory']
    }

    if (
        $null -ne $caughtException.Data -and
        $caughtException.Data.Contains('ProfMigSeverity')
    ) {
        $severity = [string]$caughtException.Data['ProfMigSeverity']
    }

    if (
        $null -ne $caughtException.Data -and
        $caughtException.Data.Contains('ProfMigRecoveryAction')
    ) {
        $recoveryAction = [string]$caughtException.Data['ProfMigRecoveryAction']
    }

    if (
        $null -ne $caughtException.Data -and
        $caughtException.Data.Contains('ProfMigReason')
    ) {
        $reason = [string]$caughtException.Data['ProfMigReason']
    }

    # -------------------------------------------------------------------------
    # Build standardized ProfMig error
    # -------------------------------------------------------------------------

    if (Get-Command New-ProfMigError -ErrorAction SilentlyContinue) {

        $profMigError = New-ProfMigError `
            -Category $category `
            -Severity $severity `
            -Component 'ProfMig' `
            -Operation 'Unknown' `
            -Message $caughtException.Message `
            -Reason $reason `
            -Exception $caughtException `
            -RecoveryAction $recoveryAction

        # ---------------------------------------------------------------------
        # Determine process exit code
        # ---------------------------------------------------------------------

        switch ($category) {

            'ConfigurationError' {
                $exitCode = Get-ProfMigExitCode -Result 'ConfigurationError'
            }

            'ValidationError' {
                $exitCode = Get-ProfMigExitCode -Result 'ValidationError'
            }

            'PermissionError' {
                $exitCode = Get-ProfMigExitCode -Result 'PermissionError'
            }

            'InsufficientStorage' {
                $exitCode = Get-ProfMigExitCode -Result 'InsufficientStorage'
            }

            'VerificationError' {
                $exitCode = Get-ProfMigExitCode -Result 'VerificationError'
            }

            'ApplicationMigrationError' {
                $exitCode = Get-ProfMigExitCode -Result 'ApplicationMigrationError'
            }

            default {
                $exitCode = Get-ProfMigExitCode -Result 'UnexpectedError'
            }
        }
    }

    # -------------------------------------------------------------------------
    # Log standardized ProfMig error when logging is available
    #
    # Logging is best-effort here. Startup may have failed before the logging
    # subsystem was initialized, and a logging failure must never replace the
    # original application error.
    # -------------------------------------------------------------------------

    if (
        $null -ne $profMigError -and
        (Get-Command Write-ProfMigError -ErrorAction SilentlyContinue)
    ) {
        try {
            Write-ProfMigError `
                -ErrorObject $profMigError
        }
        catch {
            Write-Host (
                'Warning: the error could not be written to the ProfMig log.'
            ) -ForegroundColor Yellow
        }
    }

    # -------------------------------------------------------------------------
    # Console fallback
    #
    # Error handling must remain usable even when startup failed before
    # logging or other ProfMig infrastructure became available.
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'ProfMig encountered a critical error.' -ForegroundColor Red

    if ($null -ne $profMigError) {

        Write-Host (
            'Category : {0}' -f $profMigError.Category
        ) -ForegroundColor Red

        Write-Host (
            'Message  : {0}' -f $profMigError.Message
        ) -ForegroundColor Red
    }
    else {
        Write-Host $caughtException.Message -ForegroundColor Red
    }

    Write-Host ''

    exit $exitCode
}