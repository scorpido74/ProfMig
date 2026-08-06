function Show-Header {

    Clear-Host

    Write-Host ""
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "        Profile Migration Tool" -ForegroundColor White
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version : $($Global:Config.Version)"
    Write-Host ""

}

function Select-User {

    param(
        $Users,
        $Title
    )

    Write-Host ""
    Write-Host $Title
    Write-Host ""

    $i = 1

    foreach($User in $Users)
    {
        Write-Host ("[{0}] {1}" -f $i,$User.Name)
        $i++
    }

    Write-Host ""

    do{

        $Choice = Read-Host "Maak een keuze"

    } until ($Choice -as [int] -and
             $Choice -ge 1 -and
             $Choice -le $Users.Count)

    return $Users[$Choice-1]

}

Export-ModuleMember -Function *