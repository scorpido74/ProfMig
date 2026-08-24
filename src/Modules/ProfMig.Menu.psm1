# ============================================================================
# ProfMig.Menu.psm1
# ============================================================================
#
# ProfMig interactive menu
#
# Sprint 2.7 - Application Migration Integration
#
# Responsibilities:
# - Display ProfMig status
# - Select source profile
# - Select destination profile
# - Detect applications
# - Select applications for migration
# - Display migration configuration
# - Execute M1 profile migration
# - Execute M2 application migration
# - Display migration results
#
# ============================================================================


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
        $DestinationProfile = $null,

        [Parameter()]
        [array]$SelectedApplications = @()
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
        Write-Host 'Source profile      : Not selected' -ForegroundColor Yellow
    }
    else {
        Write-Host "Source profile      : $($SourceProfile.ProfileName)" -ForegroundColor Green
    }

    if ($null -eq $DestinationProfile) {
        Write-Host 'Destination profile : Not selected' -ForegroundColor Yellow
    }
    else {
        Write-Host "Destination profile : $($DestinationProfile.ProfileName)" -ForegroundColor Green
    }

    if ($null -ne $SourceProfile) {
        Write-Host "Applications        : $($SelectedApplications.Count) selected"
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

        $account = if ($user.AccountDomain -and $user.AccountName) {
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
# Internal function: Get-ProfMigDetectedApplications
# ---------------------------------------------------------------------------

function Get-ProfMigDetectedApplications {

    [CmdletBinding()]
    param (
        [Parameter()]
        [array]$ApplicationInventory = @()
    )

    return @(
        $ApplicationInventory |
            Where-Object {
                $_.Detected -eq $true
            }
    )
}


# ---------------------------------------------------------------------------
# Internal function: Test-ProfMigApplicationSelected
# ---------------------------------------------------------------------------

function Test-ProfMigApplicationSelected {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ApplicationId,

        [Parameter()]
        [array]$SelectedApplications = @()
    )

    $match = @(
        $SelectedApplications |
            Where-Object {
                $_.Id -eq $ApplicationId
            }
    )

    return ($match.Count -gt 0)
}


# ---------------------------------------------------------------------------
# Internal function: Show-ProfMigDetectedApplications
# ---------------------------------------------------------------------------

function Show-ProfMigDetectedApplications {

    [CmdletBinding()]
    param (
        [Parameter()]
        [array]$ApplicationInventory = @(),

        [Parameter()]
        [array]$SelectedApplications = @()
    )

    $detectedApplications = @(
        Get-ProfMigDetectedApplications `
            -ApplicationInventory $ApplicationInventory
    )

    Write-Host ''
    Write-Host 'Applications detected' -ForegroundColor Cyan
    Write-Host '---------------------' -ForegroundColor Cyan

    if ($detectedApplications.Count -eq 0) {
        Write-Host 'No supported applications detected.' -ForegroundColor Yellow
        return
    }

    foreach ($application in $detectedApplications) {

        $selected = Test-ProfMigApplicationSelected `
            -ApplicationId $application.Id `
            -SelectedApplications $SelectedApplications

        $marker = if ($selected) {
            '[X]'
        }
        else {
            '[ ]'
        }

        Write-Host (
            ' {0} {1} [{2}]' -f
            $marker,
            $application.Name,
            $application.Type
        )
    }
}


# ---------------------------------------------------------------------------
# Internal function: Select-ProfMigApplications
# ---------------------------------------------------------------------------

function Select-ProfMigApplications {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [array]$ApplicationInventory,

        [Parameter()]
        [array]$SelectedApplications = @()
    )

    $detectedApplications = @(
        Get-ProfMigDetectedApplications `
            -ApplicationInventory $ApplicationInventory
    )

    if ($detectedApplications.Count -eq 0) {

        Write-Host ''
        Write-Host `
            'No supported applications were detected for the source profile.' `
            -ForegroundColor Yellow

        Write-Host ''
        Read-Host 'Press Enter to return to the main menu' |
            Out-Null

        return @()
    }

    $currentSelection = @($SelectedApplications)
    $selectionComplete = $false

    while (-not $selectionComplete) {

        Clear-Host

        Write-Host ''
        Write-Host 'ProfMig - Application Selection' -ForegroundColor Cyan
        Write-Host '===============================' -ForegroundColor Cyan
        Write-Host ''

        Write-Host 'Detected applications:' -ForegroundColor Cyan
        Write-Host ''

        for ($i = 0; $i -lt $detectedApplications.Count; $i++) {

            $application = $detectedApplications[$i]

            $selected = Test-ProfMigApplicationSelected `
                -ApplicationId $application.Id `
                -SelectedApplications $currentSelection

            $marker = if ($selected) {
                '[X]'
            }
            else {
                '[ ]'
            }

            Write-Host (
                '[{0}] {1} {2}' -f
                ($i + 1),
                $marker,
                $application.Name
            )
        }

        Write-Host ''
        Write-Host '[A] Select all'
        Write-Host '[N] Select none'
        Write-Host '[Enter] Done'
        Write-Host ''

        $choice = Read-Host 'Select application to toggle'

        if ([string]::IsNullOrWhiteSpace($choice)) {
            $selectionComplete = $true
            continue
        }

        $normalizedChoice = $choice.ToUpperInvariant()

        if ($normalizedChoice -eq 'A') {
            $currentSelection = @($detectedApplications)
            continue
        }

        if ($normalizedChoice -eq 'N') {
            $currentSelection = @()
            continue
        }

        $choiceNumber = 0

        $validChoice = [int]::TryParse(
            $choice,
            [ref]$choiceNumber
        )

        if (
            -not $validChoice -or
            $choiceNumber -lt 1 -or
            $choiceNumber -gt $detectedApplications.Count
        ) {
            Write-Host ''
            Write-Host 'Invalid selection.' -ForegroundColor Red
            Start-Sleep -Seconds 1
            continue
        }

        $selectedApplication = $detectedApplications[$choiceNumber - 1]

        $alreadySelected = Test-ProfMigApplicationSelected `
            -ApplicationId $selectedApplication.Id `
            -SelectedApplications $currentSelection

        if ($alreadySelected) {

            $currentSelection = @(
                $currentSelection |
                    Where-Object {
                        $_.Id -ne $selectedApplication.Id
                    }
            )
        }
        else {

            $currentSelection = @(
                $currentSelection
                $selectedApplication
            )
        }
    }

    return @($currentSelection)
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
        [string]$ReportFolder,

        [Parameter()]
        [array]$ApplicationInventory = @(),

        [Parameter()]
        [array]$SelectedApplications = @()
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
    Write-Host 'Applications' -ForegroundColor Cyan

    if ($ApplicationInventory.Count -eq 0) {
        Write-Host ' - No application inventory available.'
    }
    else {

        foreach ($application in $ApplicationInventory) {

            if ($application.Detected) {

                $selected = Test-ProfMigApplicationSelected `
                    -ApplicationId $application.Id `
                    -SelectedApplications $SelectedApplications

                if ($selected) {
                    Write-Host " - [X] $($application.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host " - [ ] $($application.Name)" -ForegroundColor Yellow
                }
            }
            elseif ($application.Status -eq 'DetectionFailed') {
                Write-Host `
                    " - [Detection failed] $($application.Name)" `
                    -ForegroundColor Red
            }
            elseif ($application.Status -eq 'ProviderUnavailable') {
                Write-Host `
                    " - [Unavailable] $($application.Name)" `
                    -ForegroundColor Yellow
            }
            elseif ($application.Status -eq 'InvalidDefinition') {
                Write-Host `
                    " - [Invalid definition] $($application.Name)" `
                    -ForegroundColor Red
            }
            else {
                Write-Host " - [Not detected] $($application.Name)"
            }
        }
    }

    Write-Host ''
    Read-Host 'Press Enter to return to the main menu' |
        Out-Null
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
            Write-Host "Status         : $($Result.Status)" -ForegroundColor Green
        }

        'Success with warnings' {
            Write-Host "Status         : $($Result.Status)" -ForegroundColor Yellow
        }

        'Failed' {
            Write-Host "Status         : $($Result.Status)" -ForegroundColor Red
        }

        default {
            Write-Host "Status         : $($Result.Status)" -ForegroundColor Yellow
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

    if ($Result.SkippedItems.Count -gt 0) {

        Write-Host ''
        Write-Host 'Skipped items' -ForegroundColor Yellow

        foreach ($item in $Result.SkippedItems) {
            Write-Host " - $($item.SourceFile)" -ForegroundColor Yellow
            Write-Host "   Reason: $($item.Reason)" -ForegroundColor DarkYellow
        }
    }

    if ($Result.Warnings.Count -gt 0) {

        Write-Host ''
        Write-Host 'Warnings' -ForegroundColor Yellow

        foreach ($warning in $Result.Warnings) {
            Write-Host " - $warning" -ForegroundColor Yellow
        }
    }

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
# Internal function: Show-ProfMigApplicationMigrationResult
# ---------------------------------------------------------------------------

function Show-ProfMigApplicationMigrationResult {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Result
    )

    Write-Host ''
    Write-Host 'Application migration result' -ForegroundColor Cyan
    Write-Host '============================' -ForegroundColor Cyan
    Write-Host ''

    foreach ($applicationResult in $Result.Results) {

        $statusColor = switch ($applicationResult.Status) {

            'Success' {
                'Green'
            }

            'Warning' {
                'Yellow'
            }

            'Skipped' {
                'Yellow'
            }

            'Failed' {
                'Red'
            }

            default {
                'White'
            }
        }

        Write-Host (
            '{0,-25} {1,-10} Provider: {2}' -f
            $applicationResult.Name,
            $applicationResult.Status,
            $applicationResult.ProviderStatus
        ) -ForegroundColor $statusColor

        if (-not [string]::IsNullOrWhiteSpace($applicationResult.Error)) {
            Write-Host (
                "  Error: $($applicationResult.Error)"
            ) -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host "Status             : $($Result.Status)"
    Write-Host "Applications       : $($Result.ApplicationsTotal)"
    Write-Host "Successful         : $($Result.ApplicationsSuccess)"
    Write-Host "Warnings           : $($Result.ApplicationsWarning)"
    Write-Host "Failed             : $($Result.ApplicationsFailed)"
    Write-Host "Skipped            : $($Result.ApplicationsSkipped)"
    Write-Host "Files copied       : $($Result.FilesCopied)"
    Write-Host "Files failed       : $($Result.FilesFailed)"
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
            'Music'
            'Videos'
            'Favorites'
            'Links'
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
        [string]$ReportFolder,

        [Parameter()]
        [object[]]$ApplicationDefinitions = @()
    )

    $sourceProfile = $null
    $destinationProfile = $null

    $applicationInventory = @()
    $selectedApplications = @()

    $running = $true

    while ($running) {

        Show-Header `
            -Configuration $Configuration `
            -SourceProfile $sourceProfile `
            -DestinationProfile $destinationProfile `
            -SelectedApplications $selectedApplications

        Write-Host '1. Select source profile'
        Write-Host '2. Select destination profile'
        Write-Host '3. Select applications'
        Write-Host '4. Show migration configuration'
        Write-Host '5. Start migration'
        Write-Host '6. Exit'
        Write-Host ''

        $selection = Read-Host 'Select an option'

        switch ($selection) {

            # ----------------------------------------------------------------
            # 1 - Select source profile
            # ----------------------------------------------------------------

            '1' {

                $selectedSourceProfile = Select-User `
                    -Users $Profiles `
                    -Title 'Select source profile'

                if (
                    $null -ne $destinationProfile -and
                    $selectedSourceProfile.ProfilePath -eq
                    $destinationProfile.ProfilePath
                ) {

                    Write-Host ''
                    Write-Host `
                        'Source and destination profile cannot be the same.' `
                        -ForegroundColor Red

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                $sourceProfile = $selectedSourceProfile

                # A new source profile invalidates the old application state.
                $applicationInventory = @()
                $selectedApplications = @()

                try {

                    Write-Info (
                        "Detecting applications for source profile " +
                        "'$($sourceProfile.ProfileName)'."
                    )

                    $applicationInventory = @(
                        Get-ProfMigApplicationInventory `
                            -SourceProfilePath $sourceProfile.ProfilePath `
                            -ApplicationDefinitions $ApplicationDefinitions
                    )

                    $detectedApplications = @(
                        Get-ProfMigDetectedApplications `
                            -ApplicationInventory $applicationInventory
                    )

                    # All detected applications are selected by default.
                    $selectedApplications = @($detectedApplications)

                    Write-Info (
                        "$($detectedApplications.Count) application(s) detected."
                    )

                    Show-ProfMigDetectedApplications `
                        -ApplicationInventory $applicationInventory `
                        -SelectedApplications $selectedApplications

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null
                }
                catch {

                    $applicationInventory = @()
                    $selectedApplications = @()

                    Write-Host ''
                    Write-Host 'Application detection failed.' -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    Write-Host ''

                    Write-Warning (
                        "Application detection failed for source profile " +
                        "'$($sourceProfile.ProfileName)': " +
                        "$($_.Exception.Message)"
                    )

                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null
                }
            }


            # ----------------------------------------------------------------
            # 2 - Select destination profile
            # ----------------------------------------------------------------

            '2' {

                $selectedDestinationProfile = Select-User `
                    -Users $Profiles `
                    -Title 'Select destination profile'

                if (
                    $null -ne $sourceProfile -and
                    $selectedDestinationProfile.ProfilePath -eq
                    $sourceProfile.ProfilePath
                ) {

                    Write-Host ''
                    Write-Host `
                        'Source and destination profile cannot be the same.' `
                        -ForegroundColor Red

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                $destinationProfile = $selectedDestinationProfile
            }


            # ----------------------------------------------------------------
            # 3 - Select applications
            # ----------------------------------------------------------------

            '3' {

                if ($null -eq $sourceProfile) {

                    Write-Host ''
                    Write-Host `
                        'Select a source profile first.' `
                        -ForegroundColor Yellow

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                $selectedApplications = @(
                    Select-ProfMigApplications `
                        -ApplicationInventory $applicationInventory `
                        -SelectedApplications $selectedApplications
                )

                Write-Info (
                    "$($selectedApplications.Count) application(s) " +
                    "selected for migration."
                )
            }


            # ----------------------------------------------------------------
            # 4 - Show migration configuration
            # ----------------------------------------------------------------

            '4' {

                Show-ProfMigConfiguration `
                    -Configuration $Configuration `
                    -ReportFolder $ReportFolder `
                    -ApplicationInventory $applicationInventory `
                    -SelectedApplications $selectedApplications
            }


            # ----------------------------------------------------------------
            # 5 - Start migration
            # ----------------------------------------------------------------

            '5' {

                Write-Host ''

                # ------------------------------------------------------------
                # Validate source and destination
                # ------------------------------------------------------------

                if (
                    $null -eq $sourceProfile -or
                    $null -eq $destinationProfile
                ) {

                    Write-Host 'Migration cannot start.' -ForegroundColor Yellow

                    Write-Host `
                        'A valid source and destination profile must be selected.'

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                if (-not $sourceProfile.Accessible) {

                    Write-Host 'Migration cannot start.' -ForegroundColor Yellow
                    Write-Host 'The selected source profile is not accessible.'

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                if (-not $destinationProfile.Accessible) {

                    Write-Host 'Migration cannot start.' -ForegroundColor Yellow
                    Write-Host 'The selected destination profile is not accessible.'

                    Write-Host ''
                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                # ------------------------------------------------------------
                # M1 configuration
                # ------------------------------------------------------------

                $copyConfiguration = New-ProfMigCopyConfiguration

                # ------------------------------------------------------------
                # Pre-migration validation
                # ------------------------------------------------------------

                $validationConfiguration = @{}

                foreach ($key in $Configuration.Keys) {
                    $validationConfiguration[$key] = $Configuration[$key]
                }

                $validationConfiguration['Folders'] = @(
                    $copyConfiguration.Folders
                )

                $validationConfiguration['AdditionalFolders'] = @(
                    $copyConfiguration.AdditionalFolders
                )

                $selectedApplicationIds = @(
                    $selectedApplications |
                        ForEach-Object {
                            $_.Id
                        }
                )

                try {

                    Write-Host 'Running pre-migration validation...' `
                        -ForegroundColor Cyan
                    Write-Host ''

                    $validationResult = Invoke-ProfMigPreMigrationValidation `
                        -SourceProfile $sourceProfile.ProfilePath `
                        -DestinationProfile $destinationProfile.ProfilePath `
                        -Configuration $validationConfiguration `
                        -SelectedApplications $selectedApplicationIds

                    $storageValidation = @(
                        $validationResult.Results |
                            Where-Object {
                                $_.Check -eq 'FreeDiskSpace'
                            }
                    ) |
                        Select-Object -First 1

                    if ($null -ne $storageValidation) {

                        $storageColor = switch ($storageValidation.Status) {
                            'Passed'  { 'Green' }
                            'Warning' { 'Yellow' }
                            'Failed'  { 'Red' }
                            default   { 'White' }
                        }

                        Write-Host 'Storage capacity' -ForegroundColor Cyan
                        Write-Host (
                            " Selected data   : {0}" -f
                            $storageValidation.Details['SourceSize']
                        )
                        Write-Host (
                            " Profile data    : {0}" -f
                            $storageValidation.Details['ProfileSize']
                        )
                        Write-Host (
                            " Application data: {0}" -f
                            $storageValidation.Details['ApplicationSize']
                        )
                        Write-Host (
                            " Safety margin   : {0}%" -f
                            $storageValidation.Details['BufferPercent']
                        )
                        Write-Host (
                            " Required space  : {0}" -f
                            $storageValidation.Details['RequiredSize']
                        )
                        Write-Host (
                            " Available space : {0}" -f
                            $storageValidation.Details['AvailableSize']
                        )
                        $estimateComplete =
                            $storageValidation.Details['EstimateComplete']

                        $estimateText = if ($estimateComplete -eq $false) {
                            'No'
                        }
                        else {
                            'Yes'
                        }

                        $estimateColor = if ($estimateComplete -eq $false) {
                            'Yellow'
                        }
                        else {
                            'Green'
                        }

                        Write-Host (
                            " Estimate complete: {0}" -f
                            $estimateText
                        ) -ForegroundColor $estimateColor

                        $unsupportedApplications = @(
                            $storageValidation.Details['UnsupportedApplications']
                        )

                        if ($unsupportedApplications.Count -gt 0) {
                            Write-Host (
                                " Unsupported apps : {0}" -f
                                ($unsupportedApplications -join ', ')
                            ) -ForegroundColor Yellow
                        }

                        Write-Host (
                            " Status          : {0}" -f
                            $storageValidation.Status
                        ) -ForegroundColor $storageColor
                        Write-Host ''
                    }

                    foreach ($validationWarning in @(
                        $validationResult.Results |
                            Where-Object {
                                $_.Status -eq 'Warning'
                            }
                    )) {
                        Write-Host (
                            "Validation warning: {0}" -f
                            $validationWarning.Message
                        ) -ForegroundColor Yellow
                    }

                    if (-not $validationResult.CanProceed) {

                        Write-Host ''
                        Write-Host 'Migration blocked.' -ForegroundColor Red
                        Write-Host (
                            'One or more critical pre-migration validation ' +
                            'checks failed.'
                        ) -ForegroundColor Red
                        Write-Host ''

                        foreach ($failedValidation in @(
                            $validationResult.Results |
                                Where-Object {
                                    $_.Severity -eq 'Critical' -and
                                    $_.Status -eq 'Failed'
                                }
                        )) {
                            Write-Host (
                                " - {0}: {1}" -f
                                $failedValidation.Check,
                                $failedValidation.Message
                            ) -ForegroundColor Red
                        }

                        Write-Host ''
                        Read-Host 'Press Enter to return to the main menu' |
                            Out-Null

                        continue
                    }
                }
                catch {

                    Write-Host ''
                    Write-Host 'Pre-migration validation failed.' `
                        -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red
                    Write-Host ''

                    Write-ErrorLog (
                        "Pre-migration validation failed: " +
                        "$($_.Exception.Message)"
                    )

                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                # ------------------------------------------------------------
                # Migration summary
                # ------------------------------------------------------------

                Write-Host "Source profile      : $($sourceProfile.ProfileName)"
                Write-Host "Destination profile : $($destinationProfile.ProfileName)"
                Write-Host ''

                Write-Host `
                    'The following folders will be migrated:' `
                    -ForegroundColor Cyan

                foreach ($folder in $copyConfiguration.Folders) {
                    Write-Host " - $folder"
                }

                Write-Host ''
                Write-Host 'Applications selected:' -ForegroundColor Cyan

                if ($selectedApplications.Count -eq 0) {
                    Write-Host ' - None' -ForegroundColor Yellow
                }
                else {

                    foreach ($application in $selectedApplications) {
                        Write-Host " - $($application.Name)"
                    }
                }

                Write-Host ''
                Write-Host `
                    'Existing destination files will NOT be overwritten.' `
                    -ForegroundColor Yellow

                Write-Host ''

                $confirmation = Read-Host 'Start migration? (Y/N)'

                if ($confirmation -notmatch '^[Yy]$') {

                    Write-Host ''
                    Write-Host 'Migration cancelled.' -ForegroundColor Yellow
                    Write-Host ''

                    Read-Host 'Press Enter to return to the main menu' |
                        Out-Null

                    continue
                }

                $copyResult = $null
                $applicationMigrationResult = $null
                $reportResult = $null
                $reportPath = $null

                Write-Host ''
                Write-Host 'Migration started...' -ForegroundColor Cyan
                Write-Host ''

                # ------------------------------------------------------------
                # M1 profile migration
                # ------------------------------------------------------------

                try {

                    Write-Info 'Starting profile folder migration.'

                    $copyResult = Invoke-ProfMigCopy `
                        -SourceProfile $sourceProfile.ProfilePath `
                        -DestinationProfile $destinationProfile.ProfilePath `
                        -Configuration $validationConfiguration
                }
                catch {

                    Write-Host ''
                    Write-Host 'Profile migration failed.' -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red

                    Write-ErrorLog (
                        "Profile migration failed: $($_.Exception.Message)"
                    )
                }

                # ------------------------------------------------------------
                # M2 application migration
                #
                # This deliberately has its own try/catch. A profile copy
                # problem must not unnecessarily prevent application
                # migration, and application problems must not destroy the
                # M1 result.
                # ------------------------------------------------------------

                if ($selectedApplications.Count -gt 0) {

                    try {

                        Write-Host ''
                        Write-Host `
                            'Starting application migration...' `
                            -ForegroundColor Cyan
                        Write-Host ''

                        $applicationMigrationResult = `
                            Invoke-ProfMigSelectedApplicationMigration `
                                -Applications $selectedApplications `
                                -SourceProfile $sourceProfile.ProfilePath `
                                -DestinationProfile $destinationProfile.ProfilePath

                        Show-ProfMigApplicationMigrationResult `
                            -Result $applicationMigrationResult
                    }
                    catch {

                        Write-Host ''
                        Write-Host `
                            'Application migration dispatcher failed.' `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message -ForegroundColor Red

                        Write-ErrorLog (
                            "Application migration dispatcher failed: " +
                            "$($_.Exception.Message)"
                        )
                    }
                }
                else {

                    Write-Info 'No applications selected for migration.'
                }

                # ------------------------------------------------------------
                # Integrated migration reporting
                #
                # Combine profile migration and application migration results
                # into one reporting result.
                # ------------------------------------------------------------

                if ($null -ne $copyResult) {

                    try {

                        $reportResult = ConvertTo-ProfMigMigrationResult `
                            -CopyResult $copyResult `
                            -ApplicationMigrationResult $applicationMigrationResult `
                            -ProfMigVersion $Configuration.Application.Version

                        $reportPath = New-ProfMigMigrationReport `
                            -MigrationResult $reportResult `
                            -ReportFolder $ReportFolder

                        Show-ProfMigMigrationResult `
                            -Result $reportResult `
                            -ReportPath $reportPath
                    }
                    catch {

                        Write-Host ''
                        Write-Host `
                            'Migration reporting failed.' `
                            -ForegroundColor Red

                        Write-Host $_.Exception.Message -ForegroundColor Red

                        Write-ErrorLog (
                            "Migration reporting failed: " +
                            "$($_.Exception.Message)"
                        )
                    }
                }

                Write-Host ''
                Read-Host 'Press Enter to return to the main menu' |
                    Out-Null
            }


            # ----------------------------------------------------------------
            # 6 - Exit
            # ----------------------------------------------------------------

            '6' {

                Write-Host ''
                Write-Host 'Exiting ProfMig...'

                $running = $false
            }


            # ----------------------------------------------------------------
            # Invalid option
            # ----------------------------------------------------------------

            default {

                Write-Host ''
                Write-Host `
                    'Invalid selection. Choose option 1 through 6.' `
                    -ForegroundColor Red

                Start-Sleep -Seconds 2
            }
        }
    }

    return [PSCustomObject]@{
        SourceProfile              = $sourceProfile
        DestinationProfile         = $destinationProfile
        ApplicationInventory       = @($applicationInventory)
        SelectedApplications       = @($selectedApplications)
        ApplicationMigrationResult = $applicationMigrationResult
    }
}


# ---------------------------------------------------------------------------
# Module exports
# ---------------------------------------------------------------------------

Export-ModuleMember -Function Start-ProfMigMenu
