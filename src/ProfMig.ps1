$Root = Split-Path $MyInvocation.MyCommand.Path

Import-Module "$Root\Modules\Logging.psm1" -Force
Import-Module "$Root\Modules\UserProfiles.psm1" -Force
Import-Module "$Root\Modules\Menu.psm1" -Force
Import-Module "$Root\Modules\CopyFunctions.psm1" -Force

. "$Root\Config.ps1"

Start-MigrationLog

Show-Header

$Users = Get-UserProfiles

if($Users.Count -lt 2)
{
    Write-Host ""
    Write-Host "Er zijn minder dan twee gebruikersprofielen gevonden." -ForegroundColor Red
    pause
    exit
}

$Source = Select-User $Users "Selecteer BRON gebruiker"

$Target = Select-User $Users "Selecteer DOEL gebruiker"

Write-Host ""
Write-Host "=========================================="
Write-Host ""
Write-Host "Bron : $($Source.Name)"
Write-Host "Doel : $($Target.Name)"
Write-Host ""

$Go = Read-Host "Doorgaan (J/N)"

if($Go -ne "J")
{
    exit
}

Write-Log "Bronprofiel : $($Source.FullName)"
Write-Log "Doelprofiel : $($Target.FullName)"

Write-Host ""
Write-Host ""
Write-Host "Migratie gestart..." -ForegroundColor Green

Copy-ProfileFolder `
    -Name "Desktop" `
    -Source "$($Source.FullName)\Desktop" `
    -Destination "$($Target.FullName)\Desktop"

Copy-ProfileFolder `
    -Name "Documenten" `
    -Source "$($Source.FullName)\Documents" `
    -Destination "$($Target.FullName)\Documents"

Copy-ProfileFolder `
    -Name "Downloads" `
    -Source "$($Source.FullName)\Downloads" `
    -Destination "$($Target.FullName)\Downloads"

Copy-ProfileFolder `
    -Name "Afbeeldingen" `
    -Source "$($Source.FullName)\Pictures" `
    -Destination "$($Target.FullName)\Pictures"

Copy-ProfileFolder `
    -Name "Video's" `
    -Source "$($Source.FullName)\Videos" `
    -Destination "$($Target.FullName)\Videos"

Copy-ProfileFolder `
    -Name "Muziek" `
    -Source "$($Source.FullName)\Music" `
    -Destination "$($Target.FullName)\Music"

Copy-ProfileFolder `
    -Name "Favorieten" `
    -Source "$($Source.FullName)\Favorites" `
    -Destination "$($Target.FullName)\Favorites"

Write-Host ""
Write-Host "Migratie voltooid." -ForegroundColor Green
Write-Host ""
Write-Host "Logbestand:"
Write-Host $script:LogFile
Pause