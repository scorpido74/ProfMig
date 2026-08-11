<#
.SYNOPSIS
    ProfMig Profile Inventory Engine.

.DESCRIPTION
    Discovers registered Windows user profiles using the Windows
    ProfileList registry instead of relying only on directories
    under C:\Users.

    The inventory engine is read-only and returns structured
    PowerShell objects that can be consumed by the menu, GUI,
    CLI, or silent execution modes.
#>

Set-StrictMode -Version Latest


function Get-UserProfiles {

    [CmdletBinding()]
    param (
        [string[]]$ExcludedProfiles = @()
    )

    $profileListPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
    $inventory = @()

    Write-Verbose 'Starting Windows profile inventory.'
    Write-Verbose "Profile registry path: $profileListPath"


    # -------------------------------------------------------------------------
    # Validate Windows ProfileList
    # -------------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $profileListPath)) {
        throw 'Windows ProfileList registry path could not be found.'
    }


    # -------------------------------------------------------------------------
    # Enumerate registered Windows profiles
    # -------------------------------------------------------------------------

    $profileKeys = Get-ChildItem `
        -LiteralPath $profileListPath `
        -ErrorAction Stop

    Write-Verbose "Found $($profileKeys.Count) registered Windows profile entries."


    foreach ($profileKey in $profileKeys) {

        $sid = $profileKey.PSChildName


        # ---------------------------------------------------------------------
        # Read profile registry information
        # ---------------------------------------------------------------------

        try {

            $profileProperties = Get-ItemProperty `
                -LiteralPath $profileKey.PSPath `
                -ErrorAction Stop

        }
        catch {

            Write-Verbose "Unable to read profile registry entry: $sid"
            continue

        }


        $profilePath = [Environment]::ExpandEnvironmentVariables(
            $profileProperties.ProfileImagePath
        )

        if ([string]::IsNullOrWhiteSpace($profilePath)) {

            Write-Verbose "Profile entry has no valid ProfileImagePath: $sid"
            continue

        }


        $profileName = Split-Path `
            -Path $profilePath `
            -Leaf


        # ---------------------------------------------------------------------
        # Apply configured profile exclusions
        # ---------------------------------------------------------------------

        if ($ExcludedProfiles -contains $profileName) {

            Write-Verbose "Excluded profile: $profileName"
            continue

        }


        # ---------------------------------------------------------------------
        # Determine profile existence and accessibility
        # ---------------------------------------------------------------------

        $exists = $false
        $accessible = $false

        try {

            $exists = Test-Path `
                -LiteralPath $profilePath `
                -PathType Container `
                -ErrorAction Stop

        }
        catch [System.UnauthorizedAccessException] {

            # The path exists, but ProfMig cannot access it.
            $exists = $true
            $accessible = $false

        }
        catch {

            # ProfMig cannot reliably determine whether the path exists.
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


        # ---------------------------------------------------------------------
        # Resolve SID to Windows account information
        # ---------------------------------------------------------------------

        $accountName = $null
        $accountDomain = $null

        try {

            $sidObject = [System.Security.Principal.SecurityIdentifier]::new(
                $sid
            )

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
            # temporary, or otherwise unavailable accounts.
            Write-Verbose "Unable to resolve SID to account: $sid"

        }


        # ---------------------------------------------------------------------
        # Detect relevant profile folders
        # ---------------------------------------------------------------------

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

            $folderPath = Join-Path `
                $profilePath `
                $folderDefinitions[$folderName]

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


        # ---------------------------------------------------------------------
        # Determine basic profile status
        # ---------------------------------------------------------------------

        $status = if (-not $exists) {

            'Missing'

        }
        elseif (-not $accessible) {

            'Inaccessible'

        }
        else {

            'Available'

        }


        Write-Verbose "Profile discovered: $profileName [$status]"


        # ---------------------------------------------------------------------
        # Create structured inventory object
        # ---------------------------------------------------------------------

        $profileObject = [PSCustomObject]@{

            ProfileName = $profileName
            ProfilePath = $profilePath

            SID = $sid

            AccountName   = $accountName
            AccountDomain = $accountDomain

            Exists     = $exists
            Accessible = $accessible
            Status     = $status

            RelevantFolders = [PSCustomObject]$relevantFolders

        }


        $inventory += $profileObject

    }


    # -------------------------------------------------------------------------
    # Inventory completed
    # -------------------------------------------------------------------------

    Write-Verbose "Profile inventory completed. $($inventory.Count) profile(s) returned."

    return $inventory
}


Export-ModuleMember -Function Get-UserProfiles