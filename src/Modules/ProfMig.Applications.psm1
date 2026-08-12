<#
.SYNOPSIS
    Application detection engine for ProfMig.

.DESCRIPTION
    Detects supported application data inside a selected Windows
    source user profile.

    Supported applications:
    - Microsoft Edge
    - Google Chrome
    - Microsoft Outlook

    Detection is read-only. No source application data is modified.
    Credentials, passwords and cookies are not read, extracted or decrypted.

.NOTES
    Part of ProfMig - Professional Windows Profile Migration Toolkit.
#>


function Write-ProfMigApplicationLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    #
    # Application detection can also be used independently.
    # Logging is therefore optional and only used when the
    # central ProfMig logging module has been loaded.
    #
    $writeLogCommand = Get-Command `
        -Name "Write-Log" `
        -CommandType Function `
        -ErrorAction SilentlyContinue

    if ($null -ne $writeLogCommand) {
        Write-Log -Level $Level -Message $Message
    }
}
function Get-ProfMigApplications {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    Write-ProfMigApplicationLog `
        -Level "INFO" `
        -Message "Starting application detection for source profile: $ProfilePath"

    try {
        $profileExists = Test-Path `
            -LiteralPath $ProfilePath `
            -PathType Container `
            -ErrorAction Stop
    }
    catch {

        Write-ProfMigApplicationLog `
            -Level "ERROR" `
            -Message "Invalid source profile path: $ProfilePath"

        throw "Invalid source profile path '$ProfilePath': $($_.Exception.Message)"
    }

    if (-not $profileExists) {

        Write-ProfMigApplicationLog `
            -Level "ERROR" `
            -Message "Source profile path does not exist: $ProfilePath"

        throw "Source profile path does not exist: $ProfilePath"
    }

    $applications = @()

    #
    # Microsoft Edge
    #
    $edge = Get-ProfMigEdge -ProfilePath $ProfilePath
    $applications += $edge

    Write-ProfMigApplicationLog `
        -Level "INFO" `
        -Message "Microsoft Edge detected: $($edge.Detected); profiles: $($edge.ProfileCount); migration available: $($edge.MigrationAvailable)"

    #
    # Google Chrome
    #
    $chrome = Get-ProfMigChrome -ProfilePath $ProfilePath
    $applications += $chrome

    Write-ProfMigApplicationLog `
        -Level "INFO" `
        -Message "Google Chrome detected: $($chrome.Detected); profiles: $($chrome.ProfileCount); migration available: $($chrome.MigrationAvailable)"

    #
    # Microsoft Outlook
    #
    $outlook = Get-ProfMigOutlook -ProfilePath $ProfilePath
    $applications += $outlook

    Write-ProfMigApplicationLog `
        -Level "INFO" `
        -Message "Microsoft Outlook detected: $($outlook.Detected); profiles: $($outlook.ProfileCount); migration available: $($outlook.MigrationAvailable)"

    if (-not $outlook.RegistryAvailable) {
        Write-ProfMigApplicationLog `
            -Level "WARNING" `
            -Message "Outlook registry profile information is unavailable for source profile: $ProfilePath"
    }

    Write-ProfMigApplicationLog `
        -Level "SUCCESS" `
        -Message "Application detection completed for source profile: $ProfilePath"

    return $applications
}

function Get-ProfMigBrowserProfileName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DirectoryName,

        [Parameter()]
        $ProfileInfoCache
    )

    $displayName = $DirectoryName

    if ($null -eq $ProfileInfoCache) {
        return $displayName
    }

    try {
        $profileProperty = $ProfileInfoCache.PSObject.Properties |
            Where-Object {
                $_.Name -eq $DirectoryName
            } |
            Select-Object -First 1

        if ($null -ne $profileProperty) {

            $profileMetadata = $profileProperty.Value

            if (-not [string]::IsNullOrWhiteSpace($profileMetadata.name)) {
                $displayName = $profileMetadata.name
            }
        }
    }
    catch {
        # Fall back to the directory name if profile metadata
        # cannot be interpreted.
    }

    return $displayName
}


function Get-ProfMigBrowserLocalState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$UserDataPath
    )

    $localStatePath = Join-Path `
        -Path $UserDataPath `
        -ChildPath "Local State"

    if (-not (Test-Path -LiteralPath $localStatePath -PathType Leaf)) {
        return $null
    }

    try {
        $localState = Get-Content `
            -LiteralPath $localStatePath `
            -Raw `
            -ErrorAction Stop |
            ConvertFrom-Json -ErrorAction Stop

        if ($null -ne $localState.profile.info_cache) {
            return $localState.profile.info_cache
        }
    }
    catch {
        return $null
    }

    return $null
}


function Get-ProfMigBrowserDetectedData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$BrowserProfilePath
    )

    $detectedData = @()

    #
    # Relevant Chromium profile files.
    # Detection only checks whether the files exist.
    # File contents are not opened or interpreted.
    #
    $relevantFiles = @(
        "Bookmarks"
        "History"
        "Preferences"
        "Favicons"
        "Login Data"
        "Web Data"
    )

    foreach ($file in $relevantFiles) {

        $candidatePath = Join-Path `
            -Path $BrowserProfilePath `
            -ChildPath $file

        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
            $detectedData += $file
        }
    }

    #
    # Modern Chromium versions store cookies under Network\Cookies.
    #
    $cookiesPath = Join-Path `
        -Path $BrowserProfilePath `
        -ChildPath "Network\Cookies"

    if (Test-Path -LiteralPath $cookiesPath -PathType Leaf) {
        $detectedData += "Cookies"
    }
    else {
        #
        # Older Chromium versions may store the Cookies database
        # directly inside the profile directory.
        #
        $legacyCookiesPath = Join-Path `
            -Path $BrowserProfilePath `
            -ChildPath "Cookies"

        if (Test-Path -LiteralPath $legacyCookiesPath -PathType Leaf) {
            $detectedData += "Cookies"
        }
    }

    return $detectedData
}


function Get-ProfMigEdge {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $edgeUserDataPath = Join-Path `
        -Path $ProfilePath `
        -ChildPath "AppData\Local\Microsoft\Edge\User Data"

    $profiles = @()
    $detectionNotes = @()

    if (-not (Test-Path -LiteralPath $edgeUserDataPath -PathType Container)) {

        $detectionNotes += "Edge user data directory not found."

        return [PSCustomObject]@{
            Application        = "Microsoft Edge"
            ApplicationId      = "Edge"
            Detected           = $false
            DataPath           = $edgeUserDataPath
            DataPaths          = @()
            ProfileCount       = 0
            Profiles           = @()
            DetectedData       = @()
            MigrationAvailable = $false
            DetectionNotes     = $detectionNotes
        }
    }

    $profileInfoCache = Get-ProfMigBrowserLocalState `
        -UserDataPath $edgeUserDataPath

    if ($null -eq $profileInfoCache) {
        $detectionNotes += "Edge Local State profile metadata was not available."
    }

    $profileDirectories = @(
        Get-ChildItem `
            -LiteralPath $edgeUserDataPath `
            -Directory `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq "Default" -or
                $_.Name -match '^Profile \d+$'
            }
    )

    foreach ($profileDirectory in $profileDirectories) {

        $detectedData = @(
            Get-ProfMigBrowserDetectedData `
                -BrowserProfilePath $profileDirectory.FullName
        )

        if ($detectedData.Count -eq 0) {
            continue
        }

        $displayName = Get-ProfMigBrowserProfileName `
            -DirectoryName $profileDirectory.Name `
            -ProfileInfoCache $profileInfoCache

        $profiles += [PSCustomObject]@{
            Name               = $displayName
            DirectoryName      = $profileDirectory.Name
            Path               = $profileDirectory.FullName
            DetectedData       = $detectedData
            MigrationAvailable = $true
        }
    }

    $detected = $profiles.Count -gt 0
    $migrationAvailable = $profiles.Count -gt 0

    if (-not $detected) {
        $detectionNotes += "Edge directory exists, but no supported browser profiles containing relevant data were detected."
    }

    return [PSCustomObject]@{
        Application        = "Microsoft Edge"
        ApplicationId      = "Edge"
        Detected           = $detected
        DataPath           = $edgeUserDataPath
        DataPaths          = @($edgeUserDataPath)
        ProfileCount       = $profiles.Count
        Profiles           = $profiles
        DetectedData       = @()
        MigrationAvailable = $migrationAvailable
        DetectionNotes     = $detectionNotes
    }
}


function Get-ProfMigChrome {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $chromeUserDataPath = Join-Path `
        -Path $ProfilePath `
        -ChildPath "AppData\Local\Google\Chrome\User Data"

    $profiles = @()
    $detectionNotes = @()

    if (-not (Test-Path -LiteralPath $chromeUserDataPath -PathType Container)) {

        $detectionNotes += "Chrome user data directory not found."

        return [PSCustomObject]@{
            Application        = "Google Chrome"
            ApplicationId      = "Chrome"
            Detected           = $false
            DataPath           = $chromeUserDataPath
            DataPaths          = @()
            ProfileCount       = 0
            Profiles           = @()
            DetectedData       = @()
            MigrationAvailable = $false
            DetectionNotes     = $detectionNotes
        }
    }

    $profileInfoCache = Get-ProfMigBrowserLocalState `
        -UserDataPath $chromeUserDataPath

    if ($null -eq $profileInfoCache) {
        $detectionNotes += "Chrome Local State profile metadata was not available."
    }

    $profileDirectories = @(
        Get-ChildItem `
            -LiteralPath $chromeUserDataPath `
            -Directory `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -eq "Default" -or
                $_.Name -match '^Profile \d+$'
            }
    )

    foreach ($profileDirectory in $profileDirectories) {

        $detectedData = @(
            Get-ProfMigBrowserDetectedData `
                -BrowserProfilePath $profileDirectory.FullName
        )

        if ($detectedData.Count -eq 0) {
            continue
        }

        $displayName = Get-ProfMigBrowserProfileName `
            -DirectoryName $profileDirectory.Name `
            -ProfileInfoCache $profileInfoCache

        $profiles += [PSCustomObject]@{
            Name               = $displayName
            DirectoryName      = $profileDirectory.Name
            Path               = $profileDirectory.FullName
            DetectedData       = $detectedData
            MigrationAvailable = $true
        }
    }

    $detected = $profiles.Count -gt 0
    $migrationAvailable = $profiles.Count -gt 0

    if (-not $detected) {
        $detectionNotes += "Chrome directory exists, but no supported browser profiles containing relevant data were detected."
    }

    return [PSCustomObject]@{
        Application        = "Google Chrome"
        ApplicationId      = "Chrome"
        Detected           = $detected
        DataPath           = $chromeUserDataPath
        DataPaths          = @($chromeUserDataPath)
        ProfileCount       = $profiles.Count
        Profiles           = $profiles
        DetectedData       = @()
        MigrationAvailable = $migrationAvailable
        DetectionNotes     = $detectionNotes
    }
}

function Get-ProfMigOutlookProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $result = [PSCustomObject]@{
        RegistryAvailable = $false
        SID               = $null
        Profiles          = @()
        DetectionNotes    = @()
    }

    try {
        $userProfile = Get-CimInstance Win32_UserProfile -ErrorAction Stop |
            Where-Object {
                $_.LocalPath -eq $ProfilePath
            } |
            Select-Object -First 1
    }
    catch {
        $result.DetectionNotes += "Windows user profile information could not be queried."
        return $result
    }

    if ($null -eq $userProfile) {
        $result.DetectionNotes += "Windows user profile could not be matched to the selected source path."
        return $result
    }

    $result.SID = $userProfile.SID

    #
    # Do not load NTUSER.DAT during detection.
    # Outlook registry information is inspected only when the
    # selected source user's registry hive is already loaded.
    #
    if (-not $userProfile.Loaded) {
        $result.DetectionNotes += "Outlook registry hive is not currently loaded."
        return $result
    }

    $result.RegistryAvailable = $true

    $officeVersions = @(
        "16.0"
        "15.0"
        "14.0"
    )

    foreach ($version in $officeVersions) {

        $registryPath = "Registry::HKEY_USERS\$($userProfile.SID)\Software\Microsoft\Office\$version\Outlook\Profiles"

        if (-not (Test-Path -LiteralPath $registryPath)) {
            continue
        }

        $registryProfiles = @(
            Get-ChildItem `
                -LiteralPath $registryPath `
                -ErrorAction SilentlyContinue
        )

        foreach ($registryProfile in $registryProfiles) {

            $result.Profiles += [PSCustomObject]@{
                Name          = $registryProfile.PSChildName
                OfficeVersion = $version
                RegistryPath  = $registryProfile.Name
            }
        }
    }

    if ($result.Profiles.Count -eq 0) {
        $result.DetectionNotes += "No Outlook registry profiles were detected."
    }

    return $result
}
function Get-ProfMigOutlook {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $localOutlookPath = Join-Path `
        -Path $ProfilePath `
        -ChildPath "AppData\Local\Microsoft\Outlook"

    $roamingOutlookPath = Join-Path `
        -Path $ProfilePath `
        -ChildPath "AppData\Roaming\Microsoft\Outlook"

    $documentsOutlookPath = Join-Path `
        -Path $ProfilePath `
        -ChildPath "Documents\Outlook Files"

    $roamCachePath = Join-Path `
        -Path $localOutlookPath `
        -ChildPath "RoamCache"

    $detectedData = @()
    $dataPaths = @()
    $detectionNotes = @()
    $outlookProfileInfo = Get-ProfMigOutlookProfiles `
        -ProfilePath $ProfilePath

    foreach  ($note in $outlookProfileInfo.DetectionNotes) {
    $detectionNotes += $note
    }


    #
    # Local Outlook mailbox data.
    #
    if (Test-Path -LiteralPath $localOutlookPath -PathType Container) {

        $dataPaths += $localOutlookPath

        $ostFiles = @(
            Get-ChildItem `
                -LiteralPath $localOutlookPath `
                -Filter "*.ost" `
                -File `
                -ErrorAction SilentlyContinue
        )

        $pstFiles = @(
            Get-ChildItem `
                -LiteralPath $localOutlookPath `
                -Filter "*.pst" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $ostFiles) {

            #
            # OST files are mailbox caches and should normally be rebuilt
            # by Outlook instead of copied to a new Windows profile.
            #
            $detectedData += [PSCustomObject]@{
                Type               = "OST"
                Name               = $file.Name
                Path               = $file.FullName
                SizeBytes          = $file.Length
                MigrationAvailable = $false
            }
        }

        foreach ($file in $pstFiles) {

            $detectedData += [PSCustomObject]@{
                Type               = "PST"
                Name               = $file.Name
                Path               = $file.FullName
                SizeBytes          = $file.Length
                MigrationAvailable = $true
            }
        }
    }

    #
    # Outlook AutoComplete cache.
    #
    if (Test-Path -LiteralPath $roamCachePath -PathType Container) {

        if ($dataPaths -notcontains $roamCachePath) {
            $dataPaths += $roamCachePath
        }

        $autoCompleteFiles = @(
            Get-ChildItem `
                -LiteralPath $roamCachePath `
                -Filter "Stream_Autocomplete_*.dat" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $autoCompleteFiles) {

            $detectedData += [PSCustomObject]@{
                Type               = "AutoComplete"
                Name               = $file.Name
                Path               = $file.FullName
                SizeBytes          = $file.Length
                MigrationAvailable = $true
            }
        }
    }

    #
    # Outlook roaming settings.
    #
    if (Test-Path -LiteralPath $roamingOutlookPath -PathType Container) {

        if ($dataPaths -notcontains $roamingOutlookPath) {
            $dataPaths += $roamingOutlookPath
        }

        $settingsDefinitions = @(
            @{
                File = "Outlook.srs"
                Type = "SendReceiveSettings"
            },
            @{
                File = "Outlook.xml"
                Type = "OutlookSettings"
            },
            @{
                File = "OutlPrnt"
                Type = "PrintSettings"
            }
        )

        foreach ($definition in $settingsDefinitions) {

            $settingsPath = Join-Path `
                -Path $roamingOutlookPath `
                -ChildPath $definition.File

            if (Test-Path -LiteralPath $settingsPath -PathType Leaf) {

                $file = Get-Item `
                    -LiteralPath $settingsPath `
                    -ErrorAction SilentlyContinue

                if ($null -ne $file) {

                    $detectedData += [PSCustomObject]@{
                        Type               = $definition.Type
                        Name               = $file.Name
                        Path               = $file.FullName
                        SizeBytes          = $file.Length
                        MigrationAvailable = $true
                    }
                }
            }
        }
    }

    #
    # PST files stored in the standard Outlook Files directory.
    #
    if (Test-Path -LiteralPath $documentsOutlookPath -PathType Container) {

        if ($dataPaths -notcontains $documentsOutlookPath) {
            $dataPaths += $documentsOutlookPath
        }

        $documentPstFiles = @(
            Get-ChildItem `
                -LiteralPath $documentsOutlookPath `
                -Filter "*.pst" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $documentPstFiles) {

            $detectedData += [PSCustomObject]@{
                Type               = "PST"
                Name               = $file.Name
                Path               = $file.FullName
                SizeBytes          = $file.Length
                MigrationAvailable = $true
            }
        }
    }

    $detected = (
    $detectedData.Count -gt 0 -or
    $outlookProfileInfo.Profiles.Count -gt 0
)

    $migrationAvailable = @(
        $detectedData |
            Where-Object {
                $_.MigrationAvailable -eq $true
            }
    ).Count -gt 0

    if (-not $detected) {
        $detectionNotes += "No supported Outlook user data was detected."
    }

    if ($detected -and -not $migrationAvailable) {
        $detectionNotes += "Outlook data was detected, but no directly migratable data was found."
    }

    #
    # Outlook profile registry detection will be implemented separately.
    # ProfileCount therefore remains 0 until the selected source user's
    # Outlook registry profile can be determined safely.
    #
    return [PSCustomObject]@{
        Application        = "Microsoft Outlook"
        ApplicationId      = "Outlook"
        Detected           = $detected
        DataPath           = $localOutlookPath
        DataPaths          = $dataPaths
        ProfileCount       = $outlookProfileInfo.Profiles.Count
        Profiles           = $outlookProfileInfo.Profiles
        RegistryAvailable  = $outlookProfileInfo.RegistryAvailable
        SID                = $outlookProfileInfo.SID
        DetectedData       = $detectedData
        MigrationAvailable = $migrationAvailable
        DetectionNotes     = $detectionNotes
    }
}


Export-ModuleMember -Function Get-ProfMigApplications