<#
.SYNOPSIS
    Validates ProfMig remote result interpretation.

.DESCRIPTION
    Verifies that ProfMig migration artifacts contain the information
    required by remote management tooling.

    ProfMig uses process exit codes for immediate machine-readable status,
    migration reports for result details and logs for diagnostics.

    This test is self-contained. It creates representative temporary
    ProfMig report and log artifacts, validates remote interpretation and
    removes the temporary artifacts afterwards.

    Structured JSON output is intentionally not required by the ProfMig core.

.NOTES
    Project : ProfMig
    Sprint  : 5.6 - RMM & Remote Deployment
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Passed = 0
$Failed = 0

$TestRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-RemoteResults-Test-' + [guid]::NewGuid().ToString('N'))

$ReportRoot = Join-Path `
    $TestRoot `
    'Reports'

$LogRoot = Join-Path `
    $TestRoot `
    'Logs'


function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [string]$Details = ''
    )

    if ($Passed) {

        Write-Host "[PASS] $Name"

        $script:Passed++
    }
    else {

        Write-Host "[FAIL] $Name"

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host "       $Details"
        }

        $script:Failed++
    }
}


function New-TestArtifacts {

    New-Item `
        -ItemType Directory `
        -Path $ReportRoot `
        -Force |
        Out-Null

    New-Item `
        -ItemType Directory `
        -Path $LogRoot `
        -Force |
        Out-Null

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    $ReportPath = Join-Path `
        $ReportRoot `
        "ProfMig_Migration_$Timestamp.txt"

    $LogPath = Join-Path `
        $LogRoot `
        "ProfMig_$Timestamp.log"

    $ReportContent = @'
ProfMig Migration Report
============================================================

Source      : C:\Users\ProfMigSource
Destination : C:\Users\ProfMigDestination
Started     : 2026-09-11 09:17:20
Completed   : 2026-09-11 09:17:23
Duration    : 00:00:03

Migration statistics
============================================================

Files selected : 10
Files copied   : 9
Files skipped  : 1
Files failed   : 0

Verification
============================================================

Level    : Standard
Status   : Completed

Overall result
============================================================

Success with warnings

Copy Engine status
============================================================

CompletedWithWarnings

Application Migration status
============================================================

NotRun
'@

    $LogContent = @'
2026-09-11 09:17:20 [INFO] ProfMig migration started.
2026-09-11 09:17:21 [INFO] Source profile validated.
2026-09-11 09:17:21 [INFO] Destination profile validated.
2026-09-11 09:17:23 [WARN] Migration completed with warnings.
'@

    Set-Content `
        -LiteralPath $ReportPath `
        -Value $ReportContent `
        -Encoding UTF8

    Set-Content `
        -LiteralPath $LogPath `
        -Value $LogContent `
        -Encoding UTF8
}


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Result Tests'
Write-Host '========================================'
Write-Host "Temporary test root: $TestRoot"


try {

    # -----------------------------------------------------------------------
    # Create isolated test artifacts
    # -----------------------------------------------------------------------

    New-TestArtifacts

    Write-TestResult `
        -Name 'Temporary report directory created' `
        -Passed (Test-Path -LiteralPath $ReportRoot)

    Write-TestResult `
        -Name 'Temporary log directory created' `
        -Passed (Test-Path -LiteralPath $LogRoot)


    # -----------------------------------------------------------------------
    # Locate latest migration report
    # -----------------------------------------------------------------------

    $Report = Get-ChildItem `
        -LiteralPath $ReportRoot `
        -Filter 'ProfMig_Migration_*.txt' `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    Write-TestResult `
        -Name 'Migration report can be located' `
        -Passed ($null -ne $Report)

    if ($null -ne $Report) {

        $ReportText = Get-Content `
            -LiteralPath $Report.FullName `
            -Raw

        $RequiredPatterns = @(
            'Source'
            'Destination'
            'Started'
            'Completed'
            'Duration'
            'Files selected'
            'Files copied'
            'Files skipped'
            'Files failed'
            'Verification'
            'Overall result'
            'Copy Engine status'
        )

        foreach ($Pattern in $RequiredPatterns) {

            Write-TestResult `
                -Name "Report contains '$Pattern'" `
                -Passed (
                    $ReportText -match [regex]::Escape($Pattern)
                )
        }

        Write-TestResult `
            -Name 'Report contains interpretable overall result' `
            -Passed (
                $ReportText -match
                '(?s)Overall result.*?(Success with warnings|Success|Failed)'
            )

        Write-TestResult `
            -Name 'Report contains interpretable Copy Engine status' `
            -Passed (
                $ReportText -match
                '(?s)Copy Engine status.*?(CompletedWithWarnings|Completed|Failed)'
            )

        Write-Host ''
        Write-Host "Report : $($Report.FullName)"
    }


    # -----------------------------------------------------------------------
    # Locate latest ProfMig log
    # -----------------------------------------------------------------------

    $Log = Get-ChildItem `
        -LiteralPath $LogRoot `
        -Filter 'ProfMig_*.log' `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    Write-TestResult `
        -Name 'ProfMig log can be located' `
        -Passed ($null -ne $Log)

    if ($null -ne $Log) {

        $LogText = Get-Content `
            -LiteralPath $Log.FullName `
            -Raw

        Write-TestResult `
            -Name 'ProfMig log contains diagnostic content' `
            -Passed (
                -not [string]::IsNullOrWhiteSpace($LogText)
            )

        Write-Host "Log    : $($Log.FullName)"
    }
}
catch {

    Write-Host ''
    Write-Host "[FAIL] Unexpected test failure"
    Write-Host "       $($_.Exception.Message)"

    $Failed++
}
finally {

    Write-Host ''
    Write-Host 'Cleaning temporary test artifacts...'

    if (Test-Path -LiteralPath $TestRoot) {

        Remove-Item `
            -LiteralPath $TestRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    $CleanupSuccessful = -not (
        Test-Path -LiteralPath $TestRoot
    )

    Write-TestResult `
        -Name 'Temporary test artifacts removed' `
        -Passed $CleanupSuccessful
}


# ---------------------------------------------------------------------------
# Result
# ---------------------------------------------------------------------------

Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Result Summary'
Write-Host '========================================'
Write-Host "Passed : $Passed"
Write-Host "Failed : $Failed"

if ($Failed -eq 0) {

    Write-Host 'RESULT : PASSED'
    exit 0
}

Write-Host 'RESULT : FAILED'
exit 1