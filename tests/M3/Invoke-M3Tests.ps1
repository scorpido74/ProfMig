[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# ProfMig Milestone 3 automated regression test runner
# ---------------------------------------------------------------------------

$M3Root = $PSScriptRoot
$AutomatedTestPath = Join-Path $M3Root 'Automated'

if (-not (Test-Path -LiteralPath $AutomatedTestPath -PathType Container)) {
    throw "M3 automated test directory not found: $AutomatedTestPath"
}

$PesterModule = Get-Module `
    -ListAvailable `
    -Name Pester |
    Sort-Object Version -Descending |
    Select-Object -First 1

if ($null -eq $PesterModule) {
    throw 'Pester is not installed.'
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' ProfMig Milestone 3 - Automated Regression Tests' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Pester version : $($PesterModule.Version)"
Write-Host "Test path      : $AutomatedTestPath"
Write-Host ''

$Result = Invoke-Pester `
    -Script $AutomatedTestPath `
    -PassThru

$Total = [int]$Result.TotalCount
$Passed = [int]$Result.PassedCount
$Failed = [int]$Result.FailedCount
$Skipped = [int]$Result.SkippedCount
$Pending = [int]$Result.PendingCount

$Inconclusive = 0

if (
    $Result.PSObject.Properties.Name -contains 'InconclusiveCount' -and
    $null -ne $Result.InconclusiveCount
) {
    $Inconclusive = [int]$Result.InconclusiveCount
}

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ' M3 AUTOMATED REGRESSION SUMMARY' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan

Write-Host ('Total        : {0}' -f $Total)
Write-Host ('Passed       : {0}' -f $Passed)
Write-Host ('Failed       : {0}' -f $Failed)
Write-Host ('Skipped      : {0}' -f $Skipped)
Write-Host ('Pending      : {0}' -f $Pending)
Write-Host ('Inconclusive : {0}' -f $Inconclusive)

Write-Host ''

$Successful = (
    $Total -gt 0 -and
    $Failed -eq 0 -and
    $Pending -eq 0 -and
    $Inconclusive -eq 0 -and
    $Passed -eq $Total
)

if ($Successful) {
    Write-Host 'M3 AUTOMATED REGRESSION: PASS' -ForegroundColor Green
    exit 0
}

Write-Host 'M3 AUTOMATED REGRESSION: FAIL' -ForegroundColor Red
exit 1
