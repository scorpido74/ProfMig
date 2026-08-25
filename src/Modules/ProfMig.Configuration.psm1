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
# Module exports
# ============================================================================

Export-ModuleMember -Function @(
    'Import-ProfMigConfiguration',
    'Get-ProfMigConfiguration'
)