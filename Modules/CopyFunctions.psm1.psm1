function Copy-ProfileFolder {

    param(
        [Parameter(Mandatory)]
        [string]$Source,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [string]$Name
    )

    Write-Host ""
    Write-Host ">> $Name" -ForegroundColor Cyan

    if (!(Test-Path $Source))
    {
        Write-Log "$Name : OVERGESLAGEN (bron bestaat niet)"
        return
    }

    if (!(Test-Path $Destination))
    {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    $Arguments = @(
        "`"$Source`"",
        "`"$Destination`"",
        "/E",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/R:1",
        "/W:1",
        "/XJ",
        "/FFT",
        "/MT:16",
        "/NFL",
        "/NDL",
        "/NP",
        "/NJH",
        "/NJS"
    )

    robocopy @Arguments | Out-Null

    switch ($LASTEXITCODE)
    {
        {$_ -lt 8} {
            Write-Log "$Name : OK"
        }

        default {
            Write-Log "$Name : FOUT (Robocopy exitcode $LASTEXITCODE)"
        }
    }
}

Export-ModuleMember -Function *