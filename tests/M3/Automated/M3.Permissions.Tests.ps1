# ============================================================================
# ProfMig - Milestone 3 Permissions / ACL Regression Tests
# ============================================================================
# Compatible with Pester 3.4
# ============================================================================

$M3Root = Split-Path -Parent $PSScriptRoot
$HelperPath = Join-Path $M3Root 'TestHelpers.psm1'

Import-Module $HelperPath -Force

$PermissionsModule = Get-ProfMigTestModulePath `
    -ModuleName 'ProfMig.Permissions'

Remove-Module ProfMig.Permissions `
    -Force `
    -ErrorAction SilentlyContinue

Import-Module $PermissionsModule -Force


function Get-M3CurrentUserSid {

    return (
        [System.Security.Principal.WindowsIdentity]::GetCurrent()
    ).User.Value
}


function Add-M3AclRule {

    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Sid,

        [Parameter(Mandatory)]
        [System.Security.AccessControl.FileSystemRights]$Rights
    )

    $Acl = Get-Acl `
        -LiteralPath $Path `
        -ErrorAction Stop

    $SecurityIdentifier =
        New-Object `
            System.Security.Principal.SecurityIdentifier `
            $Sid

    $Rule =
        New-Object `
            System.Security.AccessControl.FileSystemAccessRule(
                $SecurityIdentifier,
                $Rights,
                (
                    [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
                    [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
                ),
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )

    $Acl.AddAccessRule($Rule)

    Set-Acl `
        -LiteralPath $Path `
        -AclObject $Acl `
        -ErrorAction Stop
}


function Remove-M3ExplicitAclRules {

    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Sid
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $Acl = Get-Acl `
        -LiteralPath $Path `
        -ErrorAction SilentlyContinue

    if ($null -eq $Acl) {
        return
    }

    foreach ($Rule in @($Acl.Access)) {

        $RuleSid = $null

        try {

            $RuleSid = $Rule.IdentityReference.Translate(
                [System.Security.Principal.SecurityIdentifier]
            ).Value
        }
        catch {

            $RuleSid = $Rule.IdentityReference.Value
        }

        if (
            $RuleSid -eq $Sid -and
            -not $Rule.IsInherited
        ) {

            $Acl.RemoveAccessRuleSpecific($Rule)
        }
    }

    Set-Acl `
        -LiteralPath $Path `
        -AclObject $Acl `
        -ErrorAction SilentlyContinue
}


Describe 'M3 - Permissions and ACL' {

    It 'M3-ACL-01 reads ACL information for a temporary directory' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-ACL-01'

        try {

            $AclInfo = Get-ProfMigAclInfo `
                -Path $TestRoot

            $AclInfo.Success |
                Should Be $true

            $AclInfo.ItemType |
                Should Be 'Directory'

            $AclInfo.Path |
                Should Be (
                    Get-Item -LiteralPath $TestRoot
                ).FullName

            $AclInfo.AccessRuleCount |
                Should BeGreaterThan 0

            $AclInfo.Owner |
                Should Not BeNullOrEmpty
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-ACL-02 recognizes destination user access' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-ACL-02'

        $DestinationSid = Get-M3CurrentUserSid

        try {

            Add-M3AclRule `
                -Path $TestRoot `
                -Sid $DestinationSid `
                -Rights Modify

            $Validation = Test-ProfMigAcl `
                -Path $TestRoot `
                -DestinationSid $DestinationSid

            $Validation.DestinationUserAccess |
                Should Be $true

            ($Validation.Findings -contains 'ACL-DESTINATION-NO-ACCESS') |
                Should Be $false
        }
        finally {

            Remove-M3ExplicitAclRules `
                -Path $TestRoot `
                -Sid $DestinationSid

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-ACL-03 detects missing destination user access' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-ACL-03'

        # Valid SID syntax, deliberately not the current user.
        $MissingDestinationSid =
            'S-1-5-21-4242424242-4242424242-4242424242-4242'

        try {

            $Validation = Test-ProfMigAcl `
                -Path $TestRoot `
                -DestinationSid $MissingDestinationSid

            $Validation.DestinationUserAccess |
                Should Be $false

            $Validation.RemediationRequired |
                Should Be $true

            ($Validation.Findings -contains 'ACL-DESTINATION-NO-ACCESS') |
                Should Be $true
        }
        finally {

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-ACL-04 repairs missing destination access with explicit Modify permission' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-ACL-04'

        $DestinationSid =
            'S-1-5-21-4242424242-4242424242-4242424242-4343'

        try {

            $Before = Test-ProfMigAcl `
                -Path $TestRoot `
                -DestinationSid $DestinationSid

            $Before.DestinationUserAccess |
                Should Be $false

            $Result = Repair-ProfMigDestinationPermissions `
                -Path $TestRoot `
                -DestinationSid $DestinationSid `
                -Confirm:$false

            $Result.Success |
                Should Be $true

            $Result.Changed |
                Should Be $true

            $Result.Strategy |
                Should Be 'ExplicitDestinationAccess'

            ($Result.Action -contains 'GrantDestinationModify') |
                Should Be $true

            $Result.ValidationAfter.DestinationUserAccess |
                Should Be $true
        }
        finally {

            Remove-M3ExplicitAclRules `
                -Path $TestRoot `
                -Sid $DestinationSid

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }


    It 'M3-ACL-05 repair does not introduce Everyone FullControl' {

        $TestRoot = New-ProfMigTestRoot `
            -TestId 'M3-ACL-05'

        $DestinationSid =
            'S-1-5-21-4242424242-4242424242-4242424242-4444'

        try {

            $Result = Repair-ProfMigDestinationPermissions `
                -Path $TestRoot `
                -DestinationSid $DestinationSid `
                -Confirm:$false

            $Result.Success |
                Should Be $true

            $Acl = Get-Acl `
                -LiteralPath $TestRoot `
                -ErrorAction Stop

            $UnsafeRules = @(
                foreach ($Rule in $Acl.Access) {

                    $RuleSid = $null

                    try {

                        $RuleSid = $Rule.IdentityReference.Translate(
                            [System.Security.Principal.SecurityIdentifier]
                        ).Value
                    }
                    catch {

                        $RuleSid = $Rule.IdentityReference.Value
                    }

                    if (
                        $RuleSid -eq 'S-1-1-0' -and
                        $Rule.AccessControlType -eq 'Allow' -and
                        (
                            $Rule.FileSystemRights -band
                            [System.Security.AccessControl.FileSystemRights]::FullControl
                        ) -eq
                        [System.Security.AccessControl.FileSystemRights]::FullControl
                    ) {

                        $Rule
                    }
                }
            )

            $UnsafeRules.Count |
                Should Be 0
        }
        finally {

            Remove-M3ExplicitAclRules `
                -Path $TestRoot `
                -Sid $DestinationSid

            Remove-ProfMigTestRoot `
                -Path $TestRoot
        }
    }
}
