$Root = Split-Path -Parent $PSCommandPath

Import-Module "$Root\Modules\ProfMig.Core.psm1" -Force
Import-Module "$Root\Modules\ProfMig.Logging.psm1" -Force

$null = Initialize-ProfMig
$LogFolder = Join-Path $Root "..\logs"

Initialize-Logging -LogFolder $LogFolder | Out-Null

Test-ProfMigEnvironment

Show-ProfMigBanner

Write-Success "Core Framework loaded successfully."

Write-Info "Logging initialized."

Write-Info "ProfMig startup completed."

Stop-ProfMig