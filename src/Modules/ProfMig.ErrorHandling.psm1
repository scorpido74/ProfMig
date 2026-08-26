<#
.SYNOPSIS
    Central error handling and recovery framework for ProfMig.

.DESCRIPTION
    Provides standardized ProfMig error objects, error categories,
    severity levels, recovery actions and process exit codes.

    The module is intentionally independent from the ProfMig logging
    and reporting modules so that it can also be used during early
    application startup.

.NOTES
    Project : ProfMig
    Module  : ProfMig.ErrorHandling
    Sprint  : 3.6 - Error Handling & Recovery
#>

Set-StrictMode -Version Latest


# ============================================================================
# Script constants
# ============================================================================

$script:ProfMigErrorType = 'ProfMig.Error'


# ============================================================================
# New-ProfMigError
# ============================================================================

function New-ProfMigError {
    <#
    .SYNOPSIS
        Creates a standardized ProfMig error object.

    .DESCRIPTION
        Creates a structured error object that can be consumed by migration
        components, logging, reporting and the application entry point.

        Exception objects themselves are not stored in the returned object.
        Only selected diagnostic information is retained to reduce the risk
        of exposing unnecessary or sensitive exception data.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet(
            'ConfigurationError',
            'ValidationError',
            'PermissionError',
            'SourceReadError',
            'DestinationWriteError',
            'FileLocked',
            'InsufficientStorage',
            'ApplicationMigrationError',
            'VerificationError',
            'UnexpectedError'
        )]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Information',
            'Warning',
            'Error',
            'Critical'
        )]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Component,

        [Parameter()]
        [ValidateSet(
            'Startup',
            'Configuration',
            'Validation',
            'Read',
            'Write',
            'Enumerate',
            'Copy',
            'ApplicationMigration',
            'Verification',
            'Reporting',
            'Shutdown',
            'Unknown'
        )]
        [string]$Operation = 'Unknown',

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [string]$Reason = $null,

        [Parameter()]
        [AllowNull()]
        [string]$SourcePath = $null,

        [Parameter()]
        [AllowNull()]
        [string]$DestinationPath = $null,

        [Parameter()]
        [AllowNull()]
        [System.Exception]$Exception = $null,

        [Parameter()]
        [bool]$Retryable = $false,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$RetryCount = 0,

        [Parameter()]
        [ValidateSet(
            'None',
            'Retry',
            'Skip',
            'Stop',
            'ReRun'
        )]
        [string]$RecoveryAction = 'None'
    )

    $exceptionType = $null
    $hResult = $null

    if ($null -ne $Exception) {

        $classificationException = $Exception

        while ($null -ne $classificationException.InnerException) {
            $classificationException = $classificationException.InnerException
        }

        $exceptionType = $classificationException.GetType().FullName
        $hResult = $classificationException.HResult
    }

    $critical = ($Severity -eq 'Critical')

    return [PSCustomObject]@{
        PSTypeName      = $script:ProfMigErrorType
        Timestamp       = Get-Date
        Category        = $Category
        Severity        = $Severity
        Component       = $Component
        Operation       = $Operation
        Message         = $Message
        Reason          = $Reason
        SourcePath      = $SourcePath
        DestinationPath = $DestinationPath
        ExceptionType   = $exceptionType
        HResult         = $hResult
        Retryable       = $Retryable
        RetryCount      = $RetryCount
        RecoveryAction  = $RecoveryAction
        Critical        = $critical
    }
}


# ============================================================================
# New-ProfMigException
# ============================================================================

function New-ProfMigException {
    <#
    .SYNOPSIS
        Creates an exception containing ProfMig error metadata.

    .DESCRIPTION
        Creates a standard System.Exception and stores ProfMig-specific
        classification information in the exception Data collection.

        This allows exceptions to travel through existing PowerShell
        try/catch boundaries without relying on message parsing.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Mandatory)]
        [ValidateSet(
            'ConfigurationError',
            'ValidationError',
            'PermissionError',
            'SourceReadError',
            'DestinationWriteError',
            'FileLocked',
            'InsufficientStorage',
            'ApplicationMigrationError',
            'VerificationError',
            'UnexpectedError'
        )]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateSet(
            'Information',
            'Warning',
            'Error',
            'Critical'
        )]
        [string]$Severity,

        [Parameter()]
        [ValidateSet(
            'None',
            'Retry',
            'Skip',
            'Stop',
            'ReRun'
        )]
        [string]$RecoveryAction = 'None',

        [Parameter()]
        [AllowNull()]
        [string]$Reason = $null,

        [Parameter()]
        [AllowNull()]
        [System.Exception]$InnerException = $null
    )

    if ($null -ne $InnerException) {
        $exception = [System.Exception]::new(
            $Message,
            $InnerException
        )
    }
    else {
        $exception = [System.Exception]::new($Message)
    }

    $exception.Data['ProfMigCategory'] = $Category
    $exception.Data['ProfMigSeverity'] = $Severity
    $exception.Data['ProfMigRecoveryAction'] = $RecoveryAction

    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $exception.Data['ProfMigReason'] = $Reason
    }

    return $exception
}

# ============================================================================
# Get-ProfMigExitCode
# ============================================================================

function Get-ProfMigExitCode {
    <#
    .SYNOPSIS
        Returns the documented ProfMig process exit code.

    .DESCRIPTION
        Converts a ProfMig result or error category into a stable process
        exit code suitable for scripts, deployment tools and automation.

    .NOTES
        Exit codes:

          0  Success
          1  SuccessWithWarnings
          2  MigrationFailed
          3  ConfigurationError
          4  ValidationError
          5  PermissionError
          6  InsufficientStorage
          7  VerificationError
          8  ApplicationMigrationError
         99  UnexpectedError
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet(
            'Success',
            'SuccessWithWarnings',
            'MigrationFailed',
            'ConfigurationError',
            'ValidationError',
            'PermissionError',
            'InsufficientStorage',
            'VerificationError',
            'ApplicationMigrationError',
            'UnexpectedError'
        )]
        [string]$Result
    )

    switch ($Result) {

        'Success' {
            return 0
        }

        'SuccessWithWarnings' {
            return 1
        }

        'MigrationFailed' {
            return 2
        }

        'ConfigurationError' {
            return 3
        }

        'ValidationError' {
            return 4
        }

        'PermissionError' {
            return 5
        }

        'InsufficientStorage' {
            return 6
        }

        'VerificationError' {
            return 7
        }

        'ApplicationMigrationError' {
            return 8
        }

        'UnexpectedError' {
            return 99
        }
    }
}


# ============================================================================
# Test-ProfMigErrorCritical
# ============================================================================

function Test-ProfMigErrorCritical {
    <#
    .SYNOPSIS
        Determines whether a ProfMig error requires migration termination.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ErrorObject
    )

    if (
        $ErrorObject.PSObject.Properties.Name -contains 'Severity' -and
        $ErrorObject.Severity -eq 'Critical'
    ) {
        return $true
    }

    if (
        $ErrorObject.PSObject.Properties.Name -contains 'Critical' -and
        $ErrorObject.Critical
    ) {
        return $true
    }

    if (
        $ErrorObject.PSObject.Properties.Name -contains 'RecoveryAction' -and
        $ErrorObject.RecoveryAction -eq 'Stop'
    ) {
        return $true
    }

    return $false
}


# ============================================================================
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'New-ProfMigError',
    'New-ProfMigException',
    'Get-ProfMigExitCode',
    'Test-ProfMigErrorCritical'
)