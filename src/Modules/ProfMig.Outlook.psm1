<#
.SYNOPSIS
    Microsoft Outlook migration support for ProfMig.

.DESCRIPTION
    Provides detection and migration planning functionality for
    Microsoft Outlook user data.

    Outlook data is classified before migration so that portable
    user data can be migrated without copying synchronized mailbox
    caches, authentication data or Microsoft 365 session information.

    This module currently performs detection only.

.NOTES
    Part of ProfMig - Professional Windows Profile Migration Toolkit.

    Security rules:
    - Source Outlook data remains read-only.
    - OST files are detected but excluded from migration.
    - Microsoft 365 authentication data is not migrated.
    - Authentication tokens are not read or copied.
    - PST files are never modified.
#>

Set-StrictMode -Version Latest

$exclusionModulePath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath 'ProfMig.Exclusions.psm1'

if (-not (Test-Path -LiteralPath $exclusionModulePath)) {
    throw "ProfMig exclusions module not found: $exclusionModulePath"
}

Import-Module `
    -Name $exclusionModulePath `
    -Force `
    -ErrorAction Stop

Initialize-ProfMigDefaultExclusions

function Write-ProfMigOutlookLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $writeLogCommand = Get-Command `
        -Name "Write-Log" `
        -CommandType Function `
        -ErrorAction SilentlyContinue

    if ($null -ne $writeLogCommand) {
        Write-Log -Level $Level -Message $Message
    }
}


function Get-ProfMigOutlookPaths {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    return [PSCustomObject]@{
        LocalOutlook = Join-Path `
            -Path $ProfilePath `
            -ChildPath "AppData\Local\Microsoft\Outlook"

        RoamingOutlook = Join-Path `
            -Path $ProfilePath `
            -ChildPath "AppData\Roaming\Microsoft\Outlook"

        RoamCache = Join-Path `
            -Path $ProfilePath `
            -ChildPath "AppData\Local\Microsoft\Outlook\RoamCache"

        Signatures = Join-Path `
            -Path $ProfilePath `
            -ChildPath "AppData\Roaming\Microsoft\Signatures"

        Templates = Join-Path `
            -Path $ProfilePath `
            -ChildPath "AppData\Roaming\Microsoft\Templates"

        OutlookFiles = Join-Path `
            -Path $ProfilePath `
            -ChildPath "Documents\Outlook Files"
    }
}


function Get-ProfMigOutlookFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $paths = Get-ProfMigOutlookPaths `
        -ProfilePath $ProfilePath

    $items = @()

    #
    # OST mailbox caches.
    #
    if (Test-Path -LiteralPath $paths.LocalOutlook -PathType Container) {

        $ostFiles = @(
            Get-ChildItem `
                -LiteralPath $paths.LocalOutlook `
                -Filter "*.ost" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $ostFiles) {

            $relativePath = $file.FullName.Substring($ProfilePath.Length).TrimStart('\')

            $exclusionResult = Test-ProfMigExclusion `
                -RelativePath $relativePath `
                -Application 'Outlook'

            $items += [PSCustomObject]@{
                Type              = "OST"
                Name              = $file.Name
                Path              = $file.FullName
                SizeBytes         = $file.Length
                Classification    = "Recreate"
                Action            = if ($exclusionResult.Excluded) { "Exclude" } else { "Review" }
                Reason            = if ($exclusionResult.Excluded) {
                    $exclusionResult.Reason
                }
                else {
                    "OST exclusion rule was not matched; manual review required."
                }
                ExclusionRuleId   = $exclusionResult.RuleId
                ExclusionType     = $exclusionResult.RuleType
                ExclusionCategory = $exclusionResult.Category
                Mandatory         = $exclusionResult.Mandatory
            }
        }

        #
        # PST files may also exist in the local Outlook directory.
        #
        $pstFiles = @(
            Get-ChildItem `
                -LiteralPath $paths.LocalOutlook `
                -Filter "*.pst" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $pstFiles) {

            $items += [PSCustomObject]@{
                Type          = "PST"
                Name          = $file.Name
                Path          = $file.FullName
                SizeBytes     = $file.Length
                Classification = "Portable"
                Action        = "Migrate"
                Reason        = "PST is portable Outlook user data."
                ExclusionRuleId   = $null
                ExclusionType     = $null
                ExclusionCategory = $null
                Mandatory         = $false
            }
        }
    }

    #
    # PST files stored in Documents\Outlook Files.
    #
    if (Test-Path -LiteralPath $paths.OutlookFiles -PathType Container) {

        $pstFiles = @(
            Get-ChildItem `
                -LiteralPath $paths.OutlookFiles `
                -Filter "*.pst" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $pstFiles) {

            $items += [PSCustomObject]@{
                Type          = "PST"
                Name          = $file.Name
                Path          = $file.FullName
                SizeBytes     = $file.Length
                Classification = "Portable"
                Action        = "Migrate"
                Reason        = "PST is portable Outlook user data."
                ExclusionRuleId   = $null
                ExclusionType     = $null
                ExclusionCategory = $null
                Mandatory         = $false
            }
        }
    }

    #
    # AutoComplete cache.
    #
    if (Test-Path -LiteralPath $paths.RoamCache -PathType Container) {

        $autoCompleteFiles = @(
            Get-ChildItem `
                -LiteralPath $paths.RoamCache `
                -Filter "Stream_Autocomplete_*.dat" `
                -File `
                -ErrorAction SilentlyContinue
        )

        foreach ($file in $autoCompleteFiles) {

          $items += [PSCustomObject]@{
            Type           = "AutoComplete"
            Name           = $file.Name
            Path           = $file.FullName
            SizeBytes      = $file.Length
            Classification = "Recreate"
            Action         = "Exclude"
            Reason         = "AutoComplete data is profile dependent and should be recreated by Outlook or Microsoft 365."
        }
        }
    }

    #
    # Classic Outlook roaming settings.
    #
    if (Test-Path -LiteralPath $paths.RoamingOutlook -PathType Container) {

        $settings = @(
            @{
                File           = "Outlook.srs"
                Type           = "SendReceiveSettings"
                Classification = "Recreate"
                Action         = "Exclude"
                Reason         = "Send/Receive settings are profile and account dependent and should be recreated."
            }
            @{
                File           = "Outlook.xml"
                Type           = "OutlookSettings"
                Classification = "Portable"
                Action         = "Migrate"
                Reason         = "Classic Outlook navigation pane settings can be migrated."
            }
            @{
                File           = "OutlPrnt"
                Type           = "PrintSettings"
                Classification = "Portable"
                Action         = "Migrate"
                Reason         = "Classic Outlook print styles can be migrated."
            }
        )

        foreach ($setting in $settings) {

            $candidate = Join-Path `
                -Path $paths.RoamingOutlook `
                -ChildPath $setting.File

            if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                continue
            }

            $file = Get-Item `
                -LiteralPath $candidate `
                -ErrorAction SilentlyContinue

            if ($null -eq $file) {
                continue
            }

           $items += [PSCustomObject]@{
                Type           = $setting.Type
                Name           = $file.Name
                Path           = $file.FullName
                SizeBytes      = $file.Length
                Classification = $setting.Classification
                Action         = $setting.Action
                Reason         = $setting.Reason
            }
        }
    }

    return $items
}


function Get-ProfMigOutlookSignatures {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $paths = Get-ProfMigOutlookPaths `
        -ProfilePath $ProfilePath

    if (-not (Test-Path -LiteralPath $paths.Signatures -PathType Container)) {
        return @()
    }

    $files = @(
        Get-ChildItem `
            -LiteralPath $paths.Signatures `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue
    )

    $items = @()

    foreach ($file in $files) {

        $items += [PSCustomObject]@{
            Type           = "Signature"
            Name           = $file.Name
            Path           = $file.FullName
            SizeBytes      = $file.Length
            Classification = "Portable"
            Action         = "Migrate"
            Reason         = "Outlook signature data is portable user content."
        }
    }

    return $items
}


function Get-ProfMigOutlookTemplates {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $paths = Get-ProfMigOutlookPaths `
        -ProfilePath $ProfilePath

    if (-not (Test-Path -LiteralPath $paths.Templates -PathType Container)) {
        return @()
    }

    $files = @(
        Get-ChildItem `
            -LiteralPath $paths.Templates `
            -File `
            -Recurse `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Extension -eq ".oft" -or
                $_.Name -eq "NormalEmail.dotm"
            }
    )

    $items = @()

    foreach ($file in $files) {

        $items += [PSCustomObject]@{
            Type           = "Template"
            Name           = $file.Name
            Path           = $file.FullName
            SizeBytes      = $file.Length
            Classification = "Portable"
            Action         = "Migrate"
            Reason         = "Microsoft Office template is portable user content."
        }
    }

    return $items
}

function Get-ProfMigOutlookInstallation {
    [CmdletBinding()]
    param ()

    $classicDetected = $false
    $classicPath = $null
    $classicVersion = $null
    $classicArchitecture = $null

    $newOutlookDetected = $false
    $newOutlookVersion = $null
    $newOutlookPackage = $null

    $detectionNotes = @()

    #
    # Classic Outlook detection.
    #
    # App Paths is preferred because it works for Click-to-Run
    # and traditional Office installations without hard-coding
    # an Office installation directory.
    #
    $classicRegistryPaths = @(
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE"
        "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE"
    )

    foreach ($registryPath in $classicRegistryPaths) {

        if (-not (Test-Path -LiteralPath $registryPath)) {
            continue
        }

        try {
            $appPath = Get-ItemProperty `
                -LiteralPath $registryPath `
                -ErrorAction Stop

            $candidatePath = $appPath.'(default)'

            if ([string]::IsNullOrWhiteSpace($candidatePath)) {
                $candidatePath = $appPath.Path

                if (-not [string]::IsNullOrWhiteSpace($candidatePath)) {
                    $candidatePath = Join-Path `
                        -Path $candidatePath `
                        -ChildPath "OUTLOOK.EXE"
                }
            }

            if (
                -not [string]::IsNullOrWhiteSpace($candidatePath) -and
                (Test-Path -LiteralPath $candidatePath -PathType Leaf)
            ) {
                $classicDetected = $true
                $classicPath = $candidatePath
                break
            }
        }
        catch {
            $detectionNotes += "Classic Outlook App Paths registry information could not be read."
        }
    }

    #
    # Fallback to common Office installation paths.
    #
    if (-not $classicDetected) {

        $classicCandidates = @(
            "$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE"
            "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE"
            "$env:ProgramFiles\Microsoft Office\Office16\OUTLOOK.EXE"
            "${env:ProgramFiles(x86)}\Microsoft Office\Office16\OUTLOOK.EXE"
        )

        foreach ($candidatePath in $classicCandidates) {

            if ([string]::IsNullOrWhiteSpace($candidatePath)) {
                continue
            }

            if (Test-Path -LiteralPath $candidatePath -PathType Leaf) {
                $classicDetected = $true
                $classicPath = $candidatePath
                break
            }
        }
    }

    if ($classicDetected) {

        try {
            $file = Get-Item `
                -LiteralPath $classicPath `
                -ErrorAction Stop

            $classicVersion = $file.VersionInfo.ProductVersion

            if ($classicPath -like "${env:ProgramFiles(x86)}*") {
                $classicArchitecture = "x86"
            }
            else {
                $classicArchitecture = "x64"
            }
        }
        catch {
            $detectionNotes += "Classic Outlook executable was detected but version information could not be read."
        }
    }
    else {
        $detectionNotes += "Classic Outlook executable was not detected."
    }

    #
    # New Outlook detection.
    #
    # New Outlook is delivered as the Microsoft.OutlookForWindows
    # AppX/MSIX package.
    #
    try {
        $newOutlook = Get-AppxPackage `
            -Name "Microsoft.OutlookForWindows" `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1

        if ($null -ne $newOutlook) {
            $newOutlookDetected = $true
            $newOutlookVersion = $newOutlook.Version.ToString()
            $newOutlookPackage = $newOutlook.PackageFullName
        }
        else {
            $detectionNotes += "New Outlook package was not detected for the current Windows user."
        }
    }
    catch {
        $detectionNotes += "New Outlook package information could not be queried."
    }

    $outlookType = switch ($true) {
        ($classicDetected -and $newOutlookDetected) {
            "ClassicAndNew"
            break
        }

        $classicDetected {
            "Classic"
            break
        }

        $newOutlookDetected {
            "New"
            break
        }

        default {
            "None"
        }
    }

    return [PSCustomObject]@{
        OutlookType         = $outlookType

        ClassicDetected     = $classicDetected
        ClassicPath         = $classicPath
        ClassicVersion      = $classicVersion
        ClassicArchitecture = $classicArchitecture

        NewOutlookDetected  = $newOutlookDetected
        NewOutlookVersion   = $newOutlookVersion
        NewOutlookPackage   = $newOutlookPackage

        DetectionNotes      = $detectionNotes
    }
}

function Get-ProfMigOutlookProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $profiles = @()
    $detectionNotes = @()
    $sid = $null
    $registryAvailable = $false

    try {
        $userProfile = Get-CimInstance `
            -ClassName Win32_UserProfile `
            -ErrorAction Stop |
            Where-Object {
                $_.LocalPath -eq $ProfilePath
            } |
            Select-Object -First 1
    }
    catch {
        $detectionNotes += "Windows user profile information could not be queried."

        return [PSCustomObject]@{
            SID               = $null
            RegistryAvailable = $false
            ProfileCount      = 0
            Profiles          = @()
            DetectionNotes    = $detectionNotes
        }
    }

    if ($null -eq $userProfile) {

        $detectionNotes += "Windows user profile could not be matched to the selected source path."

        return [PSCustomObject]@{
            SID               = $null
            RegistryAvailable = $false
            ProfileCount      = 0
            Profiles          = @()
            DetectionNotes    = $detectionNotes
        }
    }

    $sid = $userProfile.SID

    #
    # ProfMig does not load NTUSER.DAT during Outlook detection.
    # Registry information is inspected only when the source
    # user's registry hive is already loaded.
    #
    if (-not $userProfile.Loaded) {

        $detectionNotes += "Source user registry hive is not currently loaded."

        return [PSCustomObject]@{
            SID               = $sid
            RegistryAvailable = $false
            ProfileCount      = 0
            Profiles          = @()
            DetectionNotes    = $detectionNotes
        }
    }

    $registryAvailable = $true

    $officeVersions = @(
        "16.0"
        "15.0"
        "14.0"
    )

    foreach ($officeVersion in $officeVersions) {

        $profilesPath = "Registry::HKEY_USERS\$sid\Software\Microsoft\Office\$officeVersion\Outlook\Profiles"

        if (-not (Test-Path -LiteralPath $profilesPath)) {
            continue
        }

        $registryProfiles = @(
            Get-ChildItem `
                -LiteralPath $profilesPath `
                -ErrorAction SilentlyContinue
        )

        foreach ($registryProfile in $registryProfiles) {

            $profiles += [PSCustomObject]@{
                Name          = $registryProfile.PSChildName
                OfficeVersion = $officeVersion
                RegistryPath  = $registryProfile.Name
                Classification = "Recreate"
                Action        = "Recreate"
            }
        }
    }

    if ($profiles.Count -eq 0) {
        $detectionNotes += "No Classic Outlook registry profiles were detected."
    }

    return [PSCustomObject]@{
        SID               = $sid
        RegistryAvailable = $registryAvailable
        ProfileCount      = $profiles.Count
        Profiles          = $profiles
        DetectionNotes    = $detectionNotes
    }
}

function Test-ProfMigOutlookRunning {
    [CmdletBinding()]
    param ()

    $processes = @(
        Get-Process `
            -Name "OUTLOOK", "olk" `
            -ErrorAction SilentlyContinue
    )

    return [PSCustomObject]@{
        IsRunning = $processes.Count -gt 0
        Processes = @(
            $processes |
                ForEach-Object {
                    [PSCustomObject]@{
                        Name = $_.ProcessName
                        Id   = $_.Id
                    }
                }
        )
    }
}


function Test-ProfMigOutlookMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfilePath
    )

    $checks = @()
    $warnings = @()

    #
    # Source profile.
    #
    $sourceExists = Test-Path `
        -LiteralPath $SourceProfilePath `
        -PathType Container

    $checks += [PSCustomObject]@{
        Check   = "SourceProfileExists"
        Passed  = $sourceExists
        Blocking = $true
        Message = if ($sourceExists) {
            "Source profile exists."
        }
        else {
            "Source profile does not exist."
        }
    }

    #
    # Destination profile.
    #
    $destinationExists = Test-Path `
        -LiteralPath $DestinationProfilePath `
        -PathType Container

    $checks += [PSCustomObject]@{
        Check   = "DestinationProfileExists"
        Passed  = $destinationExists
        Blocking = $true
        Message = if ($destinationExists) {
            "Destination profile exists."
        }
        else {
            "Destination profile does not exist."
        }
    }

    #
    # Source and destination must be different.
    #
    $differentProfiles = (
        $SourceProfilePath.TrimEnd('\') -ne
        $DestinationProfilePath.TrimEnd('\')
    )

    $checks += [PSCustomObject]@{
        Check   = "DifferentProfiles"
        Passed  = $differentProfiles
        Blocking = $true
        Message = if ($differentProfiles) {
            "Source and destination profiles are different."
        }
        else {
            "Source and destination profiles cannot be the same."
        }
    }

    #
    # Do not continue with Outlook running.
    #
    $runningState = Test-ProfMigOutlookRunning

    $checks += [PSCustomObject]@{
        Check   = "OutlookNotRunning"
        Passed  = (-not $runningState.IsRunning)
        Blocking = $true
        Message = if (-not $runningState.IsRunning) {
            "Outlook is not running."
        }
        else {
            "Outlook is currently running."
        }
    }

    #
    # Only create the migration plan if the source profile exists.
    #
    $plan = $null

    if ($sourceExists) {
        $plan = Get-ProfMigOutlookMigrationPlan `
            -ProfilePath $SourceProfilePath
    }

    $outlookDetected = (
        $null -ne $plan -and
        $plan.ItemsDetected -gt 0
    )

    $checks += [PSCustomObject]@{
        Check   = "OutlookDataDetected"
        Passed  = $outlookDetected
        Blocking = $true
        Message = if ($outlookDetected) {
            "Outlook user data was detected."
        }
        else {
            "No supported Outlook user data was detected."
        }
    }

    $migrationItemsAvailable = (
        $null -ne $plan -and
        $plan.MigrateCount -gt 0
    )

    $checks += [PSCustomObject]@{
        Check   = "MigrationItemsAvailable"
        Passed  = $migrationItemsAvailable
        Blocking = $true
        Message = if ($migrationItemsAvailable) {
            "Portable Outlook migration items are available."
        }
        else {
            "No portable Outlook migration items are available."
        }
    }

    #
    # Verify OST policy.
    #
    $ostExcluded = $true

    if ($null -ne $plan) {

        $unexpectedOst = @(
            $plan.MigrateItems |
                Where-Object {
                    $_.Type -eq "OST"
                }
        )

        $ostExcluded = $unexpectedOst.Count -eq 0
    }

    $checks += [PSCustomObject]@{
        Check   = "OSTExcluded"
        Passed  = $ostExcluded
        Blocking = $true
        Message = if ($ostExcluded) {
            "OST files are excluded from migration."
        }
        else {
            "One or more OST files are incorrectly marked for migration."
        }
    }

    #
    # Authentication is never migrated.
    #
    $authenticationExcluded = (
        $null -eq $plan -or
        $plan.AuthenticationPolicy -eq "Reauthenticate"
    )

    $checks += [PSCustomObject]@{
        Check   = "AuthenticationExcluded"
        Passed  = $authenticationExcluded
        Blocking = $true
        Message = if ($authenticationExcluded) {
            "Microsoft 365 authentication will not be migrated."
        }
        else {
            "Authentication policy is unsafe."
        }
    }

    #
    # Review items are informational at this stage.
    #
    if (
        $null -ne $plan -and
        $plan.ReviewCount -gt 0
    ) {
        $warnings += "$($plan.ReviewCount) Outlook item(s) require review and will not be automatically migrated."
    }

    $failedBlockingChecks = @(
        $checks |
            Where-Object {
                $_.Blocking -and
                -not $_.Passed
            }
    )

    $ready = $failedBlockingChecks.Count -eq 0

    return [PSCustomObject]@{
        Ready                   = $ready
        SourceProfilePath       = $SourceProfilePath
        DestinationProfilePath  = $DestinationProfilePath
        OutlookRunning          = $runningState.IsRunning
        Checks                  = $checks
        Warnings                = $warnings
        MigrationPlan           = $plan
    }
}

function Get-ProfMigOutlookMigrationPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    $detection = Get-ProfMigOutlookDetection `
        -ProfilePath $ProfilePath

    $installation = Get-ProfMigOutlookInstallation

    $profileInfo = Get-ProfMigOutlookProfiles `
        -ProfilePath $ProfilePath

    $migrateItems = @(
        $detection.Items |
            Where-Object {
                $_.Action -eq "Migrate"
            }
    )

    $reviewItems = @(
        $detection.Items |
            Where-Object {
                $_.Action -eq "Review"
            }
    )

    $excludedItems = @(
        $detection.Items |
            Where-Object {
                $_.Action -eq "Exclude"
            }
    )

    $totalMigrationBytes = (
        $migrateItems |
            Measure-Object `
                -Property SizeBytes `
                -Sum
    ).Sum

    if ($null -eq $totalMigrationBytes) {
        $totalMigrationBytes = 0
    }

    $status = if (-not $detection.Detected) {
        "NoData"
    }
    elseif ($migrateItems.Count -eq 0) {
        "ReviewOnly"
    }
    else {
        "Ready"
    }

    return [PSCustomObject]@{
        Application          = "Microsoft Outlook"
        ApplicationId        = "Outlook"

        OutlookType          = $installation.OutlookType

        ClassicDetected      = $installation.ClassicDetected
        ClassicVersion       = $installation.ClassicVersion
        ClassicArchitecture  = $installation.ClassicArchitecture

        NewOutlookDetected   = $installation.NewOutlookDetected
        NewOutlookVersion    = $installation.NewOutlookVersion

        RegistryAvailable    = $profileInfo.RegistryAvailable
        OutlookProfileCount  = $profileInfo.ProfileCount
        OutlookProfiles      = $profileInfo.Profiles

        ItemsDetected        = $detection.ItemCount

        MigrateCount         = $migrateItems.Count
        ReviewCount          = $reviewItems.Count
        ExcludeCount         = $excludedItems.Count

        MigrationBytes       = [Int64]$totalMigrationBytes

        MigrateItems         = $migrateItems
        ReviewItems          = $reviewItems
        ExcludedItems        = $excludedItems

        AuthenticationPolicy = "Reauthenticate"
        OstPolicy            = "Exclude"
        ProfilePolicy        = "Recreate"

        Status               = $status
    }
}

function Get-ProfMigOutlookDetection {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ProfilePath
    )

    Write-ProfMigOutlookLog `
        -Level "INFO" `
        -Message "Starting Outlook data detection for source profile: $ProfilePath"

    if (-not (Test-Path -LiteralPath $ProfilePath -PathType Container)) {
        throw "Source profile path does not exist: $ProfilePath"
    }

    $paths = Get-ProfMigOutlookPaths `
        -ProfilePath $ProfilePath

    $outlookData = @(
        Get-ProfMigOutlookFiles `
            -ProfilePath $ProfilePath
    )

    $signatures = @(
        Get-ProfMigOutlookSignatures `
            -ProfilePath $ProfilePath
    )

    $templates = @(
        Get-ProfMigOutlookTemplates `
            -ProfilePath $ProfilePath
    )

    $allItems = @(
        $outlookData
        $signatures
        $templates
    )

    $portableCount = @(
        $allItems |
            Where-Object Classification -eq "Portable"
    ).Count

    $reviewCount = @(
        $allItems |
            Where-Object Classification -eq "Review"
    ).Count

    $recreateCount = @(
        $allItems |
            Where-Object Classification -eq "Recreate"
    ).Count

    $detected = $allItems.Count -gt 0

    Write-ProfMigOutlookLog `
        -Level "SUCCESS" `
        -Message "Outlook data detection completed. Items: $($allItems.Count); portable: $portableCount; review: $reviewCount; recreate: $recreateCount"

    return [PSCustomObject]@{
        Application     = "Microsoft Outlook"
        ApplicationId   = "Outlook"
        ProfilePath     = $ProfilePath
        Detected        = $detected
        Paths           = $paths
        ItemCount       = $allItems.Count
        PortableCount   = $portableCount
        ReviewCount     = $reviewCount
        RecreateCount   = $recreateCount
        Items           = $allItems
    }
}

function Copy-ProfMigOutlookPst {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = "Source PST does not exist."
        }
    }

    $sourceFile = Get-Item `
        -LiteralPath $SourcePath `
        -ErrorAction Stop

    if ($sourceFile.Extension -ne ".pst") {
        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]$sourceFile.Length
            Reason          = "Source file is not a PST file."
        }
    }

    #
    # Never overwrite an existing destination PST.
    #
    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {

        return [PSCustomObject]@{
            Success         = $true
            Skipped         = $true
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = "Destination PST already exists."
        }
    }

    $destinationDirectory = Split-Path `
        -Path $DestinationPath `
        -Parent

    #
    # Determine the destination drive and verify available space.
    #
    $destinationRoot = [System.IO.Path]::GetPathRoot(
        $DestinationPath
    )

    try {
        $driveInfo = [System.IO.DriveInfo]::new(
            $destinationRoot
        )

        [Int64]$requiredBytes = $sourceFile.Length

        #
        # Reserve 10 percent extra space, with a minimum
        # safety margin of 100 MB.
        #
        [Int64]$safetyMargin = [Math]::Max(
            [Math]::Ceiling($requiredBytes * 0.10),
            100MB
        )

        [Int64]$totalRequired = (
            $requiredBytes +
            $safetyMargin
        )

        if ($driveInfo.AvailableFreeSpace -lt $totalRequired) {

            return [PSCustomObject]@{
                Success         = $false
                Skipped         = $false
                SourcePath      = $SourcePath
                DestinationPath = $DestinationPath
                SizeBytes       = [Int64]0
                Reason          = "Insufficient destination disk space."
            }
        }
    }
    catch {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = "Destination disk space could not be validated: $($_.Exception.Message)"
        }
    }

    try {

        if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {

            New-Item `
                -ItemType Directory `
                -Path $destinationDirectory `
                -Force `
                -ErrorAction Stop |
                Out-Null
        }

        Copy-Item `
            -LiteralPath $SourcePath `
            -Destination $DestinationPath `
            -ErrorAction Stop

        #
        # Post-copy validation.
        #
        if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf)) {
            throw "Destination PST was not created."
        }

        $destinationFile = Get-Item `
            -LiteralPath $DestinationPath `
            -ErrorAction Stop

        if ($destinationFile.Length -ne $sourceFile.Length) {

            #
            # Do not leave an incomplete PST behind.
            #
            Remove-Item `
                -LiteralPath $DestinationPath `
                -Force `
                -ErrorAction SilentlyContinue

            throw "Destination PST size does not match source PST size."
        }

        return [PSCustomObject]@{
            Success         = $true
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]$destinationFile.Length
            Reason          = "PST copied and validated successfully."
        }
    }
    catch {

        return [PSCustomObject]@{
            Success         = $false
            Skipped         = $false
            SourcePath      = $SourcePath
            DestinationPath = $DestinationPath
            SizeBytes       = [Int64]0
            Reason          = $_.Exception.Message
        }
    }
}

function Invoke-ProfMigOutlookMigration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceProfilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationProfilePath
    )

    $startedAt = Get-Date

    Write-ProfMigOutlookLog `
        -Level "INFO" `
        -Message "Starting Outlook migration from '$SourceProfilePath' to '$DestinationProfilePath'."


    #
    # Run all pre-flight validation checks before writing anything
    # to the destination profile.
    #
    $validation = Test-ProfMigOutlookMigration `
        -SourceProfilePath $SourceProfilePath `
        -DestinationProfilePath $DestinationProfilePath

    if (-not $validation.Ready) {

        $failedChecks = @(
            $validation.Checks |
                Where-Object {
                    $_.Blocking -and
                    -not $_.Passed
                }
        )

        $failedCheckNames = (
            $failedChecks |
                ForEach-Object {
                    $_.Check
                }
        ) -join ", "

        Write-ProfMigOutlookLog `
            -Level "ERROR" `
            -Message "Outlook migration blocked. Failed checks: $failedCheckNames"

        return [PSCustomObject]@{
            Application            = "Microsoft Outlook"
            ApplicationId          = "Outlook"
            Status                 = "Blocked"
            SourceProfilePath      = $SourceProfilePath
            DestinationProfilePath = $DestinationProfilePath
            FilesSelected          = 0
            FilesCopied            = 0
            FilesSkipped           = 0
            FilesFailed            = 0
            BytesCopied            = [Int64]0
            CopiedItems            = @()
            SkippedItems           = @()
            FailedItems            = @()
            Warnings               = $validation.Warnings
            Validation             = $validation
        }
    }

    $sourcePaths = Get-ProfMigOutlookPaths `
        -ProfilePath $SourceProfilePath

    $destinationPaths = Get-ProfMigOutlookPaths `
        -ProfilePath $DestinationProfilePath

    $copiedItems = @()
    $skippedItems = @()
    $failedItems = @()

    $filesSelected = 0
    $filesCopied = 0
    $filesSkipped = 0
    $filesFailed = 0

    [Int64]$bytesCopied = 0

    #
    # Signatures
    #
    # Copy the complete signature directory structure because
    # HTML signatures may reference supporting files located
    # inside subdirectories.
    #
    $signatureItems = @(
        $validation.MigrationPlan.MigrateItems |
            Where-Object {
                $_.Type -eq "Signature"
            }
    )

    foreach ($item in $signatureItems) {

        $filesSelected++

        try {
            $relativePath = $item.Path.Substring(
                $sourcePaths.Signatures.Length
            ).TrimStart('\')

            $destinationFile = Join-Path `
                -Path $destinationPaths.Signatures `
                -ChildPath $relativePath

            $destinationDirectory = Split-Path `
                -Path $destinationFile `
                -Parent

            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {

                New-Item `
                    -ItemType Directory `
                    -Path $destinationDirectory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }


            #
            # ProfMig currently follows the safe default used by
            # the copy engine: existing destination data is not
            # overwritten.
            #
            if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {

                $filesSkipped++

                $skippedItems += [PSCustomObject]@{
                    Type            = $item.Type
                    SourcePath      = $item.Path
                    DestinationPath = $destinationFile
                    Reason          = "Destination file already exists."
                }

                continue
            }

            Copy-Item `
                -LiteralPath $item.Path `
                -Destination $destinationFile `
                -ErrorAction Stop

            $filesCopied++
            $bytesCopied += [Int64]$item.SizeBytes

            $copiedItems += [PSCustomObject]@{
                Type            = $item.Type
                SourcePath      = $item.Path
                DestinationPath = $destinationFile
                SizeBytes       = $item.SizeBytes
            }
        }
        catch {

            $filesFailed++

            $failedItems += [PSCustomObject]@{
                Type       = $item.Type
                SourcePath = $item.Path
                Error      = $_.Exception.Message
            }

            Write-ProfMigOutlookLog `
                -Level "ERROR" `
                -Message "Failed to migrate Outlook signature file '$($item.Path)': $($_.Exception.Message)"
        }
    }

    #
    # Outlook templates
    #
    $templateItems = @(
        $validation.MigrationPlan.MigrateItems |
            Where-Object {
                $_.Type -eq "Template"
            }
    )

    foreach ($item in $templateItems) {

        $filesSelected++

        try {
            $relativePath = $item.Path.Substring(
                $sourcePaths.Templates.Length
            ).TrimStart('\')

            $destinationFile = Join-Path `
                -Path $destinationPaths.Templates `
                -ChildPath $relativePath

            $destinationDirectory = Split-Path `
                -Path $destinationFile `
                -Parent

            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {

                New-Item `
                    -ItemType Directory `
                    -Path $destinationDirectory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }

            if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {

                $filesSkipped++

                $skippedItems += [PSCustomObject]@{
                    Type            = $item.Type
                    SourcePath      = $item.Path
                    DestinationPath = $destinationFile
                    Reason          = "Destination file already exists."
                }

                continue
            }

            Copy-Item `
                -LiteralPath $item.Path `
                -Destination $destinationFile `
                -ErrorAction Stop

            $filesCopied++
            $bytesCopied += [Int64]$item.SizeBytes

            $copiedItems += [PSCustomObject]@{
                Type            = $item.Type
                SourcePath      = $item.Path
                DestinationPath = $destinationFile
                SizeBytes       = $item.SizeBytes
            }
        }
        catch {

            $filesFailed++

            $failedItems += [PSCustomObject]@{
                Type       = $item.Type
                SourcePath = $item.Path
                Error      = $_.Exception.Message
            }

            Write-ProfMigOutlookLog `
                -Level "ERROR" `
                -Message "Failed to migrate Outlook template '$($item.Path)': $($_.Exception.Message)"
        }
    }

    #
    # Portable Classic Outlook settings
    #
    # Only settings explicitly classified as portable are copied.
    #
    $settingsItems = @(
        $validation.MigrationPlan.MigrateItems |
            Where-Object {
                $_.Type -in @(
                    "OutlookSettings",
                    "PrintSettings"
                )
            }
    )

    foreach ($item in $settingsItems) {

        $filesSelected++

        try {
            $destinationFile = Join-Path `
                -Path $destinationPaths.RoamingOutlook `
                -ChildPath $item.Name

            $destinationDirectory = Split-Path `
                -Path $destinationFile `
                -Parent

            if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {

                New-Item `
                    -ItemType Directory `
                    -Path $destinationDirectory `
                    -Force `
                    -ErrorAction Stop |
                    Out-Null
            }

            if (Test-Path -LiteralPath $destinationFile -PathType Leaf) {

                $filesSkipped++

                $skippedItems += [PSCustomObject]@{
                    Type            = $item.Type
                    SourcePath      = $item.Path
                    DestinationPath = $destinationFile
                    Reason          = "Destination file already exists."
                }

                continue
            }

            Copy-Item `
                -LiteralPath $item.Path `
                -Destination $destinationFile `
                -ErrorAction Stop

            #
            # Validate the copied file.
            #
            $destinationItem = Get-Item `
                -LiteralPath $destinationFile `
                -ErrorAction Stop

            if ($destinationItem.Length -ne $item.SizeBytes) {

                Remove-Item `
                    -LiteralPath $destinationFile `
                    -Force `
                    -ErrorAction SilentlyContinue

                throw "Destination file size does not match source file size."
            }

            $filesCopied++
            $bytesCopied += [Int64]$item.SizeBytes

            $copiedItems += [PSCustomObject]@{
                Type            = $item.Type
                SourcePath      = $item.Path
                DestinationPath = $destinationFile
                SizeBytes       = $item.SizeBytes
            }
        }
        catch {

            $filesFailed++

            $failedItems += [PSCustomObject]@{
                Type       = $item.Type
                SourcePath = $item.Path
                Error      = $_.Exception.Message
            }

            Write-ProfMigOutlookLog `
                -Level "ERROR" `
                -Message "Failed to migrate Outlook setting '$($item.Path)': $($_.Exception.Message)"
        }
    }

    #
    # PST files
    #
    # PST files contain portable Outlook user data.
    # They are copied without modification and validated after copy.
    #
    $pstItems = @(
        $validation.MigrationPlan.MigrateItems |
            Where-Object {
                $_.Type -eq "PST"
            }
    )

    foreach ($item in $pstItems) {

        $filesSelected++

        try {
            #
            # Preserve the standard Outlook Files location
            # inside the destination profile.
            #
            $destinationFile = Join-Path `
                -Path $destinationPaths.OutlookFiles `
                -ChildPath $item.Name

            $pstResult = Copy-ProfMigOutlookPst `
                -SourcePath $item.Path `
                -DestinationPath $destinationFile

            if ($pstResult.Success -and $pstResult.Skipped) {

                $filesSkipped++

                $skippedItems += [PSCustomObject]@{
                    Type            = $item.Type
                    SourcePath      = $item.Path
                    DestinationPath = $destinationFile
                    Reason          = $pstResult.Reason
                }

                continue
            }

            if ($pstResult.Success) {

                $filesCopied++
                $bytesCopied += [Int64]$pstResult.SizeBytes

                $copiedItems += [PSCustomObject]@{
                    Type            = $item.Type
                    SourcePath      = $item.Path
                    DestinationPath = $destinationFile
                    SizeBytes       = $pstResult.SizeBytes
                }

                continue
            }

            $filesFailed++

            $failedItems += [PSCustomObject]@{
                Type       = $item.Type
                SourcePath = $item.Path
                Error      = $pstResult.Reason
            }

            Write-ProfMigOutlookLog `
                -Level "ERROR" `
                -Message "Failed to migrate Outlook PST '$($item.Path)': $($pstResult.Reason)"
        }
        catch {

            $filesFailed++

            $failedItems += [PSCustomObject]@{
                Type       = $item.Type
                SourcePath = $item.Path
                Error      = $_.Exception.Message
            }

            Write-ProfMigOutlookLog `
                -Level "ERROR" `
                -Message "Failed to migrate Outlook PST '$($item.Path)': $($_.Exception.Message)"
        }
    }


    $status = if ($filesFailed -gt 0) {
        "CompletedWithErrors"
    }
    elseif ($filesSkipped -gt 0 -or $validation.Warnings.Count -gt 0) {
        "CompletedWithWarnings"
    }
    else {
        "Success"
    }

    Write-ProfMigOutlookLog `
        -Level "SUCCESS" `
        -Message "Outlook migration completed. Selected: $filesSelected; copied: $filesCopied; skipped: $filesSkipped; failed: $filesFailed; bytes: $bytesCopied"

    $completedAt = Get-Date
    $duration = $completedAt - $startedAt

    return [PSCustomObject]@{
        Application            = "Microsoft Outlook"
        ApplicationId          = "Outlook"
        Status                 = $status
        SourceProfilePath      = $SourceProfilePath
        DestinationProfilePath = $DestinationProfilePath

        StartedAt              = $startedAt
        CompletedAt            = $completedAt
        Duration               = $duration

        FilesSelected          = $filesSelected
        FilesCopied            = $filesCopied
        FilesSkipped           = $filesSkipped
        FilesFailed            = $filesFailed
        BytesCopied            = $bytesCopied
        CopiedItems            = $copiedItems
        SkippedItems           = $skippedItems
        FailedItems            = $failedItems
        Warnings               = $validation.Warnings
        Validation             = $validation
    }
}

function ConvertTo-ProfMigOutlookCopyResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$OutlookResult
    )

    $now = Get-Date

    #
    # Use timestamps from the Outlook result when available.
    #
    $startedAt = if (
        $OutlookResult.PSObject.Properties.Name -contains "StartedAt" -and
        $null -ne $OutlookResult.StartedAt
    ) {
        $OutlookResult.StartedAt
    }
    else {
        $now
    }

    $completedAt = if (
        $OutlookResult.PSObject.Properties.Name -contains "CompletedAt" -and
        $null -ne $OutlookResult.CompletedAt
    ) {
        $OutlookResult.CompletedAt
    }
    else {
        $now
    }

    $duration = $completedAt - $startedAt

    #
    # Outlook is the selected migration component regardless
    # of whether files were copied or skipped.
    #
    $components = @(
        [PSCustomObject]@{
            Component     = "Outlook"
            FilesSelected = $OutlookResult.FilesSelected
            FilesCopied   = $OutlookResult.FilesCopied
            FilesSkipped  = $OutlookResult.FilesSkipped
            FilesFailed   = $OutlookResult.FilesFailed
            BytesCopied   = $OutlookResult.BytesCopied
            Status        = $OutlookResult.Status
        }
    )

    #
    # Skipped items.
    #
    $skippedItems = @(
        $OutlookResult.SkippedItems |
            ForEach-Object {

                [PSCustomObject]@{
                    Component       = "Outlook.$($_.Type)"
                    SourceFile      = $_.SourcePath
                    DestinationFile = $_.DestinationPath
                    Reason           = $_.Reason
                }
            }
    )

    #
    # Failed items.
    #
    $errors = @(
        $OutlookResult.FailedItems |
            ForEach-Object {

                [PSCustomObject]@{
                    Component       = "Outlook.$($_.Type)"
                    SourceFile      = $_.SourcePath
                    DestinationFile = if (
                        $_.PSObject.Properties.Name -contains "DestinationPath"
                    ) {
                        $_.DestinationPath
                    }
                    else {
                        $null
                    }
                    Error            = $_.Error
                }
            }
    )

    #
    # Explicitly report Outlook data that ProfMig intentionally
    # does not migrate.
    #
    $excludedItems = @()

    if (
        $OutlookResult.PSObject.Properties.Name -contains "Validation" -and
        $null -ne $OutlookResult.Validation -and
        $null -ne $OutlookResult.Validation.MigrationPlan
    ) {

        $plan = $OutlookResult.Validation.MigrationPlan

        foreach ($item in @($plan.ExcludedItems)) {

            $excludedItems += [PSCustomObject]@{
                Component  = "Outlook.$($item.Type)"
                SourceFile = $item.Path
                Reason     = $item.Reason
            }
        }

        #
        # Outlook profiles are intentionally recreated rather
        # than copied between Windows users.
        #
        foreach ($profile in @($plan.OutlookProfiles)) {

            $excludedItems += [PSCustomObject]@{
                Component  = "Outlook.Profile"
                SourceFile = $profile.RegistryPath
                Reason     = "Outlook profile configuration is recreated for the destination user."
            }
        }
    }

    #
    # Microsoft 365 authentication is always explicitly excluded.
    #
    $excludedItems += [PSCustomObject]@{
    Component  = "Outlook.Authentication"
    SourceFile = "Not applicable"
    Reason     = "Microsoft 365 authentication tokens and authenticated sessions are not migrated. Reauthentication is required."
}

    $filesExcluded = @(
        $excludedItems |
            Where-Object {
                $_.Component -notin @(
                    "Outlook.Authentication"
                )
            }
    ).Count

    return [PSCustomObject]@{
        SourceProfile      = $OutlookResult.SourceProfilePath
        DestinationProfile = $OutlookResult.DestinationProfilePath

        StartedAt          = $startedAt
        CompletedAt        = $completedAt
        Duration           = $duration

        Components         = $components

        SkippedItems       = $skippedItems
        ExcludedItems      = $excludedItems
        Errors             = $errors

        Totals             = [PSCustomObject]@{
            FilesSelected = $OutlookResult.FilesSelected
            FilesCopied   = $OutlookResult.FilesCopied
            FilesSkipped  = $OutlookResult.FilesSkipped
            FilesExcluded = $filesExcluded
            FilesFailed   = $OutlookResult.FilesFailed
            BytesCopied   = $OutlookResult.BytesCopied
        }

        Status             = $OutlookResult.Status
    }
}

Export-ModuleMember -Function @(
    'ConvertTo-ProfMigOutlookCopyResult'
    'Get-ProfMigOutlookDetection'
    'Get-ProfMigOutlookFiles'
    'Get-ProfMigOutlookInstallation'
    'Get-ProfMigOutlookMigrationPlan'
    'Get-ProfMigOutlookPaths'
    'Get-ProfMigOutlookProfiles'
    'Get-ProfMigOutlookSignatures'
    'Get-ProfMigOutlookTemplates'
    'Invoke-ProfMigOutlookMigration'
    'Test-ProfMigOutlookMigration'
    'Test-ProfMigOutlookRunning'
)