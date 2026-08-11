<#
Module      : ProfMig.Menu
Description : Interactive menu functions for ProfMig.

The menu consumes structured objects from the ProfMig inventory engine.
Inventory discovery itself remains independent from menu formatting.
#>

Set-StrictMode -Version Latest


function Show-Header {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Configuration
    )

    Clear-Host

    Write-Host ''
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host '        Profile Migration Tool' -ForegroundColor White
    Write-Host '==============================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Version : $($Configuration.Application.Version)"
    Write-Host "Build   : $($Configuration.Application.Build)"
    Write-Host ''
}


function Select-User {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Users,

        [Parameter(Mandatory)]
        [string]$Title
    )

    if ($Users.Count -eq 0) {
        throw 'No user profiles are available for selection.'
    }

    Write-Host ''
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ''

    for ($i = 0; $i -lt $Users.Count; $i++) {

        $user = $Users[$i]

        $account = if ($user.AccountDomain -and $user.AccountName) {
            "$($user.AccountDomain)\$($user.AccountName)"
        }
        elseif ($user.AccountName) {
            $user.AccountName
        }
        else {
            'Unknown account'
        }

        Write-Host (
            '[{0}] {1} | {2} | {3}' -f
            ($i + 1),
            $user.ProfileName,
            $account,
            $user.Status
        )
    }

    Write-Host ''

    do {

        $choice = Read-Host 'Maak een keuze'
        $choiceNumber = 0

        $validChoice = [int]::TryParse(
            $choice,
            [ref]$choiceNumber
        )

    } until (
        $validChoice -and
        $choiceNumber -ge 1 -and
        $choiceNumber -le $Users.Count
    )

    return $Users[$choiceNumber - 1]
}


Export-ModuleMember -Function Show-Header, Select-User