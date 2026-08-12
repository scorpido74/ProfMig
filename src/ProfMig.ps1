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
    Import-Module (Join-Path $ModuleRoot 'ProfMig.Menu.psm1') -Force


    # -------------------------------------------------------------------------
    # Load configuration
    # -------------------------------------------------------------------------

    $Config = Import-ProfMigConfiguration -Path $ConfigPath

    if ($null -eq $Config) {
        throw 'ProfMig configuration could not be loaded.'
    }


    # -------------------------------------------------------------------------
    # Initialize core framework
    # -------------------------------------------------------------------------

    $null = Initialize-ProfMig `
        -Configuration $Config

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
    -ReportFolder $ReportFolder

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