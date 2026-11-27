<#PSScriptInfo

.VERSION 1.0.0

.GUID be6e1200-1c0c-4b58-8f67-f206dda25d1c

.AUTHOR waresoft

.COMPANYNAME waresoft

.COPYRIGHT (c) 2026 waresoft. All rights reserved.

.TAGS PSEdition_Desktop PSEdition_Core Windows Windows11 PowerShell WPF GUI Shortcut Shortcuts Desktop UWP MSIX MicrosoftStore AppsFolder IconPicker DarkMode Utility

.LICENSEURI https://opensource.org/licenses/MIT

.PROJECTURI https://www.powershellgallery.com/packages/Shortcut-Studio/

.RELEASENOTES
v1.0.0

Initial release of **Shortcut Studio**, a Windows 11 Fluent Desktop shortcut builder for Microsoft Store apps, executables, folders, and URLs.

Highlights
- Microsoft Store & App Browser:** Scans `shell:AppsFolder` with instant search, a **Store Only / All Apps** toggle, one-click access to `shell:AppsFolder`, and automatic high-resolution `.ico` extraction via `IShellItemImageFactory`.
- Custom Shortcut Builder:** Creates `.lnk` and `.url` shortcuts with drag-and-drop support, custom arguments, working directory, window style, Public Desktop placement, and native **Run as administrator** flagging.
- Visual Icon Grid Picker:** Browse and filter embedded icons from `.dll`, `.exe`, and `.ico` files with quick presets for `imageres.dll`, `shell32.dll`, `ddores.dll`, and `pifmgr.dll`.
- Adaptive Windows 11 Fluent UI:** Supports **Auto** (live system theme sync), **Dark**, and **Light** modes with native DWM dark title bars and rounded window corners.
- PS 5.1 & 7.x Compatible:** Runs with zero external dependencies and relaunches elevated in your exact active PowerShell host (`powershell.exe` or `pwsh.exe`) with the console window hidden.

#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Shortcut Studio - Windows 11 Fluent Desktop Shortcut Creator (PS 5.1 & 7.x)
.DESCRIPTION
    Shortcut Studio is a lightweight, zero-dependency Windows 11 utility built in PowerShell and WPF that makes creating Desktop shortcuts effortless for Microsoft Store (UWP/MSIX) apps, Win32 programs, folders, scripts, and web URLs. Featuring a native Fluent interface with live Auto/Dark/Light theme synchronization, DWM dark title bars, host-matched UAC elevation, live Shell icon extraction, and a visual icon grid browser, it runs natively on both Windows PowerShell 5.1 and PowerShell 7.x.




.PARAMETER Theme
    Initial theme mode: Auto, Dark, or Light. Defaults to Auto.
.PARAMETER HideConsole
    Hides the attached PowerShell console window on startup (used automatically on relaunch).
#>

[CmdletBinding()]
param(
    [ValidateSet('Auto', 'Dark', 'Light')]
    [string]$Theme = 'Auto',

    [switch]$HideConsole
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CurrentPowerShellHostPath {
    $exeName = if ($PSVersionTable.PSVersion.Major -ge 6 -or $PSVersionTable.PSEdition -eq 'Core') {
        'pwsh.exe'
    }
    else {
        'powershell.exe'
    }

    $psHomeCandidate = Join-Path $PSHOME $exeName
    if (Test-Path -LiteralPath $psHomeCandidate -PathType Leaf) {
        return $psHomeCandidate
    }

    $procPath = (Get-Process -Id $PID).Path
    if ($procPath -and (Test-Path -LiteralPath $procPath -PathType Leaf)) {
        return $procPath
    }

    return $exeName
}

# Ensure Single-Threaded Apartment (STA) for WPF & Shell COM
if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
    $hostExe = Get-CurrentPowerShellHostPath
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath) {
        $argList = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$scriptPath`" -Theme $Theme -HideConsole"
        Start-Process -FilePath $hostExe -WindowStyle Hidden -ArgumentList $argList
        exit
    }
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Native Windows 11 DWM, Shell Image Factory, Icon Extractor & Theme Manager (C# 5 for PS 5.1 + PS 7.x)
if (-not ([System.Management.Automation.PSTypeName]'ShortcutStudio.ThemeManager').Type) {
    $wpfRefs = @(
        [System.Windows.Window].Assembly.Location,
        [System.Windows.Media.SolidColorBrush].Assembly.Location,
        [System.Windows.Media.Imaging.BitmapSource].Assembly.Location,
        [System.Windows.Interop.Imaging].Assembly.Location,
        [System.Windows.DependencyObject].Assembly.Location,
        [System.Windows.Markup.IUriContext].Assembly.Location,
        [System.ComponentModel.INotifyPropertyChanged].Assembly.Location,
        [System.ComponentModel.TypeConverter].Assembly.Location
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    Add-Type -ReferencedAssemblies $wpfRefs -TypeDefinition @"
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace ShortcutStudio {
    [StructLayout(LayoutKind.Sequential)]
    public struct SIZE {
        public int cx;
        public int cy;
        public SIZE(int x, int y) {
            cx = x;
            cy = y;
        }
    }

    [ComImport]
    [Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IShellItemImageFactory {
        [PreserveSig]
        int GetImage([In] SIZE size, [In] int flags, [Out] out IntPtr phbm);
    }

    public static class NativeMethods {
        [DllImport("dwmapi.dll", PreserveSig = true)]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("gdi32.dll", SetLastError = true)]
        public static extern bool DeleteObject(IntPtr hObject);

        [DllImport("kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
        public static extern int SHCreateItemFromParsingName(
            [MarshalAs(UnmanagedType.LPWStr)] string pszPath,
            IntPtr pbc,
            [MarshalAs(UnmanagedType.LPStruct)] Guid riid,
            [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory ppv
        );

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        public static extern uint ExtractIconExW(
            string lpszFile,
            int nIconIndex,
            IntPtr[] phiconLarge,
            IntPtr[] phiconSmall,
            uint nIcons
        );

        public static void HideConsoleWindow() {
            IntPtr hwnd = GetConsoleWindow();
            if (hwnd != IntPtr.Zero) {
                ShowWindow(hwnd, 0);
            }
        }

        public static void ApplyWindowChromeAttributes(IntPtr hwnd, bool darkMode) {
            if (hwnd == IntPtr.Zero) return;
            int useDark = darkMode ? 1 : 0;
            if (DwmSetWindowAttribute(hwnd, 20, ref useDark, sizeof(int)) != 0) {
                DwmSetWindowAttribute(hwnd, 19, ref useDark, sizeof(int));
            }
            int cornerPref = 2;
            DwmSetWindowAttribute(hwnd, 33, ref cornerPref, sizeof(int));
        }

        public static BitmapSource ExtractShellItemBitmapSource(string parsingName, int pixelSize) {
            if (string.IsNullOrEmpty(parsingName)) return null;
            IShellItemImageFactory factory = null;
            IntPtr hBitmap = IntPtr.Zero;
            try {
                Guid iid = new Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b");
                int hr = SHCreateItemFromParsingName(parsingName, IntPtr.Zero, iid, out factory);
                if (hr != 0 || factory == null) return null;

                // Try SIIGBF_ICONONLY (0x04) first for crisp transparent app icons, fallback to SIIGBF_RESIZETOFIT (0x00)
                hr = factory.GetImage(new SIZE(pixelSize, pixelSize), 0x04, out hBitmap);
                if (hr != 0 || hBitmap == IntPtr.Zero) {
                    hr = factory.GetImage(new SIZE(pixelSize, pixelSize), 0x00, out hBitmap);
                }
                if (hr != 0 || hBitmap == IntPtr.Zero) return null;

                BitmapSource bs = Imaging.CreateBitmapSourceFromHBitmap(
                    hBitmap,
                    IntPtr.Zero,
                    Int32Rect.Empty,
                    BitmapSizeOptions.FromEmptyOptions()
                );
                bs.Freeze();
                return bs;
            }
            catch {
                return null;
            }
            finally {
                if (hBitmap != IntPtr.Zero) {
                    DeleteObject(hBitmap);
                }
                if (factory != null) {
                    Marshal.ReleaseComObject(factory);
                }
            }
        }

        public static bool SaveBitmapSourceAsIco(BitmapSource source, string icoPath) {
            if (source == null || string.IsNullOrEmpty(icoPath)) return false;
            try {
                PngBitmapEncoder encoder = new PngBitmapEncoder();
                encoder.Frames.Add(BitmapFrame.Create(source));
                byte[] pngBytes;
                using (MemoryStream ms = new MemoryStream()) {
                    encoder.Save(ms);
                    pngBytes = ms.ToArray();
                }

                byte wByte = (source.PixelWidth >= 256) ? (byte)0 : (byte)source.PixelWidth;
                byte hByte = (source.PixelHeight >= 256) ? (byte)0 : (byte)source.PixelHeight;

                using (FileStream fs = new FileStream(icoPath, FileMode.Create, FileAccess.Write))
                using (BinaryWriter bw = new BinaryWriter(fs)) {
                    bw.Write((ushort)0);
                    bw.Write((ushort)1);
                    bw.Write((ushort)1);

                    bw.Write(wByte);
                    bw.Write(hByte);
                    bw.Write((byte)0);
                    bw.Write((byte)0);
                    bw.Write((ushort)1);
                    bw.Write((ushort)32);
                    bw.Write((uint)pngBytes.Length);
                    bw.Write((uint)22);

                    bw.Write(pngBytes);
                    bw.Flush();
                }
                return true;
            }
            catch {
                return false;
            }
        }

        public static int GetEmbeddedIconCount(string filePath) {
            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return 0;
            try {
                return (int)ExtractIconExW(filePath, -1, null, null, 0);
            }
            catch {
                return 0;
            }
        }

        public static BitmapSource ExtractIndexedIcon(string filePath, int index) {
            if (string.IsNullOrEmpty(filePath) || !File.Exists(filePath)) return null;
            IntPtr[] large = new IntPtr[1];
            IntPtr[] small = new IntPtr[1];
            try {
                uint extracted = ExtractIconExW(filePath, index, large, small, 1);
                IntPtr hIcon = (large[0] != IntPtr.Zero) ? large[0] : small[0];
                if (extracted == 0 || hIcon == IntPtr.Zero) return null;

                BitmapSource bs = Imaging.CreateBitmapSourceFromHIcon(
                    hIcon,
                    Int32Rect.Empty,
                    BitmapSizeOptions.FromWidthAndHeight(48, 48)
                );
                bs.Freeze();
                return bs;
            }
            catch {
                return null;
            }
            finally {
                if (large[0] != IntPtr.Zero) DestroyIcon(large[0]);
                if (small[0] != IntPtr.Zero) DestroyIcon(small[0]);
            }
        }
    }

    public class ThemeManager : INotifyPropertyChanged {
        public event PropertyChangedEventHandler PropertyChanged;

        public SolidColorBrush BgBrush { get; private set; }
        public SolidColorBrush SurfaceBrush { get; private set; }
        public SolidColorBrush CardBrush { get; private set; }
        public SolidColorBrush CardHoverBrush { get; private set; }
        public SolidColorBrush InputBrush { get; private set; }
        public SolidColorBrush BorderBrush { get; private set; }
        public SolidColorBrush TextBrush { get; private set; }
        public SolidColorBrush MutedBrush { get; private set; }
        public SolidColorBrush AccentBrush { get; private set; }
        public SolidColorBrush AccentHoverBrush { get; private set; }
        public SolidColorBrush AccentTextBrush { get; private set; }
        public SolidColorBrush SelectedBgBrush { get; private set; }
        public SolidColorBrush SelectedBdBrush { get; private set; }
        public SolidColorBrush ScrollThumbBrush { get; private set; }
        public SolidColorBrush ElevationBgBrush { get; private set; }
        public SolidColorBrush ElevationFgBrush { get; private set; }

        public ThemeManager() {
            Configure(true, false);
        }

        private static SolidColorBrush MakeBrush(string hex) {
            string h = hex.TrimStart('#');
            byte a = 255;
            int offset = 0;
            if (h.Length == 8) {
                a = Convert.ToByte(h.Substring(0, 2), 16);
                offset = 2;
            }
            byte r = Convert.ToByte(h.Substring(offset, 2), 16);
            byte g = Convert.ToByte(h.Substring(offset + 2, 2), 16);
            byte b = Convert.ToByte(h.Substring(offset + 4, 2), 16);
            SolidColorBrush brush = new SolidColorBrush(Color.FromArgb(a, r, g, b));
            brush.Freeze();
            return brush;
        }

        private void OnPropertyChanged(string name) {
            PropertyChangedEventHandler handler = PropertyChanged;
            if (handler != null) {
                handler(this, new PropertyChangedEventArgs(name));
            }
        }

        public void Configure(bool darkMode, bool isElevated) {
            if (darkMode) {
                BgBrush          = MakeBrush("#121418");
                SurfaceBrush     = MakeBrush("#1A1D24");
                CardBrush        = MakeBrush("#21252E");
                CardHoverBrush   = MakeBrush("#2A2F3B");
                InputBrush       = MakeBrush("#161920");
                BorderBrush      = MakeBrush("#2E3440");
                TextBrush        = MakeBrush("#F3F4F6");
                MutedBrush       = MakeBrush("#9CA3AF");
                AccentBrush      = MakeBrush("#38BDF8");
                AccentHoverBrush = MakeBrush("#0EA5E9");
                AccentTextBrush  = MakeBrush("#0B1120");
                SelectedBgBrush  = MakeBrush("#1E3A52");
                SelectedBdBrush  = MakeBrush("#38BDF8");
                ScrollThumbBrush = MakeBrush("#3B4252");
                ElevationBgBrush = isElevated ? MakeBrush("#14532D") : MakeBrush("#78350F");
                ElevationFgBrush = isElevated ? MakeBrush("#86EFAC") : MakeBrush("#FDE68A");
            } else {
                BgBrush          = MakeBrush("#F1F5F9");
                SurfaceBrush     = MakeBrush("#FFFFFF");
                CardBrush        = MakeBrush("#FFFFFF");
                CardHoverBrush   = MakeBrush("#F8FAFC");
                InputBrush       = MakeBrush("#F8FAFC");
                BorderBrush      = MakeBrush("#CBD5E1");
                TextBrush        = MakeBrush("#0F172A");
                MutedBrush       = MakeBrush("#64748B");
                AccentBrush      = MakeBrush("#0284C7");
                AccentHoverBrush = MakeBrush("#0369A1");
                AccentTextBrush  = MakeBrush("#FFFFFF");
                SelectedBgBrush  = MakeBrush("#E0F2FE");
                SelectedBdBrush  = MakeBrush("#0284C7");
                ScrollThumbBrush = MakeBrush("#CBD5E1");
                ElevationBgBrush = isElevated ? MakeBrush("#DCFCE7") : MakeBrush("#FEF3C7");
                ElevationFgBrush = isElevated ? MakeBrush("#166534") : MakeBrush("#92400E");
            }
            OnPropertyChanged(string.Empty);
        }
    }
}
"@
}

if ($HideConsole) {
    [ShortcutStudio.NativeMethods]::HideConsoleWindow()
}

# ---------------------------------------------------------------------------
# System & Theme Helpers
# ---------------------------------------------------------------------------

function Test-IsElevated {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsIsDarkMode {
    try {
        $regPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        $val = Get-ItemPropertyValue -Path $regPath -Name 'AppsUseLightTheme' -ErrorAction Stop
        return ($val -eq 0)
    }
    catch {
        return $true
    }
}

function Resolve-UseDarkMode {
    param([string]$Mode)
    switch ($Mode) {
        'Dark'  { return $true }
        'Light' { return $false }
        default { return (Get-WindowsIsDarkMode) }
    }
}

# ---------------------------------------------------------------------------
# App Discovery & Shortcut Creation Engine
# ---------------------------------------------------------------------------

function Get-InstalledAppsInventory {
    $list = New-Object 'System.Collections.Generic.List[PSObject]'
    $shell = $null

    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace('shell:AppsFolder')
        if ($folder) {
            foreach ($item in $folder.Items()) {
                $name = $item.Name
                $path = $item.Path
                if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($path)) {
                    continue
                }

                $isStore = ($path -like '*!*')
                $parsingName = "shell:AppsFolder\$path"
                $iconImg = [ShortcutStudio.NativeMethods]::ExtractShellItemBitmapSource($parsingName, 48)

                $subtitle = $path
                if ($isStore) {
                    $familyPart = ($path -split '!')[0]
                    $underIdx = $familyPart.LastIndexOf('_')
                    $subtitle = if ($underIdx -gt 0) { $familyPart.Substring(0, $underIdx) } else { $familyPart }
                }

                $list.Add([PSCustomObject]@{
                    Name        = $name
                    Subtitle    = $subtitle
                    Path        = $path
                    ParsingName = $parsingName
                    IsStoreApp  = $isStore
                    BadgeText   = if ($isStore) { 'STORE' } else { 'WIN32' }
                    IconImage   = $iconImg
                })
            }
        }
    }
    finally {
        if ($shell) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
        }
    }

    return @($list | Sort-Object -Property Name)
}

function Get-SanitizedFileName {
    param([string]$Name)
    $clean = $Name.Trim()
    foreach ($ch in [System.IO.Path]::GetInvalidFileNameChars()) {
        $clean = $clean.Replace($ch, '_')
    }
    return $clean
}

function New-DesktopShortcut {
    param(
        [Parameter(Mandatory)][string]$ShortcutName,
        [Parameter(Mandatory)][string]$TargetPath,
        [string]$Arguments = '',
        [string]$WorkingDirectory = '',
        [string]$IconLocation = '',
        [int]$WindowStyle = 1,
        [bool]$RunAsAdmin = $false,
        [bool]$AllUsersDesktop = $false
    )

    $desktopDir = if ($AllUsersDesktop) {
        [Environment]::GetFolderPath('CommonDesktopDirectory')
    }
    else {
        [Environment]::GetFolderPath('DesktopDirectory')
    }

    $safeName = Get-SanitizedFileName -Name $ShortcutName
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        throw 'Shortcut name cannot be empty.'
    }

    if ($TargetPath -match '^(https?|ftp|ms-settings|mailto):') {
        $urlFile = Join-Path $desktopDir "$safeName.url"
        $lines = New-Object 'System.Collections.Generic.List[string]'
        $lines.Add('[InternetShortcut]')
        $lines.Add("URL=$TargetPath")
        if (-not [string]::IsNullOrWhiteSpace($IconLocation)) {
            $iconParts = $IconLocation -split ','
            $lines.Add("IconFile=$($iconParts[0])")
            $idx = if ($iconParts.Count -gt 1) { $iconParts[1].Trim() } else { '0' }
            $lines.Add("IconIndex=$idx")
        }
        [System.IO.File]::WriteAllLines($urlFile, $lines, [System.Text.Encoding]::UTF8)
        return $urlFile
    }

    $lnkFile = Join-Path $desktopDir "$safeName.lnk"
    $wsh = $null
    try {
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnkFile)
        $sc.TargetPath = $TargetPath
        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
            $sc.Arguments = $Arguments
        }
        if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
            $sc.WorkingDirectory = $WorkingDirectory
        }
        elseif ($TargetPath -match '^[a-zA-Z]:\\' -and (Test-Path -LiteralPath $TargetPath -PathType Leaf)) {
            $sc.WorkingDirectory = Split-Path -Path $TargetPath -Parent
        }
        if (-not [string]::IsNullOrWhiteSpace($IconLocation)) {
            $sc.IconLocation = $IconLocation
        }
        $sc.WindowStyle = $WindowStyle
        $sc.Save()
    }
    finally {
        if ($wsh) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wsh)
        }
    }

    if ($RunAsAdmin -and (Test-Path -LiteralPath $lnkFile)) {
        $bytes = [System.IO.File]::ReadAllBytes($lnkFile)
        if ($bytes.Length -gt 21) {
            $bytes[21] = $bytes[21] -bor 0x20
            [System.IO.File]::WriteAllBytes($lnkFile, $bytes)
        }
    }

    return $lnkFile
}

# ---------------------------------------------------------------------------
# Visual .DLL / .EXE / .ICO Icon Picker Modal
# ---------------------------------------------------------------------------

function Show-IconPickerDialog {
    param(
        [Parameter(Mandatory)][System.Windows.Window]$OwnerWindow,
        [Parameter(Mandatory)][ShortcutStudio.ThemeManager]$ThemeManager,
        [bool]$UseDarkMode,
        [string]$InitialIconSpec = ''
    )

    $themeAssemblyName = [ShortcutStudio.ThemeManager].Assembly.GetName().Name

    $pickerXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ss="clr-namespace:ShortcutStudio;assembly=$themeAssemblyName"
        Title="Visual Icon Picker"
        Width="780" Height="560"
        MinWidth="680" MinHeight="460"
        WindowStartupLocation="CenterOwner"
        FontFamily="Segoe UI"
        FontSize="13"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True">

    <Window.Resources>
        <ss:ThemeManager x:Key="PickerTheme"/>

        <Style TargetType="{x:Type ScrollBar}">
            <Setter Property="Width" Value="8"/>
            <Setter Property="MinWidth" Value="8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid Background="Transparent" Margin="1,2">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="{x:Type Thumb}">
                                                <Border Background="{Binding ScrollThumbBrush, Source={StaticResource PickerTheme}}" CornerRadius="4"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="PickerPrimaryBtn" TargetType="Button">
            <Setter Property="Background" Value="{Binding AccentBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="Foreground" Value="{Binding AccentTextBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{Binding AccentHoverBrush, Source={StaticResource PickerTheme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="PickerSecondaryBtn" TargetType="Button">
            <Setter Property="Background" Value="{Binding CardBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="11,6"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="7"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource PickerTheme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <Style x:Key="PickerTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="{Binding InputBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="CaretBrush" Value="{Binding AccentBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource PickerTheme}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,6"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="7">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="2,0" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter Property="BorderBrush" Value="{Binding AccentBrush, Source={StaticResource PickerTheme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Window.Background>
        <Binding Path="BgBrush" Source="{StaticResource PickerTheme}"/>
    </Window.Background>
    <Window.Foreground>
        <Binding Path="TextBrush" Source="{StaticResource PickerTheme}"/>
    </Window.Foreground>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- File Path & Browse Row -->
        <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBox x:Name="TxtIconFile" Grid.Column="0" Style="{StaticResource PickerTextBox}" Margin="0,0,8,0"/>
            <Button x:Name="BtnBrowseLib" Grid.Column="1" Content="Browse .exe / .dll / .ico..." Style="{StaticResource PickerSecondaryBtn}"/>
        </Grid>

        <!-- System Library Presets + Index Filter -->
        <Grid Grid.Row="1" Margin="0,0,0,12">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="150"/>
            </Grid.ColumnDefinitions>
            <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                <TextBlock Text="Presets:" FontSize="12" Foreground="{Binding MutedBrush, Source={StaticResource PickerTheme}}" VerticalAlignment="Center" Margin="0,0,8,0"/>
                <Button x:Name="BtnPresetImageres" Content="imageres.dll" Style="{StaticResource PickerSecondaryBtn}" FontSize="11.5" Margin="0,0,6,0"/>
                <Button x:Name="BtnPresetShell32" Content="shell32.dll" Style="{StaticResource PickerSecondaryBtn}" FontSize="11.5" Margin="0,0,6,0"/>
                <Button x:Name="BtnPresetDdores" Content="ddores.dll" Style="{StaticResource PickerSecondaryBtn}" FontSize="11.5" Margin="0,0,6,0"/>
                <Button x:Name="BtnPresetPifmgr" Content="pifmgr.dll" Style="{StaticResource PickerSecondaryBtn}" FontSize="11.5"/>
            </StackPanel>
            <TextBox x:Name="TxtIndexFilter" Grid.Column="1" Style="{StaticResource PickerTextBox}" ToolTip="Filter by icon index number (e.g. 15)"/>
        </Grid>

        <!-- Icon Grid -->
        <Border Grid.Row="2"
                Background="{Binding SurfaceBrush, Source={StaticResource PickerTheme}}"
                BorderBrush="{Binding BorderBrush, Source={StaticResource PickerTheme}}"
                BorderThickness="1"
                CornerRadius="10"
                Padding="6">
            <ListBox x:Name="LstIcons"
                     Background="Transparent"
                     BorderThickness="0"
                     ScrollViewer.HorizontalScrollBarVisibility="Disabled">
                <ListBox.ItemsPanel>
                    <ItemsPanelTemplate>
                        <WrapPanel IsItemsHost="True" Orientation="Horizontal"/>
                    </ItemsPanelTemplate>
                </ListBox.ItemsPanel>
                <ListBox.ItemContainerStyle>
                    <Style TargetType="ListBoxItem">
                        <Setter Property="Background" Value="{Binding CardBrush, Source={StaticResource PickerTheme}}"/>
                        <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource PickerTheme}}"/>
                        <Setter Property="Padding" Value="0"/>
                        <Setter Property="Margin" Value="5"/>
                        <Setter Property="Template">
                            <Setter.Value>
                                <ControlTemplate TargetType="ListBoxItem">
                                    <Border Background="{TemplateBinding Background}"
                                            BorderBrush="{TemplateBinding BorderBrush}"
                                            BorderThickness="1"
                                            CornerRadius="8"
                                            Width="78" Height="78"
                                            Cursor="Hand">
                                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                    </Border>
                                </ControlTemplate>
                            </Setter.Value>
                        </Setter>
                        <Style.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource PickerTheme}}"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Background" Value="{Binding SelectedBgBrush, Source={StaticResource PickerTheme}}"/>
                                <Setter Property="BorderBrush" Value="{Binding SelectedBdBrush, Source={StaticResource PickerTheme}}"/>
                            </Trigger>
                        </Style.Triggers>
                    </Style>
                </ListBox.ItemContainerStyle>
                <ListBox.ItemTemplate>
                    <DataTemplate>
                        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                            <Image Source="{Binding Image}" Width="36" Height="36" RenderOptions.BitmapScalingMode="HighQuality" Margin="0,2,0,5"/>
                            <TextBlock Text="{Binding Label}" FontSize="11" Foreground="{Binding MutedBrush, Source={StaticResource PickerTheme}}" HorizontalAlignment="Center"/>
                        </StackPanel>
                    </DataTemplate>
                </ListBox.ItemTemplate>
            </ListBox>
        </Border>

        <!-- Footer -->
        <Grid Grid.Row="3" Margin="0,12,0,0">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock x:Name="TxtPickerStatus" Grid.Column="0" Text="Select an icon tile..." FontSize="12" Foreground="{Binding MutedBrush, Source={StaticResource PickerTheme}}" VerticalAlignment="Center"/>
            <Button x:Name="BtnPickerCancel" Grid.Column="1" Content="Cancel" Style="{StaticResource PickerSecondaryBtn}" Margin="0,0,8,0"/>
            <Button x:Name="BtnPickerUse" Grid.Column="2" Content="Use Selected Icon" Style="{StaticResource PickerPrimaryBtn}"/>
        </Grid>
    </Grid>
</Window>
"@

    [xml]$pxml = $pickerXaml
    $pReader = New-Object System.Xml.XmlNodeReader($pxml)
    $pickerWin = [System.Windows.Markup.XamlReader]::Load($pReader)
    $pickerWin.Owner = $OwnerWindow
    $pickerTheme = $pickerWin.Resources['PickerTheme']
    $pickerTheme.Configure($UseDarkMode, $false)

    $pickerWin.Add_SourceInitialized({
        $phwnd = (New-Object System.Windows.Interop.WindowInteropHelper($pickerWin)).Handle
        if ($phwnd -ne [IntPtr]::Zero) {
            [ShortcutStudio.NativeMethods]::ApplyWindowChromeAttributes($phwnd, $UseDarkMode)
        }
    })

    $txtIconFile       = $pickerWin.FindName('TxtIconFile')
    $btnBrowseLib      = $pickerWin.FindName('BtnBrowseLib')
    $btnPresetImageres = $pickerWin.FindName('BtnPresetImageres')
    $btnPresetShell32  = $pickerWin.FindName('BtnPresetShell32')
    $btnPresetDdores   = $pickerWin.FindName('BtnPresetDdores')
    $btnPresetPifmgr   = $pickerWin.FindName('BtnPresetPifmgr')
    $txtIndexFilter    = $pickerWin.FindName('TxtIndexFilter')
    $lstIcons          = $pickerWin.FindName('LstIcons')
    $txtPickerStatus   = $pickerWin.FindName('TxtPickerStatus')
    $btnPickerCancel   = $pickerWin.FindName('BtnPickerCancel')
    $btnPickerUse      = $pickerWin.FindName('BtnPickerUse')

    $script:PickerAllTiles = @()
    $script:PickerSelectedResult = $null

    $loadIconLibrary = {
        param([string]$LibPath, [int]$SelectIndex = 0)
        $cleanPath = [Environment]::ExpandEnvironmentVariables($LibPath.Trim().Trim('"'))
        if (-not (Test-Path -LiteralPath $cleanPath -PathType Leaf)) {
            $txtPickerStatus.Text = "File not found: $cleanPath"
            $lstIcons.ItemsSource = @()
            return
        }

        $txtIconFile.Text = $cleanPath
        $total = [ShortcutStudio.NativeMethods]::GetEmbeddedIconCount($cleanPath)
        if ($total -le 0) {
            $txtPickerStatus.Text = 'No embedded icons found in this file.'
            $lstIcons.ItemsSource = @()
            return
        }

        $limit = [Math]::Min($total, 450)
        $tiles = New-Object 'System.Collections.Generic.List[PSObject]'
        for ($i = 0; $i -lt $limit; $i++) {
            $bmp = [ShortcutStudio.NativeMethods]::ExtractIndexedIcon($cleanPath, $i)
            if ($bmp) {
                $tiles.Add([PSCustomObject]@{
                    Index = $i
                    Label = "#$i"
                    Image = $bmp
                })
            }
        }

        $script:PickerAllTiles = @($tiles)
        $lstIcons.ItemsSource = $script:PickerAllTiles
        $txtPickerStatus.Text = "Loaded $($script:PickerAllTiles.Count) of $total icons from $(Split-Path -Path $cleanPath -Leaf)"

        $match = $script:PickerAllTiles | Where-Object { $_.Index -eq $SelectIndex } | Select-Object -First 1
        if ($match) {
            $lstIcons.SelectedItem = $match
            $lstIcons.ScrollIntoView($match)
        }
    }

    $txtIndexFilter.Add_TextChanged({
        $q = $txtIndexFilter.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($q)) {
            $lstIcons.ItemsSource = $script:PickerAllTiles
        }
        else {
            $lstIcons.ItemsSource = @($script:PickerAllTiles | Where-Object { $_.Label -like "*$q*" })
        }
    })

    $btnPresetImageres.Add_Click({ & $loadIconLibrary "$env:WINDIR\System32\imageres.dll" 0 })
    $btnPresetShell32.Add_Click({ & $loadIconLibrary "$env:WINDIR\System32\shell32.dll" 0 })
    $btnPresetDdores.Add_Click({ & $loadIconLibrary "$env:WINDIR\System32\ddores.dll" 0 })
    $btnPresetPifmgr.Add_Click({ & $loadIconLibrary "$env:WINDIR\System32\pifmgr.dll" 0 })

    $btnBrowseLib.Add_Click({
        $dlg = New-Object Microsoft.Win32.OpenFileDialog
        $dlg.Title = 'Select Icon Library or Executable'
        $dlg.Filter = 'Icon Sources (*.dll;*.exe;*.ico)|*.dll;*.exe;*.ico|All Files (*.*)|*.*'
        if ($dlg.ShowDialog()) {
            & $loadIconLibrary $dlg.FileName 0
        }
    })

    $lstIcons.Add_SelectionChanged({
        $sel = $lstIcons.SelectedItem
        if ($sel) {
            $txtPickerStatus.Text = "Selected: $($txtIconFile.Text),$($sel.Index)"
        }
    })

    $lstIcons.Add_MouseDoubleClick({
        $sel = $lstIcons.SelectedItem
        if ($sel) {
            $script:PickerSelectedResult = "$($txtIconFile.Text),$($sel.Index)"
            $pickerWin.DialogResult = $true
            $pickerWin.Close()
        }
    })

    $btnPickerUse.Add_Click({
        $sel = $lstIcons.SelectedItem
        if ($sel) {
            $script:PickerSelectedResult = "$($txtIconFile.Text),$($sel.Index)"
            $pickerWin.DialogResult = $true
            $pickerWin.Close()
        }
    })

    $btnPickerCancel.Add_Click({
        $pickerWin.DialogResult = $false
        $pickerWin.Close()
    })

    $startLib = "$env:WINDIR\System32\imageres.dll"
    $startIdx = 0
    if (-not [string]::IsNullOrWhiteSpace($InitialIconSpec)) {
        $parts = $InitialIconSpec -split ','
        $candidatePath = [Environment]::ExpandEnvironmentVariables($parts[0].Trim().Trim('"'))
        if ((Test-Path -LiteralPath $candidatePath -PathType Leaf) -and ([ShortcutStudio.NativeMethods]::GetEmbeddedIconCount($candidatePath) -gt 0)) {
            $startLib = $candidatePath
            if ($parts.Count -gt 1 -and ($parts[1].Trim() -match '^\d+$')) {
                $startIdx = [int]$parts[1].Trim()
            }
        }
    }

    & $loadIconLibrary $startLib $startIdx
    [void]$pickerWin.ShowDialog()
    return $script:PickerSelectedResult
}

# ---------------------------------------------------------------------------
# WPF Fluent UI Definition (Data-Bound to INotifyPropertyChanged ThemeManager)
# ---------------------------------------------------------------------------

$themeAssemblyName = [ShortcutStudio.ThemeManager].Assembly.GetName().Name

$xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:ss="clr-namespace:ShortcutStudio;assembly=$themeAssemblyName"
        Title="Shortcut Studio"
        Width="1060" Height="700"
        MinWidth="940" MinHeight="620"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI"
        FontSize="13"
        AllowDrop="True"
        UseLayoutRounding="True"
        SnapsToDevicePixels="True">

    <Window.Resources>
        <ss:ThemeManager x:Key="Theme"/>

        <!-- Slim Modern ScrollBar -->
        <Style TargetType="{x:Type ScrollBar}">
            <Setter Property="Width" Value="8"/>
            <Setter Property="MinWidth" Value="8"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid Background="Transparent" Margin="1,2">
                            <Track x:Name="PART_Track" IsDirectionReversed="True">
                                <Track.Thumb>
                                    <Thumb>
                                        <Thumb.Template>
                                            <ControlTemplate TargetType="{x:Type Thumb}">
                                                <Border Background="{Binding ScrollThumbBrush, Source={StaticResource Theme}}" CornerRadius="4"/>
                                            </ControlTemplate>
                                        </Thumb.Template>
                                    </Thumb>
                                </Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Primary Accent Button -->
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Foreground" Value="{Binding AccentTextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="18,9"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="Bd" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{Binding AccentHoverBrush, Source={StaticResource Theme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Secondary Surface Button -->
        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="{Binding CardBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="13,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="7"
                                Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource Theme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Segmented Pill RadioButton -->
        <Style x:Key="PillRadio" TargetType="RadioButton">
            <Setter Property="Foreground" Value="{Binding MutedBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="12,5"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="5" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsChecked" Value="True">
                    <Setter Property="Background" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
                    <Setter Property="Foreground" Value="{Binding AccentTextBrush, Source={StaticResource Theme}}"/>
                </Trigger>
                <MultiTrigger>
                    <MultiTrigger.Conditions>
                        <Condition Property="IsMouseOver" Value="True"/>
                        <Condition Property="IsChecked" Value="False"/>
                    </MultiTrigger.Conditions>
                    <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource Theme}}"/>
                    <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
                </MultiTrigger>
            </Style.Triggers>
        </Style>

        <!-- Modern Rounded TextBox -->
        <Style x:Key="ModernTextBox" TargetType="TextBox">
            <Setter Property="Background" Value="{Binding InputBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="CaretBrush" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="Bd"
                                Background="{TemplateBinding Background}"
                                BorderBrush="{TemplateBinding BorderBrush}"
                                BorderThickness="{TemplateBinding BorderThickness}"
                                CornerRadius="7">
                            <ScrollViewer x:Name="PART_ContentHost" Margin="2,0" VerticalAlignment="Center"/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsKeyboardFocused" Value="True">
                    <Setter Property="BorderBrush" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Modern CheckBox -->
        <Style x:Key="ModernCheckBox" TargetType="CheckBox">
            <Setter Property="Background" Value="{Binding InputBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="Box"
                                    Width="18" Height="18"
                                    CornerRadius="5"
                                    Background="{TemplateBinding Background}"
                                    BorderBrush="{TemplateBinding BorderBrush}"
                                    BorderThickness="1">
                                <TextBlock x:Name="CheckGlyph"
                                           Text="&#xE73E;"
                                           FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                           FontSize="11"
                                           Foreground="{Binding AccentTextBrush, Source={StaticResource Theme}}"
                                           HorizontalAlignment="Center"
                                           VerticalAlignment="Center"
                                           Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter Margin="9,0,0,0" VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="CheckGlyph" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsChecked" Value="True">
                    <Setter Property="Background" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
                    <Setter Property="BorderBrush" Value="{Binding AccentBrush, Source={StaticResource Theme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>

        <!-- Modern ComboBox -->
        <Style x:Key="ModernComboBox" TargetType="ComboBox">
            <Setter Property="Background" Value="{Binding InputBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderBrush" Value="{Binding BorderBrush, Source={StaticResource Theme}}"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton x:Name="ToggleButton"
                                          Focusable="False"
                                          IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"
                                          ClickMode="Press">
                                <ToggleButton.Template>
                                    <ControlTemplate TargetType="ToggleButton">
                                        <Border Background="{Binding InputBrush, Source={StaticResource Theme}}"
                                                BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                                                BorderThickness="1"
                                                CornerRadius="7">
                                            <TextBlock Text="&#xE70D;"
                                                       FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                                       FontSize="11"
                                                       Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"
                                                       HorizontalAlignment="Right"
                                                       VerticalAlignment="Center"
                                                       Margin="0,0,10,0"/>
                                        </Border>
                                    </ControlTemplate>
                                </ToggleButton.Template>
                            </ToggleButton>
                            <ContentPresenter IsHitTestVisible="False"
                                              Content="{TemplateBinding SelectionBoxItem}"
                                              ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                              Margin="11,0,28,0"
                                              VerticalAlignment="Center"
                                              HorizontalAlignment="Left"/>
                            <Popup x:Name="Popup"
                                   Placement="Bottom"
                                   IsOpen="{TemplateBinding IsDropDownOpen}"
                                   AllowsTransparency="True"
                                   Focusable="False"
                                   PopupAnimation="Fade">
                                <Border Background="{Binding CardBrush, Source={StaticResource Theme}}"
                                        BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                                        BorderThickness="1"
                                        CornerRadius="7"
                                        Margin="0,4,0,0"
                                        MinWidth="{TemplateBinding ActualWidth}">
                                    <ScrollViewer MaxHeight="200">
                                        <ItemsPresenter/>
                                    </ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Padding" Value="10,7"/>
            <Setter Property="Foreground" Value="{Binding TextBrush, Source={StaticResource Theme}}"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}" CornerRadius="5" Margin="3,2">
                            <ContentPresenter/>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
            <Style.Triggers>
                <Trigger Property="IsHighlighted" Value="True">
                    <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource Theme}}"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>

    <Window.Background>
        <Binding Path="BgBrush" Source="{StaticResource Theme}"/>
    </Window.Background>
    <Window.Foreground>
        <Binding Path="TextBrush" Source="{StaticResource Theme}"/>
    </Window.Foreground>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- TOP HEADER BAR -->
        <Border Grid.Row="0"
                Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                BorderThickness="0,0,0,1"
                Padding="22,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <Grid Grid.Column="0" VerticalAlignment="Center" Margin="0,0,16,0">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Border Grid.Column="0" Width="38" Height="38" CornerRadius="9" Background="{Binding AccentBrush, Source={StaticResource Theme}}" Margin="0,0,13,0">
                        <TextBlock Text="&#xE71B;"
                                   FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                   FontSize="18"
                                   Foreground="{Binding AccentTextBrush, Source={StaticResource Theme}}"
                                   HorizontalAlignment="Center"
                                   VerticalAlignment="Center"/>
                    </Border>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                        <TextBlock Text="Shortcut Studio" FontSize="18" FontWeight="SemiBold" Foreground="{Binding TextBrush, Source={StaticResource Theme}}"/>
                        <TextBlock x:Name="TxtSubtitle" Text="Windows 11 Store &amp; Desktop Shortcut Builder" FontSize="12" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" TextTrimming="CharacterEllipsis" Margin="0,1,0,0"/>
                    </StackPanel>
                </Grid>

                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <!-- Elevation Pill -->
                    <Border Background="{Binding ElevationBgBrush, Source={StaticResource Theme}}" CornerRadius="6" Padding="10,5" Margin="0,0,8,0" VerticalAlignment="Center">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xEA18;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" Foreground="{Binding ElevationFgBrush, Source={StaticResource Theme}}" VerticalAlignment="Center" Margin="0,0,6,0"/>
                            <TextBlock x:Name="TxtElevation" Text="Standard User" FontSize="12" FontWeight="SemiBold" Foreground="{Binding ElevationFgBrush, Source={StaticResource Theme}}" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>

                    <Button x:Name="BtnElevate" Style="{StaticResource SecondaryButton}" Margin="0,0,12,0" ToolTip="Relaunch in the exact same PowerShell host with UAC elevation">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE72E;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="12" VerticalAlignment="Center" Margin="0,0,6,0"/>
                            <TextBlock Text="Run as Admin" FontSize="12" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Button>

                    <!-- Theme Segmented Control -->
                    <Border Background="{Binding InputBrush, Source={StaticResource Theme}}"
                            BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                            BorderThickness="1"
                            CornerRadius="7"
                            Padding="3">
                        <StackPanel Orientation="Horizontal">
                            <RadioButton x:Name="RbThemeAuto" Content="Auto" Style="{StaticResource PillRadio}" GroupName="ThemeGroup" IsChecked="True"/>
                            <RadioButton x:Name="RbThemeDark" Content="Dark" Style="{StaticResource PillRadio}" GroupName="ThemeGroup" Margin="2,0"/>
                            <RadioButton x:Name="RbThemeLight" Content="Light" Style="{StaticResource PillRadio}" GroupName="ThemeGroup"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>
        </Border>

        <!-- NAVIGATION & QUICK EXPLORER BAR -->
        <Border Grid.Row="1" Background="{Binding BgBrush, Source={StaticResource Theme}}" Padding="22,14,22,4">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Mode Switcher Pills -->
                <Border Grid.Column="0"
                        HorizontalAlignment="Left"
                        Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                        BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                        BorderThickness="1"
                        CornerRadius="8"
                        Padding="4">
                    <StackPanel Orientation="Horizontal">
                        <RadioButton x:Name="RbTabStore" Style="{StaticResource PillRadio}" GroupName="ViewGroup" IsChecked="True" Padding="14,7">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE719;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                <TextBlock Text="Microsoft Store Apps" FontSize="12.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </RadioButton>
                        <RadioButton x:Name="RbTabCustom" Style="{StaticResource PillRadio}" GroupName="ViewGroup" Margin="4,0,0,0" Padding="14,7">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE8A5;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center" Margin="0,0,7,0"/>
                                <TextBlock Text="Custom File, Folder, or URL" FontSize="12.5" VerticalAlignment="Center"/>
                            </StackPanel>
                        </RadioButton>
                    </StackPanel>
                </Border>

                <!-- Quick Shell Folders -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnOpenDesktop" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xE8FC;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center" Margin="0,0,7,0"/>
                            <TextBlock Text="Open Desktop" FontSize="12"/>
                        </StackPanel>
                    </Button>
                    <Button x:Name="BtnOpenAppsFolder" Style="{StaticResource SecondaryButton}" ToolTip="Opens shell:AppsFolder directly in Windows Explorer">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="&#xED25;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Foreground="{Binding AccentBrush, Source={StaticResource Theme}}" VerticalAlignment="Center" Margin="0,0,7,0"/>
                            <TextBlock Text="Open shell:AppsFolder" FontSize="12" FontWeight="SemiBold"/>
                        </StackPanel>
                    </Button>
                </StackPanel>
            </Grid>
        </Border>

        <!-- MAIN WORKSPACE -->
        <Grid Grid.Row="2" Margin="22,10,22,14">

            <!-- VIEW 1: MICROSOFT STORE APPS -->
            <Grid x:Name="ViewStoreApps" Visibility="Visible">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>

                <!-- Search & Scope Filter Bar -->
                <Grid Grid.Row="0" Margin="0,0,0,10">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>

                    <!-- Search Box with Placeholder -->
                    <Grid Grid.Column="0" Margin="0,0,10,0">
                        <TextBox x:Name="TxtSearch" Style="{StaticResource ModernTextBox}" Padding="32,7,30,7"/>
                        <TextBlock Text="&#xE721;"
                                   FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                   FontSize="13"
                                   Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"
                                   Margin="12,0,0,0"
                                   VerticalAlignment="Center"
                                   HorizontalAlignment="Left"
                                   IsHitTestVisible="False"/>
                        <TextBlock x:Name="TxtSearchPlaceholder"
                                   Text="Search installed Microsoft Store apps..."
                                   Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"
                                   Margin="35,0,0,0"
                                   VerticalAlignment="Center"
                                   HorizontalAlignment="Left"
                                   IsHitTestVisible="False"/>
                        <Button x:Name="BtnClearSearch"
                                Content="&#xE711;"
                                FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                FontSize="10"
                                Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"
                                Background="Transparent"
                                BorderThickness="0"
                                Cursor="Hand"
                                Width="26" Height="26"
                                Margin="0,0,4,0"
                                HorizontalAlignment="Right"
                                VerticalAlignment="Center"
                                Visibility="Collapsed"/>
                    </Grid>

                    <!-- Scope Toggle: Store Only vs All Apps -->
                    <Border Grid.Column="1"
                            Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                            BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                            BorderThickness="1"
                            CornerRadius="7"
                            Padding="3"
                            Margin="0,0,8,0">
                        <StackPanel Orientation="Horizontal">
                            <RadioButton x:Name="RbScopeStoreOnly" Content="Store Only" Style="{StaticResource PillRadio}" GroupName="ScopeGroup" IsChecked="True"/>
                            <RadioButton x:Name="RbScopeAllApps" Content="All Apps" Style="{StaticResource PillRadio}" GroupName="ScopeGroup" Margin="2,0,0,0"/>
                        </StackPanel>
                    </Border>

                    <Button x:Name="BtnRefreshApps" Grid.Column="2" Style="{StaticResource SecondaryButton}" ToolTip="Rescan shell:AppsFolder">
                        <TextBlock Text="&#xE72C;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13"/>
                    </Button>
                </Grid>

                <!-- App List Card -->
                <Border Grid.Row="1"
                        Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                        BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                        BorderThickness="1"
                        CornerRadius="10"
                        Padding="4">
                    <ListBox x:Name="LstApps"
                             Background="Transparent"
                             BorderThickness="0"
                             ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                             VirtualizingPanel.IsVirtualizing="True"
                             VirtualizingPanel.ScrollUnit="Pixel">
                        <ListBox.ItemContainerStyle>
                            <Style TargetType="ListBoxItem">
                                <Setter Property="Background" Value="Transparent"/>
                                <Setter Property="BorderBrush" Value="Transparent"/>
                                <Setter Property="Padding" Value="0"/>
                                <Setter Property="Margin" Value="3,2"/>
                                <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
                                <Setter Property="Template">
                                    <Setter.Value>
                                        <ControlTemplate TargetType="ListBoxItem">
                                            <Border x:Name="RowBd"
                                                    Background="{TemplateBinding Background}"
                                                    BorderBrush="{TemplateBinding BorderBrush}"
                                                    BorderThickness="1"
                                                    CornerRadius="8"
                                                    Padding="10,8"
                                                    Cursor="Hand">
                                                <ContentPresenter/>
                                            </Border>
                                        </ControlTemplate>
                                    </Setter.Value>
                                </Setter>
                                <Style.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter Property="Background" Value="{Binding CardHoverBrush, Source={StaticResource Theme}}"/>
                                    </Trigger>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter Property="Background" Value="{Binding SelectedBgBrush, Source={StaticResource Theme}}"/>
                                        <Setter Property="BorderBrush" Value="{Binding SelectedBdBrush, Source={StaticResource Theme}}"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                        </ListBox.ItemContainerStyle>
                        <ListBox.ItemTemplate>
                            <DataTemplate>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="42"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>

                                    <!-- Live Extracted App Icon Tile -->
                                    <Border Grid.Column="0"
                                            Width="38" Height="38"
                                            CornerRadius="8"
                                            Background="{Binding CardBrush, Source={StaticResource Theme}}"
                                            BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                                            BorderThickness="1">
                                        <Grid>
                                            <TextBlock Text="&#xE719;"
                                                       FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets"
                                                       FontSize="16"
                                                       Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"
                                                       HorizontalAlignment="Center"
                                                       VerticalAlignment="Center">
                                                <TextBlock.Style>
                                                    <Style TargetType="TextBlock">
                                                        <Setter Property="Visibility" Value="Collapsed"/>
                                                        <Style.Triggers>
                                                            <DataTrigger Binding="{Binding IconImage}" Value="{x:Null}">
                                                                <Setter Property="Visibility" Value="Visible"/>
                                                            </DataTrigger>
                                                        </Style.Triggers>
                                                    </Style>
                                                </TextBlock.Style>
                                            </TextBlock>
                                            <Image Source="{Binding IconImage}" Width="28" Height="28" RenderOptions.BitmapScalingMode="HighQuality"/>
                                        </Grid>
                                    </Border>

                                    <!-- App Title & Package Identity -->
                                    <StackPanel Grid.Column="1" Margin="12,0,10,0" VerticalAlignment="Center">
                                        <TextBlock Text="{Binding Name}" FontSize="13.5" FontWeight="SemiBold" Foreground="{Binding TextBrush, Source={StaticResource Theme}}" TextTrimming="CharacterEllipsis"/>
                                        <TextBlock Text="{Binding Subtitle}" FontSize="11.5" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" TextTrimming="CharacterEllipsis" Margin="0,1,0,0"/>
                                    </StackPanel>

                                    <!-- Category Badge -->
                                    <Border Grid.Column="2"
                                            Background="{Binding InputBrush, Source={StaticResource Theme}}"
                                            BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                                            BorderThickness="1"
                                            CornerRadius="5"
                                            Padding="8,3"
                                            VerticalAlignment="Center">
                                        <TextBlock Text="{Binding BadgeText}" FontSize="10.5" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}"/>
                                    </Border>
                                </Grid>
                            </DataTemplate>
                        </ListBox.ItemTemplate>
                    </ListBox>
                </Border>

                <!-- Bottom Shortcut Action Bar -->
                <Border Grid.Row="2"
                        Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                        BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                        BorderThickness="1"
                        CornerRadius="10"
                        Padding="16,12"
                        Margin="0,10,0,0">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" Margin="0,0,16,0">
                            <TextBlock Text="Desktop Shortcut Name" FontSize="11.5" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,4"/>
                            <TextBox x:Name="TxtAppShortcutName" Style="{StaticResource ModernTextBox}"/>
                        </StackPanel>

                        <CheckBox x:Name="ChkAppAllUsers" Grid.Column="1" Content="Public Desktop (All Users)" Style="{StaticResource ModernCheckBox}" VerticalAlignment="Bottom" Margin="0,0,16,8"/>

                        <Button x:Name="BtnCreateAppShortcut" Grid.Column="2" Style="{StaticResource PrimaryButton}" VerticalAlignment="Bottom">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE710;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <TextBlock Text="Create Desktop Shortcut" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Border>
            </Grid>

            <!-- VIEW 2: CUSTOM SHORTCUT BUILDER -->
            <Border x:Name="ViewCustom"
                    Visibility="Collapsed"
                    Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                    BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                    BorderThickness="1"
                    CornerRadius="10"
                    Padding="22">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>

                    <StackPanel Grid.Row="0" Margin="0,0,0,16">
                        <TextBlock Text="Custom Shortcut Builder" FontSize="15" FontWeight="SemiBold" Foreground="{Binding TextBrush, Source={StaticResource Theme}}"/>
                        <TextBlock Text="Create a shortcut for any .exe, script, folder, or web URL - or drag and drop any item onto this window." FontSize="12" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,2,0,0"/>
                    </StackPanel>

                    <!-- Target Path -->
                    <StackPanel Grid.Row="1" Margin="0,0,0,12">
                        <TextBlock Text="Target File, Folder, or URL" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtTarget" Grid.Column="0" Style="{StaticResource ModernTextBox}" Margin="0,0,8,0"/>
                            <Button x:Name="BtnBrowseFile" Grid.Column="1" Content="Browse File..." Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
                            <Button x:Name="BtnBrowseFolder" Grid.Column="2" Content="Browse Folder..." Style="{StaticResource SecondaryButton}"/>
                        </Grid>
                    </StackPanel>

                    <!-- Shortcut Name + Window Mode -->
                    <Grid Grid.Row="2" Margin="0,0,0,12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="220"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,12,0">
                            <TextBlock Text="Desktop Shortcut Name" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                            <TextBox x:Name="TxtCustomName" Style="{StaticResource ModernTextBox}"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Window Style" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                            <ComboBox x:Name="CmbWinStyle" Style="{StaticResource ModernComboBox}" SelectedIndex="0">
                                <ComboBoxItem Content="Normal Window"/>
                                <ComboBoxItem Content="Minimized"/>
                                <ComboBoxItem Content="Maximized"/>
                            </ComboBox>
                        </StackPanel>
                    </Grid>

                    <!-- Arguments + Working Directory -->
                    <Grid Grid.Row="3" Margin="0,0,0,12">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Margin="0,0,12,0">
                            <TextBlock Text="Command-Line Arguments (Optional)" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                            <TextBox x:Name="TxtArgs" Style="{StaticResource ModernTextBox}"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1">
                            <TextBlock Text="Start In / Working Directory (Optional)" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                            <TextBox x:Name="TxtWorkDir" Style="{StaticResource ModernTextBox}"/>
                        </StackPanel>
                    </Grid>

                    <!-- Custom Icon with Visual Grid Picker -->
                    <StackPanel Grid.Row="4" Margin="0,0,0,14">
                        <TextBlock Text="Custom Icon Source (Optional - .ico, .exe, .dll)" FontSize="12" FontWeight="SemiBold" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" Margin="0,0,0,5"/>
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBox x:Name="TxtIcon" Grid.Column="0" Style="{StaticResource ModernTextBox}" Margin="0,0,8,0"/>
                            <Button x:Name="BtnVisualIconPicker" Grid.Column="1" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0" ToolTip="Browse embedded icons visually from .dll, .exe, or .ico files">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE8A9;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" Foreground="{Binding AccentBrush, Source={StaticResource Theme}}" VerticalAlignment="Center" Margin="0,0,6,0"/>
                                    <TextBlock Text="Pick Icon Grid..." FontWeight="SemiBold" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnBrowseIcon" Grid.Column="2" Content="Browse File..." Style="{StaticResource SecondaryButton}"/>
                        </Grid>
                    </StackPanel>

                    <!-- Checkboxes & Create CTA -->
                    <Grid Grid.Row="6">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" VerticalAlignment="Center">
                            <CheckBox x:Name="ChkCustomRunAdmin" Content="Run shortcut as Administrator (UAC prompt on launch)" Style="{StaticResource ModernCheckBox}" Margin="0,0,0,8"/>
                            <CheckBox x:Name="ChkCustomAllUsers" Content="Place shortcut on Public Desktop (All Users)" Style="{StaticResource ModernCheckBox}"/>
                        </StackPanel>
                        <Button x:Name="BtnCreateCustomShortcut" Grid.Column="1" Style="{StaticResource PrimaryButton}" VerticalAlignment="Bottom">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="&#xE710;" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="13" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                <TextBlock Text="Create Desktop Shortcut" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Grid>
            </Border>
        </Grid>

        <!-- STATUS FOOTER -->
        <Border Grid.Row="3"
                Background="{Binding SurfaceBrush, Source={StaticResource Theme}}"
                BorderBrush="{Binding BorderBrush, Source={StaticResource Theme}}"
                BorderThickness="0,1,0,0"
                Padding="22,9">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <Ellipse x:Name="StatusDot" Grid.Column="0" Width="8" Height="8" Fill="#38BDF8" VerticalAlignment="Center" Margin="0,0,9,0"/>
                <TextBlock x:Name="TxtStatus" Grid.Column="1" Text="Ready." FontSize="12" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
                <TextBlock x:Name="TxtHostBadge" Grid.Column="2" FontSize="11.5" Foreground="{Binding MutedBrush, Source={StaticResource Theme}}" VerticalAlignment="Center" Margin="12,0,0,0"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# ---------------------------------------------------------------------------
# Load XAML & Bind Controls
# ---------------------------------------------------------------------------

[xml]$xmlDoc = $xamlString
$nodeReader = New-Object System.Xml.XmlNodeReader($xmlDoc)
$window = [System.Windows.Markup.XamlReader]::Load($nodeReader)
$themeMgr = $window.Resources['Theme']

$txtSubtitle          = $window.FindName('TxtSubtitle')
$txtElevation         = $window.FindName('TxtElevation')
$btnElevate           = $window.FindName('BtnElevate')

$rbThemeAuto          = $window.FindName('RbThemeAuto')
$rbThemeDark          = $window.FindName('RbThemeDark')
$rbThemeLight         = $window.FindName('RbThemeLight')

$rbTabStore           = $window.FindName('RbTabStore')
$rbTabCustom          = $window.FindName('RbTabCustom')
$btnOpenDesktop       = $window.FindName('BtnOpenDesktop')
$btnOpenAppsFolder    = $window.FindName('BtnOpenAppsFolder')

$viewStoreApps        = $window.FindName('ViewStoreApps')
$viewCustom           = $window.FindName('ViewCustom')

$txtSearch            = $window.FindName('TxtSearch')
$txtSearchPlaceholder = $window.FindName('TxtSearchPlaceholder')
$btnClearSearch       = $window.FindName('BtnClearSearch')
$rbScopeStoreOnly     = $window.FindName('RbScopeStoreOnly')
$rbScopeAllApps       = $window.FindName('RbScopeAllApps')
$btnRefreshApps       = $window.FindName('BtnRefreshApps')
$lstApps              = $window.FindName('LstApps')
$txtAppShortcutName   = $window.FindName('TxtAppShortcutName')
$chkAppAllUsers       = $window.FindName('ChkAppAllUsers')
$btnCreateAppShortcut = $window.FindName('BtnCreateAppShortcut')

$txtTarget            = $window.FindName('TxtTarget')
$btnBrowseFile        = $window.FindName('BtnBrowseFile')
$btnBrowseFolder      = $window.FindName('BtnBrowseFolder')
$txtCustomName        = $window.FindName('TxtCustomName')
$cmbWinStyle          = $window.FindName('CmbWinStyle')
$txtArgs              = $window.FindName('TxtArgs')
$txtWorkDir           = $window.FindName('TxtWorkDir')
$txtIcon              = $window.FindName('TxtIcon')
$btnVisualIconPicker  = $window.FindName('BtnVisualIconPicker')
$btnBrowseIcon        = $window.FindName('BtnBrowseIcon')
$chkCustomRunAdmin    = $window.FindName('ChkCustomRunAdmin')
$chkCustomAllUsers    = $window.FindName('ChkCustomAllUsers')
$btnCreateCustom      = $window.FindName('BtnCreateCustomShortcut')

$statusDot            = $window.FindName('StatusDot')
$txtStatus            = $window.FindName('TxtStatus')
$txtHostBadge         = $window.FindName('TxtHostBadge')

# ---------------------------------------------------------------------------
# State & UI Logic
# ---------------------------------------------------------------------------

$script:CurrentThemeMode = $Theme
$script:IsElevated = Test-IsElevated
$script:AllApps = Get-InstalledAppsInventory

$psVer = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
$editionLabel = $PSVersionTable.PSEdition
$txtHostBadge.Text = "PowerShell $psVer ($editionLabel)"

function Apply-ActiveTheme {
    $useDark = Resolve-UseDarkMode -Mode $script:CurrentThemeMode
    $themeMgr.Configure($useDark, $script:IsElevated)
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    if ($hwnd -ne [IntPtr]::Zero) {
        [ShortcutStudio.NativeMethods]::ApplyWindowChromeAttributes($hwnd, $useDark)
    }
}

function Set-Status {
    param(
        [string]$Message,
        [ValidateSet('Info', 'Success', 'Error')][string]$Level = 'Info'
    )
    $txtStatus.Text = $Message
    $hex = switch ($Level) {
        'Success' { '#22C55E' }
        'Error'   { '#EF4444' }
        default   { '#38BDF8' }
    }
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $brush = New-Object System.Windows.Media.SolidColorBrush($color)
    $brush.Freeze()
    $statusDot.Fill = $brush
}

function Update-FilteredAppList {
    $query = $txtSearch.Text.Trim()
    $storeOnly = [bool]$rbScopeStoreOnly.IsChecked

    $txtSearchPlaceholder.Visibility = if ($query -eq '') { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }
    $btnClearSearch.Visibility = if ($query -ne '') { [System.Windows.Visibility]::Visible } else { [System.Windows.Visibility]::Collapsed }

    $filtered = @(foreach ($app in $script:AllApps) {
        if ($storeOnly -and (-not $app.IsStoreApp)) { continue }
        if ($query -ne '' -and ($app.Name -notlike "*$query*") -and ($app.Subtitle -notlike "*$query*")) { continue }
        $app
    })

    $lstApps.ItemsSource = $filtered
    $count = $filtered.Count
    $label = if ($storeOnly) { 'Microsoft Store apps' } else { 'total installed apps' }
    $txtSubtitle.Text = "Showing $count $label  -  Drag & drop any file or folder onto window"
}

function Invoke-RelaunchElevated {
    $hostExe = Get-CurrentPowerShellHostPath
    $scriptPath = $PSCommandPath
    if (-not $scriptPath) {
        Set-Status -Message 'Save this script as a .ps1 file first so it can relaunch elevated.' -Level 'Error'
        return
    }
    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$scriptPath`" -Theme $($script:CurrentThemeMode) -HideConsole"
        Start-Process -FilePath $hostExe -Verb RunAs -WindowStyle Hidden -ArgumentList $argList
        $window.Close()
    }
    catch {
        Set-Status -Message "Elevation canceled: $($_.Exception.Message)" -Level 'Error'
    }
}

function Confirm-AdminForPublicDesktop {
    if ($script:IsElevated) { return $true }
    $res = [System.Windows.MessageBox]::Show(
        "Creating shortcuts on the Public Desktop (All Users) requires Administrator privileges.`n`nRestart Shortcut Studio as Administrator now?",
        'Elevation Required',
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($res -eq [System.Windows.MessageBoxResult]::Yes) {
        Invoke-RelaunchElevated
    }
    return $false
}

# ---------------------------------------------------------------------------
# Event Wiring
# ---------------------------------------------------------------------------

if ($script:IsElevated) {
    $txtElevation.Text = 'Administrator'
    $btnElevate.Visibility = [System.Windows.Visibility]::Collapsed
}
else {
    $txtElevation.Text = 'Standard User'
    $btnElevate.Visibility = [System.Windows.Visibility]::Visible
}

Apply-ActiveTheme

$window.Add_SourceInitialized({
    Apply-ActiveTheme
    if ($HideConsole) {
        [ShortcutStudio.NativeMethods]::HideConsoleWindow()
    }
})

$prefHandler = [Microsoft.Win32.UserPreferenceChangedEventHandler]{
    param($sender, $e)
    if ($script:CurrentThemeMode -eq 'Auto') {
        $window.Dispatcher.Invoke([Action]{
            Apply-ActiveTheme
        })
    }
}
[Microsoft.Win32.SystemEvents]::add_UserPreferenceChanged($prefHandler)
$window.Add_Closed({
    [Microsoft.Win32.SystemEvents]::remove_UserPreferenceChanged($prefHandler)
})

switch ($Theme) {
    'Dark'  { $rbThemeDark.IsChecked = $true }
    'Light' { $rbThemeLight.IsChecked = $true }
    default { $rbThemeAuto.IsChecked = $true }
}

$rbThemeAuto.Add_Checked({
    $script:CurrentThemeMode = 'Auto'
    Apply-ActiveTheme
})
$rbThemeDark.Add_Checked({
    $script:CurrentThemeMode = 'Dark'
    Apply-ActiveTheme
})
$rbThemeLight.Add_Checked({
    $script:CurrentThemeMode = 'Light'
    Apply-ActiveTheme
})

$btnElevate.Add_Click({ Invoke-RelaunchElevated })

$rbTabStore.Add_Checked({
    $viewStoreApps.Visibility = [System.Windows.Visibility]::Visible
    $viewCustom.Visibility = [System.Windows.Visibility]::Collapsed
})
$rbTabCustom.Add_Checked({
    $viewStoreApps.Visibility = [System.Windows.Visibility]::Collapsed
    $viewCustom.Visibility = [System.Windows.Visibility]::Visible
})

$btnOpenAppsFolder.Add_Click({
    Start-Process 'explorer.exe' -ArgumentList 'shell:AppsFolder'
    Set-Status -Message 'Opened shell:AppsFolder in File Explorer.' -Level 'Info'
})

$btnOpenDesktop.Add_Click({
    Start-Process 'explorer.exe' -ArgumentList ([Environment]::GetFolderPath('DesktopDirectory'))
})

$txtSearch.Add_TextChanged({ Update-FilteredAppList })
$rbScopeStoreOnly.Add_Checked({ Update-FilteredAppList })
$rbScopeAllApps.Add_Checked({ Update-FilteredAppList })

$btnClearSearch.Add_Click({
    $txtSearch.Text = ''
    $txtSearch.Focus()
})

$btnRefreshApps.Add_Click({
    Set-Status -Message 'Rescanning Microsoft Store & installed apps...' -Level 'Info'
    $script:AllApps = Get-InstalledAppsInventory
    Update-FilteredAppList
    Set-Status -Message 'App inventory refreshed.' -Level 'Success'
})

$lstApps.Add_SelectionChanged({
    $sel = $lstApps.SelectedItem
    if ($sel) {
        $txtAppShortcutName.Text = $sel.Name
    }
})

$btnCreateAppShortcut.Add_Click({
    $app = $lstApps.SelectedItem
    if (-not $app) {
        Set-Status -Message 'Select an application from the list first.' -Level 'Error'
        return
    }
    if ($chkAppAllUsers.IsChecked -and -not (Confirm-AdminForPublicDesktop)) {
        return
    }

    $scName = if ([string]::IsNullOrWhiteSpace($txtAppShortcutName.Text)) { $app.Name } else { $txtAppShortcutName.Text }
    $safeName = Get-SanitizedFileName -Name $scName

    try {
        if ($app.IsStoreApp) {
            $iconLoc = "$env:WINDIR\System32\imageres.dll,11"
            $hiResBmp = [ShortcutStudio.NativeMethods]::ExtractShellItemBitmapSource($app.ParsingName, 128)
            if (-not $hiResBmp) {
                $hiResBmp = $app.IconImage
            }
            if ($hiResBmp) {
                $iconCacheDir = Join-Path (Join-Path $env:LOCALAPPDATA 'ShortcutStudio') 'Icons'
                if (-not (Test-Path -LiteralPath $iconCacheDir)) {
                    New-Item -ItemType Directory -Path $iconCacheDir -Force | Out-Null
                }
                $icoOut = Join-Path $iconCacheDir "$safeName.ico"
                if ([ShortcutStudio.NativeMethods]::SaveBitmapSourceAsIco($hiResBmp, $icoOut)) {
                    $iconLoc = "$icoOut,0"
                }
            }

            $created = New-DesktopShortcut `
                -ShortcutName $scName `
                -TargetPath "$env:WINDIR\explorer.exe" `
                -Arguments "shell:AppsFolder\$($app.Path)" `
                -IconLocation $iconLoc `
                -AllUsersDesktop ([bool]$chkAppAllUsers.IsChecked)
        }
        else {
            $iconLoc = ''
            if ($app.Path -match '^[a-zA-Z]:\\' -and (Test-Path -LiteralPath $app.Path -PathType Leaf)) {
                $iconLoc = "$($app.Path),0"
            }
            elseif ($app.IconImage) {
                $iconCacheDir = Join-Path (Join-Path $env:LOCALAPPDATA 'ShortcutStudio') 'Icons'
                if (-not (Test-Path -LiteralPath $iconCacheDir)) {
                    New-Item -ItemType Directory -Path $iconCacheDir -Force | Out-Null
                }
                $icoOut = Join-Path $iconCacheDir "$safeName.ico"
                if ([ShortcutStudio.NativeMethods]::SaveBitmapSourceAsIco($app.IconImage, $icoOut)) {
                    $iconLoc = "$icoOut,0"
                }
            }

            $targetExec = if ($app.Path -match '^[a-zA-Z]:\\') { $app.Path } else { "$env:WINDIR\explorer.exe" }
            $targetArgs = if ($app.Path -match '^[a-zA-Z]:\\') { '' } else { "shell:AppsFolder\$($app.Path)" }

            $created = New-DesktopShortcut `
                -ShortcutName $scName `
                -TargetPath $targetExec `
                -Arguments $targetArgs `
                -IconLocation $iconLoc `
                -AllUsersDesktop ([bool]$chkAppAllUsers.IsChecked)
        }

        Set-Status -Message "Created shortcut: $created" -Level 'Success'
    }
    catch {
        Set-Status -Message "Error: $($_.Exception.Message)" -Level 'Error'
    }
})

$btnBrowseFile.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title = 'Select Target Executable or File'
    $dlg.Filter = 'Programs & Scripts (*.exe;*.bat;*.cmd;*.ps1;*.msc)|*.exe;*.bat;*.cmd;*.ps1;*.msc|All Files (*.*)|*.*'
    if ($dlg.ShowDialog()) {
        $txtTarget.Text = $dlg.FileName
        if ([string]::IsNullOrWhiteSpace($txtCustomName.Text)) {
            $txtCustomName.Text = [System.IO.Path]::GetFileNameWithoutExtension($dlg.FileName)
        }
    }
})

$btnBrowseFolder.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select Target Folder'
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtTarget.Text = $dlg.SelectedPath
        if ([string]::IsNullOrWhiteSpace($txtCustomName.Text)) {
            $txtCustomName.Text = Split-Path -Path $dlg.SelectedPath -Leaf
        }
    }
    $dlg.Dispose()
})

$btnVisualIconPicker.Add_Click({
    $initialSpec = $txtIcon.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($initialSpec) -and -not [string]::IsNullOrWhiteSpace($txtTarget.Text)) {
        $initialSpec = $txtTarget.Text.Trim()
    }
    $useDark = Resolve-UseDarkMode -Mode $script:CurrentThemeMode
    $picked = Show-IconPickerDialog -OwnerWindow $window -ThemeManager $themeMgr -UseDarkMode $useDark -InitialIconSpec $initialSpec
    if ($picked) {
        $txtIcon.Text = $picked
        Set-Status -Message "Selected icon: $picked" -Level 'Info'
    }
})

$btnBrowseIcon.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Title = 'Select Icon File'
    $dlg.Filter = 'Icon Sources (*.ico;*.exe;*.dll)|*.ico;*.exe;*.dll|All Files (*.*)|*.*'
    if ($dlg.ShowDialog()) {
        $txtIcon.Text = "$($dlg.FileName),0"
    }
})

$btnCreateCustom.Add_Click({
    $target = $txtTarget.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($target)) {
        Set-Status -Message 'Enter or browse for a target file, folder, or URL first.' -Level 'Error'
        return
    }
    if ($chkCustomAllUsers.IsChecked -and -not (Confirm-AdminForPublicDesktop)) {
        return
    }

    $scName = $txtCustomName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($scName)) {
        if ($target -match '^(https?|ftp)://([^/]+)') {
            $scName = $Matches[2]
        }
        else {
            $scName = [System.IO.Path]::GetFileNameWithoutExtension($target)
        }
    }

    $winStyle = switch ($cmbWinStyle.SelectedIndex) {
        1 { 7 } # Minimized
        2 { 3 } # Maximized
        default { 1 } # Normal
    }

    try {
        $created = New-DesktopShortcut `
            -ShortcutName $scName `
            -TargetPath $target `
            -Arguments $txtArgs.Text.Trim() `
            -WorkingDirectory $txtWorkDir.Text.Trim() `
            -IconLocation $txtIcon.Text.Trim() `
            -WindowStyle $winStyle `
            -RunAsAdmin ([bool]$chkCustomRunAdmin.IsChecked) `
            -AllUsersDesktop ([bool]$chkCustomAllUsers.IsChecked)

        Set-Status -Message "Created shortcut: $created" -Level 'Success'
    }
    catch {
        Set-Status -Message "Error: $($_.Exception.Message)" -Level 'Error'
    }
})

# Drag-and-Drop Support Anywhere on the Window
$window.Add_DragOver({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $e.Effects = [System.Windows.DragDropEffects]::Copy
    }
    else {
        $e.Effects = [System.Windows.DragDropEffects]::None
    }
    $e.Handled = $true
})

$window.Add_Drop({
    param($sender, $e)
    if ($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)) {
        $files = $e.Data.GetData([System.Windows.DataFormats]::FileDrop)
        if ($files -and $files.Count -gt 0) {
            $dropped = $files[0]
            $rbTabCustom.IsChecked = $true
            $txtTarget.Text = $dropped
            $nameGuess = [System.IO.Path]::GetFileNameWithoutExtension($dropped)
            if ([string]::IsNullOrWhiteSpace($nameGuess)) {
                $nameGuess = Split-Path -Path $dropped -Leaf
            }
            $txtCustomName.Text = $nameGuess
            Set-Status -Message "Loaded dropped item: $dropped" -Level 'Info'
        }
    }
})

Update-FilteredAppList
$storeCount = @($script:AllApps | Where-Object { $_.IsStoreApp }).Count
Set-Status -Message "Loaded $storeCount Microsoft Store apps." -Level 'Success'

[void]$window.ShowDialog()

