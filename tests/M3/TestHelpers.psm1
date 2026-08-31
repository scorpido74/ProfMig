Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ProfMigTestRepositoryRoot {
    $m3Root = Split-Path -Parent $PSScriptRoot
    return (Split-Path -Parent $m3Root)
}

function Get-ProfMigTestModulePath {
    param(
        [Parameter(Mandatory)]
        [string]$ModuleName
    )

    $repositoryRoot = Get-ProfMigTestRepositoryRoot

    return Join-Path `
        $repositoryRoot `
        "src\Modules\$ModuleName.psm1"
}

function Get-ProfMigTestConfigPath {
    $repositoryRoot = Get-ProfMigTestRepositoryRoot

    return Join-Path `
        $repositoryRoot `
        'src\Config.psd1'
}

function New-ProfMigTestRoot {
    param(
        [Parameter(Mandatory)]
        [string]$TestId
    )

    $baseRoot = Join-Path `
        $env:TEMP `
        'ProfMig-M3-Tests'

    $testRoot = Join-Path `
        $baseRoot `
        $TestId

    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item `
            -LiteralPath $testRoot `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }

    New-Item `
        -Path $testRoot `
        -ItemType Directory `
        -Force |
        Out-Null

    return $testRoot
}

function Remove-ProfMigTestRoot {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item `
            -LiteralPath $Path `
            -Recurse `
            -Force `
            -ErrorAction SilentlyContinue
    }
}

function Test-ProfMigAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $principal = New-Object `
        Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

Export-ModuleMember -Function @(
    'Get-ProfMigTestRepositoryRoot'
    'Get-ProfMigTestModulePath'
    'Get-ProfMigTestConfigPath'
    'New-ProfMigTestRoot'
    'Remove-ProfMigTestRoot'
    'Test-ProfMigAdministrator'
)