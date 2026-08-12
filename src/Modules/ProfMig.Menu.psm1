<#
.SYNOPSIS
    Interactive menu for ProfMig.

.DESCRIPTION
    Provides the interactive command-line interface for ProfMig.

    The menu consumes structured profile information from the Inventory
    Engine, starts migrations through the Copy Engine and sends migration
    results to the Reporting Engine.

    The menu itself does not perform file migration or reporting logic.

.NOTES
    Project : ProfMig
    Module  : ProfMig.Menu
    Sprint  : 1.7 - Reporting integration
#>

Set-StrictMode -Version Latest


# ---------------------------------------------------------------------------
# Internal function: Show-Header
# ---------------------------------------------------------------------------

function Show-Header {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter()]
        $SourceProfile = $null,

        [Parameter()]
        $DestinationProfile = $null
    )

    Clear-Host

    Write-Host ''
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host '                    ProfMig' -ForegroundColor White
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host "Version : $($Configuration.Application.Version)"
    Write-Host "Build   : $($Configuration.Application.Build)"
    Write-Host ''

    if ($null -eq $SourceProfile) {

        Write-Host `
            'Source profile      : Not selected' `
            -ForegroundColor Yellow
    }
    else {

        Write-Host `
            "Source profile      : $($SourceProfile.ProfileName)" `
            -ForegroundColor Green
    }

    if ($null -eq $DestinationProfile) {

        Write-Host `
            'Destination profile : Not selected' `
            -ForegroundColor Yellow
    }
    else {

        Write-Host `
            "Destination profile : $($DestinationProfile.ProfileName)" `
            -ForegroundColor Green
    }

    Write-Host ''
}


# ---------------------------------------------------------------------------
# Internal function: Select-User
# ---------------------------------------------------------------------------

function Select-User {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [array]$Users,

        [Parameter(Mandatory)]
        [string]$Title
    )

    if ($Users.Count -eq 0) {
        throw 'No user profiles are available for selection.'
    }

    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $Users.Count; $i++) {

        $user = $Users[$i]

        $account = if (
            $user.AccountDomain -and
            $user.AccountName
        ) {

            "$($user.AccountDomain)\$($user.AccountName)"
        }
        elseif ($user.AccountName) {

            $user.AccountName
        }
        else {

            'Unknown account'
        }

        Write-Host (
            '[{0}] {1} | {2} | {3}' -f
            ($i + 1),
            $user.ProfileName,
            $account,
            $user.Status
        )
    }

    Write-Host ''

    do {

        $choice = Read-Host 'Select a profile'

        $choiceNumber = 0

        $validChoice = [int]::TryParse(
            $choice,
            [ref]$choiceNumber
        )

        if (
            -not $validChoice -or
            $choiceNumber -lt 1 -or
            $choiceNumber -gt $Users.Count
        ) {

            Write-Host ''
            Write-Host 'Invalid selection.' -ForegroundColor Red
            Write-Host ''
        }

    } until (
        $validChoice -and
        $choiceNumber -ge 1 -and
        $choiceNumber -le $Users.Count
    )

    return $Users[$choiceNumber - 1]
}


# ---------------------------------------------------------------------------
# Internal function: Show-ProfMigConfiguration
# ---------------------------------------------------------------------------

function Show-ProfMigConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [string]$ReportFolder
    )

    Clear-Host

    Write-Host ''
    Write-Host 'ProfMig - Configuration' -ForegroundColor Cyan
    Write-Host '=======================' -ForegroundColor Cyan
    Write-Host ''

    Write-Host "Application : $($Configuration.Application.Name)"
    Write-Host "Version     : $($Configuration.Application.Version)"
    Write-Host "Build       : $($Configuration.Application.Build)"
    Write-Host ''

    Write-Host 'Paths' -ForegroundColor Cyan
    Write-Host "Logs        : $($Configuration.Paths.Logs)"
    Write-Host "Reports     : $($Configuration.Paths.Reports)"
    Write-Host "Backup      : $($Configuration.Paths.Backup)"
    Write-Host ''
    Write-Host "Resolved report path : $ReportFolder"
    Write-Host ''

    Write-Host 'Excluded profiles' -ForegroundColor Cyan

    foreach ($profile in $Configuration.ExcludedProfiles) {
        Write-Host " - $profile"
    }

    Write-Host ''
    Read-Host 'Press Enter to return to the main menu' | Out-Null
}


# ---------------------------------------------------------------------------
# Internal function: Show-ProfMigMigrationResult
# ---------------------------------------------------------------------------

function Show-ProfMigMigrationResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Result,

        [Parameter()]
        [string]$ReportPath
    )

    Write-Host ''
    Write-Host 'Migration result' -ForegroundColor Cyan
    Write-Host '================' -ForegroundColor Cyan
    Write-Host ''

    switch ($Result.Status) {

        'Success' {

            Write-Host `
                "Status         : $($Result.Status)" `
                -ForegroundColor Green
        }

        'Success with warnings' {

            Write-Host `
                "Status         : $($Result.Status)" `
                -ForegroundColor Yellow
        }

        'Failed' {

            Write-Host `
                "Status         : $($Result.Status)" `
                -ForegroundColor Red
        }

        default {

            Write-Host `
                "Status         : $($Result.Status)" `
                -ForegroundColor Yellow
        }
    }

    Write-Host "Source         : $($Result.SourceProfile)"
    Write-Host "Destination    : $($Result.DestinationProfile)"
    Write-Host ''

    Write-Host "Started        : $($Result.StartTime)"
    Write-Host "Completed      : $($Result.CompletionTime)"
    Write-Host "Duration       : $($Result.Duration)"
    Write-Host ''

    Write-Host 'Totals' -ForegroundColor Cyan

    Write-Host "Files selected : $($Result.FilesSelected)"
    Write-Host "Files copied   : $($Result.FilesCopied)"
    Write-Host "Files skipped  : $($Result.FilesSkipped)"
    Write-Host "Files excluded : $($Result.FilesExcluded)"
    Write-Host "Files failed   : $($Result.FilesFailed)"
    Write-Host "Bytes copied   : $($Result.BytesCopied)"
    Write-Host ''

    Write-Host 'Components' -ForegroundColor Cyan

    foreach ($component in $Result.ComponentResults) {

        Write-Host (
            '{0,-15} Selected: {1,-6} Copied: {2,-6} Skipped: {3,-6} Excluded: {4,-6} Failed: {5,-6} {6}' -f
            $component.Component,
            $component.FilesSelected,
            $component.FilesCopied,
            $component.FilesSkipped,
            $component.FilesExcluded,
            $component.FilesFailed,
            $component.Status
        )
    }


    # -----------------------------------------------------------------------
    # Skipped items
    # -----------------------------------------------------------------------

    if ($Result.SkippedItems.Count -gt 0) {

        Write-Host ''
        Write-Host 'Skipped items' -ForegroundColor Yellow

        foreach ($item in $Result.SkippedItems) {

            Write-Host " - $($item.SourceFile)" -ForegroundColor Yellow
            Write-Host "   Reason: $($item.Reason)" -ForegroundColor DarkYellow
        }
    }


    # -----------------------------------------------------------------------
    # Warnings
    # -----------------------------------------------------------------------

    if ($Result.Warnings.Count -gt 0) {

        Write-Host ''
        Write-Host 'Warnings' -ForegroundColor Yellow

        foreach ($warning in $Result.Warnings) {

            Write-Host " - $warning" -ForegroundColor Yellow
        }
    }


    # -----------------------------------------------------------------------
    # Failed items
    # -----------------------------------------------------------------------

    if ($Result.FailedItems.Count -gt 0) {

        Write-Host ''
        Write-Host 'Failed items' -ForegroundColor Red

        foreach ($item in $Result.FailedItems) {

            $sourceFile = if ($item.SourceFile) {
                $item.SourceFile
            }
            else {
                'Unknown'
            }

            Write-Host " - $sourceFile" -ForegroundColor Red
            Write-Host "   Error: $($item.Error)" -ForegroundColor Red
        }
    }


    # -----------------------------------------------------------------------
    # Report location
    # -----------------------------------------------------------------------

    Write-Host ''

    if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {

        Write-Host 'Migration report' -ForegroundColor Cyan
        Write-Host $ReportPath -ForegroundColor Green
    }
    else {

        Write-Host `
            'Migration report could not be created.' `
            -ForegroundColor Yellow
    }

    Write-Host ''
}


# ---------------------------------------------------------------------------
# Internal function: New-ProfMigCopyConfiguration
# ---------------------------------------------------------------------------

function New-ProfMigCopyConfiguration {
    [CmdletBinding()]
    param()

    return @{
        Folders = @(
            'Desktop'
            'Documents'
            'Downloads'
            'Pictures'
        )

        AdditionalFolders = @()

        Exclusions = @(
            '*.tmp'
            '*.log'
            'Thumbs.db'
        )
    }
}


# ---------------------------------------------------------------------------
# Public function: Start-ProfMigMenu
# ---------------------------------------------------------------------------

function Start-ProfMigMenu {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        [array]$Profiles,

        [Parameter(Mandatory)]
        [string]$ReportFolder
    )

    $sourceProfile      = $null
    $destinationProfile = $null
    $running            = $true


    while ($running) {

        Show-Header `
            -Configuration $Configuration `
            -SourceProfile $sourceProfile `
            -DestinationProfile $destinationProfile

        Write-Host '1. Select source profile'
        Write-Host '2. Select destination profile'
        Write-Host '3. Show migration configuration'
        Write-Host '4. Start migration'
        Write-Host '5. Exit'
        Write-Host ''

        $selection = Read-Host 'Select an option'


        switch ($selection) {


            # ----------------------------------------------------------------
            # Select source
            # ----------------------------------------------------------------

            '1' {

                $sourceProfile = Select-User `
                    -Users $Profiles `
                    -Title 'Select source profile'

                if (
                    $null -ne $destinationProfile -and
                    $sourceProfile.ProfilePath -eq
                    $destinationProfile.ProfilePath
                ) {

                    Write-Host ''
                    Write-Host `
                        'Source and destination profile cannot be the same.' `
                        -ForegroundColor Red

                    $sourceProfile = $null

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null
                }
            }


            # ----------------------------------------------------------------
            # Select destination
            # ----------------------------------------------------------------

            '2' {

                $destinationProfile = Select-User `
                    -Users $Profiles `
                    -Title 'Select destination profile'

                if (
                    $null -ne $sourceProfile -and
                    $destinationProfile.ProfilePath -eq
                    $sourceProfile.ProfilePath
                ) {

                    Write-Host ''
                    Write-Host `
                        'Source and destination profile cannot be the same.' `
                        -ForegroundColor Red

                    $destinationProfile = $null

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null
                }
            }


            # ----------------------------------------------------------------
            # Show configuration
            # ----------------------------------------------------------------

            '3' {

                Show-ProfMigConfiguration `
                    -Configuration $Configuration `
                    -ReportFolder $ReportFolder
            }


            # ----------------------------------------------------------------
            # Start migration
            # ----------------------------------------------------------------

            '4' {

                Write-Host ''

                if (
                    $null -eq $sourceProfile -or
                    $null -eq $destinationProfile
                ) {

                    Write-Host `
                        'Migration cannot start.' `
                        -ForegroundColor Yellow

                    Write-Host `
                        'A valid source and destination profile must be selected.'
                }
                elseif (-not $sourceProfile.Accessible) {

                    Write-Host `
                        'Migration cannot start.' `
                        -ForegroundColor Yellow

                    Write-Host `
                        'The selected source profile is not accessible.'
                }
                elseif (-not $destinationProfile.Accessible) {

                    Write-Host `
                        'Migration cannot start.' `
                        -ForegroundColor Yellow

                    Write-Host `
                        'The selected destination profile is not accessible.'
                }
                else {

                    Write-Host `
                        "Source profile      : $($sourceProfile.ProfileName)"

                    Write-Host `
                        "Destination profile : $($destinationProfile.ProfileName)"

                    Write-Host ''

                    Write-Host `
                        'The following folders will be migrated:' `
                        -ForegroundColor Cyan

                    Write-Host ' - Desktop'
                    Write-Host ' - Documents'
                    Write-Host ' - Downloads'
                    Write-Host ' - Pictures'

                    Write-Host ''

                    Write-Host `
                        'Existing destination files will NOT be overwritten.' `
                        -ForegroundColor Yellow

                    Write-Host ''

                    $confirmation = Read-Host 'Start migration? (Y/N)'


                    if ($confirmation -match '^[Yy]$') {

                        $copyConfiguration = New-ProfMigCopyConfiguration

                        Write-Host ''
                        Write-Host `
                            'Migration started...' `
                            -ForegroundColor Cyan
                        Write-Host ''


                        try {

                            # -------------------------------------------------
                            # Copy Engine
                            # -------------------------------------------------

                            $copyResult = Invoke-ProfMigCopy `
                                -SourceProfile $sourceProfile.ProfilePath `
                                -DestinationProfile $destinationProfile.ProfilePath `
                                -Configuration $copyConfiguration


                            # -------------------------------------------------
                            # Reporting result
                            # -------------------------------------------------

                            $reportResult = ConvertTo-ProfMigMigrationResult `
                                -CopyResult $copyResult `
                                -ProfMigVersion $Configuration.Application.Version


                            # -------------------------------------------------
                            # Generate human-readable report
                            #
                            # Reporting failure must not destroy the migration
                            # result. New-ProfMigMigrationReport returns $null
                            # when report creation fails.
                            # -------------------------------------------------

                            $reportPath = New-ProfMigMigrationReport `
                                -MigrationResult $reportResult `
                                -ReportFolder $ReportFolder


                            # -------------------------------------------------
                            # Display result
                            # -------------------------------------------------

                            Show-ProfMigMigrationResult `
                                -Result $reportResult `
                                -ReportPath $reportPath
                        }
                        catch {

                            Write-Host ''
                            Write-Host `
                                'Migration failed.' `
                                -ForegroundColor Red

                            Write-Host `
                                $_.Exception.Message `
                                -ForegroundColor Red
                        }
                    }
                    else {

                        Write-Host ''
                        Write-Host `
                            'Migration cancelled.' `
                            -ForegroundColor Yellow
                    }
                }

                Write-Host ''
                Read-Host 'Press Enter to return to the main menu' |
                    Out-Null
            }


            # ----------------------------------------------------------------
            # Exit
            # ----------------------------------------------------------------

            '5' {

                Write-Host ''
                Write-Host 'Exiting ProfMig...'

                $running = $false
            }


            # ----------------------------------------------------------------
            # Invalid selection
            # ----------------------------------------------------------------

            default {

                Write-Host ''
                Write-Host `
                    'Invalid selection. Choose option 1 through 5.' `
                    -ForegroundColor Red

                Start-Sleep -Seconds 2
            }
        }
    }


    return [PSCustomObject]@{
        SourceProfile      = $sourceProfile
        DestinationProfile = $destinationProfile
    }
}


Export-ModuleMember -Function Start-ProfMigMenu