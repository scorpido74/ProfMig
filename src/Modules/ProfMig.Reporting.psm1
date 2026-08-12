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

    switch ($Type) {

        'Skipped' {

            $source = if ($Item.SourceFile) {
                $Item.SourceFile
            }
            else {
                'Unknown'
            }

            $destination = if ($Item.DestinationFile) {
                $Item.DestinationFile
            }
            else {
                'Unknown'
            }

            $reason = if ($Item.Reason) {
                $Item.Reason
            }
            else {
                'Unknown'
            }

            return @"
- Component   : $($Item.Component)
  Source      : $source
  Destination : $destination
  Reason      : $reason
"@
        }


        'Excluded' {

            $source = if ($Item.SourceFile) {
                $Item.SourceFile
            }
            else {
                'Unknown'
            }

            $reason = if ($Item.Reason) {
                $Item.Reason
            }
            else {
                'Unknown'
            }

            return @"
- Component : $($Item.Component)
  Source    : $source
  Reason    : $reason
"@
        }


        'Failed' {

            $source = if ($Item.SourceFile) {
                $Item.SourceFile
            }
            else {
                'Unknown'
            }

            $destination = if ($Item.DestinationFile) {
                $Item.DestinationFile
            }
            else {
                'Unknown'
            }

            $errorMessage = if ($Item.Error) {
                $Item.Error
            }
            else {
                'Unknown error'
            }

            return @"
- Component   : $($Item.Component)
  Source      : $source
  Destination : $destination
  Error       : $errorMessage
"@
        }
    }
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
        [string]$ProfMigVersion = 'Unknown'
    )


    # -----------------------------------------------------------------------
    # Selected components
    # -----------------------------------------------------------------------

    $selectedComponents = @(
        $CopyResult.Components |
            ForEach-Object {
                $_.Component
            }
    )


    # -----------------------------------------------------------------------
    # Preserve structured result information
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
    # Build human-readable warning and error collections
    # -----------------------------------------------------------------------

    $warnings = @()
    $errors   = @()

    if ($CopyResult.Totals.FilesSkipped -gt 0) {

        $warnings += (
            '{0} file(s) were skipped because destination files already existed.' `
                -f $CopyResult.Totals.FilesSkipped
        )
    }

    if ($CopyResult.Totals.FilesExcluded -gt 0) {

        $warnings += (
            '{0} file(s) were excluded by migration rules.' `
                -f $CopyResult.Totals.FilesExcluded
        )
    }

    foreach ($errorItem in $failedItems) {

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


    # -----------------------------------------------------------------------
    # Determine reporting status
    #
    # Reporting uses three public states:
    #
    # Success
    # Success with warnings
    # Failed
    # -----------------------------------------------------------------------

    if (
        $CopyResult.Status -eq 'CompletedWithErrors' -or
        $CopyResult.Totals.FilesFailed -gt 0 -or
        $errors.Count -gt 0
    ) {

        $status = 'Failed'
    }
    elseif (
        $CopyResult.Status -eq 'CompletedWithWarnings' -or
        $warnings.Count -gt 0
    ) {

        $status = 'Success with warnings'
    }
    else {

        $status = 'Success'
    }


    # -----------------------------------------------------------------------
    # Return structured reporting result
    # -----------------------------------------------------------------------

    return [PSCustomObject]@{
        ProfMigVersion      = $ProfMigVersion

        SourceProfile       = $CopyResult.SourceProfile
        DestinationProfile  = $CopyResult.DestinationProfile

        StartTime           = $CopyResult.StartedAt
        CompletionTime      = $CopyResult.CompletedAt
        Duration            = $CopyResult.Duration

        SelectedComponents  = $selectedComponents

        FilesSelected       = $CopyResult.Totals.FilesSelected
        FilesCopied         = $CopyResult.Totals.FilesCopied
        FilesSkipped        = $CopyResult.Totals.FilesSkipped
        FilesExcluded       = $CopyResult.Totals.FilesExcluded
        FilesFailed         = $CopyResult.Totals.FilesFailed
        BytesCopied         = $CopyResult.Totals.BytesCopied

        SkippedItems        = $skippedItems
        ExcludedItems       = $excludedItems
        FailedItems         = $failedItems

        Warnings            = $warnings
        Errors              = $errors

        Status              = $status

        ComponentResults    = @($CopyResult.Components)
        CopyEngineStatus    = $CopyResult.Status
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
        # Format selected components
        # -------------------------------------------------------------------

        $components = if ($MigrationResult.SelectedComponents.Count -gt 0) {

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

        $skippedItems = if ($MigrationResult.SkippedItems.Count -gt 0) {

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

        $excludedItems = if ($MigrationResult.ExcludedItems.Count -gt 0) {

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

        $failedItems = if ($MigrationResult.FailedItems.Count -gt 0) {

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

        $warnings = if ($MigrationResult.Warnings.Count -gt 0) {

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

        $errors = if ($MigrationResult.Errors.Count -gt 0) {

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
        # Format bytes
        # -------------------------------------------------------------------

        $bytesFormatted = '{0:N0}' -f $MigrationResult.BytesCopied


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

Selected components
------------------------------------------------------------
$components

Migration statistics
------------------------------------------------------------
Files selected : $($MigrationResult.FilesSelected)
Files copied   : $($MigrationResult.FilesCopied)
Files skipped  : $($MigrationResult.FilesSkipped)
Files excluded : $($MigrationResult.FilesExcluded)
Files failed   : $($MigrationResult.FilesFailed)
Bytes copied   : $bytesFormatted

Skipped items
------------------------------------------------------------
$skippedItems

Excluded items
------------------------------------------------------------
$excludedItems

Failed items
------------------------------------------------------------
$failedItems

Warnings
------------------------------------------------------------
$warnings

Errors
------------------------------------------------------------
$errors

Overall result
------------------------------------------------------------
$($MigrationResult.Status)

Copy Engine status
------------------------------------------------------------
$($MigrationResult.CopyEngineStatus)
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
            "Unable to create ProfMig migration report: $($_.Exception.Message)"
        )

        return $null
    }
}


Export-ModuleMember -Function `
    ConvertTo-ProfMigMigrationResult,
    New-ProfMigMigrationReport