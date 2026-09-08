<#
.SYNOPSIS
    Regression tests for ProfMig versioning and build information.

.DESCRIPTION
    Verifies the ProfMig versioning strategy introduced in Sprint 5.4.

    Tests include:
    - Central application version configuration
    - Semantic Versioning validation
    - Pre-release version support
    - Command-line version output
    - Migration reporting version/build information
    - Package build metadata
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$ConfigurationPath = Join-Path $ProjectRoot 'src\Config.psd1'
$ConfigurationModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Configuration.psm1'

$ProfMigPath = Join-Path $ProjectRoot 'src\ProfMig.ps1'

$ReportingModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Reporting.psm1'

$LoggingModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Logging.psm1'

$PackagingPath = Join-Path $ProjectRoot 'build\New-ProfMigPackage.ps1'

$PassedCount = 0
$FailedCount = 0


function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [string]$Details
    )

    if ($Passed) {

        $script:PassedCount++

        Write-Host (
            '[PASS] {0}' -f $Name
        ) -ForegroundColor Green

        return
    }

    $script:FailedCount++

    if ([string]::IsNullOrWhiteSpace($Details)) {

        Write-Host (
            '[FAIL] {0}' -f $Name
        ) -ForegroundColor Red
    }
    else {

        Write-Host (
            '[FAIL] {0} - {1}' -f
            $Name,
            $Details
        ) -ForegroundColor Red
    }
}


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Versioning Tests'
Write-Host '========================================'


# ---------------------------------------------------------------------------
# Test central version configuration
# ---------------------------------------------------------------------------

$Configuration = Import-PowerShellDataFile `
    -LiteralPath $ConfigurationPath

Write-TestResult `
    -Name 'Application version is defined in Config.psd1' `
    -Passed (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Configuration.Application.Version
        )
    )

Write-TestResult `
    -Name 'Application build is defined in Config.psd1' `
    -Passed (
        -not [string]::IsNullOrWhiteSpace(
            [string]$Configuration.Application.Build
        )
    )


# ---------------------------------------------------------------------------
# Test Semantic Versioning
# ---------------------------------------------------------------------------

Import-Module `
    $ConfigurationModulePath `
    -Force

$ValidVersions = @(
    '0.2.0'
    '1.0.0'
    '1.0.0-alpha'
    '1.0.0-beta'
    '1.0.0-rc1'
    '1.0.0-rc.1'
)

foreach ($Version in $ValidVersions) {

    $TestConfiguration = $Configuration.Clone()
    $TestConfiguration.Application = $Configuration.Application.Clone()
    $TestConfiguration.Application.Version = $Version

    try {

        $null = Test-ProfMigConfigurationSchema `
            -Configuration $TestConfiguration

        Write-TestResult `
            -Name "Valid version accepted: $Version" `
            -Passed $true
    }
    catch {

        Write-TestResult `
            -Name "Valid version accepted: $Version" `
            -Passed $false `
            -Details $_.Exception.Message
    }
}


$InvalidVersions = @(
    '1.0'
    'v1.0.0'
    '1'
    'abc'
    ''
)

foreach ($Version in $InvalidVersions) {

    $TestConfiguration = $Configuration.Clone()
    $TestConfiguration.Application = $Configuration.Application.Clone()
    $TestConfiguration.Application.Version = $Version

    try {

        $null = Test-ProfMigConfigurationSchema `
            -Configuration $TestConfiguration

        Write-TestResult `
            -Name "Invalid version rejected: '$Version'" `
            -Passed $false `
            -Details 'Version was unexpectedly accepted.'
    }
    catch {

        Write-TestResult `
            -Name "Invalid version rejected: '$Version'" `
            -Passed $true
    }
}


# ---------------------------------------------------------------------------
# Test command-line version output
# ---------------------------------------------------------------------------

$ExpectedVersion = [string]$Configuration.Application.Version
$ExpectedBuild   = [string]$Configuration.Application.Build

$CliOutput = @(
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ProfMigPath `
        -Version 2>&1
)

$CliExitCode = $LASTEXITCODE
$CliText = $CliOutput -join [Environment]::NewLine

Write-TestResult `
    -Name 'CLI -Version reports configured version' `
    -Passed (
        $CliText -match (
            'ProfMig\s+' +
            [regex]::Escape($ExpectedVersion)
        )
    ) `
    -Details $CliText

Write-TestResult `
    -Name 'CLI -Version reports configured build' `
    -Passed (
        $CliText -match (
            'Build:\s*' +
            [regex]::Escape($ExpectedBuild)
        )
    ) `
    -Details $CliText

Write-TestResult `
    -Name 'CLI -Version exits successfully' `
    -Passed ($CliExitCode -eq 0) `
    -Details "Exit code: $CliExitCode"


$SilentVersionOutput = @(
    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $ProfMigPath `
        -Silent `
        -Version 2>&1
)

$SilentVersionExitCode = $LASTEXITCODE
$SilentVersionText = $SilentVersionOutput -join [Environment]::NewLine

Write-TestResult `
    -Name 'Silent CLI -Version reports configured version' `
    -Passed (
        $SilentVersionText -match (
            'ProfMig\s+' +
            [regex]::Escape($ExpectedVersion)
        )
    ) `
    -Details $SilentVersionText

Write-TestResult `
    -Name 'Silent CLI -Version exits successfully' `
    -Passed ($SilentVersionExitCode -eq 0) `
    -Details "Exit code: $SilentVersionExitCode"

# ---------------------------------------------------------------------------
# Test logging version/build information
# ---------------------------------------------------------------------------

Import-Module `
    $LoggingModulePath `
    -Force

$TestLogFolder = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Logging-' + [guid]::NewGuid().ToString('N'))

try {

    $null = New-Item `
        -ItemType Directory `
        -Path $TestLogFolder `
        -Force

    $null = Initialize-Logging `
        -LogFolder $TestLogFolder

    Write-Info (
        'ProfMig version: ' +
        $ExpectedVersion
    )

    Write-Info (
        'ProfMig build: ' +
        $ExpectedBuild
    )

    $LogFiles = @(
        Get-ChildItem `
            -LiteralPath $TestLogFolder `
            -File
    )

    Write-TestResult `
        -Name 'Logging creates a log file' `
        -Passed ($LogFiles.Count -gt 0)

    $LogContent = (
        $LogFiles |
            Get-Content -Raw
    ) -join [Environment]::NewLine

    Write-TestResult `
        -Name 'Log contains configured version' `
        -Passed (
            $LogContent -match (
                'ProfMig version:\s*' +
                [regex]::Escape($ExpectedVersion)
            )
        )

    Write-TestResult `
        -Name 'Log contains configured build' `
        -Passed (
            $LogContent -match (
                'ProfMig build:\s*' +
                [regex]::Escape($ExpectedBuild)
            )
        )
}
finally {

    if (Test-Path -LiteralPath $TestLogFolder) {

        Remove-Item `
            -LiteralPath $TestLogFolder `
            -Recurse `
            -Force
    }
}

# ---------------------------------------------------------------------------
# Test migration report version/build information
# ---------------------------------------------------------------------------

Import-Module `
    $ReportingModulePath `
    -Force

$CopyResult = [pscustomobject]@{
    SourceProfile      = 'C:\Users\OldUser'
    DestinationProfile = 'C:\Users\NewUser'
    StartedAt          = Get-Date
    CompletedAt        = Get-Date
    Duration           = [timespan]::Zero
    Status             = 'Success'

    Components = @(
        [pscustomobject]@{
            Component           = 'Documents'
            FilesCopied         = 1
            BytesCopied         = 100
            Status              = 'Success'
            VerificationResults = @()
        }
    )

    Totals = [pscustomobject]@{
        FilesSelected        = 1
        FilesCopied          = 1
        FilesSkipped         = 0
        FilesExcluded        = 0
        FilesFailed          = 0
        BytesCopied          = 100
        FilesVerified        = 1
        BytesVerified        = 100
        VerificationFailures = 0
        VerificationLevel    = 'Standard'
        HashAlgorithm        = 'Not configured'
    }

    SkippedItems  = @()
    ExcludedItems = @()
    Errors        = @()
}

$MigrationResult = ConvertTo-ProfMigMigrationResult `
    -CopyResult $CopyResult `
    -ProfMigVersion $ExpectedVersion `
    -ProfMigBuild $ExpectedBuild

Write-TestResult `
    -Name 'Migration result contains configured version' `
    -Passed (
        $MigrationResult.ProfMigVersion -eq $ExpectedVersion
    ) `
    -Details (
        'Actual version: ' +
        [string]$MigrationResult.ProfMigVersion
    )

Write-TestResult `
    -Name 'Migration result contains configured build' `
    -Passed (
        $MigrationResult.ProfMigBuild -eq $ExpectedBuild
    ) `
    -Details (
        'Actual build: ' +
        [string]$MigrationResult.ProfMigBuild
    )

# ---------------------------------------------------------------------------
# Test physical migration report
# ---------------------------------------------------------------------------

$TestReportFolder = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Versioning-' + [guid]::NewGuid().ToString('N'))

try {

    $null = New-Item `
        -ItemType Directory `
        -Path $TestReportFolder `
        -Force

    $ReportPath = New-ProfMigMigrationReport `
        -MigrationResult $MigrationResult `
        -ReportFolder $TestReportFolder

    Write-TestResult `
        -Name 'Migration report file is created' `
        -Passed (
            Test-Path -LiteralPath $ReportPath
        ) `
        -Details $ReportPath

    $ReportContent = Get-Content `
        -LiteralPath $ReportPath `
        -Raw

    Write-TestResult `
        -Name 'Migration report contains configured version' `
        -Passed (
            $ReportContent -match (
                'ProfMig version\s*:\s*' +
                [regex]::Escape($ExpectedVersion)
            )
        )

    Write-TestResult `
        -Name 'Migration report contains configured build' `
        -Passed (
            $ReportContent -match (
                'ProfMig build\s*:\s*' +
                [regex]::Escape($ExpectedBuild)
            )
        )
}
finally {

    if (Test-Path -LiteralPath $TestReportFolder) {

        Remove-Item `
            -LiteralPath $TestReportFolder `
            -Recurse `
            -Force
    }
}

# ---------------------------------------------------------------------------
# Test package build metadata
# ---------------------------------------------------------------------------

$TestPackageRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Package-' + [guid]::NewGuid().ToString('N'))

try {

    $PackageOutput = @(
        & powershell.exe `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $PackagingPath `
            -OutputPath $TestPackageRoot 2>&1
    )

    $PackageExitCode = $LASTEXITCODE
    $PackageOutputText = $PackageOutput -join [Environment]::NewLine

    Write-TestResult `
        -Name 'Runtime package builds successfully' `
        -Passed ($PackageExitCode -eq 0) `
        -Details $PackageOutputText

    $BuildMetadataPath = Join-Path `
        $TestPackageRoot `
        'ProfMig.Build.psd1'

    Write-TestResult `
        -Name 'Package contains ProfMig.Build.psd1' `
        -Passed (
            Test-Path -LiteralPath $BuildMetadataPath
        ) `
        -Details $BuildMetadataPath

    if (Test-Path -LiteralPath $BuildMetadataPath) {

        $BuildMetadata = Import-PowerShellDataFile `
            -LiteralPath $BuildMetadataPath

        Write-TestResult `
            -Name 'Package metadata contains configured version' `
            -Passed (
                [string]$BuildMetadata.Version -eq $ExpectedVersion
            ) `
            -Details (
                'Actual version: ' +
                [string]$BuildMetadata.Version
            )

        Write-TestResult `
            -Name 'Package metadata contains configured build' `
            -Passed (
                [string]$BuildMetadata.Build -eq $ExpectedBuild
            ) `
            -Details (
                'Actual build: ' +
                [string]$BuildMetadata.Build
            )

        Write-TestResult `
            -Name 'Package metadata contains Git commit' `
            -Passed (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$BuildMetadata.GitCommit
                )
            ) `
            -Details (
                'Git commit: ' +
                [string]$BuildMetadata.GitCommit
            )

        Write-TestResult `
            -Name 'Package metadata contains Git working tree state' `
            -Passed (
                $BuildMetadata.ContainsKey('GitDirty') -and
                $null -ne $BuildMetadata.GitDirty
            ) `
            -Details (
                'Git dirty: ' +
                [string]$BuildMetadata.GitDirty
            )

        Write-TestResult `
            -Name 'Package metadata contains build timestamp' `
            -Passed (
                -not [string]::IsNullOrWhiteSpace(
                    [string]$BuildMetadata.BuiltAt
                )
            ) `
            -Details (
                'BuiltAt: ' +
                [string]$BuildMetadata.BuiltAt
            )
    }
}
finally {

    if (Test-Path -LiteralPath $TestPackageRoot) {

        Remove-Item `
            -LiteralPath $TestPackageRoot `
            -Recurse `
            -Force
    }
}

# ---------------------------------------------------------------------------
# Test summary
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '========================================'
Write-Host 'Versioning Test Summary'
Write-Host '========================================'
Write-Host "Passed: $PassedCount"
Write-Host "Failed: $FailedCount"
Write-Host ''

if ($FailedCount -gt 0) {
    exit 1
}

exit 0