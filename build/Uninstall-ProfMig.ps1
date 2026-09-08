<#
.SYNOPSIS
    Uninstalls ProfMig from a Windows system.

.DESCRIPTION
    Removes an installed ProfMig runtime while preserving persistent runtime
    data by default.

    The following directories are preserved unless -RemoveData is specified:
    - Logs
    - Reports
    - Backup

    The script is intended for interactive administration as well as
    unattended deployment through RMM or software-distribution systems.

    Before removing application files, the target directory is validated as
    a ProfMig installation.

.PARAMETER InstallPath
    Path containing the installed ProfMig runtime.

    Default:
    C:\Program Files\ProfMig

.PARAMETER RemoveData
    Also removes persistent ProfMig runtime data, including Logs, Reports
    and Backup.

.EXAMPLE
    .\Uninstall-ProfMig.ps1

    Removes the ProfMig application while preserving persistent data.

.EXAMPLE
    .\Uninstall-ProfMig.ps1 -RemoveData

    Completely removes ProfMig, including persistent runtime data.

.EXAMPLE
    .\Uninstall-ProfMig.ps1 `
        -InstallPath 'D:\Applications\ProfMig'

    Removes ProfMig from an alternate installation path.
#>

[CmdletBinding()]
param (
    [string]$InstallPath = (Join-Path $env:ProgramFiles 'ProfMig'),

    [switch]$RemoveData
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# -----------------------------------------------------------------------------
# Exit codes
# -----------------------------------------------------------------------------

$ExitCodes = @{
    Success             = 0
    GeneralFailure      = 1
    AdministratorNeeded = 2
    InvalidInstallation = 3
}


# -----------------------------------------------------------------------------
# Persistent runtime directories
# -----------------------------------------------------------------------------

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


function Test-ProfMigInstallation {

    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $false
    }

    $MetadataPath = Join-Path `
        $Path `
        'ProfMig.Build.psd1'

    $ApplicationPath = Join-Path `
        $Path `
        'src\ProfMig.ps1'

    if (
        -not (
            Test-Path `
                -LiteralPath $MetadataPath `
                -PathType Leaf
        )
    ) {
        return $false
    }

    if (
        -not (
            Test-Path `
                -LiteralPath $ApplicationPath `
                -PathType Leaf
        )
    ) {
        return $false
    }

    try {

        $Metadata = Import-PowerShellDataFile `
            -LiteralPath $MetadataPath

        if (
            -not $Metadata.ContainsKey('Name') -or
            [string]$Metadata.Name -ne 'ProfMig'
        ) {
            return $false
        }
    }
    catch {
        return $false
    }

    return $true
}


function Remove-ProfMigApplicationFiles {

    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $Items = @(
        Get-ChildItem `
            -LiteralPath $Path `
            -Force
    )

    foreach ($Item in $Items) {

        if (
            -not $RemoveData -and
            $Item.PSIsContainer -and
            $Item.Name -in $PersistentDirectories
        ) {

            Write-Host (
                'Preserving persistent directory: ' +
                $Item.Name
            )

            continue
        }

        Write-Host (
            'Removing: ' +
            $Item.FullName
        )

        Remove-Item `
            -LiteralPath $Item.FullName `
            -Recurse `
            -Force
    }
}


try {

    Write-Host ''
    Write-Host 'ProfMig uninstall'
    Write-Host '================='
    Write-Host ''
    Write-Host "Install path: $InstallPath"

    if ($RemoveData) {
        Write-Host 'Persistent data: remove'
    }
    else {
        Write-Host 'Persistent data: preserve'
    }

    Write-Host ''

    # -------------------------------------------------------------------------
    # Administrator validation
    # -------------------------------------------------------------------------

    if (-not (Test-Administrator)) {

        [Console]::Error.WriteLine(
            'Administrator privileges are required to uninstall ProfMig.'
        )

        exit $ExitCodes.AdministratorNeeded
    }


    # -------------------------------------------------------------------------
    # Nothing installed
    # -------------------------------------------------------------------------

    if (-not (Test-Path -LiteralPath $InstallPath)) {

        Write-Host (
            'ProfMig is not installed at the specified location. ' +
            'No uninstall action is required.'
        )

        exit $ExitCodes.Success
    }


    # -------------------------------------------------------------------------
    # Installation validation
    # -------------------------------------------------------------------------

    if (
        -not (
            Test-ProfMigInstallation `
                -Path $InstallPath
        )
    ) {

        [Console]::Error.WriteLine(
            'The specified directory is not a valid ProfMig installation: ' +
            $InstallPath
        )

        exit $ExitCodes.InvalidInstallation
    }


    # -------------------------------------------------------------------------
    # Read installed version for informational output
    # -------------------------------------------------------------------------

    $MetadataPath = Join-Path `
        $InstallPath `
        'ProfMig.Build.psd1'

    $Metadata = Import-PowerShellDataFile `
        -LiteralPath $MetadataPath

    $InstalledVersion = [string]$Metadata.Version

    Write-Host "Installed version: $InstalledVersion"
    Write-Host ''
    Write-Host 'Removing ProfMig application files...'


    # -------------------------------------------------------------------------
    # Remove application files
    # -------------------------------------------------------------------------

    Remove-ProfMigApplicationFiles `
        -Path $InstallPath


    # -------------------------------------------------------------------------
    # Remove installation directory when appropriate
    # -------------------------------------------------------------------------

    if ($RemoveData) {

        if (Test-Path -LiteralPath $InstallPath) {

            $RemainingItems = @(
                Get-ChildItem `
                    -LiteralPath $InstallPath `
                    -Force
            )

            if ($RemainingItems.Count -eq 0) {

                Remove-Item `
                    -LiteralPath $InstallPath `
                    -Force
            }
        }
    }
    else {

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
    }


    # -------------------------------------------------------------------------
    # Final validation
    # -------------------------------------------------------------------------

    $ApplicationPath = Join-Path `
        $InstallPath `
        'src\ProfMig.ps1'

    $MetadataPath = Join-Path `
        $InstallPath `
        'ProfMig.Build.psd1'

    if (
        (Test-Path -LiteralPath $ApplicationPath) -or
        (Test-Path -LiteralPath $MetadataPath)
    ) {

        throw (
            'ProfMig application files remain after uninstall.'
        )
    }

    if ($RemoveData) {

        if (Test-Path -LiteralPath $InstallPath) {

            $RemainingItems = @(
                Get-ChildItem `
                    -LiteralPath $InstallPath `
                    -Force
            )

            if ($RemainingItems.Count -gt 0) {

                throw (
                    'Files or directories remain after complete uninstall.'
                )
            }

            Remove-Item `
                -LiteralPath $InstallPath `
                -Force
        }
    }


    # -------------------------------------------------------------------------
    # Success
    # -------------------------------------------------------------------------

    Write-Host ''

    if ($RemoveData) {

        Write-Host (
            'ProfMig and all persistent runtime data were removed ' +
            'successfully.'
        )
    }
    else {

        Write-Host 'ProfMig was removed successfully.'
        Write-Host (
            'Logs, reports and backup data were preserved in: ' +
            $InstallPath
        )
    }

    exit $ExitCodes.Success
}
catch {

    [Console]::Error.WriteLine(
        'ProfMig uninstall failed: ' +
        $_.Exception.Message
    )

    exit $ExitCodes.GeneralFailure
}