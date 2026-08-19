<#
.SYNOPSIS
    Central pre-migration validation engine for ProfMig.

.DESCRIPTION
    Performs all required validation checks before ProfMig is allowed
    to start copying or modifying migration data.

    Validation is read-only for the source profile.

    The destination write test creates a temporary file in the destination
    and immediately removes it.

    All validation functions return structured PowerShell objects so the
    results can be consumed by:
        - CLI / Menu
        - GUI
        - Logging
        - Reporting
        - Automated tests

.NOTES
    Module  : ProfMig.Validation.psm1
    Project : ProfMig
    Sprint  : 3.1 - Pre-Migration Validation
#>

Set-StrictMode -Version Latest

# ============================================================================
# Module constants
# ============================================================================

$script:ProfMigValidationResultType  = 'ProfMig.ValidationResult'
$script:ProfMigValidationSummaryType = 'ProfMig.ValidationSummary'

# Default disk-space safety margin.
# A destination should preferably have at least 10% more free space than
# the calculated source migration size.
$script:DefaultDiskSpaceBufferPercent = 10

# When available space is sufficient, but remaining capacity after migration
# falls below this percentage, return a warning.
$script:DefaultDiskSpaceWarningPercent = 15


# ============================================================================
# Helper functions
# ============================================================================

function New-ProfMigValidationResult {
    <#
    .SYNOPSIS
        Creates a standardized ProfMig validation result object.
    #>

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

    [PSCustomObject]@{
        PSTypeName = $script:ProfMigValidationResultType
        Check      = $Check
        Status     = $Status
        Severity   = $Severity
        Message    = $Message
        Details    = $Details
        Timestamp  = Get-Date
    }
}


function Get-ProfMigNormalizedPath {
    <#
    .SYNOPSIS
        Normalizes a path for reliable path comparison.

    .DESCRIPTION
        Uses System.IO.Path.GetFullPath and removes trailing directory
        separators.

        This is compatible with Windows PowerShell 5.1.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)

        $fullPath = [System.IO.Path]::GetFullPath($expandedPath)

        $normalized = $fullPath.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        )

        return $normalized
    }
    catch {
        throw "Unable to normalize path '$Path': $($_.Exception.Message)"
    }
}


function Get-ProfMigDirectorySize {
    <#
    .SYNOPSIS
        Calculates the total size of accessible files below a directory.

    .DESCRIPTION
        Files that cannot be read are skipped.

        The function does not modify source data.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Directory does not exist: $Path"
    }

    [Int64]$totalBytes = 0
    [Int64]$fileCount  = 0

    try {
        $files = Get-ChildItem `
            -LiteralPath $Path `
            -File `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            try {
                $totalBytes += [Int64]$file.Length
                $fileCount++
            }
            catch {
                # Individual inaccessible files are ignored here.
                # Accessibility validation is handled separately.
            }
        }
    }
    catch {
        throw "Unable to calculate directory size for '$Path': $($_.Exception.Message)"
    }

    [PSCustomObject]@{
        Path       = $Path
        TotalBytes = $totalBytes
        FileCount  = $fileCount
    }
}


function Get-ProfMigDriveFreeSpace {
    <#
    .SYNOPSIS
        Returns free and total space for the drive containing a path.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $normalizedPath = Get-ProfMigNormalizedPath -Path $Path

        $root = [System.IO.Path]::GetPathRoot($normalizedPath)

        if ([string]::IsNullOrWhiteSpace($root)) {
            throw "Unable to determine drive root."
        }

        $driveInfo = New-Object System.IO.DriveInfo($root)

        if (-not $driveInfo.IsReady) {
            throw "Drive '$root' is not ready."
        }

        [PSCustomObject]@{
            Root           = $root
            AvailableBytes = [Int64]$driveInfo.AvailableFreeSpace
            TotalBytes     = [Int64]$driveInfo.TotalSize
        }
    }
    catch {
        throw "Unable to determine free disk space for '$Path': $($_.Exception.Message)"
    }
}


function ConvertTo-ProfMigReadableSize {
    <#
    .SYNOPSIS
        Converts bytes to a human-readable string.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Int64]$Bytes
    )

    if ($Bytes -ge 1TB) {
        return ('{0:N2} TB' -f ($Bytes / 1TB))
    }

    if ($Bytes -ge 1GB) {
        return ('{0:N2} GB' -f ($Bytes / 1GB))
    }

    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }

    if ($Bytes -ge 1KB) {
        return ('{0:N2} KB' -f ($Bytes / 1KB))
    }

    return "$Bytes bytes"
}


function Test-ProfMigIsAdministrator {
    <#
    .SYNOPSIS
        Determines whether the current process has administrative privileges.
    #>

    [CmdletBinding()]
    param ()

    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

        $principal = New-Object Security.Principal.WindowsPrincipal($identity)

        return $principal.IsInRole(
            [Security.Principal.WindowsBuiltInRole]::Administrator
        )
    }
    catch {
        return $false
    }
}


# ============================================================================
# Source validation
# ============================================================================

function Test-ProfMigSourceProfile {
    <#
    .SYNOPSIS
        Verifies that the source profile exists.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {

            return New-ProfMigValidationResult `
                -Check 'SourceProfile' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "Source profile does not exist: $Path" `
                -Details @{
                    Path = $Path
                }
        }

        return New-ProfMigValidationResult `
            -Check 'SourceProfile' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'Source profile exists.' `
            -Details @{
                Path = (Get-ProfMigNormalizedPath -Path $Path)
            }
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'SourceProfile' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to validate source profile: $($_.Exception.Message)" `
            -Details @{
                Path = $Path
            }
    }
}


function Test-ProfMigSourceAccessibility {
    <#
    .SYNOPSIS
        Verifies that required source profile directories are accessible.

    .DESCRIPTION
        The function only reads the source.

        By default several standard Windows profile directories are checked
        if they exist.

        Missing optional profile directories do not fail validation.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [string[]]$RequiredDirectories = @(
            'Desktop',
            'Documents',
            'Downloads',
            'Favorites',
            'AppData'
        )
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {

        return New-ProfMigValidationResult `
            -Check 'SourceAccessibility' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message 'Source accessibility cannot be validated because the source profile does not exist.' `
            -Details @{
                Path = $Path
            }
    }

    $checked      = @()
    $inaccessible = @()

    foreach ($directory in $RequiredDirectories) {

        $directoryPath = Join-Path $Path $directory

        if (-not (Test-Path -LiteralPath $directoryPath -PathType Container)) {
            continue
        }

        try {
            $null = Get-ChildItem `
                -LiteralPath $directoryPath `
                -Force `
                -ErrorAction Stop |
                Select-Object -First 1

            $checked += $directory
        }
        catch {
            $inaccessible += [PSCustomObject]@{
                Directory = $directory
                Path      = $directoryPath
                Error     = $_.Exception.Message
            }
        }
    }

    if ($inaccessible.Count -gt 0) {

        return New-ProfMigValidationResult `
            -Check 'SourceAccessibility' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "$($inaccessible.Count) source profile director$(if ($inaccessible.Count -eq 1) {'y is'} else {'ies are'}) not accessible." `
            -Details @{
                Checked      = $checked
                Inaccessible = $inaccessible
            }
    }

    return New-ProfMigValidationResult `
        -Check 'SourceAccessibility' `
        -Status 'Passed' `
        -Severity 'Critical' `
        -Message 'Required source profile directories are accessible.' `
        -Details @{
            CheckedDirectories = $checked
        }
}


# ============================================================================
# Destination validation
# ============================================================================

function Test-ProfMigDestinationProfile {
    <#
    .SYNOPSIS
        Verifies that the destination profile exists or can be used.

    .DESCRIPTION
        If the destination already exists it is considered valid at this
        stage.

        If it does not exist, its parent directory must exist and be
        accessible.

        The function does not create the destination.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {

        if (Test-Path -LiteralPath $Path -PathType Container) {

            return New-ProfMigValidationResult `
                -Check 'DestinationProfile' `
                -Status 'Passed' `
                -Severity 'Critical' `
                -Message 'Destination profile exists.' `
                -Details @{
                    Path   = (Get-ProfMigNormalizedPath -Path $Path)
                    Exists = $true
                }
        }

        $normalizedPath = Get-ProfMigNormalizedPath -Path $Path

        $parentPath = Split-Path -Path $normalizedPath -Parent

        if ([string]::IsNullOrWhiteSpace($parentPath)) {

            return New-ProfMigValidationResult `
                -Check 'DestinationProfile' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "Destination profile path is invalid: $Path" `
                -Details @{
                    Path = $Path
                }
        }

        if (-not (Test-Path -LiteralPath $parentPath -PathType Container)) {

            return New-ProfMigValidationResult `
                -Check 'DestinationProfile' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "Destination profile does not exist and its parent directory is unavailable: $parentPath" `
                -Details @{
                    Path       = $Path
                    ParentPath = $parentPath
                }
        }

        return New-ProfMigValidationResult `
            -Check 'DestinationProfile' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'Destination profile does not yet exist but the destination path is valid for migration.' `
            -Details @{
                Path       = $normalizedPath
                ParentPath = $parentPath
                Exists     = $false
            }
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'DestinationProfile' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to validate destination profile: $($_.Exception.Message)" `
            -Details @{
                Path = $Path
            }
    }
}


function Test-ProfMigDestinationWritable {
    <#
    .SYNOPSIS
        Verifies write access to the destination.

    .DESCRIPTION
        Creates a temporary validation file and immediately removes it.

        If the destination profile does not yet exist, the test is performed
        in its parent directory.

        No source data is modified.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $testPath = $null

    try {

        if (Test-Path -LiteralPath $Path -PathType Container) {
            $writeTarget = $Path
        }
        else {

            $normalizedPath = Get-ProfMigNormalizedPath -Path $Path

            $writeTarget = Split-Path -Path $normalizedPath -Parent

            if (-not (Test-Path -LiteralPath $writeTarget -PathType Container)) {

                return New-ProfMigValidationResult `
                    -Check 'DestinationWritable' `
                    -Status 'Failed' `
                    -Severity 'Critical' `
                    -Message 'Destination write access cannot be tested because the destination parent directory does not exist.' `
                    -Details @{
                        Path        = $Path
                        WriteTarget = $writeTarget
                    }
            }
        }

        $testFileName = '.profmig-validation-{0}.tmp' -f (
            [Guid]::NewGuid().ToString('N')
        )

        $testPath = Join-Path $writeTarget $testFileName

        [System.IO.File]::WriteAllText(
            $testPath,
            'ProfMig destination write validation'
        )

        if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
            throw 'Temporary validation file was not created successfully.'
        }

        Remove-Item `
            -LiteralPath $testPath `
            -Force `
            -ErrorAction Stop

        $testPath = $null

        return New-ProfMigValidationResult `
            -Check 'DestinationWritable' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'Destination is writable.' `
            -Details @{
                Path        = $Path
                WriteTarget = $writeTarget
            }
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'DestinationWritable' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Destination is not writable: $($_.Exception.Message)" `
            -Details @{
                Path = $Path
            }
    }
    finally {

        if (
            $null -ne $testPath -and
            (Test-Path -LiteralPath $testPath -PathType Leaf)
        ) {
            Remove-Item `
                -LiteralPath $testPath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}


# ============================================================================
# Source / destination relationship
# ============================================================================

function Test-ProfMigProfilesDiffer {
    <#
    .SYNOPSIS
        Verifies that source and destination are not the same profile.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfile
    )

    try {

        $source = Get-ProfMigNormalizedPath -Path $SourceProfile

        $destination = Get-ProfMigNormalizedPath -Path $DestinationProfile

        if ($source -ieq $destination) {

            return New-ProfMigValidationResult `
                -Check 'ProfilesDiffer' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message 'Source and destination profiles are the same.' `
                -Details @{
                    Source      = $source
                    Destination = $destination
                }
        }

        return New-ProfMigValidationResult `
            -Check 'ProfilesDiffer' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'Source and destination profiles are different.' `
            -Details @{
                Source      = $source
                Destination = $destination
            }
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'ProfilesDiffer' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to compare source and destination profiles: $($_.Exception.Message)"
    }
}


# ============================================================================
# Privilege validation
# ============================================================================

function Test-ProfMigPrivileges {
    <#
    .SYNOPSIS
        Verifies that ProfMig is running with sufficient privileges.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$AdministratorRequired = $true
    )

    if (-not $AdministratorRequired) {

        return New-ProfMigValidationResult `
            -Check 'Privileges' `
            -Status 'Passed' `
            -Severity 'Information' `
            -Message 'Administrative privileges are not required by the current migration configuration.'
    }

    if (Test-ProfMigIsAdministrator) {

        return New-ProfMigValidationResult `
            -Check 'Privileges' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'ProfMig is running with administrative privileges.' `
            -Details @{
                IsAdministrator = $true
                Identity        = [Security.Principal.WindowsIdentity]::GetCurrent().Name
            }
    }

    return New-ProfMigValidationResult `
        -Check 'Privileges' `
        -Status 'Failed' `
        -Severity 'Critical' `
        -Message 'ProfMig is not running with administrative privileges.' `
        -Details @{
            IsAdministrator = $false
            Identity        = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        }
}


# ============================================================================
# Configuration validation
# ============================================================================

function Test-ProfMigConfiguration {
    <#
    .SYNOPSIS
        Performs central validation of the ProfMig configuration.

    .DESCRIPTION
        Accepts any configuration object or hashtable.

        The function deliberately performs only central checks here so
        configuration validation is not duplicated across modules.

        Additional required settings can be supplied using
        RequiredProperties.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [AllowNull()]
        [object]$Configuration,

        [Parameter()]
        [string[]]$RequiredProperties = @()
    )

    if ($null -eq $Configuration) {

        if ($RequiredProperties.Count -gt 0) {

            return New-ProfMigValidationResult `
                -Check 'Configuration' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message 'Required ProfMig configuration is missing.' `
                -Details @{
                    RequiredProperties = $RequiredProperties
                }
        }

        return New-ProfMigValidationResult `
            -Check 'Configuration' `
            -Status 'Passed' `
            -Severity 'Information' `
            -Message 'No mandatory configuration properties were specified.'
    }

    $missingProperties = @()

    foreach ($propertyName in $RequiredProperties) {

        $valueFound = $false
        $value      = $null

        if ($Configuration -is [System.Collections.IDictionary]) {

            if ($Configuration.Contains($propertyName)) {
                $valueFound = $true
                $value = $Configuration[$propertyName]
            }
        }
        else {

            $property = $Configuration.PSObject.Properties[$propertyName]

            if ($null -ne $property) {
                $valueFound = $true
                $value = $property.Value
            }
        }

        if (
            -not $valueFound -or
            $null -eq $value -or
            (
                $value -is [string] -and
                [string]::IsNullOrWhiteSpace($value)
            )
        ) {
            $missingProperties += $propertyName
        }
    }

    if ($missingProperties.Count -gt 0) {

        return New-ProfMigValidationResult `
            -Check 'Configuration' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message 'Required ProfMig configuration is incomplete or invalid.' `
            -Details @{
                MissingProperties = $missingProperties
            }
    }

    return New-ProfMigValidationResult `
        -Check 'Configuration' `
        -Status 'Passed' `
        -Severity 'Critical' `
        -Message 'Required ProfMig configuration is valid.' `
        -Details @{
            RequiredProperties = $RequiredProperties
        }
}


# ============================================================================
# Storage validation
# ============================================================================

function Test-ProfMigDiskSpace {
    <#
    .SYNOPSIS
        Verifies that sufficient destination disk space is available.

    .DESCRIPTION
        Calculates source profile size and adds a configurable safety margin.

        Results:
            Passed
                Sufficient capacity with healthy remaining space.

            Warning
                Sufficient capacity, but remaining free space is close
                to the configured threshold.

            Failed / Critical
                Not enough destination capacity.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfile,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$BufferPercent = $script:DefaultDiskSpaceBufferPercent,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$WarningRemainingPercent = $script:DefaultDiskSpaceWarningPercent,

        [Parameter()]
        [Nullable[Int64]]$RequiredBytes
    )

    try {

        if ($null -ne $RequiredBytes) {

            $sourceBytes = [Int64]$RequiredBytes
            $sourceFileCount = $null
        }
        else {

            $sourceSize = Get-ProfMigDirectorySize -Path $SourceProfile

            $sourceBytes = [Int64]$sourceSize.TotalBytes
            $sourceFileCount = $sourceSize.FileCount
        }

        if (Test-Path -LiteralPath $DestinationProfile) {
            $spaceCheckPath = $DestinationProfile
        }
        else {
            $spaceCheckPath = Split-Path `
                -Path (Get-ProfMigNormalizedPath -Path $DestinationProfile) `
                -Parent
        }

        $driveSpace = Get-ProfMigDriveFreeSpace -Path $spaceCheckPath

        [Int64]$bufferBytes = [Math]::Ceiling(
            $sourceBytes * ($BufferPercent / 100)
        )

        [Int64]$requiredWithBuffer = $sourceBytes + $bufferBytes

        [Int64]$availableBytes = $driveSpace.AvailableBytes

        $freeAfterMigration = $availableBytes - $requiredWithBuffer

        [Int64]$displayFreeAfterMigration = 0

if ($freeAfterMigration -gt 0) {
    $displayFreeAfterMigration = [Int64]$freeAfterMigration
}

        if ($driveSpace.TotalBytes -gt 0) {

            $remainingPercent = (
                $freeAfterMigration /
                $driveSpace.TotalBytes
            ) * 100
        }
        else {
            $remainingPercent = 0
        }

        $details = @{
            SourceBytes               = $sourceBytes
            SourceSize                = ConvertTo-ProfMigReadableSize -Bytes $sourceBytes
            SourceFileCount           = $sourceFileCount
            BufferPercent             = $BufferPercent
            BufferBytes               = $bufferBytes
            RequiredBytes             = $requiredWithBuffer
            RequiredSize              = ConvertTo-ProfMigReadableSize -Bytes $requiredWithBuffer
            AvailableBytes            = $availableBytes
            AvailableSize             = ConvertTo-ProfMigReadableSize -Bytes $availableBytes
            FreeAfterMigrationBytes   = $freeAfterMigration
            FreeAfterMigration = ConvertTo-ProfMigReadableSize -Bytes $displayFreeAfterMigration
            RemainingPercent          = [Math]::Round($remainingPercent, 2)
            DestinationDrive          = $driveSpace.Root
            DestinationDriveTotalSize = ConvertTo-ProfMigReadableSize -Bytes $driveSpace.TotalBytes
        }

        if ($availableBytes -lt $requiredWithBuffer) {

            $shortage = $requiredWithBuffer - $availableBytes

            $details['ShortageBytes'] = $shortage
            $details['Shortage'] = ConvertTo-ProfMigReadableSize -Bytes $shortage

            return New-ProfMigValidationResult `
                -Check 'FreeDiskSpace' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message "Insufficient destination disk space. Required: $(ConvertTo-ProfMigReadableSize -Bytes $requiredWithBuffer). Available: $(ConvertTo-ProfMigReadableSize -Bytes $availableBytes)." `
                -Details $details
        }

        if ($remainingPercent -lt $WarningRemainingPercent) {

            return New-ProfMigValidationResult `
                -Check 'FreeDiskSpace' `
                -Status 'Warning' `
                -Severity 'Warning' `
                -Message "Destination has sufficient capacity, but remaining disk space after migration is estimated at $([Math]::Round($remainingPercent, 1))%." `
                -Details $details
        }

        return New-ProfMigValidationResult `
            -Check 'FreeDiskSpace' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message "Sufficient destination disk space is available. Required: $(ConvertTo-ProfMigReadableSize -Bytes $requiredWithBuffer). Available: $(ConvertTo-ProfMigReadableSize -Bytes $availableBytes)." `
            -Details $details
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'FreeDiskSpace' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to validate destination disk space: $($_.Exception.Message)"
    }
}


# ============================================================================
# Critical condition validation
# ============================================================================

function Test-ProfMigCriticalConditions {
    <#
    .SYNOPSIS
        Performs additional central safety checks.

    .DESCRIPTION
        This function provides a central location for ProfMig-wide blocking
        conditions that do not belong to one specific migration component.

        More checks can be added here during future sprints.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfile
    )

    try {

        $source = Get-ProfMigNormalizedPath -Path $SourceProfile
        $destination = Get-ProfMigNormalizedPath -Path $DestinationProfile

        #
        # Protect Windows system locations from accidentally being used
        # as profile roots.
        #
        $protectedPaths = @()

        if (-not [string]::IsNullOrWhiteSpace($env:SystemRoot)) {
            $protectedPaths += Get-ProfMigNormalizedPath -Path $env:SystemRoot
        }

        if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
            $protectedPaths += Get-ProfMigNormalizedPath -Path $env:ProgramFiles
        }

        if (-not [string]::IsNullOrWhiteSpace(${env:ProgramFiles(x86)})) {
            $protectedPaths += Get-ProfMigNormalizedPath -Path ${env:ProgramFiles(x86)}
        }

        foreach ($protectedPath in $protectedPaths) {

            if (
                $source -ieq $protectedPath -or
                $destination -ieq $protectedPath
            ) {

                return New-ProfMigValidationResult `
                    -Check 'CriticalConditions' `
                    -Status 'Failed' `
                    -Severity 'Critical' `
                    -Message "A protected Windows system directory was selected as a migration profile: $protectedPath" `
                    -Details @{
                        ProtectedPath = $protectedPath
                    }
            }
        }

        #
        # Prevent a destination from being located inside the source.
        #
        $sourcePrefix = $source + [System.IO.Path]::DirectorySeparatorChar

        if ($destination.StartsWith(
            $sourcePrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {

            return New-ProfMigValidationResult `
                -Check 'CriticalConditions' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message 'Destination profile is located inside the source profile.' `
                -Details @{
                    Source      = $source
                    Destination = $destination
                }
        }

        #
        # Prevent the source from being located inside the destination.
        #
        $destinationPrefix = $destination + [System.IO.Path]::DirectorySeparatorChar

        if ($source.StartsWith(
            $destinationPrefix,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {

            return New-ProfMigValidationResult `
                -Check 'CriticalConditions' `
                -Status 'Failed' `
                -Severity 'Critical' `
                -Message 'Source profile is located inside the destination profile.' `
                -Details @{
                    Source      = $source
                    Destination = $destination
                }
        }

        return New-ProfMigValidationResult `
            -Check 'CriticalConditions' `
            -Status 'Passed' `
            -Severity 'Critical' `
            -Message 'No known critical condition prevents migration.'
    }
    catch {

        return New-ProfMigValidationResult `
            -Check 'CriticalConditions' `
            -Status 'Failed' `
            -Severity 'Critical' `
            -Message "Unable to evaluate critical migration conditions: $($_.Exception.Message)"
    }
}


# ============================================================================
# Logging integration
# ============================================================================

function Write-ProfMigValidationLog {
    <#
    .SYNOPSIS
        Writes validation results to the ProfMig logging system when available.

    .DESCRIPTION
        This function does not implement a second logging framework.

        If Write-ProfMigLog exists, it is used.

        If logging is unavailable, validation continues and structured
        objects are still returned.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $logCommand = Get-Command `
        -Name 'Write-ProfMigLog' `
        -ErrorAction SilentlyContinue

    if ($null -eq $logCommand) {
        return
    }

    foreach ($result in $Results) {

        switch ($result.Status) {

            'Passed' {
                $level = 'Information'
            }

            'Warning' {
                $level = 'Warning'
            }

            'Failed' {
                $level = 'Error'
            }

            default {
                $level = 'Information'
            }
        }

        $message = '[Validation] {0}: {1} | Status={2} | Severity={3}' -f `
            $result.Check,
            $result.Message,
            $result.Status,
            $result.Severity

        try {

            & $logCommand `
                -Level $level `
                -Message $message
        }
        catch {
            #
            # Logging failure must not hide or replace validation results.
            #
        }
    }
}


# ============================================================================
# Validation summary
# ============================================================================

function New-ProfMigValidationSummary {
    <#
    .SYNOPSIS
        Creates the final ProfMig validation summary.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$Results
    )

    $passed = @(
        $Results |
        Where-Object {
            $_.Status -eq 'Passed'
        }
    )

    $warnings = @(
        $Results |
        Where-Object {
            $_.Status -eq 'Warning'
        }
    )

    $failed = @(
        $Results |
        Where-Object {
            $_.Status -eq 'Failed'
        }
    )

    $criticalFailures = @(
        $Results |
        Where-Object {
            $_.Status -eq 'Failed' -and
            $_.Severity -eq 'Critical'
        }
    )

    [PSCustomObject]@{
        PSTypeName       = $script:ProfMigValidationSummaryType

        CanProceed       = ($criticalFailures.Count -eq 0)
        HasWarnings      = ($warnings.Count -gt 0)
        HasFailures      = ($failed.Count -gt 0)

        TotalChecks      = $Results.Count
        PassedCount      = $passed.Count
        WarningCount     = $warnings.Count
        FailedCount      = $failed.Count
        CriticalFailures = $criticalFailures.Count

        Results          = $Results

        Timestamp        = Get-Date
    }
}


# ============================================================================
# Central validation engine
# ============================================================================

function Invoke-ProfMigPreMigrationValidation {
    <#
    .SYNOPSIS
        Runs all ProfMig pre-migration validation checks.

    .DESCRIPTION
        This is the central entry point for ProfMig pre-migration validation.

        The copy engine or migration orchestrator should call this function
        before any migration data is copied.

        Critical failures result in:

            CanProceed = $false

        Warnings result in:

            CanProceed  = $true
            HasWarnings = $true

        The function itself does not prompt the administrator.

        User interaction belongs in the menu or GUI layer.

    .EXAMPLE
        $validation = Invoke-ProfMigPreMigrationValidation `
            -SourceProfile 'C:\Users\OldUser' `
            -DestinationProfile 'C:\Users\NewUser'

        if (-not $validation.CanProceed) {
            return
        }

    .EXAMPLE
        $validation = Invoke-ProfMigPreMigrationValidation `
            -SourceProfile 'C:\Users\OldUser' `
            -DestinationProfile 'C:\Users\NewUser'

        $validation.Results |
            Format-Table Check, Status, Severity, Message
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfile,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfile,

        [Parameter()]
        [AllowNull()]
        [object]$Configuration = $null,

        [Parameter()]
        [string[]]$RequiredConfigurationProperties = @(),

        [Parameter()]
        [string[]]$RequiredSourceDirectories = @(
            'Desktop',
            'Documents',
            'Downloads',
            'Favorites',
            'AppData'
        ),

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$DiskSpaceBufferPercent = $script:DefaultDiskSpaceBufferPercent,

        [Parameter()]
        [ValidateRange(0, 100)]
        [int]$DiskSpaceWarningPercent = $script:DefaultDiskSpaceWarningPercent,

        [Parameter()]
        [Nullable[Int64]]$RequiredMigrationBytes,

        [Parameter()]
        [switch]$SkipPrivilegeCheck,

        [Parameter()]
        [switch]$SkipDiskSpaceCheck,

        [Parameter()]
        [switch]$SkipLogging
    )

    $results = New-Object System.Collections.Generic.List[object]

    #
    # 1. Source profile
    #
    $results.Add(
        (
            Test-ProfMigSourceProfile `
                -Path $SourceProfile
        )
    )

    #
    # 2. Destination profile
    #
    $results.Add(
        (
            Test-ProfMigDestinationProfile `
                -Path $DestinationProfile
        )
    )

    #
    # 3. Source and destination must differ
    #
    $results.Add(
        (
            Test-ProfMigProfilesDiffer `
                -SourceProfile $SourceProfile `
                -DestinationProfile $DestinationProfile
        )
    )

    #
    # 4. Source accessibility
    #
    $results.Add(
        (
            Test-ProfMigSourceAccessibility `
                -Path $SourceProfile `
                -RequiredDirectories $RequiredSourceDirectories
        )
    )

    #
    # 5. Destination write access
    #
    $results.Add(
        (
            Test-ProfMigDestinationWritable `
                -Path $DestinationProfile
        )
    )

    #
    # 6. Privileges
    #
    if (-not $SkipPrivilegeCheck) {

        $results.Add(
            (
                Test-ProfMigPrivileges
            )
        )
    }
    else {

        $results.Add(
            (
                New-ProfMigValidationResult `
                    -Check 'Privileges' `
                    -Status 'Passed' `
                    -Severity 'Information' `
                    -Message 'Privilege validation was skipped by configuration.'
            )
        )
    }

    #
    # 7. ProfMig configuration
    #
    $results.Add(
        (
            Test-ProfMigConfiguration `
                -Configuration $Configuration `
                -RequiredProperties $RequiredConfigurationProperties
        )
    )

    #
    # 8. Disk capacity
    #
    if (-not $SkipDiskSpaceCheck) {

        $diskParameters = @{
            SourceProfile           = $SourceProfile
            DestinationProfile      = $DestinationProfile
            BufferPercent           = $DiskSpaceBufferPercent
            WarningRemainingPercent = $DiskSpaceWarningPercent
        }

        if ($null -ne $RequiredMigrationBytes) {
            $diskParameters['RequiredBytes'] = $RequiredMigrationBytes
        }

        $results.Add(
            (
                Test-ProfMigDiskSpace @diskParameters
            )
        )
    }
    else {

        $results.Add(
            (
                New-ProfMigValidationResult `
                    -Check 'FreeDiskSpace' `
                    -Status 'Passed' `
                    -Severity 'Information' `
                    -Message 'Disk space validation was skipped by configuration.'
            )
        )
    }

    #
    # 9. Additional safety conditions
    #
    $results.Add(
        (
            Test-ProfMigCriticalConditions `
                -SourceProfile $SourceProfile `
                -DestinationProfile $DestinationProfile
        )
    )

    #
    # Logging
    #
    if (-not $SkipLogging) {

        Write-ProfMigValidationLog `
            -Results $results.ToArray()
    }

    #
    # Final summary
    #
    return New-ProfMigValidationSummary `
        -Results $results.ToArray()
}


# ============================================================================
# Migration gate
# ============================================================================

function Assert-ProfMigMigrationAllowed {
    <#
    .SYNOPSIS
        Provides a reusable hard gate before the copy engine starts.

    .DESCRIPTION
        Throws when the validation summary contains one or more critical
        failures.

        This function should be called immediately before migration execution.

        It accepts the structured summary generated by
        Invoke-ProfMigPreMigrationValidation.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ValidationSummary
    )

    if ($null -eq $ValidationSummary) {
        throw 'Migration cannot start because no validation summary was provided.'
    }

    if (
        $null -eq $ValidationSummary.PSObject.Properties['CanProceed']
    ) {
        throw 'Migration cannot start because the validation summary is invalid.'
    }

    if (-not $ValidationSummary.CanProceed) {

        $failedChecks = @(
            $ValidationSummary.Results |
            Where-Object {
                $_.Status -eq 'Failed' -and
                $_.Severity -eq 'Critical'
            } |
            ForEach-Object {
                '{0}: {1}' -f $_.Check, $_.Message
            }
        )

        $message = 'Pre-migration validation failed. Migration has been blocked.'

        if ($failedChecks.Count -gt 0) {
            $message += ' Critical failure(s): ' + ($failedChecks -join ' | ')
        }

        throw $message
    }

    return $true
}


# ============================================================================
# Reporting helper
# ============================================================================

function ConvertTo-ProfMigValidationReport {
    <#
    .SYNOPSIS
        Converts a validation summary into a reporting-friendly object.

    .DESCRIPTION
        The returned object can be consumed directly by a future ProfMig
        reporting engine without introducing reporting logic inside the
        validation checks.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ValidationSummary
    )

    if ($null -eq $ValidationSummary) {
        throw 'Validation summary cannot be null.'
    }

    $reportResults = @(
        foreach ($result in $ValidationSummary.Results) {

            [PSCustomObject]@{
                Check     = $result.Check
                Status    = $result.Status
                Severity  = $result.Severity
                Message   = $result.Message
                Details   = $result.Details
                Timestamp = $result.Timestamp
            }
        }
    )

    [PSCustomObject]@{
        PSTypeName       = 'ProfMig.ValidationReport'
        CanProceed       = $ValidationSummary.CanProceed
        HasWarnings      = $ValidationSummary.HasWarnings
        TotalChecks      = $ValidationSummary.TotalChecks
        PassedCount      = $ValidationSummary.PassedCount
        WarningCount     = $ValidationSummary.WarningCount
        FailedCount      = $ValidationSummary.FailedCount
        CriticalFailures = $ValidationSummary.CriticalFailures
        Results          = $reportResults
        Timestamp        = Get-Date
    }
}


# ============================================================================
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'New-ProfMigValidationResult',
    'Test-ProfMigSourceProfile',
    'Test-ProfMigDestinationProfile',
    'Test-ProfMigProfilesDiffer',
    'Test-ProfMigSourceAccessibility',
    'Test-ProfMigDestinationWritable',
    'Test-ProfMigPrivileges',
    'Test-ProfMigConfiguration',
    'Test-ProfMigDiskSpace',
    'Test-ProfMigCriticalConditions',
    'Invoke-ProfMigPreMigrationValidation',
    'Assert-ProfMigMigrationAllowed',
    'ConvertTo-ProfMigValidationReport'
)