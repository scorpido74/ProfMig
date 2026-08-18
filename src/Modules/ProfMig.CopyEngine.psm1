<#
.SYNOPSIS
    Core copy engine for ProfMig.

.DESCRIPTION
    Provides reusable and resilient functions for copying selected
    Windows user profile data from a source profile to a destination
    profile.

    The engine processes directory trees incrementally instead of first
    recursively enumerating the complete source tree.

    Reparse points are not traversed. Failures are recorded and migration
    continues where possible.

.NOTES
    Project : ProfMig
    Module  : ProfMig.CopyEngine
    Sprint  : 1.6 - Copy Engine
    Updated : 2.7 - Resilient traversal and application integration
#>
Set-StrictMode -Version Latest

$exclusionModulePath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'ProfMig.Exclusions.psm1'

if (-not (Test-Path -LiteralPath $exclusionModulePath)) {
    throw "ProfMig exclusions module not found: $exclusionModulePath"
}

Import-Module `
    -Name $exclusionModulePath `
    -Force `
    -ErrorAction Stop

Initialize-ProfMigDefaultExclusions

$loggingModulePath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'ProfMig.Logging.psm1'

if (-not (Test-Path -LiteralPath $loggingModulePath)) {
    throw "ProfMig logging module not found: $loggingModulePath"
}

Import-Module `
    -Name $loggingModulePath `
    -Force `
    -ErrorAction Stop

# ---------------------------------------------------------------------------
# Internal function: Test-ProfMigLegacyExclusion
# ---------------------------------------------------------------------------

function Test-ProfMigLegacyExclusion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [string[]]$Exclusions = @()
    )

    $normalizedPath = $RelativePath.Replace('/', '\').TrimStart('\')
    $fileName = Split-Path -Path $normalizedPath -Leaf

    foreach ($exclusion in $Exclusions) {

        if ([string]::IsNullOrWhiteSpace($exclusion)) {
            continue
        }

        $normalizedExclusion = $exclusion.Replace('/', '\').Trim('\')

        if ($normalizedPath -like $normalizedExclusion) {
            return $true
        }

        if ($fileName -like $normalizedExclusion) {
            return $true
        }

        if (
            $normalizedPath -like "$normalizedExclusion\*" -or
            $normalizedPath -like "*\$normalizedExclusion\*"
        ) {
            return $true
        }
    }

    return $false
}


# ---------------------------------------------------------------------------
# Internal function: Test-ProfMigRelativeFolder
# ---------------------------------------------------------------------------

function Test-ProfMigRelativeFolder {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $false
    }

    $normalizedPath = $Path.Replace('/', '\').Trim('\')

    if ([string]::IsNullOrWhiteSpace($normalizedPath)) {
        return $false
    }

    foreach ($segment in $normalizedPath.Split('\')) {

        if (
            [string]::IsNullOrWhiteSpace($segment) -or
            $segment -eq '.' -or
            $segment -eq '..'
        ) {
            return $false
        }
    }

    return $true
}


# ---------------------------------------------------------------------------
# Internal function: Test-ProfMigReparsePoint
# ---------------------------------------------------------------------------

function Test-ProfMigReparsePoint {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    return (
        ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    )
}


# ---------------------------------------------------------------------------
# Internal function: Get-ProfMigRelativePath
# ---------------------------------------------------------------------------

function Get-ProfMigRelativePath {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$BasePath,

        [Parameter(Mandatory)]
        [string]$FullPath
    )

    $normalizedBase = $BasePath.TrimEnd('\')

    if ($FullPath.Length -le $normalizedBase.Length) {
        return (Split-Path -Path $FullPath -Leaf)
    }

    return $FullPath.Substring($normalizedBase.Length).TrimStart('\')
}


# ---------------------------------------------------------------------------
# Internal function: New-ProfMigCopyError
# ---------------------------------------------------------------------------

function New-ProfMigCopyError {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter()]
        [AllowNull()]
        [string]$SourceFile,

        [Parameter()]
        [AllowNull()]
        [string]$DestinationFile,

        [Parameter(Mandatory)]
        [string]$ErrorMessage
    )

    return [PSCustomObject]@{
        Component       = $Component
        SourceFile      = $SourceFile
        DestinationFile = $DestinationFile
        Error           = $ErrorMessage
    }
}


# ---------------------------------------------------------------------------
# Internal function: ConvertTo-ProfMigExtendedPath
# ---------------------------------------------------------------------------

function ConvertTo-ProfMigExtendedPath {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Path.StartsWith('\\?\')) {
        return $Path
    }

    # UNC path
    if ($Path.StartsWith('\\')) {

        return (
            '\\?\UNC\' +
            $Path.TrimStart('\')
        )
    }

    # Local absolute path
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return "\\?\$Path"
    }

    return $Path
}

# ---------------------------------------------------------------------------
# Internal function: Copy-ProfMigSingleFile
# ---------------------------------------------------------------------------

function Copy-ProfMigSingleFile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory)]
        [string]$DestinationFile,

        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [string[]]$Exclusions = @()
    )

    $result = [ordered]@{
        Selected     = 1
        Copied       = 0
        Skipped      = 0
        Excluded     = 0
        Failed       = 0
        BytesCopied  = [int64]0
        SkippedItem  = $null
        ExcludedItem = $null
        Error        = $null
    }

    if (
        Test-ProfMigLegacyExclusion `
            -RelativePath $RelativePath `
            -Exclusions $Exclusions
    ) {

        $result.Excluded = 1

        $result.ExcludedItem = [PSCustomObject]@{
            Component  = $Component
            SourceFile = $File.FullName
            Reason     = 'Excluded by migration rule'
        }

        return [PSCustomObject]$result
    }

    try {

        $destinationDirectory = Split-Path `
            -Path $DestinationFile `
            -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($destinationDirectory) -and
            -not (
                Test-Path `
                    -LiteralPath $destinationDirectory `
                    -PathType Container
            )
        ) {

        $extendedDestinationDirectory = ConvertTo-ProfMigExtendedPath `
            -Path $destinationDirectory

        [System.IO.Directory]::CreateDirectory(
            $extendedDestinationDirectory
        ) | Out-Null
        }

        $extendedDestinationFile = ConvertTo-ProfMigExtendedPath `
            -Path $DestinationFile

        if ([System.IO.File]::Exists($extendedDestinationFile)) {

            $result.Skipped = 1

            $result.SkippedItem = [PSCustomObject]@{
                Component       = $Component
                SourceFile      = $File.FullName
                DestinationFile = $DestinationFile
                Reason          = 'Destination file already exists'
            }

            return [PSCustomObject]$result
        }

        $sourceCopyPath = ConvertTo-ProfMigExtendedPath `
            -Path $File.FullName

        $destinationCopyPath = ConvertTo-ProfMigExtendedPath `
            -Path $DestinationFile

        [System.IO.File]::Copy(
            $sourceCopyPath,
            $destinationCopyPath,
            $false
        )

        $result.Copied = 1
        $result.BytesCopied = [int64]$File.Length
    }
    catch {

        $result.Failed = 1

        $result.Error = New-ProfMigCopyError `
            -Component $Component `
            -SourceFile $File.FullName `
            -DestinationFile $DestinationFile `
            -ErrorMessage $_.Exception.Message
    }

    return [PSCustomObject]$result
}


# ---------------------------------------------------------------------------
# Internal function: Copy-ProfMigComponent
# ---------------------------------------------------------------------------

function Copy-ProfMigComponent {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter()]
        [string[]]$Exclusions = @()
    )

    $componentStartedAt = Get-Date

    $filesSelected = 0
    $filesCopied   = 0
    $filesSkipped  = 0
    $filesExcluded = 0
    $filesFailed   = 0
    $bytesCopied   = [int64]0

    $skippedItems  = @()
    $excludedItems = @()
    $errors        = @()

    Write-Verbose "Processing component '$Component': $SourcePath"

    # -----------------------------------------------------------------------
    # Validate source
    # -----------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $SourcePath)) {

        $componentCompletedAt = Get-Date

        return [PSCustomObject]@{
            Component       = $Component
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath

            StartedAt       = $componentStartedAt
            CompletedAt     = $componentCompletedAt
            Duration        = ($componentCompletedAt - $componentStartedAt)

            FilesSelected   = 0
            FilesCopied     = 0
            FilesSkipped    = 0
            FilesExcluded   = 0
            FilesFailed     = 0
            BytesCopied     = [int64]0

            Status          = 'SourceNotFound'

            SkippedItems    = @()
            ExcludedItems   = @()
            Errors          = @()
        }
    }

    try {

        $sourceItem = Get-Item `
            -LiteralPath $SourcePath `
            -Force `
            -ErrorAction Stop
    }
    catch {

        $componentCompletedAt = Get-Date

        return [PSCustomObject]@{
            Component       = $Component
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath

            StartedAt       = $componentStartedAt
            CompletedAt     = $componentCompletedAt
            Duration        = ($componentCompletedAt - $componentStartedAt)

            FilesSelected   = 0
            FilesCopied     = 0
            FilesSkipped    = 0
            FilesExcluded   = 0
            FilesFailed     = 0
            BytesCopied     = [int64]0

            Status          = 'Failed'

            SkippedItems    = @()
            ExcludedItems   = @()

            Errors          = @(
                New-ProfMigCopyError `
                    -Component $Component `
                    -SourceFile $SourcePath `
                    -DestinationFile $DestinationPath `
                    -ErrorMessage $_.Exception.Message
            )
        }
    }

    # -----------------------------------------------------------------------
    # Single-file component
    # -----------------------------------------------------------------------

    if (-not $sourceItem.PSIsContainer) {

        $relativePath = $sourceItem.Name

        $exclusionResult = Test-ProfMigExclusion `
            -RelativePath $relativePath `
            -Application $Component

        if ($exclusionResult.Excluded) {

            $filesSelected++
            $filesExcluded++

            $excludedItems += [PSCustomObject]@{
                Component         = $Component
                SourceFile        = $sourceItem.FullName
                DestinationFile   = $DestinationPath
                RelativePath      = $relativePath
                Reason            = $exclusionResult.Reason
                ExclusionRuleId   = $exclusionResult.RuleId
                ExclusionType     = $exclusionResult.RuleType
                ExclusionCategory = $exclusionResult.Category
                Application       = $exclusionResult.Application
                Mandatory         = $exclusionResult.Mandatory
            }

            Write-Info `
                -Message "Excluded [$($exclusionResult.Category)] rule $($exclusionResult.RuleId): $relativePath - $($exclusionResult.Reason)"
        }
        else {

            $fileResult = Copy-ProfMigSingleFile `
                -Component $Component `
                -File $sourceItem `
                -DestinationFile $DestinationPath `
                -RelativePath $relativePath `
                -Exclusions $Exclusions

            $filesSelected += $fileResult.Selected
            $filesCopied   += $fileResult.Copied
            $filesSkipped  += $fileResult.Skipped
            $filesExcluded += $fileResult.Excluded
            $filesFailed   += $fileResult.Failed
            $bytesCopied   += $fileResult.BytesCopied

            if ($null -ne $fileResult.SkippedItem) {
                $skippedItems += $fileResult.SkippedItem
            }

            if ($null -ne $fileResult.ExcludedItem) {
                $excludedItems += $fileResult.ExcludedItem
            }

            if ($null -ne $fileResult.Error) {
                $errors += $fileResult.Error
            }
        }

    }

    # -----------------------------------------------------------------------
    # Directory component
    #
    # IMPORTANT:
    # Do not use Get-ChildItem -Recurse.
    #
    # We maintain our own directory queue and inspect one directory at a
    # time. Reparse points are never added to the queue.
    # -----------------------------------------------------------------------

    else {

        try {

            if (
                -not (
                    Test-Path `
                        -LiteralPath $DestinationPath `
                        -PathType Container
                )
            ) {

                New-Item `
                    -Path $DestinationPath `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }
        }
        catch {

            $componentCompletedAt = Get-Date

            return [PSCustomObject]@{
                Component       = $Component
                SourcePath      = $SourcePath
                DestinationPath = $DestinationPath

                StartedAt       = $componentStartedAt
                CompletedAt     = $componentCompletedAt
                Duration        = ($componentCompletedAt - $componentStartedAt)

                FilesSelected   = 0
                FilesCopied     = 0
                FilesSkipped    = 0
                FilesExcluded   = 0
                FilesFailed     = 0
                BytesCopied     = [int64]0

                Status          = 'Failed'

                SkippedItems    = @()
                ExcludedItems   = @()

                Errors          = @(
                    New-ProfMigCopyError `
                        -Component $Component `
                        -SourceFile $SourcePath `
                        -DestinationFile $DestinationPath `
                        -ErrorMessage $_.Exception.Message
                )
            }
        }

        $directoryQueue = New-Object `
            'System.Collections.Generic.Queue[string]'

        $directoryQueue.Enqueue($sourceItem.FullName)

        while ($directoryQueue.Count -gt 0) {

            $currentDirectory = $directoryQueue.Dequeue()

            Write-Verbose (
                "Scanning '$Component': $currentDirectory"
            )

            # ---------------------------------------------------------------
            # Enumerate this directory only
            # ---------------------------------------------------------------

            try {

                $children = @(
                    Get-ChildItem `
                        -LiteralPath $currentDirectory `
                        -Force `
                        -ErrorAction Stop
                )
            }
            catch {

                $filesFailed++

                $errors += New-ProfMigCopyError `
                    -Component $Component `
                    -SourceFile $currentDirectory `
                    -DestinationFile $null `
                    -ErrorMessage (
                        "Unable to enumerate directory: " +
                        $_.Exception.Message
                    )

                continue
            }

            foreach ($child in $children) {

                # -----------------------------------------------------------
                # Directory
                # -----------------------------------------------------------

                if ($child.PSIsContainer) {

                    $relativeDirectory = Get-ProfMigRelativePath `
                        -BasePath $SourcePath `
                        -FullPath $child.FullName

                    # Central application exclusion policy takes precedence.
                    $centralDirectoryExclusion = Test-ProfMigExclusion `
                        -RelativePath $relativeDirectory `
                        -Application $Component

                    if ($centralDirectoryExclusion.Excluded) {

                        $filesExcluded++

                        $excludedItems += [PSCustomObject]@{
                            Component         = $Component
                            SourceFile        = $child.FullName
                            DestinationFile   = $null
                            RelativePath      = $relativeDirectory
                            Reason            = $centralDirectoryExclusion.Reason
                            ExclusionRuleId   = $centralDirectoryExclusion.RuleId
                            ExclusionType     = $centralDirectoryExclusion.RuleType
                            ExclusionCategory = $centralDirectoryExclusion.Category
                            Application       = $centralDirectoryExclusion.Application
                            Mandatory         = $centralDirectoryExclusion.Mandatory
                        }

                        Write-Info `
                            -Message "Excluded [$($centralDirectoryExclusion.Category)] rule $($centralDirectoryExclusion.RuleId): $relativeDirectory - $($centralDirectoryExclusion.Reason)"

                        continue
                    }

                    # Preserve configured/legacy exclusions from the copy engine.
                    if (
                        Test-ProfMigLegacyExclusion `
                            -RelativePath $relativeDirectory `
                            -Exclusions $Exclusions
                    ) {

                        $filesExcluded++

                        $excludedItems += [PSCustomObject]@{
                            Component    = $Component
                            SourceFile   = $child.FullName
                            RelativePath = $relativeDirectory
                            Reason       = 'Excluded directory by migration rule'
                        }

                        continue
                    }

                    # Never traverse junctions, symlinks or other
                    # filesystem reparse points.
                    if (Test-ProfMigReparsePoint -Item $child) {

                        $filesSkipped++

                        $skippedItems += [PSCustomObject]@{
                            Component       = $Component
                            SourceFile      = $child.FullName
                            DestinationFile = $null
                            Reason          = 'Reparse point not traversed'
                        }

                        Write-Verbose (
                            "Skipping reparse point: $($child.FullName)"
                        )

                        continue
                    }

                    $directoryQueue.Enqueue($child.FullName)

                    continue
                }

                # -----------------------------------------------------------
                # File
                # -----------------------------------------------------------

                $relativePath = Get-ProfMigRelativePath `
                    -BasePath $SourcePath `
                    -FullPath $child.FullName

                $destinationFile = Join-Path `
                    -Path $DestinationPath `
                    -ChildPath $relativePath

                $centralFileExclusion = Test-ProfMigExclusion `
                    -RelativePath $relativePath `
                    -Application $Component

                if ($centralFileExclusion.Excluded) {

                    $filesSelected++
                    $filesExcluded++

                    $excludedItems += [PSCustomObject]@{
                        Component         = $Component
                        SourceFile        = $child.FullName
                        DestinationFile   = $destinationFile
                        RelativePath      = $relativePath
                        Reason            = $centralFileExclusion.Reason
                        ExclusionRuleId   = $centralFileExclusion.RuleId
                        ExclusionType     = $centralFileExclusion.RuleType
                        ExclusionCategory = $centralFileExclusion.Category
                        Application       = $centralFileExclusion.Application
                        Mandatory         = $centralFileExclusion.Mandatory
                    }

                    Write-Info `
                        -Message "Excluded [$($centralFileExclusion.Category)] rule $($centralFileExclusion.RuleId): $relativePath - $($centralFileExclusion.Reason)"

                    continue
                }

                $fileResult = Copy-ProfMigSingleFile `
                    -Component $Component `
                    -File $child `
                    -DestinationFile $destinationFile `
                    -RelativePath $relativePath `
                    -Exclusions $Exclusions

                $filesSelected += $fileResult.Selected
                $filesCopied   += $fileResult.Copied
                $filesSkipped  += $fileResult.Skipped
                $filesExcluded += $fileResult.Excluded
                $filesFailed   += $fileResult.Failed
                $bytesCopied   += $fileResult.BytesCopied

                if ($null -ne $fileResult.SkippedItem) {
                    $skippedItems += $fileResult.SkippedItem
                }

                if ($null -ne $fileResult.ExcludedItem) {
                    $excludedItems += $fileResult.ExcludedItem
                }

                if ($null -ne $fileResult.Error) {
                    $errors += $fileResult.Error
                }
            }
        }
    }

    # -----------------------------------------------------------------------
    # Determine status
    # -----------------------------------------------------------------------

    if ($filesFailed -gt 0) {
        $status = 'CompletedWithErrors'
    }
    elseif ($filesSkipped -gt 0) {
        $status = 'CompletedWithWarnings'
    }
    else {
        $status = 'Success'
    }

    $componentCompletedAt = Get-Date

    return [PSCustomObject]@{
        Component       = $Component
        SourcePath      = $SourcePath
        DestinationPath = $DestinationPath

        StartedAt       = $componentStartedAt
        CompletedAt     = $componentCompletedAt
        Duration        = ($componentCompletedAt - $componentStartedAt)

        FilesSelected   = $filesSelected
        FilesCopied     = $filesCopied
        FilesSkipped    = $filesSkipped
        FilesExcluded   = $filesExcluded
        FilesFailed     = $filesFailed
        BytesCopied     = $bytesCopied

        Status          = $status

        SkippedItems    = @($skippedItems)
        ExcludedItems   = @($excludedItems)
        Errors          = @($errors)
    }
}


# ---------------------------------------------------------------------------
# Public function: Invoke-ProfMigComponentCopy
# ---------------------------------------------------------------------------

function Invoke-ProfMigComponentCopy {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [Parameter()]
        [string[]]$Exclusions = @()
    )

    return Copy-ProfMigComponent `
        -Component $Component `
        -SourcePath $SourcePath `
        -DestinationPath $DestinationPath `
        -Exclusions $Exclusions
}


# ---------------------------------------------------------------------------
# Public function: Invoke-ProfMigCopy
# ---------------------------------------------------------------------------

function Invoke-ProfMigCopy {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [string]$DestinationProfile,

        [Parameter(Mandatory)]
        [hashtable]$Configuration
    )

    $migrationStartedAt = Get-Date

    # -----------------------------------------------------------------------
    # Validate profiles
    # -----------------------------------------------------------------------

    if (
        -not (
            Test-Path `
                -LiteralPath $SourceProfile `
                -PathType Container
        )
    ) {
        throw "Source profile does not exist: $SourceProfile"
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $DestinationProfile `
                -PathType Container
        )
    ) {
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
    # Read configuration
    # -----------------------------------------------------------------------

    if (
        -not $Configuration.ContainsKey('Folders') -or
        $null -eq $Configuration.Folders
    ) {
        throw "Migration configuration must contain a 'Folders' entry."
    }

    $supportedFolders = @(
            'Desktop'
            'Documents'
            'Downloads'
            'Pictures'
            'Music'
            'Videos'
            'Favorites'
            'Links'
    )

    $selectedFolders = @($Configuration.Folders)

    $exclusions = @()

    if (
        $Configuration.ContainsKey('Exclusions') -and
        $null -ne $Configuration.Exclusions
    ) {
        $exclusions = @($Configuration.Exclusions)
    }

    $additionalFolders = @()

    if (
        $Configuration.ContainsKey('AdditionalFolders') -and
        $null -ne $Configuration.AdditionalFolders
    ) {
        $additionalFolders = @($Configuration.AdditionalFolders)
    }

    # -----------------------------------------------------------------------
    # Result collections
    # -----------------------------------------------------------------------

    $components             = @()
    $migrationErrors        = @()
    $migrationSkippedItems  = @()
    $migrationExcludedItems = @()

    # -----------------------------------------------------------------------
    # Standard folders
    # -----------------------------------------------------------------------

    foreach ($folder in $selectedFolders) {

        if ($folder -notin $supportedFolders) {

            $migrationErrors += New-ProfMigCopyError `
                -Component $folder `
                -SourceFile $null `
                -DestinationFile $null `
                -ErrorMessage "Unsupported migration folder: $folder"

            continue
        }

        Write-Verbose "Starting profile component: $folder"

        $componentResult = Copy-ProfMigComponent `
            -Component $folder `
            -SourcePath (Join-Path $resolvedSource $folder) `
            -DestinationPath (Join-Path $resolvedDestination $folder) `
            -Exclusions $exclusions

        $components += $componentResult

        if ($componentResult.SkippedItems.Count -gt 0) {
            $migrationSkippedItems += $componentResult.SkippedItems
        }

        if ($componentResult.ExcludedItems.Count -gt 0) {
            $migrationExcludedItems += $componentResult.ExcludedItems
        }

        if ($componentResult.Errors.Count -gt 0) {
            $migrationErrors += $componentResult.Errors
        }
    }

    # -----------------------------------------------------------------------
    # Additional folders
    # -----------------------------------------------------------------------

    foreach ($folder in $additionalFolders) {

        if (-not (Test-ProfMigRelativeFolder -Path $folder)) {

            $migrationErrors += New-ProfMigCopyError `
                -Component $folder `
                -SourceFile $null `
                -DestinationFile $null `
                -ErrorMessage "Invalid additional folder path: $folder"

            continue
        }

        $normalizedFolder = $folder.Replace('/', '\').Trim('\')

        if ($normalizedFolder -in $selectedFolders) {

            $migrationErrors += New-ProfMigCopyError `
                -Component $normalizedFolder `
                -SourceFile $null `
                -DestinationFile $null `
                -ErrorMessage (
                    "Additional folder is already selected as a " +
                    "standard folder: $normalizedFolder"
                )

            continue
        }

        Write-Verbose "Starting additional component: $normalizedFolder"

        $componentResult = Copy-ProfMigComponent `
            -Component $normalizedFolder `
            -SourcePath (Join-Path $resolvedSource $normalizedFolder) `
            -DestinationPath (Join-Path $resolvedDestination $normalizedFolder) `
            -Exclusions $exclusions

        $components += $componentResult

        if ($componentResult.SkippedItems.Count -gt 0) {
            $migrationSkippedItems += $componentResult.SkippedItems
        }

        if ($componentResult.ExcludedItems.Count -gt 0) {
            $migrationExcludedItems += $componentResult.ExcludedItems
        }

        if ($componentResult.Errors.Count -gt 0) {
            $migrationErrors += $componentResult.Errors
        }
    }

    # -----------------------------------------------------------------------
    # Totals
    # -----------------------------------------------------------------------

    $totalFilesSelected = 0
    $totalFilesCopied   = 0
    $totalFilesSkipped  = 0
    $totalFilesExcluded = 0
    $totalFilesFailed   = 0
    $totalBytesCopied   = [int64]0

    foreach ($component in $components) {

        $totalFilesSelected += $component.FilesSelected
        $totalFilesCopied   += $component.FilesCopied
        $totalFilesSkipped  += $component.FilesSkipped
        $totalFilesExcluded += $component.FilesExcluded
        $totalFilesFailed   += $component.FilesFailed
        $totalBytesCopied   += $component.BytesCopied
    }

    $totals = [PSCustomObject]@{
        FilesSelected = $totalFilesSelected
        FilesCopied   = $totalFilesCopied
        FilesSkipped  = $totalFilesSkipped
        FilesExcluded = $totalFilesExcluded
        FilesFailed   = $totalFilesFailed
        BytesCopied   = $totalBytesCopied
    }

    # -----------------------------------------------------------------------
    # Overall status
    # -----------------------------------------------------------------------

    $failedComponents = @(
        $components |
            Where-Object {
                $_.Status -eq 'Failed' -or
                $_.Status -eq 'CompletedWithErrors'
            }
    )

    $warningComponents = @(
        $components |
            Where-Object {
                $_.Status -eq 'CompletedWithWarnings'
            }
    )

    if (
        $failedComponents.Count -gt 0 -or
        $migrationErrors.Count -gt 0
    ) {
        $overallStatus = 'CompletedWithErrors'
    }
    elseif (
        $warningComponents.Count -gt 0 -or
        $migrationSkippedItems.Count -gt 0
    ) {
        $overallStatus = 'CompletedWithWarnings'
    }
    else {
        $overallStatus = 'Success'
    }

    $migrationCompletedAt = Get-Date

    return [PSCustomObject]@{
        SourceProfile      = $resolvedSource
        DestinationProfile = $resolvedDestination

        StartedAt          = $migrationStartedAt
        CompletedAt        = $migrationCompletedAt
        Duration           = ($migrationCompletedAt - $migrationStartedAt)

        Status             = $overallStatus

        Totals             = $totals
        Components         = @($components)

        SkippedItems       = @($migrationSkippedItems)
        ExcludedItems      = @($migrationExcludedItems)
        Errors             = @($migrationErrors)
    }
}


# ---------------------------------------------------------------------------
# Public function: Invoke-ProfMigFileCopy
# ---------------------------------------------------------------------------

function Invoke-ProfMigFileCopy {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$SourceFile,

        [Parameter(Mandatory)]
        [string]$DestinationFile
    )

    $startedAt = Get-Date

    if (
        -not (
            Test-Path `
                -LiteralPath $SourceFile `
                -PathType Leaf
        )
    ) {

        $completedAt = Get-Date

        return [PSCustomObject]@{
            Component       = $Component
            SourcePath      = $SourceFile
            DestinationPath = $DestinationFile
            StartedAt       = $startedAt
            CompletedAt     = $completedAt
            Duration        = ($completedAt - $startedAt)
            FilesSelected   = 1
            FilesCopied     = 0
            FilesSkipped    = 0
            FilesExcluded   = 0
            FilesFailed     = 1
            BytesCopied     = [int64]0
            Status          = 'Failed'
            SkippedItems    = @()
            ExcludedItems   = @()
            Errors          = @(
                New-ProfMigCopyError `
                    -Component $Component `
                    -SourceFile $SourceFile `
                    -DestinationFile $DestinationFile `
                    -ErrorMessage 'Source file does not exist.'
            )
        }
    }

    try {
        $sourceItem = Get-Item `
            -LiteralPath $SourceFile `
            -Force `
            -ErrorAction Stop
    }
    catch {

        $completedAt = Get-Date

        return [PSCustomObject]@{
            Component       = $Component
            SourcePath      = $SourceFile
            DestinationPath = $DestinationFile
            StartedAt       = $startedAt
            CompletedAt     = $completedAt
            Duration        = ($completedAt - $startedAt)
            FilesSelected   = 1
            FilesCopied     = 0
            FilesSkipped    = 0
            FilesExcluded   = 0
            FilesFailed     = 1
            BytesCopied     = [int64]0
            Status          = 'Failed'
            SkippedItems    = @()
            ExcludedItems   = @()
            Errors          = @(
                New-ProfMigCopyError `
                    -Component $Component `
                    -SourceFile $SourceFile `
                    -DestinationFile $DestinationFile `
                    -ErrorMessage $_.Exception.Message
            )
        }
    }

    $relativePath = $sourceItem.Name

    $exclusionResult = Test-ProfMigExclusion `
        -RelativePath $relativePath `
        -Application $Component

    if ($exclusionResult.Excluded) {

        $completedAt = Get-Date

        $excludedItem = [PSCustomObject]@{
            Component         = $Component
            SourceFile        = $SourceFile
            DestinationFile   = $DestinationFile
            RelativePath      = $relativePath
            Reason            = $exclusionResult.Reason
            ExclusionRuleId   = $exclusionResult.RuleId
            ExclusionType     = $exclusionResult.RuleType
            ExclusionCategory = $exclusionResult.Category
            Application       = $exclusionResult.Application
            Mandatory         = $exclusionResult.Mandatory
        }

        Write-Info `
            -Message "Excluded [$($exclusionResult.Category)] rule $($exclusionResult.RuleId): $relativePath - $($exclusionResult.Reason)"

        return [PSCustomObject]@{
            Component       = $Component
            SourcePath      = $SourceFile
            DestinationPath = $DestinationFile
            StartedAt       = $startedAt
            CompletedAt     = $completedAt
            Duration        = ($completedAt - $startedAt)
            FilesSelected   = 1
            FilesCopied     = 0
            FilesSkipped    = 0
            FilesExcluded   = 1
            FilesFailed     = 0
            BytesCopied     = [int64]0
            Status          = 'Success'
            SkippedItems    = @()
            ExcludedItems   = @($excludedItem)
            Errors          = @()
        }
    }

    $fileResult = Copy-ProfMigSingleFile `
        -Component $Component `
        -File $sourceItem `
        -DestinationFile $DestinationFile `
        -RelativePath $relativePath `
        -Exclusions @()

    if ($fileResult.Failed -gt 0) {
        $status = 'CompletedWithErrors'
    }
    elseif ($fileResult.Skipped -gt 0) {
        $status = 'CompletedWithWarnings'
    }
    else {
        $status = 'Success'
    }

    $completedAt = Get-Date

    $skippedItems = @()
    if ($null -ne $fileResult.SkippedItem) {
        $skippedItems += $fileResult.SkippedItem
    }

    $excludedItems = @()
    if ($null -ne $fileResult.ExcludedItem) {
        $excludedItems += $fileResult.ExcludedItem
    }

    $errors = @()
    if ($null -ne $fileResult.Error) {
        $errors += $fileResult.Error
    }

    return [PSCustomObject]@{
        Component       = $Component
        SourcePath      = $SourceFile
        DestinationPath = $DestinationFile
        StartedAt       = $startedAt
        CompletedAt     = $completedAt
        Duration        = ($completedAt - $startedAt)
        FilesSelected   = 1
        FilesCopied     = $fileResult.Copied
        FilesSkipped    = $fileResult.Skipped
        FilesExcluded   = $fileResult.Excluded
        FilesFailed     = $fileResult.Failed
        BytesCopied     = $fileResult.BytesCopied
        Status          = $status
        SkippedItems    = @($skippedItems)
        ExcludedItems   = @($excludedItems)
        Errors          = @($errors)
    }
}


# ---------------------------------------------------------------------------
# Module exports
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Invoke-ProfMigCopy'
    'Invoke-ProfMigComponentCopy'
    'Invoke-ProfMigFileCopy'
)