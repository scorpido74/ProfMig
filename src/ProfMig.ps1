<#
.SYNOPSIS
    ProfMig main application entry point.

.DESCRIPTION
    Initializes the ProfMig configuration, core framework and logging
    components before starting the application.

    This script acts as the central entry point for ProfMig.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Determine ProfMig paths.
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

    $null = Initialize-ProfMig -Configuration $Config


    # -------------------------------------------------------------------------
    # Initialize logging
    # -------------------------------------------------------------------------

    if ($Config.Paths -and $Config.Paths.Logs) {

        $LogFolder = Join-Path $ProjectRoot $Config.Paths.Logs

    }
    else {

        $LogFolder = Join-Path $ProjectRoot 'Logs'

    }

    Initialize-Logging -LogFolder $LogFolder | Out-Null


    # -------------------------------------------------------------------------
    # Validate environment
    # -------------------------------------------------------------------------

    Test-ProfMigEnvironment


    # -------------------------------------------------------------------------
    # Start ProfMig
    # -------------------------------------------------------------------------

    Show-ProfMigBanner

    Write-Success 'Core Framework loaded successfully.'
    Write-Info 'Logging initialized.'
    Write-Info 'ProfMig startup completed.'


    # -------------------------------------------------------------------------
    # ProfMig application
    # -------------------------------------------------------------------------

    # Menu integration will be started here.


    # -------------------------------------------------------------------------
    # Shutdown
    # -------------------------------------------------------------------------

    Stop-ProfMig
}
catch {

    Write-Host ''
    Write-Host 'ProfMig failed to start.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''

    exit 1
}