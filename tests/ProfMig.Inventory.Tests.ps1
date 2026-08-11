<#
.SYNOPSIS
    Pester tests for the ProfMig Inventory Engine.

.DESCRIPTION
    Validates the basic behaviour and output of
    ProfMig.Inventory.psm1.

    Compatible with Pester 3.4.
#>

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$ModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Inventory.psm1'

$ConfigModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Configuration.psm1'

$ConfigPath = Join-Path `
    $ProjectRoot `
    'src\Config.psd1'


Describe 'ProfMig Inventory Engine' {

    Import-Module $ModulePath -Force
    Import-Module $ConfigModulePath -Force

    $Config = Import-ProfMigConfiguration -Path $ConfigPath

    $Profiles = @(
        Get-UserProfiles `
            -ExcludedProfiles $Config.ExcludedProfiles
    )


    It 'loads the Get-UserProfiles function' {

        $command = Get-Command `
            Get-UserProfiles `
            -ErrorAction SilentlyContinue

        ($null -ne $command) |
            Should Be $true
    }


    It 'returns at least one Windows profile on the test system' {

        ($Profiles.Count -gt 0) |
            Should Be $true
    }


    It 'returns structured PowerShell objects' {

        $Profiles[0].GetType().Name |
            Should Be 'PSCustomObject'
    }


    It 'returns required profile properties' {

        $propertyNames = @(
            $Profiles[0].PSObject.Properties |
                Select-Object -ExpandProperty Name
        )

        ($propertyNames -contains 'ProfileName') |
            Should Be $true

        ($propertyNames -contains 'ProfilePath') |
            Should Be $true

        ($propertyNames -contains 'SID') |
            Should Be $true

        ($propertyNames -contains 'AccountName') |
            Should Be $true

        ($propertyNames -contains 'AccountDomain') |
            Should Be $true

        ($propertyNames -contains 'Exists') |
            Should Be $true

        ($propertyNames -contains 'Accessible') |
            Should Be $true

        ($propertyNames -contains 'Status') |
            Should Be $true

        ($propertyNames -contains 'RelevantFolders') |
            Should Be $true
    }


    It 'returns expected relevant folder definitions' {

        $folderNames = @(
            $Profiles[0].RelevantFolders.PSObject.Properties |
                Select-Object -ExpandProperty Name
        )

        ($folderNames -contains 'Desktop') |
            Should Be $true

        ($folderNames -contains 'Documents') |
            Should Be $true

        ($folderNames -contains 'Downloads') |
            Should Be $true

        ($folderNames -contains 'Pictures') |
            Should Be $true

        ($folderNames -contains 'Favorites') |
            Should Be $true

        ($folderNames -contains 'AppData') |
            Should Be $true
    }


    It 'returns structured relevant folder information' {

        $folder = $Profiles[0].RelevantFolders.Documents

        ($null -ne $folder.Path) |
            Should Be $true

        ($null -ne $folder.Exists) |
            Should Be $true

        ($null -ne $folder.Accessible) |
            Should Be $true
    }


    It 'uses only supported profile status values' {

        $validStatuses = @(
            'Available',
            'Inaccessible',
            'Missing'
        )

        $invalidProfiles = @(
            $Profiles |
                Where-Object {
                    $validStatuses -notcontains $_.Status
                }
        )

        $invalidProfiles.Count |
            Should Be 0
    }


    It 'applies configured profile exclusions' {

        $returnedNames = @(
            $Profiles |
                Select-Object -ExpandProperty ProfileName
        )

        $excludedProfilesReturned = @(
            $Config.ExcludedProfiles |
                Where-Object {
                    $returnedNames -contains $_
                }
        )

        $excludedProfilesReturned.Count |
            Should Be 0
    }


    It 'returns profile paths for discovered profiles' {

        $profilesWithoutPath = @(
            $Profiles |
                Where-Object {
                    [string]::IsNullOrWhiteSpace(
                        $_.ProfilePath
                    )
                }
        )

        $profilesWithoutPath.Count |
            Should Be 0
    }


    It 'returns SID information for discovered registry profiles' {

        $profilesWithoutSID = @(
            $Profiles |
                Where-Object {
                    [string]::IsNullOrWhiteSpace(
                        $_.SID
                    )
                }
        )

        $profilesWithoutSID.Count |
            Should Be 0
    }


    It 'returns predictable status information for every profile' {

        $profilesWithoutStatus = @(
            $Profiles |
                Where-Object {
                    [string]::IsNullOrWhiteSpace(
                        $_.Status
                    )
                }
        )

        $profilesWithoutStatus.Count |
            Should Be 0
    }

}