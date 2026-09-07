<#
.SYNOPSIS
    Configuration handling for ProfMig.

.DESCRIPTION
    Loads and exposes the ProfMig configuration.

.NOTES
    Project : ProfMig
    Module  : ProfMig.Configuration
#>

Set-StrictMode -Version Latest

# ============================================================================
# Import-ProfMigConfiguration
# ============================================================================

function Import-ProfMigConfiguration {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Leaf
        )
    ) {

        throw (
            New-ProfMigException `
                -Message "Configuration file not found: $Path" `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'ConfigurationFileNotFound'
        )
    }

    try {

    $script:Config = Import-PowerShellDataFile `
        -LiteralPath $Path `
        -ErrorAction Stop

    $null = Test-ProfMigConfigurationSchema `
        -Configuration $script:Config
    }
    catch {

        throw (
            New-ProfMigException `
                -Message "Configuration file could not be loaded: $Path" `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'ConfigurationLoadFailed' `
                -InnerException $_.Exception
        )
    }

    return $script:Config
}


# ============================================================================
# Get-ProfMigConfiguration
# ============================================================================

function Get-ProfMigConfiguration {

    return $script:Config
}

# ============================================================================
# Test-ProfMigConfigurationSchema
# ============================================================================

function Test-ProfMigConfigurationSchema {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration
    )

    $supportedSchemaVersions = @(
        '1.0'
    )

    # ------------------------------------------------------------------------
    # Schema version
    # ------------------------------------------------------------------------

    if (
        $Configuration.Contains('SchemaVersion') -and
        -not [string]::IsNullOrWhiteSpace(
            [string]$Configuration.SchemaVersion
        )
    ) {

        $schemaVersion = [string]$Configuration.SchemaVersion

        if ($schemaVersion -notin $supportedSchemaVersions) {

            throw (
                New-ProfMigException `
                    -Message (
                        "Unsupported ProfMig configuration schema version: " +
                        "$schemaVersion"
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'UnsupportedConfigurationSchema'
            )
        }
    }

    # Configurations created before schema versioning remain supported.
    # Missing SchemaVersion therefore represents the legacy configuration
    # format and must not cause an error.

    # ------------------------------------------------------------------------
    # Verification
    # ------------------------------------------------------------------------

    if (
        $Configuration.Contains('Verification') -and
        $null -ne $Configuration.Verification
    ) {

        $verification = $Configuration.Verification

        if (
            $verification.Contains('Level') -and
            [string]$verification.Level -notin @(
                'Standard'
                'Hash'
            )
        ) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Invalid verification level in ProfMig configuration: ' +
                        [string]$verification.Level
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidVerificationLevel'
            )
        }

        if (
            $verification.Contains('HashAlgorithm') -and
            [string]$verification.HashAlgorithm -notin @(
                'SHA256'
                'SHA384'
                'SHA512'
            )
        ) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Invalid hash algorithm in ProfMig configuration: ' +
                        [string]$verification.HashAlgorithm
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidHashAlgorithm'
            )
        }
    }

    # ------------------------------------------------------------------------
    # Retry
    # ------------------------------------------------------------------------

    if (
        $Configuration.Contains('Retry') -and
        $null -ne $Configuration.Retry
    ) {

        $retry = $Configuration.Retry

        if (
            $retry.Contains('Count') -and
            (
                $retry.Count -isnot [int] -or
                $retry.Count -lt 0 -or
                $retry.Count -gt 10
            )
        ) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Retry.Count must be an integer between 0 and 10.'
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidRetryCount'
            )
        }

        if (
            $retry.Contains('DelaySeconds') -and
            (
                $retry.DelaySeconds -isnot [int] -or
                $retry.DelaySeconds -lt 0 -or
                $retry.DelaySeconds -gt 60
            )
        ) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Retry.DelaySeconds must be an integer between 0 and 60.'
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidRetryDelay'
            )
        }
    }

    # ------------------------------------------------------------------------
    # Storage validation
    # ------------------------------------------------------------------------

    if (
        $Configuration.Contains('Validation') -and
        $null -ne $Configuration.Validation -and
        $Configuration.Validation.Contains('Storage') -and
        $null -ne $Configuration.Validation.Storage
    ) {

        $storage = $Configuration.Validation.Storage

        foreach ($propertyName in @(
            'SafetyMarginPercent'
            'WarningRemainingPercent'
        )) {

            if ($storage.Contains($propertyName)) {

                $value = $storage[$propertyName]

                if (
                    $value -isnot [int] -or
                    $value -lt 0 -or
                    $value -gt 100
                ) {

                    throw (
                        New-ProfMigException `
                            -Message (
                                "Validation.Storage.$propertyName must be " +
                                'an integer between 0 and 100.'
                            ) `
                            -Category 'ConfigurationError' `
                            -Severity 'Critical' `
                            -RecoveryAction 'Stop' `
                            -Reason 'InvalidStorageConfiguration'
                    )
                }
            }
        }
    }

    return $true
}

# ============================================================================
# Test-ProfMigMigrationProfile
# ============================================================================

function Test-ProfMigMigrationProfile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Profile
    )

    $supportedSchemaVersions = @(
        '1.0'
    )

    $supportedComponents = @(
        'Desktop'
        'Documents'
        'Downloads'
        'Pictures'
        'Music'
        'Videos'
        'Favorites'
        'Links'
    )

    $supportedApplications = @(
        'Microsoft.Edge'
        'Google.Chrome'
        'Microsoft.Outlook'
    )

    # ------------------------------------------------------------------------
    # Required profile schema version
    # ------------------------------------------------------------------------

    if (
        -not $Profile.Contains('SchemaVersion') -or
        [string]::IsNullOrWhiteSpace(
            [string]$Profile.SchemaVersion
        )
    ) {
        throw (
            New-ProfMigException `
                -Message 'Migration profile SchemaVersion is required.' `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'MigrationProfileSchemaMissing'
        )
    }

    if (
        [string]$Profile.SchemaVersion -notin $supportedSchemaVersions
    ) {
        throw (
            New-ProfMigException `
                -Message (
                    'Unsupported migration profile schema version: ' +
                    [string]$Profile.SchemaVersion
                ) `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'UnsupportedMigrationProfileSchema'
        )
    }

    # ------------------------------------------------------------------------
    # Profile metadata
    # ------------------------------------------------------------------------

    if (
        -not $Profile.Contains('Profile') -or
        $null -eq $Profile.Profile -or
        -not $Profile.Profile.Contains('Name') -or
        [string]::IsNullOrWhiteSpace(
            [string]$Profile.Profile.Name
        )
    ) {
        throw (
            New-ProfMigException `
                -Message 'Migration profile Name is required.' `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'MigrationProfileNameMissing'
        )
    }

    # ------------------------------------------------------------------------
    # Components
    # ------------------------------------------------------------------------

    if (
        -not $Profile.Contains('Components') -or
        $null -eq $Profile.Components
    ) {
        throw (
            New-ProfMigException `
                -Message 'Migration profile Components are required.' `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'MigrationProfileComponentsMissing'
        )
    }

    foreach ($component in @($Profile.Components)) {

        if ([string]$component -notin $supportedComponents) {

            throw (
                New-ProfMigException `
                    -Message (
                        'Unsupported migration component: ' +
                        [string]$component
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'UnsupportedMigrationComponent'
            )
        }
    }

    # ------------------------------------------------------------------------
    # Applications
    # ------------------------------------------------------------------------

    if (
        $Profile.Contains('Applications') -and
        $null -ne $Profile.Applications
    ) {

        $applications = $Profile.Applications

        if (
            $applications.Contains('Enabled') -and
            $applications.Enabled -isnot [bool]
        ) {
            throw (
                New-ProfMigException `
                    -Message 'Applications.Enabled must be a Boolean value.' `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidApplicationProfileSetting'
            )
        }

        if (
            $applications.Contains('Include') -and
            $null -ne $applications.Include
        ) {

            foreach ($application in @($applications.Include)) {

                if (
                    [string]$application -notin
                    $supportedApplications
                ) {
                    throw (
                        New-ProfMigException `
                            -Message (
                                'Unsupported migration application: ' +
                                [string]$application
                            ) `
                            -Category 'ConfigurationError' `
                            -Severity 'Critical' `
                            -RecoveryAction 'Stop' `
                            -Reason 'UnsupportedMigrationApplication'
                    )
                }
            }
        }
    }

    # ------------------------------------------------------------------------
    # Verification
    # ------------------------------------------------------------------------

    if (
        $Profile.Contains('Verification') -and
        $null -ne $Profile.Verification -and
        $Profile.Verification.Contains('Level')
    ) {

        if (
            [string]$Profile.Verification.Level -notin @(
                'Standard'
                'Hash'
            )
        ) {
            throw (
                New-ProfMigException `
                    -Message (
                        'Invalid migration profile verification level: ' +
                        [string]$Profile.Verification.Level
                    ) `
                    -Category 'ConfigurationError' `
                    -Severity 'Critical' `
                    -RecoveryAction 'Stop' `
                    -Reason 'InvalidMigrationProfileVerificationLevel'
            )
        }
    }

    return $true
}

# ============================================================================
# Import-ProfMigMigrationProfile
# ============================================================================

function Import-ProfMigMigrationProfile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Leaf
        )
    ) {
        throw (
            New-ProfMigException `
                -Message "Migration profile was not found: $Path" `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'MigrationProfileNotFound'
        )
    }

    try {
        $profile = Import-PowerShellDataFile `
            -LiteralPath $Path `
            -ErrorAction Stop
    }
    catch {
        throw (
            New-ProfMigException `
                -Message (
                    "Migration profile could not be loaded: $Path. " +
                    $_.Exception.Message
                ) `
                -Category 'ConfigurationError' `
                -Severity 'Critical' `
                -RecoveryAction 'Stop' `
                -Reason 'MigrationProfileLoadFailed'
        )
    }

    $null = Test-ProfMigMigrationProfile `
        -Profile $profile

    return $profile
}

# ============================================================================
# Merge-ProfMigMigrationProfile
# ============================================================================

function Merge-ProfMigMigrationProfile {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Configuration,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Profile
    )

    $null = Test-ProfMigConfigurationSchema `
        -Configuration $Configuration

    $null = Test-ProfMigMigrationProfile `
        -Profile $Profile

    # Create a new configuration instead of modifying the global
    # configuration object supplied by the caller.
    $effectiveConfiguration = @{}

    foreach ($key in $Configuration.Keys) {
        $effectiveConfiguration[$key] = $Configuration[$key]
    }

    # ------------------------------------------------------------------------
    # Migration components
    #
    # Existing migration code consumes these through Configuration.Folders.
    # ------------------------------------------------------------------------

    $effectiveConfiguration['Folders'] = @(
        $Profile.Components
    )

    # ------------------------------------------------------------------------
    # Application selection
    # ------------------------------------------------------------------------

    $applications = @{
        Enabled = $true
        Include = @()
    }

    if (
        $Profile.Contains('Applications') -and
        $null -ne $Profile.Applications
    ) {
        if ($Profile.Applications.Contains('Enabled')) {
            $applications.Enabled = [bool]$Profile.Applications.Enabled
        }

        if (
            $Profile.Applications.Contains('Include') -and
            $null -ne $Profile.Applications.Include
        ) {
            $applications.Include = @(
                $Profile.Applications.Include
            )
        }
    }

    $effectiveConfiguration['MigrationApplications'] = $applications

    # ------------------------------------------------------------------------
    # Verification override
    #
    # Preserve the global hash algorithm unless explicitly supported by a
    # future migration profile schema.
    # ------------------------------------------------------------------------

    $verification = @{}

    if (
        $Configuration.Contains('Verification') -and
        $null -ne $Configuration.Verification
    ) {
        foreach ($key in $Configuration.Verification.Keys) {
            $verification[$key] = $Configuration.Verification[$key]
        }
    }

    if (
        $Profile.Contains('Verification') -and
        $null -ne $Profile.Verification -and
        $Profile.Verification.Contains('Level')
    ) {
        $verification['Level'] = [string]$Profile.Verification.Level
    }

    $effectiveConfiguration['Verification'] = $verification

    # ------------------------------------------------------------------------
    # Profile metadata
    # ------------------------------------------------------------------------

    $effectiveConfiguration['MigrationProfile'] = @{
        Name          = [string]$Profile.Profile.Name
        SchemaVersion = [string]$Profile.SchemaVersion
    }

    if ($Profile.Profile.Contains('Description')) {
        $effectiveConfiguration.MigrationProfile['Description'] =
            [string]$Profile.Profile.Description
    }

    return $effectiveConfiguration
}

# ============================================================================
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'Import-ProfMigConfiguration',
    'Get-ProfMigConfiguration',
    'Test-ProfMigConfigurationSchema',
    'Test-ProfMigMigrationProfile',
    'Import-ProfMigMigrationProfile',
    'Merge-ProfMigMigrationProfile'
)