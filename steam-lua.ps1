param(
    [ValidateSet("Restart","Stop","Start")]
    [string]$Action = "Restart"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-SteamExePath {
    try {
        $regPaths = @(
            'HKCU:\Software\Valve\Steam',
            'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
            'HKLM:\SOFTWARE\Valve\Steam'
        )
        foreach ($rp in $regPaths) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($name in @('SteamExe','SteamPath','InstallPath')) {
                    if ($null -ne $k.$name -and [string]::IsNullOrWhiteSpace($k.$name) -eq $false) {
                        $candidate = $k.$name
                        if ($candidate -like '*.exe') {
                            if (Test-Path $candidate) { return $candidate }
                        } else {
                            $exe = Join-Path $candidate 'steam.exe'
                            if (Test-Path $exe) { return $exe }
                        }
                    }
                }
            }
        }
    } catch {
        # ignore, fall through
    }

    # Fallback to common default paths
    $defaults = @(
        "$env:ProgramFiles (x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe",
        "$env:LOCALAPPDATA\Programs\Steam\steam.exe"
    )
    foreach ($p in $defaults) {
        if (Test-Path $p) { return $p }
    }

    throw "Nie znaleziono pliku steam.exe. Zainstaluj Steam lub podaj ścieżkę ręcznie."
}

function Stop-SteamGracefully {
    param(
        [int]$WaitSeconds = 12
    )
    $steamExe = Get-SteamExePath

    Write-Host "Zamykanie Steam (grzecznie)..." -ForegroundColor Cyan
    try { & $steamExe -shutdown | Out-Null } catch { }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        Start-Sleep -Milliseconds 300
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    } while ($procs -and (Get-Date) -lt $deadline)

    $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    if ($procs) {
        Write-Host "Wymuszanie zamknięcia pozostałych procesów Steam..." -ForegroundColor Yellow
        foreach ($p in $procs) {
            try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { }
        }
    }
}

function Start-Steam {
    $steamExe = Get-SteamExePath
    Write-Host "Uruchamianie Steam..." -ForegroundColor Green
    Start-Process -FilePath $steamExe -ErrorAction Stop | Out-Null
}

function Restart-Steam {
    Stop-SteamGracefully -WaitSeconds 12
    Start-Steam
    Write-Host "Steam został zrestartowany." -ForegroundColor Green
}

# Wykonuj akcję tylko przy bezpośrednim uruchomieniu skryptu (nie przy dot-sourcowaniu w GUI)
if ($MyInvocation.InvocationName -ne '.') {
    switch ($Action) {
        'Stop'    { Stop-SteamGracefully; break }
        'Start'   { Start-Steam; break }
        'Restart' { Restart-Steam; break }
        default   { throw "Nieznana akcja: $Action" }
    }
}
