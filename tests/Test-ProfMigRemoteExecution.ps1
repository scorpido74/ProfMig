<#
.SYNOPSIS
    Validates ProfMig remote execution requirements.

.DESCRIPTION
    Provides regression tests for execution requirements introduced
    for Sprint 5.6 - RMM and Remote Deployment.

    These tests remain vendor-neutral and validate the ProfMig runtime
    rather than a specific remote management platform.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$CoreModule = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Core.psm1'

Write-Host ''
Write-Host '=== ProfMig Remote Execution Tests ==='
Write-Host ''

# ---------------------------------------------------------------------------
# Test 1 - Core module exists
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $CoreModule -PathType Leaf)) {
    throw "ProfMig Core module was not found: $CoreModule"
}

Write-Host '[PASS] ProfMig Core module found.'

# ---------------------------------------------------------------------------
# Test 2 - Import Core module
# ---------------------------------------------------------------------------

Import-Module `
    -Name $CoreModule `
    -Force `
    -ErrorAction Stop

Write-Host '[PASS] ProfMig Core module imported.'

# ---------------------------------------------------------------------------
# Test 3 - PowerShell version
# ---------------------------------------------------------------------------

if ($PSVersionTable.PSVersion -lt [Version]'5.1') {
    throw (
        'Test requires PowerShell 5.1 or newer. Current version: ' +
        $PSVersionTable.PSVersion
    )
}

Write-Host (
    '[PASS] PowerShell version: ' +
    $PSVersionTable.PSVersion
)

# ---------------------------------------------------------------------------
# Test 4 - 64-bit operating system
# ---------------------------------------------------------------------------

if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'ProfMig requires a 64-bit Windows operating system.'
}

Write-Host '[PASS] 64-bit Windows detected.'

# ---------------------------------------------------------------------------
# Test 5 - 64-bit PowerShell process
# ---------------------------------------------------------------------------

if (-not [Environment]::Is64BitProcess) {
    throw 'ProfMig remote execution requires 64-bit PowerShell.'
}

Write-Host '[PASS] 64-bit PowerShell process detected.'

# ---------------------------------------------------------------------------
# Test 6 - ProfMig environment validation
# ---------------------------------------------------------------------------

Test-ProfMigEnvironment

Write-Host '[PASS] Test-ProfMigEnvironment accepted the runtime.'

# ---------------------------------------------------------------------------
# Test 7 - Profile inventory
# ---------------------------------------------------------------------------

$InventoryModule = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Inventory.psm1'

$ConfigPath = Join-Path `
    $ProjectRoot `
    'src\Config.psd1'

if (-not (Test-Path -LiteralPath $InventoryModule -PathType Leaf)) {
    throw "ProfMig Inventory module was not found: $InventoryModule"
}

Import-Module `
    -Name $InventoryModule `
    -Force `
    -ErrorAction Stop

$Config = Import-PowerShellDataFile `
    -Path $ConfigPath

$Profiles = @(
    Get-UserProfiles `
        -ExcludedProfiles $Config.ExcludedProfiles
)

if ($Profiles.Count -eq 0) {
    throw 'ProfMig profile inventory returned no user profiles.'
}

$SystemProfiles = @(
    $Profiles | Where-Object {
        $_.ProfilePath -match '\\systemprofile$' -or
        $_.ProfilePath -match '\\LocalService$' -or
        $_.ProfilePath -match '\\NetworkService$'
    }
)

if ($SystemProfiles.Count -gt 0) {
    throw 'ProfMig profile inventory returned a SYSTEM/service profile.'
}

Write-Host (
    '[PASS] Profile inventory completed. ' +
    "$($Profiles.Count) user profile(s) found."
)

Write-Host '[PASS] SYSTEM/service profiles are excluded.'

# ---------------------------------------------------------------------------
# Execution context information
# ---------------------------------------------------------------------------

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()

Write-Host ''
Write-Host 'Execution context:'
Write-Host "  Identity       : $($identity.Name)"
Write-Host "  PowerShell     : $($PSVersionTable.PSVersion)"
Write-Host "  64-bit OS      : $([Environment]::Is64BitOperatingSystem)"
Write-Host "  64-bit process : $([Environment]::Is64BitProcess)"
Write-Host "  Working dir    : $(Get-Location)"
Write-Host "  USERPROFILE    : $env:USERPROFILE"

Write-Host ''
Write-Host 'All ProfMig remote execution tests passed.'
Write-Host ''

exit 0