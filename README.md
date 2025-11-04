# Steam Lua

Proste narzędzie do zarządzania Steamem i importu plików manifest oraz lua.

## Funkcje
- Start / Stop / Restart Steam
- Import wielu plików:
  - .manifest → C:\Program Files (x86)\Steam\depotcache
  - .lua → C:\Program Files (x86)\Steam\config\stplug-in
- Ciemny motyw, responsywne okno

## Wymagania
- Windows + PowerShell 5.1+
- Uprawnienia administratora (Import do Program Files)

## Użycie (skrypty)
Uruchom GUI:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File ".\steam-lua-gui.ps1"
```

## Build do EXE (opcjonalnie)
Wymagany moduł ps2exe (instalacja jednorazowa):
```powershell
Install-Module -Name ps2exe -Scope CurrentUser -Force
Import-Module ps2exe
Invoke-PS2EXE -InputFile ".\steam-lua-gui.ps1" -OutputFile ".\Steam lua.exe" -NoConsole -RequireAdmin
```

## Licencja
MIT. Zobacz plik LICENSE.
