<#
    Module      : ProfMig.Logging
    Description : Central logging framework for ProfMig.

    Author      : Remco de Kievit
    Repository  : https://github.com/scorpido74/ProfMig
#>

Set-StrictMode -Version Latest

$script:LogFile = $null

function Initialize-Logging {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFolder
    )

    if (-not (Test-Path $LogFolder)) {
        New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    }

    $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

    $script:LogFile = Join-Path $LogFolder "ProfMig_$TimeStamp.log"

    New-Item -ItemType File -Path $script:LogFile -Force | Out-Null

    return $script:LogFile
}

function Write-Log {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message
    )

    $Time = Get-Date -Format "HH:mm:ss"

    $Line = "[$Time] [$Level] $Message"

    switch ($Level) {

        "INFO"    { $Color = "White" }

        "SUCCESS" { $Color = "Green" }

        "WARNING" { $Color = "Yellow" }

        "ERROR"   { $Color = "Red" }

        default   { $Color = "Gray" }

    }

    Write-Host $Line -ForegroundColor $Color

    if ($script:LogFile) {

        Add-Content `
            -Path $script:LogFile `
            -Value $Line

    }

}

function Write-Info {

    param([string]$Message)

    Write-Log -Level "INFO" -Message $Message

}

function Write-Success {

    param([string]$Message)

    Write-Log -Level "SUCCESS" -Message $Message

}

function Write-WarningLog {

    param([string]$Message)

    Write-Log -Level "WARNING" -Message $Message

}

function Write-ErrorLog {

    param([string]$Message)

    Write-Log -Level "ERROR" -Message $Message

}

function Get-LogFile {

    return $script:LogFile

}

Export-ModuleMember -Function *