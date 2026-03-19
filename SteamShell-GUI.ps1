Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# SteamShell v1.0.0 "The Elite Release"
$script:AppVersion = '1.0.0'
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
        Title="SteamShell Elite" Height="820" Width="1240"
        WindowStartupLocation="CenterScreen" AllowDrop="True"
        WindowStyle="None" ResizeMode="CanResizeWithGrip"
        Background="Transparent" AllowsTransparency="True">
  <Window.Resources>
    
    <SolidColorBrush x:Key="BgBrush" Color="#0B0F14"/>
    <SolidColorBrush x:Key="PanelBrush" Color="#121821"/>
    <SolidColorBrush x:Key="HoverBrush" Color="#1A2330"/>
    <SolidColorBrush x:Key="BorderBrush" Color="#1F2937"/>
    <SolidColorBrush x:Key="TextMain" Color="#FFFFFF"/>
    <SolidColorBrush x:Key="TextDim" Color="#8B949E"/>

    <LinearGradientBrush x:Key="AccentBrush" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#4CC2FF" Offset="0"/>
      <GradientStop Color="#6EE7FF" Offset="1"/>
    </LinearGradientBrush>

    <!-- Nav Button with Slide Animation -->
    <Style x:Key="NavBtn" TargetType="RadioButton">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Height" Value="54"/>
      <Setter Property="Margin" Value="0,4"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="bd" Background="Transparent" CornerRadius="10" Padding="16,0">
              <Border.RenderTransform><TranslateTransform X="0"/></Border.RenderTransform>
              <StackPanel Orientation="Horizontal">
                <Border x:Name="indicator" Width="4" Height="22" Background="{StaticResource AccentBrush}" CornerRadius="2" HorizontalAlignment="Left" Visibility="Collapsed" Margin="-16,0,12,0"/>
                <TextBlock x:Name="icon" Text="{TemplateBinding Content}" FontFamily="Segoe MDL2 Assets" FontSize="20" VerticalAlignment="Center" Margin="0,0,16,0"/>
                <TextBlock x:Name="txt" Text="{TemplateBinding Tag}" VerticalAlignment="Center" FontFamily="Segoe UI Semibold"/>
              </StackPanel>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Setter Property="Foreground" Value="White"/>
                <Trigger.EnterActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="6" Duration="0:0:0.2"/></Storyboard></BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="0" Duration="0:0:0.2"/></Storyboard></BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="indicator" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="{StaticResource AccentBrush}"/>
                <Setter TargetName="icon" Property="Foreground" Value="{StaticResource AccentBrush}"/>
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Glowing Dash Card -->
    <Style x:Key="DashCard" TargetType="Border">
      <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
      <Setter Property="CornerRadius=" Value="16"/>
      <Setter Property="Padding" Value="28"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Margin" Value="0,0,20,20"/>
      <Setter Property="RenderTransformOrigin" Value="0.5,0.5"/>
      <Setter Property="RenderTransform"><ScaleTransform ScaleX="1" ScaleY="1"/></Setter>
      <Setter Property="Effect">
        <Setter.Value><DropShadowEffect BlurRadius="25" ShadowDepth="0" Opacity="0"/></Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsMouseOver" Value="True">
          <Trigger.EnterActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetProperty="Effect.Opacity" To="0.4" Duration="0:0:0.2"/>
              <ColorAnimation Storyboard.TargetProperty="Effect.Color" To="#4CC2FF" Duration="0:0:0.2"/>
              <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1.03" Duration="0:0:0.2"/>
              <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)" To="1.03" Duration="0:0:0.2"/>
            </Storyboard></BeginStoryboard>
          </Trigger.EnterActions>
          <Trigger.ExitActions>
            <BeginStoryboard><Storyboard>
              <DoubleAnimation Storyboard.TargetProperty="Effect.Opacity" To="0" Duration="0:0:0.2"/>
              <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1" Duration="0:0:0.2"/>
              <DoubleAnimation Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleY)" To="1" Duration="0:0:0.2"/>
            </Storyboard></BeginStoryboard>
          </Trigger.ExitActions>
        </Trigger>
      </Style.Triggers>
    </Style>

    <!-- Standard Button -->
    <Style x:Key="EliteBtn" TargetType="Button">
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontFamily" Value="Segoe UI Semibold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Padding" Value="28,14"/>
      <Setter Property="Background" Value="{StaticResource PanelBrush}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="BorderBrush" Value="{StaticResource BorderBrush}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="bd" Background="{TemplateBinding Background}" CornerRadius="12" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
               <Border.RenderTransform><ScaleTransform ScaleX="1" ScaleY="1"/></Border.RenderTransform>
               <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="bd" Property="Background" Value="{StaticResource HoverBrush}"/>
                <Trigger.EnterActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1.05" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="bd" Storyboard.TargetProperty="(UIElement.RenderTransform).(ScaleTransform.ScaleX)" To="1" Duration="0:0:0.15"/></Storyboard></BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

  </Window.Resources>

  <Border x:Name="mainBorder" Background="{StaticResource BgBrush}" CornerRadius="20" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="280"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- Sidebar -->
      <Border Grid.Column="0" Background="{StaticResource PanelBrush}" CornerRadius="20,0,0,20" BorderBrush="{StaticResource BorderBrush}" BorderThickness="0,0,1,0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <StackPanel Grid.Row="0" Margin="32,56,32,48">
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
              <Border Width="42" Height="42" CornerRadius="12" Background="{StaticResource AccentBrush}">
                 <TextBlock Text="&#xE961;" FontFamily="Segoe MDL2 Assets" Foreground="#000" VerticalAlignment="Center" HorizontalAlignment="Center" FontSize="22"/>
              </Border>
              <TextBlock Text="SteamShell" FontSize="26" FontWeight="Bold" Foreground="White" Margin="16,0,0,0" VerticalAlignment="Center" LetterSpacing="-0.5"/>
            </StackPanel>
            <TextBlock x:Name="lblVer" Text="ELITE STABLE v1.0.0" FontSize="10" Foreground="{StaticResource TextDim}" Margin="58,2,0,0" FontWeight="Bold" LetterSpacing="1"/>
          </StackPanel>

          <StackPanel Grid.Row="1" Margin="20,0">
            <RadioButton x:Name="navDashboard" Content="&#xE80F;" Tag="Dashboard" Style="{StaticResource NavBtn}" IsChecked="True"/>
            <RadioButton x:Name="navAccounts"  Content="&#xE77B;" Tag="Profiles" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navFiles"     Content="&#xE8B7;" Tag="Assets &amp; Tools" Style="{StaticResource NavBtn}"/>
            <RadioButton x:Name="navSettings"  Content="&#xE713;" Tag="Configuration" Style="{StaticResource NavBtn}"/>
          </StackPanel>

          <StackPanel Grid.Row="2" Margin="20,0,20,32">
             <Button x:Name="btnAbout" Content="&#xE946;" Tag="Help &amp; Social" Style="{StaticResource NavBtn}"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Content -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions><RowDefinition Height="64"/><RowDefinition Height="*"/></Grid.RowDefinitions>

        <!-- ToolBar -->
        <Grid Grid.Row="0" x:Name="titleBar" Background="Transparent" Margin="0,0,12,0">
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <Button x:Name="btnMin" Content="&#xE921;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="34" Width="46" Margin="0"/>
            <Button x:Name="btnClose" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="34" Width="46" Foreground="#F85149" Margin="0"/>
          </StackPanel>
        </Grid>

        <!-- Page Content -->
        <Grid Grid.Row="1" Margin="48,0,48,40">

          <!-- Dashboard -->
          <Grid x:Name="pageDashboard">
            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
            
            <!-- Hero Header -->
            <Border Grid.Row="0" Height="140" CornerRadius="20" Margin="0,0,0,32">
              <Border.Background>
                <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                  <GradientStop Color="#4CC2FF" Offset="0"/>
                  <GradientStop Color="#0B0F14" Offset="1.2"/>
                </LinearGradientBrush>
              </Border.Background>
              <Grid Margin="32">
                <StackPanel VerticalAlignment="Center">
                  <TextBlock Text="Welcome back, Agent." FontSize="28" FontWeight="Bold" Foreground="White" LetterSpacing="-0.5"/>
                  <TextBlock Text="Everything is optimized. Steam environment ready for operations." Foreground="#E0E0E0" Opacity="0.9" Margin="0,4,0,0"/>
                </StackPanel>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                  <Button x:Name="btnStart" Content="START STEAM" Background="White" Foreground="#0B0F14" Style="{StaticResource EliteBtn}" Width="150" FontWeight="Bold" Margin="0,0,16,0"/>
                  <Button x:Name="btnStop" Content="STOP" Background="#20FFFFFF" Foreground="White" BorderBrush="Transparent" Style="{StaticResource EliteBtn}" Width="100"/>
                </StackPanel>
              </Grid>
            </Border>

            <!-- Cards -->
            <WrapPanel Grid.Row="1">
              <Border Style="{StaticResource DashCard}" Width="260">
                <StackPanel>
                  <TextBlock Text="SESSION STATUS" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,16" LetterSpacing="1"/>
                  <Border x:Name="bdStatus" Background="#20F85149" CornerRadius="8" Padding="12,6" HorizontalAlignment="Left" BorderThickness="1" BorderBrush="#80F85149">
                     <TextBlock x:Name="statusSteam" Text="INACTIVE" Foreground="#FF6B60" FontSize="13" FontWeight="Bold"/>
                  </Border>
                </StackPanel>
              </Border>

              <Border Style="{StaticResource DashCard}" Width="380">
                <StackPanel>
                  <TextBlock Text="ACTIVE STEAM PROFILE" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,16" LetterSpacing="1"/>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE77B;" FontFamily="Segoe MDL2 Assets" Foreground="{StaticResource AccentBrush}" FontSize="24" VerticalAlignment="Center" Margin="0,0,14,0"/>
                    <TextBlock x:Name="lblActiveAcc" Text="None" Foreground="White" FontSize="20" FontWeight="SemiBold" VerticalAlignment="Center"/>
                  </StackPanel>
                </StackPanel>
              </Border>
            </WrapPanel>

            <!-- Console -->
            <Grid Grid.Row="2" Margin="0,8,0,0">
              <Border Background="{StaticResource PanelBrush}" CornerRadius="18" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <Grid>
                  <Grid.RowDefinitions><RowDefinition Height="52"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                  <Border Background="{StaticResource HoverBrush}" CornerRadius="18,18,0,0" Padding="22,0">
                    <Grid>
                      <TextBlock Text="System Terminal Output" VerticalAlignment="Center" Foreground="{StaticResource TextDim}" FontSize="13" FontWeight="SemiBold"/>
                       <Button x:Name="btnClear" Content="&#xE894; Flush Logs" FontFamily="Segoe MDL2 Assets" Style="{StaticResource NavBtn}" Height="34" HorizontalAlignment="Right" FontSize="11" Padding="12,0" Margin="0"/>
                    </Grid>
                  </Border>
                  <ScrollViewer Grid.Row="1" x:Name="svLog" VerticalScrollBarVisibility="Auto">
                    <TextBox x:Name="txtLog" Background="Transparent" Foreground="#6EE7FF" IsReadOnly="True" BorderThickness="0" Padding="24" FontFamily="Consolas" FontSize="15" TextWrapping="Wrap"/>
                  </ScrollViewer>
                </Grid>
              </Border>
            </Grid>
          </Grid>

          <!-- Accounts Page -->
          <Grid x:Name="pageAccounts" Visibility="Collapsed">
            <StackPanel MaxWidth="600" HorizontalAlignment="Left">
              <TextBlock Text="Profiles Management" FontSize="32" FontWeight="Bold" Foreground="White" Margin="0,0,0,12" LetterSpacing="-1"/>
              <TextBlock Text="Switch between detected Steam accounts instantly. All sessions are persistent." Foreground="{StaticResource TextDim}" FontSize="15" Margin="0,0,0,48"/>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="20" Padding="32" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <StackPanel>
                  <TextBlock Text="Identity Provider" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,14" LetterSpacing="1"/>
                  <ComboBox x:Name="cmbAccounts" Background="{StaticResource BgBrush}" Foreground="White" Height="52" Padding="16" FontSize="15" BorderBrush="{StaticResource BorderBrush}"/>
                  <Button x:Name="btnSwitch" Content="Switch Identity &amp; Reboot Steam" Background="{StaticResource AccentBrush}" Foreground="#000" Style="{StaticResource EliteBtn}" Margin="0,32,0,0" FontWeight="Bold" FontSize="14"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </Grid>

          <!-- Assets Page -->
          <Grid x:Name="pageFiles" Visibility="Collapsed">
            <StackPanel MaxWidth="800" HorizontalAlignment="Left">
              <TextBlock Text="Asset Deployment" FontSize="32" FontWeight="Bold" Foreground="White" Margin="0,0,0,12" LetterSpacing="-1"/>
              <TextBlock Text="Deploy .manifest and .lua assets directly to targeted Steam directories." Foreground="{StaticResource TextDim}" FontSize="15" Margin="0,0,0,48"/>
              
              <Button x:Name="btnImport" Content="&#xE8B5; Select Assets to Import" Background="{StaticResource AccentBrush}" Foreground="#000" Style="{StaticResource EliteBtn}" Height="70" Width="400" HorizontalAlignment="Left" FontSize="18" Margin="0,0,0,56" FontWeight="Bold"/>
              
              <TextBlock Text="Quick Access Bridges" Foreground="White" FontSize="16" FontWeight="Bold" Margin="0,0,0,24"/>
              <WrapPanel>
                 <Button x:Name="btnDepot"  Content="&#xE8B7; Depot Vault" Style="{StaticResource EliteBtn}" Margin="0,0,16,16"/>
                 <Button x:Name="btnLua"    Content="&#xE8B7; LUA Repository" Style="{StaticResource EliteBtn}" Margin="0,0,16,16"/>
                 <Button x:Name="btnConfig" Content="&#xE8B7; Config Root" Style="{StaticResource EliteBtn}" Margin="0,0,16,16"/>
              </WrapPanel>
            </StackPanel>
          </Grid>

          <!-- Configuration Page -->
          <Grid x:Name="pageSettings" Visibility="Collapsed">
            <StackPanel MaxWidth="600" HorizontalAlignment="Left">
              <TextBlock Text="Engine Settings" FontSize="32" FontWeight="Bold" Foreground="White" Margin="0,0,0,48" LetterSpacing="-1"/>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="20" Padding="32" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1" Margin="0,0,0,32">
                <StackPanel>
                  <TextBlock Text="Behavior" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,20" LetterSpacing="1"/>
                  <CheckBox x:Name="chkBackup" Content="Automatic asset backup before deployment" IsChecked="True" Foreground="White" FontSize="14" Margin="0,0,0,16"/>
                  <CheckBox x:Name="chkOnTop" Content="Force Shell Topmost" Foreground="White" FontSize="14"/>
                </StackPanel>
              </Border>
              
              <Border Background="{StaticResource PanelBrush}" CornerRadius="20" Padding="32" BorderBrush="{StaticResource BorderBrush}" BorderThickness="1">
                <StackPanel>
                  <TextBlock Text="Core Bridge" Foreground="{StaticResource TextDim}" FontSize="11" FontWeight="Bold" Margin="0,0,0,20" LetterSpacing="1"/>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="Steam Linkage:" Foreground="White" VerticalAlignment="Center" Margin="0,0,24,0" FontSize="14"/>
                    <Button x:Name="btnBrowse" Content="Repair Path..." Style="{StaticResource EliteBtn}" Padding="20,10"/>
                  </StackPanel>
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

# Find controls
$titleBar = $w.FindName("titleBar"); $lblVer = $w.FindName("lblVer")
$btnMin = $w.FindName("btnMin"); $btnClose = $w.FindName("btnClose")
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
    foreach ($a in $script:AccList) { $cmbAccounts.Items.Add("$($a.persona) ($($a.name))") | Out-Null }
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
            Write-Log "Deployed: $([System.IO.Path]::GetFileName($p))"
        }
    }
}

# Win Handles
$titleBar.Add_MouseLeftButtonDown({ $w.DragMove() })
$btnMin.Add_Click({ $w.WindowState = 'Minimized' })
$btnClose.Add_Click({ $w.Close() })

# Core Handles
$btnStart.Add_Click({ try { Start-Steam; Write-Log "Initializing Steam Engine..." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnStop.Add_Click({ try { Stop-SteamGracefully 12; Write-Log "System shutdown signaled." } catch { Write-Log "Error: $($_.Exception.Message)" } })
$btnSwitch.Add_Click({
    if ($cmbAccounts.SelectedIndex -ge 0) {
        $a = $script:AccList[$cmbAccounts.SelectedIndex]
        Set-ItemProperty "HKCU:\Software\Valve\Steam" -Name "AutoLoginUser" -Value $a.name
        Write-Log "Profile Switch: $($a.name). Rebooting Steam..."; Restart-Steam
    }
})
$btnClear.Add_Click({ $txtLog.Text = "" })
$btnImport.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Multiselect=$true; $dlg.Filter="Manifests & Scripts|*.manifest;*.lua"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Import-Files $dlg.FileNames; Write-Log "Manifest cycle complete." }
})
$btnAbout.Add_Click({ [System.Windows.MessageBox]::Show("SteamShell ELITE v$script:AppVersion`nPower User Environment`n`ngithub.com/kozaaaaczx/steam-lua","Elite Shell",0,64) })
$chkOnTop.Add_Checked({ $w.Topmost=$true }); $chkOnTop.Add_Unchecked({ $w.Topmost=$false })

$btnDepot.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\depotcache' } catch {} })
$btnLua.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config\stplug-in' } catch {} })
$btnConfig.Add_Click({ try { Start-Process 'C:\Program Files (x86)\Steam\config' } catch {} })
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="steam.exe|steam.exe"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $script:SteamExeOverride=$dlg.FileName; Write-Log "Core Path Linked: $($dlg.FileName)" }
})

# DragDrop
$w.Add_DragEnter({ param($s,$e) if($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){$e.Effects='Copy'} })
$w.Add_Drop({ param($s,$e) Import-Files ($e.Data.GetData([System.Windows.DataFormats]::FileDrop)); Write-Log "Drag & Drop sync finished." })

# Timer
$t = New-Object System.Windows.Threading.DispatcherTimer; $t.Interval=[TimeSpan]::FromSeconds(2.5)
$t.Add_Tick({ Update-Status }); $t.Start()

# Startup
Update-Accounts; Update-Status; Write-Log "Elite Environment v$script:AppVersion Stable."
$w.ShowDialog() | Out-Null