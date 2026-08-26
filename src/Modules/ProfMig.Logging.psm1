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

function Write-ProfMigError {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ErrorObject
    )

    $category = 'UnexpectedError'
    $severity = 'Error'
    $component = 'ProfMig'
    $message = 'An unspecified ProfMig error occurred.'
    $reason = $null
    $recoveryAction = $null

    if (
        $null -ne $ErrorObject.PSObject.Properties['Category'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Category)
    ) {
        $category = [string]$ErrorObject.Category
    }

    if (
        $null -ne $ErrorObject.PSObject.Properties['Severity'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Severity)
    ) {
        $severity = [string]$ErrorObject.Severity
    }

    if (
        $null -ne $ErrorObject.PSObject.Properties['Component'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Component)
    ) {
        $component = [string]$ErrorObject.Component
    }

    if (
        $null -ne $ErrorObject.PSObject.Properties['Message'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Message)
    ) {
        $message = [string]$ErrorObject.Message
    }
    elseif (
        $null -ne $ErrorObject.PSObject.Properties['Error'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Error)
    ) {
        $message = [string]$ErrorObject.Error
    }

    if (
        $null -ne $ErrorObject.PSObject.Properties['Reason'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.Reason)
    ) {
        $reason = [string]$ErrorObject.Reason
    }

    if (
        $null -ne $ErrorObject.PSObject.Properties['RecoveryAction'] -and
        -not [string]::IsNullOrWhiteSpace([string]$ErrorObject.RecoveryAction)
    ) {
        $recoveryAction = [string]$ErrorObject.RecoveryAction
    }

    $level = switch ($severity) {

        'Information' { 'INFO' }
        'Warning'     { 'WARNING' }
        'Error'       { 'ERROR' }
        'Critical'    { 'ERROR' }

        default       { 'ERROR' }
    }

    $details = @(
        "Category=$category"
        "Severity=$severity"
        "Component=$component"
    )

    if (-not [string]::IsNullOrWhiteSpace($reason)) {
        $details += "Reason=$reason"
    }

    if (-not [string]::IsNullOrWhiteSpace($recoveryAction)) {
        $details += "Recovery=$recoveryAction"
    }

    $logMessage = '[{0}] {1}' -f `
    ($details -join ' | '),
    $message

    Write-Log `
        -Level $level `
        -Message $logMessage
}

function Get-LogFile {

    return $script:LogFile

}

Export-ModuleMember -Function *