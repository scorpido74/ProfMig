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

function Test-ProfMigFileVerification {
    <#
    .SYNOPSIS
        Verifies a migrated file against its source file.

    .DESCRIPTION
        Performs read-only verification of a source and destination file.

        Basic and Standard verification validate that the destination exists
        and that its file size matches the source.

        Hash verification is handled separately and is not performed by this
        function yet.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Component,

        [Parameter(Mandatory)]
        [string]$SourceFile,

        [Parameter(Mandatory)]
        [string]$DestinationFile,

        [Parameter()]
        [ValidateSet('Basic', 'Standard', 'Hash')]
        [string]$VerificationLevel = 'Standard'
    )

    $sourceExists = Test-Path -LiteralPath $SourceFile -PathType Leaf

    if (-not $sourceExists) {
        return New-ProfMigVerificationResult `
            -Component $Component `
            -SourceFile $SourceFile `
            -DestinationFile $DestinationFile `
            -VerificationLevel $VerificationLevel `
            -SourceExists $false `
            -DestinationExists (
                Test-Path -LiteralPath $DestinationFile -PathType Leaf
            ) `
            -Status 'Failed' `
            -Reason 'VerificationReadError'
    }

    try {
        $sourceItem = Get-Item `
            -LiteralPath $SourceFile `
            -Force `
            -ErrorAction Stop
    }
    catch {
        return New-ProfMigVerificationResult `
            -Component $Component `
            -SourceFile $SourceFile `
            -DestinationFile $DestinationFile `
            -VerificationLevel $VerificationLevel `
            -SourceExists $true `
            -DestinationExists (
                Test-Path -LiteralPath $DestinationFile -PathType Leaf
            ) `
            -Status 'Failed' `
            -Reason 'VerificationReadError'
    }

    $destinationExists = Test-Path `
        -LiteralPath $DestinationFile `
        -PathType Leaf

    if (-not $destinationExists) {
        return New-ProfMigVerificationResult `
            -Component $Component `
            -SourceFile $SourceFile `
            -DestinationFile $DestinationFile `
            -VerificationLevel $VerificationLevel `
            -SourceExists $true `
            -DestinationExists $false `
            -SourceSize $sourceItem.Length `
            -Status 'Failed' `
            -Reason 'DestinationMissing'
    }

    try {
        $destinationItem = Get-Item `
            -LiteralPath $DestinationFile `
            -Force `
            -ErrorAction Stop
    }
    catch {
        return New-ProfMigVerificationResult `
            -Component $Component `
            -SourceFile $SourceFile `
            -DestinationFile $DestinationFile `
            -VerificationLevel $VerificationLevel `
            -SourceExists $true `
            -DestinationExists $true `
            -SourceSize $sourceItem.Length `
            -Status 'Failed' `
            -Reason 'VerificationReadError'
    }

    $sizeMatch = $sourceItem.Length -eq $destinationItem.Length

    if (-not $sizeMatch) {
        return New-ProfMigVerificationResult `
            -Component $Component `
            -SourceFile $SourceFile `
            -DestinationFile $DestinationFile `
            -VerificationLevel $VerificationLevel `
            -SourceExists $true `
            -DestinationExists $true `
            -SourceSize $sourceItem.Length `
            -DestinationSize $destinationItem.Length `
            -SizeMatch $false `
            -Status 'Failed' `
            -Reason 'SizeMismatch'
    }

    return New-ProfMigVerificationResult `
        -Component $Component `
        -SourceFile $SourceFile `
        -DestinationFile $DestinationFile `
        -VerificationLevel $VerificationLevel `
        -SourceExists $true `
        -DestinationExists $true `
        -SourceSize $sourceItem.Length `
        -DestinationSize $destinationItem.Length `
        -SizeMatch $true `
        -Status 'Success' `
        -Reason 'Verified'
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

function Get-ProfMigVerificationSummary {
    <#
    .SYNOPSIS
        Creates migration verification totals from copy and verification data.

    .DESCRIPTION
        Calculates file and byte totals for a migration component and determines
        whether the component totals are internally consistent.

        Verification failures are never silently treated as successful.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object[]]$VerificationResults,

        [Parameter(Mandatory)]
        [long]$FilesSelected,

        [Parameter(Mandatory)]
        [long]$FilesCopied,

        [Parameter()]
        [long]$FilesSkipped = 0,

        [Parameter()]
        [long]$FilesFailed = 0,

        [Parameter(Mandatory)]
        [long]$BytesSelected,

        [Parameter(Mandatory)]
        [long]$BytesCopied
    )

    $results = @($VerificationResults)

    $verifiedResults = @(
        $results | Where-Object {
            $_.Verified -eq $true
        }
    )

    $failedVerificationResults = @(
        $results | Where-Object {
            $_.Status -eq 'Failed'
        }
    )

    $filesVerified = [long]$verifiedResults.Count

    $bytesVerified = [long](
        (
            $verifiedResults |
                Measure-Object -Property DestinationSize -Sum
        ).Sum
    )

    $verificationFailures = [long]$failedVerificationResults.Count

    $summary = New-ProfMigVerificationSummary `
        -FilesSelected $FilesSelected `
        -FilesCopied $FilesCopied `
        -FilesVerified $filesVerified `
        -FilesSkipped $FilesSkipped `
        -FilesFailed $FilesFailed `
        -BytesSelected $BytesSelected `
        -BytesCopied $BytesCopied `
        -BytesVerified $bytesVerified `
        -VerificationFailures $verificationFailures

    $fileCountMatch = (
        $FilesCopied -eq
        ($filesVerified + $verificationFailures)
    )

    $byteCountMatch = (
        $BytesCopied -eq $bytesVerified
    )

    $componentVerified = (
        $verificationFailures -eq 0 -and
        $FilesFailed -eq 0 -and
        $fileCountMatch -and
        $byteCountMatch
    )

    [pscustomobject]@{
        PSTypeName           = 'ProfMig.ComponentVerificationSummary'

        FilesSelected        = $summary.FilesSelected
        FilesCopied          = $summary.FilesCopied
        FilesVerified        = $summary.FilesVerified
        FilesSkipped         = $summary.FilesSkipped
        FilesFailed          = $summary.FilesFailed

        BytesSelected        = $summary.BytesSelected
        BytesCopied          = $summary.BytesCopied
        BytesVerified        = $summary.BytesVerified

        VerificationFailures = $summary.VerificationFailures

        FileCountMatch       = $fileCountMatch
        ByteCountMatch       = $byteCountMatch
        Verified             = $componentVerified

        Status = if ($componentVerified) {
            'Success'
        }
        else {
            'Failed'
        }
    }
}

Export-ModuleMember -Function @(
    'Test-ProfMigVerificationLevel'
    'New-ProfMigVerificationResult'
    'Test-ProfMigFileVerification'
    'New-ProfMigVerificationSummary'
    'Get-ProfMigVerificationSummary'
)