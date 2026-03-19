Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v1.1.1 "The Stability Hotfix"
$script:AppVersion = '1.1.1'
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
        Title="SteamShell" Height="780" Width="1180"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        WindowStyle="None" ResizeMode="CanResizeWithGrip"
        Background="#0d1117" AllowsTransparency="True">
  <Window.Resources>
    
    <SolidColorBrush x:Key="AccentBrush" Color="#58a6ff"/>
    <SolidColorBrush x:Key="PanelBrush" Color="#161b22"/>
    <SolidColorBrush x:Key="HoverBrush" Color="#21262d"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#30363d"/>
    <SolidColorBrush x:Key="TextMain" Color="#c9d1d9"/>
    <SolidColorBrush x:Key="TextDim" Color="#8b949e"/>

    <!-- Nav Button (RadioButton Style) -->
    <Style x:Key="NavBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Height" Value="46"/>
      <Setter Property="Margin" Value="0,2"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="6" Padding="12,0">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="icon" Text="{TemplateBinding Content}" FontFamily="Segoe MDL2 Assets" FontSize="18" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock Text="{TemplateBinding Tag}" VerticalAlignment="Center" FontFamily="Segoe UI Semibold"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter Property="Foreground" Value="{StaticResource AccentBrush}"/>
                <Setter TargetName="icon" Property="Foreground" Value="{StaticResource AccentBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Side Button (Button Style - copy of Nav styling but for generic buttons) -->
    <Style x:Key="SideBtn" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Height" Value="46"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" Padding="12,0">
              <StackPanel Orientation="Horizontal">
                <TextBlock x:Name="icon" Text="{TemplateBinding Content}" FontFamily="Segoe MDL2 Assets" FontSize="18" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock Text="{TemplateBinding Tag}" VerticalAlignment="Center" FontFamily="Segoe UI Semibold"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="FlatCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="Padding" Value="24"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Margin" Value="0,0,16,16"/>
    </Style>

    <Style x:Key="SimpleBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="20,10"/>
      <Setter Property="Background" Value="{StaticResource HoverBrush}"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
               <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#30363d"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="bd" Property="Opacity" Value="0.7"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Border BorderBrush="{StaticResource BorderBrush}" BorderThickness="1" CornerRadius="8">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="240"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- Sidebar -->
      <Border Grid.Column="0" Background="#010409" BorderBrush="{StaticResource BorderBrush}" BorderThickness="0,0,1,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <StackPanel Grid.Row="0" Margin="24,32,24,32">
            <TextBlock Text="SteamShell" FontSize="20" FontWeight="Bold" Foreground="White"/>
            <TextBlock Text="Management Environment" FontSize="11" Foreground="{StaticResource TextDim}" Margin="2,2,0,0"/>
          </StackPanel>

          <StackPanel Grid.Row="1" Margin="14,0">
            <RadioButton x:Name="navDashboard" Content="&#xE80F;" Tag="Home" Style="{StaticResource NavBtn}" IsChecked="True"/>
            <RadioButton x:Name="navAccounts"  Content="&#xE77B;" Tag="Accounts" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navFiles"     Content="&#xE8B7;" Tag="Files" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navSettings"  Content="&#xE713;" Tag="Settings" Style="{StaticResource NavBtn}"/>
          </StackPanel>

          <StackPanel Grid.Row="2" Margin="14,0,14,24">
             <Button x:Name="btnAbout" Content="&#xE946;" Tag="Help" Style="{StaticResource SideBtn}"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Content Area -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions><RowDefinition Height="46"/><RowDefinition Height="*"/></Grid.RowDefinitions>

        <Grid Grid.Row="0" x:Name="titleBar">
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,4,0">
            <Button x:Name="btnMin" Content="&#xE921;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource SideBtn}" Tag="Minimize" Height="32" Width="40" Margin="0"/>
            <Button x:Name="btnClose" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource SideBtn}" Tag="Close" Height="32" Width="40" Foreground="#F85149" Margin="0"/>
          </StackPanel>
        </Grid>

        <!-- Pages -->
        <Grid Grid.Row="1" Margin="32,8,32,32">

          <Grid x:Name="pageDashboard">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Text="Home" FontSize="24" FontWeight="Bold" Foreground="White" Margin="0,0,0,24"/>
            <WrapPanel Grid.Row="1">
              <Border Style="{StaticResource FlatCard}" Width="220">
                <StackPanel>
                  <TextBlock Text="STEAM SERVICE" Foreground="{StaticResource TextDim}" FontSize="10" FontWeight="Bold" Margin="0,0,0,12"/>
                  <Border x:Name="bdStatus" Background="#203fb950" CornerRadius="4" Padding="8,4" HorizontalAlignment="Left" BorderThickness="1" BorderBrush="#803fb950">
                     <TextBlock x:Name="statusSteam" Text="ACTIVE" Foreground="#3fb950" FontSize="11" FontWeight="Bold"/>
                  </Border>
                </StackPanel>
              </Border>
              <Border Style="{StaticResource FlatCard}" Width="280">
                <StackPanel>
                  <TextBlock Text="LOGGED PROFILE" Foreground="{StaticResource TextDim}" FontSize="10" FontWeight="Bold" Margin="0,0,0,12"/>
                  <TextBlock x:Name="lblActiveAcc" Text="None" Foreground="White" FontSize="16" FontWeight="SemiBold"/>
                </StackPanel>
              </Border>
            </WrapPanel>
            <Grid Grid.Row="2" Margin="0,8,0,0">
               <Border Background="#010409" CornerRadius="8" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <Grid>
                  <Grid.RowDefinitions><RowDefinition Height="40"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                  <Border Background="{StaticResource PanelBrush}" CornerRadius="8,8,0,0" Padding="16,0" BorderBrush="{StaticResource BorderBrush}" BorderThickness="0,0,0,1">
                    <Grid>
                      <TextBlock Text="Event Terminal" VerticalAlignment="Center" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="SemiBold"/>
                       <Button x:Name="btnClear" Content="Flush Buffer" Style="{StaticResource SimpleBtn}" Height="24" Padding="12,0" FontSize="10" HorizontalAlignment="Right" Margin="0"/>
                    </Grid>
                  </Border>
                  <ScrollViewer Grid.Row="1" x:Name="svLog" VerticalScrollBarVisibility="Auto">
                    <TextBox x:Name="txtLog" Background="Transparent" Foreground="#58a6ff" IsReadOnly="True" BorderThickness="0" Padding="20" FontFamily="Consolas" FontSize="13" TextWrapping="Wrap"/>
                  </ScrollViewer>
                </Grid>
              </Border>
            </Grid>
            <StackPanel Grid.Row="3" Orientation="Horizontal" Margin="0,20,0,0">
              <Button x:Name="btnStart" Content="Launch Steam" Background="#238636" BorderThickness="0" Style="{StaticResource SimpleBtn}" Width="140" Margin="0,0,12,0"/>
              <Button x:Name="btnStop" Content="Close Service" Style="{StaticResource SimpleBtn}" Width="120"/>
            </StackPanel>
          </Grid>

          <Grid x:Name="pageAccounts" Visibility="Collapsed">
            <StackPanel MaxWidth="500" HorizontalAlignment="Left">
              <TextBlock Text="Account Management" FontSize="24" FontWeight="Bold" Foreground="White" Margin="0,0,0,32"/>
              <Border Style="{StaticResource FlatCard}" Padding="32">
                <StackPanel>
                  <TextBlock Text="Identified Accounts" Foreground="{StaticResource TextDim}" Margin="0,0,0,12"/>
                  <ComboBox x:Name="cmbAccounts" Background="#010409" Foreground="White" Height="40" Padding="12" FontSize="13"/>
                  <Button x:Name="btnSwitch" Content="Switch Account" Background="#1f6feb" BorderThickness="0" Style="{StaticResource SimpleBtn}" Margin="0,24,0,0" Height="40"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </Grid>

          <Grid x:Name="pageFiles" Visibility="Collapsed">
            <StackPanel MaxWidth="700" HorizontalAlignment="Left">
              <TextBlock Text="Files" FontSize="24" FontWeight="Bold" Foreground="White" Margin="0,0,0,32"/>
              <Button x:Name="btnImport" Content="&#xE8B5; Open File Selector..." Style="{StaticResource SimpleBtn}" Height="46" HorizontalAlignment="Left" Margin="0,0,0,32"/>
              <TextBlock Text="Storage Locations" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,16"/>
              <WrapPanel>
                 <Button x:Name="btnDepot"  Content="Depot Cache" Style="{StaticResource SimpleBtn}" Margin="0,0,12,12"/>
                 <Button x:Name="btnLua"    Content="LUA assets" Style="{StaticResource SimpleBtn}" Margin="0,0,12,12"/>
                 <Button x:Name="btnConfig" Content="User Config" Style="{StaticResource SimpleBtn}" Margin="0,0,12,12"/>
              </WrapPanel>
            </StackPanel>
          </Grid>

          <Grid x:Name="pageSettings" Visibility="Collapsed">
            <StackPanel MaxWidth="500" HorizontalAlignment="Left">
              <TextBlock Text="Preferences" FontSize="24" FontWeight="Bold" Foreground="White" Margin="0,0,0,32"/>
              <Border Style="{StaticResource FlatCard}" Padding="32">
                <StackPanel>
                  <CheckBox x:Name="chkBackup" Content="Enable automated backups" IsChecked="True" Foreground="White" Margin="0,0,0,12"/>
                  <CheckBox x:Name="chkOnTop" Content="Keep UI Topmost" Foreground="White" Margin="0,0,0,24"/>
                  <Button x:Name="btnBrowse" Content="Repair steam.exe Link" Style="{StaticResource SimpleBtn}"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </Grid>

        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$w = [System.Windows.Markup.XamlReader]::Load($reader)

# Controls
$titleBar = $w.FindName("titleBar"); $btnMin = $w.FindName("btnMin"); $btnClose = $w.FindName("btnClose")
$btnStart = $w.FindName("btnStart"); $btnStop = $w.FindName("btnStop")
$btnImport = $w.FindName("btnImport"); $btnSwitch = $w.FindName("btnSwitch")
$btnClear = $w.FindName("btnClear"); $btnDepot = $w.FindName("btnDepot")
$btnLua = $w.FindName("btnLua"); $btnConfig = $w.FindName("btnConfig")
$btnBrowse = $w.FindName("btnBrowse"); $btnAbout = $w.FindName("btnAbout")
$cmbAccounts = $w.FindName("cmbAccounts"); $chkBackup = $w.FindName("chkBackup"); $chkOnTop = $w.FindName("chkOnTop")
$txtLog = $w.FindName("txtLog"); $svLog = $w.FindName("svLog")
$statusSteam = $w.FindName("statusSteam"); $lblActiveAcc = $w.FindName("lblActiveAcc"); $bdStatus = $w.FindName("bdStatus")

# Nav
$navDashboard = $w.FindName("navDashboard"); $navAccounts = $w.FindName("navAccounts")
$navFiles = $w.FindName("navFiles"); $navSettings = $w.FindName("navSettings")
$pDashboard = $w.FindName("pageDashboard"); $pAccounts = $w.FindName("pageAccounts")
$pFiles = $w.FindName("pageFiles"); $pSettings = $w.FindName("pageSettings")

function Switch-Page($page) {
    @($pDashboard, $pAccounts, $pFiles, $pSettings) | ForEach-Object { $_.Visibility = 'Collapsed' }
    $page.Visibility = 'Visible'
}

$navDashboard.Add_Checked({ Switch-Page $pDashboard })
$navAccounts.Add_Checked({ Switch-Page $pAccounts })
$navFiles.Add_Checked({ Switch-Page $pFiles })
$navSettings.Add_Checked({ Switch-Page $pSettings })

# Logic
function Write-Log([string]$msg) {
    if (!$txtLog) { return }
    $ts = (Get-Date).ToString('HH:mm:ss')
    $txtLog.AppendText("[$ts] $msg`n")
    if ($svLog) { $svLog.ScrollToEnd() }
}

function Update-Status {
    $pr = Get-Process steam -ErrorAction SilentlyContinue
    if ($pr) { 
        $statusSteam.Text = "ACTIVE"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#3fb950")
        $bdStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#203fb950")
        $bdStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#803fb950")
    } else { 
        $statusSteam.Text = "INACTIVE"; $statusSteam.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#F85149")
        $bdStatus.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#20F85149")
        $bdStatus.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFrom("#80F85149")
    }
    try {
        $cur = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).AutoLoginUser
        $lblActiveAcc.Text = if ($cur) { $cur } else { "None" }
    } catch { $lblActiveAcc.Text = "Error" }
}

function Update-Accounts {
    $cmbAccounts.Items.Clear(); $script:AccList = @(Get-SteamAccounts)
    $script:AccList | ForEach-Object { $cmbAccounts.Items.Add("$($_.persona) ($($_.name))") | Out-Null }
}

function Import-Files($ps) {
    if (!$ps) { return }
    $dM = 'C:\Program Files (x86)\Steam\depotcache'; $dL = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dM)) { New-Item $dM -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dL)) { New-Item $dL -ItemType Directory -Force | Out-Null }
    $ps | ForEach-Object {
        $p = $_
        $ext = [System.IO.Path]::GetExtension($p).ToLower()
        $dst = if ($ext -eq '.manifest') { $dM } elseif ($ext -eq '.lua') { $dL } else { $null }
        if ($dst) {
            $dest = Join-Path $dst ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.IsChecked -and (Test-Path $dest)) { Copy-Item $dest "$dest.bak" -Force }
            Copy-Item -LiteralPath $p -Destination $dest -Force
            Write-Log "Imported: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

# Handlers
$titleBar.Add_MouseLeftButtonDown({ $w.DragMove() })
$btnMin.Add_Click({ $w.WindowState = 'Minimized' })
$btnClose.Add_Click({ $w.Close() })
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Initializing Steam..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { Stop-SteamGracefully 12; Write-Log "Siganling shutdown..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Write-Log "Profile Switch: $($a.name). Rebooting Steam..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Text = "" })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Filter="Assets|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Batch import complete." }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell v$script:AppVersion","Info",0,64) })
$chkOnTop.Add_Checked({ $w.Topmost=$true }); $chkOnTop.Add_Unchecked({ $w.Topmost=$false })

$btnDepot.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\depotcache' } catch {} })
$btnLua.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' } catch {} })
$btnConfig.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config' } catch {} })
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="steam.exe|steam.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:SteamExeOverride=$dlg.FileName; Write-Log "Path Sync: $($dlg.FileName)" }
})

# DragDrop
$w.Add_DragEnter({ param($s,$e) if($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){$e.Effects='Copy'} })
$w.Add_Drop({ param($s,$e) Import-Files ($e.Data.GetData([System.Windows.DataFormats]::FileDrop)); Write-Log "Imported dropped assets." })

# Timer
$t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval=[TimeSpan]::FromSeconds(3)
$t.Add_Tick({ Update-Status }); $t.Start()

# Startup
Update-Accounts; Update-Status; Write-Log "Environment v$script:AppVersion Stable."
$w.ShowDialog() | Out-Null