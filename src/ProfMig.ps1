$Root = Split-Path -Parent $PSCommandPath

Import-Module "$Root\Modules\ProfMig.Core.psm1" -Force

$null = Initialize-ProfMig

Test-ProfMigEnvironment

Show-ProfMigBanner

Write-Host "Core Framework loaded successfully." -ForegroundColor Green

Stop-ProfMig