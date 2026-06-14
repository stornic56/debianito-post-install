# Debianito - Post-Installation Automation for Debian

<div align="center">

Debianito is a user-friendly post-installation automation script for Debian 11 (Bullseye), Debian 12 (Bookworm) and Debian 13 (Trixie). It streamlines system configuration, driver installation (including NVIDIA drivers with legacy support via rescue environment), repository setup with backports support, gaming tools integration, and more with an interactive menu-driven interface.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-red.svg?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/stornic56/debianito-post-install/blob/main/LICENSE)

</div>

---

## System Requirements

| Requirement | Specification |
|-------------|---------------|
| **OS**      | Debian 11 (Bullseye), Debian 12 (Bookworm), Debian 13 (Trixie) |
| **Privileges** | Normal user with `sudo` access, script validates root/sudo in utils.sh |
| **Terminal**   | Any modern terminal emulator supporting ANSI colors and UTF-8 box-drawing characters |
| **Dependencies**     | Standard Debian packages (`whiptail`, `lsb-release`); auto-installed if missing |

---

## Installation Instructions

Clone the repository, make the script executable, and run it:

```bash
git clone https://github.com/stornic56/debianito-post-install
cd debianito-post-install
chmod +x debianito.sh && ./debianito.sh
```

> ⚠️ **Do not run as root.** The script checks for non-root execution and requires sudo privileges.

---

## Usage 

After running the script:

1. **Select Option:** Use arrow keys or type 1-10.
2. **Navigation:** Use Arrow Keys (Up↑/Down↓) to move between list options and ENTER key to confirm selection.
3. **Confirm Actions:** Installation prompts use whiptail for TUI confirmations.
4. **Review System Info:** Header displays detected Debian version and hardware summary before each action.
5. **Repeat as Needed:** Return to main menu at any time or exit when done.

| Option | Description | What it does |
|--------|-------------|--------------|
| **1** | System Info | Show detected OS, CPU, RAM, GPU and hardware details |
| **2** | [User Privileges & Feedback](#user-privileges--feedback) | Configure sudo group membership, enable passwordless sudo for frequent tasks, repair home directory ownership issues, and toggle visual password feedback (asterisks) in terminal |
| **3** | Configure Repositories | Setup official repos with/without backports (deb822 or classic format)|
| **4** | Setup Wireless & Firmware | Install WiFi firmware for Broadcom, Intel, and other chipsets|
| **5** | Configure Graphics Stack | AMD/Intel/NVIDIA drivers + monitoring tools |
| **6** | Update Kernel to Backports | Install latest stable kernel from Debian backports|
| **7** | Gaming Setup and Performance | Steam, Heroic Games Launcher, GameMode, MangoHud, Java JRE (Temurin 8/17/21) |
| **8** | Install ZRAM (compressed swap) | Configure compressed RAM for memory optimization|
| **9** | Install Programs and Software | Selection across 10 categories (Dev, Themes, System, etc.) |
| **10** | Exit | Return to terminal |

### Extra Applications Categories (Option 9)

The submenu offers the next categories:

| Option | Category Title | Description |
|--------|-------------------------------|-------------|
| **0** | Essential Pack | Quick install of common tools (compression, system info, VLC, MS fonts)|
| **1** | Customization System | Desktop themes, icon themes, cursor themes, and fonts |
| **2** | Download & Network | Downloaders (aria2, ytdlp, FileZilla) + Torrent clients (qBittorrent, Deluge, Transmission) |
| **3** | Internet (Browsers, Email Clients, VPN Tools) | Web browsers (Firefox/Mozilla, LibreWolf, Floorp, Chromium, Brave, Tor), email clients (Thunderbird), and VPN tools including Riseup |
| **4** | Media Players | Multimedia playback with VLC media player and MPV for advanced video/audio support |
| **5** | Multimedia & Design | image editing (GIMP), video editing (Kdenlive, HandBrake), 3D modeling (Blender), audio recording (Audacity), and graphics design (Inkscape) |
| **6** | Code Editors & IDEs | vim, vim-gtk3, Neovim, Helix, nano, Emacs, Kate, Mousepad, Gedit, Geany, GNOME Text Editor, and VSCodium (VS Code open-source) |
| **7** | Servers & Dev Tools | Web servers (Nginx/Apache), databases (PostgreSQL/MariaDB), Java Development Kit (Temurin 17/21/25 JDK), Docker, Python, SSH tools, fail2ban, and essential utilities |
| **8** | Security & Networking | Wireshark, tcpdump, Zenmap, ClamAV, UFW, Fail2ban |
| **9** | System Tools | htop/btop, ncdu, Timeshift, tmux/screen, Flatpak support, extension repository manager, and qemu/virtmanager |
| **10** | Fetch / System Info | fastfetch/neofetch, hyfetch, Linux logo and screenfetch |
| **11** | Back to Main Menu | Return directly to the main Debianito menu (exit submenu) |

---

## User Privileges & Feedback

Admin rights, passwordless commands, and file ownership fixes—optimized for Debian users.

### 1. Sudo Group Membership
If you just installed Debian and can’t install software or change system settings (you get "Permission denied"), this option adds your user to the sudo group. This gives you admin privileges so you can manage your system. Changes take effect after you log out and back in.

### 2. Passwordless Sudo for Frequent Tasks
Every time you run sudo apt install or sudo reboot, Linux asks for your password. This option lets you skip typing your password for common commands like installing/updating software (apt), restarting or shutting down (systemctl).
- ⚠️ Security Note: While convenient, this reduces security if someone else uses your PC physically.

### 3. Repair Home Directory Ownership
Sometimes, when you use sudo incorrectly (e.g., installing games or apps), files get "stolen" by the system (root) instead of your user. This causes apps to fail (e.g., saving settings or game progress). This option fixes ownership so all your files and folders belong to you again.

### 4. Sudo Password Feedback (Asterisks)
By default, Debian’s terminal hides your password (no asterisks or feedback). This option adds visual feedback (e.g., ****) so you can see how many characters you’ve typed. Toggle it on/off as needed.

---

## File Structure

| Directory/File | Description |
|----------------|-------------|
| `./debianito.sh` | Main entry point; handles menu navigation and system detection. |
| `/modules/` | Modular scripts for specific tasks: sudo config, repos, firmware, gpu, kernel, gaming, zram. |
| `/modules/extras/` | Split-by-category sub-modules for the "Install Programs and Software" menu (Option 9). |

```bash
├── debianito.sh
├── modules
│   ├── bullseye
│   │   ├── extras.sh
│   │   ├── legacy.sh
│   │   └── repos.sh
│   ├── extras
│   │   ├── design
│   │   │   └── design.sh
│   │   ├── dev
│   │   │   └── dev.sh
│   │   ├── download
│   │   │   └── download.sh
│   │   ├── essential
│   │   │   └── essential.sh
│   │   ├── fetch
│   │   │   └── fetch.sh
│   │   ├── _helpers.sh
│   │   ├── internet
│   │   │   └── internet.sh
│   │   ├── java.sh
│   │   ├── players
│   │   │   └── players.sh
│   │   ├── programming
│   │   │   └── programming.sh
│   │   ├── security
│   │   │   └── security.sh
│   │   ├── system
│   │   │   └── system.sh
│   │   └── themes
│   │       ├── cursors
│   │       │   └── cursors.sh
│   │       ├── desktop-themes
│   │       │   └── desktop-themes.sh
│   │       ├── fonts
│   │       │   └── fonts.sh
│   │       ├── icons
│   │       │   └── icons.sh
│   │       └── themes.sh
│   ├── extras.sh
│   ├── firmware.sh
│   ├── gaming
│   │   ├── _helpers.sh
│   │   ├── heroic.sh
│   │   ├── steam.sh
│   │   └── tools.sh
│   ├── gaming.sh
│   ├── gpu
│   │   ├── amd_intel.sh
│   │   ├── _helpers.sh
│   │   └── nvidia.sh
│   ├── gpu.sh
│   ├── kernel.sh
│   ├── repos.sh
│   ├── sudo_config.sh
│   ├── utils.sh
│   └── zram.sh
└── README.md
```

---

> 🤖 **AI-Assisted Development Note**  
> This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
