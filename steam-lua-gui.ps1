Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Steam functions (embedded so the EXE is self-contained)
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
    } catch { }

    $defaults = @(
        "$env:ProgramFiles (x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe",
        "$env:LOCALAPPDATA\Programs\Steam\steam.exe"
    )
    foreach ($p in $defaults) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found. Install Steam or provide the path manually."
}

function Stop-SteamGracefully {
    param([int]$WaitSeconds = 12)
    $steamExe = Get-SteamExePath
    try { & $steamExe -shutdown | Out-Null } catch { }
    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    do {
        Start-Sleep -Milliseconds 300
        $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    } while ($procs -and (Get-Date) -lt $deadline)
    $procs = Get-Process -Name steam, steamwebhelper, SteamService, SteamBootstrapper -ErrorAction SilentlyContinue
    if ($procs) { foreach ($p in $procs) { try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { } } }
}

function Start-Steam {
    $steamExe = Get-SteamExePath
    Start-Process -FilePath $steamExe -ErrorAction Stop | Out-Null
}

function Restart-Steam {
    Stop-SteamGracefully -WaitSeconds 12
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
${form}            = New-Object System.Windows.Forms.Form
${form}.Text       = 'Steam lua'
${form}.Size       = New-Object System.Drawing.Size(720, 380)
${form}.StartPosition= 'CenterScreen'
${form}.MaximizeBox= $true
${form}.FormBorderStyle = 'Sizable'
${form}.MinimumSize = New-Object System.Drawing.Size(640, 360)
${form}.BackColor   = [System.Drawing.Color]::FromArgb(24,24,28)
${form}.ForeColor   = [System.Drawing.Color]::White
${form}.Font        = New-Object System.Drawing.Font('Segoe UI', 9)

## Top bar: TableLayoutPanel with buttons
$topPanel = New-Object System.Windows.Forms.TableLayoutPanel
$topPanel.ColumnCount = 4
$topPanel.RowCount = 1
$topPanel.Dock = 'Top'
$topPanel.Height = 56
$topPanel.Padding = New-Object System.Windows.Forms.Padding(12,12,12,6)
$topPanel.BackColor = [System.Drawing.Color]::FromArgb(28,28,32)
for ($i=0; $i -lt 4; $i++) { $null = $topPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25))) }

function New-DarkButton([string]$text){
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text
    $b.Dock = 'Fill'
    $b.Margin = New-Object System.Windows.Forms.Padding(6,0,6,0)
    $b.FlatStyle = 'Flat'
    $b.BackColor = [System.Drawing.Color]::FromArgb(45,45,48)
    $b.ForeColor = [System.Drawing.Color]::White
    $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(62,62,66)
    $b.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(63,63,70)
    $b.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::FromArgb(51,51,55)
    return $b
}

$btnStart   = New-DarkButton 'Start'
$btnStop    = New-DarkButton 'Stop'
$btnRestart = New-DarkButton 'Restart'
$btnImport  = New-DarkButton 'Import'

$topPanel.Controls.Add($btnStart,0,0)
$topPanel.Controls.Add($btnStop,1,0)
$topPanel.Controls.Add($btnRestart,2,0)
$topPanel.Controls.Add($btnImport,3,0)

## Log as RichTextBox filling the client area
$rtbLog = New-Object System.Windows.Forms.RichTextBox
$rtbLog.Dock = 'Fill's
$rtbLog.Margin = New-Object System.Windows.Forms.Padding(12,6,12,0)
$rtbLog.ReadOnly = $true
$rtbLog.Font = New-Object System.Drawing.Font('Consolas', 10)
$rtbLog.BackColor = [System.Drawing.Color]::FromArgb(18,18,22)
$rtbLog.ForeColor = [System.Drawing.Color]::Gainsboro
$rtbLog.BorderStyle = 'None'
$rtbLog.DetectUrls = $false

## Status strip at bottom
$statusStrip = New-Object System.Windows.Forms.StatusStrip
$statusStrip.SizingGrip = $true
$statusStrip.BackColor = [System.Drawing.Color]::FromArgb(28,28,32)
$statusStrip.ForeColor = [System.Drawing.Color]::White
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = 'Ready'
$statusStrip.Items.Add($statusLabel) | Out-Null

${form}.Controls.AddRange(@($rtbLog, $topPanel, $statusStrip))

function Set-UiBusy($busy) {
    $btnStart.Enabled   = -not $busy
    $btnStop.Enabled    = -not $busy
    $btnRestart.Enabled = -not $busy
    $btnImport.Enabled  = -not $busy
    if ($busy) { $statusLabel.Text = 'Working...' } else { $statusLabel.Text = 'Ready' }
}

# Handlery
$btnStart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Starting Steam...'
        Start-Steam
        Add-Log -TextBox $rtbLog -Message 'Steam started.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnStop.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Closing Steam...'
        Stop-SteamGracefully -WaitSeconds 12
        Add-Log -TextBox $rtbLog -Message 'Steam closed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnRestart.Add_Click({
    try {
        Set-UiBusy $true
        Add-Log -TextBox $rtbLog -Message 'Restarting Steam...'
        Restart-Steam
        Add-Log -TextBox $rtbLog -Message 'Restart completed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

$btnImport.Add_Click({
    try {
        Set-UiBusy $true
        $manifestDialog = New-Object System.Windows.Forms.OpenFileDialog
        $manifestDialog.Title = 'Select .manifest files'
        $manifestDialog.Filter = 'Manifest (*.manifest)|*.manifest'
        $manifestDialog.CheckFileExists = $true
        $manifestDialog.Multiselect = $true
        if ($manifestDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Add-Log -TextBox $rtbLog -Message 'Import cancelled (manifest).'
            return
        }

        $luaDialog = New-Object System.Windows.Forms.OpenFileDialog
        $luaDialog.Title = 'Select .lua files'
        $luaDialog.Filter = 'Lua (*.lua)|*.lua'
        $luaDialog.CheckFileExists = $true
        $luaDialog.Multiselect = $true
        if ($luaDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            Add-Log -TextBox $rtbLog -Message 'Import cancelled (lua).'
            return
        }

        $manifestSrcs = @($manifestDialog.FileNames)
        $luaSrcs = @($luaDialog.FileNames)

        $manifestDstDir = 'C:\Program Files (x86)\Steam\depotcache'
        $luaDstDir      = 'C:\Program Files (x86)\Steam\config\stplug-in'

        if (-not (Test-Path $manifestDstDir)) { New-Item -ItemType Directory -Path $manifestDstDir -Force | Out-Null }
        if (-not (Test-Path $luaDstDir)) { New-Item -ItemType Directory -Path $luaDstDir -Force | Out-Null }

        Add-Log -TextBox $rtbLog -Message ("Copying manifests (" + $manifestSrcs.Count + ")...")
        foreach ($m in $manifestSrcs) {
            $manifestDst = Join-Path $manifestDstDir ([System.IO.Path]::GetFileName($m))
            Copy-Item -LiteralPath $m -Destination $manifestDst -Force
        }
        Add-Log -TextBox $rtbLog -Message ("Copying lua files (" + $luaSrcs.Count + ")...")
        foreach ($l in $luaSrcs) {
            $luaDst = Join-Path $luaDstDir ([System.IO.Path]::GetFileName($l))
            Copy-Item -LiteralPath $l -Destination $luaDst -Force
        }
        Add-Log -TextBox $rtbLog -Message 'Import completed.'
    } catch {
        Add-Log -TextBox $rtbLog -Message ("Error: " + $_.Exception.Message)
    } finally {
        Set-UiBusy $false
    }
})

# Show
[void]${form}.ShowDialog()
