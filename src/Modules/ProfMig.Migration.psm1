# ============================================================================
# ProfMig.Migration.psm1
#
# Shared migration orchestration for ProfMig.
#
# Responsibilities:
# - Resolve source and destination profiles
# - Prepare migration configuration
# - Execute pre-migration validation
# - Execute profile migration
# - Execute application migration
# - Generate migration reports
# - Return a standardized migration result
#
# This module contains no interactive user input. It can therefore be used by
# both the interactive ProfMig menu and command-line / silent execution.
# ============================================================================


# ----------------------------------------------------------------------------
# Public function: Resolve-ProfMigProfile
# ----------------------------------------------------------------------------

function Resolve-ProfMigProfile {

    [CmdletBinding(DefaultParameterSetName = 'BySid')]
    param (
        [Parameter(Mandatory)]
        [array]$Profiles,

        [Parameter(
            Mandatory,
            ParameterSetName = 'BySid'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$Sid,

        [Parameter(
            Mandatory,
            ParameterSetName = 'ByPath'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $profileMatches = @()

    switch ($PSCmdlet.ParameterSetName) {

        'BySid' {

            $profileMatches = @(
                $Profiles |
                    Where-Object {
                        $_.SID -eq $Sid
                    }
            )
        }

        'ByPath' {

            $normalizedRequestedPath = $ProfilePath.TrimEnd('\')

            $profileMatches = @(
                $Profiles |
                    Where-Object {
                        -not [string]::IsNullOrWhiteSpace($_.ProfilePath) -and
                        $_.ProfilePath.TrimEnd('\') -ieq
                            $normalizedRequestedPath
                    }
            )
        }
    }

    if ($profileMatches.Count -eq 0) {

        $identifier = if ($PSCmdlet.ParameterSetName -eq 'BySid') {
            $Sid
        }
        else {
            $ProfilePath
        }

        throw (
            New-ProfMigException `
                -Message (
                    "Windows profile could not be resolved: $identifier"
                ) `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'ProfileNotFound'
        )
    }

    if ($profileMatches.Count -gt 1) {

        $identifier = if ($PSCmdlet.ParameterSetName -eq 'BySid') {
            $Sid
        }
        else {
            $ProfilePath
        }

        throw (
            New-ProfMigException `
                -Message (
                    "Windows profile identifier is ambiguous: $identifier"
                ) `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'AmbiguousProfile'
        )
    }

    return $profileMatches[0]
}


# ----------------------------------------------------------------------------
# Public function: Test-ProfMigMigrationProfiles
# ----------------------------------------------------------------------------

function Test-ProfMigMigrationProfiles {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $SourceProfile,

        [Parameter(Mandatory)]
        $DestinationProfile
    )

    if (-not $SourceProfile.Accessible) {

        throw (
            New-ProfMigException `
                -Message 'The source profile is not accessible.' `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'SourceProfileNotAccessible'
        )
    }

    if (-not $DestinationProfile.Accessible) {

        throw (
            New-ProfMigException `
                -Message 'The destination profile is not accessible.' `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'DestinationProfileNotAccessible'
        )
    }

    if (
        $SourceProfile.ProfilePath.TrimEnd('\') -ieq
        $DestinationProfile.ProfilePath.TrimEnd('\')
    ) {

        throw (
            New-ProfMigException `
                -Message (
                    'Source and destination profile cannot use the same path.'
                ) `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'SourceEqualsDestination'
        )
    }

    if (
        -not [string]::IsNullOrWhiteSpace($SourceProfile.SID) -and
        -not [string]::IsNullOrWhiteSpace($DestinationProfile.SID) -and
        $SourceProfile.SID -eq $DestinationProfile.SID
    ) {

        throw (
            New-ProfMigException `
                -Message (
                    'Source and destination profile cannot use the same SID.'
                ) `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'SourceSidEqualsDestinationSid'
        )
    }

    return $true
}


# ----------------------------------------------------------------------------
# Public function: New-ProfMigMigrationConfiguration
# ----------------------------------------------------------------------------

function New-ProfMigMigrationConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Configuration
    )

    $migrationConfiguration = @{}

    foreach ($key in $Configuration.Keys) {
        $migrationConfiguration[$key] = $Configuration[$key]
    }

    # Use explicitly configured migration folders when provided.
    # Otherwise preserve the standard ProfMig folder selection.
    if (
        $Configuration.ContainsKey('Folders') -and
        $null -ne $Configuration.Folders -and
        @($Configuration.Folders).Count -gt 0
    ) {
        $migrationConfiguration['Folders'] = @(
            $Configuration.Folders
        )
    }
    else {
        $migrationConfiguration['Folders'] = @(
            'Desktop'
            'Documents'
            'Downloads'
            'Pictures'
            'Music'
            'Videos'
            'Favorites'
            'Links'
        )
    }

    if (
        $Configuration.ContainsKey('AdditionalFolders') -and
        $null -ne $Configuration.AdditionalFolders
    ) {
        $migrationConfiguration['AdditionalFolders'] = @(
            $Configuration.AdditionalFolders
        )
    }
    else {
        $migrationConfiguration['AdditionalFolders'] = @()
    }

    return $migrationConfiguration
}


# ----------------------------------------------------------------------------
# Public function: Invoke-ProfMigMigration
# ----------------------------------------------------------------------------

function Invoke-ProfMigMigration {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        $Configuration,

        [Parameter(Mandatory)]
        $SourceProfile,

        [Parameter(Mandatory)]
        $DestinationProfile,

        [Parameter(Mandatory)]
        [string]$ReportFolder,

        [Parameter()]
        [object[]]$SelectedApplications = @()
    )

    # ------------------------------------------------------------------------
    # Validate selected profiles
    # ------------------------------------------------------------------------

    $null = Test-ProfMigMigrationProfiles `
        -SourceProfile $SourceProfile `
        -DestinationProfile $DestinationProfile

    # ------------------------------------------------------------------------
    # Build migration configuration
    # ------------------------------------------------------------------------

    $migrationConfiguration = New-ProfMigMigrationConfiguration `
        -Configuration $Configuration

    $selectedApplicationIds = @(
        $SelectedApplications |
            ForEach-Object {
                $_.Id
            }
    )

    # ------------------------------------------------------------------------
    # Pre-migration validation
    # ------------------------------------------------------------------------

    Write-Info 'Running pre-migration validation.'

    $validationResult = Invoke-ProfMigPreMigrationValidation `
        -SourceProfile $SourceProfile.ProfilePath `
        -DestinationProfile $DestinationProfile.ProfilePath `
        -Configuration $migrationConfiguration `
        -SelectedApplications $selectedApplicationIds

    if (-not $validationResult.CanProceed) {

        $failedChecks = @(
            $validationResult.Results |
                Where-Object {
                    $_.Severity -eq 'Critical' -and
                    $_.Status -eq 'Failed'
                }
        )

        $failedCheckText = @(
            $failedChecks |
                ForEach-Object {
                    '{0}: {1}' -f $_.Check, $_.Message
                }
        ) -join '; '

        if ([string]::IsNullOrWhiteSpace($failedCheckText)) {
            $failedCheckText = 'Unknown critical validation failure.'
        }

        throw (
            New-ProfMigException `
                -Message (
                    'Pre-migration validation blocked the migration. ' +
                    $failedCheckText
                ) `
                -Category 'ValidationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'PreMigrationValidationFailed'
        )
    }

    # ------------------------------------------------------------------------
    # Profile migration
    # ------------------------------------------------------------------------

    Write-Info (
        "Starting profile migration from " +
        "'$($SourceProfile.ProfilePath)' to " +
        "'$($DestinationProfile.ProfilePath)'."
    )

    $copyResult = Invoke-ProfMigCopy `
        -SourceProfile $SourceProfile.ProfilePath `
        -DestinationProfile $DestinationProfile.ProfilePath `
        -Configuration $migrationConfiguration

    # ------------------------------------------------------------------------
    # Application migration
    # ------------------------------------------------------------------------

    $applicationMigrationResult = $null

    if ($SelectedApplications.Count -gt 0) {

        Write-Info (
            "Starting migration of " +
            "$($SelectedApplications.Count) application(s)."
        )

        $applicationMigrationResult =
            Invoke-ProfMigSelectedApplicationMigration `
                -Applications $SelectedApplications `
                -SourceProfile $SourceProfile.ProfilePath `
                -DestinationProfile $DestinationProfile.ProfilePath `
                -Configuration $migrationConfiguration
    }
    else {

        Write-Info 'No applications selected for migration.'
    }

    # ------------------------------------------------------------------------
    # Integrated reporting
    # ------------------------------------------------------------------------

    $reportResult = ConvertTo-ProfMigMigrationResult `
        -CopyResult $copyResult `
        -ApplicationMigrationResult $applicationMigrationResult `
        -ProfMigVersion $Configuration.Application.Version

    $reportPath = New-ProfMigMigrationReport `
        -MigrationResult $reportResult `
        -ReportFolder $ReportFolder

    # ------------------------------------------------------------------------
    # Return standardized orchestration result
    # ------------------------------------------------------------------------

    return [PSCustomObject]@{
        SourceProfile              = $SourceProfile
        DestinationProfile         = $DestinationProfile
        ValidationResult           = $validationResult
        CopyResult                 = $copyResult
        ApplicationMigrationResult = $applicationMigrationResult
        MigrationResult            = $reportResult
        ReportPath                 = $reportPath
        Status                     = $reportResult.Status
    }
}


# ----------------------------------------------------------------------------
# Module exports
# ----------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Resolve-ProfMigProfile',
    'Test-ProfMigMigrationProfiles',
    'New-ProfMigMigrationConfiguration',
    'Invoke-ProfMigMigration'
)