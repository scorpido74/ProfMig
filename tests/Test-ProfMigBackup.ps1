$ErrorActionPreference = 'Stop'

# ============================================================================
# ProfMig Backup Tests
# ============================================================================
#
# Tests:
# 1. OneDrive path detection
# 2. Missing OneDrive detection
# 3. Backup staging creation
# 4. OneDrive backup destination generation
# 5. Backup content copy
# 6. SHA256 backup verification
# 7. Modified destination detection
# 8. Verified transfer and staging cleanup
# 9. Reparse point / junction protection
#
# Compatible with Windows PowerShell 5.1.
# ============================================================================


$ProjectRoot = Split-Path `
    -Parent `
    $PSScriptRoot

$ModulePath = Join-Path `
    -Path $ProjectRoot `
    -ChildPath 'src\Modules\ProfMig.Backup.psm1'

Import-Module `
    -Name $ModulePath `
    -Force `
    -ErrorAction Stop


$TestRoot = Join-Path `
    -Path $env:TEMP `
    -ChildPath 'ProfMig-Backup-Test'


if (Test-Path -LiteralPath $TestRoot) {
    Remove-Item `
        -LiteralPath $TestRoot `
        -Recurse `
        -Force `
        -ErrorAction Stop
}


New-Item `
    -Path $TestRoot `
    -ItemType Directory `
    -Force `
    -ErrorAction Stop |
    Out-Null


try {

    Write-Host '=== ProfMig Backup Tests ==='


    # ========================================================================
    # Test 1 - OneDrive path detection
    # ========================================================================

    $ProfilePath = Join-Path `
        -Path $TestRoot `
        -ChildPath 'TestUser'

    $ExpectedOneDrivePath = Join-Path `
        -Path $ProfilePath `
        -ChildPath 'OneDrive - Infinigate Holding GmbH'

    New-Item `
        -Path $ExpectedOneDrivePath `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
        Out-Null

    $ActualOneDrivePath = Get-ProfMigOneDrivePath `
        -ProfilePath $ProfilePath `
        -FolderName 'OneDrive - Infinigate Holding GmbH'

    if ($ActualOneDrivePath -ne $ExpectedOneDrivePath) {
        throw 'OneDrive path detection failed.'
    }

    Write-Host '[PASS] OneDrive path detected'


    # ========================================================================
    # Test 2 - Missing OneDrive folder
    # ========================================================================

    $MissingProfile = Join-Path `
        -Path $TestRoot `
        -ChildPath 'MissingOneDriveUser'

    New-Item `
        -Path $MissingProfile `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
        Out-Null

    $MissingOneDriveDetected = $false

    try {
        Get-ProfMigOneDrivePath `
            -ProfilePath $MissingProfile `
            -FolderName 'OneDrive - Infinigate Holding GmbH' |
            Out-Null
    }
    catch {
        $MissingOneDriveDetected = $true
    }

    if (-not $MissingOneDriveDetected) {
        throw 'Missing OneDrive folder was not detected.'
    }

    Write-Host '[PASS] Missing OneDrive folder detected'


    # ========================================================================
    # Test 3 - Backup staging creation
    # ========================================================================

    $Timestamp = [datetime]'2026-09-29T08:15:30'

    $StagingRoot = Join-Path `
        -Path $TestRoot `
        -ChildPath 'Staging'

    $StagingPath = New-ProfMigBackupStaging `
        -RootPath $StagingRoot `
        -ComputerName 'TESTPC01' `
        -Timestamp $Timestamp

    $ExpectedStagingPath = Join-Path `
        -Path $StagingRoot `
        -ChildPath 'TESTPC01_2026-09-29_081530'

    if ($StagingPath -ne $ExpectedStagingPath) {
        throw (
            'Unexpected staging path. ' +
            "Expected '$ExpectedStagingPath', " +
            "received '$StagingPath'."
        )
    }

    if (-not (
        Test-Path `
            -LiteralPath $StagingPath `
            -PathType Container
    )) {
        throw 'Staging directory was not created.'
    }

    Write-Host '[PASS] Backup staging created'


    # ========================================================================
    # Test 4 - OneDrive backup destination generation
    # ========================================================================

    $BackupPath = Get-ProfMigOneDriveBackupPath `
        -OneDrivePath $ExpectedOneDrivePath `
        -BackupFolder 'ProfMig\Backup' `
        -ComputerName 'TESTPC01' `
        -Timestamp $Timestamp

    $ExpectedBackupPath = Join-Path `
        -Path $ExpectedOneDrivePath `
        -ChildPath 'ProfMig\Backup\TESTPC01_2026-09-29_081530'

    if ($BackupPath -ne $ExpectedBackupPath) {
        throw (
            'Unexpected OneDrive backup destination. ' +
            "Expected '$ExpectedBackupPath', " +
            "received '$BackupPath'."
        )
    }

    Write-Host '[PASS] OneDrive backup destination generated'


    # ========================================================================
    # Test 5 - Backup content copy
    # ========================================================================

    $CopySource = Join-Path `
        -Path $TestRoot `
        -ChildPath 'CopySource'

    $CopyDestination = Join-Path `
        -Path $TestRoot `
        -ChildPath 'CopyDestination'

    $DocumentsPath = Join-Path `
        -Path $CopySource `
        -ChildPath 'Documents'

    New-Item `
        -Path $DocumentsPath `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
        Out-Null

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $CopySource `
                -ChildPath 'test.txt'
        ) `
        -Value 'ProfMig backup test' `
        -ErrorAction Stop

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $DocumentsPath `
                -ChildPath 'document.txt'
        ) `
        -Value 'ProfMig nested backup test' `
        -ErrorAction Stop

    $CopyResult = Copy-ProfMigBackupContent `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination

    if (-not (
        Test-Path `
            -LiteralPath (
                Join-Path `
                    -Path $CopyDestination `
                    -ChildPath 'test.txt'
            ) `
            -PathType Leaf
    )) {
        throw 'Root backup file was not copied.'
    }

    if (-not (
        Test-Path `
            -LiteralPath (
                Join-Path `
                    -Path $CopyDestination `
                    -ChildPath 'Documents\document.txt'
            ) `
            -PathType Leaf
    )) {
        throw 'Nested backup file was not copied.'
    }

    if ($CopyResult.CopiedFileCount -ne 2) {
        throw (
            'Unexpected copied file count. ' +
            "Expected 2, received $($CopyResult.CopiedFileCount)."
        )
    }

    Write-Host '[PASS] Backup content copied'


    # ========================================================================
    # Test 6 - SHA256 backup verification
    # ========================================================================

    $Verification = Test-ProfMigBackupVerification `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination

    if (-not $Verification.Success) {
        throw (
            'Backup verification failed: ' +
            ($Verification.Errors -join '; ')
        )
    }

    if ($Verification.SourceFileCount -ne 2) {
        throw (
            'Unexpected source file count. ' +
            "Expected 2, received $($Verification.SourceFileCount)."
        )
    }

    if ($Verification.DestinationFileCount -ne 2) {
        throw (
            'Unexpected destination file count. ' +
            "Expected 2, received " +
            "$($Verification.DestinationFileCount)."
        )
    }

    Write-Host '[PASS] SHA256 backup verification succeeded'


    # ========================================================================
    # Test 7 - Modified destination detection
    # ========================================================================

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $CopyDestination `
                -ChildPath 'test.txt'
        ) `
        -Value 'Modified after backup' `
        -ErrorAction Stop

    $FailedVerification = Test-ProfMigBackupVerification `
        -SourcePath $CopySource `
        -DestinationPath $CopyDestination

    if ($FailedVerification.Success) {
        throw 'Modified destination file was not detected.'
    }

    $HashMismatchDetected = @(
        $FailedVerification.Errors |
        Where-Object {
            $_ -like 'SHA256 mismatch:*' -or
            $_ -like 'File size mismatch:*'
        }
    ).Count -gt 0

    if (-not $HashMismatchDetected) {
        throw (
            'Verification failed, but no file content ' +
            'mismatch was reported.'
        )
    }

    Write-Host '[PASS] Modified backup file detected'


    # ========================================================================
    # Test 8 - Verified transfer and staging cleanup
    # ========================================================================

    $TransferSource = Join-Path `
        -Path $TestRoot `
        -ChildPath 'TransferSource'

    $TransferDestination = Join-Path `
        -Path $TestRoot `
        -ChildPath 'TransferDestination'

    New-Item `
        -Path $TransferSource `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
        Out-Null

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $TransferSource `
                -ChildPath 'backup.txt'
        ) `
        -Value 'ProfMig verified transfer' `
        -ErrorAction Stop

    $TransferResult = Invoke-ProfMigOneDriveBackupTransfer `
        -SourcePath $TransferSource `
        -DestinationPath $TransferDestination `
        -CleanupSource

    if (-not $TransferResult.Success) {
        throw 'Verified OneDrive backup transfer failed.'
    }

    if ($TransferResult.Verification -ne 'SHA256') {
        throw 'Unexpected backup verification method.'
    }

    if ($TransferResult.FileCount -ne 1) {
        throw (
            'Unexpected verified file count. ' +
            "Expected 1, received $($TransferResult.FileCount)."
        )
    }

    if (-not $TransferResult.SourceRemoved) {
        throw 'Source cleanup was not reported.'
    }

    if (Test-Path -LiteralPath $TransferSource) {
        throw (
            'Staging source still exists after ' +
            'successful verified cleanup.'
        )
    }

    if (-not (
        Test-Path `
            -LiteralPath (
                Join-Path `
                    -Path $TransferDestination `
                    -ChildPath 'backup.txt'
            ) `
            -PathType Leaf
    )) {
        throw 'Verified backup destination file is missing.'
    }

    Write-Host '[PASS] Staging removed after verified backup'


    # ========================================================================
    # Test 9 - Reparse point / junction protection
    # ========================================================================

    $ReparseSource = Join-Path `
        -Path $TestRoot `
        -ChildPath 'ReparseSource'

    $ReparseDestination = Join-Path `
        -Path $TestRoot `
        -ChildPath 'ReparseDestination'

    $RealFolder = Join-Path `
        -Path $ReparseSource `
        -ChildPath 'RealFolder'

    $JunctionPath = Join-Path `
        -Path $ReparseSource `
        -ChildPath 'CompatibilityJunction'

    New-Item `
        -Path $RealFolder `
        -ItemType Directory `
        -Force `
        -ErrorAction Stop |
        Out-Null

    Set-Content `
        -LiteralPath (
            Join-Path `
                -Path $RealFolder `
                -ChildPath 'real-file.txt'
        ) `
        -Value 'ProfMig junction test' `
        -ErrorAction Stop

    $JunctionCommand = (
        'mklink /J "{0}" "{1}"' -f
        $JunctionPath,
        $RealFolder
    )

    $JunctionOutput = cmd.exe /c $JunctionCommand 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw (
            'Test junction could not be created. ' +
            ($JunctionOutput -join ' ')
        )
    }

    $JunctionItem = Get-Item `
        -LiteralPath $JunctionPath `
        -Force `
        -ErrorAction Stop

    if (-not (
        (
            $JunctionItem.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint
        ) -ne 0
    )) {
        throw 'Created test junction is not a reparse point.'
    }

    $ReparseCopyResult = Copy-ProfMigBackupContent `
        -SourcePath $ReparseSource `
        -DestinationPath $ReparseDestination

    if (-not (
        Test-Path `
            -LiteralPath (
                Join-Path `
                    -Path $ReparseDestination `
                    -ChildPath 'RealFolder\real-file.txt'
            ) `
            -PathType Leaf
    )) {
        throw (
            'Normal file was not copied during ' +
            'reparse-point test.'
        )
    }

    if (
        Test-Path `
            -LiteralPath (
                Join-Path `
                    -Path $ReparseDestination `
                    -ChildPath (
                        'CompatibilityJunction\real-file.txt'
                    )
            )
    ) {
        throw 'Backup followed a reparse point.'
    }

    if ($ReparseCopyResult.CopiedFileCount -ne 1) {
        throw (
            'Unexpected copied file count during ' +
            'reparse-point test.'
        )
    }

    if (
        $ReparseCopyResult.SkippedReparsePointCount -ne 1
    ) {
        throw (
            'Expected exactly one skipped reparse point, ' +
            "received " +
            "$($ReparseCopyResult.SkippedReparsePointCount)."
        )
    }

    if (
        $ReparseCopyResult.SkippedReparsePoints -notcontains
        'CompatibilityJunction'
    ) {
        throw (
            'Skipped reparse point was not reported ' +
            'by the backup copy operation.'
        )
    }

    $ReparseVerification = Test-ProfMigBackupVerification `
        -SourcePath $ReparseSource `
        -DestinationPath $ReparseDestination

    if (-not $ReparseVerification.Success) {
        throw (
            'Reparse-point backup verification failed: ' +
            ($ReparseVerification.Errors -join '; ')
        )
    }

    if ($ReparseVerification.SourceFileCount -ne 1) {
        throw (
            'Reparse-point source manifest contains ' +
            'unexpected files.'
        )
    }

    if ($ReparseVerification.DestinationFileCount -ne 1) {
        throw (
            'Reparse-point destination manifest contains ' +
            'unexpected files.'
        )
    }

    Write-Host '[PASS] Reparse points safely skipped'


    # ========================================================================

    # ========================================================================
    # Empty backup verification must fail
    # ========================================================================

    $EmptySource = Join-Path `
        -Path $TestRoot `
        -ChildPath 'EmptySource'

    $EmptyDestination = Join-Path `
        -Path $TestRoot `
        -ChildPath 'EmptyDestination'

    New-Item `
        -ItemType Directory `
        -Path $EmptySource `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path $EmptyDestination `
        -Force |
        Out-Null

    $EmptyVerification = Test-ProfMigBackupVerification `
        -SourcePath $EmptySource `
        -DestinationPath $EmptyDestination

    if ($EmptyVerification.Success) {
        throw (
            'Verification incorrectly succeeded for ' +
            'empty source and destination manifests.'
        )
    }

    if ($EmptyVerification.SourceFileCount -ne 0) {
        throw 'Empty source manifest should contain zero files.'
    }

    if ($EmptyVerification.DestinationFileCount -ne 0) {
        throw 'Empty destination manifest should contain zero files.'
    }

    if (
        $EmptyVerification.Errors -notcontains
        'Source backup manifest contains no files.'
    ) {
        throw 'Missing expected empty source verification error.'
    }

    if (
        $EmptyVerification.Errors -notcontains
        'Destination backup manifest contains no files.'
    ) {
        throw 'Missing expected empty destination verification error.'
    }

    Write-Host '[PASS] Empty backup verification safely rejected'

    # Result
    # ========================================================================

    Write-Host ''
    Write-Host 'All ProfMig Backup tests passed.'
}
finally {

    if (Test-Path -LiteralPath $TestRoot) {
        Remove-Item `
            -LiteralPath $TestRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}
