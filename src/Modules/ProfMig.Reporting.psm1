<#
.SYNOPSIS
    Migration reporting engine for ProfMig.

.DESCRIPTION
    Converts structured migration results produced by the ProfMig
    Copy Engine into a reporting result and generates a human-readable
    migration report.

    This module does not perform migration operations.

    Reporting data remains structured so it can later be reused by
    GUI components, automation, machine-readable output and
    centralized reporting.

.NOTES
    Project : ProfMig
    Module  : ProfMig.Reporting
    Sprint  : 1.7 - Reporting
#>

Set-StrictMode -Version Latest


# ---------------------------------------------------------------------------
# Internal function: Format-ProfMigReportItem
# ---------------------------------------------------------------------------

function Format-ProfMigReportItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$Item,

        [Parameter(Mandatory)]
        [ValidateSet('Skipped', 'Excluded', 'Failed')]
        [string]$Type
    )

    # -----------------------------------------------------------------------
    # Normalize properties
    #
    # Items can originate from different migration providers. Not every
    # provider exposes the same properties. All property access must
    # therefore be safe when StrictMode is enabled.
    # -----------------------------------------------------------------------

    $component = if (
        $Item.PSObject.Properties.Name -contains 'Component' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Component)
    ) {
        [string]$Item.Component
    }
    elseif (
        $Item.PSObject.Properties.Name -contains 'Application' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Application)
    ) {
        [string]$Item.Application
    }
    else {
        'Unknown'
    }

    $source = if (
        $Item.PSObject.Properties.Name -contains 'SourceFile' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.SourceFile)
    ) {
        [string]$Item.SourceFile
    }
    elseif (
        $Item.PSObject.Properties.Name -contains 'Path' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Path)
    ) {
        [string]$Item.Path
    }
    else {
        'Unknown'
    }

    $destination = if (
        $Item.PSObject.Properties.Name -contains 'DestinationFile' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.DestinationFile)
    ) {
        [string]$Item.DestinationFile
    }
    elseif (
        $Item.PSObject.Properties.Name -contains 'Destination' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Destination)
    ) {
        [string]$Item.Destination
    }
    else {
        'Unknown'
    }

    $reason = if (
        $Item.PSObject.Properties.Name -contains 'Reason' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Reason)
    ) {
        [string]$Item.Reason
    }
    elseif (
        $Item.PSObject.Properties.Name -contains 'Message' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Message)
    ) {
        [string]$Item.Message
    }
    else {
        'Unknown'
    }

    $errorMessage = if (
        $Item.PSObject.Properties.Name -contains 'Error' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Error)
    ) {
        [string]$Item.Error
    }
    elseif (
        $Item.PSObject.Properties.Name -contains 'Message' -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Message)
    ) {
        [string]$Item.Message
    }
    else {
        'Unknown error'
    }

    # -----------------------------------------------------------------------
    # Format item
    # -----------------------------------------------------------------------

    switch ($Type) {

        'Skipped' {

            return @"
- Component   : $component
  Source      : $source
  Destination : $destination
  Reason      : $reason
"@
        }

        'Excluded' {

            return @"
- Component : $component
  Source    : $source
  Reason    : $reason
"@
        }

        'Failed' {

            return @"
- Component   : $component
  Source      : $source
  Destination : $destination
  Error       : $errorMessage
"@
        }
    }
}

# ---------------------------------------------------------------------------
# Internal function: Get-ProfMigApplicationReportMetrics
# ---------------------------------------------------------------------------

function Get-ProfMigApplicationReportMetrics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$ApplicationResult
    )

    $providerResult = $ApplicationResult.Result

    $metrics = [ordered]@{
        FilesSelected = [int64]0
        FilesCopied   = [int64]0
        FilesSkipped  = [int64]0
        FilesExcluded = [int64]0
        FilesFailed   = [int64]0
        BytesCopied   = [int64]0
    }

    if (
        $null -ne $providerResult -and
        $providerResult.PSObject.Properties.Name -contains 'Totals' -and
        $null -ne $providerResult.Totals
    ) {
        foreach ($propertyName in @(
            'FilesSelected'
            'FilesCopied'
            'FilesSkipped'
            'FilesExcluded'
            'FilesFailed'
            'BytesCopied'
        )) {
            if (
                $providerResult.Totals.PSObject.Properties.Name -contains
                $propertyName
            ) {
                $metrics[$propertyName] =
                    [int64]$providerResult.Totals.$propertyName
            }
        }
    }
    elseif ($null -ne $providerResult) {
        foreach ($propertyName in @(
            'FilesSelected'
            'FilesCopied'
            'FilesSkipped'
            'FilesExcluded'
            'FilesFailed'
            'BytesCopied'
        )) {
            if (
                $providerResult.PSObject.Properties.Name -contains
                $propertyName
            ) {
                $metrics[$propertyName] =
                    [int64]$providerResult.$propertyName
            }
        }
    }

    if (
        $metrics.FilesCopied -eq 0 -and
        $ApplicationResult.PSObject.Properties.Name -contains 'FilesCopied'
    ) {
        $metrics.FilesCopied = [int64]$ApplicationResult.FilesCopied
    }

    if (
        $metrics.FilesFailed -eq 0 -and
        $ApplicationResult.PSObject.Properties.Name -contains 'FilesFailed'
    ) {
        $metrics.FilesFailed = [int64]$ApplicationResult.FilesFailed
    }

    return [PSCustomObject]$metrics
}

# ---------------------------------------------------------------------------
# Public function: ConvertTo-ProfMigMigrationResult
# ---------------------------------------------------------------------------

function ConvertTo-ProfMigMigrationResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$CopyResult,

        [Parameter()]
        [PSCustomObject]$ApplicationMigrationResult,

        [Parameter()]
        [string]$ProfMigVersion = 'Unknown'
    )


    # -----------------------------------------------------------------------
    # Selected profile components
    # -----------------------------------------------------------------------

    $selectedComponents = @(
        $CopyResult.Components |
            ForEach-Object {
                $_.Component
            }
    )


    # -----------------------------------------------------------------------
    # Preserve profile copy result information
    # -----------------------------------------------------------------------

    $skippedItems = @(
        $CopyResult.SkippedItems
    )

    $excludedItems = @(
        $CopyResult.ExcludedItems
    )

    $failedItems = @(
        $CopyResult.Errors
    )


    # -----------------------------------------------------------------------
    # Application migration information
    # -----------------------------------------------------------------------

    $applicationResults = @()

    if ($null -ne $ApplicationMigrationResult) {

        $applicationResults = @(
            $ApplicationMigrationResult.Results
        )
    }


    # -----------------------------------------------------------------------
    # Profile totals
    # -----------------------------------------------------------------------

    $profileFilesSelected = [int64]$CopyResult.Totals.FilesSelected
    $profileFilesCopied   = [int64]$CopyResult.Totals.FilesCopied
    $profileFilesSkipped  = [int64]$CopyResult.Totals.FilesSkipped
    $profileFilesExcluded = [int64]$CopyResult.Totals.FilesExcluded
    $profileFilesFailed   = [int64]$CopyResult.Totals.FilesFailed
    $profileBytesCopied   = [int64]$CopyResult.Totals.BytesCopied


    # -----------------------------------------------------------------------
    # Application totals
    #
    # Normalize every provider through one helper. Prefer Result.Totals,
    # fall back to direct provider properties, then dispatcher counters.
    # -----------------------------------------------------------------------

    $applicationFilesSelected = [int64]0
    $applicationFilesCopied   = [int64]0
    $applicationFilesSkipped  = [int64]0
    $applicationFilesExcluded = [int64]0
    $applicationFilesFailed   = [int64]0
    $applicationBytesCopied   = [int64]0

    foreach ($applicationResult in $applicationResults) {

        $metrics = Get-ProfMigApplicationReportMetrics `
            -ApplicationResult $applicationResult

        $applicationFilesSelected += $metrics.FilesSelected
        $applicationFilesCopied   += $metrics.FilesCopied
        $applicationFilesSkipped  += $metrics.FilesSkipped
        $applicationFilesExcluded += $metrics.FilesExcluded
        $applicationFilesFailed   += $metrics.FilesFailed
        $applicationBytesCopied   += $metrics.BytesCopied

        $providerResult = $applicationResult.Result

        if ($null -eq $providerResult) {
            continue
        }

        if (
            $providerResult.PSObject.Properties.Name -contains
            'SkippedItems'
        ) {
            $skippedItems += @($providerResult.SkippedItems)
        }

        if (
            $providerResult.PSObject.Properties.Name -contains
            'ExcludedItems'
        ) {
            $excludedItems += @($providerResult.ExcludedItems)
        }

       if (
            $providerResult.PSObject.Properties.Name -contains
            'Errors'
        ) {

             foreach ($providerError in @($providerResult.Errors)) {

                if ($null -eq $providerError) {
                    continue
                }

                $errorMessage = $null
                $sourceFile = $null
                $destinationFile = $null

                if (
                    $providerError.PSObject.Properties.Name -contains
                    'Error'
                ) {
                    $errorMessage = [string]$providerError.Error
                }

                if (
                    $providerError.PSObject.Properties.Name -contains
                    'SourceFile'
                ) {
                    $sourceFile = [string]$providerError.SourceFile
                }

                if (
                    $providerError.PSObject.Properties.Name -contains
                    'DestinationFile'
                ) {
                    $destinationFile = [string]$providerError.DestinationFile
                }

                if (
                    -not [string]::IsNullOrWhiteSpace($errorMessage) -or
                    -not [string]::IsNullOrWhiteSpace($sourceFile) -or
                    -not [string]::IsNullOrWhiteSpace($destinationFile)
                ) {
                    $failedItems += $providerError
                }
            }
    }
}

    # -----------------------------------------------------------------------
    # Combined totals
    # -----------------------------------------------------------------------

    $filesSelected = (
        $profileFilesSelected +
        $applicationFilesSelected
    )

    $filesCopied = (
        $profileFilesCopied +
        $applicationFilesCopied
    )

    $filesSkipped = (
        $profileFilesSkipped +
        $applicationFilesSkipped
    )

    $filesExcluded = (
        $profileFilesExcluded +
        $applicationFilesExcluded
    )

    $filesFailed = (
        $profileFilesFailed +
        $applicationFilesFailed
    )

    $bytesCopied = (
        $profileBytesCopied +
        $applicationBytesCopied
    )


    # -----------------------------------------------------------------------
    # Human-readable warnings and errors
    # -----------------------------------------------------------------------

    $warnings = @()
    $errors   = @()

    if ($profileFilesSkipped -gt 0) {

        $warnings += (
            '{0} profile file(s) or item(s) were skipped.' `
                -f $profileFilesSkipped
        )
    }

    if ($profileFilesExcluded -gt 0) {

        $warnings += (
            '{0} profile file(s) were excluded by migration rules.' `
                -f $profileFilesExcluded
        )
    }

    if ($applicationFilesSkipped -gt 0) {

        $warnings += (
            '{0} application file(s) were skipped.' `
                -f $applicationFilesSkipped
        )
    }

    if ($applicationFilesExcluded -gt 0) {

        $warnings += (
            '{0} application file(s) were excluded by migration rules.' `
                -f $applicationFilesExcluded
        )
    }

    foreach ($errorItem in @($CopyResult.Errors)) {

        $componentName = if ($errorItem.Component) {
            $errorItem.Component
        }
        else {
            'Unknown component'
        }

        $errorMessage = if ($errorItem.Error) {
            $errorItem.Error
        }
        else {
            'Unknown error'
        }

        $errors += "$componentName : $errorMessage"
    }

    foreach ($applicationResult in $applicationResults) {

        if (-not [string]::IsNullOrWhiteSpace($applicationResult.Error)) {

            $errors += (
                '{0} : {1}' -f
                $applicationResult.Name,
                $applicationResult.Error
            )

            continue
        }

        if ($applicationResult.Status -eq 'Failed') {

            $errors += (
                '{0} : application migration failed ({1})' -f
                $applicationResult.Name,
                $applicationResult.ProviderStatus
            )
        }

        elseif ($applicationResult.Status -eq 'Warning') {

            $warnings += (
                '{0} completed with warnings ({1}).' -f
                $applicationResult.Name,
                $applicationResult.ProviderStatus
            )
        }

        elseif ($applicationResult.Status -eq 'Skipped') {

            $warnings += (
                '{0} was skipped ({1}).' -f
                $applicationResult.Name,
                $applicationResult.ProviderStatus
            )
        }
    }


    # -----------------------------------------------------------------------
    # Determine overall reporting status
    # -----------------------------------------------------------------------

    if (
        $filesFailed -gt 0 -or
        $errors.Count -gt 0 -or
        $CopyResult.Status -eq 'CompletedWithErrors' -or
        (
            $null -ne $ApplicationMigrationResult -and
            (
                $ApplicationMigrationResult.Status -eq 'Failed' -or
                $ApplicationMigrationResult.Status -eq 'PartialSuccess'
            )
        )
    ) {

        $status = 'Failed'
    }
    elseif (
        $warnings.Count -gt 0 -or
        $CopyResult.Status -eq 'CompletedWithWarnings' -or
        (
            $null -ne $ApplicationMigrationResult -and
            $ApplicationMigrationResult.Status -eq 'CompletedWithWarnings'
        )
    ) {

        $status = 'Success with warnings'
    }
    else {

        $status = 'Success'
    }


    # -----------------------------------------------------------------------
    # Overall timing
    # -----------------------------------------------------------------------

    $startTime = $CopyResult.StartedAt
    $completionTime = $CopyResult.CompletedAt

    if ($null -ne $ApplicationMigrationResult) {

        if (
            $ApplicationMigrationResult.StartedAt -and
            $ApplicationMigrationResult.StartedAt -lt $startTime
        ) {
            $startTime = $ApplicationMigrationResult.StartedAt
        }

        if (
            $ApplicationMigrationResult.CompletedAt -and
            $ApplicationMigrationResult.CompletedAt -gt $completionTime
        ) {
            $completionTime = $ApplicationMigrationResult.CompletedAt
        }
    }

    $duration = (
        $completionTime -
        $startTime
    )


    # -----------------------------------------------------------------------
    # Return structured reporting result
    # -----------------------------------------------------------------------

    return [PSCustomObject]@{

        ProfMigVersion      = $ProfMigVersion

        SourceProfile       = $CopyResult.SourceProfile
        DestinationProfile  = $CopyResult.DestinationProfile

        StartTime           = $startTime
        CompletionTime      = $completionTime
        Duration            = $duration

        SelectedComponents  = $selectedComponents

        FilesSelected       = [int64]$filesSelected
        FilesCopied         = [int64]$filesCopied
        FilesSkipped        = [int64]$filesSkipped
        FilesExcluded       = [int64]$filesExcluded
        FilesFailed         = [int64]$filesFailed
        BytesCopied         = [int64]$bytesCopied

        ProfileTotals       = [PSCustomObject]@{
            FilesSelected = $profileFilesSelected
            FilesCopied   = $profileFilesCopied
            FilesSkipped  = $profileFilesSkipped
            FilesExcluded = $profileFilesExcluded
            FilesFailed   = $profileFilesFailed
            BytesCopied   = $profileBytesCopied
        }

        ApplicationTotals   = [PSCustomObject]@{
            FilesSelected = $applicationFilesSelected
            FilesCopied   = $applicationFilesCopied
            FilesSkipped  = $applicationFilesSkipped
            FilesExcluded = $applicationFilesExcluded
            FilesFailed   = $applicationFilesFailed
            BytesCopied   = $applicationBytesCopied
        }

        SkippedItems        = @($skippedItems)
        ExcludedItems       = @($excludedItems)
        FailedItems         = @($failedItems)

        Warnings            = @($warnings)
        Errors              = @($errors)

        Status              = $status

        ComponentResults    = @($CopyResult.Components)
        ApplicationResults  = @($applicationResults)

        CopyEngineStatus    = $CopyResult.Status

        ApplicationMigrationStatus = if (
            $null -ne $ApplicationMigrationResult
        ) {
            $ApplicationMigrationResult.Status
        }
        else {
            'NotRun'
        }
    }
}


# ---------------------------------------------------------------------------
# Public function: New-ProfMigMigrationReport
# ---------------------------------------------------------------------------

function New-ProfMigMigrationReport {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$MigrationResult,

        [Parameter(Mandatory)]
        [string]$ReportFolder
    )

    try {

        # -------------------------------------------------------------------
        # Ensure configured report folder exists
        # -------------------------------------------------------------------

        if (-not (Test-Path -LiteralPath $ReportFolder -PathType Container)) {

            New-Item `
                -ItemType Directory `
                -Path $ReportFolder `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }


        # -------------------------------------------------------------------
        # Generate report filename
        # -------------------------------------------------------------------

        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

        $reportFile = Join-Path `
            -Path $ReportFolder `
            -ChildPath "ProfMig_Migration_$timestamp.txt"


        # -------------------------------------------------------------------
        # Format migration times
        # -------------------------------------------------------------------

        $started = if ($null -ne $MigrationResult.StartTime) {

            $MigrationResult.StartTime.ToString(
                'yyyy-MM-dd HH:mm:ss'
            )
        }
        else {

            'Unknown'
        }

        $completed = if ($null -ne $MigrationResult.CompletionTime) {

            $MigrationResult.CompletionTime.ToString(
                'yyyy-MM-dd HH:mm:ss'
            )
        }
        else {

            'Not completed'
        }

        $duration = if ($null -ne $MigrationResult.Duration) {

            '{0:hh\:mm\:ss}' -f $MigrationResult.Duration
        }
        else {

            'Unknown'
        }


        # -------------------------------------------------------------------
        # Format selected profile components
        # -------------------------------------------------------------------

        $components = if (
            $MigrationResult.SelectedComponents.Count -gt 0
        ) {

            (
                $MigrationResult.SelectedComponents |
                    ForEach-Object {
                        "- $_"
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format skipped items
        # -------------------------------------------------------------------

        $skippedItems = if (
            $MigrationResult.SkippedItems.Count -gt 0
        ) {

            (
                $MigrationResult.SkippedItems |
                    ForEach-Object {

                        Format-ProfMigReportItem `
                            -Item $_ `
                            -Type 'Skipped'
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format excluded items
        # -------------------------------------------------------------------

        $excludedItems = if (
            $MigrationResult.ExcludedItems.Count -gt 0
        ) {

            (
                $MigrationResult.ExcludedItems |
                    ForEach-Object {

                        Format-ProfMigReportItem `
                            -Item $_ `
                            -Type 'Excluded'
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format failed items
        # -------------------------------------------------------------------

        $failedItems = if (
            $MigrationResult.FailedItems.Count -gt 0
        ) {

            (
                $MigrationResult.FailedItems |
                    ForEach-Object {

                        Format-ProfMigReportItem `
                            -Item $_ `
                            -Type 'Failed'
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format warnings
        # -------------------------------------------------------------------

        $warnings = if (
            $MigrationResult.Warnings.Count -gt 0
        ) {

            (
                $MigrationResult.Warnings |
                    ForEach-Object {
                        "- $_"
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format errors
        # -------------------------------------------------------------------

        $errors = if (
            $MigrationResult.Errors.Count -gt 0
        ) {

            (
                $MigrationResult.Errors |
                    ForEach-Object {
                        "- $_"
                    }
            ) -join [Environment]::NewLine
        }
        else {

            '- None'
        }


        # -------------------------------------------------------------------
        # Format overall statistics
        # -------------------------------------------------------------------

        $bytesFormatted = (
            '{0:N0}' -f [int64]$MigrationResult.BytesCopied
        )


        # -------------------------------------------------------------------
        # Format profile statistics
        # -------------------------------------------------------------------

        $profileStatistics = '- Not available'

        if ($null -ne $MigrationResult.ProfileTotals) {

            $profileBytesFormatted = (
                '{0:N0}' -f
                [int64]$MigrationResult.ProfileTotals.BytesCopied
            )

            $profileStatistics = @"
Files selected : $($MigrationResult.ProfileTotals.FilesSelected)
Files copied   : $($MigrationResult.ProfileTotals.FilesCopied)
Files skipped  : $($MigrationResult.ProfileTotals.FilesSkipped)
Files excluded : $($MigrationResult.ProfileTotals.FilesExcluded)
Files failed   : $($MigrationResult.ProfileTotals.FilesFailed)
Bytes copied   : $profileBytesFormatted
"@
        }


        # -------------------------------------------------------------------
        # Format application statistics
        # -------------------------------------------------------------------

        $applicationStatistics = '- Not run'

        if (
            $null -ne $MigrationResult.ApplicationTotals -and
            $MigrationResult.ApplicationMigrationStatus -ne 'NotRun'
        ) {

            $applicationBytesFormatted = (
                '{0:N0}' -f
                [int64]$MigrationResult.ApplicationTotals.BytesCopied
            )

            $applicationStatistics = @"
Files selected : $($MigrationResult.ApplicationTotals.FilesSelected)
Files copied   : $($MigrationResult.ApplicationTotals.FilesCopied)
Files skipped  : $($MigrationResult.ApplicationTotals.FilesSkipped)
Files excluded : $($MigrationResult.ApplicationTotals.FilesExcluded)
Files failed   : $($MigrationResult.ApplicationTotals.FilesFailed)
Bytes copied   : $applicationBytesFormatted
"@
        }


        # -------------------------------------------------------------------
        # Format individual application results
        # -------------------------------------------------------------------

        $applicationDetails = '- None'

        if (
            $null -ne $MigrationResult.ApplicationResults -and
            $MigrationResult.ApplicationResults.Count -gt 0
        ) {

            $applicationSections = @()

            foreach (
                $applicationResult in
                $MigrationResult.ApplicationResults
            ) {

                $metrics = Get-ProfMigApplicationReportMetrics `
                    -ApplicationResult $applicationResult

                $filesSelected = $metrics.FilesSelected
                $filesCopied   = $metrics.FilesCopied
                $filesSkipped  = $metrics.FilesSkipped
                $filesExcluded = $metrics.FilesExcluded
                $filesFailed   = $metrics.FilesFailed
                $bytesCopied   = $metrics.BytesCopied

                $applicationBytesFormatted = (
                    '{0:N0}' -f $bytesCopied
                )

                $applicationError = if (
                    [string]::IsNullOrWhiteSpace(
                        [string]$applicationResult.Error
                    )
                ) {

                    'None'
                }
                else {

                    [string]$applicationResult.Error
                }

                $applicationSections += @"
$($applicationResult.Name)
------------------------------------------------------------
Type            : $($applicationResult.Type)
Status          : $($applicationResult.Status)
Provider status : $($applicationResult.ProviderStatus)
Duration        : $($applicationResult.Duration)

Files selected  : $filesSelected
Files copied    : $filesCopied
Files skipped   : $filesSkipped
Files excluded  : $filesExcluded
Files failed    : $filesFailed
Bytes copied    : $applicationBytesFormatted

Error           : $applicationError
"@
            }

            $applicationDetails = (
                $applicationSections -join (
                    [Environment]::NewLine +
                    [Environment]::NewLine
                )
            )
        }


        # -------------------------------------------------------------------
        # Application migration status
        # -------------------------------------------------------------------

        $applicationMigrationStatus = if (
            [string]::IsNullOrWhiteSpace(
                [string]$MigrationResult.ApplicationMigrationStatus
            )
        ) {

            'NotRun'
        }
        else {

            [string]$MigrationResult.ApplicationMigrationStatus
        }


        # -------------------------------------------------------------------
        # Build human-readable report
        # -------------------------------------------------------------------

        $report = @"
ProfMig Migration Report
============================================================

ProfMig version : $($MigrationResult.ProfMigVersion)

Source      : $($MigrationResult.SourceProfile)
Destination : $($MigrationResult.DestinationProfile)

Started     : $started
Completed   : $completed
Duration    : $duration


Selected profile components
------------------------------------------------------------
$components


Overall migration statistics
------------------------------------------------------------
Files selected : $($MigrationResult.FilesSelected)
Files copied   : $($MigrationResult.FilesCopied)
Files skipped  : $($MigrationResult.FilesSkipped)
Files excluded : $($MigrationResult.FilesExcluded)
Files failed   : $($MigrationResult.FilesFailed)
Bytes copied   : $bytesFormatted


Profile migration statistics
------------------------------------------------------------
$profileStatistics


Application migration statistics
------------------------------------------------------------
$applicationStatistics


Applications
============================================================

$applicationDetails


Skipped items
============================================================

$skippedItems


Excluded items
============================================================

$excludedItems


Failed items
============================================================

$failedItems


Warnings
============================================================

$warnings


Errors
============================================================

$errors


Overall result
============================================================

$($MigrationResult.Status)


Copy Engine status
============================================================

$($MigrationResult.CopyEngineStatus)


Application Migration status
============================================================

$applicationMigrationStatus
"@


        # -------------------------------------------------------------------
        # Write report
        # -------------------------------------------------------------------

        $report |
            Set-Content `
                -LiteralPath $reportFile `
                -Encoding UTF8 `
                -ErrorAction Stop

        return $reportFile
    }
    catch {

        # Reporting failure must never destroy the migration result.

        Write-Warning (
            "Unable to create ProfMig migration report: " +
            "$($_.Exception.Message)"
        )

        return $null
    }
}


Export-ModuleMember -Function `
    ConvertTo-ProfMigMigrationResult,
    New-ProfMigMigrationReport