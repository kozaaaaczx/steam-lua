Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v0.8.0 "The Sidebar Revolution"
$script:AppVersion = '0.8.0'
$script:SteamExeOverride = $null

function Get-SteamExePath {
    if ($script:SteamExeOverride -and (Test-Path $script:SteamExeOverride)) { return $script:SteamExeOverride }
    try {
        foreach ($rp in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
            if (Test-Path $rp) {
                $k = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                foreach ($n in @('SteamExe','SteamPath','InstallPath')) {
                    if ($k.$n -and -not [string]::IsNullOrWhiteSpace($k.$n)) {
                        if ($k.$n -like '*.exe') { if (Test-Path $k.$n) { return $k.$n } }
                        else { $exe = Join-Path $k.$n 'steam.exe'; if (Test-Path $exe) { return $exe } }
                    }
                }
            }
        }
    } catch {}
    foreach ($p in @("$env:ProgramFiles (x86)\Steam\steam.exe","$env:ProgramFiles\Steam\steam.exe")) { if (Test-Path $p) { return $p } }
    throw "steam.exe not found."
}
function Get-SteamInstallDir { try { Split-Path (Get-SteamExePath) -Parent } catch { $null } }
function Stop-SteamGracefully([int]$Wait=12) {
    try { & (Get-SteamExePath) -shutdown | Out-Null } catch {}
    $end = (Get-Date).AddSeconds($Wait)
    do { Start-Sleep -Milliseconds 400; $pr = Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue } while ($pr -and (Get-Date) -lt $end)
    Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}
function Start-Steam { Start-Process (Get-SteamExePath) }
function Restart-Steam { Stop-SteamGracefully; Start-Steam }
function Get-SteamAccounts {
    $accs = @(); $dir = Get-SteamInstallDir; if (!$dir) { return $accs }
    $vdf = Join-Path $dir "config\loginusers.vdf"; if (!(Test-Path $vdf)) { return $accs }
    $cur = $null
    foreach ($l in (Get-Content $vdf)) {
        if ($l -match '^\s*"(\d{5,})"') { $cur = [PSCustomObject]@{id=$matches[1];name="";persona=""} }
        elseif ($cur -and $l -match '"AccountName"\s+"([^"]+)"') { $cur.name = $matches[1] }
        elseif ($cur -and $l -match '"PersonaName"\s+"([^"]+)"') { $cur.persona = $matches[1] }
        elseif ($cur -and $l -match '^\s*}') { if ($cur.name) { $accs += $cur }; $cur = $null }
    }
    $accs
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SteamShell" Height="760" Width="1160"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        WindowStyle="None" ResizeMode="CanResizeWithGrip"
        Background="Transparent" AllowsTransparency="True">
  <Window.Resources>

    <Style x:Key="NavBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="#8b949e"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Height" Value="48"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="8" Padding="16,0">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="icon" Text="{TemplateBinding Content}" FontSize="16" Width="24" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock x:Name="txt" Text="{TemplateBinding Tag}" VerticalAlignment="Center"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1f2937"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#1f2937"/>
                <Setter Property="Foreground" Value="#58a6ff"/>
                <Setter TargetName="icon" Property="Foreground" Value="#58a6ff"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="ActionBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="24,12"/>
      <Setter Property="Background" Value="#161b22"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.7"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="WinBtn" TargetType="Button">
      <Setter Property="Foreground" Value="#6e7681"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="44"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="0,6">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#21262d"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="SectionLabel" TargetType="TextBlock">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="Margin" Value="0,0,0,20"/>
    </Style>

  </Window.Resources>

  <Border Background="#0d1117" CornerRadius="12" BorderBrush="#21262d" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- Sidebar -->
      <Border Grid.Column="0" Background="#161b22" CornerRadius="12,0,0,12" BorderBrush="#21262d" BorderThickness="0,0,1,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <!-- App Branding -->
          <StackPanel Grid.Row="0" Margin="24,32,24,32">
            <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
               <Ellipse Width="12" Height="12" Fill="#58a6ff" Margin="0,0,12,0"/>
               <TextBlock Text="SteamShell" FontSize="20" FontWeight="Bold" Foreground="White"/>
            </StackPanel>
            <TextBlock x:Name="lblVer" Text="v$script:AppVersion" FontSize="11" Foreground="#484f58" Margin="26,0,0,0"/>
          </StackPanel>

          <!-- Nav Menu -->
          <StackPanel Grid.Row="1" Margin="16,0">
            <RadioButton x:Name="navDashboard" Content="&#x1F4BB;" Tag="Dashboard"   Style="{StaticResource NavBtn}" IsChecked="True"/>
            <RadioButton x:Name="navAccounts"  Content="&#x1F464;" Tag="Accounts"    Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navFiles"     Content="&#x1F4C1;" Tag="Files"       Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navSettings"  Content="&#x2699;" Tag="Settings"    Style="{StaticResource NavBtn}"/>
          </StackPanel>

          <!-- App Support -->
          <StackPanel Grid.Row="2" Margin="16,16,16,24">
            <Button x:Name="btnAbout" Content="About &amp; Info" Style="{StaticResource NavBtn}" Tag="Info"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Main Content Area -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="46"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="36"/>
        </Grid.RowDefinitions>

        <!-- Top Right Window Controls -->
        <StackPanel Grid.Row="0" Orientation="Horizontal" HorizontalAlignment="Right" x:Name="titleBar">
          <Button x:Name="btnMin" Content="&#x2500;" Style="{StaticResource WinBtn}" FontSize="10"/>
          <Button x:Name="btnMax" Content="&#x25A1;" Style="{StaticResource WinBtn}"/>
          <Button x:Name="btnClose" Content="&#x2715;" Style="{StaticResource WinBtn}"/>
        </StackPanel>

        <!-- Pages Container -->
        <Grid Grid.Row="1" Margin="40,24,40,16">
          
          <!-- P1: Dashboard -->
          <Grid x:Name="pageDashboard" Visibility="Visible">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Text="Dashboard" Style="{StaticResource SectionLabel}"/>
            
            <WrapPanel Grid.Row="1" Margin="0,0,0,24">
              <Button x:Name="btnStart" Content="Start Steam" Background="#238636" Style="{StaticResource ActionBtn}" Margin="0,0,12,0"/>
              <Button x:Name="btnRestart" Content="Restart" Style="{StaticResource ActionBtn}" Margin="0,0,12,0"/>
              <Button x:Name="btnStop" Content="Stop" Style="{StaticResource ActionBtn}" Margin="0,0,12,0"/>
              <Button x:Name="btnKill" Content="Kill All" Background="#da3633" Style="{StaticResource ActionBtn}" Margin="0"/>
            </WrapPanel>

            <Grid Grid.Row="2">
              <Border Background="#010409" CornerRadius="12" Padding="0">
                <Grid>
                   <Grid.RowDefinitions><RowDefinition Height="40"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                   <Border Background="#161b22" CornerRadius="12,12,0,0" Padding="16,8">
                     <Grid>
                       <TextBlock Text="Recent Logs" Foreground="#8b949e" FontSize="12" FontWeight="SemiBold"/>
                       <Button x:Name="btnClear" Content="Clear" Style="{StaticResource NavBtn}" Height="24" HorizontalAlignment="Right" FontSize="11" Margin="0" Tag="Clear All"/>
                     </Grid>
                   </Border>
                   <ScrollViewer Grid.Row="1" x:Name="svLog" VerticalScrollBarVisibility="Auto">
                     <TextBox x:Name="txtLog" Background="Transparent" Foreground="#3FB950" IsReadOnly="True" BorderThickness="0" Padding="16" FontFamily="Consolas" FontSize="13" TextWrapping="Wrap"/>
                   </ScrollViewer>
                </Grid>
              </Border>
            </Grid>
          </Grid>

          <!-- P2: Accounts -->
          <Grid x:Name="pageAccounts" Visibility="Collapsed">
            <StackPanel>
              <TextBlock Text="Steam Accounts" Style="{StaticResource SectionLabel}"/>
              <TextBlock Text="Select an account to switch to. Steam will restart automatically." Foreground="#8b949e" Margin="0,0,0,20" TextWrapping="Wrap"/>
              <ComboBox x:Name="cmbAccounts" Background="#161b22" Foreground="White" Padding="12" FontSize="14" Height="46" BorderBrush="#30363d">
                <ComboBox.Resources>
                  <SolidColorBrush x:Key="{x:Static SystemColors.WindowBrushKey}" Color="#161b22"/>
                </ComboBox.Resources>
              </ComboBox>
              <Button x:Name="btnSwitch" Content="Switch to Selected Account" Background="#1f6feb" Style="{StaticResource ActionBtn}" Margin="0,20" Height="46"/>
            </StackPanel>
          </Grid>

          <!-- P3: Files & Importing -->
          <Grid x:Name="pageFiles" Visibility="Collapsed">
            <StackPanel>
              <TextBlock Text="Files &amp; Tools" Style="{StaticResource SectionLabel}"/>
              <TextBlock Text="Drag and drop your manifest or lua files anywhere to import them." Foreground="#8b949e" Margin="0,0,0,20"/>
              
              <Button x:Name="btnImport" Content="Manual File Import..." Background="#1f6feb" Style="{StaticResource ActionBtn}" Margin="0,0,0,32" Height="46"/>
              
              <TextBlock Text="Browse Folders" Foreground="#8b949e" Margin="0,0,0,12" FontSize="12" FontWeight="SemiBold"/>
              <Button x:Name="btnDepot"  Content="&#x1F4C1; Open Depot Cache" Style="{StaticResource SideBtn}" Tag="Browse"/>
              <Button x:Name="btnLua"    Content="&#x1F4C1; Open Scripts Folder" Style="{StaticResource SideBtn}" Tag="Browse"/>
              <Button x:Name="btnConfig" Content="&#x1F4C1; Open Steam Config"  Style="{StaticResource SideBtn}" Tag="Browse"/>
            </StackPanel>
          </Grid>

          <!-- P4: Settings -->
          <Grid x:Name="pageSettings" Visibility="Collapsed">
            <StackPanel>
              <TextBlock Text="Application Settings" Style="{StaticResource SectionLabel}"/>
              
              <CheckBox x:Name="chkBackup" Content="Enable automatic backups before overwriting" IsChecked="True" FontSize="13" Margin="0,0,0,12"/>
              <CheckBox x:Name="chkOnTop" Content="Keep SteamShell always on top" FontSize="13" Margin="0,0,0,20"/>
              
              <TextBlock Text="Steam Configuration" Foreground="#8b949e" FontSize="12" FontWeight="SemiBold" Margin="0,10,0,12"/>
              <StackPanel Orientation="Horizontal" Margin="0,0,0,20">
                 <TextBlock Text="Shutdown Wait Time:" Foreground="#C9D1D9" VerticalAlignment="Center" Margin="0,0,16,0"/>
                 <TextBox x:Name="txtWait" Text="12" Width="60" Background="#161b22" Foreground="White" Padding="10,6" BorderBrush="#30363d"/>
                 <TextBlock Text="seconds" Foreground="#484f58" VerticalAlignment="Center" Margin="10,0,0,0"/>
              </StackPanel>
              
              <Button x:Name="btnBrowse" Content="Manually Locatesteam.exe" Style="{StaticResource SideBtn}" Tag="Advanced"/>
            </StackPanel>
          </Grid>

        </Grid>

        <!-- Bottom Footer -->
        <Border Grid.Row="2" Padding="40,0" VerticalAlignment="Center">
          <Grid>
            <TextBlock x:Name="statusLabel" Text="All systems operational" Foreground="#484f58" FontSize="11"/>
            <TextBlock x:Name="statusSteam" Text="STEAM: UNKNOWN" HorizontalAlignment="Right" FontSize="11" FontWeight="Bold"/>
          </Grid>
        </Border>

      </Grid>
    </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$w = [System.Windows.Markup.XamlReader]::Load($reader)

# Find controls
$titleBar = $w.FindName("titleBar"); $lblVer = $w.FindName("lblVer")
$btnMin = $w.FindName("btnMin"); $btnMax = $w.FindName("btnMax"); $btnClose = $w.FindName("btnClose")
$btnStart = $w.FindName("btnStart"); $btnStop = $w.FindName("btnStop"); $btnRestart = $w.FindName("btnRestart")
$btnKill = $w.FindName("btnKill"); $btnImport = $w.FindName("btnImport"); $btnSwitch = $w.FindName("btnSwitch")
$btnClear = $w.FindName("btnClear"); $btnDepot = $w.FindName("btnDepot"); $btnLua = $w.FindName("btnLua")
$btnConfig = $w.FindName("btnConfig"); $btnBrowse = $w.FindName("btnBrowse"); $btnAbout = $w.FindName("btnAbout")
$cmbAccounts = $w.FindName("cmbAccounts"); $chkBackup = $w.FindName("chkBackup"); $chkOnTop = $w.FindName("chkOnTop")
$txtWait = $w.FindName("txtWait"); $txtLog = $w.FindName("txtLog"); $svLog = $w.FindName("svLog")
$statusLabel = $w.FindName("statusLabel"); $statusSteam = $w.FindName("statusSteam")

# Navigation Controls
$navDashboard = $w.FindName("navDashboard"); $navAccounts = $w.FindName("navAccounts")
$navFiles = $w.FindName("navFiles"); $navSettings = $w.FindName("navSettings")
$pDashboard = $w.FindName("pageDashboard"); $pAccounts = $w.FindName("pageAccounts")
$pFiles = $w.FindName("pageFiles"); $pSettings = $w.FindName("pageSettings")

function Switch-Page($page) {
    @($pDashboard, $pAccounts, $pFiles, $pSettings) | foreach { $_.Visibility = 'Collapsed' }
    $page.Visibility = 'Visible'
}

$navDashboard.Add_Checked({ Switch-Page $pDashboard })
$navAccounts.Add_Checked({ Switch-Page $pAccounts })
$navFiles.Add_Checked({ Switch-Page $pFiles })
$navSettings.Add_Checked({ Switch-Page $pSettings })

$lblVer.Text = "v$script:AppVersion"

# Window Management
$titleBar.Add_MouseLeftButtonDown({ $w.DragMove() })
$btnMin.Add_Click({ $w.WindowState = 'Minimized' })
$btnMax.Add_Click({ if ($w.WindowState -eq 'Maximized') { $w.WindowState = 'Normal' } else { $w.WindowState = 'Maximized' } })
$btnClose.Add_Click({ $w.Close() })

# Functionality
function Write-Log([string]$msg) {
    if (!$txtLog) { return }
    $ts = (Get-Date).ToString('HH:mm:ss')
    $txtLog.AppendText("[$ts] $msg`n")
    if ($svLog) { $svLog.ScrollToEnd() }
}

function Import-Files($ps) {
    $dM = 'C:\Program Files (x86)\Steam\depotcache'; $dL = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dM)) { New-Item $dM -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dL)) { New-Item $dL -ItemType Directory -Force | Out-Null }
    foreach ($p in $ps) {
        $ext = [System.IO.Path]::GetExtension($p).ToLower()
        $dst = if ($ext -eq '.manifest') { $dM } elseif ($ext -eq '.lua') { $dL } else { $null }
        if ($dst) {
            $dest = Join-Path $dst ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.IsChecked -and (Test-Path $dest)) { Copy-Item $dest "$dest.bak" -Force }
            Copy-Item -LiteralPath $p -Destination $dest -Force
            Write-Log "Applied: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

function Update-Accounts {
    $cmbAccounts.Items.Clear(); $script:AccList = @(Get-SteamAccounts)
    foreach ($a in $script:AccList) { $cmbAccounts.Items.Add("$($a.persona) ($($a.name))") | Out-Null }
    if ($cmbAccounts.Items.Count -gt 0) {
        $cmbAccounts.SelectedIndex = 0
        try { $cur = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).AutoLoginUser
            if ($cur) { for($i=0;$i -lt $script:AccList.Count;$i++) { if ($script:AccList[$i].name -eq $cur) { $cmbAccounts.SelectedIndex=$i; break } } }
        } catch {}
    }
}

function Update-Status {
    $pr = Get-Process steam -ErrorAction SilentlyContinue
    if ($pr) { $statusSteam.Text = "● RUNNING"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#3fb950") }
    else { $statusSteam.Text = "● STOPPED"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#f85149") }
}

# Handlers
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Initializing Steam..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { Stop-SteamGracefully ([int]$txtWait.Text); Write-Log "Graceful shutdown complete." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnRestart.Add_Click({ try { Restart-Steam; Write-Log "Restarting services..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnKill.Add_Click({ Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Write-Log "All Steam processes terminated." })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Filter="Assets|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Batch import complete." }
})
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0 -and $script:AccList.Count -gt 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "RememberPassword" -Value 1
        Write-Log "Active profile changed to: $($a.name). Running Steam..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Text = "" })
$btnDepot.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\depotcache' } catch {} })
$btnLua.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' } catch {} })
$btnConfig.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config' } catch {} })
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="steam.exe|steam.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:SteamExeOverride=$dlg.FileName; Write-Log "Manual override: $($dlg.FileName)" }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell Professional`nVersion: $script:AppVersion`n`nPremium Steam asset management utility.`n`ngithub.com/kozaaaaczx/steam-lua","About",0,64) })
$chkOnTop.Add_Checked({ $w.Topmost=$true }); $chkOnTop.Add_Unchecked({ $w.Topmost=$false })

# Drag & Drop
$w.Add_DragEnter({ param($s,$e) if($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){$e.Effects='Copy'} })
$w.Add_Drop({ param($s,$e) 
    $fs = $e.Data.GetData([System.Windows.DataFormats]::FileDrop); Import-Files $fs; 
    Write-Log "Drag & drop files processed."
    if ([System.Windows.MessageBox]::Show("Files imported successfully. Restart Steam now?", "Deploy", 4, 32) -eq 6) { Restart-Steam }
})

# Timers
$timer = New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval=[TimeSpan]::FromSeconds(3)
$timer.Add_Tick({ Update-Status }); $timer.Start()

$timerUpd = New-Object System.Windows.Threading.DispatcherTimer; $timerUpd.Interval=[TimeSpan]::FromSeconds(5)
$timerUpd.Add_Tick({ param($s,$e); $s.Stop()
    try { $rel = Invoke-RestMethod "https://api.github.com/repos/kozaaaaczx/steam-lua/releases/latest" -ErrorAction SilentlyContinue
        if ($rel.tag_name -match '(\d+\.\d+\.\d+)' -and [version]$matches[1] -gt [version]$script:AppVersion) {
            if ([System.Windows.MessageBox]::Show("Version v$($matches[1]) is available!`nApply update?","Update",4,32) -eq 6) { Start-Process "https://github.com/kozaaaaczx/steam-lua/releases/latest" }
        }
    } catch {}
}); $timerUpd.Start()

# Init
Update-Accounts; Update-Status; Write-Log "SteamShell v$script:AppVersion initialized."
$w.ShowDialog() | Out-Null