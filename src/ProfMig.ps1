<#
.SYNOPSIS
    ProfMig main application entry point.

.DESCRIPTION
    Initializes the ProfMig configuration, core framework, logging,
    inventory engine and migration workflow.

    ProfMig supports both interactive and unattended command-line execution.

.EXAMPLE
    .\ProfMig.ps1

    Starts ProfMig in interactive mode.

.EXAMPLE
    .\ProfMig.ps1 `
        -Silent `
        -SourceSid 'S-1-12-1-...' `
        -DestinationSid 'S-1-12-1-...'

    Starts an unattended migration using Windows profile SIDs.

.EXAMPLE
    .\ProfMig.ps1 `
        -Silent `
        -SourceProfilePath 'C:\Users\OldUser' `
        -DestinationProfilePath 'C:\Users\NewUser'

    Starts an unattended migration using Windows profile paths.

.EXAMPLE
    .\ProfMig.ps1 `
        -Silent `
        -SourceSid 'S-1-12-1-...' `
        -DestinationSid 'S-1-12-1-...' `
        -SkipApplications

    Starts an unattended migration without application migration.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [switch]$Silent,

    [Parameter()]
    [string]$SourceSid,

    [Parameter()]
    [string]$DestinationSid,

    [Parameter()]
    [string]$SourceProfilePath,

    [Parameter()]
    [string]$DestinationProfilePath,

    [Parameter()]
    [switch]$SkipApplications,

    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [string]$LogPath,

    [Parameter()]
    [string]$ReportPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# -----------------------------------------------------------------------------
# Determine ProfMig paths
# -----------------------------------------------------------------------------

$SourceRoot  = Split-Path -Parent $PSCommandPath
$ProjectRoot = Split-Path -Parent $SourceRoot
$ModuleRoot  = Join-Path $SourceRoot 'Modules'

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $SourceRoot 'Config.psd1'
}
else {
    $ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
}


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
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Migration.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Menu.psm1') -Force


    # -------------------------------------------------------------------------
    # Validate command-line mode
    # -------------------------------------------------------------------------

    if ($Silent) {

        $usingSid = (
            -not [string]::IsNullOrWhiteSpace($SourceSid) -or
            -not [string]::IsNullOrWhiteSpace($DestinationSid)
        )

        $usingPath = (
            -not [string]::IsNullOrWhiteSpace($SourceProfilePath) -or
            -not [string]::IsNullOrWhiteSpace($DestinationProfilePath)
        )

        if ($usingSid -and $usingPath) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Silent mode cannot combine SID and profile-path ' +
                        'identifiers.'
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'MixedProfileIdentifiers'
            )
        }

        if ($usingSid) {

            if (
                [string]::IsNullOrWhiteSpace($SourceSid) -or
                [string]::IsNullOrWhiteSpace($DestinationSid)
            ) {

                throw (
                    New-ProfMigException `
                        -Message (
                            'Silent SID mode requires both SourceSid and ' +
                            'DestinationSid.'
                        ) `
                        -Category 'ConfigurationError' `
                        -Severity 'Critical' `
                        -RecoveryAction 'Stop' `
                        -Reason 'IncompleteSidParameters'
                )
            }
        }
        elseif ($usingPath) {

            if (
                [string]::IsNullOrWhiteSpace($SourceProfilePath) -or
                [string]::IsNullOrWhiteSpace($DestinationProfilePath)
            ) {

                throw (
                    New-ProfMigException `
                        -Message (
                            'Silent profile-path mode requires both ' +
                            'SourceProfilePath and DestinationProfilePath.'
                        ) `
                        -Category 'ConfigurationError' `
                        -Severity 'Critical' `
                        -RecoveryAction 'Stop' `
                        -Reason 'IncompleteProfilePathParameters'
                )
            }
        }
        else {

            throw (
                New-ProfMigException `
                    -Message (
                        'Silent mode requires source and destination ' +
                        'identifiers.'
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'MissingProfileIdentifiers'
            )
        }
    }


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

    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {

        $ReportFolder = [System.IO.Path]::GetFullPath($ReportPath)
    }
    elseif ($Config.Paths -and $Config.Paths.Reports) {

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
    # Resolve log folder
    # -------------------------------------------------------------------------

    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {

        $LogFolder = [System.IO.Path]::GetFullPath($LogPath)
    }
    elseif ($Config.Paths -and $Config.Paths.Logs) {

        $LogFolder = Join-Path `
            $ProjectRoot `
            $Config.Paths.Logs
    }
    else {

        $LogFolder = Join-Path `
            $ProjectRoot `
            'Logs'
    }


    # -------------------------------------------------------------------------
    # Initialize logging
    # -------------------------------------------------------------------------

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

    Write-Info (
        "Profile inventory completed. " +
        "$($Profiles.Count) profile(s) found."
    )

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


    # =========================================================================
    # Interactive mode
    # =========================================================================

    if (-not $Silent) {

        Write-Info 'Starting interactive menu.'

        $null = Start-ProfMigMenu `
            -Configuration $Config `
            -Profiles $Profiles `
            -ReportFolder $ReportFolder `
            -ApplicationDefinitions $ApplicationDefinitions

        Write-Info 'ProfMig session completed.'

        Stop-ProfMig
    }


    # =========================================================================
    # Silent mode
    # =========================================================================

    else {

        Write-Info 'Starting silent migration.'


        # ---------------------------------------------------------------------
        # Resolve source and destination profiles
        # ---------------------------------------------------------------------

        if (-not [string]::IsNullOrWhiteSpace($SourceSid)) {

            $SourceProfile = Resolve-ProfMigProfile `
                -Profiles $Profiles `
                -Sid $SourceSid

            $DestinationProfile = Resolve-ProfMigProfile `
                -Profiles $Profiles `
                -Sid $DestinationSid
        }
        else {

            $SourceProfile = Resolve-ProfMigProfile `
                -Profiles $Profiles `
                -ProfilePath $SourceProfilePath

            $DestinationProfile = Resolve-ProfMigProfile `
                -Profiles $Profiles `
                -ProfilePath $DestinationProfilePath
        }

        $null = Test-ProfMigMigrationProfiles `
            -SourceProfile $SourceProfile `
            -DestinationProfile $DestinationProfile

        Write-Info (
            'Silent source profile resolved: ' +
            $SourceProfile.ProfilePath
        )

        Write-Info (
            'Silent destination profile resolved: ' +
            $DestinationProfile.ProfilePath
        )


        # ---------------------------------------------------------------------
        # Detect applications
        # ---------------------------------------------------------------------

        $SelectedApplications = @()

        if (-not $SkipApplications) {

            Write-Info 'Starting silent application detection.'

            $ApplicationInventory = @(
                Get-ProfMigApplicationInventory `
                    -SourceProfilePath $SourceProfile.ProfilePath `
                    -ApplicationDefinitions $ApplicationDefinitions
            )

            $SelectedApplications = @(
                $ApplicationInventory |
                    Where-Object {
                        $_.Detected -eq $true -and
                        $_.Id -notlike 'ProfMig.Test*'
                    }
            )

            Write-Info (
                'Silent application detection selected ' +
                "$($SelectedApplications.Count) application(s)."
            )

            foreach ($application in $SelectedApplications) {

                Write-Info (
                    'Selected application: ' +
                    "$($application.Name) [$($application.Id)]"
                )
            }
        }
        else {

            Write-Info (
                'Application migration skipped by command-line option.'
            )
        }


        # ---------------------------------------------------------------------
        # Execute migration
        # ---------------------------------------------------------------------

        $Migration = Invoke-ProfMigMigration `
            -Configuration $Config `
            -SourceProfile $SourceProfile `
            -DestinationProfile $DestinationProfile `
            -ReportFolder $ReportFolder `
            -SelectedApplications $SelectedApplications


        # ---------------------------------------------------------------------
        # Silent migration result
        # ---------------------------------------------------------------------

        Write-Info (
            'Silent migration completed with status: ' +
            $Migration.Status
        )

        if (
            -not [string]::IsNullOrWhiteSpace(
                [string]$Migration.ReportPath
            )
        ) {

            Write-Info (
                'Migration report: ' +
                $Migration.ReportPath
            )
        }


        # ---------------------------------------------------------------------
        # Determine successful process exit code
        # ---------------------------------------------------------------------

        $resultName = 'Success'

        if ($Migration.Status -match 'Warning') {
            $resultName = 'SuccessWithWarnings'
        }
        elseif (
            $Migration.Status -match 'Fail|Error'
        ) {
            $resultName = 'MigrationFailed'
        }

        $exitCode = Get-ProfMigExitCode `
            -Result $resultName

        Write-Info (
            "ProfMig silent-mode exit code: $exitCode"
        )

        Stop-ProfMig

        exit $exitCode
    }
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
        $recoveryAction = [string]$caughtException.Data[
            'ProfMigRecoveryAction'
        ]
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
                $exitCode = Get-ProfMigExitCode `
                    -Result 'ConfigurationError'
            }

            'ValidationError' {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'ValidationError'
            }

            'PermissionError' {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'PermissionError'
            }

            'InsufficientStorage' {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'InsufficientStorage'
            }

            'VerificationError' {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'VerificationError'
            }

            'ApplicationMigrationError' {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'ApplicationMigrationError'
            }

            default {
                $exitCode = Get-ProfMigExitCode `
                    -Result 'UnexpectedError'
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
    Write-Host (
        'ProfMig encountered a critical error.'
    ) -ForegroundColor Red

    if ($null -ne $profMigError) {

        Write-Host (
            'Category : {0}' -f $profMigError.Category
        ) -ForegroundColor Red

        Write-Host (
            'Message  : {0}' -f $profMigError.Message
        ) -ForegroundColor Red
    }
    else {

        Write-Host $caughtException.Message `
            -ForegroundColor Red
    }

    Write-Host ''

    exit $exitCode
}