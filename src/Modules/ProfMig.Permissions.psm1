Set-StrictMode -Version Latest

function Write-ProfMigPermissionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'SUCCESS', 'WARNING', 'ERROR')]
        [string]$Level,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    $writeLog = Get-Command `
        -Name 'Write-Log' `
        -CommandType Function `
        -ErrorAction SilentlyContinue

    if ($null -ne $writeLog) {
        try {
            Write-Log -Level $Level -Message $Message
        }
        catch {
            # Logging must never block permission handling.
        }
    }
}

function Get-ProfMigUserSid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UserName
    )

    try {
        $account = [System.Security.Principal.NTAccount]::new($UserName)
        $sid = $account.Translate(
            [System.Security.Principal.SecurityIdentifier]
        )

        [PSCustomObject]@{
            UserName = $UserName
            Sid      = $sid.Value
            Success  = $true
            Error    = $null
        }
    }
    catch {
        [PSCustomObject]@{
            UserName = $UserName
            Sid      = $null
            Success  = $false
            Error    = $_.Exception.Message
        }
    }
}

function Get-ProfMigProfileSid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    try {
        $normalizedPath = [System.IO.Path]::GetFullPath(
            $ProfilePath
        ).TrimEnd('\')

        $profile = Get-CimInstance `
            -ClassName Win32_UserProfile `
            -ErrorAction Stop |
            Where-Object {
                $_.LocalPath -and
                $_.LocalPath.TrimEnd('\') -ieq $normalizedPath
            } |
            Select-Object -First 1

        if ($null -eq $profile) {
            return [PSCustomObject]@{
                ProfilePath = $normalizedPath
                Sid         = $null
                Registered  = $false
                Success     = $false
                Error       = "No registered Windows profile found for '$normalizedPath'."
            }
        }

        [PSCustomObject]@{
            ProfilePath = $normalizedPath
            Sid         = $profile.SID
            Registered  = $true
            Success     = $true
            Error       = $null
        }
    }
    catch {
        [PSCustomObject]@{
            ProfilePath = $ProfilePath
            Sid         = $null
            Registered  = $false
            Success     = $false
            Error       = $_.Exception.Message
        }
    }
}

function Get-ProfMigAclInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $item = Get-Item `
            -LiteralPath $Path `
            -Force `
            -ErrorAction Stop

        $acl = Get-Acl `
            -LiteralPath $item.FullName `
            -ErrorAction Stop

        $accessRules = @(
            foreach ($rule in $acl.Access) {
                [PSCustomObject]@{
                    IdentityReference = $rule.IdentityReference.Value
                    FileSystemRights  = $rule.FileSystemRights.ToString()
                    AccessControlType = $rule.AccessControlType.ToString()
                    IsInherited       = $rule.IsInherited
                    InheritanceFlags  = $rule.InheritanceFlags.ToString()
                    PropagationFlags  = $rule.PropagationFlags.ToString()
                }
            }
        )

        [PSCustomObject]@{
            Path                    = $item.FullName
            ItemType                = if ($item.PSIsContainer) { 'Directory' } else { 'File' }
            Owner                   = $acl.Owner
            InheritanceEnabled      = -not $acl.AreAccessRulesProtected
            AreAccessRulesProtected = $acl.AreAccessRulesProtected
            AccessRuleCount         = $accessRules.Count
            Access                  = $accessRules
            Success                 = $true
            Error                   = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Path                    = $Path
            ItemType                = $null
            Owner                   = $null
            InheritanceEnabled      = $null
            AreAccessRulesProtected = $null
            AccessRuleCount         = 0
            Access                  = @()
            Success                 = $false
            Error                   = $_.Exception.Message
        }
    }
}

function Test-ProfMigAcl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationSid,

        [Parameter()]
        [string]$SourceSid
    )

    $aclInfo = Get-ProfMigAclInfo -Path $Path

    if (-not $aclInfo.Success) {
        return [PSCustomObject]@{
            Path                   = $Path
            Valid                  = $false
            DestinationUserAccess  = $false
            SourceSidPresent       = $false
            InheritanceEnabled     = $null
            SystemAccessPresent    = $false
            AdministratorsPresent  = $false
            RemediationRequired    = $false
            Findings               = @('ACL-READ-FAILED')
            Error                  = $aclInfo.Error
        }
    }

    $findings = [System.Collections.Generic.List[string]]::new()

    $destinationUserAccess = $false
    $sourceSidPresent      = $false
    $systemAccessPresent   = $false
    $administratorsPresent = $false

    foreach ($rule in $aclInfo.Access) {
        $identity = $rule.IdentityReference

        try {
            $account = [System.Security.Principal.NTAccount]::new($identity)
            $ruleSid = $account.Translate(
                [System.Security.Principal.SecurityIdentifier]
            ).Value
        }
        catch {
            # IdentityReference can already be a SID, including orphaned SIDs.
            $ruleSid = $identity
        }

        if (
            $ruleSid -eq $DestinationSid -and
            $rule.AccessControlType -eq 'Allow'
        ) {
            $destinationUserAccess = $true
        }

        if ($SourceSid -and $ruleSid -eq $SourceSid) {
            $sourceSidPresent = $true
        }

        if (
            $ruleSid -eq 'S-1-5-18' -and
            $rule.AccessControlType -eq 'Allow'
        ) {
            $systemAccessPresent = $true
        }

        if (
            $ruleSid -eq 'S-1-5-32-544' -and
            $rule.AccessControlType -eq 'Allow'
        ) {
            $administratorsPresent = $true
        }
    }

    if (-not $destinationUserAccess) {
        $findings.Add('ACL-DESTINATION-NO-ACCESS')
    }

    if ($sourceSidPresent) {
        $findings.Add('ACL-SOURCE-SID-PRESENT')
    }

    if (-not $aclInfo.InheritanceEnabled) {
        $findings.Add('ACL-INHERITANCE-DISABLED')
    }

    if (-not $systemAccessPresent) {
        $findings.Add('ACL-SYSTEM-MISSING')
    }

    if (-not $administratorsPresent) {
        $findings.Add('ACL-ADMINISTRATORS-MISSING')
    }

    $remediationRequired = (
        -not $destinationUserAccess -or
        -not $systemAccessPresent -or
        -not $administratorsPresent
    )

    [PSCustomObject]@{
        Path                   = $aclInfo.Path
        Valid                  = (-not $remediationRequired)
        DestinationUserAccess  = $destinationUserAccess
        SourceSidPresent       = $sourceSidPresent
        InheritanceEnabled     = $aclInfo.InheritanceEnabled
        SystemAccessPresent    = $systemAccessPresent
        AdministratorsPresent  = $administratorsPresent
        RemediationRequired    = $remediationRequired
        Findings               = @($findings)
        Error                  = $null
    }
}

function Test-ProfMigParentAcl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationSid
    )

    try {
        $item = Get-Item `
            -LiteralPath $Path `
            -Force `
            -ErrorAction Stop

        $parentPath = if ($item.PSIsContainer) {
            $item.Parent.FullName
        }
        else {
            $item.Directory.FullName
        }

        if (-not $parentPath) {
            return [PSCustomObject]@{
                Path                  = $Path
                ParentPath            = $null
                ParentFound           = $false
                DestinationUserAccess = $false
                InheritanceSuitable   = $false
                Success               = $false
                ParentValidation      = $null
                Error                 = 'Unable to determine parent path.'
            }
        }

        $parentValidation = Test-ProfMigAcl `
            -Path $parentPath `
            -DestinationSid $DestinationSid

        [PSCustomObject]@{
            Path                  = $item.FullName
            ParentPath            = $parentPath
            ParentFound           = $true
            DestinationUserAccess = $parentValidation.DestinationUserAccess
            InheritanceSuitable   = (
                $parentValidation.DestinationUserAccess -and
                $parentValidation.SystemAccessPresent -and
                $parentValidation.AdministratorsPresent
            )
            Success               = (-not $parentValidation.Error)
            ParentValidation      = $parentValidation
            Error                 = $parentValidation.Error
        }
    }
    catch {
        [PSCustomObject]@{
            Path                  = $Path
            ParentPath            = $null
            ParentFound           = $false
            DestinationUserAccess = $false
            InheritanceSuitable   = $false
            Success               = $false
            ParentValidation      = $null
            Error                 = $_.Exception.Message
        }
    }
}

function Repair-ProfMigDestinationPermissions {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationSid,

        [Parameter()]
        [string]$SourceSid,

        [Parameter()]
        [switch]$AllowInheritanceRepair
    )

    $before = Test-ProfMigAcl `
        -Path $Path `
        -DestinationSid $DestinationSid `
        -SourceSid $SourceSid

    $logMessage = (
        "ACL validation: Path='{0}'; DestinationSid='{1}'; SourceSid='{2}'; " +
        "Valid={3}; DestinationAccess={4}; InheritanceEnabled={5}; Findings='{6}'"
    ) -f `
        $Path,
        $DestinationSid,
        $SourceSid,
        $before.Valid,
        $before.DestinationUserAccess,
        $before.InheritanceEnabled,
        ($before.Findings -join ',')

    Write-ProfMigPermissionLog -Level 'INFO' -Message $logMessage

    if ($before.Error) {
        $logMessage = (
            "ACL validation failed: Path='{0}'; DestinationSid='{1}'; Error='{2}'."
        ) -f $Path, $DestinationSid, $before.Error

        Write-ProfMigPermissionLog -Level 'ERROR' -Message $logMessage

        return [PSCustomObject]@{
            Path             = $Path
            Changed          = $false
            Action           = @()
            Success          = $false
            Strategy         = 'None'
            ValidationBefore = $before
            ValidationAfter  = $null
            ParentValidation = $null
            Error            = $before.Error
        }
    }

    if ($before.DestinationUserAccess) {
        $logMessage = (
            "ACL validation successful: Path='{0}'; Strategy='ExistingPermissions'; No permission changes required."
        ) -f $Path

        Write-ProfMigPermissionLog -Level 'SUCCESS' -Message $logMessage

        return [PSCustomObject]@{
            Path             = $Path
            Changed          = $false
            Action           = @('None')
            Success          = $true
            Strategy         = 'ExistingPermissions'
            ValidationBefore = $before
            ValidationAfter  = $before
            ParentValidation = $null
            Error            = $null
        }
    }

    $actions = [System.Collections.Generic.List[string]]::new()
    $parentValidation = $null

    try {
        $parentValidation = Test-ProfMigParentAcl `
            -Path $Path `
            -DestinationSid $DestinationSid

        if (
            $AllowInheritanceRepair -and
            $parentValidation.Success -and
            $parentValidation.InheritanceSuitable
        ) {
            $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop

            if ($acl.AreAccessRulesProtected) {
                if ($PSCmdlet.ShouldProcess(
                    $Path,
                    'Restore NTFS inheritance from destination parent'
                )) {
                    $acl.SetAccessRuleProtection($false, $true)

                    Set-Acl `
                        -LiteralPath $Path `
                        -AclObject $acl `
                        -ErrorAction Stop

                    $actions.Add('EnableInheritance')

                    $logMessage = (
                        "ACL security change: Path='{0}'; Action='EnableInheritance'; " +
                        "Strategy='DestinationInheritance'; DestinationSid='{1}'."
                    ) -f $Path, $DestinationSid

                    Write-ProfMigPermissionLog -Level 'INFO' -Message $logMessage
                }

                $afterInheritance = Test-ProfMigAcl `
                    -Path $Path `
                    -DestinationSid $DestinationSid `
                    -SourceSid $SourceSid

                if ($afterInheritance.DestinationUserAccess) {
                    $logMessage = (
                        "ACL repair successful: Path='{0}'; Strategy='DestinationInheritance'; Destination access restored."
                    ) -f $Path

                    Write-ProfMigPermissionLog -Level 'SUCCESS' -Message $logMessage

                    return [PSCustomObject]@{
                        Path             = $Path
                        Changed          = ($actions.Count -gt 0)
                        Action           = @($actions)
                        Success          = $true
                        Strategy         = 'DestinationInheritance'
                        ValidationBefore = $before
                        ValidationAfter  = $afterInheritance
                        ParentValidation = $parentValidation
                        Error            = $null
                    }
                }
            }
        }

        $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
        $sid = [System.Security.Principal.SecurityIdentifier]::new($DestinationSid)
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop

        if ($item.PSIsContainer) {
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid,
                [System.Security.AccessControl.FileSystemRights]::Modify,
                (
                    [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
                    [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
                ),
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
        }
        else {
            $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid,
                [System.Security.AccessControl.FileSystemRights]::Modify,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
        }

        if ($PSCmdlet.ShouldProcess(
            $Path,
            "Grant Modify to destination SID $DestinationSid"
        )) {
            $acl.AddAccessRule($rule)

            Set-Acl `
                -LiteralPath $Path `
                -AclObject $acl `
                -ErrorAction Stop

            $actions.Add('GrantDestinationModify')

            $logMessage = (
                "ACL security change: Path='{0}'; Action='GrantDestinationModify'; " +
                "Strategy='ExplicitDestinationAccess'; DestinationSid='{1}'; Rights='Modify'."
            ) -f $Path, $DestinationSid

            Write-ProfMigPermissionLog -Level 'WARNING' -Message $logMessage
        }

        $after = Test-ProfMigAcl `
            -Path $Path `
            -DestinationSid $DestinationSid `
            -SourceSid $SourceSid

        if ($after.DestinationUserAccess) {
            $logMessage = (
                "ACL repair successful: Path='{0}'; Strategy='ExplicitDestinationAccess'; Destination access restored."
            ) -f $Path

            Write-ProfMigPermissionLog -Level 'SUCCESS' -Message $logMessage
        }
        else {
            $logMessage = (
                "ACL repair failed validation: Path='{0}'; DestinationSid='{1}'; Findings='{2}'."
            ) -f $Path, $DestinationSid, ($after.Findings -join ',')

            Write-ProfMigPermissionLog -Level 'ERROR' -Message $logMessage
        }

        [PSCustomObject]@{
            Path             = $Path
            Changed          = ($actions.Count -gt 0)
            Action           = @($actions)
            Success          = $after.DestinationUserAccess
            Strategy         = 'ExplicitDestinationAccess'
            ValidationBefore = $before
            ValidationAfter  = $after
            ParentValidation = $parentValidation
            Error            = $null
        }
    }
    catch {
        $logMessage = (
            "ACL repair failed: Path='{0}'; DestinationSid='{1}'; Error='{2}'."
        ) -f $Path, $DestinationSid, $_.Exception.Message

        Write-ProfMigPermissionLog -Level 'ERROR' -Message $logMessage

        [PSCustomObject]@{
            Path             = $Path
            Changed          = $false
            Action           = @($actions)
            Success          = $false
            Strategy         = 'Failed'
            ValidationBefore = $before
            ValidationAfter  = $null
            ParentValidation = $parentValidation
            Error            = $_.Exception.Message
        }
    }
}

Export-ModuleMember -Function @(
    'Get-ProfMigUserSid'
    'Get-ProfMigProfileSid'
    'Get-ProfMigAclInfo'
    'Test-ProfMigAcl'
    'Test-ProfMigParentAcl'
    'Repair-ProfMigDestinationPermissions'
)
