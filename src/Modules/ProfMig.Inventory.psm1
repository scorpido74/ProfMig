<#
.SYNOPSIS
    ProfMig Profile Inventory Engine.

.DESCRIPTION
    Discovers Windows user profiles using the Windows ProfileList registry
    instead of relying only on directories under C:\Users.

    The inventory engine is read-only and returns structured PowerShell
    objects that can be consumed by the menu, GUI, CLI, or silent mode.
#>

function Get-UserProfiles {
    [CmdletBinding()]
    param (
        [string[]]$ExcludedProfiles = @()
    )

    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $inventory = @()

    if (-not (Test-Path -LiteralPath $profileListPath)) {
        throw "Windows ProfileList registry path could not be found."
    }

    $profileKeys = Get-ChildItem -LiteralPath $profileListPath -ErrorAction Stop

    foreach ($profileKey in $profileKeys) {

        $sid = $profileKey.PSChildName

        try {
            $profileProperties = Get-ItemProperty `
                -LiteralPath $profileKey.PSPath `
                -ErrorAction Stop
        }
        catch {
            continue
        }

        $profilePath = [Environment]::ExpandEnvironmentVariables(
            $profileProperties.ProfileImagePath
        )

        if ([string]::IsNullOrWhiteSpace($profilePath)) {
            continue
        }

        $profileName = Split-Path -Path $profilePath -Leaf

        # Apply configured exclusions.
        if ($ExcludedProfiles -contains $profileName) {
            continue
        }

        $exists = $false
        $accessible = $false

        try {
            $exists = Test-Path `
            -LiteralPath $profilePath `
            -PathType Container `
            -ErrorAction Stop
        }
        catch [System.UnauthorizedAccessException] {
            # The profile exists, but access to the path is denied.
            $exists = $true
            $accessible = $false
        }
        catch {
            # Unable to reliably determine whether the profile exists.
            $exists = $false
            $accessible = $false
        }

        
        if ($exists) {
            try {
                Get-ChildItem `
                    -LiteralPath $profilePath `
                    -Force `
                    -ErrorAction Stop |
                    Select-Object -First 1 |
                    Out-Null

                $accessible = $true
            }
            catch {
                $accessible = $false
            }
        }

        $accountName = $null
        $accountDomain = $null

        try {
            $sidObject = [System.Security.Principal.SecurityIdentifier]::new($sid)

            $account = $sidObject.Translate(
                [System.Security.Principal.NTAccount]
            )

            $accountValue = $account.Value

            if ($accountValue -match '\\') {
                $accountParts = $accountValue -split '\\', 2
                $accountDomain = $accountParts[0]
                $accountName = $accountParts[1]
            }
            else {
                $accountName = $accountValue
            }
        }
        catch {
            # SID translation can fail for deleted, disconnected,
            # or otherwise unavailable accounts.
        }

   $folderDefinitions = [ordered]@{
    Desktop   = 'Desktop'
    Documents = 'Documents'
    Downloads = 'Downloads'
    Pictures  = 'Pictures'
    Favorites = 'Favorites'
    AppData   = 'AppData'
}

$relevantFolders = [ordered]@{}

foreach ($folderName in $folderDefinitions.Keys) {

    $folderPath = Join-Path $profilePath $folderDefinitions[$folderName]
    $folderExists = $false
    $folderAccessible = $false

    try {
        $folderExists = Test-Path `
            -LiteralPath $folderPath `
            -PathType Container `
            -ErrorAction Stop

        if ($folderExists) {
            try {
                Get-ChildItem `
                    -LiteralPath $folderPath `
                    -Force `
                    -ErrorAction Stop |
                    Select-Object -First 1 |
                    Out-Null

                $folderAccessible = $true
            }
            catch {
                $folderAccessible = $false
            }
        }
    }
    catch [System.UnauthorizedAccessException] {
        $folderExists = $true
        $folderAccessible = $false
    }
    catch {
        $folderExists = $false
        $folderAccessible = $false
    }

    $relevantFolders[$folderName] = [PSCustomObject]@{
        Path       = $folderPath
        Exists     = $folderExists
        Accessible = $folderAccessible
    }
}

        $status = if (-not $exists) {
            'Missing'
        }
        elseif (-not $accessible) {
            'Inaccessible'
        }
        else {
            'Available'
        }

        $profileObject = [PSCustomObject]@{
            ProfileName    = $profileName
            ProfilePath    = $profilePath
            SID            = $sid
            AccountName    = $accountName
            AccountDomain  = $accountDomain
            Exists         = $exists
            Accessible     = $accessible
            Status         = $status
            RelevantFolders = [PSCustomObject]$relevantFolders
        }

        $inventory += $profileObject
    }

    return $inventory
}
Export-ModuleMember -Function Get-UserProfiles
