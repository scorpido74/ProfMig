<#
.SYNOPSIS
    Microsoft Edge migration support for ProfMig.

.DESCRIPTION
    Detects Microsoft Edge user profiles and safely migrates approved,
    portable Edge user data between Windows profiles.

    Security-sensitive or user-bound data is explicitly excluded.
    ProfMig does not decrypt credentials, bypass DPAPI or migrate
    authentication/session state.

    File operations are performed through the ProfMig Copy Engine.

.NOTES
    Project : ProfMig
    Module  : ProfMig.Edge
    Sprint  : 2.2 - Microsoft Edge Migration
#>

Set-StrictMode -Version Latest


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeUserDataPath
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeUserDataPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $edgeUserDataPath = Join-Path `
        $ProfilePath `
        'AppData\Local\Microsoft\Edge\User Data'

    if (Test-Path -LiteralPath $edgeUserDataPath -PathType Container) {
        return $edgeUserDataPath
    }

    return $null
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeProfiles
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $userDataPath = Get-ProfMigEdgeUserDataPath `
        -ProfilePath $ProfilePath

    if (-not $userDataPath) {
        return @()
    }

    $profiles = @(
        Get-ChildItem `
            -LiteralPath $userDataPath `
            -Directory `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -eq 'Default' -or
            $_.Name -match '^Profile \d+$'
        }
    )

    foreach ($profile in $profiles) {

        $preferencesPath = Join-Path `
            $profile.FullName `
            'Preferences'

        [PSCustomObject]@{
            Browser         = 'Microsoft Edge'
            ProfileName     = $profile.Name
            ProfilePath     = $profile.FullName
            PreferencesPath = $preferencesPath
            HasPreferences  = Test-Path -LiteralPath $preferencesPath
        }
    }
}


# ---------------------------------------------------------------------------
# Public function: Test-ProfMigEdgeRunning
# ---------------------------------------------------------------------------

function Test-ProfMigEdgeRunning {
    [CmdletBinding()]
    param ()

    $process = Get-Process `
        -Name 'msedge' `
        -ErrorAction SilentlyContinue

    return ($null -ne $process)
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeDetection
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeDetection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $userDataPath = Get-ProfMigEdgeUserDataPath `
        -ProfilePath $ProfilePath

    if (-not $userDataPath) {

        return [PSCustomObject]@{
            Browser      = 'Microsoft Edge'
            Detected     = $false
            UserDataPath = $null
            IsRunning    = Test-ProfMigEdgeRunning
            Profiles     = @()
            ProfileCount = 0
        }
    }

    $profiles = @(
        Get-ProfMigEdgeProfiles `
            -ProfilePath $ProfilePath
    )

    return [PSCustomObject]@{
        Browser      = 'Microsoft Edge'
        Detected     = $true
        UserDataPath = $userDataPath
        IsRunning    = Test-ProfMigEdgeRunning
        Profiles     = $profiles
        ProfileCount = $profiles.Count
    }
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeProfileData
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeProfileData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$EdgeProfilePath
    )

    if (-not (Test-Path -LiteralPath $EdgeProfilePath -PathType Container)) {
        return @()
    }

    $dataDefinitions = @(

        @{
            Name     = 'Bookmarks'
            Path     = 'Bookmarks'
            Category = 'Portable'
            Migrate  = $true
            Reason   = 'Edge favorites/bookmarks'
        }

        @{
            Name     = 'Bookmarks Backup'
            Path     = 'Bookmarks.bak'
            Category = 'Portable'
            Migrate  = $true
            Reason   = 'Backup of Edge favorites/bookmarks'
        }

        @{
            Name     = 'Preferences'
            Path     = 'Preferences'
            Category = 'Review'
            Migrate  = $false
            Reason   = 'Contains profile settings that require validation before migration'
        }

        @{
            Name     = 'History'
            Path     = 'History'
            Category = 'Review'
            Migrate  = $false
            Reason   = 'SQLite browser history database; migration requires validation'
        }

        @{
            Name     = 'Favicons'
            Path     = 'Favicons'
            Category = 'Portable'
            Migrate  = $true
            Reason   = 'Website favicon database'
        }

        @{
            Name     = 'Extensions'
            Path     = 'Extensions'
            Category = 'Review'
            Migrate  = $false
            Reason   = 'Extension files require validation before migration'
        }

        @{
            Name     = 'Login Data'
            Path     = 'Login Data'
            Category = 'Sensitive'
            Migrate  = $false
            Reason   = 'Contains credential information'
        }

        @{
            Name     = 'Cookies'
            Path     = 'Network\Cookies'
            Category = 'Sensitive'
            Migrate  = $false
            Reason   = 'Contains authentication and session data'
        }

        @{
            Name     = 'Web Data'
            Path     = 'Web Data'
            Category = 'Sensitive'
            Migrate  = $false
            Reason   = 'May contain autofill and payment information'
        }

        @{
            Name     = 'Sessions'
            Path     = 'Sessions'
            Category = 'Sensitive'
            Migrate  = $false
            Reason   = 'Contains browser session information'
        }

        @{
            Name     = 'Session Storage'
            Path     = 'Session Storage'
            Category = 'Sensitive'
            Migrate  = $false
            Reason   = 'Contains site and session state'
        }
    )

    foreach ($definition in $dataDefinitions) {

        $fullPath = Join-Path `
            $EdgeProfilePath `
            $definition.Path

        [PSCustomObject]@{
            Name     = $definition.Name
            Path     = $fullPath
            Exists   = Test-Path -LiteralPath $fullPath
            Category = $definition.Category
            Migrate  = $definition.Migrate
            Reason   = $definition.Reason
        }
    }
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeExtensions
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeExtensions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$EdgeProfilePath
    )

    $extensionsPath = Join-Path `
        $EdgeProfilePath `
        'Extensions'

    if (-not (Test-Path -LiteralPath $extensionsPath -PathType Container)) {
        return @()
    }

    $extensionDirectories = @(
        Get-ChildItem `
            -LiteralPath $extensionsPath `
            -Directory `
            -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '^[a-z]{32}$'
        }
    )

    foreach ($extensionDirectory in $extensionDirectories) {

        $versions = @(
            Get-ChildItem `
                -LiteralPath $extensionDirectory.FullName `
                -Directory `
                -ErrorAction SilentlyContinue
        )

        [PSCustomObject]@{
            ExtensionId  = $extensionDirectory.Name
            Path         = $extensionDirectory.FullName
            Versions     = @($versions.Name)
            VersionCount = $versions.Count
            Category     = 'Review'
            Migrate      = $false
            Reason       = 'Extension files detected; migration requires validation'
        }
    }
}


# ---------------------------------------------------------------------------
# Public function: Get-ProfMigEdgeMigrationPlan
# ---------------------------------------------------------------------------

function Get-ProfMigEdgeMigrationPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ProfilePath
    )

    $detection = Get-ProfMigEdgeDetection `
        -ProfilePath $ProfilePath

    if (-not $detection.Detected) {

        return [PSCustomObject]@{
            Browser       = 'Microsoft Edge'
            Detected      = $false
            IsRunning     = $detection.IsRunning
            UserDataPath  = $null
            ProfileCount  = 0
            Profiles      = @()
            MigrateCount  = 0
            ExcludeCount  = 0
            ReviewCount   = 0
            Status        = 'NotDetected'
        }
    }

    $profilePlans = @()

    foreach ($edgeProfile in $detection.Profiles) {

        $profileData = @(
            Get-ProfMigEdgeProfileData `
                -EdgeProfilePath $edgeProfile.ProfilePath
        )

        $extensions = @(
            Get-ProfMigEdgeExtensions `
                -EdgeProfilePath $edgeProfile.ProfilePath
        )

        $items = @(
            foreach ($item in $profileData) {

                $action = switch ($item.Category) {
                    'Portable'  { 'Migrate' }
                    'Sensitive' { 'Exclude' }
                    'Review'    { 'Review' }
                    default     { 'Exclude' }
                }

                [PSCustomObject]@{
                    Name     = $item.Name
                    Path     = $item.Path
                    Exists   = $item.Exists
                    Category = $item.Category
                    Action   = $action
                    Reason   = $item.Reason
                }
            }
        )

        $profilePlans += [PSCustomObject]@{
            ProfileName    = $edgeProfile.ProfileName
            ProfilePath    = $edgeProfile.ProfilePath
            Items          = $items
            Extensions     = $extensions
            ExtensionCount = $extensions.Count
        }
    }

    $allItems = @(
        foreach ($profilePlan in $profilePlans) {
            $profilePlan.Items
        }
    )

    $migrateCount = @(
        $allItems |
        Where-Object {
            $_.Exists -and
            $_.Action -eq 'Migrate'
        }
    ).Count

    $excludeCount = @(
        $allItems |
        Where-Object {
            $_.Exists -and
            $_.Action -eq 'Exclude'
        }
    ).Count

    $reviewCount = @(
        $allItems |
        Where-Object {
            $_.Exists -and
            $_.Action -eq 'Review'
        }
    ).Count

    $status = if ($detection.IsRunning) {
        'Warning'
    }
    else {
        'Ready'
    }

    return [PSCustomObject]@{
        Browser       = 'Microsoft Edge'
        Detected      = $true
        IsRunning     = $detection.IsRunning
        UserDataPath  = $detection.UserDataPath
        ProfileCount  = $profilePlans.Count
        Profiles      = $profilePlans
        MigrateCount  = $migrateCount
        ExcludeCount  = $excludeCount
        ReviewCount   = $reviewCount
        Status        = $status
    }
}


# ---------------------------------------------------------------------------
# Public function: Test-ProfMigEdgeMigration
# ---------------------------------------------------------------------------

function Test-ProfMigEdgeMigration {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $resolvedSource = [System.IO.Path]::GetFullPath($SourceProfile)
    $resolvedDestination = [System.IO.Path]::GetFullPath($DestinationProfile)

    $plan = Get-ProfMigEdgeMigrationPlan `
        -ProfilePath $resolvedSource

    $validationResults = @()

    if (-not $plan.Detected) {
        return @()
    }

    foreach ($edgeProfile in $plan.Profiles) {

        foreach ($item in $edgeProfile.Items) {

            # Reset validation state for every item.
            $expected = $null
            $valid = $false
            $validationStatus = $null

            $sourcePath = $item.Path

            # Build destination path from the existing source item path.
            if ($sourcePath.StartsWith(
                $resolvedSource,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {

                $relativePath = $sourcePath.Substring(
                    $resolvedSource.Length
                ).TrimStart('\')

                $destinationPath = Join-Path `
                    $resolvedDestination `
                    $relativePath
            }
            else {

                $validationResults += [PSCustomObject]@{
                    ProfileName      = $edgeProfile.ProfileName
                    Name             = $item.Name
                    Action           = $item.Action
                    SourcePath       = $sourcePath
                    DestinationPath  = $null
                    Expected         = $null
                    DestinationFound = $false
                    ValidationStatus = 'InvalidSourcePath'
                    Valid            = $false
                }

                continue
            }

            $destinationFound = Test-Path `
                -LiteralPath $destinationPath

            switch ($item.Action) {

                'Migrate' {

                    if ($item.Exists) {

                        $expected = $true
                        $valid = $destinationFound

                        if ($valid) {
                            $validationStatus = 'Validated'
                        }
                        else {
                            $validationStatus = 'Missing'
                        }
                    }
                    else {

                        $expected = $false

                        if ($destinationFound) {
                            $valid = $true
                            $validationStatus = 'DestinationOnly'
                        }
                        else {
                            $valid = $true
                            $validationStatus = 'NotPresent'
                        }
                    }
                }

                'Review' {

                    # Review items are deliberately not migrated.
                    # Edge may already have created these items itself
                    # in an initialized destination profile.

                    $expected = $null
                    $valid = $true

                    if ($destinationFound) {
                        $validationStatus = 'DestinationPreExistingOrManaged'
                    }
                    else {
                        $validationStatus = 'NotMigrated'
                    }
                }

                'Exclude' {

                    # Sensitive items are never migrated by ProfMig.
                    # Their existence at the destination does not prove
                    # that ProfMig copied them because Edge can create
                    # these items itself.

                    $expected = $null
                    $valid = $true

                    if ($destinationFound) {
                        $validationStatus = 'DestinationPreExistingOrManaged'
                    }
                    else {
                        $validationStatus = 'Excluded'
                    }
                }

                default {

                    $expected = $null
                    $valid = $false
                    $validationStatus = 'UnknownAction'
                }
            }

            $validationResults += [PSCustomObject]@{
                ProfileName      = $edgeProfile.ProfileName
                Name             = $item.Name
                Action           = $item.Action
                SourcePath       = $sourcePath
                DestinationPath  = $destinationPath
                Expected         = $expected
                DestinationFound = $destinationFound
                ValidationStatus = $validationStatus
                Valid            = $valid
            }
        }
    }

    return $validationResults
}


# ---------------------------------------------------------------------------
# Public function: Invoke-ProfMigEdgeMigration
# ---------------------------------------------------------------------------

function Invoke-ProfMigEdgeMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile
    )

    $migrationStartedAt = Get-Date

    if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
        Write-Info 'Starting Microsoft Edge migration.'
        Write-Info "Source profile: $SourceProfile"
        Write-Info "Destination profile: $DestinationProfile"
    }


    # -----------------------------------------------------------------------
    # Validate source and destination Windows profiles
    # -----------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $SourceProfile -PathType Container)) {
        throw "Source profile does not exist: $SourceProfile"
    }

    if (-not (Test-Path -LiteralPath $DestinationProfile -PathType Container)) {
        throw "Destination profile does not exist: $DestinationProfile"
    }

    $resolvedSource = (
        Resolve-Path -LiteralPath $SourceProfile
    ).Path.TrimEnd('\')

    $resolvedDestination = (
        Resolve-Path -LiteralPath $DestinationProfile
    ).Path.TrimEnd('\')

    if ($resolvedSource -ieq $resolvedDestination) {
        throw 'Source and destination profiles cannot be the same.'
    }


    # -----------------------------------------------------------------------
    # Build Edge migration plan
    # -----------------------------------------------------------------------

    $plan = Get-ProfMigEdgeMigrationPlan `
        -ProfilePath $resolvedSource


    # -----------------------------------------------------------------------
    # Edge not detected
    # -----------------------------------------------------------------------

    if (-not $plan.Detected) {

    if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {
        Write-WarningLog 'Microsoft Edge user data was not detected in the source profile.'
    }

    $completedAt = Get-Date

    return [PSCustomObject]@{
        Component          = 'Microsoft Edge'

        SourceProfile      = $resolvedSource
        DestinationProfile = $resolvedDestination

        StartedAt          = $migrationStartedAt
        CompletedAt        = $completedAt
        Duration           = ($completedAt - $migrationStartedAt)

        Status             = 'NotDetected'

        ProfilesDetected   = 0
        ProfilesMigrated   = 0

        FilesCopied        = 0
        FilesFailed        = 0
        BytesCopied        = [int64]0

        Results            = @()
        SensitiveExcluded  = @()
        ReviewSkipped      = @()
        Warnings           = @()

        Components         = @()
        SkippedItems       = @()
        ExcludedItems      = @()
        Errors             = @()

        Totals             = [PSCustomObject]@{
            FilesSelected = 0
            FilesCopied   = 0
            FilesSkipped  = 0
            FilesExcluded = 0
            FilesFailed   = 0
            BytesCopied   = [int64]0
        }
    }
}

    # -----------------------------------------------------------------------
    # Do not migrate while Edge is running
    # -----------------------------------------------------------------------

    if ($plan.IsRunning) {

        if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {
            Write-WarningLog 'Microsoft Edge is running. Edge migration skipped.'
        }

        $completedAt = Get-Date

        return [PSCustomObject]@{
            Component          = 'Microsoft Edge'
            SourceProfile      = $resolvedSource
            DestinationProfile = $resolvedDestination
            StartedAt          = $migrationStartedAt
            CompletedAt        = $completedAt
            Duration           = ($completedAt - $migrationStartedAt)

            Status             = 'Skipped'

            ProfilesDetected   = $plan.ProfileCount
            ProfilesMigrated   = 0

            FilesCopied        = 0
            FilesFailed        = 0
            BytesCopied        = [int64]0

            Results            = @()
            Errors             = @()
            Warnings           = @(
                'Microsoft Edge is running. Close Edge before migration.'
            )

            SensitiveExcluded  = @()
            ReviewSkipped      = @()
        }
    }


    # -----------------------------------------------------------------------
    # Verify Copy Engine integration
    # -----------------------------------------------------------------------

    if (-not (Get-Command Invoke-ProfMigComponentCopy -ErrorAction SilentlyContinue)) {
        throw 'Invoke-ProfMigComponentCopy is not available. Load ProfMig.CopyEngine before starting Edge migration.'
    }


    # -----------------------------------------------------------------------
    # Prepare result collections
    # -----------------------------------------------------------------------

    $results            = @()
    $errors             = @()
    $sensitiveExcluded  = @()
    $reviewSkipped      = @()
    $profilesMigrated   = 0


    if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
        Write-Info "Detected $($plan.ProfileCount) Microsoft Edge profile(s)."
    }


    # -----------------------------------------------------------------------
    # Process Edge profiles
    # -----------------------------------------------------------------------

    foreach ($edgeProfile in $plan.Profiles) {

        if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
            Write-Info "Processing Edge profile: $($edgeProfile.ProfileName)"
        }

        $destinationEdgeProfile = Join-Path `
            $resolvedDestination `
            "AppData\Local\Microsoft\Edge\User Data\$($edgeProfile.ProfileName)"

        $profileMigrated = $false


        # -------------------------------------------------------------------
        # Record Review and Exclude decisions
        # -------------------------------------------------------------------

        foreach ($item in $edgeProfile.Items) {

            if (-not $item.Exists) {
                continue
            }

            if ($item.Action -eq 'Exclude') {

                $excludedItem = [PSCustomObject]@{
                    Component  = "Edge:$($edgeProfile.ProfileName):$($item.Name)"
                    SourceFile = $item.Path
                    Reason     = $item.Reason
                    Category   = $item.Category
                    Action     = $item.Action
                    Name       = $item.Name
                }

                $sensitiveExcluded += $excludedItem

                if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
                    Write-Info "Edge item excluded: $($edgeProfile.ProfileName)\$($item.Name) - $($item.Reason)"
                }

                continue
            }

            if ($item.Action -eq 'Review') {

                $skippedItem = [PSCustomObject]@{
                    Component       = "Edge:$($edgeProfile.ProfileName):$($item.Name)"
                    SourceFile      = $item.Path
                    DestinationFile = $null
                    Reason          = $item.Reason
                    Category        = $item.Category
                    Action          = $item.Action
                    Name            = $item.Name
                }

                $reviewSkipped += $skippedItem

                if (Get-Command Write-Info -ErrorAction SilentlyContinue) {
                    Write-Info "Edge item skipped pending validation: $($edgeProfile.ProfileName)\$($item.Name)"
                }
            }
        }


        # -------------------------------------------------------------------
        # Migrate approved items
        # -------------------------------------------------------------------

        foreach ($item in $edgeProfile.Items) {

            if (-not $item.Exists) {
                continue
            }

            if ($item.Action -ne 'Migrate') {
                continue
            }

            $sourceItem = $item.Path

            $relativeItemPath = $sourceItem.Substring(
                $edgeProfile.ProfilePath.Length
            ).TrimStart('\')

            $destinationItem = Join-Path `
                $destinationEdgeProfile `
                $relativeItemPath

            $destinationItemParent = Split-Path `
                $destinationItem `
                -Parent

            $componentName = "Edge:$($edgeProfile.ProfileName):$($item.Name)"

            # The current Copy Engine works with source directories.
            # A temporary directory exposes only the approved Edge file
            # to the generic Copy Engine.

            $tempRoot = Join-Path `
                ([System.IO.Path]::GetTempPath()) `
                ("ProfMig_Edge_" + [guid]::NewGuid().ToString())

            try {

                New-Item `
                    -Path $tempRoot `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null

                Copy-Item `
                    -LiteralPath $sourceItem `
                    -Destination $tempRoot `
                    -Force `
                    -ErrorAction Stop

                $componentResult = Invoke-ProfMigComponentCopy `
                    -Component $componentName `
                    -SourcePath $tempRoot `
                    -DestinationPath $destinationItemParent

                $results += $componentResult

                if ($componentResult.Errors.Count -gt 0) {
                    $errors += $componentResult.Errors
                }

                if ($componentResult.FilesCopied -gt 0) {

                    $profileMigrated = $true

                    if (Get-Command Write-Success -ErrorAction SilentlyContinue) {
                        Write-Success "Edge item migrated: $($edgeProfile.ProfileName)\$($item.Name)"
                    }
                }
            }
            catch {

                $errorItem = [PSCustomObject]@{
                    Component       = $componentName
                    SourceFile      = $sourceItem
                    DestinationFile = $destinationItem
                    Error           = $_.Exception.Message
                }

                $errors += $errorItem

                if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
                    Write-ErrorLog "Failed to migrate Edge item $($edgeProfile.ProfileName)\$($item.Name): $($_.Exception.Message)"
                }
            }
            finally {

                if (Test-Path -LiteralPath $tempRoot) {

                    Remove-Item `
                        -LiteralPath $tempRoot `
                        -Recurse `
                        -Force `
                        -ErrorAction SilentlyContinue
                }
            }
        }


        if ($profileMigrated) {
            $profilesMigrated++
        }
    }


    # -----------------------------------------------------------------------
    # Calculate totals
    # -----------------------------------------------------------------------

    $filesSelected = 0
    $filesCopied   = 0
    $filesSkipped  = $reviewSkipped.Count
    $filesExcluded = $sensitiveExcluded.Count
    $filesFailed   = 0
    $bytesCopied   = [int64]0

    foreach ($result in $results) {

        $filesSelected += $result.FilesSelected
        $filesCopied   += $result.FilesCopied
        $filesFailed   += $result.FilesFailed
        $bytesCopied   += $result.BytesCopied
    }


    # -----------------------------------------------------------------------
    # Determine final status
    # -----------------------------------------------------------------------

    $migrationCompletedAt = Get-Date

   if ($errors.Count -gt 0 -or $filesFailed -gt 0) {
    $status = 'CompletedWithErrors'
}
else {
    $status = 'Completed'
}

if ($status -eq 'Completed') {

    if (Get-Command Write-Success -ErrorAction SilentlyContinue) {

        Write-Success (
            "Microsoft Edge migration completed successfully. " +
            "Profiles: $profilesMigrated, " +
            "Files: $filesCopied, " +
            "Bytes: $bytesCopied"
        )
    }
}
else {

    if (Get-Command Write-WarningLog -ErrorAction SilentlyContinue) {

        Write-WarningLog (
            "Microsoft Edge migration completed with errors. " +
            "Files copied: $filesCopied, " +
            "Files failed: $filesFailed"
        )
    }
}
 

    # -----------------------------------------------------------------------
    # Return structured migration result
    # -----------------------------------------------------------------------

   return [PSCustomObject]@{
    Component          = 'Microsoft Edge'

    SourceProfile      = $resolvedSource
    DestinationProfile = $resolvedDestination

    StartedAt          = $migrationStartedAt
    CompletedAt        = $migrationCompletedAt
    Duration           = ($migrationCompletedAt - $migrationStartedAt)

    Status             = $status

    ProfilesDetected   = $plan.ProfileCount
    ProfilesMigrated   = $profilesMigrated

    FilesCopied        = $filesCopied
    FilesFailed        = $filesFailed
    BytesCopied        = $bytesCopied

    # Edge-specific result data
    Results            = @($results)
    SensitiveExcluded  = @($sensitiveExcluded)
    ReviewSkipped      = @($reviewSkipped)
    Warnings           = @()

    # Standard ProfMig reporting contract
    Components         = @($results)
    SkippedItems       = @($reviewSkipped)
    ExcludedItems      = @($sensitiveExcluded)
    Errors             = @($errors)

    Totals             = [PSCustomObject]@{
        FilesSelected = $filesSelected
        FilesCopied   = $filesCopied
        FilesSkipped  = $filesSkipped
        FilesExcluded = $filesExcluded
        FilesFailed   = $filesFailed
        BytesCopied   = $bytesCopied
    }
}
}


# ---------------------------------------------------------------------------
# Module exports
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Get-ProfMigEdgeUserDataPath'
    'Get-ProfMigEdgeProfiles'
    'Test-ProfMigEdgeRunning'
    'Get-ProfMigEdgeDetection'
    'Get-ProfMigEdgeProfileData'
    'Get-ProfMigEdgeExtensions'
    'Get-ProfMigEdgeMigrationPlan'
    'Test-ProfMigEdgeMigration'
    'Invoke-ProfMigEdgeMigration'
)