# ============================================================================
# ProfMig.OneNote.psm1
#
# Microsoft OneNote discovery and migration protection provider.
#
# Responsibilities:
#
# - Discover OneNote-related user data
# - Distinguish portable data, backups, cache and Office templates
# - Build a safe migration plan
# - Preserve recoverable OneNote backup data
# - Prevent blind migration of OneNote cache
# - Never overwrite existing destination OneNote data
# - Validate copied files
#
# OneNote cache data is discovery-only. Cache presence does not prove whether
# changes are synchronized or unsynchronized.
# ============================================================================

Set-StrictMode -Version Latest


# ============================================================================
# Get-ProfMigOneNotePaths
# ============================================================================

function Get-ProfMigOneNotePaths {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $localAppData = Join-Path `
        $ProfilePath `
        'AppData\Local'

    $roamingAppData = Join-Path `
        $ProfilePath `
        'AppData\Roaming'

    $documents = Join-Path `
        $ProfilePath `
        'Documents'

    [PSCustomObject]@{
        ProfilePath = $ProfilePath

        LocalRoot = Join-Path `
            $localAppData `
            'Microsoft\OneNote'

        RoamingRoot = Join-Path `
            $roamingAppData `
            'Microsoft\OneNote'

        Local16 = Join-Path `
            $localAppData `
            'Microsoft\OneNote\16.0'

        Roaming16 = Join-Path `
            $roamingAppData `
            'Microsoft\OneNote\16.0'

        DefaultNotebooks = Join-Path `
            $documents `
            'OneNote Notebooks'

        LocalCache = Join-Path `
            $localAppData `
            'Microsoft\OneNote\16.0\cache'

        LocalBackupPaths = @(
            (Join-Path `
                $localAppData `
                'Microsoft\OneNote\16.0\Backup')

            (Join-Path `
                $localAppData `
                'Microsoft\OneNote\16.0\Back-up')
        )

        ServerListings = Join-Path `
            $localAppData `
            'Microsoft\OneNote\16.0\ServerListings'

        OfficeTemplates = Join-Path `
            $roamingAppData `
            'Microsoft\Templates'
    }
}


# ============================================================================
# Test-ProfMigOneNotePathWithin
#
# Determines whether a path is equal to or located below a known directory.
#
# Including the directory separator prevents paths such as "cache-old" from
# being incorrectly classified as being inside "cache".
# ============================================================================

function Test-ProfMigOneNotePathWithin {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ParentPath
    )

    $normalizedPath = $Path.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    $normalizedParent = $ParentPath.TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )

    if (
        $normalizedPath.Equals(
            $normalizedParent,
            [System.StringComparison]::OrdinalIgnoreCase
        )
    ) {
        return $true
    }

    $parentPrefix = (
        $normalizedParent +
        [System.IO.Path]::DirectorySeparatorChar
    )

    return $normalizedPath.StartsWith(
        $parentPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}


# ============================================================================
# Get-ProfMigOneNoteFiles
#
# Searches the source profile for known portable OneNote file types.
#
# Classification:
#
# Portable
#   Potential local notebook data.
#
# Backup
#   OneNote-created backup data. Preserve for recovery.
#
# Cache
#   Portable-looking OneNote data inside the cache. Review only.
#
# Template
#   Office template artifacts using OneNote-related extensions.
# ============================================================================

function Get-ProfMigOneNoteFiles {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $ProfilePath `
                -PathType Container `
                -ErrorAction SilentlyContinue
        )
    ) {
        return @()
    }

    $oneNotePaths = Get-ProfMigOneNotePaths `
        -ProfilePath $ProfilePath

    $portableExtensions = @(
        '.one'
        '.onetoc2'
        '.onepkg'
    )

    $files = New-Object `
        'System.Collections.Generic.List[object]'

    $profileFiles = @(
        Get-ChildItem `
            -LiteralPath $ProfilePath `
            -File `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    )

    foreach ($file in $profileFiles) {

        $extension = (
            [System.IO.Path]::GetExtension(
                $file.Name
            )
        ).ToLowerInvariant()

        if ($extension -notin $portableExtensions) {
            continue
        }

        # --------------------------------------------------------------------
        # Default classification
        # --------------------------------------------------------------------

        $classification = 'Portable'
        $action = 'Migrate'
        $reason = 'PortableOneNoteData'

        # --------------------------------------------------------------------
        # Office template data
        # --------------------------------------------------------------------

        if (
            Test-ProfMigOneNotePathWithin `
                -Path $file.FullName `
                -ParentPath $oneNotePaths.OfficeTemplates
        ) {
            $classification = 'Template'
            $action = 'Exclude'
            $reason = 'OfficeTemplateData'
        }

        # --------------------------------------------------------------------
        # OneNote cache
        # --------------------------------------------------------------------

        elseif (
            Test-ProfMigOneNotePathWithin `
                -Path $file.FullName `
                -ParentPath $oneNotePaths.LocalCache
        ) {
            $classification = 'Cache'
            $action = 'Review'
            $reason = 'OneNoteCacheData'
        }

        # --------------------------------------------------------------------
        # OneNote backups
        # --------------------------------------------------------------------

        else {

            $isBackup = $false

            foreach (
                $backupPath in @(
                    $oneNotePaths.LocalBackupPaths
                )
            ) {

                if (
                    Test-ProfMigOneNotePathWithin `
                        -Path $file.FullName `
                        -ParentPath $backupPath
                ) {
                    $isBackup = $true
                    break
                }
            }

            if ($isBackup) {
                $classification = 'Backup'
                $action = 'Preserve'
                $reason = 'OneNoteBackupData'
            }
        }

        # --------------------------------------------------------------------
        # Relative source-profile path
        # --------------------------------------------------------------------

        $profileRoot = $ProfilePath.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )

        $relativePath = $file.FullName.Substring(
            $profileRoot.Length
        ).TrimStart(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )

        # --------------------------------------------------------------------
        # Result
        # --------------------------------------------------------------------

        $files.Add(
            [PSCustomObject]@{
                Path           = $file.FullName
                RelativePath   = $relativePath
                Name           = $file.Name
                Extension      = $extension
                Size           = [Int64]$file.Length
                LastWriteTime  = $file.LastWriteTime
                Classification = $classification
                Action         = $action
                Reason         = $reason
            }
        )
    }

    return $files.ToArray()
}


# ============================================================================
# Get-ProfMigOneNoteCacheState
#
# Discovers OneNote cache state without interpreting cache contents.
#
# Cache presence does not prove that unsynchronized changes exist.
#
# If cache data exists, synchronization/recoverability must be reviewed before
# the source profile is removed.
#
# Cache contents are never automatically migrated.
# ============================================================================

function Get-ProfMigOneNoteCacheState {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $paths = Get-ProfMigOneNotePaths `
        -ProfilePath $ProfilePath

    $cacheExists = Test-Path `
        -LiteralPath $paths.LocalCache `
        -PathType Container `
        -ErrorAction SilentlyContinue

    if (-not $cacheExists) {

        return [PSCustomObject]@{
            Exists         = $false
            HasData        = $false
            FileCount      = 0
            TotalBytes     = [Int64]0
            LatestWrite    = $null
            Action         = 'None'
            RequiresReview = $false
            Warning        = $null
        }
    }

    $cacheFiles = @(
        Get-ChildItem `
            -LiteralPath $paths.LocalCache `
            -File `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    )

    [Int64]$totalBytes = 0
    $latestWrite = $null

    foreach ($file in $cacheFiles) {

        $totalBytes += [Int64]$file.Length

        if (
            $null -eq $latestWrite -or
            $file.LastWriteTime -gt $latestWrite
        ) {
            $latestWrite = $file.LastWriteTime
        }
    }

    $hasData = ($cacheFiles.Count -gt 0)

    $warning = $null
    $action = 'None'

    if ($hasData) {

        $action = 'Review'

        $warning = (
            'OneNote local cache data was detected. ' +
            'ProfMig cannot determine from the cache alone whether all ' +
            'changes are synchronized. Verify OneNote synchronization ' +
            'before removing the source profile. The cache will not be ' +
            'automatically migrated.'
        )
    }

    [PSCustomObject]@{
        Exists         = $true
        HasData        = $hasData
        FileCount      = $cacheFiles.Count
        TotalBytes     = $totalBytes
        LatestWrite    = $latestWrite
        Action         = $action
        RequiresReview = $hasData
        Warning        = $warning
    }
}


# ============================================================================
# Get-ProfMigOneNoteDetection
#
# Builds the complete OneNote discovery result for a source profile.
#
# Detection means OneNote-related profile state exists. It does not
# necessarily mean that active notebooks are stored locally.
# ============================================================================

function Get-ProfMigOneNoteDetection {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $paths = Get-ProfMigOneNotePaths `
        -ProfilePath $ProfilePath

    $files = @(
        Get-ProfMigOneNoteFiles `
            -ProfilePath $ProfilePath
    )

    $cacheState = Get-ProfMigOneNoteCacheState `
        -ProfilePath $ProfilePath

    # ------------------------------------------------------------------------
    # Known OneNote locations
    # ------------------------------------------------------------------------

    $localRootExists = Test-Path `
        -LiteralPath $paths.LocalRoot `
        -PathType Container `
        -ErrorAction SilentlyContinue

    $roamingRootExists = Test-Path `
        -LiteralPath $paths.RoamingRoot `
        -PathType Container `
        -ErrorAction SilentlyContinue

    $defaultNotebookPathExists = Test-Path `
        -LiteralPath $paths.DefaultNotebooks `
        -PathType Container `
        -ErrorAction SilentlyContinue

    $serverListingsExists = Test-Path `
        -LiteralPath $paths.ServerListings `
        -PathType Container `
        -ErrorAction SilentlyContinue

    # ------------------------------------------------------------------------
    # Backup locations
    # ------------------------------------------------------------------------

    $backupExists = $false

    $existingBackupPaths = New-Object `
        'System.Collections.Generic.List[string]'

    foreach (
        $backupPath in @(
            $paths.LocalBackupPaths
        )
    ) {

        if (
            Test-Path `
                -LiteralPath $backupPath `
                -PathType Container `
                -ErrorAction SilentlyContinue
        ) {
            $backupExists = $true
            $existingBackupPaths.Add(
                $backupPath
            )
        }
    }

    # ------------------------------------------------------------------------
    # File classifications
    # ------------------------------------------------------------------------

    $portableFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Portable'
            }
    )

    $backupFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Backup'
            }
    )

    $cacheFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Cache'
            }
    )

    $templateFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Template'
            }
    )

    # ------------------------------------------------------------------------
    # Overall detection
    # ------------------------------------------------------------------------

    $detected = (
        $localRootExists -or
        $roamingRootExists -or
        $defaultNotebookPathExists -or
        $files.Count -gt 0 -or
        $cacheState.HasData
    )

    # ------------------------------------------------------------------------
    # Review state
    # ------------------------------------------------------------------------

    $requiresReview = (
        $cacheState.RequiresReview -or
        $cacheFiles.Count -gt 0
    )

    # ------------------------------------------------------------------------
    # Result
    # ------------------------------------------------------------------------

    [PSCustomObject]@{
        Id                        = 'Microsoft.OneNote'
        Name                      = 'Microsoft OneNote'
        Detected                  = $detected
        ProfilePath               = $ProfilePath

        LocalRootExists           = $localRootExists
        RoamingRootExists         = $roamingRootExists
        DefaultNotebookPathExists = $defaultNotebookPathExists

        CacheExists               = $cacheState.Exists
        BackupExists              = $backupExists
        ServerListingsExists      = $serverListingsExists

        ExistingBackupPaths       = $existingBackupPaths.ToArray()

        PortableFiles             = $portableFiles
        BackupFiles               = $backupFiles
        CacheFiles                = $cacheFiles
        TemplateFiles             = $templateFiles

        Files                     = $files
        CacheState                = $cacheState

        PortableCount             = $portableFiles.Count
        BackupCount               = $backupFiles.Count
        CacheCount                = $cacheFiles.Count
        TemplateCount             = $templateFiles.Count
        TotalFiles                = $files.Count

        RequiresReview            = $requiresReview
        Warning                   = $cacheState.Warning
    }
}


# ============================================================================
# Get-ProfMigOneNoteMigrationPlan
#
# Builds a migration plan from OneNote discovery results.
#
# Policies:
#
# Portable
#   Migrate local portable OneNote data.
#
# Backup
#   Preserve recoverable OneNote backup data.
#
# Cache
#   Review only. Cache contents are never automatically migrated.
#
# Template
#   Exclude unrelated Office template artifacts.
# ============================================================================

function Get-ProfMigOneNoteMigrationPlan {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $detection = Get-ProfMigOneNoteDetection `
        -ProfilePath $ProfilePath

    $migrateItems = @(
        $detection.Files |
            Where-Object {
                $_.Action -eq 'Migrate'
            }
    )

    $preserveItems = @(
        $detection.Files |
            Where-Object {
                $_.Action -eq 'Preserve'
            }
    )

    $reviewItems = @(
        $detection.Files |
            Where-Object {
                $_.Action -eq 'Review'
            }
    )

    $excludedItems = @(
        $detection.Files |
            Where-Object {
                $_.Action -eq 'Exclude'
            }
    )

    [Int64]$migrationBytes = 0
    [Int64]$preservationBytes = 0

    foreach ($item in $migrateItems) {
        $migrationBytes += [Int64]$item.Size
    }

    foreach ($item in $preserveItems) {
        $preservationBytes += [Int64]$item.Size
    }

    $warnings = New-Object `
        'System.Collections.Generic.List[string]'

    if ($detection.CacheState.RequiresReview) {

        if (
            -not [string]::IsNullOrWhiteSpace(
                $detection.CacheState.Warning
            )
        ) {
            $warnings.Add(
                $detection.CacheState.Warning
            )
        }
    }

    $status = if (-not $detection.Detected) {
        'NoData'
    }
    elseif (
        $migrateItems.Count -eq 0 -and
        $preserveItems.Count -eq 0
    ) {
        'ReviewOnly'
    }
    elseif ($detection.RequiresReview) {
        'ReadyWithWarnings'
    }
    else {
        'Ready'
    }

    [PSCustomObject]@{
        Application       = 'Microsoft OneNote'
        ApplicationId     = 'OneNote'
        ProfilePath       = $ProfilePath

        Detected          = $detection.Detected
        Status            = $status

        ItemsDetected     = $detection.TotalFiles

        MigrateCount      = $migrateItems.Count
        PreserveCount     = $preserveItems.Count
        ReviewCount       = $reviewItems.Count
        ExcludeCount      = $excludedItems.Count

        MigrationBytes    = $migrationBytes
        PreservationBytes = $preservationBytes

        TotalCopyBytes    = (
            $migrationBytes +
            $preservationBytes
        )

        MigrateItems      = $migrateItems
        PreserveItems     = $preserveItems
        ReviewItems       = $reviewItems
        ExcludedItems     = $excludedItems

        CachePolicy       = 'ReviewOnly'
        BackupPolicy      = 'Preserve'
        CloudPolicy       = 'Resynchronize'
        OverwritePolicy   = 'NeverOverwrite'

        CacheState        = $detection.CacheState
        RequiresReview    = $detection.RequiresReview
        Warnings          = $warnings.ToArray()

        Detection         = $detection
    }
}


# ============================================================================
# Copy-ProfMigOneNoteFile
#
# Safely copies a portable or recoverable OneNote file.
#
# Safety rules:
#
# - Only supported OneNote portable file types are accepted.
# - Existing destination files are never overwritten.
# - Destination disk space is validated before copying.
# - Destination directories are created only when required.
# - The copied file must exist and match the source file size.
# - An incomplete destination file is removed after validation failure.
#
# This function must never be used to copy OneNote cache files.
# ============================================================================

function Copy-ProfMigOneNoteFile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    $supportedExtensions = @(
        '.one'
        '.onetoc2'
        '.onepkg'
    )

    # ------------------------------------------------------------------------
    # Validate source
    # ------------------------------------------------------------------------

    if (
        -not (
            Test-Path `
                -LiteralPath $SourcePath `
                -PathType Leaf `
                -ErrorAction SilentlyContinue
        )
    ) {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = 'Source OneNote file does not exist.'
        }
    }

    try {

        $sourceFile = Get-Item `
            -LiteralPath $SourcePath `
            -ErrorAction Stop
    }
    catch {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = $_.Exception.Message
        }
    }

    $extension = (
        [System.IO.Path]::GetExtension(
            $sourceFile.Name
        )
    ).ToLowerInvariant()

    if ($extension -notin $supportedExtensions) {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]$sourceFile.Length
            Reason          = 'Source file is not a supported OneNote file.'
        }
    }

    # ------------------------------------------------------------------------
    # Never overwrite existing destination data
    # ------------------------------------------------------------------------

    if (
        Test-Path `
            -LiteralPath $DestinationPath `
            -PathType Leaf `
            -ErrorAction SilentlyContinue
    ) {

        return [PSCustomObject]@{
            Success         = $true
            Skipped         = $true
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = 'Destination OneNote file already exists.'
        }
    }

    # ------------------------------------------------------------------------
    # Destination directory
    # ------------------------------------------------------------------------

    $destinationDirectory = Split-Path `
        -Path $DestinationPath `
        -Parent

    if (
        [string]::IsNullOrWhiteSpace(
            $destinationDirectory
        )
    ) {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = 'Destination directory could not be determined.'
        }
    }

    # ------------------------------------------------------------------------
    # Destination disk-space validation
    #
    # Use the same safety policy as the Outlook provider:
    #
    # - source file size
    # - plus 10 percent
    # - minimum safety margin of 100 MB
    # ------------------------------------------------------------------------

    try {

        $destinationRoot = [System.IO.Path]::GetPathRoot(
            $DestinationPath
        )

        if (
            [string]::IsNullOrWhiteSpace(
                $destinationRoot
            )
        ) {
            throw 'Destination root could not be determined.'
        }

        $driveInfo = [System.IO.DriveInfo]::new(
            $destinationRoot
        )

        [Int64]$requiredBytes = $sourceFile.Length

        [Int64]$safetyMargin = [Math]::Max(
            [Math]::Ceiling(
                $requiredBytes * 0.10
            ),
            100MB
        )

        [Int64]$totalRequired = (
            $requiredBytes +
            $safetyMargin
        )

        if (
            $driveInfo.AvailableFreeSpace -lt
            $totalRequired
        ) {

            return [PSCustomObject]@{
                Success         = $false
                Skipped         = $false
                SourcePath      = $SourcePath
                DestinationPath = $DestinationPath
                SizeBytes       = [Int64]0
                Reason          = 'Insufficient destination disk space.'
            }
        }
    }
    catch {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = (
                'Destination disk space could not be validated: ' +
                $_.Exception.Message
            )
        }
    }

    # ------------------------------------------------------------------------
    # Copy
    # ------------------------------------------------------------------------

    try {

        if (
            -not (
                Test-Path `
                    -LiteralPath $destinationDirectory `
                    -PathType Container `
                    -ErrorAction SilentlyContinue
            )
        ) {

            New-Item `
                -ItemType Directory `
                -Path $destinationDirectory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }

        #
        # Deliberately do not use -Force.
        #
        Copy-Item `
            -LiteralPath $SourcePath `
            -Destination $DestinationPath `
            -ErrorAction Stop

        # --------------------------------------------------------------------
        # Post-copy validation
        # --------------------------------------------------------------------

        if (
            -not (
                Test-Path `
                    -LiteralPath $DestinationPath `
                    -PathType Leaf
            )
        ) {
            throw 'Destination OneNote file was not created.'
        }

        $destinationFile = Get-Item `
            -LiteralPath $DestinationPath `
            -ErrorAction Stop

        if (
            $destinationFile.Length -ne
            $sourceFile.Length
        ) {

            #
            # Never leave an incomplete copy behind.
            #
            Remove-Item `
                -LiteralPath $DestinationPath `
                -Force `
                -ErrorAction SilentlyContinue

            throw (
                'Destination OneNote file size does not match ' +
                'source file size.'
            )
        }

        return [PSCustomObject]@{
            Success         = $true
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]$destinationFile.Length
            Reason          = 'OneNote file copied and validated successfully.'
        }
    }
    catch {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = $_.Exception.Message
        }
    }
}


# ============================================================================
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'Get-ProfMigOneNotePaths'
    'Get-ProfMigOneNoteFiles'
    'Get-ProfMigOneNoteCacheState'
    'Get-ProfMigOneNoteDetection'
    'Get-ProfMigOneNoteMigrationPlan'
    'Copy-ProfMigOneNoteFile'
)