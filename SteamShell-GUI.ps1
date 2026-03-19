Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:AppVersion = '0.5.1'
$script:SteamExeOverride = $null

# Core Steam Functions
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

# WPF UI
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SteamShell v$($script:AppVersion)" Width="1100" Height="720"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        Background="#0D1117" Foreground="#C9D1D9">
  <Window.Resources>
    <Style x:Key="CardBorder" TargetType="Border">
      <Setter Property="Background" Value="#161B22"/>
      <Setter Property="CornerRadius" Value="10"/>
      <Setter Property="BorderBrush" Value="#21262D"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="18"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="SectionTitle" TargetType="TextBlock">
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#58A6FF"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
    </Style>
    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Background" Value="#21262D"/>
      <Setter Property="Foreground" Value="#C9D1D9"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="#30363D"/>
      <Setter Property="Padding" Value="14,10"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,8,0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#30363D"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#3A424A"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GreenBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#238636"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderBrush" Value="#2EA043"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#2EA043"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="RedBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#DA3633"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderBrush" Value="#F85149"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#F85149"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BlueBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#1F6FEB"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderBrush" Value="#388BFD"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="8"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#388BFD"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SideBtn" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Margin" Value="0,0,0,6"/>
      <Setter Property="Padding" Value="12,10"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="6"
                    BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}"
                    Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="#30363D"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- Header -->
    <Border Grid.Row="0" Background="#161B22" Padding="16,14" BorderBrush="#21262D" BorderThickness="0,0,0,1">
      <Grid>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
          <TextBlock Text="&#x25B6;" FontSize="18" Foreground="#58A6FF" VerticalAlignment="Center" Margin="0,0,10,0"/>
          <TextBlock Text="SteamShell" FontSize="18" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
          <TextBlock Text="v$($script:AppVersion)" FontSize="11" Foreground="#484F58" VerticalAlignment="Center" Margin="8,3,0,0"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="btnStart" Content="&#x25B6; Start" Style="{StaticResource GreenBtn}" Width="110"/>
          <Button x:Name="btnStop" Content="&#x23F9; Stop" Style="{StaticResource RedBtn}" Width="110"/>
          <Button x:Name="btnRestart" Content="&#x21BB; Restart" Style="{StaticResource Btn}" Width="110"/>
          <Button x:Name="btnKill" Content="&#x2716; Kill All" Style="{StaticResource Btn}" Width="110"/>
          <Button x:Name="btnImport" Content="&#x2B06; Import" Style="{StaticResource BlueBtn}" Width="110" Margin="0"/>
        </StackPanel>
      </Grid>
    </Border>

    <!-- Content -->
    <Grid Grid.Row="1" Margin="16">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="290"/>
      </Grid.ColumnDefinitions>

      <!-- Log Terminal -->
      <Border Grid.Column="0" Background="#010409" CornerRadius="10" BorderBrush="#21262D" BorderThickness="1" Margin="0,0,16,0" Padding="0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Border Background="#161B22" CornerRadius="10,10,0,0" Padding="14,8">
            <Grid>
              <TextBlock Text="&#x1F4C4; Console Output" Foreground="#8B949E" FontSize="12"/>
              <Button x:Name="btnClear" Content="Clear" Style="{StaticResource Btn}" HorizontalAlignment="Right" Padding="10,4" FontSize="11"/>
            </Grid>
          </Border>
          <TextBox Grid.Row="1" x:Name="txtLog" IsReadOnly="True" Background="Transparent" Foreground="#3FB950"
                   FontFamily="Cascadia Code, Consolas, Courier New" FontSize="12" BorderThickness="0"
                   VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" AcceptsReturn="True" Padding="14,10"
                   CaretBrush="Transparent"/>
        </Grid>
      </Border>

      <!-- Sidebar -->
      <ScrollViewer Grid.Column="1" VerticalScrollBarVisibility="Auto">
        <StackPanel>
          <!-- Accounts Card -->
          <Border Style="{StaticResource CardBorder}">
            <StackPanel>
              <TextBlock Text="&#x1F464; Steam Accounts" Style="{StaticResource SectionTitle}"/>
              <ComboBox x:Name="cmbAccounts" Background="#0D1117" Foreground="White" FontSize="12" Padding="8,6" Margin="0,0,0,10"/>
              <Button x:Name="btnSwitch" Content="&#x21C4; Switch Account" Style="{StaticResource BlueBtn}" Margin="0" Padding="12,10"/>
            </StackPanel>
          </Border>

          <!-- Options Card -->
          <Border Style="{StaticResource CardBorder}">
            <StackPanel>
              <TextBlock Text="&#x2699; Options" Style="{StaticResource SectionTitle}"/>
              <CheckBox x:Name="chkBackup" Content="Backup before overwrite" IsChecked="True" Foreground="#C9D1D9" Margin="0,0,0,8"/>
              <CheckBox x:Name="chkOnTop" Content="Always on top" Foreground="#C9D1D9" Margin="0,0,0,8"/>
              <StackPanel Orientation="Horizontal" Margin="0,4,0,0">
                <TextBlock Text="Shutdown wait:" Foreground="#8B949E" VerticalAlignment="Center" Margin="0,0,10,0"/>
                <TextBox x:Name="txtWait" Text="12" Width="50" Background="#0D1117" Foreground="White" BorderBrush="#30363D" Padding="6,4" FontSize="12"/>
                <TextBlock Text="sec" Foreground="#484F58" VerticalAlignment="Center" Margin="6,0,0,0"/>
              </StackPanel>
            </StackPanel>
          </Border>

          <!-- Quick Access Card -->
          <Border Style="{StaticResource CardBorder}">
            <StackPanel>
              <TextBlock Text="&#x1F527; Quick Access" Style="{StaticResource SectionTitle}"/>
              <Button x:Name="btnDepot"  Content="&#x1F4C1; Depot Cache Folder"  Style="{StaticResource SideBtn}"/>
              <Button x:Name="btnLua"    Content="&#x1F4C1; Lua Scripts Folder"   Style="{StaticResource SideBtn}"/>
              <Button x:Name="btnConfig" Content="&#x1F4C1; Steam Config Folder"  Style="{StaticResource SideBtn}"/>
              <Button x:Name="btnBrowse" Content="&#x1F50D; Set Steam Path"       Style="{StaticResource SideBtn}"/>
              <Button x:Name="btnAbout"  Content="&#x2139; About SteamShell"      Style="{StaticResource SideBtn}" Margin="0"/>
            </StackPanel>
          </Border>
        </StackPanel>
      </ScrollViewer>
    </Grid>

    <!-- Status Bar -->
    <Border Grid.Row="2" Background="#161B22" Padding="16,10" BorderBrush="#21262D" BorderThickness="0,1,0,0">
      <Grid>
        <TextBlock x:Name="statusLabel" Text="Ready" Foreground="#484F58" FontSize="12"/>
        <TextBlock x:Name="statusSteam" Text="STEAM: CHECKING..." HorizontalAlignment="Right" FontSize="12" FontWeight="SemiBold"/>
      </Grid>
    </Border>
  </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get Controls
$btnStart    = $window.FindName("btnStart")
$btnStop     = $window.FindName("btnStop")
$btnRestart  = $window.FindName("btnRestart")
$btnKill     = $window.FindName("btnKill")
$btnImport   = $window.FindName("btnImport")
$btnSwitch   = $window.FindName("btnSwitch")
$btnClear    = $window.FindName("btnClear")
$btnDepot    = $window.FindName("btnDepot")
$btnLua      = $window.FindName("btnLua")
$btnConfig   = $window.FindName("btnConfig")
$btnBrowse   = $window.FindName("btnBrowse")
$btnAbout    = $window.FindName("btnAbout")
$cmbAccounts = $window.FindName("cmbAccounts")
$chkBackup   = $window.FindName("chkBackup")
$chkOnTop    = $window.FindName("chkOnTop")
$txtWait     = $window.FindName("txtWait")
$txtLog      = $window.FindName("txtLog")
$statusLabel = $window.FindName("statusLabel")
$statusSteam = $window.FindName("statusSteam")

# Helpers
function Write-Log([string]$msg) {
    $ts = (Get-Date).ToString('HH:mm:ss')
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToEnd()
}

function Import-Files($paths) {
    $dM = 'C:\Program Files (x86)\Steam\depotcache'; $dL = 'C:\Program Files (x86)\Steam\config\stplug-in'
    if (!(Test-Path $dM)) { New-Item $dM -ItemType Directory -Force | Out-Null }
    if (!(Test-Path $dL)) { New-Item $dL -ItemType Directory -Force | Out-Null }
    foreach ($p in $paths) {
        $ext = [System.IO.Path]::GetExtension($p).ToLower()
        $dst = if ($ext -eq '.manifest') { $dM } elseif ($ext -eq '.lua') { $dL } else { $null }
        if ($dst) {
            $target = Join-Path $dst ([System.IO.Path]::GetFileName($p))
            if ($chkBackup.IsChecked -and (Test-Path $target)) { Copy-Item $target "$target.bak" -Force }
            Copy-Item -LiteralPath $p -Destination $target -Force
            Write-Log "Imported: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

function Update-Accounts {
    $cmbAccounts.Items.Clear(); $script:AccList = @(Get-SteamAccounts)
    foreach ($a in $script:AccList) { $cmbAccounts.Items.Add("$($a.persona) ($($a.name))") | Out-Null }
    if ($cmbAccounts.Items.Count -gt 0) {
        $cmbAccounts.SelectedIndex = 0
        try { $cur = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).AutoLoginUser
            if ($cur) { for ($i=0;$i -lt $script:AccList.Count;$i++) { if ($script:AccList[$i].name -eq $cur) { $cmbAccounts.SelectedIndex=$i; break } } }
        } catch {}
    }
}

function Update-SteamStatus {
    $pr = Get-Process steam -ErrorAction SilentlyContinue
    if ($pr) { $statusSteam.Text = "● STEAM: RUNNING"; $statusSteam.Foreground = [System.Windows.Media.Brushes]::LimeGreen }
    else { $statusSteam.Text = "● STEAM: STOPPED"; $statusSteam.Foreground = [System.Windows.Media.Brushes]::IndianRed }
}

# Events
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Steam started." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { $w = [int]$txtWait.Text; Stop-SteamGracefully $w; Write-Log "Steam stopped." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnRestart.Add_Click({ try { Restart-Steam; Write-Log "Steam restarted." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnKill.Add_Click({ Get-Process steam,steamwebhelper,SteamService -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Write-Log "All Steam processes killed." })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect = $true; $dlg.Filter = "Steam Files|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Import complete." }
})
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0 -and $script:AccList.Count -gt 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "RememberPassword" -Value 1
        Write-Log "Switched to: $($a.name). Restarting..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Clear() })
$btnDepot.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\depotcache' } catch { Write-Log "Folder not found." } })
$btnLua.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' } catch { Write-Log "Folder not found." } })
$btnConfig.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config' } catch { Write-Log "Folder not found." } })
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter = "steam.exe|steam.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:SteamExeOverride = $dlg.FileName; Write-Log "Steam path set: $($dlg.FileName)" }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell v$script:AppVersion`n`nModern Steam Management Tool`nDrag & Drop supported!`n`nGitHub: github.com/kozaaaaczx/steam-lua", "About SteamShell", 0, 64) })
$chkOnTop.Add_Checked({ $window.Topmost = $true }); $chkOnTop.Add_Unchecked({ $window.Topmost = $false })

# Drag & Drop
$window.Add_DragEnter({ param($s,$e) if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) { $e.Effects = 'Copy' } })
$window.Add_Drop({ param($s,$e) $fs = $e.Data.GetData([System.Windows.DataFormats]::FileDrop); Import-Files $fs; Write-Log "Drag & Drop import done." })

# Timers
$timer = New-Object System.Windows.Threading.DispatcherTimer; $timer.Interval = [TimeSpan]::FromSeconds(3)
$timer.Add_Tick({ Update-SteamStatus }); $timer.Start()

$timerUpd = New-Object System.Windows.Threading.DispatcherTimer; $timerUpd.Interval = [TimeSpan]::FromSeconds(4)
$timerUpd.Add_Tick({
    $timerUpd.Stop()
    try {
        $rel = Invoke-RestMethod "https://api.github.com/repos/kozaaaaczx/steam-lua/releases/latest" -ErrorAction SilentlyContinue
        if ($rel.tag_name -match '(\d+\.\d+\.\d+)' -and [version]$matches[1] -gt [version]$script:AppVersion) {
            if ([System.Windows.MessageBox]::Show("New version v$($matches[1]) available! Open download page?", "Update", 4, 32) -eq 6) {
                Start-Process "https://github.com/kozaaaaczx/steam-lua/releases/latest"
            }
        }
    } catch {}
}); $timerUpd.Start()

# Init
Update-Accounts; Update-SteamStatus; Write-Log "SteamShell v$script:AppVersion loaded."
$window.ShowDialog() | Out-Null