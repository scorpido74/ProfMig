function Stop-Browsers {

    Write-Host ""
    Write-Host "Applicaties afsluiten..." -ForegroundColor Yellow

    $Processes = @(
        "chrome",
        "msedge",
        "firefox",
        "brave",
        "teams",
        "onedrive",
        "outlook"
    )

    foreach($Process in $Processes)
    {
        Get-Process $Process -ErrorAction SilentlyContinue | Stop-Process -Force
    }

    Start-Sleep 2

    Write-Log "Browsers en Office afgesloten"
}

function Copy-BrowserProfile {

    param(
        [string]$Name,
        [string]$Source,
        [string]$Destination
    )

    if(!(Test-Path $Source))
    {
        Write-Log "$Name niet gevonden."
        return
    }

    Write-Host ""
    Write-Host "Migreren $Name..." -ForegroundColor Cyan

    robocopy `
        $Source `
        $Destination `
        /E `
        /COPY:DAT `
        /DCOPY:DAT `
        /R:1 `
        /W:1 `
        /XJ `
        /FFT `
        /MT:16 `
        /XD `
        "Cache" `
        "Code Cache" `
        "GPUCache" `
        "Crashpad" `
        "ShaderCache" `
        "GrShaderCache" `
        "DawnCache" `
        "Service Worker\CacheStorage" `
        "Media Cache" `
        /NFL `
        /NDL `
        /NP `
        /NJH `
        /NJS | Out-Null

    if($LASTEXITCODE -lt 8)
    {
        Write-Log "$Name succesvol gekopieerd."
    }
    else
    {
        Write-Log "$Name foutcode $LASTEXITCODE"
    }

}

Export-ModuleMember *