# ============================================================================
# Test-ProfMigOneNote.ps1
#
# Regression tests for Microsoft OneNote discovery, migration protection,
# migration planning and safe file copying.
#
# Synthetic OneNote files are used to validate ProfMig behavior only.
# They are not intended to represent valid OneNote file contents.
# ============================================================================

$ErrorActionPreference = 'Stop'

$modulePath = Join-Path `
    $PSScriptRoot `
    '..\src\Modules\ProfMig.OneNote.psm1'

Import-Module $modulePath -Force


# ============================================================================
# Test helpers
# ============================================================================

$script:Passed = 0
$script:Failed = 0


function Test-Condition {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Condition
    )

    if ($Condition) {
        Write-Host "[PASS] $Name"
        $script:Passed++
    }
    else {
        Write-Host "[FAIL] $Name"
        $script:Failed++
    }
}


# ============================================================================
# Create isolated synthetic profiles
# ============================================================================

$testRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-OneNote-' + [Guid]::NewGuid().ToString('N'))

$sourceProfile = Join-Path `
    $testRoot `
    'Source'

$emptyProfile = Join-Path `
    $testRoot `
    'Empty'

$destinationProfile = Join-Path `
    $testRoot `
    'Destination'

New-Item `
    -ItemType Directory `
    -Path $sourceProfile `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $emptyProfile `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $destinationProfile `
    -Force |
    Out-Null


try {

    # ========================================================================
    # Synthetic OneNote locations
    # ========================================================================

    $backupPath = Join-Path `
        $sourceProfile `
        'AppData\Local\Microsoft\OneNote\16.0\Back-up\Test Notebook'

    $cachePath = Join-Path `
        $sourceProfile `
        'AppData\Local\Microsoft\OneNote\16.0\cache'

    $templatePath = Join-Path `
        $sourceProfile `
        'AppData\Roaming\Microsoft\Templates'

    $localNotebookPath = Join-Path `
        $sourceProfile `
        'Documents\OneNote Notebooks\Test Notebook'

    foreach (
        $path in @(
            $backupPath
            $cachePath
            $templatePath
            $localNotebookPath
        )
    ) {

        New-Item `
            -ItemType Directory `
            -Path $path `
            -Force |
            Out-Null
    }


    # ========================================================================
    # Synthetic files
    #
    # These files test ProfMig discovery, classification and copy behavior.
    # They are not valid OneNote notebooks or sections.
    # ========================================================================

    $backupFilePath = Join-Path `
        $backupPath `
        'Backup Section.one'

    $portableFilePath = Join-Path `
        $localNotebookPath `
        'Local Section.one'

    $templateFilePath = Join-Path `
        $templatePath `
        'Notebook Template.onetoc2'

    $cacheFilePath = Join-Path `
        $cachePath `
        '00000000.bin'

    $cacheHeaderPath = Join-Path `
        $cachePath `
        'header'

    Set-Content `
        -LiteralPath $backupFilePath `
        -Value 'synthetic backup'

    Set-Content `
        -LiteralPath $portableFilePath `
        -Value 'synthetic local notebook'

    Set-Content `
        -LiteralPath $templateFilePath `
        -Value 'synthetic template'

    Set-Content `
        -LiteralPath $cacheFilePath `
        -Value 'synthetic cache'

    Set-Content `
        -LiteralPath $cacheHeaderPath `
        -Value 'synthetic header'


    # ========================================================================
    # Test 1 - Paths
    # ========================================================================

    $paths = Get-ProfMigOneNotePaths `
        -ProfilePath $sourceProfile

    Test-Condition `
        -Name 'OneNote paths are generated for source profile' `
        -Condition (
            $paths.LocalRoot -like "$sourceProfile*"
        )


    # ========================================================================
    # Test 2 - File discovery
    # ========================================================================

    $files = @(
        Get-ProfMigOneNoteFiles `
            -ProfilePath $sourceProfile
    )

    Test-Condition `
        -Name 'Three OneNote extension files are discovered' `
        -Condition (
            $files.Count -eq 3
        )


    # ========================================================================
    # Test 3 - Local notebook classification
    # ========================================================================

    $portableFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Portable'
            }
    )

    Test-Condition `
        -Name 'Local notebook is classified as Portable' `
        -Condition (
            $portableFiles.Count -eq 1
        )

    Test-Condition `
        -Name 'Portable notebook action is Migrate' `
        -Condition (
            $portableFiles[0].Action -eq 'Migrate'
        )


    # ========================================================================
    # Test 4 - Backup classification
    # ========================================================================

    $backupFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Backup'
            }
    )

    Test-Condition `
        -Name 'OneNote backup is classified as Backup' `
        -Condition (
            $backupFiles.Count -eq 1
        )

    Test-Condition `
        -Name 'OneNote backup action is Preserve' `
        -Condition (
            $backupFiles[0].Action -eq 'Preserve'
        )


    # ========================================================================
    # Test 5 - Office template exclusion
    # ========================================================================

    $templateFiles = @(
        $files |
            Where-Object {
                $_.Classification -eq 'Template'
            }
    )

    Test-Condition `
        -Name 'Office template is classified as Template' `
        -Condition (
            $templateFiles.Count -eq 1
        )

    Test-Condition `
        -Name 'Office template action is Exclude' `
        -Condition (
            $templateFiles[0].Action -eq 'Exclude'
        )


    # ========================================================================
    # Test 6 - Cache discovery
    # ========================================================================

    $cacheState = Get-ProfMigOneNoteCacheState `
        -ProfilePath $sourceProfile

    Test-Condition `
        -Name 'OneNote cache is detected' `
        -Condition (
            $cacheState.Exists
        )

    Test-Condition `
        -Name 'OneNote cache data is detected' `
        -Condition (
            $cacheState.HasData
        )

    Test-Condition `
        -Name 'Cache contains two synthetic files' `
        -Condition (
            $cacheState.FileCount -eq 2
        )

    Test-Condition `
        -Name 'Cache action is Review' `
        -Condition (
            $cacheState.Action -eq 'Review'
        )

    Test-Condition `
        -Name 'Cache requires review' `
        -Condition (
            $cacheState.RequiresReview
        )


    # ========================================================================
    # Test 7 - Overall detection
    # ========================================================================

    $detection = Get-ProfMigOneNoteDetection `
        -ProfilePath $sourceProfile

    Test-Condition `
        -Name 'OneNote is detected in populated profile' `
        -Condition (
            $detection.Detected
        )

    Test-Condition `
        -Name 'Detection contains one portable file' `
        -Condition (
            $detection.PortableCount -eq 1
        )

    Test-Condition `
        -Name 'Detection contains one backup file' `
        -Condition (
            $detection.BackupCount -eq 1
        )

    Test-Condition `
        -Name 'Detection contains one template file' `
        -Condition (
            $detection.TemplateCount -eq 1
        )

    Test-Condition `
        -Name 'Detection requires review when cache contains data' `
        -Condition (
            $detection.RequiresReview
        )


    # ========================================================================
    # Test 8 - Migration plan
    # ========================================================================

    $migrationPlan = Get-ProfMigOneNoteMigrationPlan `
        -ProfilePath $sourceProfile

    Test-Condition `
        -Name 'Migration plan detects OneNote data' `
        -Condition (
            $migrationPlan.Detected
        )

    Test-Condition `
        -Name 'Migration plan contains one portable migration item' `
        -Condition (
            $migrationPlan.MigrateCount -eq 1
        )

    Test-Condition `
        -Name 'Migration plan contains one backup preservation item' `
        -Condition (
            $migrationPlan.PreserveCount -eq 1
        )

    Test-Condition `
        -Name 'Migration plan excludes one Office template' `
        -Condition (
            $migrationPlan.ExcludeCount -eq 1
        )

    Test-Condition `
        -Name 'Migration plan requires review when cache contains data' `
        -Condition (
            $migrationPlan.RequiresReview
        )

    Test-Condition `
        -Name 'Migration plan status is ReadyWithWarnings' `
        -Condition (
            $migrationPlan.Status -eq 'ReadyWithWarnings'
        )

    Test-Condition `
        -Name 'Migration plan never overwrites destination data' `
        -Condition (
            $migrationPlan.OverwritePolicy -eq 'NeverOverwrite'
        )

    Test-Condition `
        -Name 'Migration plan does not migrate OneNote cache' `
        -Condition (
            $migrationPlan.CachePolicy -eq 'ReviewOnly'
        )

    Test-Condition `
        -Name 'Migration plan preserves OneNote backups' `
        -Condition (
            $migrationPlan.BackupPolicy -eq 'Preserve'
        )

    Test-Condition `
        -Name 'Migration plan contains cache warning' `
        -Condition (
            $migrationPlan.Warnings.Count -eq 1
        )


    # ========================================================================
    # Test 9 - Safe portable file copy
    # ========================================================================

    $copyDestination = Join-Path `
        $destinationProfile `
        'Documents\OneNote Notebooks\Test Notebook\Local Section.one'

    $copyResult = Copy-ProfMigOneNoteFile `
        -SourcePath $portableFilePath `
        -DestinationPath $copyDestination

    Test-Condition `
        -Name 'Portable OneNote file is copied successfully' `
        -Condition (
            $copyResult.Success -and
            -not $copyResult.Skipped
        )

    Test-Condition `
        -Name 'Copied OneNote file exists at destination' `
        -Condition (
            Test-Path `
                -LiteralPath $copyDestination `
                -PathType Leaf
        )

    $sourceCopyFile = Get-Item `
        -LiteralPath $portableFilePath

    $destinationCopyFile = Get-Item `
        -LiteralPath $copyDestination

    Test-Condition `
        -Name 'Copied OneNote file size matches source' `
        -Condition (
            $destinationCopyFile.Length -eq
            $sourceCopyFile.Length
        )

    Test-Condition `
        -Name 'Copy result reports copied file size' `
        -Condition (
            $copyResult.SizeBytes -eq
            $sourceCopyFile.Length
        )


    # ========================================================================
    # Test 10 - Existing destination is never overwritten
    # ========================================================================

    $originalDestinationContent = Get-Content `
        -LiteralPath $copyDestination `
        -Raw

    Set-Content `
        -LiteralPath $portableFilePath `
        -Value 'THIS MUST NOT OVERWRITE DESTINATION'

    $noOverwriteResult = Copy-ProfMigOneNoteFile `
        -SourcePath $portableFilePath `
        -DestinationPath $copyDestination

    $destinationContentAfterSecondCopy = Get-Content `
        -LiteralPath $copyDestination `
        -Raw

    Test-Condition `
        -Name 'Existing destination OneNote file is skipped' `
        -Condition (
            $noOverwriteResult.Success -and
            $noOverwriteResult.Skipped
        )

    Test-Condition `
        -Name 'Existing destination OneNote file is not overwritten' `
        -Condition (
            $destinationContentAfterSecondCopy -eq
            $originalDestinationContent
        )

    Test-Condition `
        -Name 'Skipped copy reports zero copied bytes' `
        -Condition (
            $noOverwriteResult.SizeBytes -eq 0
        )


    # ========================================================================
    # Test 11 - Unsupported source type
    # ========================================================================

    $unsupportedSource = Join-Path `
        $sourceProfile `
        'Unsupported.bin'

    $unsupportedDestination = Join-Path `
        $destinationProfile `
        'Unsupported.bin'

    Set-Content `
        -LiteralPath $unsupportedSource `
        -Value 'unsupported file'

    $unsupportedResult = Copy-ProfMigOneNoteFile `
        -SourcePath $unsupportedSource `
        -DestinationPath $unsupportedDestination

    Test-Condition `
        -Name 'Unsupported OneNote source type is rejected' `
        -Condition (
            -not $unsupportedResult.Success -and
            -not $unsupportedResult.Skipped
        )

    Test-Condition `
        -Name 'Unsupported source is not created at destination' `
        -Condition (
            -not (
                Test-Path `
                    -LiteralPath $unsupportedDestination `
                    -PathType Leaf
            )
        )


    # ========================================================================
    # Test 12 - Missing source
    # ========================================================================

    $missingSource = Join-Path `
        $sourceProfile `
        'Missing.one'

    $missingDestination = Join-Path `
        $destinationProfile `
        'Missing.one'

    $missingCopyResult = Copy-ProfMigOneNoteFile `
        -SourcePath $missingSource `
        -DestinationPath $missingDestination

    Test-Condition `
        -Name 'Missing OneNote source file returns failure' `
        -Condition (
            -not $missingCopyResult.Success -and
            -not $missingCopyResult.Skipped
        )

    Test-Condition `
        -Name 'Missing OneNote source does not create destination file' `
        -Condition (
            -not (
                Test-Path `
                    -LiteralPath $missingDestination `
                    -PathType Leaf
            )
        )


    # ========================================================================
    # Test 13 - Backup file can be safely preserved
    # ========================================================================

    $backupDestination = Join-Path `
        $destinationProfile `
        'Recovery\OneNote\Backup Section.one'

    $backupCopyResult = Copy-ProfMigOneNoteFile `
        -SourcePath $backupFilePath `
        -DestinationPath $backupDestination

    Test-Condition `
        -Name 'OneNote backup file can be preserved safely' `
        -Condition (
            $backupCopyResult.Success -and
            -not $backupCopyResult.Skipped
        )

    Test-Condition `
        -Name 'Preserved OneNote backup exists at destination' `
        -Condition (
            Test-Path `
                -LiteralPath $backupDestination `
                -PathType Leaf
        )


    # ========================================================================
    # Test 14 - Empty profile
    # ========================================================================

    $emptyDetection = Get-ProfMigOneNoteDetection `
        -ProfilePath $emptyProfile

    Test-Condition `
        -Name 'OneNote is not detected in empty profile' `
        -Condition (
            -not $emptyDetection.Detected
        )

    Test-Condition `
        -Name 'Empty profile does not require review' `
        -Condition (
            -not $emptyDetection.RequiresReview
        )


    # ========================================================================
    # Test 15 - Missing profile
    # ========================================================================

    $missingProfile = Join-Path `
        $testRoot `
        'DoesNotExist'

    $missingFiles = @(
        Get-ProfMigOneNoteFiles `
            -ProfilePath $missingProfile
    )

    Test-Condition `
        -Name 'Missing profile returns no OneNote files' `
        -Condition (
            $missingFiles.Count -eq 0
        )
}
finally {

    Remove-Item `
        -LiteralPath $testRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}


# ============================================================================
# Result
# ============================================================================

Write-Host ''
Write-Host '========================================'
Write-Host 'OneNote regression test result'
Write-Host '========================================'
Write-Host "Passed: $script:Passed"
Write-Host "Failed: $script:Failed"
Write-Host '========================================'

if ($script:Failed -gt 0) {
    exit 1
}

exit 0