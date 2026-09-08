<#
.SYNOPSIS
    Regression tests for ProfMig deployment and update behavior.

.DESCRIPTION
    Tests the deployment strategy introduced in Sprint 5.5.

    The tests use temporary directories and do not install ProfMig into
    Program Files.

    Covered scenarios:
    - Clean installation
    - Same-version deployment
    - Upgrade
    - Downgrade blocking
    - Explicit downgrade
    - Persistent runtime data preservation
    - Invalid package handling
    - Deployment metadata validation
    - Deployment cleanup
#>

[CmdletBinding()]
param ()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepositoryRoot = Split-Path `
    -Parent (Split-Path -Parent $PSCommandPath)

$BuildScriptPath = Join-Path `
    $RepositoryRoot `
    'build\New-ProfMigPackage.ps1'

$TestRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    ('ProfMig-Deployment-Test-' + [guid]::NewGuid().ToString('N'))

$PackageRoot = Join-Path $TestRoot 'Package'
$InstallRoot = Join-Path $TestRoot 'Install'

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

        Write-Host (
            '[PASS] ' + $Name
        ) -ForegroundColor Green
    }
    else {

        $script:FailedTests++

        Write-Host (
            '[FAIL] ' + $Name
        ) -ForegroundColor Red

        if (-not [string]::IsNullOrWhiteSpace($Details)) {
            Write-Host ('       ' + $Details)
        }
    }
}

function Set-PackageVersion {

    param (
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Version
    )

    $MetadataPath = Join-Path `
        $Path `
        'ProfMig.Build.psd1'

    $Metadata = Import-PowerShellDataFile `
        -LiteralPath $MetadataPath

    $Build = [string]$Metadata.Build
    $GitCommit = [string]$Metadata.GitCommit
    $GitDirty = [bool]$Metadata.GitDirty
    $BuiltAt = [string]$Metadata.BuiltAt
    $Name = [string]$Metadata.Name

    $EscapedName = $Name.Replace("'", "''")
    $EscapedVersion = $Version.Replace("'", "''")
    $EscapedBuild = $Build.Replace("'", "''")
    $EscapedGitCommit = $GitCommit.Replace("'", "''")
    $EscapedBuiltAt = $BuiltAt.Replace("'", "''")

    $GitDirtyLiteral = if ($GitDirty) {
        '$True'
    }
    else {
        '$False'
    }

    $Content = @"
@{
    Name      = '$EscapedName'
    Version   = '$EscapedVersion'
    Build     = '$EscapedBuild'
    GitCommit = '$EscapedGitCommit'
    GitDirty  = $GitDirtyLiteral
    BuiltAt   = '$EscapedBuiltAt'
}
"@

    Set-Content `
        -LiteralPath $MetadataPath `
        -Value $Content `
        -Encoding UTF8
}

function Invoke-TestDeployment {

    param (
        [Parameter(Mandatory)]
        [string]$PackagePath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [switch]$AllowDowngrade
    )

    $DeploymentScriptPath = Join-Path `
        $PackagePath `
        'Deploy-ProfMig.ps1'

    $Arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $DeploymentScriptPath
        '-InstallPath'
        $TargetPath
    )

    if ($AllowDowngrade) {
        $Arguments += '-AllowDowngrade'
    }

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {

        $ErrorActionPreference = 'Continue'

        $Output = @(
            & powershell.exe @Arguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {

        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = $Output
        Text     = ($Output -join [Environment]::NewLine)
    }
}

function Invoke-TestProfMig {

    param (
        [Parameter(Mandatory)]
        [string]$InstallationPath,

        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    $ProfMigPath = Join-Path `
        $InstallationPath `
        'src\ProfMig.ps1'

    $PowerShellArguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        $ProfMigPath
    )

    $PowerShellArguments += $Arguments

    $PreviousErrorActionPreference = $ErrorActionPreference

    try {

        $ErrorActionPreference = 'Continue'

        $Output = @(
            & powershell.exe @PowerShellArguments 2>&1
        )

        $ExitCode = $LASTEXITCODE
    }
    finally {

        $ErrorActionPreference = $PreviousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output   = $Output
        Text     = ($Output -join [Environment]::NewLine)
    }
}
function New-TestPackage {

    param (
        [Parameter(Mandatory)]
        [string]$DestinationPath,

        [string]$Version
    )

    & $BuildScriptPath `
        -OutputPath $DestinationPath

    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Package build failed with exit code $LASTEXITCODE."
    }

    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        Set-PackageVersion `
            -Path $DestinationPath `
            -Version $Version
    }
}

function Get-InstalledVersion {

    param (
        [Parameter(Mandatory)]
        [string]$Path
    )

    $MetadataPath = Join-Path `
        $Path `
        'ProfMig.Build.psd1'

    if (-not (Test-Path -LiteralPath $MetadataPath -PathType Leaf)) {
        return $null
    }

    $Metadata = Import-PowerShellDataFile `
        -LiteralPath $MetadataPath

    return [string]$Metadata.Version
}

function Test-NoDeploymentArtifacts {

    param (
        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $Parent = Split-Path -Parent $TargetPath
    $Name = Split-Path -Leaf $TargetPath

    $Artifacts = @(
        Get-ChildItem `
            -LiteralPath $Parent `
            -Force `
            -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -like ($Name + '.deploy-*') -or
                $_.Name -like ($Name + '.rollback-*')
            }
    )

    return ($Artifacts.Count -eq 0)
}

try {

    Write-Host ''
    Write-Host 'ProfMig Deployment Tests'
    Write-Host '========================'
    Write-Host ''
    Write-Host "Temporary test root: $TestRoot"
    Write-Host ''

    $null = New-Item `
        -ItemType Directory `
        -Path $TestRoot `
        -Force

    # -------------------------------------------------------------------------
    # Build base package
    # -------------------------------------------------------------------------

    Write-Host 'Preparing test package...'

    New-TestPackage `
        -DestinationPath $PackageRoot `
        -Version '1.0.0'

    Write-Host ''

    # -------------------------------------------------------------------------
    # Test 1 - Clean installation
    # -------------------------------------------------------------------------

    Write-Host 'Test: clean installation'

    $Result = Invoke-TestDeployment `
        -PackagePath $PackageRoot `
        -TargetPath $InstallRoot

    Write-TestResult `
        -Name 'Clean installation exits successfully' `
        -Passed ($Result.ExitCode -eq 0) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Clean installation creates target directory' `
        -Passed (
            Test-Path `
                -LiteralPath $InstallRoot `
                -PathType Container
        )

    Write-TestResult `
        -Name 'Clean installation deploys ProfMig.ps1' `
        -Passed (
            Test-Path `
                -LiteralPath (
                    Join-Path $InstallRoot 'src\ProfMig.ps1'
                ) `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Clean installation deploys version metadata' `
        -Passed (
            Test-Path `
                -LiteralPath (
                    Join-Path $InstallRoot 'ProfMig.Build.psd1'
                ) `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Clean installation has expected version' `
        -Passed (
            (Get-InstalledVersion -Path $InstallRoot) -eq '1.0.0'
        )

    foreach ($DirectoryName in @('Logs', 'Reports', 'Backup')) {

        Write-TestResult `
            -Name "Clean installation creates $DirectoryName" `
            -Passed (
                Test-Path `
                    -LiteralPath (
                        Join-Path $InstallRoot $DirectoryName
                    ) `
                    -PathType Container
            )
    }

    # -------------------------------------------------------------------------
    # Test 2 - Same version is a no-op
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: same-version deployment'

    $MarkerPath = Join-Path `
        $InstallRoot `
        'same-version-marker.txt'

    Set-Content `
        -LiteralPath $MarkerPath `
        -Value 'Do not replace this installation.'

    $Result = Invoke-TestDeployment `
        -PackagePath $PackageRoot `
        -TargetPath $InstallRoot

    Write-TestResult `
        -Name 'Same-version deployment exits successfully' `
        -Passed ($Result.ExitCode -eq 0) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Same-version deployment reports no deployment required' `
        -Passed (
            $Result.Text -match 'No deployment required'
        ) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Same-version deployment does not replace installation' `
        -Passed (
            Test-Path `
                -LiteralPath $MarkerPath `
                -PathType Leaf
        )

    # -------------------------------------------------------------------------
    # Test 3 - Upgrade and persistent data preservation
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: upgrade and persistent data'

    $LogFile = Join-Path `
        $InstallRoot `
        'Logs\preserve.log'

    $ReportFile = Join-Path `
        $InstallRoot `
        'Reports\preserve.txt'

    $BackupFile = Join-Path `
        $InstallRoot `
        'Backup\preserve.bak'

    Set-Content `
        -LiteralPath $LogFile `
        -Value 'Persistent log data'

    Set-Content `
        -LiteralPath $ReportFile `
        -Value 'Persistent report data'

    Set-Content `
        -LiteralPath $BackupFile `
        -Value 'Persistent backup data'

    $UpgradePackage = Join-Path `
        $TestRoot `
        'UpgradePackage'

    New-TestPackage `
        -DestinationPath $UpgradePackage `
        -Version '1.1.0'

    $Result = Invoke-TestDeployment `
        -PackagePath $UpgradePackage `
        -TargetPath $InstallRoot

    Write-TestResult `
        -Name 'Upgrade exits successfully' `
        -Passed ($Result.ExitCode -eq 0) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Upgrade installs newer version' `
        -Passed (
            (Get-InstalledVersion -Path $InstallRoot) -eq '1.1.0'
        )

    Write-TestResult `
        -Name 'Upgrade preserves logs' `
        -Passed (
            Test-Path `
                -LiteralPath $LogFile `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Upgrade preserves reports' `
        -Passed (
            Test-Path `
                -LiteralPath $ReportFile `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Upgrade preserves backup data' `
        -Passed (
            Test-Path `
                -LiteralPath $BackupFile `
                -PathType Leaf
        )

    # -------------------------------------------------------------------------
    # Test 4 - Downgrade is blocked
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: downgrade blocking'

    $DowngradePackage = Join-Path `
        $TestRoot `
        'DowngradePackage'

    New-TestPackage `
        -DestinationPath $DowngradePackage `
        -Version '1.0.0'

    $Result = Invoke-TestDeployment `
        -PackagePath $DowngradePackage `
        -TargetPath $InstallRoot

    Write-TestResult `
        -Name 'Downgrade is blocked with exit code 4' `
        -Passed ($Result.ExitCode -eq 4) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Blocked downgrade preserves installed version' `
        -Passed (
            (Get-InstalledVersion -Path $InstallRoot) -eq '1.1.0'
        )

    # -------------------------------------------------------------------------
    # Test 5 - Explicit downgrade
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: explicitly allowed downgrade'

    $Result = Invoke-TestDeployment `
        -PackagePath $DowngradePackage `
        -TargetPath $InstallRoot `
        -AllowDowngrade

    Write-TestResult `
        -Name 'Explicit downgrade exits successfully' `
        -Passed ($Result.ExitCode -eq 0) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Explicit downgrade installs requested version' `
        -Passed (
            (Get-InstalledVersion -Path $InstallRoot) -eq '1.0.0'
        )

    Write-TestResult `
        -Name 'Explicit downgrade preserves logs' `
        -Passed (
            Test-Path `
                -LiteralPath $LogFile `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Explicit downgrade preserves reports' `
        -Passed (
            Test-Path `
                -LiteralPath $ReportFile `
                -PathType Leaf
        )

    Write-TestResult `
        -Name 'Explicit downgrade preserves backup data' `
        -Passed (
            Test-Path `
                -LiteralPath $BackupFile `
                -PathType Leaf
        )

    # -------------------------------------------------------------------------
    # Test 6 - Invalid package
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: invalid package'

    $InvalidPackage = Join-Path `
        $TestRoot `
        'InvalidPackage'

    New-TestPackage `
        -DestinationPath $InvalidPackage `
        -Version '2.0.0'

    Remove-Item `
        -LiteralPath (
            Join-Path $InvalidPackage 'src\ProfMig.ps1'
        ) `
        -Force

    $VersionBeforeInvalidDeployment = `
        Get-InstalledVersion -Path $InstallRoot

    $Result = Invoke-TestDeployment `
        -PackagePath $InvalidPackage `
        -TargetPath $InstallRoot

    Write-TestResult `
        -Name 'Invalid package exits with code 3' `
        -Passed ($Result.ExitCode -eq 3) `
        -Details $Result.Text

    Write-TestResult `
        -Name 'Invalid package does not change installation' `
        -Passed (
            (Get-InstalledVersion -Path $InstallRoot) -eq
            $VersionBeforeInvalidDeployment
        )

    Write-TestResult `
        -Name 'Invalid package preserves existing application' `
        -Passed (
            Test-Path `
                -LiteralPath (
                    Join-Path $InstallRoot 'src\ProfMig.ps1'
                ) `
                -PathType Leaf
        )

    # -------------------------------------------------------------------------
    # Test 7 - Deployment cleanup
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: deployment cleanup'

    Write-TestResult `
        -Name 'No deployment or rollback directories remain' `
        -Passed (
            Test-NoDeploymentArtifacts `
                -TargetPath $InstallRoot
        )

        # -------------------------------------------------------------------------
    # Test 8 - Deployed runtime
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Test: deployed runtime'

    $RuntimePackage = Join-Path `
        $TestRoot `
        'RuntimePackage'

    $RuntimeInstall = Join-Path `
        $TestRoot `
        'RuntimeInstall'

    New-TestPackage `
        -DestinationPath $RuntimePackage

    $RuntimePackageMetadata = Import-PowerShellDataFile `
        -LiteralPath (
            Join-Path $RuntimePackage 'ProfMig.Build.psd1'
        )

    $ExpectedRuntimeVersion = [string](
        $RuntimePackageMetadata.Version
    )

    $Result = Invoke-TestDeployment `
        -PackagePath $RuntimePackage `
        -TargetPath $RuntimeInstall

    if ($Result.ExitCode -ne 0) {
        throw (
            'Runtime test installation failed. ' +
            $Result.Text
        )
    }

    Write-TestResult `
        -Name 'Deployed runtime contains Start-ProfMig.bat' `
        -Passed (
            Test-Path `
                -LiteralPath (
                    Join-Path $RuntimeInstall 'Start-ProfMig.bat'
                ) `
                -PathType Leaf
        )

    $VersionResult = Invoke-TestProfMig `
        -InstallationPath $RuntimeInstall `
        -Arguments @(
            '-Version'
        )

    Write-TestResult `
        -Name 'Deployed runtime version command exits successfully' `
        -Passed ($VersionResult.ExitCode -eq 0) `
        -Details $VersionResult.Text

    Write-TestResult `
        -Name 'Deployed runtime reports expected version' `
        -Passed (
            $VersionResult.Text -match (
                'ProfMig\s+' +
                [regex]::Escape($ExpectedRuntimeVersion)
            )
        ) `
        -Details $VersionResult.Text

    $SilentResult = Invoke-TestProfMig `
        -InstallationPath $RuntimeInstall `
        -Arguments @(
            '-Silent'
        )

    Write-TestResult `
        -Name 'Deployed silent mode returns expected validation exit code' `
        -Passed ($SilentResult.ExitCode -eq 3) `
        -Details $SilentResult.Text

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------

    Write-Host ''
    Write-Host 'Deployment Test Summary'
    Write-Host '======================='
    Write-Host "Passed: $PassedTests"
    Write-Host "Failed: $FailedTests"

    if ($FailedTests -gt 0) {
        exit 1
    }

    Write-Host ''
    Write-Host (
        'PASS: ProfMig deployment validation completed successfully.'
    ) -ForegroundColor Green

    exit 0
}
catch {

    Write-Host ''
    Write-Host (
        'FATAL: Deployment test execution failed: ' +
        $_.Exception.Message
    ) -ForegroundColor Red

    exit 1
}
finally {

    if (Test-Path -LiteralPath $TestRoot) {

        try {

            Remove-Item `
                -LiteralPath $TestRoot `
                -Recurse `
                -Force
        }
        catch {

            Write-Warning (
                'Unable to remove temporary deployment test directory: ' +
                $TestRoot
            )
        }
    }
}