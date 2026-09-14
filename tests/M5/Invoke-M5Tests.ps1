[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$testSuites = @(
    @{
        Name = 'Packaging'
        Path = 'tests\Test-ProfMigPackaging.ps1'
    },
    @{
        Name = 'Versioning'
        Path = 'tests\Test-ProfMigVersioning.ps1'
    },
    @{
        Name = 'Command-Line and Silent Mode'
        Path = 'tests\Test-ProfMigCommandLine.ps1'
    },
    @{
        Name = 'Deployment'
        Path = 'tests\Test-ProfMigDeployment.ps1'
    },
    @{
        Name = 'Uninstall'
        Path = 'tests\Test-ProfMigUninstall.ps1'
    },
    @{
        Name = 'Intune Detection'
        Path = 'tests\Test-ProfMigIntuneDetection.ps1'
    },
    @{
        Name = 'Remote Configuration'
        Path = 'tests\Test-ProfMigRemoteConfiguration.ps1'
    },
    @{
        Name = 'Remote Execution'
        Path = 'tests\Test-ProfMigRemoteExecution.ps1'
    },
    @{
        Name = 'Remote Exit Codes'
        Path = 'tests\Test-ProfMigRemoteExitCodes.ps1'
    },
    @{
        Name = 'Remote Results'
        Path = 'tests\Test-ProfMigRemoteResults.ps1'
    },
    @{
        Name = 'Remote Wrapper'
        Path = 'tests\Test-ProfMigRemoteWrapper.ps1'
    },
    @{
        Name = 'Code Signing and Integrity'
        Path = 'tests\Test-ProfMigCodeSigning.ps1'
    },
    @{
        Name = 'Milestone 3 Regression'
        Path = 'tests\M3\Invoke-M3Tests.ps1'
    }
)

$results = @()

Write-Host ''
Write-Host '============================================================'
Write-Host ' ProfMig Milestone 5 - Deployment & Automation Validation'
Write-Host '============================================================'
Write-Host ''
Write-Host "Repository : $RepositoryRoot"
Write-Host "PowerShell : $($PSVersionTable.PSVersion)"
Write-Host "Identity   : $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host ''

foreach ($suite in $testSuites) {

    $testPath = Join-Path $RepositoryRoot $suite.Path

    Write-Host ''
    Write-Host '============================================================'
    Write-Host " M5 Test Suite: $($suite.Name)"
    Write-Host '============================================================'

    if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {

        Write-Host "[FAIL] Test script not found: $testPath"

        $results += [pscustomobject]@{
            Test     = $suite.Name
            ExitCode = $null
            Result   = 'FAIL'
        }

        continue
    }

    & powershell.exe `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $testPath

    $exitCode = $LASTEXITCODE

    $results += [pscustomobject]@{
        Test     = $suite.Name
        ExitCode = $exitCode
        Result   = if ($exitCode -eq 0) { 'PASS' } else { 'FAIL' }
    }
}

$failed = @($results | Where-Object { $_.Result -ne 'PASS' })

Write-Host ''
Write-Host '============================================================'
Write-Host ' M5 AUTOMATED VALIDATION SUMMARY'
Write-Host '============================================================'

$results | Format-Table -AutoSize

Write-Host "Total  : $($results.Count)"
Write-Host "Passed : $(@($results | Where-Object Result -eq 'PASS').Count)"
Write-Host "Failed : $($failed.Count)"

if ($failed.Count -gt 0) {
    Write-Host ''
    Write-Host 'M5 AUTOMATED VALIDATION: FAIL'
    exit 1
}

Write-Host ''
Write-Host 'M5 AUTOMATED VALIDATION: PASS'
exit 0