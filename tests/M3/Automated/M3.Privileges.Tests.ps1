# ============================================================================
# ProfMig - Milestone 3 Privileges Regression Tests
# ============================================================================
# Compatible with Pester 3.4
#
# The non-administrator rejection path remains a manual/hybrid M3 test because
# an elevated Pester process cannot genuinely become non-elevated in-process.
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


Describe 'M3 - Privilege Validation' {

    It 'M3-PRIV-01 detects that the elevated test session is administrator' {

        $IsAdministrator = Test-ProfMigAdministrator

        $IsAdministrator |
            Should Be $true
    }


    It 'M3-PRIV-02 passes when administrator privileges are required and present' {

        $Result = Test-ProfMigPrivileges `
            -AdministratorRequired

        $Result.Check |
            Should Be 'Privileges'

        $Result.Status |
            Should Be 'Passed'

        $Result.Severity |
            Should Be 'Critical'

        $Result.Details.IsAdministrator |
            Should Be $true

        $Result.Details.Identity |
            Should Not BeNullOrEmpty

        $Result.Message |
            Should Match 'administrative privileges'
    }


    It 'M3-PRIV-03 passes informationally when administrator privileges are not required' {

        $Result = Test-ProfMigPrivileges `
            -AdministratorRequired:$false

        $Result.Check |
            Should Be 'Privileges'

        $Result.Status |
            Should Be 'Passed'

        $Result.Severity |
            Should Be 'Information'

        $Result.Message |
            Should Match 'not required'
    }
}
