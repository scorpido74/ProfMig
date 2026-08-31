<#
.SYNOPSIS
    ProfMig Milestone 3 regression tests - Verification.

.DESCRIPTION
    Automated regression tests for migration verification and
    data-integrity behaviour.

    Compatible with Pester 3.4.
#>

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$VerificationModule = Get-ProfMigTestModulePath 'ProfMig.Verification'

Describe 'M3 - Migration Verification and Data Integrity' {

    Import-Module $VerificationModule -Force

    # -----------------------------------------------------------------------
    # M3-VER-01 - Matching file using Standard verification
    # -----------------------------------------------------------------------

    It 'M3-VER-01 verifies matching files using Standard verification' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-VER-01'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Destination.txt'

            'ProfMig verification test' |
                Set-Content -LiteralPath $Source

            Copy-Item `
                -LiteralPath $Source `
                -Destination $Destination

            $Result = Test-ProfMigFileVerification `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -Component 'M3-VER-01' `
                -VerificationLevel Standard

            $Result.Verified | Should Be $true
            $Result.Status | Should Be 'Success'
            $Result.Reason | Should Be 'Verified'
            $Result.SizeMatch | Should Be $true
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-VER-02 - Missing destination
    # -----------------------------------------------------------------------

    It 'M3-VER-02 detects a missing destination file' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-VER-02'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Missing.txt'

            'ProfMig verification test' |
                Set-Content -LiteralPath $Source

            $Result = Test-ProfMigFileVerification `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -Component 'M3-VER-02' `
                -VerificationLevel Standard

            $Result.Verified | Should Be $false
            $Result.Status | Should Be 'Failed'
            $Result.Reason | Should Be 'DestinationMissing'
            $Result.SourceExists | Should Be $true
            $Result.DestinationExists | Should Be $false
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-VER-03 - Hash verification
    # -----------------------------------------------------------------------

    It 'M3-VER-03 verifies matching files using SHA256 hash verification' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-VER-03'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Destination.txt'

            'ProfMig SHA256 verification test' |
                Set-Content -LiteralPath $Source

            Copy-Item `
                -LiteralPath $Source `
                -Destination $Destination

            $Result = Test-ProfMigFileVerification `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -Component 'M3-VER-03' `
                -VerificationLevel Hash `
                -HashAlgorithm SHA256

            $Result.Verified | Should Be $true
            $Result.Status | Should Be 'Success'
            $Result.Reason | Should Be 'Verified'
            $Result.SizeMatch | Should Be $true
            $Result.HashMatch | Should Be $true
            $Result.HashAlgorithm | Should Be 'SHA256'
            $Result.SourceHash | Should Not BeNullOrEmpty
            $Result.DestinationHash | Should Not BeNullOrEmpty
            $Result.SourceHash | Should Be $Result.DestinationHash
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-VER-04 - Size mismatch
    # -----------------------------------------------------------------------

    It 'M3-VER-04 detects a destination size mismatch' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-VER-04'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Destination.txt'

            'Original source content' |
                Set-Content -LiteralPath $Source

            'Modified destination content with additional data' |
                Set-Content -LiteralPath $Destination

            $Result = Test-ProfMigFileVerification `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -Component 'M3-VER-04' `
                -VerificationLevel Hash `
                -HashAlgorithm SHA256

            $Result.Verified | Should Be $false
            $Result.Status | Should Be 'Failed'
            $Result.Reason | Should Be 'SizeMismatch'
            $Result.SizeMatch | Should Be $false
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-VER-05 - Hash mismatch with equal file size
    # -----------------------------------------------------------------------

    It 'M3-VER-05 detects a hash mismatch when file sizes are equal' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-VER-05'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Destination.txt'

            # Equal-length content ensures that hash verification is reached.
            [System.IO.File]::WriteAllText(
                $Source,
                'AAAA'
            )

            [System.IO.File]::WriteAllText(
                $Destination,
                'BBBB'
            )

            $Result = Test-ProfMigFileVerification `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -Component 'M3-VER-05' `
                -VerificationLevel Hash `
                -HashAlgorithm SHA256

            $Result.Verified | Should Be $false
            $Result.Status | Should Be 'Failed'
            $Result.Reason | Should Be 'HashMismatch'
            $Result.SizeMatch | Should Be $true
            $Result.HashMatch | Should Be $false
            $Result.SourceHash | Should Not Be $Result.DestinationHash
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }
}
