<h1 align="center">🎮 SteamShell 🌙</h1>

<p align="center">
  <strong>Effortless Steam Management & Asset Importing</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-0.6.2-blue?style=for-the-badge&logo=powerpc&logoColor=white" alt="Version">
  <img src="https://img.shields.io/badge/Platform-Windows-0078D6?style=for-the-badge&logo=windows&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Language-PowerShell-5391FE?style=for-the-badge&logo=powershell&logoColor=white" alt="Language">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
</p>

---

### 🚀 Overview

**SteamShell** is a sleek, graphical utility built for power users. It simplifies the process of managing the Steam client lifecycle and automating the deployment of `.manifest` and `.lua` files into Steam's internal directories. No more manual path-hunting.

### ✨ Key Features

- ⚡ **Zero-Click Detection**: Automatically finds your Steam path using Registry keys.
- 🛠️ **Client Control**: Start, Stop, Restart, and **Kill All** Steam processes directly.
- 📡 **Status Monitor**: Real-time monitoring of Steam client presence.
- 📦 **Smart Injector**:
  - Automatically copies **.manifest** files to `depotcache`.
  - Automatically copies **.lua** scripts to `stplug-in` (under `config`).
  - **Optional Backups**: Create `.bak` files before overwriting.
- 🕒 **Graceful Shutdown**: Tailor the shutdown behavior with custom wait times.
- 🖥️ **Modern UI**: Dark-themed, responsive WinForms GUI.

---

### 🔥 Usage Guide

#### 💠 Option 1: The Modern GUI (Recommended)
Launch the full interface to manage your Steam environment visually.
1. Right-click `SteamShell-GUI.ps1`.
2. Select **Run with PowerShell**.

#### 💠 Option 2: Command Line (Fast)
Perfect for automation or quick restarts via Terminal.
```powershell
# Quick restart
.\SteamShell.ps1 -Action "Restart"

# Stop Steam gracefully
.\SteamShell.ps1 -Action "Stop"
```

---

### 📦 Installation & Setup

1. **Clone the repo**:
   ```bash
   git clone https://github.com/kozaaaaczx/steam-lua.git
   ```
2. **Execution Policy**:
   If you can't run the script, open PowerShell as Admin and run:
   ```powershell
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

---

### 📂 Project Structure

| File | Purpose |
| :--- | :--- |
| 🖥️ `SteamShell-GUI.ps1` | The main graphical application. |
| 📜 `SteamShell.ps1` | Core logic for Steam client handling. |
| 📂 `assets/` | High-quality visual assets and UI components. |
| 📝 `CHANGELOG.md` | Detailed history of updates and fixes. |

---

<p align="center">
  Made with ❤️ by <b>kozaaaaczx</b>
</p>
