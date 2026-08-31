# ============================================================================
# ProfMig - Milestone 3 Storage Capacity Regression Tests
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


Describe 'M3 - Storage Capacity Validation' {

    It 'M3-STO-01 passes when sufficient destination capacity is available' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-STO-01'

        $Source = Join-Path $TestRoot 'Source'
        $Destination = Join-Path $TestRoot 'Destination'

        New-Item -Path $Source -ItemType Directory -Force | Out-Null
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null

        try {

            $RequiredBytes = [Int64](1MB)

            $Result = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes $RequiredBytes `
                -BufferPercent 20 `
                -WarningRemainingPercent 0

            $Result.Check |
                Should Be 'FreeDiskSpace'

            $Result.Status |
                Should Be 'Passed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Details.CalculationMethod |
                Should Be 'ProvidedRequiredBytes'

            $Result.Details.ProfileBytes |
                Should Be $RequiredBytes

            $Result.Details.AvailableBytes |
                Should BeGreaterThan $Result.Details.RequiredBytes
        }
        finally {

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }


    It 'M3-STO-02 blocks migration when required capacity exceeds available space' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-STO-02'

        $Source = Join-Path $TestRoot 'Source'
        $Destination = Join-Path $TestRoot 'Destination'

        New-Item -Path $Source -ItemType Directory -Force | Out-Null
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null

        try {

            $Probe = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes 0 `
                -BufferPercent 0 `
                -WarningRemainingPercent 0

            [Int64]$AvailableBytes =
                $Probe.Details.AvailableBytes

            [Int64]$RequiredBytes =
                $AvailableBytes + 1MB

            $Result = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes $RequiredBytes `
                -BufferPercent 0 `
                -WarningRemainingPercent 0

            $Result.Status |
                Should Be 'Failed'

            $Result.Severity |
                Should Be 'Critical'

            $Result.Details.RequiredBytes |
                Should BeGreaterThan $Result.Details.AvailableBytes

            $Result.Details.ShortageBytes |
                Should BeGreaterThan 0

            $Result.Message |
                Should Match 'Insufficient destination disk space'
        }
        finally {

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }


    It 'M3-STO-03 applies the configured safety buffer to required capacity' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-STO-03'

        $Source = Join-Path $TestRoot 'Source'
        $Destination = Join-Path $TestRoot 'Destination'

        New-Item -Path $Source -ItemType Directory -Force | Out-Null
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null

        try {

            [Int64]$SourceBytes = 10MB
            [int]$BufferPercent = 20

            [Int64]$ExpectedBufferBytes = 2MB
            [Int64]$ExpectedRequiredBytes = 12MB

            $Result = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes $SourceBytes `
                -BufferPercent $BufferPercent `
                -WarningRemainingPercent 0

            $Result.Status |
                Should Be 'Passed'

            $Result.Details.ProfileBytes |
                Should Be $SourceBytes

            $Result.Details.BufferPercent |
                Should Be $BufferPercent

            $Result.Details.BufferBytes |
                Should Be $ExpectedBufferBytes

            $Result.Details.RequiredBytes |
                Should Be $ExpectedRequiredBytes
        }
        finally {

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }


    It 'M3-STO-04 warns when capacity is sufficient but remaining space is below threshold' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-STO-04'

        $Source = Join-Path $TestRoot 'Source'
        $Destination = Join-Path $TestRoot 'Destination'

        New-Item -Path $Source -ItemType Directory -Force | Out-Null
        New-Item -Path $Destination -ItemType Directory -Force | Out-Null

        try {

            $Probe = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes 0 `
                -BufferPercent 0 `
                -WarningRemainingPercent 0

            [Int64]$AvailableBytes =
                $Probe.Details.AvailableBytes
# DestinationDriveTotalSize is a formatted display string,
            # so derive the actual total from remaining-percent behaviour
            # instead by choosing a requirement very close to available space.
            #
            # Leave 1 MB free. This should remain sufficient while putting
            # RemainingPercent well below the 100% warning threshold.
            [Int64]$RequiredBytes =
                $AvailableBytes - 1MB

            if ($RequiredBytes -lt 0) {
                throw 'Insufficient free disk space to execute storage regression test.'
            }

            $Result = Test-ProfMigDiskSpace `
                -SourceProfile $Source `
                -DestinationProfile $Destination `
                -RequiredBytes $RequiredBytes `
                -BufferPercent 0 `
                -WarningRemainingPercent 100

            $Result.Status |
                Should Be 'Warning'

            $Result.Severity |
                Should Be 'Warning'

            $Result.Details.AvailableBytes |
                Should BeGreaterThan $Result.Details.RequiredBytes

            $Result.Details.RemainingPercent |
                Should BeLessThan 100

            $Result.Message |
                Should Match 'remaining disk space'
        }
        finally {

            Remove-ProfMigTestRoot -Path $TestRoot
        }
    }
}
