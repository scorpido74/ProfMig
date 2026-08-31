# ============================================================================
# ProfMig - Milestone 3 Recovery / Error Handling Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$ErrorHandlingModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.ErrorHandling'

Remove-Module ProfMig.ErrorHandling `
    -Force `
    -ErrorAction SilentlyContinue

Import-Module $ErrorHandlingModule -Force


Describe 'M3 - Recovery and Error Handling' {

    It 'M3-REC-01 creates a structured ProfMig error object' {

        $ErrorObject = New-ProfMigError `
            -Category 'SourceReadError' `
            -Severity 'Error' `
            -Component 'CopyEngine' `
            -Operation 'Read' `
            -Message 'Unable to read source file' `
            -Reason 'AccessDenied' `
            -SourcePath 'C:\Source\Test.txt' `
            -DestinationPath 'C:\Destination\Test.txt' `
            -RecoveryAction 'Skip'

        $ErrorObject.Category |
            Should Be 'SourceReadError'

        $ErrorObject.Severity |
            Should Be 'Error'

        $ErrorObject.Component |
            Should Be 'CopyEngine'

        $ErrorObject.Operation |
            Should Be 'Read'

        $ErrorObject.Message |
            Should Be 'Unable to read source file'

        $ErrorObject.Reason |
            Should Be 'AccessDenied'

        $ErrorObject.SourcePath |
            Should Be 'C:\Source\Test.txt'

        $ErrorObject.DestinationPath |
            Should Be 'C:\Destination\Test.txt'

        $ErrorObject.RecoveryAction |
            Should Be 'Skip'

        $ErrorObject.Critical |
            Should Be $false
    }


    It 'M3-REC-02 preserves retry metadata for retryable errors' {

        $ErrorObject = New-ProfMigError `
            -Category 'FileLocked' `
            -Severity 'Warning' `
            -Component 'CopyEngine' `
            -Operation 'Copy' `
            -Message 'Source file is locked' `
            -Reason 'FileLocked' `
            -Retryable $true `
            -RetryCount 3 `
            -RecoveryAction 'Retry'

        $ErrorObject.Category |
            Should Be 'FileLocked'

        $ErrorObject.Retryable |
            Should Be $true

        $ErrorObject.RetryCount |
            Should Be 3

        $ErrorObject.RecoveryAction |
            Should Be 'Retry'

        $ErrorObject.Critical |
            Should Be $false

        (Test-ProfMigErrorCritical `
            -ErrorObject $ErrorObject) |
            Should Be $false
    }


    It 'M3-REC-03 keeps Skip recovery non-critical' {

        $ErrorObject = New-ProfMigError `
            -Category 'SourceReadError' `
            -Severity 'Error' `
            -Component 'CopyEngine' `
            -Operation 'Copy' `
            -Message 'File cannot be copied' `
            -Reason 'AccessDenied' `
            -RecoveryAction 'Skip'

        $ErrorObject.RecoveryAction |
            Should Be 'Skip'

        $ErrorObject.Critical |
            Should Be $false

        (Test-ProfMigErrorCritical `
            -ErrorObject $ErrorObject) |
            Should Be $false
    }


    It 'M3-REC-04 detects Critical severity and Stop recovery as termination conditions' {

        $CriticalError = New-ProfMigError `
            -Category 'VerificationError' `
            -Severity 'Critical' `
            -Component 'Verification' `
            -Operation 'Verification' `
            -Message 'Migration integrity verification failed' `
            -Reason 'IntegrityFailure' `
            -RecoveryAction 'Stop'

        $CriticalError.Critical |
            Should Be $true

        (Test-ProfMigErrorCritical `
            -ErrorObject $CriticalError) |
            Should Be $true


        $StopError = New-ProfMigError `
            -Category 'ValidationError' `
            -Severity 'Error' `
            -Component 'Validation' `
            -Operation 'Validation' `
            -Message 'Migration cannot continue' `
            -Reason 'InvalidSourcePath' `
            -RecoveryAction 'Stop'

        $StopError.Critical |
            Should Be $false

        $StopError.Severity |
            Should Be 'Error'

        (Test-ProfMigErrorCritical `
            -ErrorObject $StopError) |
            Should Be $true
    }


    It 'M3-REC-05 preserves exception metadata and documented exit codes' {

        $InnerException = New-Object `
            System.InvalidOperationException `
            'Underlying regression test exception'

        $Exception = New-ProfMigException `
            -Message 'ProfMig validation failed' `
            -Category 'ValidationError' `
            -Severity 'Critical' `
            -RecoveryAction 'Stop' `
            -Reason 'InvalidSourcePath' `
            -InnerException $InnerException

        $Exception.Message |
            Should Be 'ProfMig validation failed'

        $Exception.InnerException.Message |
            Should Be 'Underlying regression test exception'

        $Exception.Data['ProfMigCategory'] |
            Should Be 'ValidationError'

        $Exception.Data['ProfMigSeverity'] |
            Should Be 'Critical'

        $Exception.Data['ProfMigRecoveryAction'] |
            Should Be 'Stop'

        $Exception.Data['ProfMigReason'] |
            Should Be 'InvalidSourcePath'


        (Get-ProfMigExitCode -Result 'Success') |
            Should Be 0

        (Get-ProfMigExitCode -Result 'SuccessWithWarnings') |
            Should Be 1

        (Get-ProfMigExitCode -Result 'MigrationFailed') |
            Should Be 2

        (Get-ProfMigExitCode -Result 'ConfigurationError') |
            Should Be 3

        (Get-ProfMigExitCode -Result 'ValidationError') |
            Should Be 4

        (Get-ProfMigExitCode -Result 'PermissionError') |
            Should Be 5

        (Get-ProfMigExitCode -Result 'InsufficientStorage') |
            Should Be 6

        (Get-ProfMigExitCode -Result 'VerificationError') |
            Should Be 7

        (Get-ProfMigExitCode -Result 'ApplicationMigrationError') |
            Should Be 8

        (Get-ProfMigExitCode -Result 'UnexpectedError') |
            Should Be 99
    }
}
