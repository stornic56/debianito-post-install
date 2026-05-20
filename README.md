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
| **1** | User Privileges & Feedback | Add user to sudo group, enable password feedback (`pwfeedback`) |
| **2** | Configure Repositories | Setup official repos with/without backports (deb822 or classic format) |
| **3** | Setup Wireless & Firmware | Install WiFi firmware for Broadcom, Intel, and other chipsets |
| **4** | Configure Graphics Stack | AMD/Intel/NVIDIA drivers + monitoring tools (`nvtop`, `radeontop`) |
| **5** | Update Kernel to Backports | Install latest stable kernel from Debian backports (7.0+) |
| **6** | Gaming Setup and Performance | Steam, GameMode, MangoHud, Heroic Games Launcher |
| **7** | Install ZRAM (compressed swap) | Configure compressed RAM for memory optimization |
| **8** | Install Extra Applications | Select from 10+ categories: System Tools, Development, Media Players, Web Browsers, GTK/Icon Themes, Downloaders, Design Software |
| **9** | Exit | Return to terminal |

### Extra Applications Categories (Option 8)

- **System Tools:** htop, btop, ncdu, timeshift, tmux, flatpak, virtualization tools
- **Development & Servers:** Docker, Nginx/Apache, PostgreSQL/MariaDB, SSH server, fail2ban
- **Media Players:** VLC, MPV, HandBrake
- **Web Browsers:** Firefox (Mozilla), LibreWolf, Floorp, Chromium, Thunderbird
- **GTK Themes:** Arc, Numix, Breeze, Bluebird, Blackbird, Greybird, Orchis
- **Icon Themes:** Papirus, Numix, Elementary, Deepin, Suru, Obsidian
- **Fetch Tools:** Neofetch/Fastfetch, Linux logo, Screenfetch
- **Downloaders:** aria2, ytdlp, FileZilla, Riseup VPN
- **Torrent Clients:** qBittorrent, Deluge, Transmission, mktorrent
- **Multimedia & Design:** GIMP, Kdenlive, Blender, OBS Studio, Audacity, Inkscape

---

## File Structure

| Directory/File | Description |
|----------------|-------------|
| `./debianito.sh` | Main entry point; handles menu navigation and system detection. |
| `/modules/` | Modular scripts for specific tasks: `sudo_config`, `repos`, `firmware`, `gpu`, etc. |

```bash
├── debianito.sh          # Main entry point; handles menu navigation and system detection
└── modules/
    ├── utils.sh             # System info helpers (CPU/RAM/GPU/WiFi detection)
    ├── sudo_config.sh       # User group + pwfeedback setup
    ├── repos.sh             # Repository configuration (classic/deb822 format)
    ├── firmware.sh          # WiFi microcode and chipset-specific support
    ├── gpu.sh               # AMD, Intel, NVIDIA driver/firmware handling
    ├── kernel.sh            # Update Kernel to Backports with NVIDIA warnings
    ├── gaming.sh            # Steam installation & performance tools (MangoHud/GameMode)
    ├── extras.sh            # Extra applications installer with 10+ categories
    └── zram.sh              # ZRAM compressed swap configuration and optimization
```
> 🤖 AI-Assisted Development Note
This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
