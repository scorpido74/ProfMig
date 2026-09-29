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

Export-ModuleMember -Function @(
    'Get-ProfMigInteractiveUser',
    'Get-ProfMigUserProfile',
    'Get-ProfMigOneDrivePath',
    'New-ProfMigBackupStaging',
    'Get-ProfMigOneDriveBackupPath'
)