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
            Music     = 'Music'
            Videos    = 'Videos'
            Favorites = 'Favorites'
            Links     = 'Links'
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

function Get-ProfMigApplicationInventory {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceProfilePath,

        [Parameter(Mandatory = $false)]
        [object[]]$ApplicationDefinitions = @()
    )

    Write-Verbose "Building application inventory for source profile: $SourceProfilePath"

    $applicationInventory = @()

    # ---------------------------------------------------------
    # Native application providers
    # ---------------------------------------------------------

    $nativeApplications = @(
        @{
            Id                = 'Microsoft.Edge'
            Name              = 'Microsoft Edge'
            DetectionFunction = 'Get-ProfMigEdgeDetection'
            MigrationFunction = 'Invoke-ProfMigEdgeMigration'
        },
        @{
            Id                = 'Google.Chrome'
            Name              = 'Google Chrome'
            DetectionFunction = 'Get-ProfMigChromeDetection'
            MigrationFunction = 'Invoke-ProfMigChromeMigration'
        },
        @{
            Id                = 'Microsoft.Outlook'
            Name              = 'Microsoft Outlook'
            DetectionFunction = 'Get-ProfMigOutlookDetection'
            MigrationFunction = 'Invoke-ProfMigOutlookMigration'
        }
    )

    foreach ($application in $nativeApplications) {

        try {

            $detectionCommand = Get-Command `
                -Name $application.DetectionFunction `
                -ErrorAction SilentlyContinue

            if (-not $detectionCommand) {

                $applicationInventory += [PSCustomObject]@{
                    Id                = $application.Id
                    Name              = $application.Name
                    Type              = 'Native'
                    Detected          = $false
                    Status            = 'ProviderUnavailable'
                    Detection         = $null
                    Definition        = $null
                    DetectionFunction = $application.DetectionFunction
                    MigrationFunction = $application.MigrationFunction
                    Error             = "Detection provider '$($application.DetectionFunction)' is not available."
                }

                continue
            }

            $detectionResult = & $application.DetectionFunction `
                -ProfilePath $SourceProfilePath

            $detected = [bool]$detectionResult.Detected

            $applicationInventory += [PSCustomObject]@{
                Id                = $application.Id
                Name              = $application.Name
                Type              = 'Native'
                Detected          = $detected
                Status            = if ($detected) {
                    'Detected'
                }
                else {
                    'NotDetected'
                }
                Detection         = $detectionResult
                Definition        = $null
                DetectionFunction = $application.DetectionFunction
                MigrationFunction = $application.MigrationFunction
                Error             = $null
            }
        }
        catch {

            $applicationInventory += [PSCustomObject]@{
                Id                = $application.Id
                Name              = $application.Name
                Type              = 'Native'
                Detected          = $false
                Status            = 'DetectionFailed'
                Detection         = $null
                Definition        = $null
                DetectionFunction = $application.DetectionFunction
                MigrationFunction = $application.MigrationFunction
                Error             = $_.Exception.Message
            }

            Write-Warning "Application detection failed for '$($application.Name)': $($_.Exception.Message)"
        }
    }

    # ---------------------------------------------------------
    # Generic application definitions
    # ---------------------------------------------------------

    foreach ($definitionResult in $ApplicationDefinitions) {

        if (-not $definitionResult.Valid) {

            $applicationInventory += [PSCustomObject]@{
                Id                = $null
                Name              = [System.IO.Path]::GetFileNameWithoutExtension($definitionResult.File)
                Type              = 'Generic'
                Detected          = $false
                Status            = 'InvalidDefinition'
                Detection         = $null
                Definition        = $definitionResult.Definition
                DetectionFunction = 'Test-ProfMigApplicationDetection'
                MigrationFunction = 'Invoke-ProfMigApplicationMigration'
                Error             = ($definitionResult.Errors -join '; ')
            }

            continue
        }

        $definition = $definitionResult.Definition

        try {

        $detectionResult = Test-ProfMigApplicationDetection `
            -Definition $definition `
            -ProfilePath $SourceProfilePath

            $detected = [bool]$detectionResult.Detected

            $applicationInventory += [PSCustomObject]@{
                Id                = $definition.Application.Id
                Name              = $definition.Application.Name
                Type              = 'Generic'
                Detected          = $detected
                Status            = if ($detected) {
                    'Detected'
                }
                else {
                    'NotDetected'
                }
                Detection         = $detectionResult
                Definition        = $definition
                DetectionFunction = 'Test-ProfMigApplicationDetection'
                MigrationFunction = 'Invoke-ProfMigApplicationMigration'
                Error             = $null
            }
        }
        catch {

            $applicationInventory += [PSCustomObject]@{
                Id                = $definition.Application.Id
                Name              = $definition.Application.Name
                Type              = 'Generic'
                Detected          = $false
                Status            = 'DetectionFailed'
                Detection         = $null
                Definition        = $definition
                DetectionFunction = 'Test-ProfMigApplicationDetection'
                MigrationFunction = 'Invoke-ProfMigApplicationMigration'
                Error             = $_.Exception.Message
            }

            Write-Warning "Application detection failed for '$($definition.Application.Name)': $($_.Exception.Message)"
        }
    }

    return $applicationInventory
}

Export-ModuleMember -Function @(
    'Get-UserProfiles',
    'Get-ProfMigApplicationInventory'
)