# Steam Lua

A simple tool to manage Steam and import manifest/lua files.

## Features
- Start / Stop / Restart Steam
- Import multiple files at once
  - .manifest → C:\Program Files (x86)\Steam\depotcache
  - .lua → C:\Program Files (x86)\Steam\config\stplug-in
- Dark theme, resizable window

## Requirements
- Windows with PowerShell 5.1+
- Administrator privileges (required to write under Program Files)

## Usage (scripts)
Launch the GUI:
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -STA -File ".\steam-lua-gui.ps1"
```

## Build EXE (optional)
Requires the `ps2exe` module (one-time install):
```powershell
Install-Module -Name ps2exe -Scope CurrentUser -Force
Import-Module ps2exe
Invoke-PS2EXE -InputFile ".\steam-lua-gui.ps1" -OutputFile ".\Steam lua.exe" -NoConsole -RequireAdmin
```

## License
MIT. See LICENSE for details.
