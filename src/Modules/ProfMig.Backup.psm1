Set-StrictMode -Version Latest

function Get-ProfMigInteractiveUser {
    [CmdletBinding()]
    param()

    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem

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
        $Account = New-Object System.Security.Principal.NTAccount($UserName)

        $Sid = $Account.Translate(
            [System.Security.Principal.SecurityIdentifier]
        ).Value
    }
    catch {
        throw "Unable to resolve SID for user '$UserName'. $($_.Exception.Message)"
    }

    $Profile = Get-CimInstance -ClassName Win32_UserProfile |
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
        [string]$ProfilePath
    )

    $OneDriveFolderName = 'OneDrive - Infinigate Holding GmbH'

    $OneDrivePath = Join-Path `
        -Path $ProfilePath `
        -ChildPath $OneDriveFolderName

    if (-not (Test-Path -LiteralPath $OneDrivePath -PathType Container)) {
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

    $TimeStampValue = $Timestamp.ToString('yyyy-MM-dd_HHmmss')

    $FolderName = '{0}_{1}' -f $ComputerName, $TimeStampValue

    $BackupPath = Join-Path `
        -Path $RootPath `
        -ChildPath $FolderName

    if (-not (Test-Path -LiteralPath $BackupPath)) {
        New-Item `
            -Path $BackupPath `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop | Out-Null
    }

    return $BackupPath
}

function Get-ProfMigOneDriveBackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$OneDrivePath,

        [datetime]$Timestamp = (Get-Date),

        [string]$ComputerName = $env:COMPUTERNAME
    )

    $TimeStampValue = $Timestamp.ToString('yyyy-MM-dd_HHmmss')

    $FolderName = '{0}_{1}' -f $ComputerName, $TimeStampValue

    return Join-Path `
        -Path $OneDrivePath `
        -ChildPath ('ProfMig\Backup\{0}' -f $FolderName)
}

function Get-ProfMigBackupManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        throw "Backup path not found: $RootPath"
    }

    $RootFullPath = (Get-Item -LiteralPath $RootPath).FullName.TrimEnd('\')

    $Manifest = @(
        Get-ChildItem `
            -LiteralPath $RootFullPath `
            -File `
            -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $RelativePath = $_.FullName.Substring(
                $RootFullPath.Length
            ).TrimStart('\')

            [pscustomobject]@{
                RelativePath = $RelativePath
                Length       = $_.Length
                SHA256       = (
                    Get-FileHash `
                        -LiteralPath $_.FullName `
                        -Algorithm SHA256
                ).Hash
            }
        }
    )

    return $Manifest
}

function Copy-ProfMigBackupToOneDrive {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Backup source not found: $SourcePath"
    }

    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        New-Item `
            -Path $DestinationPath `
            -ItemType Directory `
            -Force `
            -ErrorAction Stop | Out-Null
    }

    $SourceFullPath = (Get-Item -LiteralPath $SourcePath).FullName.TrimEnd('\')

    $Files = @(
        Get-ChildItem `
            -LiteralPath $SourceFullPath `
            -File `
            -Recurse
    )

    foreach ($File in $Files) {
        $RelativePath = $File.FullName.Substring(
            $SourceFullPath.Length
        ).TrimStart('\')

        $DestinationFile = Join-Path `
            -Path $DestinationPath `
            -ChildPath $RelativePath

        $DestinationDirectory = Split-Path `
            -Parent `
            $DestinationFile

        if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
            New-Item `
                -Path $DestinationDirectory `
                -ItemType Directory `
                -Force `
                -ErrorAction Stop | Out-Null
        }

        Copy-Item `
            -LiteralPath $File.FullName `
            -Destination $DestinationFile `
            -Force `
            -ErrorAction Stop
    }

    return $DestinationPath
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
        Get-ProfMigBackupManifest -RootPath $SourcePath
    )

    $DestinationManifest = @(
        Get-ProfMigBackupManifest -RootPath $DestinationPath
    )

    $Errors = @()

    $DestinationIndex = @{}

    foreach ($File in $DestinationManifest) {
        $DestinationIndex[$File.RelativePath] = $File
    }

    foreach ($SourceFile in $SourceManifest) {
        if (-not $DestinationIndex.ContainsKey($SourceFile.RelativePath)) {
            $Errors += "Missing destination file: $($SourceFile.RelativePath)"
            continue
        }

        $DestinationFile = $DestinationIndex[$SourceFile.RelativePath]

        if ($SourceFile.Length -ne $DestinationFile.Length) {
            $Errors += "File size mismatch: $($SourceFile.RelativePath)"
            continue
        }

        if ($SourceFile.SHA256 -ne $DestinationFile.SHA256) {
            $Errors += "SHA256 mismatch: $($SourceFile.RelativePath)"
        }
    }

    $SourceIndex = @{}

    foreach ($File in $SourceManifest) {
        $SourceIndex[$File.RelativePath] = $File
    }

    foreach ($DestinationFile in $DestinationManifest) {
        if (-not $SourceIndex.ContainsKey($DestinationFile.RelativePath)) {
            $Errors += "Unexpected destination file: $($DestinationFile.RelativePath)"
        }
    }

    return [pscustomobject]@{
        Success              = ($Errors.Count -eq 0)
        SourceFileCount      = $SourceManifest.Count
        DestinationFileCount = $DestinationManifest.Count
        Errors               = @($Errors)
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

    Copy-ProfMigBackupToOneDrive `
        -SourcePath $SourcePath `
        -DestinationPath $DestinationPath | Out-Null

    $Verification = Test-ProfMigBackupVerification `
        -SourcePath $SourcePath `
        -DestinationPath $DestinationPath

    if (-not $Verification.Success) {
        $Details = $Verification.Errors -join '; '

        throw "OneDrive backup verification failed. $Details"
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
        Success         = $true
        SourcePath      = $SourcePath
        DestinationPath = $DestinationPath
        FileCount       = $Verification.SourceFileCount
        Verification    = 'SHA256'
        SourceRemoved   = $SourceRemoved
    }
}

Export-ModuleMember -Function @(
    'Get-ProfMigInteractiveUser',
    'Get-ProfMigUserProfile',
    'Get-ProfMigOneDrivePath',
    'New-ProfMigBackupStaging',
    'Get-ProfMigOneDriveBackupPath',
    'Get-ProfMigBackupManifest',
    'Copy-ProfMigBackupToOneDrive',
    'Test-ProfMigBackupVerification',
    'Invoke-ProfMigOneDriveBackupTransfer'
)