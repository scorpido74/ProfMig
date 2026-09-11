<#
.SYNOPSIS
    Runs an installed ProfMig runtime for remote management scenarios.

.DESCRIPTION
    Provides a vendor-neutral wrapper for unattended ProfMig migrations
    initiated by RMM platforms, endpoint management systems, software
    distribution platforms, scheduled tasks, or other remote management
    tooling.

    This wrapper is intentionally thin.

    It does not implement migration logic, profile validation, application
    migration, logging, reporting, or ProfMig error handling itself.
    Those responsibilities remain inside the ProfMig runtime.

    The wrapper performs only the following tasks:

    - Resolves the installed ProfMig runtime.
    - Resolves the native 64-bit Windows PowerShell executable.
    - Handles 32-bit management processes on 64-bit Windows.
    - Starts ProfMig in silent and non-interactive mode.
    - Supplies persistent log and report directories.
    - Forwards migration parameters to ProfMig.
    - Returns the ProfMig process exit code unchanged.

    On a 64-bit Windows operating system, a 32-bit management agent sees
    $env:ProgramFiles as "Program Files (x86)". The wrapper therefore uses
    $env:ProgramW6432 when available to resolve the native Program Files
    directory.

    When the wrapper itself is running in a 32-bit process, Sysnative is used
    to start native 64-bit Windows PowerShell and bypass WOW64 file-system
    redirection.

.PARAMETER InstallPath
    Installed ProfMig runtime directory.

    When omitted, the wrapper resolves the native Program Files directory and
    uses:

        C:\Program Files\ProfMig

    An alternative installation directory may be supplied explicitly.

.PARAMETER SourceSid
    SID of the source Windows user profile.

    SourceSid and DestinationSid must be supplied together when SID-based
    migration is used.

.PARAMETER DestinationSid
    SID of the destination Windows user profile.

    SourceSid and DestinationSid must be supplied together when SID-based
    migration is used.

.PARAMETER SourceProfilePath
    Path of the source Windows user profile.

    SourceProfilePath and DestinationProfilePath must be supplied together
    when path-based migration is used.

.PARAMETER DestinationProfilePath
    Path of the destination Windows user profile.

    SourceProfilePath and DestinationProfilePath must be supplied together
    when path-based migration is used.

.PARAMETER MigrationProfile
    Optional ProfMig migration profile.

    Examples:

        Standard
        Minimal

    When omitted, ProfMig uses its configured default migration behaviour.

.PARAMETER ConfigPath
    Optional external ProfMig configuration file.

    For remote deployment scenarios, an absolute path is recommended.

    Configuration validation remains the responsibility of ProfMig.

.PARAMETER SkipApplications
    Disables application migration.

    The parameter is forwarded directly to ProfMig.

.EXAMPLE
    .\Invoke-ProfMigRemote.ps1 `
        -SourceSid 'S-1-5-21-1000-1000-1000-1001' `
        -DestinationSid 'S-1-5-21-1000-1000-1000-1002'

    Runs a silent SID-based migration using the default ProfMig installation.

.EXAMPLE
    .\Invoke-ProfMigRemote.ps1 `
        -SourceProfilePath 'C:\Users\UserA' `
        -DestinationProfilePath 'C:\Users\UserB' `
        -MigrationProfile Minimal

    Runs a silent path-based migration using the Minimal migration profile.

.EXAMPLE
    .\Invoke-ProfMigRemote.ps1 `
        -SourceSid 'S-1-5-21-1000-1000-1000-1001' `
        -DestinationSid 'S-1-5-21-1000-1000-1000-1002' `
        -ConfigPath 'C:\ProgramData\ProfMig\Config\RemoteConfig.psd1'

    Runs ProfMig using an externally supplied configuration file.

.EXAMPLE
    .\Invoke-ProfMigRemote.ps1 `
        -InstallPath 'D:\Applications\ProfMig' `
        -SourceSid 'S-1-5-21-1000-1000-1000-1001' `
        -DestinationSid 'S-1-5-21-1000-1000-1000-1002'

    Runs ProfMig from a non-default installation directory.

.NOTES
    Sprint:
        5.6 - RMM & Remote Deployment

    Design:
        Vendor-neutral remote execution example.

    Security:
        This wrapper does not bypass ProfMig validation, security checks,
        permission handling, or migration verification.

        No credentials are stored or processed by this wrapper.

    Exit codes:
        ProfMig migration exit codes are returned unchanged to the calling
        process.

        0  = Success
        1  = Success with warnings
        2  = Migration failed
        3  = Configuration error
        4  = Validation error
        5  = Permission error
        6  = Insufficient storage
        7  = Verification error
        8  = Application migration error
        99 = Unexpected error

        Exit code 99 is also used when this wrapper cannot locate the ProfMig
        runtime or the required Windows PowerShell executable.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$InstallPath,

    [Parameter()]
    [string]$SourceSid,

    [Parameter()]
    [string]$DestinationSid,

    [Parameter()]
    [string]$SourceProfilePath,

    [Parameter()]
    [string]$DestinationProfilePath,

    [Parameter()]
    [string]$MigrationProfile,

    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$SkipApplications
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


# -----------------------------------------------------------------------------
# Resolve default installation path
#
# A 32-bit management process on a 64-bit Windows operating system sees
# $env:ProgramFiles as "Program Files (x86)".
#
# $env:ProgramW6432 points to the native 64-bit Program Files directory and
# therefore matches the default ProfMig deployment location.
#
# An explicitly supplied InstallPath always takes precedence.
# -----------------------------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($InstallPath)) {

    $ProgramFilesPath = $null

    if (
        [Environment]::Is64BitOperatingSystem -and
        -not [string]::IsNullOrWhiteSpace($env:ProgramW6432)
    ) {

        $ProgramFilesPath = $env:ProgramW6432
    }
    elseif (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {

        $ProgramFilesPath = $env:ProgramFiles
    }

    if ([string]::IsNullOrWhiteSpace($ProgramFilesPath)) {

        [Console]::Error.WriteLine(
            'Unable to resolve the Windows Program Files directory.'
        )

        exit 99
    }

    $InstallPath = Join-Path `
        $ProgramFilesPath `
        'ProfMig'
}


# -----------------------------------------------------------------------------
# Normalize installation path
# -----------------------------------------------------------------------------

try {

    $InstallPath = [System.IO.Path]::GetFullPath(
        $InstallPath
    )
}
catch {

    [Console]::Error.WriteLine(
        "Invalid ProfMig installation path: $InstallPath"
    )

    exit 99
}


# -----------------------------------------------------------------------------
# Resolve installed ProfMig runtime
# -----------------------------------------------------------------------------

$ProfMigPath = Join-Path `
    $InstallPath `
    'src\ProfMig.ps1'

if (
    -not (
        Test-Path `
            -LiteralPath $ProfMigPath `
            -PathType Leaf
    )
) {

    [Console]::Error.WriteLine(
        "ProfMig runtime was not found: $ProfMigPath"
    )

    exit 99
}


# -----------------------------------------------------------------------------
# Resolve native 64-bit Windows PowerShell
#
# ProfMig requires a 64-bit PowerShell process.
#
# When this wrapper is started by a 32-bit management agent on 64-bit Windows,
# normal access to System32 is redirected to SysWOW64. The Sysnative virtual
# directory bypasses this redirection and starts native 64-bit PowerShell.
# -----------------------------------------------------------------------------

if (-not [Environment]::Is64BitOperatingSystem) {

    [Console]::Error.WriteLine(
        'ProfMig requires a 64-bit Windows operating system.'
    )

    exit 99
}

if ([Environment]::Is64BitProcess) {

    $PowerShellPath = Join-Path `
        $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
}
else {

    $PowerShellPath = Join-Path `
        $env:SystemRoot `
        'Sysnative\WindowsPowerShell\v1.0\powershell.exe'
}

if (
    -not (
        Test-Path `
            -LiteralPath $PowerShellPath `
            -PathType Leaf
    )
) {

    [Console]::Error.WriteLine(
        "64-bit Windows PowerShell was not found: $PowerShellPath"
    )

    exit 99
}


# -----------------------------------------------------------------------------
# Resolve persistent runtime output directories
#
# Deploy-ProfMig.ps1 creates and preserves the Logs and Reports directories
# inside the installed ProfMig runtime.
#
# The wrapper passes these locations explicitly so remote execution does not
# depend on the current working directory or user profile.
# -----------------------------------------------------------------------------

$LogPath = Join-Path `
    $InstallPath `
    'Logs'

$ReportPath = Join-Path `
    $InstallPath `
    'Reports'


# -----------------------------------------------------------------------------
# Build base ProfMig command line
#
# -NoProfile prevents user-specific PowerShell profiles from affecting remote
# execution.
#
# -NonInteractive prevents PowerShell itself from requesting interactive input.
#
# -Silent ensures ProfMig uses its unattended migration path.
# -----------------------------------------------------------------------------

$ProfMigArguments = @(
    '-NoProfile'
    '-NonInteractive'
    '-ExecutionPolicy'
    'Bypass'
    '-File'
    $ProfMigPath
    '-Silent'
    '-LogPath'
    $LogPath
    '-ReportPath'
    $ReportPath
)


# -----------------------------------------------------------------------------
# Forward source and destination identifiers
#
# Parameter combination validation deliberately remains inside ProfMig.
#
# This ensures local, scripted, Intune and generic remote execution all use
# the same validation rules and exit-code contract.
# -----------------------------------------------------------------------------

if (-not [string]::IsNullOrWhiteSpace($SourceSid)) {

    $ProfMigArguments += @(
        '-SourceSid'
        $SourceSid
    )
}

if (-not [string]::IsNullOrWhiteSpace($DestinationSid)) {

    $ProfMigArguments += @(
        '-DestinationSid'
        $DestinationSid
    )
}

if (-not [string]::IsNullOrWhiteSpace($SourceProfilePath)) {

    $ProfMigArguments += @(
        '-SourceProfilePath'
        $SourceProfilePath
    )
}

if (-not [string]::IsNullOrWhiteSpace($DestinationProfilePath)) {

    $ProfMigArguments += @(
        '-DestinationProfilePath'
        $DestinationProfilePath
    )
}


# -----------------------------------------------------------------------------
# Forward optional migration parameters
# -----------------------------------------------------------------------------

if (-not [string]::IsNullOrWhiteSpace($MigrationProfile)) {

    $ProfMigArguments += @(
        '-MigrationProfile'
        $MigrationProfile
    )
}

if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {

    try {

        $ResolvedConfigPath = [System.IO.Path]::GetFullPath(
            $ConfigPath
        )
    }
    catch {

        [Console]::Error.WriteLine(
            "Invalid ProfMig configuration path: $ConfigPath"
        )

        exit 99
    }

    $ProfMigArguments += @(
        '-ConfigPath'
        $ResolvedConfigPath
    )
}

if ($SkipApplications) {

    $ProfMigArguments += '-SkipApplications'
}


# -----------------------------------------------------------------------------
# Execute ProfMig
#
# ProfMig remains responsible for:
#
# - Configuration validation
# - Profile validation
# - Storage validation
# - Permission handling
# - Migration execution
# - Application migration
# - Verification
# - Logging
# - Report generation
# - Structured error handling
# - Migration exit-code selection
#
# The wrapper intentionally does not duplicate any of these responsibilities.
# -----------------------------------------------------------------------------

try {

    & $PowerShellPath @ProfMigArguments

    $ProfMigExitCode = $LASTEXITCODE
}
catch {

    [Console]::Error.WriteLine(
        "Unable to start ProfMig: $($_.Exception.Message)"
    )

    exit 99
}


# -----------------------------------------------------------------------------
# Validate child process result
#
# An external executable should populate $LASTEXITCODE. This defensive check
# prevents an undefined result from being interpreted as a successful remote
# migration.
# -----------------------------------------------------------------------------

if ($null -eq $ProfMigExitCode) {

    [Console]::Error.WriteLine(
        'ProfMig did not return a process exit code.'
    )

    exit 99
}


# -----------------------------------------------------------------------------
# Return ProfMig result unchanged
#
# The calling RMM or remote management platform can interpret the documented
# ProfMig migration exit code directly.
#
# No translation is performed here.
# -----------------------------------------------------------------------------

exit $ProfMigExitCode