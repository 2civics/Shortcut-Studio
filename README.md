# Shortcut Studio

[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Shortcut-Studio?label=PowerShell%20Gallery&logo=powershell)](https://www.powershellgallery.com/packages/Shortcut-Studio/)
[![PowerShell 5.1 & 7.x](https://img.shields.io/badge/PowerShell-5.1%20%7C%207.x-blue?logo=powershell)](https://github.com/2civics/Shortcut-Studio)
[![Platform](https://img.shields.io/badge/Platform-Windows%2011-0078D4?logo=windows)](https://github.com/2civics/Shortcut-Studio)

A lightweight, zero-dependency **Windows 11 Fluent Desktop Shortcut Creator** built in PowerShell and WPF. Shortcut Studio makes it fast and effortless to create Desktop shortcuts for **Microsoft Store (UWP/MSIX) apps**, **Win32 executables**, **scripts**, **folders**, and **web URLs**—with real icon extraction, a visual `.dll`/`.exe` icon grid browser, live Auto/Dark/Light theming, and host-matched UAC elevation.

---

## Why Shortcut Studio Was Made

In Windows 11, putting a shortcut for a **Microsoft Store app** onto your Desktop is notoriously tedious:

1. **No Direct Executable Path:** Store (UWP/MSIX) apps are sandboxed inside protected `WindowsApps` directories and cannot be launched by simply pointing a shortcut to an `.exe`.
2. **Missing Start Menu Options:** Right-clicking a Store app in the Windows 11 Start Menu offers **Pin to Start** or **Pin to taskbar**, with no built-in **Send to Desktop** option.
3. **Hidden Shell Workarounds:** The manual workaround requires opening `Win + R`, typing `shell:AppsFolder`, hunting through an unsearchable folder of mixed system and desktop entries, and dragging items out—often resulting in generic icons or mismatched shortcut names.

**Shortcut Studio** eliminates that friction. It reads `shell:AppsFolder` directly, filters down to your installed Microsoft Store apps with instant search, extracts each app's real high-resolution icon via the Windows Shell (`IShellItemImageFactory`), and creates a clean, properly named `.lnk` shortcut on your Desktop in one click.

> [!IMPORTANT]
> **Windows App Limitations:** Not all Windows Store or built-in Windows apps allow you to add them to the Desktop or launch them via a standalone shortcut. Certain protected system components, background host packages, and OS-restricted UWP experiences exposed in `shell:AppsFolder` are blocked by Windows at the AppModel level and either cannot be shortcutted or will not launch independently outside their parent Windows feature.

---

## Key Features

- **One-Click Microsoft Store App Shortcuts:** Automatically lists installed Store/UWP/MSIX apps with live search, a **Store Only / All Apps** toggle, and a quick-launch **Open shell:AppsFolder** button.
- **Automatic High-Resolution Icon Extraction:** Extracts native transparent app icons through `IShellItemImageFactory` and caches crisp `.ico` files in `%LOCALAPPDATA%\ShortcutStudio\Icons` so your Desktop shortcuts never end up with generic blank icons.
- **Full Custom Shortcut Builder:** Create `.lnk` and `.url` shortcuts for any program, script, folder, or web address with drag-and-drop support, command-line arguments, working directory (`Start In`), window style (`Normal`, `Minimized`, `Maximized`), Public Desktop placement, and native **Run as administrator** flagging.
- **Visual `.dll` / `.exe` / `.ico` Icon Grid Picker:** Browse and filter embedded icon resources visually with one-click presets for `imageres.dll`, `shell32.dll`, `ddores.dll`, and `pifmgr.dll`, or inspect any custom `.exe`/`.dll`/`.ico`.
- **Native Windows 11 Fluent UI:** Hardware-accelerated WPF interface with **Auto** (live Windows theme sync), **Dark**, and **Light** modes, native DWM dark title bars, and rounded window corners.
- **Dual PowerShell Support & Host-Matched Elevation:** Runs identically on **Windows PowerShell 5.1** and **PowerShell 7.x** with zero external modules. Clicking **Run as Admin** relaunches Shortcut Studio elevated in your exact active PowerShell host (`powershell.exe` or `pwsh.exe`) with the console window hidden.

---

## Installation

### Prerequisites
- **OS:** Windows 11 (also compatible with Windows 10 20H1 or newer)
- **PowerShell:** Windows PowerShell **5.1** or PowerShell **7.x**
- **Dependencies:** None (uses built-in .NET WPF and Win32/Shell APIs)

### Option 1: Install from the PowerShell Gallery (Recommended)

Install directly from the [PowerShell Gallery](https://www.powershellgallery.com/packages/Shortcut-Studio/):

```powershell
# Install for your user account (no admin required)
Install-Script -Name Shortcut-Studio -Scope CurrentUser

# Or install system-wide for all users (requires Administrator)
Install-Script -Name Shortcut-Studio -Scope AllUsers
```

Once installed, launch it from PowerShell 5.1 or PowerShell 7.x:

```powershell
Shortcut-Studio.ps1
```

### Option 2: Download or Clone from GitHub

1. Clone the repository or download `Shortcut-Studio.ps1` from [GitHub](https://github.com/2civics/Shortcut-Studio):
   ```powershell
   git clone [https://github.com/2civics/Shortcut-Studio.git](https://github.com/2civics/Shortcut-Studio.git)
   cd Shortcut-Studio
   ```
2. If you downloaded the `.ps1` file manually in a browser, unblock it first:
   ```powershell
   Unblock-File -Path .\Shortcut-Studio.ps1
   ```
3. Run the script in either PowerShell 5.1 or PowerShell 7.x:
   ```powershell
   # PowerShell 7.x
   pwsh.exe -ExecutionPolicy Bypass -File .\Shortcut-Studio.ps1

   # Windows PowerShell 5.1
   powershell.exe -ExecutionPolicy Bypass -File .\Shortcut-Studio.ps1
   ```

---

## Creating a Desktop Shortcut for Shortcut Studio (and Other `.ps1` Scripts)

Because `.ps1` files open in Notepad or a terminal window by default when double-clicked, you can create a clean Desktop shortcut using either the recommended GUI tool or a direct PowerShell command.

### Option A: PowerShell Desktop Shortcut Creator (Recommended)

The easiest way to create a Desktop shortcut for **Shortcut Studio**—or any other PowerShell script—is **[PowerShell Desktop Shortcut Creator](https://github.com/2civics/PowerShell-Desktop-Shortcut-Creator)**:

1. Download or run **[PowerShell Desktop Shortcut Creator](https://github.com/2civics/PowerShell-Desktop-Shortcut-Creator)**.
2. Select your installed `Shortcut-Studio.ps1` file as the target script.
3. Choose your preferred PowerShell engine (**PowerShell 5.1** or **PowerShell 7.x**) and icon.
4. **Important:** Choose the **"Hidden"** window option when creating the shortcut. Selecting **Hidden** prevents an empty PowerShell console window from popping up and lingering in the background while Shortcut Studio's GUI is open.

### Option B: Create the Shortcut via PowerShell Command

If you prefer not to use PowerShell Desktop Shortcut Creator, run one of the snippets below in PowerShell to generate the `.lnk` file directly via `WScript.Shell` with the console window hidden.

#### PowerShell 7.x (`pwsh.exe`)

```powershell
$ScriptPath = (Get-Command 'Shortcut-Studio.ps1' -ErrorAction SilentlyContinue).Source
if (-not $ScriptPath) { $ScriptPath = "$HOME\Documents\PowerShell\Scripts\Shortcut-Studio.ps1" }

$ShortcutPath = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Shortcut Studio.lnk'

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath       = 'pwsh.exe'$Shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -HideConsole"
$Shortcut.WorkingDirectory = Split-Path -Path$ScriptPath -Parent
$Shortcut.IconLocation     = "$env:WINDIR\System32\imageres.dll,11"
$Shortcut.WindowStyle      = 7  # Minimized (prevents console flash before -WindowStyle Hidden applies)
$Shortcut.Description      = 'Shortcut Studio - Windows 11 Desktop Shortcut Creator'$Shortcut.Save()
```

#### Windows PowerShell 5.1 (`powershell.exe`)

```powershell
$ScriptPath = (Get-Command 'Shortcut-Studio.ps1' -ErrorAction SilentlyContinue).Source
if (-not $ScriptPath) { $ScriptPath = "$HOME\Documents\WindowsPowerShell\Scripts\Shortcut-Studio.ps1" }

$ShortcutPath = Join-Path ([Environment]::GetFolderPath('DesktopDirectory')) 'Shortcut Studio.lnk'

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath       = 'powershell.exe'$Shortcut.Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -HideConsole"
$Shortcut.WorkingDirectory = Split-Path -Path$ScriptPath -Parent
$Shortcut.IconLocation     = "$env:WINDIR\System32\imageres.dll,11"
$Shortcut.WindowStyle      = 7  # Minimized (prevents console flash before -WindowStyle Hidden applies)
$Shortcut.Description      = 'Shortcut Studio - Windows 11 Desktop Shortcut Creator'$Shortcut.Save()
```

> **Tip for Other `.ps1` Scripts:** To adapt either command above for any other PowerShell script, replace `$ScriptPath` and `$ShortcutPath` with your script's path and desired shortcut name, and remove `-HideConsole` from `$Shortcut.Arguments`.

---

## How to Create Desktop Shortcuts

### 1. Microsoft Store & Installed Apps

1. Launch **Shortcut Studio** (it opens to the **Microsoft Store Apps** tab by default).
2. Type in the **Search** box to filter your installed Store apps, or switch the scope toggle between **Store Only** and **All Apps** to include traditional Win32 applications.
3. Click an application in the list—its display name automatically populates the **Desktop Shortcut Name** field.
4. *(Optional)* Edit the shortcut name or check **Public Desktop (All Users)** (will prompt to elevate via **Run as Admin** if not already elevated).
5. Click **Create Desktop Shortcut**. Shortcut Studio extracts the app's icon and writes the `.lnk` file directly to your Desktop.

> **Tip:** You can also click **Open shell:AppsFolder** in the top-right bar at any time to open Windows Explorer's native virtual applications folder directly.

### 2. Custom Files, Folders, Scripts, or URLs

1. Switch to the **Custom File, Folder, or URL** tab—or **drag and drop** any file or folder anywhere onto the Shortcut Studio window.
2. Enter a web URL (e.g., `https://github.com/2civics/Shortcut-Studio`), or use **Browse File...** / **Browse Folder...** to pick a target.
3. Configure optional fields as needed:
   - **Desktop Shortcut Name:** Custom label for the Desktop icon.
   - **Window Style:** `Normal Window`, `Minimized`, or `Maximized`.
   - **Command-Line Arguments:** Parameters passed to the executable on launch.
   - **Start In / Working Directory:** Working folder path for the target process.
4. *(Optional)* Click **Pick Icon Grid...** to visually browse and select an icon from `imageres.dll`, `shell32.dll`, `ddores.dll`, `pifmgr.dll`, or any `.exe`/`.dll`/`.ico` file.
5. *(Optional)* Check **Run shortcut as Administrator** to embed the native Windows UAC elevation flag into the `.lnk` file, or **Place shortcut on Public Desktop (All Users)**.
6. Click **Create Desktop Shortcut**.

---

## Command-Line Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `-Theme` | `String` | `Auto` | Sets the initial UI theme (`Auto`, `Dark`, or `Light`). `Auto` syncs live with your Windows 11 personalization setting. |
| `-HideConsole` | `Switch` | `$false` | Hides the attached PowerShell console window on startup via Win32 `ShowWindow`. |

Example:
```powershell
.\Shortcut-Studio.ps1 -Theme Dark -HideConsole
```

---

## Links

- **PowerShell Gallery:** https://www.powershellgallery.com/packages/Shortcut-Studio/
- **GitHub Repository:** https://github.com/2civics/Shortcut-Studio
- **Recommended Script Shortcut Tool:** https://github.com/2civics/PowerShell-Desktop-Shortcut-Creator