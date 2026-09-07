# ============================================================================
# Test-ProfMigMigration.ps1
#
# Tests for ProfMig.Migration.psm1.
#
# These tests validate profile resolution and migration safety without
# performing a real profile migration.
# ============================================================================

$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ModuleRoot  = Join-Path $ProjectRoot 'src\Modules'

# ----------------------------------------------------------------------------
# Import required modules
# ----------------------------------------------------------------------------

Import-Module (Join-Path $ModuleRoot 'ProfMig.ErrorHandling.psm1') -Force
Import-Module (Join-Path $ModuleRoot 'ProfMig.Migration.psm1') -Force


# ----------------------------------------------------------------------------
# Test helpers
# ----------------------------------------------------------------------------

$script:PassedCount = 0
$script:FailedCount = 0

function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [string]$Details
    )

    if ($Passed) {

        $script:PassedCount++

        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    else {

        $script:FailedCount++

        Write-Host "[FAIL] $Name" -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host "       $Details" -ForegroundColor Red
        }
    }
}


# ----------------------------------------------------------------------------
# Test data
# ----------------------------------------------------------------------------

$Profiles = @(
    [PSCustomObject]@{
        ProfileName = 'SourceUser'
        SID         = 'S-1-5-21-1000'
        ProfilePath = 'C:\Users\SourceUser'
        Accessible  = $true
    }

    [PSCustomObject]@{
        ProfileName = 'DestinationUser'
        SID         = 'S-1-5-21-2000'
        ProfilePath = 'C:\Users\DestinationUser'
        Accessible  = $true
    }
)


# ----------------------------------------------------------------------------
# Test 1: Resolve profile by SID
# ----------------------------------------------------------------------------

try {

    $result = Resolve-ProfMigProfile `
        -Profiles $Profiles `
        -Sid 'S-1-5-21-1000'

    $passed = (
        $result.ProfileName -eq 'SourceUser' -and
        $result.SID -eq 'S-1-5-21-1000' -and
        $result.ProfilePath -eq 'C:\Users\SourceUser'
    )

    Write-TestResult `
        -Name 'Resolve profile by SID' `
        -Passed $passed
}
catch {

    Write-TestResult `
        -Name 'Resolve profile by SID' `
        -Passed $false `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 2: Resolve profile by path
# ----------------------------------------------------------------------------

try {

    $result = Resolve-ProfMigProfile `
        -Profiles $Profiles `
        -ProfilePath 'C:\Users\DestinationUser'

    $passed = (
        $result.ProfileName -eq 'DestinationUser' -and
        $result.SID -eq 'S-1-5-21-2000'
    )

    Write-TestResult `
        -Name 'Resolve profile by path' `
        -Passed $passed
}
catch {

    Write-TestResult `
        -Name 'Resolve profile by path' `
        -Passed $false `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 3: Profile path matching is case-insensitive
# ----------------------------------------------------------------------------

try {

    $result = Resolve-ProfMigProfile `
        -Profiles $Profiles `
        -ProfilePath 'c:\users\destinationuser\'

    $passed = (
        $result.ProfileName -eq 'DestinationUser'
    )

    Write-TestResult `
        -Name 'Profile path matching is case-insensitive' `
        -Passed $passed
}
catch {

    Write-TestResult `
        -Name 'Profile path matching is case-insensitive' `
        -Passed $false `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 4: Unknown SID produces structured validation error
# ----------------------------------------------------------------------------

try {

    $null = Resolve-ProfMigProfile `
        -Profiles $Profiles `
        -Sid 'S-1-5-21-9999'

    Write-TestResult `
        -Name 'Unknown SID is rejected' `
        -Passed $false `
        -Details 'Expected Resolve-ProfMigProfile to throw.'
}
catch {

    $passed = (
        $_.Exception.Data['ProfMigCategory'] -eq 'ValidationError' -and
        $_.Exception.Data['ProfMigReason'] -eq 'ProfileNotFound'
    )

    Write-TestResult `
        -Name 'Unknown SID is rejected' `
        -Passed $passed `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 5: Source and destination cannot use same path
# ----------------------------------------------------------------------------

try {

    $source = $Profiles[0]

    $destination = [PSCustomObject]@{
        ProfileName = 'OtherUser'
        SID         = 'S-1-5-21-3000'
        ProfilePath = 'C:\Users\SourceUser'
        Accessible  = $true
    }

    $null = Test-ProfMigMigrationProfiles `
        -SourceProfile $source `
        -DestinationProfile $destination

    Write-TestResult `
        -Name 'Same source and destination path is rejected' `
        -Passed $false `
        -Details 'Expected profile validation to throw.'
}
catch {

    $passed = (
        $_.Exception.Data['ProfMigCategory'] -eq 'ValidationError' -and
        $_.Exception.Data['ProfMigReason'] -eq 'SourceEqualsDestination'
    )

    Write-TestResult `
        -Name 'Same source and destination path is rejected' `
        -Passed $passed `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 6: Source and destination cannot use same SID
# ----------------------------------------------------------------------------

try {

    $source = $Profiles[0]

    $destination = [PSCustomObject]@{
        ProfileName = 'OtherUser'
        SID         = $source.SID
        ProfilePath = 'C:\Users\OtherUser'
        Accessible  = $true
    }

    $null = Test-ProfMigMigrationProfiles `
        -SourceProfile $source `
        -DestinationProfile $destination

    Write-TestResult `
        -Name 'Same source and destination SID is rejected' `
        -Passed $false `
        -Details 'Expected profile validation to throw.'
}
catch {

    $passed = (
        $_.Exception.Data['ProfMigCategory'] -eq 'ValidationError' -and
        $_.Exception.Data['ProfMigReason'] -eq 'SourceSidEqualsDestinationSid'
    )

    Write-TestResult `
        -Name 'Same source and destination SID is rejected' `
        -Passed $passed `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 7: Inaccessible source is rejected
# ----------------------------------------------------------------------------

try {

    $source = [PSCustomObject]@{
        ProfileName = 'SourceUser'
        SID         = 'S-1-5-21-1000'
        ProfilePath = 'C:\Users\SourceUser'
        Accessible  = $false
    }

    $null = Test-ProfMigMigrationProfiles `
        -SourceProfile $source `
        -DestinationProfile $Profiles[1]

    Write-TestResult `
        -Name 'Inaccessible source profile is rejected' `
        -Passed $false `
        -Details 'Expected profile validation to throw.'
}
catch {

    $passed = (
        $_.Exception.Data['ProfMigCategory'] -eq 'ValidationError' -and
        $_.Exception.Data['ProfMigReason'] -eq 'SourceProfileNotAccessible'
    )

    Write-TestResult `
        -Name 'Inaccessible source profile is rejected' `
        -Passed $passed `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 8: Inaccessible destination is rejected
# ----------------------------------------------------------------------------

try {

    $destination = [PSCustomObject]@{
        ProfileName = 'DestinationUser'
        SID         = 'S-1-5-21-2000'
        ProfilePath = 'C:\Users\DestinationUser'
        Accessible  = $false
    }

    $null = Test-ProfMigMigrationProfiles `
        -SourceProfile $Profiles[0] `
        -DestinationProfile $destination

    Write-TestResult `
        -Name 'Inaccessible destination profile is rejected' `
        -Passed $false `
        -Details 'Expected profile validation to throw.'
}
catch {

    $passed = (
        $_.Exception.Data['ProfMigCategory'] -eq 'ValidationError' -and
        $_.Exception.Data['ProfMigReason'] -eq 'DestinationProfileNotAccessible'
    )

    Write-TestResult `
        -Name 'Inaccessible destination profile is rejected' `
        -Passed $passed `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 9: Valid source and destination are accepted
# ----------------------------------------------------------------------------

try {

    $result = Test-ProfMigMigrationProfiles `
        -SourceProfile $Profiles[0] `
        -DestinationProfile $Profiles[1]

    Write-TestResult `
        -Name 'Valid source and destination are accepted' `
        -Passed ($result -eq $true)
}
catch {

    Write-TestResult `
        -Name 'Valid source and destination are accepted' `
        -Passed $false `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Test 10: Migration configuration contains default folders
# ----------------------------------------------------------------------------

try {

    $configuration = @{
        Application = @{
            Name    = 'ProfMig'
            Version = '0.2.0'
        }

        Verification = @{
            Level = 'Standard'
        }
    }

    $result = New-ProfMigMigrationConfiguration `
        -Configuration $configuration

    $expectedFolders = @(
        'Desktop'
        'Documents'
        'Downloads'
        'Pictures'
        'Music'
        'Videos'
        'Favorites'
        'Links'
    )

    $missingFolders = @(
        $expectedFolders |
            Where-Object {
                $_ -notin $result.Folders
            }
    )

    $passed = (
        $missingFolders.Count -eq 0 -and
        $result.Application.Version -eq '0.2.0' -and
        $result.Verification.Level -eq 'Standard'
    )

    Write-TestResult `
        -Name 'Migration configuration contains default folders' `
        -Passed $passed
}
catch {

    Write-TestResult `
        -Name 'Migration configuration contains default folders' `
        -Passed $false `
        -Details $_.Exception.Message
}


# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'ProfMig Migration Module Test Summary' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

Write-Host "Passed : $script:PassedCount"
Write-Host "Failed : $script:FailedCount"

if ($script:FailedCount -gt 0) {

    Write-Host 'RESULT : FAILED' -ForegroundColor Red
    exit 1
}

Write-Host 'RESULT : PASSED' -ForegroundColor Green
exit 0