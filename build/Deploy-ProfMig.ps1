<#
.SYNOPSIS
    Deploys a ProfMig runtime package to a Windows system.

.DESCRIPTION
    Installs, upgrades, or explicitly downgrades ProfMig from a validated
    runtime package.

    Deployment is designed for interactive administration and unattended
    deployment through management platforms such as RMM.

    The deployment process validates the package before modifying an existing
    installation and uses staging and rollback directories to reduce the risk
    of damaging a working installation.

    Logs, reports, and backup data are preserved during upgrades.

    Downgrades are blocked unless -AllowDowngrade is specified.

.PARAMETER InstallPath
    Destination directory for the ProfMig installation.

    Default:
    C:\Program Files\ProfMig

.PARAMETER AllowDowngrade
    Allows installation of a ProfMig package with a lower semantic version
    than the currently installed version.

.EXITCODES
    0 - Success
    1 - General deployment failure
    2 - Administrator privileges required
    3 - Invalid deployment package
    4 - Downgrade blocked
#>

[CmdletBinding()]
param (
    [string]$InstallPath = (Join-Path $env:ProgramFiles 'ProfMig'),

    [switch]$AllowDowngrade
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ExitCodes = @{
    Success             = 0
    GeneralFailure      = 1
    AdministratorNeeded = 2
    InvalidPackage      = 3
    DowngradeBlocked    = 4
}

$PersistentDirectories = @(
    'Logs'
    'Reports'
    'Backup'
)

function Test-Administrator {

    $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $Principal = New-Object `
        Security.Principal.WindowsPrincipal($Identity)

    return $Principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function ConvertTo-ProfMigSemanticVersion {

    param (
        [Parameter(Mandatory)]
        [string]$Version
    )

    $Pattern = (
        '^(?<Major>0|[1-9]\d*)\.' +
        '(?<Minor>0|[1-9]\d*)\.' +
        '(?<Patch>0|[1-9]\d*)' +
        '(?:-(?<PreRelease>[0-9A-Za-z.-]+))?$'
    )

    if ($Version -notmatch $Pattern) {
        throw "Invalid ProfMig semantic version: $Version"
    }

    $PreRelease = ''

    if ($Matches.ContainsKey('PreRelease')) {
        $PreRelease = [string]$Matches['PreRelease']
    }

    return [pscustomobject]@{
        Original   = $Version
        Major      = [int]$Matches['Major']
        Minor      = [int]$Matches['Minor']
        Patch      = [int]$Matches['Patch']
        PreRelease = $PreRelease
    }
}

function Compare-ProfMigSemanticVersion {

    param (
        [Parameter(Mandatory)]
        [string]$VersionA,

        [Parameter(Mandatory)]
        [string]$VersionB
    )

    $A = ConvertTo-ProfMigSemanticVersion `
        -Version $VersionA

    $B = ConvertTo-ProfMigSemanticVersion `
        -Version $VersionB

    foreach ($Property in @('Major', 'Minor', 'Patch')) {

        if ($A.$Property -lt $B.$Property) {
            return -1
        }

        if ($A.$Property -gt $B.$Property) {
            return 1
        }
    }

    $APreRelease = $A.PreRelease
    $BPreRelease = $B.PreRelease

    if (
        [string]::IsNullOrWhiteSpace($APreRelease) -and
        [string]::IsNullOrWhiteSpace($BPreRelease)
    ) {
        return 0
    }

    if ([string]::IsNullOrWhiteSpace($APreRelease)) {
        return 1
    }

    if ([string]::IsNullOrWhiteSpace($BPreRelease)) {
        return -1
    }

    $AIdentifiers = $APreRelease -split '\.'
    $BIdentifiers = $BPreRelease -split '\.'

    $IdentifierCount = [Math]::Max(
        $AIdentifiers.Count,
        $BIdentifiers.Count
    )

    for ($Index = 0; $Index -lt $IdentifierCount; $Index++) {

        if ($Index -ge $AIdentifiers.Count) {
            return -1
        }

        if ($Index -ge $BIdentifiers.Count) {
            return 1
        }

        $AIdentifier = $AIdentifiers[$Index]
        $BIdentifier = $BIdentifiers[$Index]

        $ANumeric = $AIdentifier -match '^\d+$'
        $BNumeric = $BIdentifier -match '^\d+$'

        if ($ANumeric -and $BNumeric) {

            $ANumber = [int64]$AIdentifier
            $BNumber = [int64]$BIdentifier

            if ($ANumber -lt $BNumber) {
                return -1
            }

            if ($ANumber -gt $BNumber) {
                return 1
            }

            continue
        }

        if ($ANumeric -and -not $BNumeric) {
            return -1
        }

        if (-not $ANumeric -and $BNumeric) {
            return 1
        }

        $Comparison = [string]::CompareOrdinal(
            $AIdentifier,
            $BIdentifier
        )

        if ($Comparison -lt 0) {
            return -1
        }

        if ($Comparison -gt 0) {
            return 1
        }
    }

    return 0
}

function Get-ProfMigPackageMetadata {

    param (
        [Parameter(Mandatory)]
        [string]$PackagePath
    )

    $MetadataPath = Join-Path `
        $PackagePath `
        'ProfMig.Build.psd1'

    if (
        -not (
            Test-Path `
                -LiteralPath $MetadataPath `
                -PathType Leaf
        )
    ) {
        throw "Package metadata was not found: $MetadataPath"
    }

    return Import-PowerShellDataFile `
        -LiteralPath $MetadataPath
}

function Test-ProfMigPackage {

    param (
        [Parameter(Mandatory)]
        [string]$PackagePath
    )

    $RequiredFiles = @(
        'ProfMig.Build.psd1'
        'Start-ProfMig.bat'
        'LICENSE'
        'src\ProfMig.ps1'
        'src\Config.psd1'
    )

    $RequiredDirectories = @(
        'src\Modules'
        'src\Applications'
        'src\Profiles'
    )

    foreach ($RelativePath in $RequiredFiles) {

        $RequiredPath = Join-Path `
            $PackagePath `
            $RelativePath

        if (
            -not (
                Test-Path `
                    -LiteralPath $RequiredPath `
                    -PathType Leaf
            )
        ) {
            throw "Required package file is missing: $RelativePath"
        }
    }

    foreach ($RelativePath in $RequiredDirectories) {

        $RequiredPath = Join-Path `
            $PackagePath `
            $RelativePath

        if (
            -not (
                Test-Path `
                    -LiteralPath $RequiredPath `
                    -PathType Container
            )
        ) {
            throw "Required package directory is missing: $RelativePath"
        }
    }
}

function Test-ProfMigPreservedDataOnly {

    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Container
        )
    ) {
        return $false
    }

    $Items = @(
        Get-ChildItem `
            -LiteralPath $Path `
            -Force
    )

    if ($Items.Count -eq 0) {
        return $true
    }

    foreach ($Item in $Items) {

        if (-not $Item.PSIsContainer) {
            return $false
        }

        if ($Item.Name -notin $PersistentDirectories) {
            return $false
        }
    }

    return $true
}
function Copy-ProfMigPackage {

    param (
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$DestinationPath
    )

    $null = New-Item `
        -ItemType Directory `
        -Path $DestinationPath `
        -Force

    foreach (
        $Item in Get-ChildItem `
            -LiteralPath $SourcePath `
            -Force
    ) {

        Copy-Item `
            -LiteralPath $Item.FullName `
            -Destination $DestinationPath `
            -Recurse `
            -Force
    }
}

function Restore-ProfMigPersistentData {

    param (
        [Parameter(Mandatory)]
        [string]$PreviousInstallationPath,

        [Parameter(Mandatory)]
        [string]$NewInstallationPath
    )

    foreach ($DirectoryName in $PersistentDirectories) {

        $OldDirectory = Join-Path `
            $PreviousInstallationPath `
            $DirectoryName

        if (
            -not (
                Test-Path `
                    -LiteralPath $OldDirectory `
                    -PathType Container
            )
        ) {
            continue
        }

        $NewDirectory = Join-Path `
            $NewInstallationPath `
            $DirectoryName

        if (
            -not (
                Test-Path `
                    -LiteralPath $NewDirectory `
                    -PathType Container
            )
        ) {

            $null = New-Item `
                -ItemType Directory `
                -Path $NewDirectory `
                -Force
        }

        foreach (
            $Item in Get-ChildItem `
                -LiteralPath $OldDirectory `
                -Force
        ) {

            Copy-Item `
                -LiteralPath $Item.FullName `
                -Destination $NewDirectory `
                -Recurse `
                -Force
        }
    }
}

$PackageRoot = $PSScriptRoot

$StagingPath = $null
$RollbackPath = $null

$PreviousInstallationMoved = $false
$NewInstallationActivated = $false
$DeploymentCommitted = $false

try {

    Write-Host 'ProfMig deployment'
    Write-Host '================='
    Write-Host ''

    # -------------------------------------------------------------------------
    # Validate administrator privileges
    # -------------------------------------------------------------------------

    if (-not (Test-Administrator)) {

        [Console]::Error.WriteLine(
            'ProfMig deployment requires administrator privileges.'
        )

        exit $ExitCodes.AdministratorNeeded
    }

    # -------------------------------------------------------------------------
    # Validate source package before changing the system
    # -------------------------------------------------------------------------

    Write-Host "Package:      $PackageRoot"
    Write-Host "Install path: $InstallPath"

    try {

        Test-ProfMigPackage `
            -PackagePath $PackageRoot

        $PackageMetadata = Get-ProfMigPackageMetadata `
            -PackagePath $PackageRoot

        $PackageVersionText = [string]$PackageMetadata.Version

        if ([string]::IsNullOrWhiteSpace($PackageVersionText)) {

            throw (
                'Package version is missing from ' +
                'ProfMig.Build.psd1.'
            )
        }

        $null = ConvertTo-ProfMigSemanticVersion `
            -Version $PackageVersionText
    }
    catch {

        [Console]::Error.WriteLine(
            'ProfMig package validation failed: {0}' -f
                $_.Exception.Message
        )

        exit $ExitCodes.InvalidPackage
    }

    Write-Host "Package version: $PackageVersionText"

    # -------------------------------------------------------------------------
    # Detect existing installation
    # -------------------------------------------------------------------------

    $InstalledMetadataPath = Join-Path `
        $InstallPath `
        'ProfMig.Build.psd1'

    $InstallationExists = Test-Path `
        -LiteralPath $InstallPath `
        -PathType Container

    $InstalledVersionText = $null
    $VersionComparison = $null
    $PreservedDataOnly = $false

    if ($InstallationExists) {

        if (
            -not (
                Test-Path `
                    -LiteralPath $InstalledMetadataPath `
                    -PathType Leaf
            )
        ) {

            if (
                Test-ProfMigPreservedDataOnly `
                    -Path $InstallPath
            ) {

                $PreservedDataOnly = $true

                Write-Host 'Installed version: none'
                Write-Host (
                    'Deployment type: clean reinstall with ' +
                    'preserved runtime data'
                )
            }
            else {

                throw (
                    'The installation directory exists but is not a ' +
                    'recognized ProfMig installation or preserved-data ' +
                    'directory.'
                )
            }
        }

        if (-not $PreservedDataOnly) {

        $InstalledMetadata = Get-ProfMigPackageMetadata `
            -PackagePath $InstallPath

        $InstalledVersionText = `
            [string]$InstalledMetadata.Version

        if ([string]::IsNullOrWhiteSpace($InstalledVersionText)) {
            throw 'Installed ProfMig version is missing.'
        }

        $null = ConvertTo-ProfMigSemanticVersion `
            -Version $InstalledVersionText

        Write-Host "Installed version: $InstalledVersionText"

        $VersionComparison = Compare-ProfMigSemanticVersion `
            -VersionA $PackageVersionText `
            -VersionB $InstalledVersionText

        if ($VersionComparison -eq 0) {

            Write-Host ''
            Write-Host (
                "ProfMig $PackageVersionText is already installed."
            )
            Write-Host 'No deployment required.'

            exit $ExitCodes.Success
        }

        if (
        $VersionComparison -lt 0 -and
        -not $AllowDowngrade
    ) {

        $DowngradeMessage = (
            'Downgrade blocked. Installed version: ' +
            $InstalledVersionText +
            ', package version: ' +
            $PackageVersionText
        )

        [Console]::Error.WriteLine($DowngradeMessage)

        exit $ExitCodes.DowngradeBlocked
    }

        if ($VersionComparison -gt 0) {

            Write-Host (
                "Upgrade: $InstalledVersionText -> " +
                $PackageVersionText
            )
        }
        else {

            Write-Host (
                "Downgrade allowed: $InstalledVersionText -> " +
                $PackageVersionText
            )
        }
    }
}
    else {

        Write-Host 'Installed version: none'
        Write-Host 'Deployment type: clean installation'
    }

    # -------------------------------------------------------------------------
    # Determine deployment paths
    # -------------------------------------------------------------------------

    $InstallParent = Split-Path `
        -Parent $InstallPath

    if ([string]::IsNullOrWhiteSpace($InstallParent)) {
        throw "Invalid installation path: $InstallPath"
    }

    if (-not (Test-Path -LiteralPath $InstallParent)) {

        $null = New-Item `
            -ItemType Directory `
            -Path $InstallParent `
            -Force
    }

    $InstallName = Split-Path `
        -Leaf $InstallPath

    if ([string]::IsNullOrWhiteSpace($InstallName)) {
        throw "Invalid installation path: $InstallPath"
    }

    $DeploymentId = [guid]::NewGuid().ToString('N')

    $StagingPath = Join-Path `
        $InstallParent `
        ($InstallName + '.deploy-' + $DeploymentId)

    $RollbackPath = Join-Path `
        $InstallParent `
        ($InstallName + '.rollback-' + $DeploymentId)

    # -------------------------------------------------------------------------
    # Stage new installation
    # -------------------------------------------------------------------------

    Write-Host 'Preparing deployment staging directory...'

    Copy-ProfMigPackage `
        -SourcePath $PackageRoot `
        -DestinationPath $StagingPath

    Test-ProfMigPackage `
        -PackagePath $StagingPath

    $StagedMetadata = Get-ProfMigPackageMetadata `
        -PackagePath $StagingPath

    $StagedVersionText = [string]$StagedMetadata.Version

    $null = ConvertTo-ProfMigSemanticVersion `
        -Version $StagedVersionText

    if ($StagedVersionText -ne $PackageVersionText) {

        throw (
            'Staged ProfMig version does not match package version. ' +
            "Expected: $PackageVersionText, " +
            "actual: $StagedVersionText"
        )
    }

    Write-Host 'Staging validation completed.'

    # -------------------------------------------------------------------------
    # Preserve existing installation
    # -------------------------------------------------------------------------

    if ($InstallationExists) {

        Write-Host 'Preserving existing installation for rollback...'

        Move-Item `
            -LiteralPath $InstallPath `
            -Destination $RollbackPath

        $PreviousInstallationMoved = $true
    }

    # -------------------------------------------------------------------------
    # Activate staged installation
    # -------------------------------------------------------------------------

    Write-Host 'Activating new ProfMig installation...'

    Move-Item `
        -LiteralPath $StagingPath `
        -Destination $InstallPath

    $NewInstallationActivated = $true
    $StagingPath = $null

    # -------------------------------------------------------------------------
    # Restore persistent runtime data
    #
    # IMPORTANT:
    # Persistent data is COPIED from the rollback installation.
    # It is not moved.
    #
    # This ensures that the rollback installation remains complete until the
    # new installation has passed final validation.
    # -------------------------------------------------------------------------

    if ($PreviousInstallationMoved) {

        Write-Host 'Restoring persistent runtime data...'

        Restore-ProfMigPersistentData `
            -PreviousInstallationPath $RollbackPath `
            -NewInstallationPath $InstallPath
    }

    # Ensure persistent directories exist for both clean installations and
    # upgrades.

    foreach ($DirectoryName in $PersistentDirectories) {

        $PersistentPath = Join-Path `
            $InstallPath `
            $DirectoryName

        if (
            -not (
                Test-Path `
                    -LiteralPath $PersistentPath `
                    -PathType Container
            )
        ) {

            $null = New-Item `
                -ItemType Directory `
                -Path $PersistentPath `
                -Force
        }
    }

    # -------------------------------------------------------------------------
    # Validate final installation
    # -------------------------------------------------------------------------

    Test-ProfMigPackage `
        -PackagePath $InstallPath

    $DeployedMetadata = Get-ProfMigPackageMetadata `
        -PackagePath $InstallPath

    $DeployedVersionText = `
        [string]$DeployedMetadata.Version

    if ([string]::IsNullOrWhiteSpace($DeployedVersionText)) {
        throw 'Deployed ProfMig version is missing.'
    }

    $null = ConvertTo-ProfMigSemanticVersion `
        -Version $DeployedVersionText

    if ($DeployedVersionText -ne $PackageVersionText) {

        throw (
            'Deployed ProfMig version does not match package version. ' +
            "Expected: $PackageVersionText, " +
            "actual: $DeployedVersionText"
        )
    }

    # -------------------------------------------------------------------------
    # Commit deployment
    #
    # From this point onward the new installation is considered valid.
    # Failure to clean the rollback directory must not cause the valid new
    # installation to be replaced again.
    # -------------------------------------------------------------------------

    $DeploymentCommitted = $true

    # -------------------------------------------------------------------------
    # Remove rollback installation
    # -------------------------------------------------------------------------

    if (
        $RollbackPath -and
        (Test-Path -LiteralPath $RollbackPath)
    ) {

        try {

            Remove-Item `
                -LiteralPath $RollbackPath `
                -Recurse `
                -Force

            $RollbackPath = $null
            $PreviousInstallationMoved = $false
        }
        catch {

            Write-Warning (
                'ProfMig was deployed successfully, but the rollback ' +
                'directory could not be removed: ' +
                $RollbackPath
            )
        }
    }

    Write-Host ''
    Write-Host 'ProfMig deployment completed successfully.'
    Write-Host "Version:  $DeployedVersionText"
    Write-Host "Location: $InstallPath"

    exit $ExitCodes.Success
}
catch {

    $DeploymentError = $_

    [Console]::Error.WriteLine(
        'ProfMig deployment failed: {0}' -f
            $DeploymentError.Exception.Message
    )

    # -------------------------------------------------------------------------
    # Roll back failed deployment
    #
    # Rollback is only performed before the deployment commit point.
    # -------------------------------------------------------------------------

    if (
        -not $DeploymentCommitted -and
        $PreviousInstallationMoved -and
        $RollbackPath -and
        (Test-Path -LiteralPath $RollbackPath)
    ) {

        Write-Warning (
            'Deployment failed after the existing installation ' +
            'was preserved. Attempting rollback.'
        )

        try {

            if (
                $NewInstallationActivated -and
                (Test-Path -LiteralPath $InstallPath)
            ) {

                Remove-Item `
                    -LiteralPath $InstallPath `
                    -Recurse `
                    -Force
            }

            Move-Item `
                -LiteralPath $RollbackPath `
                -Destination $InstallPath

            $RollbackPath = $null
            $PreviousInstallationMoved = $false
            $NewInstallationActivated = $false

            Write-Warning (
                'Previous ProfMig installation restored successfully.'
            )
        }
        catch {

            [Console]::Error.WriteLine(
                'Automatic rollback failed: {0}' -f
                    $_.Exception.Message
            )

            if ($RollbackPath) {

                [Console]::Error.WriteLine(
                    (
                        'Rollback installation may still be available at: ' +
                        '{0}'
                    ) -f $RollbackPath
                )
            }
        }
    }

    exit $ExitCodes.GeneralFailure
}
finally {

    # -------------------------------------------------------------------------
    # Remove abandoned staging directory
    # -------------------------------------------------------------------------

    if (
        $StagingPath -and
        (Test-Path -LiteralPath $StagingPath)
    ) {

        try {

            Remove-Item `
                -LiteralPath $StagingPath `
                -Recurse `
                -Force
        }
        catch {

            Write-Warning (
                'Unable to remove deployment staging directory: ' +
                $StagingPath
            )
        }
    }
}