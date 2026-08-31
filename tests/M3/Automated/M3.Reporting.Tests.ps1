# ============================================================================
# ProfMig - Milestone 3 Reporting Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$LoggingModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Logging'

$ReportingModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Reporting'

Remove-Module ProfMig.Reporting -Force -ErrorAction SilentlyContinue
Remove-Module ProfMig.Logging -Force -ErrorAction SilentlyContinue

Import-Module $LoggingModule -Force
Import-Module $ReportingModule -Force


function New-M3ReportingCopyResult {

    param(
        [string]$Status = 'Success',

        [int64]$FilesSelected = 1,
        [int64]$FilesCopied = 1,
        [int64]$FilesSkipped = 0,
        [int64]$FilesExcluded = 0,
        [int64]$FilesFailed = 0,
        [int64]$BytesCopied = 21,

        [int64]$FilesVerified = 1,
        [int64]$BytesVerified = 21,
        [int64]$VerificationFailures = 0,

        [string]$VerificationLevel = 'Standard',
        [string]$HashAlgorithm = 'SHA256',

        [object[]]$Errors = @(),
        [object[]]$VerificationResults = @()
    )

    $StartedAt = Get-Date

    $Component = [PSCustomObject]@{
        Component            = 'Documents'
        FilesSelected        = $FilesSelected
        FilesCopied          = $FilesCopied
        FilesSkipped         = $FilesSkipped
        FilesExcluded        = $FilesExcluded
        FilesFailed          = $FilesFailed
        BytesCopied          = $BytesCopied
        FilesVerified        = $FilesVerified
        BytesVerified        = $BytesVerified
        VerificationFailures = $VerificationFailures
        VerificationStatus   = if ($VerificationFailures -gt 0) {
            'Failed'
        }
        else {
            'Verified'
        }
        VerificationResults  = @($VerificationResults)
    }

    return [PSCustomObject]@{
        SourceProfile      = 'C:\Users\M3Source'
        DestinationProfile = 'C:\Users\M3Destination'

        StartedAt          = $StartedAt
        CompletedAt        = $StartedAt.AddSeconds(2)

        Status             = $Status

        VerificationLevel  = $VerificationLevel
        HashAlgorithm      = $HashAlgorithm

        Components         = @($Component)

        Totals = [PSCustomObject]@{
            FilesSelected        = $FilesSelected
            FilesCopied          = $FilesCopied
            FilesSkipped         = $FilesSkipped
            FilesExcluded        = $FilesExcluded
            FilesFailed          = $FilesFailed
            BytesCopied          = $BytesCopied
            FilesVerified        = $FilesVerified
            BytesVerified        = $BytesVerified
            VerificationFailures = $VerificationFailures
            VerificationLevel    = $VerificationLevel
            HashAlgorithm        = $HashAlgorithm
        }

        SkippedItems  = @()
        ExcludedItems = @()
        Errors        = @($Errors)
    }
}


Describe 'M3 - Reporting' {

    It 'M3-RPT-01 creates a successful migration result and report' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-RPT-01'

        try {

            $ReportFolder = Join-Path `
                $TestRoot `
                'Reports'

            $CopyResult = New-M3ReportingCopyResult

            $MigrationResult = ConvertTo-ProfMigMigrationResult `
                -CopyResult $CopyResult `
                -ProfMigVersion 'M3-Test'

            $MigrationResult.Status |
                Should Be 'Success'

            $MigrationResult.FilesSelected |
                Should Be 1

            $MigrationResult.FilesCopied |
                Should Be 1

            $MigrationResult.FilesFailed |
                Should Be 0

            $MigrationResult.FilesVerified |
                Should Be 1

            $ReportFile = New-ProfMigMigrationReport `
                -MigrationResult $MigrationResult `
                -ReportFolder $ReportFolder

            (Test-Path -LiteralPath $ReportFile) |
                Should Be $true

            $Report = Get-Content `
                -LiteralPath $ReportFile `
                -Raw

            $Report |
                Should Match 'ProfMig version : M3-Test'

            $Report |
                Should Match 'Files copied\s+:\s+1'

            $Report |
                Should Match 'Overall result[\s\S]*Success'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-RPT-02 preserves partial failure information' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-RPT-02'

        try {

            $ReportFolder = Join-Path `
                $TestRoot `
                'Reports'

            $Failure = [PSCustomObject]@{
                Component       = 'Documents'
                Category        = 'SourceReadError'
                Error           = 'Unable to read Locked.txt'
                SourceFile      = 'C:\Users\M3Source\Locked.txt'
                DestinationFile = 'C:\Users\M3Destination\Locked.txt'
                Reason          = 'FileLocked'
                RecoveryAction  = 'Skip'
            }

            $CopyResult = New-M3ReportingCopyResult `
                -Status 'CompletedWithErrors' `
                -FilesSelected 2 `
                -FilesCopied 1 `
                -FilesFailed 1 `
                -FilesVerified 1 `
                -VerificationFailures 0 `
                -Errors @($Failure)

            $MigrationResult = ConvertTo-ProfMigMigrationResult `
                -CopyResult $CopyResult `
                -ProfMigVersion 'M3-Test'

            $MigrationResult.Status |
                Should Be 'Failed'

            $MigrationResult.FilesSelected |
                Should Be 2

            $MigrationResult.FilesCopied |
                Should Be 1

            $MigrationResult.FilesFailed |
                Should Be 1

            $MigrationResult.FailedItems.Count |
                Should Be 1

            $MigrationResult.Errors.Count |
                Should BeGreaterThan 0

            $ReportFile = New-ProfMigMigrationReport `
                -MigrationResult $MigrationResult `
                -ReportFolder $ReportFolder

            $Report = Get-Content `
                -LiteralPath $ReportFile `
                -Raw

            $Report |
                Should Match 'Locked\.txt'

            $Report |
                Should Match 'FileLocked'

            $Report |
                Should Match 'Overall result[\s\S]*Failed'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-RPT-03 preserves structured error information' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-RPT-03'

        try {

            $ReportFolder = Join-Path `
                $TestRoot `
                'Reports'

            $StructuredError = [PSCustomObject]@{
                Component      = 'Validation'
                Category       = 'ValidationError'
                Severity       = 'Critical'
                Error          = 'Source profile validation failed'
                Reason         = 'InvalidSourcePath'
                RecoveryAction = 'Stop'
            }

            $CopyResult = New-M3ReportingCopyResult `
                -Status 'CompletedWithErrors' `
                -FilesSelected 0 `
                -FilesCopied 0 `
                -FilesFailed 0 `
                -FilesVerified 0 `
                -BytesVerified 0 `
                -Errors @($StructuredError)

            $MigrationResult = ConvertTo-ProfMigMigrationResult `
                -CopyResult $CopyResult `
                -ProfMigVersion 'M3-Test'

            $MigrationResult.Status |
                Should Be 'Failed'

            $MigrationResult.StructuredErrors.Count |
                Should Be 1

            $MigrationResult.StructuredErrors[0].Category |
                Should Be 'ValidationError'

            $MigrationResult.StructuredErrors[0].Component |
                Should Be 'Validation'

            $MigrationResult.StructuredErrors[0].Reason |
                Should Be 'InvalidSourcePath'

            $MigrationResult.StructuredErrors[0].RecoveryAction |
                Should Be 'Stop'

            $ReportFile = New-ProfMigMigrationReport `
                -MigrationResult $MigrationResult `
                -ReportFolder $ReportFolder

            $Report = Get-Content `
                -LiteralPath $ReportFile `
                -Raw

            $Report |
                Should Match 'ValidationError'

            $Report |
                Should Match 'Source profile validation failed'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-RPT-04 preserves verification metadata and failure details' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-RPT-04'

        try {

            $ReportFolder = Join-Path `
                $TestRoot `
                'Reports'

            $VerificationFailure = [PSCustomObject]@{
                SourceFile      = 'C:\Users\M3Source\HashTest.txt'
                DestinationFile = 'C:\Users\M3Destination\HashTest.txt'
                Verified        = $false
                Status          = 'Failed'
                Reason          = 'HashMismatch'
                SourceSize      = 128
                DestinationSize = 128
                SourceHash      = 'AAAAAAAA'
                DestinationHash = 'BBBBBBBB'
                HashAlgorithm   = 'SHA256'
            }

            $CopyResult = New-M3ReportingCopyResult `
                -Status 'CompletedWithErrors' `
                -FilesSelected 1 `
                -FilesCopied 1 `
                -FilesFailed 0 `
                -BytesCopied 128 `
                -FilesVerified 0 `
                -BytesVerified 0 `
                -VerificationFailures 1 `
                -VerificationLevel 'Hash' `
                -HashAlgorithm 'SHA256' `
                -VerificationResults @($VerificationFailure)

            $MigrationResult = ConvertTo-ProfMigMigrationResult `
                -CopyResult $CopyResult `
                -ProfMigVersion 'M3-Test'

            $MigrationResult.Status |
                Should Be 'Failed'

            $MigrationResult.VerificationLevel |
                Should Be 'Hash'

            $MigrationResult.HashAlgorithm |
                Should Be 'SHA256'

            $MigrationResult.VerificationFailures |
                Should Be 1

            $MigrationResult.VerificationFailureItems.Count |
                Should Be 1

            $MigrationResult.VerificationFailureItems[0].Reason |
                Should Be 'HashMismatch'

            $ReportFile = New-ProfMigMigrationReport `
                -MigrationResult $MigrationResult `
                -ReportFolder $ReportFolder

            $Report = Get-Content `
                -LiteralPath $ReportFile `
                -Raw

            $Report |
                Should Match 'Verification level\s+:\s+Hash'

            $Report |
                Should Match 'Hash algorithm\s+:\s+SHA256'

            $Report |
                Should Match 'HashMismatch'

            $Report |
                Should Match 'Verification failures\s+:\s+1'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }
}
