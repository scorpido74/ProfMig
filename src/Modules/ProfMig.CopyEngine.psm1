<#
.SYNOPSIS
    Core copy engine for ProfMig.

.DESCRIPTION
    Provides reusable functions for copying selected user profile data
    from a source Windows profile to a destination Windows profile.

    The copy engine is independent from the interactive menu,
    future GUI, silent execution mode, and reporting implementation.

.NOTES
    Project : ProfMig
    Module  : ProfMig.CopyEngine
    Sprint  : 1.6 - Copy Engine
#>

Set-StrictMode -Version Latest


# ---------------------------------------------------------------------------
# Internal function: Test-ProfMigExclusion
# ---------------------------------------------------------------------------

function Test-ProfMigExclusion {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$RelativePath,

        [Parameter()]
        [string[]]$Exclusions = @()
    )

    foreach ($exclusion in $Exclusions) {

        if ([string]::IsNullOrWhiteSpace($exclusion)) {
            continue
        }

        if ($RelativePath -like $exclusion) {
            return $true
        }

        $fileName = Split-Path -Path $RelativePath -Leaf

        if ($fileName -like $exclusion) {
            return $true
        }

        $normalizedPath = $RelativePath.Replace('/', '\')
        $normalizedExclusion = $exclusion.Replace('/', '\').TrimEnd('\')

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

    $segments = $normalizedPath.Split('\')

    foreach ($segment in $segments) {

        if (
            $segment -eq '.' -or
            $segment -eq '..' -or
            [string]::IsNullOrWhiteSpace($segment)
        ) {
            return $false
        }
    }

    return $true
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
    $errors        = @()

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {

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
            Errors          = @()
        }
    }

    try {

        if (-not (Test-Path -LiteralPath $DestinationPath -PathType Container)) {

            New-Item `
                -Path $DestinationPath `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop | Out-Null
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
            Errors          = @(
                [PSCustomObject]@{
                    Component       = $Component
                    SourceFile      = $SourcePath
                    DestinationFile = $DestinationPath
                    Error           = $_.Exception.Message
                }
            )
        }
    }

    try {

        $files = @(
            Get-ChildItem `
                -LiteralPath $SourcePath `
                -File `
                -Recurse `
                -ErrorAction Stop
        )
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
            Errors          = @(
                [PSCustomObject]@{
                    Component       = $Component
                    SourceFile      = $SourcePath
                    DestinationFile = $DestinationPath
                    Error           = $_.Exception.Message
                }
            )
        }
    }

    foreach ($file in $files) {

        $filesSelected++

        $relativePath = $file.FullName.Substring($SourcePath.Length)
        $relativePath = $relativePath.TrimStart('\')

        $isExcluded = Test-ProfMigExclusion `
            -RelativePath $relativePath `
            -Exclusions $Exclusions

        if ($isExcluded) {
            $filesExcluded++
            continue
        }

        $destinationFile = Join-Path `
            -Path $DestinationPath `
            -ChildPath $relativePath

        $destinationDirectory = Split-Path `
            -Path $destinationFile `
            -Parent

        try {

            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {

                New-Item `
                    -Path $destinationDirectory `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop | Out-Null
            }

            # Existing-file policy:
            # never overwrite existing destination data.
            if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {
                $filesSkipped++
                continue
            }

            Copy-Item `
                -LiteralPath $file.FullName `
                -Destination $destinationFile `
                -ErrorAction Stop

            $filesCopied++
            $bytesCopied += $file.Length
        }
        catch {

            $filesFailed++

            $errors += [PSCustomObject]@{
                Component       = $Component
                SourceFile      = $file.FullName
                DestinationFile = $destinationFile
                Error           = $_.Exception.Message
            }
        }
    }

    if ($filesFailed -gt 0) {
        $status = 'CompletedWithErrors'
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
        Errors          = $errors
    }
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

    if (-not (Test-Path -LiteralPath $SourceProfile -PathType Container)) {
        throw "Source profile does not exist: $SourceProfile"
    }

    if (-not (Test-Path -LiteralPath $DestinationProfile -PathType Container)) {
        throw "Destination profile does not exist: $DestinationProfile"
    }

    $resolvedSource = (Resolve-Path -LiteralPath $SourceProfile).Path.TrimEnd('\')
    $resolvedDestination = (Resolve-Path -LiteralPath $DestinationProfile).Path.TrimEnd('\')

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

    $components = @()
    $migrationErrors = @()

    # -----------------------------------------------------------------------
    # Standard folders
    # -----------------------------------------------------------------------

    foreach ($folder in $selectedFolders) {

        if ($folder -notin $supportedFolders) {

            $migrationErrors += [PSCustomObject]@{
                Component       = $folder
                SourceFile      = $null
                DestinationFile = $null
                Error           = "Unsupported migration folder: $folder"
            }

            continue
        }

        $componentResult = Copy-ProfMigComponent `
            -Component $folder `
            -SourcePath (Join-Path $resolvedSource $folder) `
            -DestinationPath (Join-Path $resolvedDestination $folder) `
            -Exclusions $exclusions

        $components += $componentResult

        if ($componentResult.Errors.Count -gt 0) {
            $migrationErrors += $componentResult.Errors
        }
    }

    # -----------------------------------------------------------------------
    # Additional folders
    # -----------------------------------------------------------------------

    foreach ($folder in $additionalFolders) {

        if (-not (Test-ProfMigRelativeFolder -Path $folder)) {

            $migrationErrors += [PSCustomObject]@{
                Component       = $folder
                SourceFile      = $null
                DestinationFile = $null
                Error           = "Invalid additional folder path: $folder"
            }

            continue
        }

        $normalizedFolder = $folder.Replace('/', '\').Trim('\')

        if ($normalizedFolder -in $selectedFolders) {

            $migrationErrors += [PSCustomObject]@{
                Component       = $normalizedFolder
                SourceFile      = $null
                DestinationFile = $null
                Error           = "Additional folder is already selected as a standard folder: $normalizedFolder"
            }

            continue
        }

        $componentResult = Copy-ProfMigComponent `
            -Component $normalizedFolder `
            -SourcePath (Join-Path $resolvedSource $normalizedFolder) `
            -DestinationPath (Join-Path $resolvedDestination $normalizedFolder) `
            -Exclusions $exclusions

        $components += $componentResult

        if ($componentResult.Errors.Count -gt 0) {
            $migrationErrors += $componentResult.Errors
        }
    }

    # -----------------------------------------------------------------------
    # Calculate migration totals
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
    # Determine overall status
    # -----------------------------------------------------------------------

    $failedComponents = @(
        $components | Where-Object {
            $_.Status -eq 'Failed' -or
            $_.Status -eq 'CompletedWithErrors'
        }
    )

    if (
        $failedComponents.Count -gt 0 -or
        $migrationErrors.Count -gt 0
    ) {
        $overallStatus = 'CompletedWithErrors'
    }
    else {
        $overallStatus = 'Success'
    }

    $migrationCompletedAt = Get-Date

    # -----------------------------------------------------------------------
    # Return reporting-ready migration result
    # -----------------------------------------------------------------------

    return [PSCustomObject]@{
        SourceProfile      = $resolvedSource
        DestinationProfile = $resolvedDestination
        StartedAt          = $migrationStartedAt
        CompletedAt        = $migrationCompletedAt
        Duration           = ($migrationCompletedAt - $migrationStartedAt)
        Status             = $overallStatus
        Totals             = $totals
        Components         = $components
        Errors             = $migrationErrors
    }
}


Export-ModuleMember -Function Invoke-ProfMigCopy