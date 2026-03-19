Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Steam functions (embedded so the EXE is self-contained)
$script:AppVersion = '0.3.0'
$script:SteamExeOverride = $null

function Get-SteamExePath {
    if ($script:SteamExeOverride -and (Test-Path $script:SteamExeOverride)) {
        return $script:SteamExeOverride
    }
    try {
        $regPaths = @(
            'HKCU:\Software\Valve\Steam',
            'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam',
            'HKLM:\SOFTWARE\Valve\Steam'
        )
        foreach ($rp in $regPaths) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($name in @('SteamExe', 'SteamPath', 'InstallPath')) {
                    if ($null -ne $k.$name -and [string]::IsNullOrWhiteSpace($k.$name) -eq $false) {
                        $candidate = $k.$name
                        if ($candidate -like '*.exe') {
                            if (Test-Path $candidate) { return $candidate }
                        }
                        else {
                            $exe = Join-Path $candidate 'steam.exe'
                            if (Test-Path $exe) { return $exe }
                        }
                    }
                }
            }
        }
    }
    catch { }

    $defaults = @(
        "$env:ProgramFiles (x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe",
        "$env:LOCALAPPDATA\Programs\Steam\steam.exe"
    )
    foreach ($p in $defaults) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found. Install Steam or provide the path manually."
}

function Get-SteamInstallDir {
    $steamExe = Get-SteamExePath
    return Split-Path -Path $steamExe -Parent
}

function Stop-SteamGracefully {
    param(
        [int]$WaitSeconds = 12,
        [bool]$ForceClose = $true
    )
    $steamExe = Get-SteamExePath
    try { & $steamExe -shutdown | Out-Null } catch { }
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        Start-Sleep -Milliseconds 300
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    } while ($procs -and (Get-Date) -lt $deadline)
    
    if ($ForceClose) {
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } }
        }
    }
}

function Start-Steam {
    $steamExe = Get-SteamExePath
    Start-Process -FilePath $steamExe -ErrorAction Stop | Out-Null
}

function Restart-Steam {
    Stop-SteamGracefully -WaitSeconds 12 -ForceClose $true
    Start-Steam
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Add-Log {
    param(
        [System.Windows.Forms.TextBoxBase]$TextBox,
        [string]$Message
    )
    $timestamp = (Get-Date).ToString('HH:mm:ss')
    $TextBox.AppendText("[$timestamp] $Message`r`n")
}

# UI
${form} = New-Object System.Windows.Forms.Form
${form}.Text = "SteamShell v$script:AppVersion"
${form}.Size = New-Object System.Drawing.Size(1020, 600)
${form}.StartPosition = 'CenterScreen'
${form}.MaximizeBox = $true
${form}.FormBorderStyle = 'Sizable'
${form}.MinimumSize = New-Object System.Drawing.Size(900, 540)
${form}.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
${form}.ForeColor = [System.Drawing.Color]::White
${form}.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$colorSurface = [System.Drawing.Color]::FromArgb(28, 28, 32)
$colorSurfaceAlt = [System.Drawing.Color]::FromArgb(20, 20, 24)
$colorAccent = [System.Drawing.Color]::FromArgb(88, 153, 255)
$colorBorder = [System.Drawing.Color]::FromArgb(62, 62, 66)
$colorSuccess = [System.Drawing.Color]::FromArgb(80, 200, 120)
$colorError = [System.Drawing.Color]::FromArgb(255, 100, 100)

function New-DarkButton([string]$text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderColor = $colorBorder
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(63, 63, 70)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(51, 51, 55)
    return $b
}

function New-AccentButton([string]$text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6, 0, 6, 0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = $colorAccent
    $b.ForeColor = [System.Drawing.Color]::Black
    $b.FlatAppearance.BorderColor = $colorAccent
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(109, 170, 255)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(72, 137, 240)
    return $b
}

## Top bar: TableLayoutPanel with buttons
$topPanel = New-Object System.Windows.Forms.TableLayoutPanel
$topPanel.ColumnCount = 5
$topPanel.RowCount = 1
$topPanel.Dock = 'Top'
$topPanel.Height = 56
$topPanel.Padding = New-Object System.Windows.Forms.Padding(12, 12, 12, 6)
$topPanel.BackColor = $colorSurface
for ($i = 0; $i -lt 5; $i++) { $null = $topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 20))) }

$btnStart = New-DarkButton 'Start'
$btnStop = New-DarkButton 'Stop'
$btnRestart = New-DarkButton 'Restart'
$btnKill = New-DarkButton 'Kill All'
$btnKill.ForeColor = $colorError
$btnImport = New-AccentButton 'Import'

$topPanel.Controls.Add($btnStart, 0, 0)
$topPanel.Controls.Add($btnStop, 1, 0)
$topPanel.Controls.Add($btnRestart, 2, 0)
$topPanel.Controls.Add($btnKill, 3, 0)
$topPanel.Controls.Add($btnImport, 4, 0)

## Main layout
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.ColumnCount = 2
$mainLayout.RowCount = 2
$mainLayout.Dock = 'Fill'
[void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 62)))
[void]$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
[void]$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 70)))
[void]$mainLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 30)))

## Log
$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = 'Fill'
$rtbLog.Margin = New-Object System.Windows.Forms.Padding(12, 6, 12, 0)
$rtbLog.ReadOnly = $true
$rtbLog.Font = New-Object System.Drawing.Font('Consolas', 10)
$rtbLog.BackColor = $colorSurfaceAlt
$rtbLog.ForeColor = [System.Drawing.Color]::Gainsboro
$rtbLog.BorderStyle = 'None'
$rtbLog.DetectUrls = $false

## Right panel
$sidePanel = New-Object System.Windows.Forms.Panel
$sidePanel.Dock = 'Fill'
$sidePanel.BackColor = $colorSurface
$sidePanel.Padding = New-Object System.Windows.Forms.Padding(0, 8, 12, 8)

$sideLayout = New-Object System.Windows.Forms.TableLayoutPanel
$sideLayout.Dock = 'Fill'
$sideLayout.ColumnCount = 1
$sideLayout.RowCount = 3
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 240)))
[void]$sideLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

# Group Steam Path
$groupSteam = New-Object System.Windows.Forms.GroupBox
$groupSteam.Text = 'Steam Configuration'
$groupSteam.Dock = 'Fill'
$groupSteam.BackColor = $colorSurface
$groupSteam.ForeColor = [System.Drawing.Color]::Gainsboro
$groupSteam.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)

$steamLayout = New-Object System.Windows.Forms.TableLayoutPanel
$steamLayout.Dock = 'Fill'
$steamLayout.ColumnCount = 2
$steamLayout.RowCount = 3
[void]$steamLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
[void]$steamLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))

$labelSteamPath = New-Object System.Windows.Forms.Label
$labelSteamPath.Text = 'Auto-detecting...'
$labelSteamPath.Dock = 'Top'
$labelSteamPath.AutoEllipsis = $true
$labelSteamPath.ForeColor = [System.Drawing.Color]::Silver

$btnBrowseSteam = New-DarkButton 'Browse'
$btnOpenSteamFolder = New-DarkButton 'Folder'

$steamLayout.Controls.Add($labelSteamPath, 0, 0)
$steamLayout.SetColumnSpan($labelSteamPath, 2)
$steamLayout.Controls.Add($btnBrowseSteam, 0, 1)
$steamLayout.Controls.Add($btnOpenSteamFolder, 1, 1)
$groupSteam.Controls.Add($steamLayout)

# Group Import Options
$groupImport = New-Object System.Windows.Forms.GroupBox
$groupImport.Text = 'Import Options'
$groupImport.Dock = 'Fill'
$groupImport.BackColor = $colorSurface
$groupImport.ForeColor = [System.Drawing.Color]::Gainsboro
$groupImport.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)

$importLayout = New-Object System.Windows.Forms.TableLayoutPanel
$importLayout.Dock = 'Fill'
$importLayout.ColumnCount = 2
$importLayout.RowCount = 6
for ($i = 0; $i -lt 6; $i++) { [void]$importLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28))) }

$chkManifest = New-Object System.Windows.Forms.CheckBox
$chkManifest.Text = 'Manifests'
$chkManifest.Checked = $true
$chkManifest.Dock = 'Fill'

$chkLua = New-Object System.Windows.Forms.CheckBox
$chkLua.Text = 'Lua Scripts'
$chkLua.Checked = $true
$chkLua.Dock = 'Fill'

$chkBackup = New-Object System.Windows.Forms.CheckBox
$chkBackup.Text = 'Backup before overwrite'
$chkBackup.Checked = $true
$chkBackup.Dock = 'Fill'
$chkBackup.ForeColor = $colorAccent

$labelWait = New-Object System.Windows.Forms.Label
$labelWait.Text = 'Shutdown wait (s)'
$labelWait.Dock = 'Fill'
$numWait = New-Object System.Windows.Forms.NumericUpDown
$numWait.Minimum = 4; $numWait.Maximum = 60; $numWait.Value = 12
$numWait.BackColor = $colorSurfaceAlt; $numWait.ForeColor = [System.Drawing.Color]::White

$chkAlwaysOnTop = New-Object System.Windows.Forms.CheckBox
$chkAlwaysOnTop.Text = 'Always on top'
$chkAlwaysOnTop.Dock = 'Fill'

$importLayout.Controls.Add($chkManifest, 0, 0)
$importLayout.Controls.Add($chkLua, 1, 0)
$importLayout.Controls.Add($chkBackup, 0, 1)
$importLayout.SetColumnSpan($chkBackup, 2)
$importLayout.Controls.Add($labelWait, 0, 2)
$importLayout.Controls.Add($numWait, 1, 2)
$importLayout.Controls.Add($chkAlwaysOnTop, 0, 3)

$groupImport.Controls.Add($importLayout)

# Group Quick Actions
$groupQuick = New-Object System.Windows.Forms.GroupBox
$groupQuick.Text = 'Quick Actions'
$groupQuick.Dock = 'Fill'
$groupQuick.BackColor = $colorSurface
$groupQuick.ForeColor = [System.Drawing.Color]::Gainsboro
$groupQuick.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)

$quickLayout = New-Object System.Windows.Forms.TableLayoutPanel
$quickLayout.Dock = 'Fill'
$quickLayout.ColumnCount = 2
$quickLayout.RowCount = 4
for ($i = 0; $i -lt 4; $i++) { [void]$quickLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34))) }

$btnOpenDepot = New-DarkButton 'Depot cache'
$btnOpenLua = New-DarkButton 'ST Plug-in'
$btnClearLog = New-DarkButton 'Clear log'
$btnSaveLog = New-DarkButton 'Save log'
$btnRevealConfig = New-DarkButton 'Config'
$btnAbout = New-DarkButton 'About'

$quickLayout.Controls.Add($btnOpenDepot, 0, 0)
$quickLayout.Controls.Add($btnOpenLua, 1, 0)
$quickLayout.Controls.Add($btnClearLog, 0, 1)
$quickLayout.Controls.Add($btnSaveLog, 1, 1)
$quickLayout.Controls.Add($btnRevealConfig, 0, 2)
$quickLayout.Controls.Add($btnAbout, 1, 2)

$groupQuick.Controls.Add($quickLayout)

$sideLayout.Controls.AddRange(@($groupSteam, $groupImport, $groupQuick))
$sidePanel.Controls.Add($sideLayout)

## Status strip
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.BackColor = $colorSurface
$statusStrip.ForeColor = [System.Drawing.Color]::White

$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "SteamShell v$script:AppVersion • Ready"
$statusStrip.Items.Add($statusLabel) | Out-Null

$statusSteam = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusSteam.Alignment = [System.Windows.Forms.ToolStripItemAlignment]::Right
$statusSteam.Text = "STEAM: CHECKING..."
$statusStrip.Items.Add($statusSteam) | Out-Null

$mainLayout.Controls.Add($rtbLog, 0, 1)
$mainLayout.Controls.Add($sidePanel, 1, 1)
${form}.Controls.AddRange(@($mainLayout, $topPanel, $statusStrip))

# Timer for Steam Status
$timerStatus = New-Object System.Windows.Forms.Timer
$timerStatus.Interval = 3000

function Update-SteamStatus {
    $procs = Get-Process -Name steam -ErrorAction SilentlyContinue
    if ($procs) {
        $statusSteam.Text = "STEAM: RUNNING"
        $statusSteam.ForeColor = $colorSuccess
    } else {
        $statusSteam.Text = "STEAM: STOPPED"
        $statusSteam.ForeColor = $colorError
    }
}

$timerStatus.Add_Tick({ Update-SteamStatus })

# Logic
function Set-UiBusy($busy) {
    foreach ($ctrl in @($btnStart, $btnStop, $btnRestart, $btnKill, $btnImport)) { $ctrl.Enabled = -not $busy }
    $statusLabel.Text = if ($busy) { "Working... • v$script:AppVersion" } else { "Ready • v$script:AppVersion" }
}

function Update-SteamPathLabel {
    try { $labelSteamPath.Text = Get-SteamExePath } catch { $labelSteamPath.Text = 'Not found' }
}

function Open-Folder([string]$path, [string]$label) {
    if (-not (Test-Path $path)) { Add-Log -TextBox $rtbLog -Message "Missing folder: $path"; return }
    Add-Log -TextBox $rtbLog -Message "Opening $label..."
    Start-Process -FilePath $path | Out-Null
}

function Backup-File([string]$filePath) {
    if (Test-Path $filePath) {
        $bakPath = $filePath + ".bak"
        Copy-Item -LiteralPath $filePath -Destination $bakPath -Force
        return $true
    }
    return $false
}

# Handlers
$btnStart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Starting Steam...'
        Start-Steam
        Add-Log -TextBox $rtbLog -Message 'Steam start command sent.'
    } catch { Add-Log -TextBox $rtbLog -Message "Error: $($_.Exception.Message)" }
    finally { Set-UiBusy $false; Update-SteamStatus }
})

$btnStop.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Closing Steam gracefully...'
        Stop-SteamGracefully -WaitSeconds ([int]$numWait.Value) -ForceClose $false
        Add-Log -TextBox $rtbLog -Message 'Steam closed.'
    } catch { Add-Log -TextBox $rtbLog -Message "Error: $($_.Exception.Message)" }
    finally { Set-UiBusy $false; Update-SteamStatus }
})

$btnRestart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Restarting Steam...'
        Restart-Steam
        Add-Log -TextBox $rtbLog -Message 'Restart completed.'
    } catch { Add-Log -TextBox $rtbLog -Message "Error: $($_.Exception.Message)" }
    finally { Set-UiBusy $false; Update-SteamStatus }
})

$btnKill.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Killing all Steam processes...'
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
        if ($procs) {
            foreach ($p in $procs) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
            Add-Log -TextBox $rtbLog -Message "Killed $($procs.Count) processes."
        } else {
            Add-Log -TextBox $rtbLog -Message "No Steam processes found."
        }
    } catch { Add-Log -TextBox $rtbLog -Message "Error: $($_.Exception.Message)" }
    finally { Set-UiBusy $false; Update-SteamStatus }
})

$btnImport.Add_Click({
    try {
        Set-UiBusy $true
        if (-not $chkManifest.Checked -and -not $chkLua.Checked) {
            Add-Log -TextBox $rtbLog -Message 'Select at least one import type.'; return
        }

        $manifestSrcs = @(); $luaSrcs = @()
        if ($chkManifest.Checked) {
            $d = New-Object System.Windows.Forms.OpenFileDialog
            $d.Title = 'Select .manifest files'; $d.Filter = 'Manifest (*.manifest)|*.manifest'; $d.Multiselect = $true
            if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $manifestSrcs = @($d.FileNames) } else { return }
        }
        if ($chkLua.Checked) {
            $d = New-Object System.Windows.Forms.OpenFileDialog
            $d.Title = 'Select .lua files'; $d.Filter = 'Lua (*.lua)|*.lua'; $d.Multiselect = $true
            if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $luaSrcs = @($d.FileNames) } else { return }
        }

        $manifestDstDir = 'C:\Program Files (x86)\Steam\depotcache'
        $luaDstDir = 'C:\Program Files (x86)\Steam\config\stplug-in'

        if (-not (Test-Path $manifestDstDir)) { New-Item -ItemType Directory -Path $manifestDstDir -Force | Out-Null }
        if (-not (Test-Path $luaDstDir)) { New-Item -ItemType Directory -Path $luaDstDir -Force | Out-Null }

        if ($manifestSrcs.Count -gt 0) {
            Add-Log -TextBox $rtbLog -Message "Importing manifests ($($manifestSrcs.Count))..."
            foreach ($src in $manifestSrcs) {
                $dst = Join-Path $manifestDstDir ([System.IO.Path]::GetFileName($src))
                if ($chkBackup.Checked) { Backup-File $dst }
                Copy-Item -LiteralPath $src -Destination $dst -Force
            }
        }

        if ($luaSrcs.Count -gt 0) {
            Add-Log -TextBox $rtbLog -Message "Importing lua scripts ($($luaSrcs.Count))..."
            foreach ($src in $luaSrcs) {
                $dst = Join-Path $luaDstDir ([System.IO.Path]::GetFileName($src))
                if ($chkBackup.Checked) { Backup-File $dst }
                Copy-Item -LiteralPath $src -Destination $dst -Force
            }
        }
        Add-Log -TextBox $rtbLog -Message 'Import successful.'
    } catch { Add-Log -TextBox $rtbLog -Message "Import Error: $($_.Exception.Message)" }
    finally { Set-UiBusy $false }
})

$btnBrowseSteam.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Title = 'Select steam.exe'; $d.Filter = 'Steam (steam.exe)|steam.exe'
    if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $script:SteamExeOverride = $d.FileName
        Update-SteamPathLabel
        Add-Log -TextBox $rtbLog -Message "Path override: $($d.FileName)"
    }
})

$btnOpenSteamFolder.Add_Click({ try { Open-Folder -path (Get-SteamInstallDir) -label 'Steam' } catch { } })
$btnOpenDepot.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\depotcache' -label 'depotcache' })
$btnOpenLua.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\config\stplug-in' -label 'stplug-in' })
$btnRevealConfig.Add_Click({ Open-Folder -path 'C:\Program Files (x86)\Steam\config' -label 'config' })
$btnClearLog.Add_Click({ $rtbLog.Clear() })
$btnAlwaysOnTop.Add_CheckedChanged({ ${form}.TopMost = $chkAlwaysOnTop.Checked })
$btnAbout.Add_Click({
    $msg = "SteamShell v$script:AppVersion`n`nNew Features in v0.3.0:`n- Steam Status Monitor`n- Backup before Import`n- Kill All processes`n- Stability improvements`n`nGitHub: https://github.com/kozaaaaczx/steam-lua"
    [System.Windows.Forms.MessageBox]::Show($msg, 'About SteamShell', 0, 64) | Out-Null
})

# Init
Update-SteamPathLabel
Update-SteamStatus
$timerStatus.Start()

[void]${form}.ShowDialog()