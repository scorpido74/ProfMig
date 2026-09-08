<#
.SYNOPSIS
    Regression tests for Microsoft Intune ProfMig detection.

.DESCRIPTION
    Validates the custom detection script used for ProfMig Win32 application
    deployment through Microsoft Intune.

    Detection is executed in a separate PowerShell process to reproduce the
    standalone execution model used by Microsoft Intune.

    Covered scenarios:
    - Missing installation
    - Correct installed version
    - Incorrect installed version
    - Missing build metadata
    - Invalid product metadata
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path `
    -Parent (Split-Path -Parent $PSCommandPath)

$DetectionScript = Join-Path `
    $RepositoryRoot `
    'build\Intune\Detect-ProfMig.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Intune-Detection-Test-' + [guid]::NewGuid().ToString('N'))

$PassedTests = 0
$FailedTests = 0


function Write-TestResult {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [string]$Details
    )

    if ($Passed) {

        $script:PassedTests++

        Write-Host ('[PASS] ' + $Name) -ForegroundColor Green
    }
    else {

        $script:FailedTests++

        Write-Host ('[FAIL] ' + $Name) -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host ('       ' + $Details)
        }
    }
}


function Set-TestMetadata {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version
    )

    New-Item `
        -ItemType Directory `
        -Path $TestRoot `
        -Force | Out-Null

    $Metadata = @"
@{
    Name      = '$Name'
    Version   = '$Version'
    Build     = 'test'
    GitCommit = 'test'
    GitDirty  = `$false
    BuiltAt   = 'test'
}
"@

    Set-Content `
        -LiteralPath (Join-Path $TestRoot 'ProfMig.Build.psd1') `
        -Value $Metadata `
        -Encoding UTF8
}


function Invoke-DetectionTest {

    param (
        [Parameter(Mandatory)]
        [string]$ExpectedVersion
    )

    $Output = & powershell.exe `
        -NoProfile `
        -NonInteractive `
        -ExecutionPolicy Bypass `
        -File $DetectionScript `
        -ExpectedVersion $ExpectedVersion `
        -InstallPath $TestRoot 2>&1

    return [PSCustomObject]@{
        ExitCode = $LASTEXITCODE
        Output   = @($Output)
    }
}


try {

    if (-not (Test-Path -LiteralPath $DetectionScript -PathType Leaf)) {
        throw "Detection script not found: $DetectionScript"
    }


    # -------------------------------------------------------------------------
    # Missing installation
    # -------------------------------------------------------------------------

    $Result = Invoke-DetectionTest `
        -ExpectedVersion '0.2.0'

    Write-TestResult `
        -Name 'Missing installation is not detected' `
        -Passed ($Result.ExitCode -eq 1) `
        -Details ($Result.Output -join ' ')


    # -------------------------------------------------------------------------
    # Correct version
    # -------------------------------------------------------------------------

    Set-TestMetadata `
        -Name 'ProfMig' `
        -Version '0.2.0'

    $Result = Invoke-DetectionTest `
        -ExpectedVersion '0.2.0'

    Write-TestResult `
        -Name 'Correct ProfMig version is detected' `
        -Passed ($Result.ExitCode -eq 0) `
        -Details ($Result.Output -join ' ')


    # -------------------------------------------------------------------------
    # Incorrect version
    # -------------------------------------------------------------------------

    $Result = Invoke-DetectionTest `
        -ExpectedVersion '0.3.0'

    Write-TestResult `
        -Name 'Incorrect ProfMig version is not detected' `
        -Passed ($Result.ExitCode -eq 1) `
        -Details ($Result.Output -join ' ')


    # -------------------------------------------------------------------------
    # Missing metadata
    # -------------------------------------------------------------------------

    Remove-Item `
        -LiteralPath (Join-Path $TestRoot 'ProfMig.Build.psd1') `
        -Force

    $Result = Invoke-DetectionTest `
        -ExpectedVersion '0.2.0'

    Write-TestResult `
        -Name 'Installation without metadata is not detected' `
        -Passed ($Result.ExitCode -eq 1) `
        -Details ($Result.Output -join ' ')


    # -------------------------------------------------------------------------
    # Invalid product metadata
    # -------------------------------------------------------------------------

    Set-TestMetadata `
        -Name 'NotProfMig' `
        -Version '0.2.0'

    $Result = Invoke-DetectionTest `
        -ExpectedVersion '0.2.0'

    Write-TestResult `
        -Name 'Invalid product metadata is not detected' `
        -Passed ($Result.ExitCode -eq 1) `
        -Details ($Result.Output -join ' ')
}
finally {

    Remove-Item `
        -LiteralPath $TestRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}


Write-Host ''
Write-Host '=== Intune detection test summary ==='
Write-Host "Passed: $PassedTests"
Write-Host "Failed: $FailedTests"

if ($FailedTests -gt 0) {
    exit 1
}

exit 0
