function Start-MigrationLog {

    if (!(Test-Path $Global:Config.LogFolder))
    {
        New-Item $Global:Config.LogFolder -ItemType Directory | Out-Null
    }

    $script:LogFile = Join-Path `
        $Global:Config.LogFolder `
        ("Migration_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

}

function Write-Log {

    param(
        [string]$Text
    )

    $Time = Get-Date -Format "HH:mm:ss"

    $Line = "$Time`t$Text"

    Add-Content $script:LogFile $Line

    Write-Host $Text

}

Export-ModuleMember -Function *