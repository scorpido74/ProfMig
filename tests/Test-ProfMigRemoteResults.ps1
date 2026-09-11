<#
.SYNOPSIS
    Validates ProfMig remote result interpretation.

.DESCRIPTION
    Verifies that ProfMig migration artifacts contain the information
    required by remote management tooling.

    ProfMig uses process exit codes for immediate machine-readable status,
    migration reports for result details and logs for diagnostics.

    Structured JSON output is intentionally not required by the ProfMig core.

.NOTES
    Project : ProfMig
    Sprint  : 5.6 - RMM & Remote Deployment
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Passed = 0
$Failed = 0

$ReportRoot = 'C:\ProgramData\ProfMig\Test-5.6\Reports'
$LogRoot    = 'C:\ProgramData\ProfMig\Test-5.6\Logs'


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


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Result Tests'
Write-Host '========================================'


# ---------------------------------------------------------------------------
# Locate latest migration report
# ---------------------------------------------------------------------------

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
        'Start'
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
            -Passed ($ReportText -match [regex]::Escape($Pattern))
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


# ---------------------------------------------------------------------------
# Locate latest ProfMig log
# ---------------------------------------------------------------------------

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

    Write-Host "Log    : $($Log.FullName)"
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