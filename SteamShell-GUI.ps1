Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v0.5.0 - Modern Rebirth
$script:AppVersion = '0.5.0'
$script:SteamExeOverride = $null

function Get-SteamExePath {
    if ($script:SteamExeOverride -and (Test-Path $script:SteamExeOverride)) { return $script:SteamExeOverride }
    try {
        $regPaths = @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')
        foreach ($rp in $regPaths) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($name in @('SteamExe', 'SteamPath', 'InstallPath')) {
                    if ($null -ne $k.$name -and [string]::IsNullOrWhiteSpace($k.$name) -eq $false) {
                        $candidate = $k.$name
                        if ($candidate -like '*.exe') { if (Test-Path $candidate) { return $candidate } }
                        else { $exe = Join-Path $candidate 'steam.exe'; if (Test-Path $exe) { return $exe } }
                    }
                }
            }
        }
    } catch { }
    $defaults = @("$env:ProgramFiles (x86)\Steam\steam.exe", "$env:ProgramFiles\Steam\steam.exe", "$env:LOCALAPPDATA\Programs\Steam\steam.exe")
    foreach ($p in $defaults) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found."
}

function Get-SteamInstallDir { try { $p = Get-SteamExePath; Split-Path -Path $p -Parent } catch { return $null } }

function Stop-SteamGracefully {
    param([int]$WaitSeconds = 12, [bool]$ForceClose = $true)
    $steamExe = Get-SteamExePath
    try { & $steamExe -shutdown | Out-Null } catch { }
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do { Start-Sleep -Milliseconds 300; $procs = Get-Process -Name steam, steamwebhelper, SteamService -ErrorAction SilentlyContinue } while ($procs -and (Get-Date) -lt $deadline)
    if ($ForceClose) { $procs = Get-Process -Name steam, steamwebhelper, SteamService -ErrorAction SilentlyContinue; if ($procs) { foreach ($p in $procs) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } } } }
}

function Start-Steam { $steamExe = Get-SteamExePath; Start-Process -FilePath $steamExe -ErrorAction Stop | Out-Null }
function Restart-Steam { Stop-SteamGracefully -WaitSeconds 12 -ForceClose $true; Start-Steam }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Add-Log {
    param([System.Windows.Forms.TextBoxBase]$TextBox, [string]$Message)
    $timestamp = (Get-Date).ToString('HH:mm:ss')
    $TextBox.Invoke([action]{ $TextBox.AppendText("[$timestamp] $Message`r`n") })
}

# UI - MODERN STYLE (v0.5.0)
$colorBg = [System.Drawing.Color]::FromArgb(23, 26, 33)
$colorPanel = [System.Drawing.Color]::FromArgb(27, 40, 56)
$colorAccent = [System.Drawing.Color]::FromArgb(102, 192, 244)
$colorText = [System.Drawing.Color]::FromArgb(199, 213, 224)
$colorBorder = [System.Drawing.Color]::FromArgb(42, 71, 94)
$colorSuccess = [System.Drawing.Color]::FromArgb(163, 207, 6)
$colorError = [System.Drawing.Color]::FromArgb(205, 92, 92)

${form} = New-Object System.Windows.Forms.Form
${form}.Text = "SteamShell v$script:AppVersion"
${form}.Size = New-Object System.Drawing.Size(1060, 680)
${form}.StartPosition = 'CenterScreen'
${form}.BackColor = $colorBg
${form}.ForeColor = $colorText
${form}.Font = New-Object System.Drawing.Font('Segoe UI', 10)
${form}.AllowDrop = $true

function New-SteamButton([string]$text, $color = $null) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.FlatStyle = 'Flat'; $b.Height = 42; $b.Dock = 'Fill'; $b.Margin = New-Object System.Windows.Forms.Padding(4)
    $b.BackColor = if ($color) { $color } else { [System.Drawing.Color]::FromArgb(42, 71, 94) }
    $b.ForeColor = if ($color) { [System.Drawing.Color]::Black } else { [System.Drawing.Color]::White }
    $b.FlatAppearance.BorderSize = 0; $b.Cursor = 'Hand'
    return $b
}

# Layout
$mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
$mainPanel.Dock = 'Fill'; $mainPanel.ColumnCount = 2; $mainPanel.RowCount = 2
$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 72))) | Out-Null
$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 28))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 64))) | Out-Null
$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null

# Top Header
$header = New-Object System.Windows.Forms.TableLayoutPanel
$header.Dock = 'Fill'; $header.ColumnCount = 5; $header.BackColor = $colorPanel; $header.Padding = New-Object System.Windows.Forms.Padding(10)
for($i=0; $i -lt 5; $i++){ $header.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20))) | Out-Null }

$btnStart = New-SteamButton 'START' $colorSuccess; $btnStop = New-SteamButton 'STOP' $colorError
$btnRestart = New-SteamButton 'RESTART'; $btnKill = New-SteamButton 'KILL ALL'; $btnImport = New-SteamButton 'IMPORT' $colorAccent
$header.Controls.AddRange(@($btnStart, $btnStop, $btnRestart, $btnKill, $btnImport))

# Console
$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = 'Fill'; $rtbLog.BackColor = [System.Drawing.Color]::FromArgb(15, 15, 20); $rtbLog.ForeColor = [System.Drawing.Color]::FromArgb(163, 207, 6)
$rtbLog.ReadOnly = $true; $rtbLog.BorderStyle = 'None'; $rtbLog.Font = New-Object System.Drawing.Font('Consolas', 10); $rtbLog.Margin = New-Object System.Windows.Forms.Padding(15)

# Sidebar
$sidebar = New-Object System.Windows.Forms.FlowLayoutPanel
$sidebar.Dock = 'Fill'; $sidebar.FlowDirection = 'TopDown'; $sidebar.WrapContents = $false; $sidebar.Padding = New-Object System.Windows.Forms.Padding(10); $sidebar.BackColor = $colorPanel

function New-Group([string]$title, [int]$height) {
    $g = New-Object System.Windows.Forms.GroupBox; $g.Text = $title; $g.ForeColor = $colorAccent; $g.Width = 260; $g.Height = $height; $g.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 15); return $g
}

$gAcc = New-Group "👤 STEAM ACCOUNTS" 130
$comboAccounts = New-Object System.Windows.Forms.ComboBox; $comboAccounts.Dock = 'Top'; $comboAccounts.DropDownStyle = 'DropDownList'; $comboAccounts.BackColor = $colorBg; $comboAccounts.ForeColor = [System.Drawing.Color]::White; $comboAccounts.FlatStyle = 'Flat'
$btnSwitchAcc = New-SteamButton 'SWITCH ACCOUNT'; $btnSwitchAcc.Dock = 'Bottom'; $btnSwitchAcc.Height = 35
$gAcc.Controls.AddRange(@($comboAccounts, $btnSwitchAcc))

$gOpt = New-Group "⚙️ OPTIONS" 170
$chkBackup = New-Object System.Windows.Forms.CheckBox; $chkBackup.Text = 'Backup files'; $chkBackup.Checked = $true; $chkBackup.Dock = 'Top'; $chkBackup.Height = 30
$chkAlwaysOnTop = New-Object System.Windows.Forms.CheckBox; $chkAlwaysOnTop.Text = 'Always on top'; $chkAlwaysOnTop.Dock = 'Top'; $chkAlwaysOnTop.Height = 30
$lblWait = New-Object System.Windows.Forms.Label; $lblWait.Text = "Wait time (s):"; $lblWait.Dock = 'Left'; $lblWait.Width = 90
$numWait = New-Object System.Windows.Forms.NumericUpDown; $numWait.Minimum = 4; $numWait.Value = 12; $numWait.BackColor = $colorBg; $numWait.ForeColor = [System.Drawing.Color]::White; $numWait.Dock = 'Right'; $numWait.Width = 60
$pnlWait = New-Object System.Windows.Forms.Panel; $pnlWait.Dock = 'Top'; $pnlWait.Height = 30; $pnlWait.Controls.AddRange(@($lblWait, $numWait))
$gOpt.Controls.AddRange(@($chkBackup, $chkAlwaysOnTop, $pnlWait))

$gQuick = New-Group "🛠️ QUICK ACCESS" 200
$btnOpenDepot = New-SteamButton 'DEPOT FOLDER'; $btnOpenLua = New-SteamButton 'LUA FOLDER'
$btnRevealConfig = New-SteamButton 'CONFIG FOLDER'; $btnAbout = New-SteamButton 'ABOUT'
$layQuick = New-Object System.Windows.Forms.TableLayoutPanel; $layQuick.Dock = 'Fill'; $layQuick.ColumnCount = 1; $layQuick.RowCount = 4
$layQuick.Controls.AddRange(@($btnOpenDepot, $btnOpenLua, $btnRevealConfig, $btnAbout))
$gQuick.Controls.Add($layQuick)

$sidebar.Controls.AddRange(@($gAcc, $gOpt, $gQuick))

$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor = $colorBg; $statusStrip.ForeColor = [System.Drawing.Color]::Silver
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel; $statusLabel.Text = "Ready • v$script:AppVersion"; $statusStrip.Items.Add($statusLabel) | Out-Null
$statusSteam = New-Object System.Windows.Forms.ToolStripStatusLabel; $statusSteam.Alignment = 'Right'; $statusSteam.Text = "STEAM: CHECKING..."; $statusStrip.Items.Add($statusSteam) | Out-Null

$mainPanel.Controls.Add($header, 0, 0); $mainPanel.SetColumnSpan($header, 2)
$mainPanel.Controls.Add($rtbLog, 0, 1); $mainPanel.Controls.Add($sidebar, 1, 1)
${form}.Controls.AddRange(@($mainPanel, $statusStrip))

# Logic
function Get-SteamAccounts {
    $accounts = @(); $steamDir = Get-SteamInstallDir; if ($null -eq $steamDir) { return $accounts }
    $vdf = Join-Path $steamDir "config\loginusers.vdf"
    if (Test-Path $vdf) {
        $current = $null
        foreach ($line in (Get-Content $vdf)) {
            if ($line -match '^\s*"(\d+)"') { $current = [PSCustomObject]@{ id = $matches[1]; name = ""; persona = "" } }
            elseif ($line -match '"AccountName"\s+"([^"]+)"' -and $current) { $current.name = $matches[1] }
            elseif ($line -match '"PersonaName"\s+"([^"]+)"' -and $current) { $current.persona = $matches[1] }
            elseif ($line -match '^\s*}' -and $current) { if ($current.name) { $accounts += $current }; $current = $null }
        }
    }
    return $accounts
}

function Refresh-Accounts {
    $comboAccounts.Items.Clear(); $script:AccList = Get-SteamAccounts
    foreach ($a in $script:AccList) { $null = $comboAccounts.Items.Add("$($a.persona) ($($a.name))") }
    if ($comboAccounts.Items.Count -gt 0) {
        $comboAccounts.SelectedIndex = 0; $curr = (Get-ItemProperty "HKCU:\Software\Valve\Steam").AutoLoginUser
        if ($curr) { for($i=0; $i -lt $script:AccList.Count; $i++) { if ($script:AccList[$i].name -eq $curr) { $comboAccounts.SelectedIndex = $i; break } } }
    }
}

function Import-Files($ps) {
    $dManifest = 'C:\Program Files (x86)\Steam\depotcache'; $dLua = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dManifest)) { New-Item $dManifest -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dLua)) { New-Item $dLua -ItemType Directory -Force | Out-Null }
    foreach ($p in $ps) {
        $ext = [System.IO.Path]::GetExtension($p).ToLower(); $dstD = if ($ext -eq ".manifest") { $dManifest } elseif ($ext -eq ".lua") { $dLua }
        if ($dstD) {
            $dest = Join-Path $dstD ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.Checked -and (Test-Path $dest)) { Copy-Item $dest ($dest + ".bak") -Force }
            Copy-Item -LiteralPath $p -Destination $dest -Force
            Add-Log -TextBox $rtbLog -Message "Imported: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

function Check-Updates {
    try {
        $l = Invoke-RestMethod "https://api.github.com/repos/kozaaaaczx/steam-lua/releases/latest" -ErrorAction SilentlyContinue
        if ($l.tag_name -match '(\d+\.\d+\.\d+)') {
            if ([version]$matches[1] -gt [version]$script:AppVersion) {
                if ([System.Windows.Forms.MessageBox]::Show("New version available! Install?", "Update", 4, 32) -eq 6) { Start-Process "https://github.com/kozaaaaczx/steam-lua/releases/latest" }
            }
        }
    } catch {}
}

# Events
$btnStart.Add_Click({ Start-Steam; Add-Log $rtbLog "Steam started." })
$btnStop.Add_Click({ Stop-SteamGracefully ([int]$numWait.Value); Add-Log $rtbLog "Steam stopped." })
$btnRestart.Add_Click({ Restart-Steam; Add-Log $rtbLog "Steam restarted." })
$btnKill.Add_Click({ Get-Process steam, steamwebhelper -ErrorAction SilentlyContinue | Stop-Process -Force; Add-Log $rtbLog "Killed all." })
$btnImport.Add_Click({ 
    $d = New-Object System.Windows.Forms.OpenFileDialog; $d.Multiselect = $true; $d.Filter = "Files (*.manifest, *.lua)|*.manifest;*.lua"
    if ($d.ShowDialog() -eq 1) { Import-Files $d.FileNames; Add-Log $rtbLog "Import done." }
})
$btnSwitchAcc.Add_Click({
    if ($comboAccounts.SelectedIndex -ge 0) {
        $a = $script:AccList[$comboAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "RememberPassword" -Value 1
        Add-Log $rtbLog "Switched to $($a.name). Restarting..."; Restart-Steam
    }
})
${form}.Add_DragEnter({ if ($_.Data.GetDataPresent('FileDrop')) { $_.Effect = 'Copy' } })
${form}.Add_DragDrop({ $fs = $_.Data.GetData('FileDrop'); Import-Files $fs; if([System.Windows.Forms.MessageBox]::Show("Restart Steam?", "Done", 4, 32) -eq 6){ Restart-Steam } })
$chkAlwaysOnTop.Add_CheckedChanged({ ${form}.TopMost = $chkAlwaysOnTop.Checked })
$btnAbout.Add_Click({ [System.Windows.Forms.MessageBox]::Show("SteamShell v$script:AppVersion`n`nGitHub: https://github.com/kozaaaaczx/steam-lua", "About", 0, 64) })

# Init
Refresh-Accounts
$timerStatus = New-Object System.Windows.Forms.Timer; $timerStatus.Interval = 3000
$timerStatus.Add_Tick({ 
    $procs = Get-Process steam -ErrorAction SilentlyContinue
    if ($procs) { $statusSteam.Text = "STEAM: RUNNING"; $statusSteam.ForeColor = $colorSuccess } else { $statusSteam.Text = "STEAM: STOPPED"; $statusSteam.ForeColor = $colorError }
})
$timerStatus.Start()

$timerUpd = New-Object System.Windows.Forms.Timer; $timerUpd.Interval = 3000
$timerUpd.Add_Tick({ param($s,$e) $s.Stop(); Check-Updates })
$timerUpd.Start()

[void]${form}.ShowDialog()