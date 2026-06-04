# Debianito - Post-Installation Automation for Debian

<div align="center">

Debianito is a user-friendly post-installation automation script for Debian 12 (Bookworm) and Debian 13 (Trixie). It streamlines system configuration, driver installation, repository setup, gaming tools integration, and more with an interactive menu-driven interface.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-red.svg?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/stornic56/debianito-post-install/blob/main/LICENSE)

</div>

---

## System Requirements

| Requirement | Specification |
|-------------|---------------|
| **OS**      | Debian 12 (Bookworm), Debian 13 (Trixie) |
| **Privileges** | Script must be run with `sudo` privileges by a normal user |
| **Terminal**   | Any modern terminal emulator that supports ANSI colors and UTF-8 box-drawing characters |
| **Dependencies**     | Standard Debian packages; script will install missing dependencies (e.g., `whiptail`, `lsb-release`) where necessary. |

---

## Installation Instructions

### Step 1: Clone or Download the Repository

```bash
git clone https://github.com/stornic56/debianito-post-install
cd debianito-post-install
chmod +x debianito.sh && ./debianito.sh
```

If you downloaded manually, ensure all `.sh` files are in their respective directories.

### Step 2: Run the Script with Sudo Privileges

>  **Do not run this script as root.** Use a normal user account and authorize via `sudo`.

```bash
./debianito.sh
```

The script will perform initial checks, detect your system information (CPU, RAM, GPU), then present an interactive menu.

---

## Usage 

After running the script:

1. **Select Option:** Use arrow keys or type `1-9`.
2. **Confirm Actions:** For installation steps, you'll see a confirmation prompt (`whiptail`/`dialog`).
3. **Review System Info:** The header displays your detected Debian version and hardware summary before each action.
4. **Repeat as Needed:** Return to the main menu at any time or exit when done.

| Option | Description | What it does |
|--------|-------------|--------------|
| **1** | System Info | Show detected hardware and OS details |
| **2** | User Privileges & Feedback | Add user to sudo group, enable password feedback (`pwfeedback`) |
| **3** | Configure Repositories | Setup official repos with/without backports (deb822 or classic format) |
| **4** | Setup Wireless & Firmware | Install WiFi firmware for Broadcom, Intel, and other chipsets |
| **5** | Configure Graphics Stack | AMD/Intel/NVIDIA drivers + monitoring tools (`nvtop`, `radeontop`) |
| **6** | Update Kernel to Backports | Install latest stable kernel from Debian backports (7.0+) |
| **7** | Gaming Setup and Performance | Steam, GameMode, MangoHud, Heroic Games Launcher |
| **8** | Install ZRAM (compressed swap) | Configure compressed RAM for memory optimization |
| **9** | Install Programs and Software | 10 categories: Essential, System, Dev, Players, Internet, Customization, Fetch, Download, Design |
| **10** | Exit | Return to terminal |

### Extra Applications Categories (Option 9)

- **Essential Pack:** Quick install of common tools (compression, system info, VLC, MS fonts)
- **System Tools:** htop, btop, ncdu, timeshift, tmux, flatpak, extrepo, virtualization tools
- **Development & Servers:** Docker, Nginx/Apache, PostgreSQL/MariaDB, SSH server, fail2ban, Python
- **Media Players:** VLC, MPV
- **Internet:** Firefox (Mozilla), LibreWolf, Floorp, Chromium, Thunderbird, Riseup VPN, Tor Browser
- **Customization → Desktop Themes (GTK/KDE):** Arc, Numix, Breeze GTK, Bluebird, Blackbird, Greybird, Orchis
- **Customization → Icon Themes:** Papirus, Numix, Elementary, Deepin, Suru, Obsidian, Breeze, Moka
- **Customization → Cursor Themes:** Bibata, Breeze, Chameleon, DMZ, XCursor, Oxygen
- **Customization → Fonts:** Bebas Neue, Anonymous Pro, ADF Verana, 3270, Liberation, MS Core, Ubuntu, Recommended
- **Fetch Tools:** Neofetch/Fastfetch, hyfetch, Linux logo, Screenfetch
- **Downloaders:** aria2, ytdlp, FileZilla
- **Torrent Clients:** qBittorrent, Deluge, Transmission, mktorrent
- **Multimedia & Design:** GIMP, Kdenlive, Blender, OBS Studio, Audacity, Inkscape, HandBrake

---

## File Structure

| Directory/File | Description |
|----------------|-------------|
| `./debianito.sh` | Main entry point; handles menu navigation and system detection. |
| `/modules/` | Modular scripts for specific tasks: `sudo_config`, `repos`, `firmware`, `gpu`, etc. |
| `/modules/extras/` | Split-by-category sub-modules for the "Install Programs and Software" menu. |

```bash
├── debianito.sh                  # Main entry point; menu + system detection
└── modules/
    ├── utils.sh                  # System info helpers (CPU/RAM/GPU/WiFi detection)
    ├── sudo_config.sh            # User group + pwfeedback setup
    ├── repos.sh                  # Repository configuration (classic/deb822 format)
    ├── firmware.sh               # WiFi microcode and chipset-specific support
    ├── gpu.sh                    # AMD, Intel, NVIDIA driver/firmware handling
    ├── kernel.sh                 # Update Kernel to Backports with NVIDIA warnings
    ├── gaming.sh                 # Steam installation & performance tools
    ├── extras.sh                 # Dispatcher for the "Extras" submenu
    ├── extras/                   # Category modules (one folder per category)
    │   ├── _helpers.sh           # _inst() / _state() shared helpers
    │   ├── essential/essential.sh  # One-click essentials pack
    │   ├── system/system.sh      # System Tools (25 items)
    │   ├── dev/dev.sh            # Development & Servers (15 items)
    │   ├── players/players.sh    # Media Players (mpv, vlc)
    │   ├── internet/internet.sh  # Browsers, Email, VPN (incl. Mozilla/Floorp/LibreWolf)
    │   ├── themes/               # Customization submenu (4 options)
    │   │   ├── themes.sh         # Submenu dispatcher
    │   │   ├── desktop-themes/desktop-themes.sh  # GTK/KDE themes (7)
    │   │   ├── icons/icons.sh    # Icon themes (11-12)
    │   │   ├── cursors/cursors.sh # Cursor themes (6)
    │   │   └── fonts/fonts.sh    # Fonts (8)
    │   ├── fetch/fetch.sh        # System info tools (neofetch/fastfetch/hyfetch)
    │   ├── download/download.sh  # Downloaders + Torrent clients
    │   └── design/design.sh      # Multimedia & Design (12+ items)
    └── zram.sh                   # ZRAM compressed swap configuration
```
> 🤖 AI-Assisted Development Note
This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
