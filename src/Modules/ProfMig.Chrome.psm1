<#
.SYNOPSIS
    Google Chrome migration support for ProfMig.

.DESCRIPTION
    Provides detection, inventory, planning, validation and controlled
    migration of supported Google Chrome profile data.

    ProfMig deliberately does not migrate Chrome credentials,
    authentication sessions, cookies, payment information, encryption
    material or other protected browser data.

.NOTES
    ProfMig - Professional Windows Profile Migration Toolkit
    Sprint 2.3 - Google Chrome Migration
#>

Set-StrictMode -Version Latest


function Get-ProfMigChromeUserDataPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    return (Join-Path $ProfilePath 'AppData\Local\Google\Chrome\User Data')
}


function Get-ProfMigChromeProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $userDataPath = Get-ProfMigChromeUserDataPath -ProfilePath $ProfilePath

    if (-not (Test-Path -LiteralPath $userDataPath)) {
        return @()
    }

    $localStatePath = Join-Path $userDataPath 'Local State'
    $localState = $null

    if (Test-Path -LiteralPath $localStatePath) {
        try {
            $localState = Get-Content -LiteralPath $localStatePath -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {
                Write-WarningLog "Unable to read Chrome Local State: $($_.Exception.Message)"
            }
        }
    }

    $profileDirectories = @(
        Get-ChildItem -LiteralPath $userDataPath -Directory -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq 'Default' -or
                $_.Name -match '^Profile \d+$'
            }
    )

    $profiles = foreach ($directory in $profileDirectories) {

        $displayName = $directory.Name
        $userName = $null

        if (
            $null -ne $localState -and
            $null -ne $localState.profile -and
            $null -ne $localState.profile.info_cache
        ) {

            $profileProperty =
                $localState.profile.info_cache.PSObject.Properties[$directory.Name]

            if ($null -ne $profileProperty) {

                if ($profileProperty.Value.name) {
                    $displayName = $profileProperty.Value.name
                }

                if ($profileProperty.Value.user_name) {
                    $userName = $profileProperty.Value.user_name
                }
            }
        }

        [PSCustomObject]@{
            ProfileName = $directory.Name
            DisplayName = $displayName
            UserName    = $userName
            ProfilePath = $directory.FullName
            IsDefault   = ($directory.Name -eq 'Default')
        }
    }

    return @($profiles)
}


function Test-ProfMigChromeRunning {
    [CmdletBinding()]
    param()

    return [bool](Get-Process -Name 'chrome' -ErrorAction SilentlyContinue)
}


function Get-ProfMigChromeDetection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $userDataPath = Get-ProfMigChromeUserDataPath -ProfilePath $ProfilePath

    $profiles = @(
        Get-ProfMigChromeProfiles -ProfilePath $ProfilePath
    )

    return [PSCustomObject]@{
        Browser      = 'Google Chrome'
        Detected     = (Test-Path -LiteralPath $userDataPath)
        UserDataPath = $userDataPath
        ProfileCount = $profiles.Count
        Profiles     = $profiles
        IsRunning    = Test-ProfMigChromeRunning
    }
}


function Get-ProfMigChromeExtensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ChromeProfilePath
    )

    if (-not (Test-Path -LiteralPath $ChromeProfilePath)) {
        throw "Chrome profile path does not exist: $ChromeProfilePath"
    }

    $extensionsPath = Join-Path $ChromeProfilePath 'Extensions'

    if (-not (Test-Path -LiteralPath $extensionsPath)) {
        return @()
    }

    $extensions = @()

    foreach (
        $extensionDirectory in
        Get-ChildItem -LiteralPath $extensionsPath -Directory -ErrorAction SilentlyContinue
    ) {

        $extensionId = $extensionDirectory.Name
        $versions = @()

        foreach (
            $versionDirectory in
            Get-ChildItem -LiteralPath $extensionDirectory.FullName -Directory -ErrorAction SilentlyContinue
        ) {

            $manifestPath = Join-Path $versionDirectory.FullName 'manifest.json'

            if (-not (Test-Path -LiteralPath $manifestPath)) {
                continue
            }

            try {
                $manifest =
                    Get-Content -LiteralPath $manifestPath -Raw -ErrorAction Stop |
                    ConvertFrom-Json -ErrorAction Stop

                $name = $manifest.name

                #
                # Chrome Web Store extensions can use localized names such as:
                # __MSG_extensionName__
                #
                if ($name -match '^__MSG_(.+)__$') {

                    $messageKey = $Matches[1]
                    $localesPath = Join-Path $versionDirectory.FullName '_locales'

                    if (Test-Path -LiteralPath $localesPath) {

                        foreach ($locale in @('en', 'en_US', 'en_GB', 'nl')) {

                            $messagesPath =
                                Join-Path $localesPath "$locale\messages.json"

                            if (-not (Test-Path -LiteralPath $messagesPath)) {
                                continue
                            }

                            try {
                                $messages =
                                    Get-Content -LiteralPath $messagesPath -Raw -ErrorAction Stop |
                                    ConvertFrom-Json -ErrorAction Stop

                                $messageProperty =
                                    $messages.PSObject.Properties[$messageKey]

                                if (
                                    $null -ne $messageProperty -and
                                    $messageProperty.Value.message
                                ) {
                                    $name = $messageProperty.Value.message
                                    break
                                }
                            }
                            catch {
                                # Locale resolution is optional.
                            }
                        }
                    }
                }

                $versions += [PSCustomObject]@{
                    Name          = $name
                    Version       = [string]$manifest.version
                    ManifestPath  = $manifestPath
                    ExtensionPath = $versionDirectory.FullName
                }
            }
            catch {
                if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {
                    Write-WarningLog (
                        "Unable to read Chrome extension manifest: $manifestPath"
                    )
                }
            }
        }

        if ($versions.Count -eq 0) {
            continue
        }

        #
        # Chrome can keep multiple versions of an extension on disk.
        # Select the highest version for inventory purposes.
        #
        $sortedVersions = @(
            $versions |
                Sort-Object -Property @{
                    Expression = {
                        try {
                            [version]$_.Version
                        }
                        catch {
                            [version]'0.0'
                        }
                    }
                } -Descending
        )

        $current = $sortedVersions[0]

        $extensions += [PSCustomObject]@{
            ExtensionId       = $extensionId
            Name              = $current.Name
            Version           = $current.Version
            InstalledVersions = $versions.Count
            ManifestPath      = $current.ManifestPath
            ExtensionPath     = $current.ExtensionPath
            MigrationStatus   = 'InventoryOnly'
        }
    }

    return @($extensions)
}


function Get-ProfMigChromeProfileData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ChromeProfilePath
    )

    if (-not (Test-Path -LiteralPath $ChromeProfilePath)) {
        throw "Chrome profile path does not exist: $ChromeProfilePath"
    }

    #
    # Explicit allowlist.
    #
    # Only data explicitly classified as portable is eligible
    # for migration.
    #
    $includeRules = @(
        [PSCustomObject]@{
            Name   = 'Bookmarks'
            Type   = 'File'
            Reason = 'Portable Chrome bookmarks'
        }

        [PSCustomObject]@{
            Name   = 'Bookmarks.bak'
            Type   = 'File'
            Reason = 'Chrome bookmark backup'
        }

        [PSCustomObject]@{
            Name   = 'Preferences'
            Type   = 'File'
            Reason = 'Portable browser profile preferences'
        }

        [PSCustomObject]@{
            Name   = 'History'
            Type   = 'File'
            Reason = 'Browser history'
        }

        [PSCustomObject]@{
            Name   = 'Favicons'
            Type   = 'File'
            Reason = 'Favicons associated with bookmarks and history'
        }

        [PSCustomObject]@{
            Name   = 'Shortcuts'
            Type   = 'File'
            Reason = 'Chrome navigation shortcuts'
        }

        [PSCustomObject]@{
            Name   = 'Top Sites'
            Type   = 'File'
            Reason = 'Chrome frequently visited site information'
        }
    )

    #
    # Explicit denylist.
    #
    # These items may contain credentials, authentication material,
    # encrypted information, account state, certificates or sessions.
    #
    $excludeRules = @(
        [PSCustomObject]@{
            Name   = 'Login Data'
            Reason = 'Contains protected saved credentials'
        }

        [PSCustomObject]@{
            Name   = 'Login Data For Account'
            Reason = 'Contains protected account credentials'
        }

        [PSCustomObject]@{
            Name   = 'Network'
            Reason = 'May contain cookies and authentication/session state'
        }

        [PSCustomObject]@{
            Name   = 'Extension Cookies'
            Reason = 'Contains extension cookie/session data'
        }

        [PSCustomObject]@{
            Name   = 'Sessions'
            Reason = 'Contains active browser session information'
        }

        [PSCustomObject]@{
            Name   = 'Session Storage'
            Reason = 'Contains website session state'
        }

        [PSCustomObject]@{
            Name   = 'Web Data'
            Reason = 'May contain autofill and payment-related information'
        }

        [PSCustomObject]@{
            Name   = 'Account Web Data'
            Reason = 'Contains Google account-specific browser data'
        }

        [PSCustomObject]@{
            Name   = 'Accounts'
            Reason = 'Contains Google account state'
        }

        [PSCustomObject]@{
            Name   = 'Sync Data'
            Reason = 'Contains Google synchronization state'
        }

        [PSCustomObject]@{
            Name   = 'GCM Store'
            Reason = 'Contains Google messaging/account state'
        }

        [PSCustomObject]@{
            Name   = 'ClientCertificates'
            Reason = 'Contains client certificate-related security data'
        }

        [PSCustomObject]@{
            Name   = 'passkey_enclave_state'
            Reason = 'Contains passkey-related security state'
        }

        [PSCustomObject]@{
            Name   = 'trusted_vault.pb'
            Reason = 'Contains trusted vault/security state'
        }

        [PSCustomObject]@{
            Name   = 'EncryptedBookmarks'
            Reason = 'Encrypted Chrome data is not migrated'
        }

        [PSCustomObject]@{
            Name   = 'Secure Preferences'
            Reason = 'Security/integrity-sensitive Chrome preferences'
        }

        [PSCustomObject]@{
            Name   = 'Managed Extension Settings'
            Reason = 'Managed settings should be recreated through policy'
        }

        [PSCustomObject]@{
            Name   = 'Extensions'
            Reason = 'Extension packages are inventoried but not migrated'
        }

        [PSCustomObject]@{
            Name   = 'Local Extension Settings'
            Reason = 'Extension state may contain sensitive or account-bound data'
        }
    )

    $included = @()

    foreach ($rule in $includeRules) {

        $itemPath = Join-Path $ChromeProfilePath $rule.Name

        if (Test-Path -LiteralPath $itemPath) {

            $item =
                Get-Item -LiteralPath $itemPath -Force -ErrorAction SilentlyContinue

            $included += [PSCustomObject]@{
                Name   = $rule.Name
                Path   = $itemPath
                Type   = $rule.Type
                Exists = $true
                Size   = if ($item -and -not $item.PSIsContainer) {
                    $item.Length
                }
                else {
                    $null
                }
                Status = 'Include'
                Reason = $rule.Reason
            }
        }
    }

    $excluded = @()

    foreach ($rule in $excludeRules) {

        $itemPath = Join-Path $ChromeProfilePath $rule.Name

        if (Test-Path -LiteralPath $itemPath) {

            $excluded += [PSCustomObject]@{
                Name   = $rule.Name
                Path   = $itemPath
                Status = 'Excluded'
                Reason = $rule.Reason
            }
        }

        #
        # Detect associated SQLite database files as protected as well.
        #
        foreach ($suffix in @('-journal', '-wal', '-shm')) {

            $associatedName = "$($rule.Name)$suffix"
            $associatedPath = Join-Path $ChromeProfilePath $associatedName

            if (Test-Path -LiteralPath $associatedPath) {

                $excluded += [PSCustomObject]@{
                    Name   = $associatedName
                    Path   = $associatedPath
                    Status = 'Excluded'
                    Reason = "Associated protected database file for $($rule.Name)"
                }
            }
        }
    }

    return [PSCustomObject]@{
        ProfilePath   = $ChromeProfilePath
        IncludedCount = $included.Count
        ExcludedCount = $excluded.Count
        Included      = @($included)
        Excluded      = @($excluded)
    }
}


function Get-ProfMigChromeMigrationPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $sourceUserDataPath =
        Get-ProfMigChromeUserDataPath -ProfilePath $SourceProfile

    $destinationUserDataPath =
        Get-ProfMigChromeUserDataPath -ProfilePath $DestinationProfile

    if (-not (Test-Path -LiteralPath $sourceUserDataPath)) {

        return [PSCustomObject]@{
            Browser                 = 'Google Chrome'
            Detected                = $false
            SourceProfile           = $SourceProfile
            DestinationProfile      = $DestinationProfile
            SourceUserDataPath      = $sourceUserDataPath
            DestinationUserDataPath = $destinationUserDataPath
            ProfileCount            = 0
            Profiles                = @()
            FilesSelected           = 0
            ExtensionsDetected      = 0
        }
    }

    $chromeProfiles = @(
        Get-ProfMigChromeProfiles -ProfilePath $SourceProfile
    )

    $profilePlans = @()
    $totalFilesSelected = 0
    $totalExtensions = 0

    foreach ($chromeProfile in $chromeProfiles) {

        $profileData =
            Get-ProfMigChromeProfileData `
                -ChromeProfilePath $chromeProfile.ProfilePath

        $extensions = @(
            Get-ProfMigChromeExtensions `
                -ChromeProfilePath $chromeProfile.ProfilePath
        )

        $destinationChromeProfilePath =
            Join-Path $destinationUserDataPath $chromeProfile.ProfileName

        $migrationItems = @()

        foreach ($item in $profileData.Included) {

            $destinationPath =
                Join-Path $destinationChromeProfilePath $item.Name

            $migrationItems += [PSCustomObject]@{
                Name            = $item.Name
                Type            = $item.Type
                SourcePath      = $item.Path
                DestinationPath = $destinationPath
                Size            = $item.Size
                Action          = 'Migrate'
                Reason          = $item.Reason
            }
        }

        $totalFilesSelected += $migrationItems.Count
        $totalExtensions += $extensions.Count

        $profilePlans += [PSCustomObject]@{
            ProfileName     = $chromeProfile.ProfileName
            DisplayName     = $chromeProfile.DisplayName
            UserName        = $chromeProfile.UserName
            IsDefault       = $chromeProfile.IsDefault

            SourcePath      = $chromeProfile.ProfilePath
            DestinationPath = $destinationChromeProfilePath

            MigrationItems  = @($migrationItems)
            MigrationCount  = $migrationItems.Count

            ExcludedItems   = @($profileData.Excluded)
            ExcludedCount   = $profileData.ExcludedCount

            Extensions      = @($extensions)
            ExtensionCount  = $extensions.Count
        }
    }

    return [PSCustomObject]@{
        Browser                 = 'Google Chrome'
        Detected                = $true

        SourceProfile           = $SourceProfile
        DestinationProfile      = $DestinationProfile

        SourceUserDataPath      = $sourceUserDataPath
        DestinationUserDataPath = $destinationUserDataPath

        ProfileCount            = $profilePlans.Count
        Profiles                = @($profilePlans)

        FilesSelected           = $totalFilesSelected
        ExtensionsDetected      = $totalExtensions
    }
}


function Test-ProfMigChromeMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $validationResults = @()

    #
    # Validate source Windows profile.
    #
    $sourceExists = Test-Path -LiteralPath $SourceProfile

    $validationResults += [PSCustomObject]@{
        Test     = 'SourceProfileExists'
        Success  = $sourceExists
        Severity = if ($sourceExists) { 'Info' } else { 'Error' }
        Message  = if ($sourceExists) {
            "Source profile exists: $SourceProfile"
        }
        else {
            "Source profile does not exist: $SourceProfile"
        }
    }

    if (-not $sourceExists) {
        return @($validationResults)
    }

    #
    # Detect Chrome source data.
    #
    $detection =
        Get-ProfMigChromeDetection -ProfilePath $SourceProfile

    $validationResults += [PSCustomObject]@{
        Test     = 'ChromeDetected'
        Success  = $detection.Detected
        Severity = if ($detection.Detected) { 'Info' } else { 'Error' }
        Message  = if ($detection.Detected) {
            "Google Chrome data detected with $($detection.ProfileCount) profile(s)."
        }
        else {
            'Google Chrome user data was not detected.'
        }
    }

    if (-not $detection.Detected) {
        return @($validationResults)
    }

    #
    # Chrome must be closed before copying mutable profile databases.
    #
    $chromeRunning = Test-ProfMigChromeRunning

    $validationResults += [PSCustomObject]@{
        Test     = 'ChromeNotRunning'
        Success  = (-not $chromeRunning)
        Severity = if ($chromeRunning) { 'Error' } else { 'Info' }
        Message  = if ($chromeRunning) {
            'Google Chrome is running. Close Chrome before migration.'
        }
        else {
            'Google Chrome is not running.'
        }
    }

    #
    # Source and destination must not be the same Windows profile.
    #
    $sameProfile =
        $SourceProfile.TrimEnd('\') -ieq
        $DestinationProfile.TrimEnd('\')

    $validationResults += [PSCustomObject]@{
        Test     = 'DifferentProfiles'
        Success  = (-not $sameProfile)
        Severity = if ($sameProfile) { 'Error' } else { 'Info' }
        Message  = if ($sameProfile) {
            'Source and destination profiles are identical.'
        }
        else {
            'Source and destination profiles are different.'
        }
    }

    #
    # Build and inspect the migration plan.
    #
    $plan =
        Get-ProfMigChromeMigrationPlan `
            -SourceProfile $SourceProfile `
            -DestinationProfile $DestinationProfile

    $hasMigrationItems = $plan.FilesSelected -gt 0

    $validationResults += [PSCustomObject]@{
        Test     = 'MigrationItemsAvailable'
        Success  = $hasMigrationItems
        Severity = if ($hasMigrationItems) { 'Info' } else { 'Warning' }
        Message  = if ($hasMigrationItems) {
            "$($plan.FilesSelected) supported Chrome item(s) selected for migration."
        }
        else {
            'No supported Chrome items were found for migration.'
        }
    }

    #
    # Existing destination Chrome data must not be overwritten.
    #
    $destinationConflicts = @(
        foreach ($profile in $plan.Profiles) {

            foreach ($item in $profile.MigrationItems) {

                if (Test-Path -LiteralPath $item.DestinationPath) {

                    [PSCustomObject]@{
                        Profile         = $profile.ProfileName
                        Item            = $item.Name
                        DestinationPath = $item.DestinationPath
                    }
                }
            }
        }
    )

    $noDestinationConflicts = ($destinationConflicts.Count -eq 0)

    $validationResults += [PSCustomObject]@{
        Test     = 'DestinationChromeDataAvailable'
        Success  = $noDestinationConflicts
        Severity = if ($noDestinationConflicts) { 'Info' } else { 'Error' }
        Message  = if ($noDestinationConflicts) {
            'No existing destination Chrome data conflicts with the migration plan.'
        }
        else {
            "$($destinationConflicts.Count) existing destination Chrome item(s) would be overwritten."
        }
    }

    #
    # Defense-in-depth:
    # protected names must never occur in the migration plan.
    #
    $protectedPattern =
        'Login|Cookie|Session|Web Data|Account|passkey|vault|Secure'

    $protectedItems = @(
        $plan.Profiles.MigrationItems |
            Where-Object {
                $_.Name -match $protectedPattern
            }
    )

    $validationResults += [PSCustomObject]@{
        Test     = 'ProtectedDataExcluded'
        Success  = ($protectedItems.Count -eq 0)
        Severity = if ($protectedItems.Count -eq 0) { 'Info' } else { 'Error' }
        Message  = if ($protectedItems.Count -eq 0) {
            'No protected Chrome data is present in the migration plan.'
        }
        else {
            "$($protectedItems.Count) protected Chrome item(s) were found in the migration plan."
        }
    }

    #
    # Extensions must remain inventory-only.
    #
    $extensionMigrationItems = @(
        $plan.Profiles.MigrationItems |
            Where-Object {
                $_.Name -match 'Extension'
            }
    )

    $validationResults += [PSCustomObject]@{
        Test     = 'ExtensionsInventoryOnly'
        Success  = ($extensionMigrationItems.Count -eq 0)
        Severity = if ($extensionMigrationItems.Count -eq 0) { 'Info' } else { 'Error' }
        Message  = if ($extensionMigrationItems.Count -eq 0) {
            "$($plan.ExtensionsDetected) extension(s) inventoried; extension data is not selected for migration."
        }
        else {
            "$($extensionMigrationItems.Count) extension-related item(s) were incorrectly selected for migration."
        }
    }

    return @($validationResults)
}

function Update-ProfMigChromeProfileRegistration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$DestinationProfile,

        [Parameter(Mandatory)]
        [object[]]$Profiles
    )

    $userDataPath = Get-ProfMigChromeUserDataPath `
        -ProfilePath $DestinationProfile

    if (-not (Test-Path -LiteralPath $userDataPath)) {
        New-Item `
            -ItemType Directory `
            -Path $userDataPath `
            -Force | Out-Null
    }

    $localStatePath = Join-Path $userDataPath 'Local State'

    #
    # Use the destination Local State when Chrome has already created one.
    # Never copy the source Local State because it can contain account-bound
    # and security-sensitive state.
    #
    if (Test-Path -LiteralPath $localStatePath) {
        try {
            $localState = Get-Content `
                -LiteralPath $localStatePath `
                -Raw `
                -ErrorAction Stop |
                ConvertFrom-Json
        }
        catch {
            throw "Unable to read destination Chrome Local State: $($_.Exception.Message)"
        }
    }
    else {
        $localState = [PSCustomObject]@{}
    }

    if (-not $localState.PSObject.Properties['profile']) {
        $localState |
            Add-Member `
                -MemberType NoteProperty `
                -Name profile `
                -Value ([PSCustomObject]@{})
    }

    if (-not $localState.profile.PSObject.Properties['info_cache']) {
        $localState.profile |
            Add-Member `
                -MemberType NoteProperty `
                -Name info_cache `
                -Value ([PSCustomObject]@{})
    }

    foreach ($chromeProfile in $Profiles) {

        $profileName = $chromeProfile.ProfileName
        $displayName = $chromeProfile.DisplayName

        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $displayName = $profileName
        }

        #
        # Create only neutral profile-registration metadata.
        # Do not migrate Google account identifiers, authentication state,
        # credentials or encryption information from the source Local State.
        #
        $profileRegistration = [PSCustomObject]@{
            avatar_icon                       = 'chrome://theme/IDR_PROFILE_AVATAR_26'
            background_apps                   = $false
            force_signin_profile_locked       = $false
            gaia_id                           = ''
            is_consented_primary_account      = $false
            is_ephemeral                      = $false
            is_using_default_avatar           = $true
            is_using_default_name             = $false
            managed_user_id                   = ''
            name                              = $displayName
            shortcut_name                     = $displayName
            'signin.with_credential_provider' = $false
            user_name                         = ''
        }

        $existingProperty =
            $localState.profile.info_cache.PSObject.Properties[$profileName]

        if ($null -ne $existingProperty) {
            $existingProperty.Value = $profileRegistration
        }
        else {
            $localState.profile.info_cache |
                Add-Member `
                    -MemberType NoteProperty `
                    -Name $profileName `
                    -Value $profileRegistration
        }
    }

    try {
        $json = $localState |
            ConvertTo-Json -Depth 100 -Compress

        [System.IO.File]::WriteAllText(
            $localStatePath,
            $json,
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    catch {
        throw "Unable to update destination Chrome Local State: $($_.Exception.Message)"
    }

    if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
        Write-Info (
            "Registered {0} migrated Chrome profile(s) in destination Local State." `
                -f $Profiles.Count
        )
    }

    return [PSCustomObject]@{
        Success        = $true
        LocalStatePath = $localStatePath
        ProfilesAdded  = $Profiles.Count
    }
}

function Invoke-ProfMigChromeMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
        Write-Info 'Starting Google Chrome migration.'
        Write-Info "Source profile: $SourceProfile"
        Write-Info "Destination profile: $DestinationProfile"
    }

    #
    # Run all Chrome preflight checks.
    #
    $validationResults = @(
        Test-ProfMigChromeMigration `
            -SourceProfile $SourceProfile `
            -DestinationProfile $DestinationProfile
    )

    $blockingErrors = @(
        $validationResults |
            Where-Object {
                $_.Severity -eq 'Error' -and
                -not $_.Success
            }
    )

    if ($blockingErrors.Count -gt 0) {

        foreach ($blockingError in $blockingErrors) {
            if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
                Write-ErrorLog "Chrome migration blocked: $($blockingError.Message)"
            }
        }

        return [PSCustomObject]@{
            Component          = 'Google Chrome'
            Success            = $false
            Status             = 'Blocked'
            SourceProfile      = $SourceProfile
            DestinationProfile = $DestinationProfile
            ProfileCount       = 0
            FilesSelected      = 0
            FilesCopied        = 0
            FilesFailed        = 0
            BytesCopied        = 0
            ExtensionsDetected = 0
            Validation         = @($validationResults)
            Results            = @()
            Components         = @()
            Errors             = @($blockingErrors.Message)
        }
    }

    $plan =
        Get-ProfMigChromeMigrationPlan `
            -SourceProfile $SourceProfile `
            -DestinationProfile $DestinationProfile

    $results = @()
    $errors = @()

    foreach ($chromeProfile in $plan.Profiles) {

        if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
            Write-Info (
                "Processing Chrome profile: " +
                "$($chromeProfile.ProfileName) [$($chromeProfile.DisplayName)]"
            )
        }

        foreach ($item in $chromeProfile.MigrationItems) {

            try {
                #
                # Create the Chrome profile directory only when
                # an approved item actually needs to be migrated.
                #
                if (-not (Test-Path -LiteralPath $chromeProfile.DestinationPath)) {
                    New-Item `
                        -ItemType Directory `
                        -Path $chromeProfile.DestinationPath `
                        -Force `
                        -ErrorAction Stop |
                        Out-Null
                }

                if (Get-Command Invoke-ProfMigComponentCopy -ErrorAction SilentlyContinue) {

                    $componentResult =
                        Invoke-ProfMigComponentCopy `
                            -SourcePath $item.SourcePath `
                            -DestinationPath $item.DestinationPath `
                            -Component "Chrome-$($chromeProfile.ProfileName)-$($item.Name)"

                    $results += $componentResult

                    if ($componentResult.Errors.Count -gt 0) {
                        $errors += $componentResult.Errors
                    }

                    if ($componentResult.FilesCopied -gt 0) {
                        if (Get-Command Write-Success -ErrorAction SilentlyContinue) {
                            Write-Success (
                                "Chrome item migrated: " +
                                "$($chromeProfile.ProfileName)\$($item.Name)"
                            )
                        }
                    }
                }
                else {
                    throw 'Invoke-ProfMigComponentCopy is not available.'
                }
            }
            catch {
                $errorMessage =
                    "Failed to migrate Chrome item " +
                    "$($chromeProfile.ProfileName)\$($item.Name): " +
                    "$($_.Exception.Message)"

                $errors += $errorMessage

                if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
                    Write-ErrorLog $errorMessage
                }
            }
        }

        foreach ($excludedItem in $chromeProfile.ExcludedItems) {
            if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
                Write-Info (
                    "Chrome item excluded: " +
                    "$($chromeProfile.ProfileName)\$($excludedItem.Name) - " +
                    "$($excludedItem.Reason)"
                )
            }
        }

        foreach ($extension in $chromeProfile.Extensions) {
            if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
                Write-Info (
                    "Chrome extension inventory only: " +
                    "$($chromeProfile.ProfileName) - " +
                    "$($extension.Name) [$($extension.ExtensionId)] " +
                    "version $($extension.Version)"
                )
            }
        }
    }

    #
    # Register migrated Chrome profiles in the destination Local State.
    #
    # Only neutral profile metadata is written. Source Local State,
    # Google account identifiers and authentication state are not migrated.
    #
    try {
        $registrationResult =
            Update-ProfMigChromeProfileRegistration `
                -DestinationProfile $DestinationProfile `
                -Profiles $plan.Profiles

        if (-not $registrationResult.Success) {
            throw 'Chrome profile registration did not complete successfully.'
        }

        if (Get-Command Write-Success -ErrorAction SilentlyContinue) {
            Write-Success (
                "Registered $($registrationResult.ProfilesAdded) " +
                "Chrome profile(s) in destination Local State."
            )
        }
    }
    catch {
        $registrationError =
            "Failed to register migrated Chrome profiles: " +
            "$($_.Exception.Message)"

        $errors += $registrationError

        if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
            Write-ErrorLog $registrationError
        }
    }

    $filesSelected = 0
    $filesCopied = 0
    $filesFailed = 0
    $bytesCopied = 0

    foreach ($result in $results) {
        $filesSelected += $result.FilesSelected
        $filesCopied += $result.FilesCopied
        $filesFailed += $result.FilesFailed
        $bytesCopied += $result.BytesCopied
    }

    $success = ($errors.Count -eq 0)

    if ($success) {
        if (Get-Command Write-Success -ErrorAction SilentlyContinue) {
            Write-Success (
                "Google Chrome migration completed. " +
                "$filesCopied file(s) copied, " +
                "$bytesCopied byte(s) transferred."
            )
        }
    }
    else {
        if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {
            Write-WarningLog (
                "Google Chrome migration completed with " +
                "$($errors.Count) error(s)."
            )
        }
    }

    return [PSCustomObject]@{
        Component          = 'Google Chrome'
        Success            = $success
        Status             = if ($success) { 'Completed' } else { 'CompletedWithErrors' }

        SourceProfile      = $SourceProfile
        DestinationProfile = $DestinationProfile

        ProfileCount       = $plan.ProfileCount
        FilesSelected      = $filesSelected
        FilesCopied        = $filesCopied
        FilesFailed        = $filesFailed
        BytesCopied        = $bytesCopied

        ExtensionsDetected = $plan.ExtensionsDetected
        ProfilesRegistered = if ($null -ne $registrationResult) {
            $registrationResult.ProfilesAdded
        }
        else {
          0
        }

        Validation         = @($validationResults)
        Results            = @($results)

        #
        # Standard ProfMig reporting contract.
        #
        Components         = @($results)
        Errors             = @($errors)
    }
}

Export-ModuleMember -Function @(
    'Get-ProfMigChromeUserDataPath',
    'Get-ProfMigChromeProfiles',
    'Test-ProfMigChromeRunning',
    'Test-ProfMigChromeMigration',
    'Invoke-ProfMigChromeMigration'
    'Get-ProfMigChromeDetection',
    'Get-ProfMigChromeExtensions',
    'Get-ProfMigChromeProfileData',
    'Get-ProfMigChromeMigrationPlan'
)