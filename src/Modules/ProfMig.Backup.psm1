Set-StrictMode -Version Latest

# ============================================================================
# ProfMig Backup Module
# ============================================================================
#
# Provides:
# - Interactive user detection
# - Windows profile resolution
# - OneDrive path resolution
# - Local backup staging
# - Safe recursive copy
# - Reparse point protection
# - SHA256 manifest generation
# - Backup verification
# - Verified OneDrive transfer
#
# Compatible with Windows PowerShell 5.1.
# ============================================================================


function Get-ProfMigInteractiveUser {
    [CmdletBinding()]
    param()

    $ComputerSystem = Get-CimInstance `
        -ClassName Win32_ComputerSystem `
        -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($ComputerSystem.UserName)) {
        throw 'No interactive user detected.'
    }

    return $ComputerSystem.UserName
}


function Get-ProfMigUserProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserName
    )

    try {
        $Account = New-Object `
            System.Security.Principal.NTAccount($UserName)

        $Sid = $Account.Translate(
            [System.Security.Principal.SecurityIdentifier]
        ).Value
    }
    catch {
        throw (
            "Unable to resolve SID for user '$UserName'. " +
            $_.Exception.Message
        )
    }

    $Profile = Get-CimInstance `
        -ClassName Win32_UserProfile `
        -ErrorAction Stop |
        Where-Object {
            $_.SID -eq $Sid -and
            -not [string]::IsNullOrWhiteSpace($_.LocalPath)
        } |
        Select-Object -First 1

    if (-not $Profile) {
        throw "No Windows profile found for user '$UserName'."
    }

    return $Profile.LocalPath
}


function Get-ProfMigOneDrivePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ProfilePath,

        [string]$FolderName = 'OneDrive - Infinigate Holding GmbH'
    )

    $OneDrivePath = Join-Path `
        -Path $ProfilePath `
        -ChildPath $FolderName

    if (-not (
        Test-Path `
            -LiteralPath $OneDrivePath `
            -PathType Container
    )) {
        throw "OneDrive folder not found: $OneDrivePath"
    }

    return $OneDrivePath
}


function New-ProfMigBackupStaging {
    [CmdletBinding()]
    param(
        [string]$RootPath = 'C:\ProgramData\ProfMig\Backup',

        [string]$ComputerName = $env:COMPUTERNAME,

        [datetime]$Timestamp = (Get-Date)
    )

    $TimestampValue = $Timestamp.ToString(
        'yyyy-MM-dd_HHmmss'
    )

    $FolderName = '{0}_{1}' -f `
        $ComputerName,
        $TimestampValue

    $BackupPath = Join-Path `
        -Path $RootPath `
        -ChildPath $FolderName

    if (-not (
        Test-Path `
            -LiteralPath $BackupPath `
            -PathType Container
    )) {
        New-Item `
            -Path $BackupPath `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }

    return $BackupPath
}


function Get-ProfMigOneDriveBackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OneDrivePath,

        [string]$BackupFolder = 'ProfMig\Backup',

        [string]$ComputerName = $env:COMPUTERNAME,

        [datetime]$Timestamp = (Get-Date)
    )

    $TimestampValue = $Timestamp.ToString(
        'yyyy-MM-dd_HHmmss'
    )

    $FolderName = '{0}_{1}' -f `
        $ComputerName,
        $TimestampValue

    $BackupRoot = Join-Path `
        -Path $OneDrivePath `
        -ChildPath $BackupFolder

    return Join-Path `
        -Path $BackupRoot `
        -ChildPath $FolderName
}


function Test-ProfMigReparsePoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    $HasReparseAttribute = (
        (
            $Item.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint
        ) -ne 0
    )

    if (-not $HasReparseAttribute) {
        return $false
    }

    # OneDrive Files On-Demand directories also use the ReparsePoint
    # attribute. They are normal traversable profile/backup directories
    # and must not be treated as symbolic links or junctions.
    #
    # PowerShell exposes actual filesystem links through LinkType and/or
    # Target. Those must still be skipped to prevent traversal outside
    # the intended backup tree or recursive directory loops.

    if (-not [string]::IsNullOrWhiteSpace(
        [string]$Item.LinkType
    )) {
        return $true
    }

    if (
        $null -ne $Item.Target -and
        @($Item.Target).Count -gt 0
    ) {
        return $true
    }

    return $false
}

function Get-ProfMigBackupItems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    if (-not (
        Test-Path `
            -LiteralPath $RootPath `
            -PathType Container
    )) {
        throw "Backup path not found: $RootPath"
    }

    $RootFullPath = (
        Get-Item `
            -LiteralPath $RootPath `
            -Force `
            -ErrorAction Stop
    ).FullName.TrimEnd('\')

    $PendingDirectories = New-Object `
        System.Collections.Generic.Stack[string]

    $PendingDirectories.Push(
        $RootFullPath
    )

    while ($PendingDirectories.Count -gt 0) {
        $CurrentDirectory = $PendingDirectories.Pop()

        $Items = @(
            Get-ChildItem `
                -LiteralPath $CurrentDirectory `
                -Force `
                -ErrorAction Stop
        )

        foreach ($Item in $Items) {
            $RelativePath = $Item.FullName.Substring(
                $RootFullPath.Length
            ).TrimStart('\')

            $IsReparsePoint = Test-ProfMigReparsePoint `
                -Item $Item

            [pscustomobject]@{
                Item           = $Item
                FullName       = $Item.FullName
                RelativePath   = $RelativePath
                IsDirectory    = $Item.PSIsContainer
                IsReparsePoint = $IsReparsePoint
            }

            if (
                $Item.PSIsContainer -and
                -not $IsReparsePoint
            ) {
                $PendingDirectories.Push(
                    $Item.FullName
                )
            }
        }
    }
}


function Copy-ProfMigBackupContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if (-not (
        Test-Path `
            -LiteralPath $SourcePath `
            -PathType Container
    )) {
        throw "Backup source not found: $SourcePath"
    }

    if (-not (
        Test-Path `
            -LiteralPath $DestinationPath `
            -PathType Container
    )) {
        New-Item `
            -Path $DestinationPath `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop |
            Out-Null
    }

    $CopiedFileCount = 0

    $SkippedReparsePoints = New-Object `
        System.Collections.Generic.List[string]

    $Items = @(
        Get-ProfMigBackupItems `
            -RootPath $SourcePath
    )

    foreach ($BackupItem in $Items) {

        if ($BackupItem.IsReparsePoint) {
            $SkippedReparsePoints.Add(
                $BackupItem.RelativePath
            )

            continue
        }

        $TargetPath = Join-Path `
            -Path $DestinationPath `
            -ChildPath $BackupItem.RelativePath

        if ($BackupItem.IsDirectory) {
            if (-not (
                Test-Path `
                    -LiteralPath $TargetPath `
                    -PathType Container
            )) {
                New-Item `
                    -Path $TargetPath `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }

            continue
        }

        $TargetDirectory = Split-Path `
            -Parent `
            $TargetPath

        if (-not (
            Test-Path `
                -LiteralPath $TargetDirectory `
                -PathType Container
        )) {
            New-Item `
                -Path $TargetDirectory `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }

        Copy-Item `
            -LiteralPath $BackupItem.FullName `
            -Destination $TargetPath `
            -Force `
            -ErrorAction Stop

        $CopiedFileCount++
    }

    return [pscustomobject]@{
        SourcePath               = $SourcePath
        DestinationPath          = $DestinationPath
        CopiedFileCount          = $CopiedFileCount
        SkippedReparsePointCount = $SkippedReparsePoints.Count
        SkippedReparsePoints     = @(
            $SkippedReparsePoints
        )
    }
}


function Get-ProfMigBackupManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    if (-not (
        Test-Path `
            -LiteralPath $RootPath `
            -PathType Container
    )) {
        throw "Backup path not found: $RootPath"
    }

    $Manifest = @(
        Get-ProfMigBackupItems `
            -RootPath $RootPath |
        Where-Object {
            -not $_.IsDirectory -and
            -not $_.IsReparsePoint
        } |
        ForEach-Object {
            $Hash = Get-FileHash `
                -LiteralPath $_.FullName `
                -Algorithm SHA256 `
                -ErrorAction Stop

            [pscustomobject]@{
                RelativePath = $_.RelativePath
                Length       = $_.Item.Length
                SHA256       = $Hash.Hash
            }
        } |
        Sort-Object RelativePath
    )

    return $Manifest
}


function Test-ProfMigBackupVerification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $SourceManifest = @(
        Get-ProfMigBackupManifest `
            -RootPath $SourcePath
    )

    $DestinationManifest = @(
        Get-ProfMigBackupManifest `
            -RootPath $DestinationPath
    )

    $VerificationErrors = New-Object `
        System.Collections.Generic.List[string]


    if ($SourceManifest.Count -eq 0) {
        $VerificationErrors.Add(
            'Source backup manifest contains no files.'
        )
    }

    if ($DestinationManifest.Count -eq 0) {
        $VerificationErrors.Add(
            'Destination backup manifest contains no files.'
        )
    }

    $SourceIndex = @{}
    $DestinationIndex = @{}

    foreach ($File in $SourceManifest) {
        $SourceIndex[$File.RelativePath] = $File
    }

    foreach ($File in $DestinationManifest) {
        $DestinationIndex[$File.RelativePath] = $File
    }

    foreach ($SourceFile in $SourceManifest) {

        if (-not $DestinationIndex.ContainsKey(
            $SourceFile.RelativePath
        )) {
            $VerificationErrors.Add(
                "Missing destination file: $($SourceFile.RelativePath)"
            )

            continue
        }

        $DestinationFile = $DestinationIndex[
            $SourceFile.RelativePath
        ]

        if ($SourceFile.Length -ne $DestinationFile.Length) {
            $VerificationErrors.Add(
                "File size mismatch: $($SourceFile.RelativePath)"
            )

            continue
        }

        if ($SourceFile.SHA256 -ne $DestinationFile.SHA256) {
            $VerificationErrors.Add(
                "SHA256 mismatch: $($SourceFile.RelativePath)"
            )
        }
    }

    foreach ($DestinationFile in $DestinationManifest) {

        if (-not $SourceIndex.ContainsKey(
            $DestinationFile.RelativePath
        )) {
            $VerificationErrors.Add(
                "Unexpected destination file: " +
                $DestinationFile.RelativePath
            )
        }
    }

    return [pscustomobject]@{
        Success = (
            $VerificationErrors.Count -eq 0
        )
        SourceFileCount = $SourceManifest.Count
        DestinationFileCount = $DestinationManifest.Count
        Errors = @(
            $VerificationErrors
        )
    }
}


function Invoke-ProfMigOneDriveBackupTransfer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [switch]$CleanupSource
    )

    $CopyResult = Copy-ProfMigBackupContent `
        -SourcePath $SourcePath `
        -DestinationPath $DestinationPath

    $Verification = Test-ProfMigBackupVerification `
        -SourcePath $SourcePath `
        -DestinationPath $DestinationPath

    if (-not $Verification.Success) {
        $Details = $Verification.Errors -join '; '

        throw (
            'OneDrive backup verification failed. ' +
            $Details
        )
    }

    $SourceRemoved = $false

    if ($CleanupSource) {
        Remove-Item `
            -LiteralPath $SourcePath `
            -Recurse `
            -Force `
            -ErrorAction Stop

        $SourceRemoved = $true
    }

    return [pscustomobject]@{
        Success                  = $true
        SourcePath               = $SourcePath
        DestinationPath          = $DestinationPath
        FileCount                = $Verification.SourceFileCount
        DestinationFileCount     = $Verification.DestinationFileCount
        Verification             = 'SHA256'
        SourceRemoved            = $SourceRemoved
        CopiedFileCount          = $CopyResult.CopiedFileCount
        SkippedReparsePointCount = $CopyResult.SkippedReparsePointCount
        SkippedReparsePoints     = $CopyResult.SkippedReparsePoints
    }
}


Export-ModuleMember -Function @(
    'Get-ProfMigInteractiveUser',
    'Get-ProfMigUserProfile',
    'Get-ProfMigOneDrivePath',
    'New-ProfMigBackupStaging',
    'Get-ProfMigOneDriveBackupPath',
    'Get-ProfMigBackupManifest',
    'Copy-ProfMigBackupContent',
    'Test-ProfMigBackupVerification',
    'Invoke-ProfMigOneDriveBackupTransfer'
)
