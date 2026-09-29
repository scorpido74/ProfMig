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

    #
    # Test 5 - Copy backup to OneDrive
    #

    $CopySource = Join-Path $TestRoot 'CopySource'
    $CopyDestination = Join-Path $TestRoot 'CopyDestination'

    New-Item `
        -Path (Join-Path $CopySource 'Documents') `
        -ItemType Directory `
        -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $CopySource 'test.txt') `
        -Value 'ProfMig backup test'

    Set-Content `
        -LiteralPath (Join-Path $CopySource 'Documents\document.txt') `
        -Value 'ProfMig nested backup test'

    Copy-ProfMigBackupToOneDrive `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination | Out-Null

    if (-not (
        Test-Path `
            -LiteralPath (Join-Path $CopyDestination 'test.txt')
    )) {
        throw 'Root backup file was not copied.'
    }

    if (-not (
        Test-Path `
            -LiteralPath (
                Join-Path $CopyDestination 'Documents\document.txt'
            )
    )) {
        throw 'Nested backup file was not copied.'
    }

    Write-Host '[PASS] Backup copied to OneDrive destination'

    #
    # Test 6 - SHA256 verification
    #

    $Verification = Test-ProfMigBackupVerification `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination

    if (-not $Verification.Success) {
        throw "Backup verification failed: $($Verification.Errors -join '; ')"
    }

    if ($Verification.SourceFileCount -ne 2) {
        throw 'Unexpected source file count.'
    }

    Write-Host '[PASS] SHA256 backup verification succeeded'

    #
    # Test 7 - Detect modified destination file
    #

    Set-Content `
        -LiteralPath (Join-Path $CopyDestination 'test.txt') `
        -Value 'Modified after backup'

    $FailedVerification = Test-ProfMigBackupVerification `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination

    if ($FailedVerification.Success) {
        throw 'Modified destination file was not detected.'
    }

    Write-Host '[PASS] Modified backup file detected'

    #
    # Test 8 - Verified transfer with source cleanup
    #

    $TransferSource = Join-Path $TestRoot 'TransferSource'
    $TransferDestination = Join-Path $TestRoot 'TransferDestination'

    New-Item `
        -Path $TransferSource `
        -ItemType Directory `
        -Force | Out-Null

    Set-Content `
        -LiteralPath (Join-Path $TransferSource 'backup.txt') `
        -Value 'ProfMig verified transfer'

    $TransferResult = Invoke-ProfMigOneDriveBackupTransfer `
        -SourcePath $TransferSource `
        -DestinationPath $TransferDestination `
        -CleanupSource

    if (-not $TransferResult.Success) {
        throw 'Verified OneDrive backup transfer failed.'
    }

    if (-not $TransferResult.SourceRemoved) {
        throw 'Source cleanup was not reported.'
    }

    if (Test-Path -LiteralPath $TransferSource) {
        throw 'Staging source still exists after verified cleanup.'
    }

    if (-not (
        Test-Path `
            -LiteralPath (Join-Path $TransferDestination 'backup.txt')
    )) {
        throw 'Verified backup destination file is missing.'
    }

    Write-Host '[PASS] Staging removed after verified backup'

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