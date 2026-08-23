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

    Import-Module (Join-Path $ModuleRoot 'ProfMig.Configuration.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Core.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Logging.psm1') -Force
    Import-Module (Join-Path $ModuleRoot 'ProfMig.CopyEngine.psm1') -Force
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
        throw 'ProfMig configuration could not be loaded.'
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
            'Application definition folder was not found: ' +
            $ApplicationDefinitionFolder
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
            'One or more application definitions are invalid: ' +
            ($invalidFiles -join ', ')
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
        throw 'No Windows user profiles were found.'
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

    Write-Host ''
    Write-Host 'ProfMig failed to start.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''

    exit 1
}