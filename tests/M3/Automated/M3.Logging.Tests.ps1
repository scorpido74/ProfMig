# ============================================================================
# ProfMig - Milestone 3 Logging Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$LoggingModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Logging'

Remove-Module ProfMig.Logging -Force -ErrorAction SilentlyContinue
Import-Module $LoggingModule -Force

Describe 'M3 - Logging' {

    It 'M3-LOG-01 initializes a log folder and log file' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-LOG-01'

        try {

            $LogFolder = Join-Path `
                $TestRoot `
                'Logs'

            $LogFile = Initialize-Logging `
                -LogFolder $LogFolder

            (Test-Path -LiteralPath $LogFolder) |
                Should Be $true

            (Test-Path -LiteralPath $LogFile) |
                Should Be $true

            (Split-Path -Parent $LogFile) |
                Should Be $LogFolder

            (Split-Path -Leaf $LogFile) |
                Should Match '^ProfMig_\d{8}_\d{6}\.log$'

            (Get-LogFile) |
                Should Be $LogFile
        }
        finally {
            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-LOG-02 writes level and message to the active log file' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-LOG-02'

        try {

            $LogFolder = Join-Path `
                $TestRoot `
                'Logs'

            $LogFile = Initialize-Logging `
                -LogFolder $LogFolder

            Write-Log `
                -Level 'INFO' `
                -Message 'M3 logging regression message'

            $Content = Get-Content `
                -LiteralPath $LogFile `
                -Raw

            $Content |
                Should Match '\[INFO\] M3 logging regression message'

            $Content |
                Should Match '^\[\d{2}:\d{2}:\d{2}\]'
        }
        finally {
            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-LOG-03 redacts credential and bearer secrets' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-LOG-03'

        try {

            $LogFolder = Join-Path `
                $TestRoot `
                'Logs'

            $LogFile = Initialize-Logging `
                -LogFolder $LogFolder

            $PasswordSecret = 'ProfMigPasswordSecret123'
            $TokenSecret = 'ProfMigTokenSecret456'
            $BearerSecret = 'ProfMigBearerToken789'

            $Message = (
                'Password={0}; Token={1}; Authorization=Bearer {2}' -f
                    $PasswordSecret,
                    $TokenSecret,
                    $BearerSecret
            )

            Write-Log `
                -Level 'ERROR' `
                -Message $Message

            $Content = Get-Content `
                -LiteralPath $LogFile `
                -Raw

            $Content |
                Should Not Match ([regex]::Escape($PasswordSecret))

            $Content |
                Should Not Match ([regex]::Escape($TokenSecret))

            $Content |
                Should Not Match ([regex]::Escape($BearerSecret))

            $Content |
                Should Match 'Password=\[REDACTED\]'

            $Content |
                Should Match 'Token=\[REDACTED\]'

            $Content |
                Should Match 'Authorization=\[REDACTED\]'
        }
        finally {
            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-LOG-04 preserves Critical severity as CRITICAL log level' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-LOG-04'

        try {

            $LogFolder = Join-Path `
                $TestRoot `
                'Logs'

            $LogFile = Initialize-Logging `
                -LogFolder $LogFolder

            $ErrorObject = [PSCustomObject]@{
                Category       = 'VerificationError'
                Severity       = 'Critical'
                Component      = 'M3-LOG-04'
                Message        = 'Critical regression test'
                Reason         = 'IntegrityFailure'
                RecoveryAction = 'Stop'
            }

            Write-ProfMigError `
                -ErrorObject $ErrorObject

            $Content = Get-Content `
                -LiteralPath $LogFile `
                -Raw

            $Content |
                Should Match '\[CRITICAL\]'

            $Content |
                Should Match 'Severity=Critical'

            $Content |
                Should Match 'Critical regression test'
        }
        finally {
            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-LOG-05 preserves structured error metadata in the log' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-LOG-05'

        try {

            $LogFolder = Join-Path `
                $TestRoot `
                'Logs'

            $LogFile = Initialize-Logging `
                -LogFolder $LogFolder

            $ErrorObject = [PSCustomObject]@{
                Category       = 'SourceReadError'
                Severity       = 'Warning'
                Component      = 'CopyEngine'
                Message        = 'Structured logging regression test'
                Reason         = 'FileLocked'
                RecoveryAction = 'Retry'
            }

            Write-ProfMigError `
                -ErrorObject $ErrorObject

            $Content = Get-Content `
                -LiteralPath $LogFile `
                -Raw

            $Content |
                Should Match '\[WARNING\]'

            $Content |
                Should Match 'Category=SourceReadError'

            $Content |
                Should Match 'Severity=Warning'

            $Content |
                Should Match 'Component=CopyEngine'

            $Content |
                Should Match 'Reason=FileLocked'

            $Content |
                Should Match 'Recovery=Retry'

            $Content |
                Should Match 'Structured logging regression test'
        }
        finally {
            # Prevent logging state from leaking into later M3 test suites.
            # The Logging module keeps the active log file in module scope.
            Remove-Module ProfMig.Logging `
                -Force `
                -ErrorAction SilentlyContinue

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }
}
