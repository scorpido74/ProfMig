<#
.SYNOPSIS
    Detects an installed ProfMig version for Microsoft Intune.

.DESCRIPTION
    Validates that ProfMig is installed and compares the installed version
    from ProfMig.Build.psd1 with the version expected by the Intune package.

    The script is intended for use as a Microsoft Intune Win32 application
    custom detection script.

    Detection succeeds only when:
    - The ProfMig installation directory exists.
    - ProfMig.Build.psd1 exists.
    - The installed metadata identifies ProfMig.
    - The installed version exactly matches ExpectedVersion.

.PARAMETER ExpectedVersion
    ProfMig version expected by the Intune application.

.PARAMETER InstallPath
    ProfMig installation directory.

    Default:
    C:\Program Files\ProfMig

.EXITCODES
    0 - Expected ProfMig version detected
    1 - ProfMig missing, invalid, or different version
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ExpectedVersion,

    [string]$InstallPath = (Join-Path $env:ProgramFiles 'ProfMig')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {

    if (-not (Test-Path -LiteralPath $InstallPath -PathType Container)) {
        exit 1
    }

    $MetadataPath = Join-Path `
        $InstallPath `
        'ProfMig.Build.psd1'

    if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        exit 1
    }

    $Metadata = Import-PowerShellDataFile `
        -LiteralPath $MetadataPath

    if (
        -not $Metadata.ContainsKey('Name') -or
        [string]$Metadata.Name -ne 'ProfMig'
    ) {
        exit 1
    }

    if (-not $Metadata.ContainsKey('Version')) {
        exit 1
    }

    $InstalledVersion = [string]$Metadata.Version

    if ([string]::IsNullOrWhiteSpace($InstalledVersion)) {
        exit 1
    }

    if ($InstalledVersion -ne $ExpectedVersion) {
        exit 1
    }

    Write-Output (
        "ProfMig $InstalledVersion detected at $InstallPath"
    )

    exit 0
}
catch {

    Write-Error (
        'ProfMig detection failed: ' +
        $_.Exception.Message
    )

    exit 1
}
