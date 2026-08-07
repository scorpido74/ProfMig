<#
    ProfMig.Core.psm1

    Core framework for ProfMig.

    Responsible for:
        - Initialization
        - Environment checks
        - Banner
        - Shutdown

    Author : Remco de Kievit
    Project: ProfMig
#>

Set-StrictMode -Version Latest

function Initialize-ProfMig {

    [CmdletBinding()]
    param(

[Parameter(Mandatory)]

$Configuration
)

    $Script:ProfMig = [PSCustomObject]@{

        Name       = $Configuration.Application.Name
        Version    = $Configuration.Application.Version
        Build      = $Configuration.Application.Build

        StartTime  = Get-Date

        SourceUser = $null
        TargetUser = $null

        LogFile    = $null

    }

    return $Script:ProfMig
}

function Show-ProfMigBanner {

    [CmdletBinding()]
    param()

    Clear-Host

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   ____             __ __  __ _       "
    Write-Host "  |  _ \ _ __ ___  / _|  \/  (_) __ _ "
    Write-Host "  | |_) | '__/ _ \| |_| |\/| | |/ _`` |"
    Write-Host "  |  __/| | | (_) |  _| |  | | | (_| |"
    Write-Host "  |_|   |_|  \___/|_| |_|  |_|_|\__, |"
    Write-Host "                               |___/ "
    Write-Host ""
    Write-Host " Professional Windows Profile Migration Toolkit"
    Write-Host ""
    Write-Host " Version : $($Script:ProfMig.Version)"
    Write-Host " Build   : $($Script:ProfMig.Build)"
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Test-ProfMigEnvironment {

    [CmdletBinding()]
    param()

    if ($PSVersionTable.PSVersion.Major -lt 5) {

        throw "PowerShell 5.1 or newer is required."

    }

    if (-not ([Environment]::Is64BitOperatingSystem)) {

        throw "64-bit Windows is required."

    }

}

function Stop-ProfMig {

    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "ProfMig finished." -ForegroundColor Green
    Write-Host ""

}

Export-ModuleMember -Function *