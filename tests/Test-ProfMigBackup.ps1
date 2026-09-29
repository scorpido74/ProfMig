$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot

$ModulePath = Join-Path `
    $ProjectRoot `
    'src\Modules\ProfMig.Backup.psm1'

Import-Module $ModulePath -Force

$TestRoot = Join-Path `
    $env:TEMP `
    'ProfMig-Backup-Test'

if (Test-Path -LiteralPath $TestRoot) {
    Remove-Item `
        -LiteralPath $TestRoot `
        -Recurse `
        -Force
}

New-Item `
    -Path $TestRoot `
    -ItemType Directory `
    -Force | Out-Null

try {
    Write-Host '=== ProfMig Backup Tests ==='

    #
    # Test 1 - OneDrive detection
    #

    $ProfilePath = Join-Path $TestRoot 'TestUser'

    $ExpectedOneDrivePath = Join-Path `
        $ProfilePath `
        'OneDrive - Infinigate Holding GmbH'

    New-Item `
        -Path $ExpectedOneDrivePath `
        -ItemType Directory `
        -Force | Out-Null

    $ActualOneDrivePath = Get-ProfMigOneDrivePath `
        -ProfilePath $ProfilePath

    if ($ActualOneDrivePath -ne $ExpectedOneDrivePath) {
        throw 'OneDrive path detection failed.'
    }

    Write-Host '[PASS] OneDrive path detected'

    #
    # Test 2 - Missing OneDrive
    #

    $MissingProfile = Join-Path `
        $TestRoot `
        'MissingOneDriveUser'

    New-Item `
        -Path $MissingProfile `
        -ItemType Directory `
        -Force | Out-Null

    $MissingOneDriveFailed = $false

    try {
        Get-ProfMigOneDrivePath `
            -ProfilePath $MissingProfile | Out-Null
    }
    catch {
        $MissingOneDriveFailed = $true
    }

    if (-not $MissingOneDriveFailed) {
        throw 'Missing OneDrive folder was not detected.'
    }

    Write-Host '[PASS] Missing OneDrive folder detected'

    #
    # Test 3 - Staging folder
    #

    $Timestamp = [datetime]'2026-09-29T08:15:30'

    $StagingRoot = Join-Path `
        $TestRoot `
        'Staging'

    $StagingPath = New-ProfMigBackupStaging `
        -RootPath $StagingRoot `
        -ComputerName 'TESTPC01' `
        -Timestamp $Timestamp

    $ExpectedStagingPath = Join-Path `
        $StagingRoot `
        'TESTPC01_2026-09-29_081530'

    if ($StagingPath -ne $ExpectedStagingPath) {
        throw 'Unexpected staging path.'
    }

    if (-not (Test-Path -LiteralPath $StagingPath)) {
        throw 'Staging directory was not created.'
    }

    Write-Host '[PASS] Backup staging created'

    #
    # Test 4 - OneDrive backup destination
    #

    $BackupPath = Get-ProfMigOneDriveBackupPath `
        -OneDrivePath $ExpectedOneDrivePath `
        -ComputerName 'TESTPC01' `
        -Timestamp $Timestamp

    $ExpectedBackupPath = Join-Path `
        $ExpectedOneDrivePath `
        'ProfMig\Backup\TESTPC01_2026-09-29_081530'

    if ($BackupPath -ne $ExpectedBackupPath) {
        throw 'Unexpected OneDrive backup destination.'
    }

    Write-Host '[PASS] OneDrive backup destination generated'

    Write-Host ''
    Write-Host 'All ProfMig Backup tests passed.'
}
finally {
    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item `
            -LiteralPath $TestRoot `
            -Recurse `
            -Force
    }
}