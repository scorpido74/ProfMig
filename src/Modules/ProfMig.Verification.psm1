<#
.SYNOPSIS
    Provides migration verification functionality for ProfMig.

.DESCRIPTION
    Contains the verification framework used to validate that data reported
    as migrated exists at the destination and matches the expected source data.

    Verification is read-only and must never modify source or destination data.
#>

Set-StrictMode -Version Latest


# -----------------------------------------------------------------------------
# Supported verification levels
# -----------------------------------------------------------------------------

$script:ProfMigVerificationLevels = @(
    'Basic'
    'Standard'
    'Hash'
)


function Test-ProfMigVerificationLevel {
    <#
    .SYNOPSIS
        Tests whether a verification level is supported.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Level
    )

    return $script:ProfMigVerificationLevels -contains $Level
}


function New-ProfMigVerificationResult {
    <#
    .SYNOPSIS
        Creates a structured ProfMig verification result.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$SourceFile,

        [Parameter(Mandatory)]
        [string]$DestinationFile,

        [Parameter(Mandatory)]
        [ValidateSet('Basic', 'Standard', 'Hash')]
        [string]$VerificationLevel,

        [bool]$SourceExists = $false,

        [bool]$DestinationExists = $false,

        [Nullable[long]]$SourceSize = $null,

        [Nullable[long]]$DestinationSize = $null,

        [Nullable[bool]]$SizeMatch = $null,

        [AllowNull()]
        [string]$HashAlgorithm = $null,

        [AllowNull()]
        [string]$SourceHash = $null,

        [AllowNull()]
        [string]$DestinationHash = $null,

        [Nullable[bool]]$HashMatch = $null,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failed', 'Skipped')]
        [string]$Status,

        [Parameter(Mandatory)]
        [string]$Reason
    )

    $verified = $Status -eq 'Success'

    [pscustomobject]@{
        PSTypeName        = 'ProfMig.VerificationResult'
        Component         = $Component
        SourceFile        = $SourceFile
        DestinationFile   = $DestinationFile
        VerificationLevel = $VerificationLevel

        SourceExists      = $SourceExists
        DestinationExists = $DestinationExists

        SourceSize        = $SourceSize
        DestinationSize   = $DestinationSize
        SizeMatch         = $SizeMatch

        HashAlgorithm     = $HashAlgorithm
        SourceHash        = $SourceHash
        DestinationHash   = $DestinationHash
        HashMatch         = $HashMatch

        Status            = $Status
        Reason            = $Reason
        Verified          = $verified
    }
}


function New-ProfMigVerificationSummary {
    <#
    .SYNOPSIS
        Creates a structured migration verification summary.
    #>

    [CmdletBinding()]
    param (
        [long]$FilesSelected = 0,

        [long]$FilesCopied = 0,

        [long]$FilesVerified = 0,

        [long]$FilesSkipped = 0,

        [long]$FilesFailed = 0,

        [long]$BytesSelected = 0,

        [long]$BytesCopied = 0,

        [long]$BytesVerified = 0,

        [long]$VerificationFailures = 0
    )

    [pscustomobject]@{
        PSTypeName           = 'ProfMig.VerificationSummary'

        FilesSelected        = $FilesSelected
        FilesCopied          = $FilesCopied
        FilesVerified        = $FilesVerified
        FilesSkipped         = $FilesSkipped
        FilesFailed          = $FilesFailed

        BytesSelected        = $BytesSelected
        BytesCopied          = $BytesCopied
        BytesVerified        = $BytesVerified

        VerificationFailures = $VerificationFailures
    }
}


Export-ModuleMember -Function @(
    'Test-ProfMigVerificationLevel'
    'New-ProfMigVerificationResult'
    'New-ProfMigVerificationSummary'
)