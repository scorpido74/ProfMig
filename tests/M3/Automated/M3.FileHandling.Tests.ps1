<#
.SYNOPSIS
    ProfMig Milestone 3 regression tests - File Handling.

.DESCRIPTION
    Automated regression tests for safe file-copy behaviour,
    exclusions, existing destinations, missing sources and
    component-level failure isolation.

    Compatible with Pester 3.4.
#>

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$CopyEngineModule = Get-ProfMigTestModulePath 'ProfMig.CopyEngine'

Describe 'M3 - File Access and File Handling' {

    Import-Module $CopyEngineModule -Force

    # -----------------------------------------------------------------------
    # M3-FILE-01 - Normal file copy
    # -----------------------------------------------------------------------

    It 'M3-FILE-01 copies a normal accessible file successfully' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-01'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $Destination = Join-Path $TestRoot 'Destination\Copied.txt'

            'Normal ProfMig migration data' |
                Set-Content -LiteralPath $Source

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-01' `
                -SourceFile $Source `
                -DestinationFile $Destination `
                -VerificationLevel Standard

            $Result.FilesSelected | Should Be 1
            $Result.FilesCopied | Should Be 1
            $Result.FilesFailed | Should Be 0
            $Result.FilesSkipped | Should Be 0
            $Result.Status | Should Be 'Success'

            (Test-Path -LiteralPath $Destination -PathType Leaf) |
                Should Be $true

            $Result.FilesVerified | Should Be 1
            $Result.VerificationFailures | Should Be 0
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-FILE-02 - Missing source file
    # -----------------------------------------------------------------------

    It 'M3-FILE-02 handles a missing source file without terminating' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-02'

        try {
            $Source = Join-Path $TestRoot 'Missing.txt'
            $Destination = Join-Path $TestRoot 'Destination\Missing.txt'

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-02' `
                -SourceFile $Source `
                -DestinationFile $Destination

            $Result.FilesSelected | Should Be 1
            $Result.FilesCopied | Should Be 0
            $Result.FilesFailed | Should Be 1
            $Result.Status | Should Be 'Failed'

            $Result.Errors.Count | Should Be 1
            $Result.Errors[0].Reason | Should Be 'SourceNotFound'

            (Test-Path -LiteralPath $Destination) |
                Should Be $false
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-FILE-03 - Existing destination
    # -----------------------------------------------------------------------

    It 'M3-FILE-03 does not overwrite an existing destination file' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-03'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $DestinationDirectory = Join-Path $TestRoot 'Destination'
            $Destination = Join-Path $DestinationDirectory 'Existing.txt'

            New-Item `
                -Path $DestinationDirectory `
                -ItemType Directory `
                -Force |
                Out-Null

            'NEW SOURCE CONTENT' |
                Set-Content -LiteralPath $Source

            'ORIGINAL DESTINATION CONTENT' |
                Set-Content -LiteralPath $Destination

            $OriginalContent = Get-Content `
                -LiteralPath $Destination `
                -Raw

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-03' `
                -SourceFile $Source `
                -DestinationFile $Destination

            $CurrentContent = Get-Content `
                -LiteralPath $Destination `
                -Raw

            $Result.FilesCopied | Should Be 0
            $Result.FilesSkipped | Should Be 1
            $Result.FilesFailed | Should Be 0
            $Result.Status | Should Be 'CompletedWithWarnings'

            $Result.SkippedItems.Count | Should Be 1

            $Result.SkippedItems[0].Reason |
                Should Be 'Destination file already exists'

            $CurrentContent | Should Be $OriginalContent
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-FILE-04 - Destination directory creation
    # -----------------------------------------------------------------------

    It 'M3-FILE-04 creates a missing destination directory safely' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-04'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'

            $Destination = Join-Path `
                $TestRoot `
                'Level1\Level2\Level3\Copied.txt'

            'Nested destination test' |
                Set-Content -LiteralPath $Source

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-04' `
                -SourceFile $Source `
                -DestinationFile $Destination

            $Result.FilesCopied | Should Be 1
            $Result.FilesFailed | Should Be 0
            $Result.Status | Should Be 'Success'

            (Test-Path -LiteralPath $Destination -PathType Leaf) |
                Should Be $true
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-FILE-05 - Abandoned partial file
    # -----------------------------------------------------------------------

    It 'M3-FILE-05 replaces an abandoned ProfMig partial file safely' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-05'

        try {
            $Source = Join-Path $TestRoot 'Source.txt'
            $DestinationDirectory = Join-Path $TestRoot 'Destination'
            $Destination = Join-Path $DestinationDirectory 'Copied.txt'
            $Partial = $Destination + '.profmig-partial'

            New-Item `
                -Path $DestinationDirectory `
                -ItemType Directory `
                -Force |
                Out-Null

            'Correct source data' |
                Set-Content -LiteralPath $Source

            'Abandoned partial data' |
                Set-Content -LiteralPath $Partial

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-05' `
                -SourceFile $Source `
                -DestinationFile $Destination

            $Result.FilesCopied | Should Be 1
            $Result.FilesFailed | Should Be 0
            $Result.Status | Should Be 'Success'

            (Test-Path -LiteralPath $Destination -PathType Leaf) |
                Should Be $true

            (Test-Path -LiteralPath $Partial) |
                Should Be $false

            $SourceContent = Get-Content `
                -LiteralPath $Source `
                -Raw

            $DestinationContent = Get-Content `
                -LiteralPath $Destination `
                -Raw

            $DestinationContent | Should Be $SourceContent
        }
        finally {
            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }
        # -----------------------------------------------------------------------
    # M3-FILE-06 - Locked source file
    # -----------------------------------------------------------------------

    It 'M3-FILE-06 handles a locked source file with bounded retry' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-06'
        $LockStream = $null

        try {
            $Source = Join-Path $TestRoot 'Locked.txt'
            $Destination = Join-Path $TestRoot 'Destination\Locked.txt'

            'Locked ProfMig migration data' |
                Set-Content -LiteralPath $Source

            # Open the source with FileShare.None so Windows generates
            # a real sharing violation when ProfMig attempts the copy.
            $LockStream = [System.IO.File]::Open(
                $Source,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::None
            )

            $Result = Invoke-ProfMigFileCopy `
                -Component 'M3-FILE-06' `
                -SourceFile $Source `
                -DestinationFile $Destination

            $Result.FilesSelected | Should Be 1
            $Result.FilesCopied | Should Be 0
            $Result.FilesFailed | Should Be 1
            $Result.Status | Should Be 'CompletedWithErrors'

            $Result.Errors.Count | Should Be 1
            $Result.Errors[0].Reason | Should Be 'FileLocked'
            $Result.Errors[0].Retryable | Should Be $true
            $Result.Errors[0].RetryCount | Should Be 3

            (Test-Path -LiteralPath $Destination) |
                Should Be $false

            (Test-Path -LiteralPath ($Destination + '.profmig-partial')) |
                Should Be $false
        }
        finally {
            if ($null -ne $LockStream) {
                $LockStream.Dispose()
            }

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }

    # -----------------------------------------------------------------------
    # M3-FILE-07 - Continue after individual file failure
    # -----------------------------------------------------------------------

    It 'M3-FILE-07 continues a component migration after one file fails' {

        $TestRoot = New-ProfMigTestRoot -TestId 'M3-FILE-07'
        $LockStream = $null

        try {
            $SourceDirectory = Join-Path $TestRoot 'Source'
            $DestinationDirectory = Join-Path $TestRoot 'Destination'

            New-Item `
                -Path $SourceDirectory `
                -ItemType Directory `
                -Force |
                Out-Null

            $GoodFile = Join-Path $SourceDirectory 'Good.txt'
            $LockedFile = Join-Path $SourceDirectory 'Locked.txt'

            'Good migration data' |
                Set-Content -LiteralPath $GoodFile

            'Locked migration data' |
                Set-Content -LiteralPath $LockedFile

            $LockStream = [System.IO.File]::Open(
                $LockedFile,
                [System.IO.FileMode]::Open,
                [System.IO.FileAccess]::Read,
                [System.IO.FileShare]::None
            )

            $Result = Invoke-ProfMigComponentCopy `
                -Component 'M3-FILE-07' `
                -SourcePath $SourceDirectory `
                -DestinationPath $DestinationDirectory

            $Result.FilesSelected | Should Be 2
            $Result.FilesCopied | Should Be 1
            $Result.FilesFailed | Should Be 1
            $Result.Status | Should Be 'CompletedWithErrors'

            $Result.Errors.Count | Should Be 1
            $Result.Errors[0].Reason | Should Be 'FileLocked'
            $Result.Errors[0].Retryable | Should Be $true
            $Result.Errors[0].RetryCount | Should Be 3

            (Test-Path `
                -LiteralPath (Join-Path $DestinationDirectory 'Good.txt') `
                -PathType Leaf) |
                Should Be $true

            (Test-Path `
                -LiteralPath (Join-Path $DestinationDirectory 'Locked.txt')) |
                Should Be $false

            $Result.FilesVerified | Should Be 1
            $Result.VerificationFailures | Should Be 0
        }
        finally {
            if ($null -ne $LockStream) {
                $LockStream.Dispose()
            }

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }
}