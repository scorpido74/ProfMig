# ============================================================================
# ProfMig - Milestone 3 Profile Validation Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$ValidationModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Validation'

Remove-Module ProfMig.Validation `
    -Force `
    -ErrorAction SilentlyContinue

Import-Module $ValidationModule -Force


Describe 'M3 - Profile Validation' {

    It 'M3-VAL-01 accepts an existing local source profile' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-VAL-01'

        try {

            New-Item `
                -Path (Join-Path $TestRoot 'Documents') `
                -ItemType Directory `
                -Force |
                Out-Null

            $Result = Test-ProfMigSourceProfile `
                -Path $TestRoot

            $Result.Check |
                Should Be 'SourceProfile'

            $Result.Status |
                Should Be 'Passed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Details.Path |
                Should Not BeNullOrEmpty
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-VAL-02 blocks a missing source profile' {

        $BaseRoot = New-ProfMigTestRoot `
            -TestId 'M3-VAL-02'

        $MissingSource = Join-Path `
            $BaseRoot `
            'MissingSource'

        try {

            $Result = Test-ProfMigSourceProfile `
                -Path $MissingSource

            $Result.Check |
                Should Be 'SourceProfile'

            $Result.Status |
                Should Be 'Failed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Message |
                Should Match 'does not exist'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $BaseRoot
        }
    }


    It 'M3-VAL-03 accepts a usable destination and blocks identical profiles' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-VAL-03'

        $Source = Join-Path `
            $TestRoot `
            'Source'

        $Destination = Join-Path `
            $TestRoot `
            'Destination'

        New-Item `
            -Path $Source `
            -ItemType Directory `
            -Force |
            Out-Null

        try {

            $DestinationResult =
                Test-ProfMigDestinationProfile `
                    -Path $Destination

            $DestinationResult.Status |
                Should Be 'Passed'

            $DestinationResult.Details.Exists |
                Should Be $false

            $DifferentResult =
                Test-ProfMigProfilesDiffer `
                    -SourceProfile $Source `
                    -DestinationProfile $Destination

            $DifferentResult.Status |
                Should Be 'Passed'

            $SameResult =
                Test-ProfMigProfilesDiffer `
                    -SourceProfile $Source `
                    -DestinationProfile $Source

            $SameResult.Status |
                Should Be 'Failed'

            $SameResult.Severity |
                Should Be 'Critical'

            $SameResult.Message |
                Should Match 'same'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-VAL-04 validates accessible required source directories' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-VAL-04'

        $RequiredDirectories = @(
            'Documents'
            'Desktop'
        )

        try {

            foreach ($Directory in $RequiredDirectories) {

                $DirectoryPath = Join-Path `
                    $TestRoot `
                    $Directory

                New-Item `
                    -Path $DirectoryPath `
                    -ItemType Directory `
                    -Force |
                    Out-Null

                Set-Content `
                    -LiteralPath (
                        Join-Path $DirectoryPath 'validation.txt'
                    ) `
                    -Value 'ProfMig validation regression test'
            }

            $Result =
                Test-ProfMigSourceAccessibility `
                    -Path $TestRoot `
                    -RequiredDirectories $RequiredDirectories

            $Result.Check |
                Should Be 'SourceAccessibility'

            $Result.Status |
                Should Be 'Passed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Details.CheckedDirectories.Count |
                Should Be 2

            (
                $Result.Details.CheckedDirectories -contains 'Documents'
            ) |
                Should Be $true

            (
                $Result.Details.CheckedDirectories -contains 'Desktop'
            ) |
                Should Be $true
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-VAL-05 blocks nested source and destination profiles' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-VAL-05'

        $Source = Join-Path `
            $TestRoot `
            'Source'

        $Destination = Join-Path `
            $Source `
            'NestedDestination'

        New-Item `
            -Path $Destination `
            -ItemType Directory `
            -Force |
            Out-Null

        try {

            $Result =
                Test-ProfMigCriticalConditions `
                    -SourceProfile $Source `
                    -DestinationProfile $Destination

            $Result.Check |
                Should Be 'CriticalConditions'

            $Result.Status |
                Should Be 'Failed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Message |
                Should Match 'inside the source profile'

            $ReverseResult =
                Test-ProfMigCriticalConditions `
                    -SourceProfile $Destination `
                    -DestinationProfile $Source

            $ReverseResult.Status |
                Should Be 'Failed'

            $ReverseResult.Severity |
                Should Be 'Critical'

            $ReverseResult.Message |
                Should Match 'inside the destination profile'
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }
}
