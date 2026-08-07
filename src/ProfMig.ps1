$Root = Split-Path -Parent $PSCommandPath

Import-Module "$Root\Modules\ProfMig.Core.psm1" -Force
Import-Module "$Root\Modules\ProfMig.Logging.psm1" -Force
Import-Module "$Root\Modules\ProfMig.Configuration.psm1" -Force

$null = Initialize-ProfMig

$Config = Import-ProfMigConfiguration `
-Path "$Root\Config.psd1"

$LogFolder = Join-Path (Split-Path $Root -Parent)
$Config.Paths.Logs

Initialize-Logging -LogFolder $LogFolder | Out-Null

Test-ProfMigEnvironment

Show-ProfMigBanner

Write-Success "Core Framework loaded successfully."

Write-Info "Logging initialized."

Write-Info "ProfMig startup completed."

Stop-ProfMig