<#
.SYNOPSIS
    Windows profile and privilege validation helpers for ProfMig.

.DESCRIPTION
    Provides non-destructive discovery and validation of Windows user profiles,
    profile identity, local profile paths, administrator context and profile
    registry access.

    The module does not assume that a profile folder name equals the username.
    Profile identity is determined primarily from Win32_UserProfile, the
    ProfileList registry key and the profile SID.

.NOTES
    Module  : ProfMig.ProfileValidation.psm1
    Project : ProfMig
    Sprint  : 3.2 - Profile & Privilege Validation
#>

Set-StrictMode -Version Latest

$script:ProfMigProfileValidationResultType = 'ProfMig.ProfileValidationResult'
$script:ProfileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'


# ============================================================================
# Internal helpers
# ============================================================================

function New-ProfMigProfileValidationResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Check,

        [Parameter(Mandatory)]
        [ValidateSet('Passed', 'Warning', 'Failed')]
        [string]$Status,

        [Parameter(Mandatory)]
        [ValidateSet('Information', 'Warning', 'Critical')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [object]$Details = $null
    )

    return [PSCustomObject]@{
        PSTypeName = $script:ProfMigProfileValidationResultType
        Check      = $Check
        Status     = $Status
        Severity   = $Severity
        Message    = $Message
        Details    = $Details
        Timestamp  = Get-Date
    }
}


function Get-ProfMigCanonicalPath {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    $fullPath = [System.IO.Path]::GetFullPath($expandedPath)

    return $fullPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
}


function Resolve-ProfMigSidToAccountName {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SID
    )

    try {
        $sidObject = New-Object System.Security.Principal.SecurityIdentifier($SID)

        $account = $sidObject.Translate(
            [System.Security.Principal.NTAccount]
        )

        return $account.Value
    }
    catch {
        return $null
    }
}


function Get-ProfMigAccountType {

    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [string]$QualifiedName
    )

    if ([string]::IsNullOrWhiteSpace($QualifiedName)) {
        return 'Unknown'
    }

    $parts = $QualifiedName -split '\\', 2

    if ($parts.Count -lt 2) {
        return 'Unknown'
    }

    $authority = $parts[0]

    if ($authority -ieq 'AzureAD') {
        return 'EntraID'
    }

    if ($authority -ieq 'MicrosoftAccount') {
        return 'MicrosoftAccount'
    }

    if (
        $authority -ieq $env:COMPUTERNAME -or
        $authority -eq '.'
    ) {
        return 'Local'
    }

    return 'Domain'
}


function Get-ProfMigProfileListRegistration {

    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [string]$Path,

        [Parameter()]
        [AllowNull()]
        [string]$SID
    )

    if (-not (Test-Path -LiteralPath $script:ProfileListPath)) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($SID)) {

        $sidPath = Join-Path -Path $script:ProfileListPath -ChildPath $SID

        if (Test-Path -LiteralPath $sidPath) {

            try {
                $item = Get-ItemProperty -LiteralPath $sidPath -ErrorAction Stop

                return [PSCustomObject]@{
                    SID              = $SID
                    RegistryPath     = $sidPath
                    ProfileImagePath = $item.ProfileImagePath
                }
            }
            catch {
                return $null
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    try {
        $targetPath = Get-ProfMigCanonicalPath -Path $Path

        foreach ($key in Get-ChildItem -LiteralPath $script:ProfileListPath -ErrorAction Stop) {

            try {
                $item = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction Stop

                if ([string]::IsNullOrWhiteSpace($item.ProfileImagePath)) {
                    continue
                }

                $registeredPath = Get-ProfMigCanonicalPath -Path $item.ProfileImagePath

                if ($registeredPath -ieq $targetPath) {

                    return [PSCustomObject]@{
                        SID              = $key.PSChildName
                        RegistryPath     = $key.PSPath
                        ProfileImagePath = $item.ProfileImagePath
                    }
                }
            }
            catch {
                continue
            }
        }
    }
    catch {
        return $null
    }

    return $null
}


# ============================================================================
# Profile discovery and identity
# ============================================================================

function Get-ProfMigWindowsProfile {
    <#
    .SYNOPSIS
        Returns Windows user profile registrations from Win32_UserProfile.

    .DESCRIPTION
        If Path is supplied, only the profile whose LocalPath matches the
        canonical path is returned.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [string]$Path
    )

    try {
        $profiles = @(
            Get-CimInstance `
                -ClassName Win32_UserProfile `
                -ErrorAction Stop
        )
    }
    catch {
        throw "Unable to query Win32_UserProfile: $($_.Exception.Message)"
    }

    $targetPath = $null

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $targetPath = Get-ProfMigCanonicalPath -Path $Path
    }

    $results = @(
        foreach ($profile in $profiles) {

            if ([string]::IsNullOrWhiteSpace($profile.LocalPath)) {
                continue
            }

            try {
                $localPath = Get-ProfMigCanonicalPath -Path $profile.LocalPath
            }
            catch {
                continue
            }

            if (
                $null -ne $targetPath -and
                $localPath -ine $targetPath
            ) {
                continue
            }

            [PSCustomObject]@{
                PSTypeName = 'ProfMig.WindowsProfile'
                SID        = [string]$profile.SID
                LocalPath  = $localPath
                Loaded     = [bool]$profile.Loaded
                Special    = [bool]$profile.Special
                Status     = $profile.Status
            }
        }
    )

    return $results
}


function Get-ProfMigProfileIdentity {
    <#
    .SYNOPSIS
        Resolves a Windows profile path to its SID and account identity.

    .DESCRIPTION
        Win32_UserProfile is used first. ProfileList is used as a fallback.
        The SID is translated to an NTAccount when Windows can resolve it.

        Folder names are never treated as usernames.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $canonicalPath = Get-ProfMigCanonicalPath -Path $Path

    $windowsProfile = $null
    $identitySource = $null
    $sid = $null

    try {
        $windowsProfile = @(
            Get-ProfMigWindowsProfile -Path $canonicalPath
        ) | Select-Object -First 1
    }
    catch {
        $windowsProfile = $null
    }

    if ($null -ne $windowsProfile) {
        $sid = $windowsProfile.SID
        $identitySource = 'Win32_UserProfile'
    }

    $registration = Get-ProfMigProfileListRegistration `
        -Path $canonicalPath `
        -SID $sid

    if (
        [string]::IsNullOrWhiteSpace($sid) -and
        $null -ne $registration
    ) {
        $sid = $registration.SID
        $identitySource = 'ProfileList'
    }

    $qualifiedName = $null

    if (-not [string]::IsNullOrWhiteSpace($sid)) {
        $qualifiedName = Resolve-ProfMigSidToAccountName -SID $sid
    }

    $accountName = $null

    if (-not [string]::IsNullOrWhiteSpace($qualifiedName)) {
        $nameParts = $qualifiedName -split '\\', 2

        if ($nameParts.Count -eq 2) {
            $accountName = $nameParts[1]
        }
        else {
            $accountName = $qualifiedName
        }
    }

    $accountType = Get-ProfMigAccountType -QualifiedName $qualifiedName

    if (
        -not [string]::IsNullOrWhiteSpace($sid) -and
        -not [string]::IsNullOrWhiteSpace($qualifiedName)
    ) {
        $confidence = 'High'
    }
    elseif (-not [string]::IsNullOrWhiteSpace($sid)) {
        $confidence = 'Medium'
    }
    else {
        $confidence = 'Low'
    }

    return [PSCustomObject]@{
        PSTypeName       = 'ProfMig.ProfileIdentity'
        ProfilePath      = $canonicalPath
        SID              = $sid
        AccountName      = $accountName
        QualifiedName    = $qualifiedName
        AccountType      = $accountType
        IdentitySource   = $identitySource
        Confidence       = $confidence
        Registered       = ($null -ne $registration)
        RegistryPath     = if ($null -ne $registration) { $registration.RegistryPath } else { $null }
        ProfileImagePath = if ($null -ne $registration) { $registration.ProfileImagePath } else { $null }
        Loaded           = if ($null -ne $windowsProfile) { $windowsProfile.Loaded } else { $null }
        Special          = if ($null -ne $windowsProfile) { $windowsProfile.Special } else { $null }
    }
}


# ============================================================================
# Profile path and structure validation
# ============================================================================

function Test-ProfMigProfilePath {
    <#
    .SYNOPSIS
        Validates that a profile path is a local filesystem path.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateSet('Source', 'Destination')]
        [string]$Role = 'Source'
    )

    try {
        $canonicalPath = Get-ProfMigCanonicalPath -Path $Path

        if (-not [System.IO.Path]::IsPathRooted($canonicalPath)) {
            throw 'Profile path is not rooted.'
        }

        if ($canonicalPath.StartsWith('\\')) {

            return New-ProfMigProfileValidationResult `
                -Check "${Role}ProfilePath" `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "$Role profile path must be local. UNC paths are not supported." `
                -Details @{
                    Path = $canonicalPath
                    Role = $Role
                }
        }

        $root = [System.IO.Path]::GetPathRoot($canonicalPath)

        if ([string]::IsNullOrWhiteSpace($root)) {
            throw 'Unable to determine the local drive root.'
        }

        $driveName = $root.TrimEnd('\').TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue

        if (
            $null -eq $drive -or
            $drive.Provider.Name -ne 'FileSystem'
        ) {

            return New-ProfMigProfileValidationResult `
                -Check "${Role}ProfilePath" `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "$Role profile path does not resolve to an available local filesystem drive." `
                -Details @{
                    Path      = $canonicalPath
                    DriveRoot = $root
                    Role      = $Role
                }
        }

        return New-ProfMigProfileValidationResult `
            -Check "${Role}ProfilePath" `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message "$Role profile path is a valid local filesystem path." `
            -Details @{
                Path      = $canonicalPath
                DriveRoot = $root
                Role      = $Role
            }
    }
    catch {

        return New-ProfMigProfileValidationResult `
            -Check "${Role}ProfilePath" `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to validate $($Role.ToLower()) profile path: $($_.Exception.Message)" `
            -Details @{
                Path = $Path
                Role = $Role
            }
    }
}


function Test-ProfMigProfileStructure {
    <#
    .SYNOPSIS
        Checks expected Windows profile structure without modifying it.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if ($Path.StartsWith('\\')) {

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileStructure' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message 'Profile structure cannot be validated for a UNC path because ProfMig only supports local Windows profiles.' `
            -Details @{
                Path = $Path
            }
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container -ErrorAction SilentlyContinue)) {

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileStructure' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message 'Profile structure cannot be validated because the profile directory does not exist.' `
            -Details @{
                Path = $Path
            }
    }

    $canonicalPath = Get-ProfMigCanonicalPath -Path $Path
    $ntUserPath = Join-Path -Path $canonicalPath -ChildPath 'NTUSER.DAT'
    $appDataPath = Join-Path -Path $canonicalPath -ChildPath 'AppData'

    $hasNtUserDat = Test-Path -LiteralPath $ntUserPath -PathType Leaf -ErrorAction SilentlyContinue
    $hasAppData = Test-Path -LiteralPath $appDataPath -PathType Container -ErrorAction SilentlyContinue

    $identity = $null

    try {
        $identity = Get-ProfMigProfileIdentity -Path $canonicalPath
    }
    catch {
        $identity = $null
    }

    $registered = (
        $null -ne $identity -and
        $identity.Registered
    )

    if (
        -not $registered -and
        -not $hasNtUserDat -and
        -not $hasAppData
    ) {

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileStructure' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message 'The source does not contain expected Windows profile structure and is not registered as a Windows profile.' `
            -Details @{
                Path        = $canonicalPath
                NTUSER_DAT  = $hasNtUserDat
                AppData     = $hasAppData
                Registered  = $registered
            }
    }

    if (-not $registered) {

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileStructure' `
            -Status 'Warning' `
            -Severity 'Warning' `
            -Message 'Windows profile structure was detected, but the profile could not be confirmed in ProfileList.' `
            -Details @{
                Path        = $canonicalPath
                NTUSER_DAT  = $hasNtUserDat
                AppData     = $hasAppData
                Registered  = $registered
            }
    }

    return New-ProfMigProfileValidationResult `
        -Check 'ProfileStructure' `
        -Status 'Passed' `
        -Severity 'Critical' `
        -Message 'Expected Windows profile structure was detected.' `
        -Details @{
            Path        = $canonicalPath
            NTUSER_DAT  = $hasNtUserDat
            AppData     = $hasAppData
            Registered  = $registered
            SID         = $identity.SID
            AccountType = $identity.AccountType
        }
}


function Test-ProfMigProfileRegistration {
    <#
    .SYNOPSIS
        Confirms that a profile path is registered to a Windows profile SID.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $identity = Get-ProfMigProfileIdentity -Path $Path

        if (
            -not $identity.Registered -or
            [string]::IsNullOrWhiteSpace($identity.SID)
        ) {

            return New-ProfMigProfileValidationResult `
                -Check 'ProfileRegistration' `
                -Status 'Warning' `
                -Severity 'Warning' `
                -Message 'Profile path could not be confirmed against Windows profile registration.' `
                -Details $identity
        }

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileRegistration' `
            -Status 'Passed' `
            -Severity 'Information' `
            -Message 'Profile path is registered to a Windows profile SID.' `
            -Details $identity
    }
    catch {

        return New-ProfMigProfileValidationResult `
            -Check 'ProfileRegistration' `
            -Status 'Warning' `
            -Severity 'Warning' `
            -Message "Unable to confirm Windows profile registration: $($_.Exception.Message)"
    }
}


# ============================================================================
# Privilege and registry validation
# ============================================================================

function Test-ProfMigAdministrator {
    <#
    .SYNOPSIS
        Determines whether the current PowerShell process is elevated.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$Required = $true
    )

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)

        $isAdministrator = $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )

        if ($isAdministrator) {

            return New-ProfMigProfileValidationResult `
                -Check 'AdministratorContext' `
                -Status 'Passed' `
                -Severity $(if ($Required) { 'Critical' } else { 'Information' }) `
                -Message 'PowerShell is running with an elevated administrator token.' `
                -Details @{
                    IsElevated = $true
                    Identity   = $identity.Name
                    SID        = $identity.User.Value
                    Required   = [bool]$Required
                }
        }

        if ($Required) {

            return New-ProfMigProfileValidationResult `
                -Check 'AdministratorContext' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message 'PowerShell is not running with an elevated administrator token.' `
                -Details @{
                    IsElevated = $false
                    Identity   = $identity.Name
                    SID        = $identity.User.Value
                    Required   = $true
                }
        }

        return New-ProfMigProfileValidationResult `
            -Check 'AdministratorContext' `
            -Status 'Warning' `
            -Severity 'Warning' `
            -Message 'PowerShell is not elevated, but administrator privileges are not required for this validation.' `
            -Details @{
                IsElevated = $false
                Identity   = $identity.Name
                SID        = $identity.User.Value
                Required   = $false
            }
    }
    catch {

        return New-ProfMigProfileValidationResult `
            -Check 'AdministratorContext' `
            -Status 'Failed' `
            -Severity $(if ($Required) { 'Critical' } else { 'Warning' }) `
            -Message "Unable to determine administrator context: $($_.Exception.Message)"
    }
}


function Test-ProfMigRegistryAccess {
    <#
    .SYNOPSIS
        Validates read access to required Windows profile registry locations.

    .DESCRIPTION
        The function is read-only and never loads or modifies a user hive.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [string]$SID
    )

    try {
        if ([string]::IsNullOrWhiteSpace($SID)) {
            return New-ProfMigProfileValidationResult `
                -Check 'RegistryAccess' `
                -Status 'Warning' `
                -Severity 'Warning' `
                -Message 'ProfileList registry access was not tested for a specific user because no profile SID was supplied.' `
                -Details @{
                    ProfileListPath = $script:ProfileListPath
                    SID             = $SID
                    ProfileListRead = $null
                    ProfileKeyRead  = $null
                    UserHiveLoaded  = $null
                    UserHiveRead    = $null
                }
        }

        if (-not (Test-Path -LiteralPath $script:ProfileListPath)) {
            throw "Required registry path is unavailable: $script:ProfileListPath"
        }

        $null = Get-ChildItem `
            -LiteralPath $script:ProfileListPath `
            -ErrorAction Stop |
            Select-Object -First 1

        $details = @{
            ProfileListPath = $script:ProfileListPath
            SID             = $SID
            ProfileListRead = $true
            UserHiveLoaded  = $null
            UserHiveRead    = $null
        }

        if (-not [string]::IsNullOrWhiteSpace($SID)) {

            $profileKey = Join-Path -Path $script:ProfileListPath -ChildPath $SID

            if (Test-Path -LiteralPath $profileKey) {
                $null = Get-ItemProperty -LiteralPath $profileKey -ErrorAction Stop
                $details['ProfileKeyRead'] = $true
            }
            else {
                $details['ProfileKeyRead'] = $false
            }

            $hkuPath = "Registry::HKEY_USERS\$SID"
            $hiveLoaded = Test-Path -LiteralPath $hkuPath
            $details['UserHiveLoaded'] = $hiveLoaded

            if ($hiveLoaded) {
                $null = Get-Item -LiteralPath $hkuPath -ErrorAction Stop
                $details['UserHiveRead'] = $true
            }
        }

        return New-ProfMigProfileValidationResult `
            -Check 'RegistryAccess' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'Required Windows profile registry locations are readable.' `
            -Details $details
    }
    catch {

        return New-ProfMigProfileValidationResult `
            -Check 'RegistryAccess' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Required Windows profile registry locations are not accessible: $($_.Exception.Message)" `
            -Details @{
                ProfileListPath = $script:ProfileListPath
                SID             = $SID
            }
    }
}


# ============================================================================
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'Get-ProfMigWindowsProfile',
    'Get-ProfMigProfileIdentity',
    'Test-ProfMigProfilePath',
    'Test-ProfMigProfileStructure',
    'Test-ProfMigProfileRegistration',
    'Test-ProfMigAdministrator',
    'Test-ProfMigRegistryAccess'
)
