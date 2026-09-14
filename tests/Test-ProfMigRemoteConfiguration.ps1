<#
.SYNOPSIS
    Tests ProfMig configuration deployment for remote execution.

.DESCRIPTION
    Validates that ProfMig can consume an externally deployed configuration
    file from a location outside the ProfMig runtime directory.

    Also verifies predictable exit codes for missing and invalid external
    configuration files.

.NOTES
    Project : ProfMig
    Sprint  : 5.6 - RMM & Remote Deployment
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$ProfMigPath = Join-Path $ProjectRoot 'src\ProfMig.ps1'

$TestRoot = Join-Path `
    $env:TEMP `
    ('ProfMig-RemoteConfig-Test-' + [guid]::NewGuid().ToString())

$Passed = 0
$Failed = 0


function Invoke-RemoteConfigTest {

    param (
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [int]$ExpectedExitCode
    )

    & powershell.exe `
        -NoProfile `
        -NonInteractive `
        -ExecutionPolicy Bypass `
        -File $ProfMigPath `
        @Arguments *> $null

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -eq $ExpectedExitCode) {

        Write-Host (
            '[PASS] {0} - Exit code {1}' -f
            $Name,
            $ExitCode
        )

        $script:Passed++
    }
    else {

        Write-Host (
            '[FAIL] {0} - Expected {1}, received {2}' -f
            $Name,
            $ExpectedExitCode,
            $ExitCode
        )

        $script:Failed++
    }
}


try {

    New-Item `
        -ItemType Directory `
        -Path $TestRoot `
        -Force |
        Out-Null

    $ExternalConfig = Join-Path `
        $TestRoot `
        'RemoteConfig.psd1'

    Copy-Item `
        -LiteralPath (Join-Path $ProjectRoot 'src\Config.psd1') `
        -Destination $ExternalConfig `
        -Force


    Write-Host ''
    Write-Host '========================================'
    Write-Host 'ProfMig Remote Configuration Tests'
    Write-Host '========================================'


    # -----------------------------------------------------------------------
    # Test 1 - Valid external configuration
    #
    # Unknown SIDs deliberately cause ValidationError (4) after the external
    # configuration has successfully been loaded.
    # -----------------------------------------------------------------------

    Push-Location $env:TEMP

    try {

        Invoke-RemoteConfigTest `
            -Name 'Valid external configuration' `
            -Arguments @(
                '-Silent'
                '-SourceSid'
                'S-1-5-21-999999999-999999999-999999999-9998'
                '-DestinationSid'
                'S-1-5-21-999999999-999999999-999999999-9999'
                '-ConfigPath'
                $ExternalConfig
            ) `
            -ExpectedExitCode 4
    }
    finally {
        Pop-Location
    }


    # -----------------------------------------------------------------------
    # Test 2 - Missing external configuration
    # -----------------------------------------------------------------------

    $MissingConfig = Join-Path `
        $TestRoot `
        'DoesNotExist.psd1'

    Invoke-RemoteConfigTest `
        -Name 'Missing external configuration' `
        -Arguments @(
            '-Silent'
            '-SourceSid'
            'S-1-5-21-999999999-999999999-999999999-9998'
            '-DestinationSid'
            'S-1-5-21-999999999-999999999-999999999-9999'
            '-ConfigPath'
            $MissingConfig
        ) `
        -ExpectedExitCode 3


    # -----------------------------------------------------------------------
    # Test 3 - Unsupported external configuration schema
    # -----------------------------------------------------------------------

    $InvalidConfig = Join-Path `
        $TestRoot `
        'InvalidSchema.psd1'

    @"
@{
    SchemaVersion = '99.0'

    Application = @{
        Name    = 'ProfMig'
        Version = '0.2.0'
        Build   = 'Development'
    }
}
"@ | Set-Content `
        -LiteralPath $InvalidConfig `
        -Encoding UTF8

    Invoke-RemoteConfigTest `
        -Name 'Unsupported external configuration schema' `
        -Arguments @(
            '-Silent'
            '-SourceSid'
            'S-1-5-21-999999999-999999999-999999999-9998'
            '-DestinationSid'
            'S-1-5-21-999999999-999999999-999999999-9999'
            '-ConfigPath'
            $InvalidConfig
        ) `
        -ExpectedExitCode 3
}
finally {

    Remove-Item `
        -LiteralPath $TestRoot `
        -Recurse `
        -Force `
        -ErrorAction SilentlyContinue
}


Write-Host ''
Write-Host '========================================'
Write-Host 'ProfMig Remote Configuration Summary'
Write-Host '========================================'
Write-Host "Passed : $Passed"
Write-Host "Failed : $Failed"

if ($Failed -eq 0) {

    Write-Host 'RESULT : PASSED'
    exit 0
}

Write-Host 'RESULT : FAILED'
exit 1
