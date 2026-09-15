# ============================================================================
# ProfMig.OneNote.psm1
#
# Microsoft OneNote discovery and migration protection provider.
#
# This module discovers OneNote-related user data and classifies it so that
# ProfMig can distinguish between:
#
# - Portable notebook data
# - Recoverable OneNote backups
# - OneNote cache/offline state
# - Office template artifacts
#
# OneNote cache data is discovery-only. ProfMig must never blindly migrate
# cache contents because cache presence does not prove whether changes are
# synchronized or unsynchronized.
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
# The directory separator is included in the comparison so that a path such
# as "cache-old" is not incorrectly classified as being inside "cache".
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
# Searches the complete source profile for known OneNote portable file types.
#
# Classification:
#
# Portable
#   Potential local notebook data.
#
# Backup
#   OneNote-created backup data. Preserve for recovery instead of treating it
#   as an active notebook.
#
# Cache
#   Portable-looking data located inside the OneNote cache. Review only.
#
# Template
#   Office template artifacts that happen to use a OneNote extension.
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
            [System.IO.Path]::GetExtension($file.Name)
        ).ToLowerInvariant()

        if ($extension -notin $portableExtensions) {
            continue
        }

        # --------------------------------------------------------------------
        # Default: potential portable/local OneNote data
        # --------------------------------------------------------------------

        $classification = 'Portable'
        $action = 'Migrate'
        $reason = 'PortableOneNoteData'

        # --------------------------------------------------------------------
        # Office templates
        #
        # .onetoc2 files can occur below Microsoft\Templates even though they
        # are not actual user notebooks.
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
        #
        # Cache data may represent cloud/offline application state.
        # Never treat it as normal portable notebook data.
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
        # OneNote backup directories
        #
        # Support both Backup and Back-up directory names.
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
        # Relative path
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
# Discovers OneNote cache state without reading or interpreting cache content.
#
# Cache presence does not prove that unsynchronized changes exist.
#
# If cache files are present, ProfMig requires review because synchronization
# and recoverability cannot be determined from cache presence alone.
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
    # Backup location detection
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
            $existingBackupPaths.Add($backupPath)
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
    #
    # Cache data requires review because ProfMig cannot prove synchronization
    # state from the cache alone.
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
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'Get-ProfMigOneNotePaths'
    'Get-ProfMigOneNoteFiles'
    'Get-ProfMigOneNoteCacheState'
    'Get-ProfMigOneNoteDetection'
)