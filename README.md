# Debianito - Post-Installation Automation for Debian

<div align="center">

Debianito is a user-friendly post-installation automation script for Debian 12 (Bookworm) and Debian 13 (Trixie). It streamlines system configuration, driver installation (including NVIDIA drivers), repository setup with backports support, gaming tools integration, and more with an interactive menu-driven interface.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-red.svg?style=for-the-badge&logo=gnu&logoColor=white)](https://github.com/stornic56/debianito-post-install/blob/main/LICENSE)

</div>

---

## System Requirements

| Requirement | Specification |
|-------------|---------------|
| **OS**      | Debian 12 (Bookworm), Debian 13 (Trixie) |
| **Privileges** | Normal user with `sudo` access, script validates root/sudo in `utils.sh`|
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

1. **Select Option:** Use arrow keys or type `1-10`.
2. **Confirm Actions:** Installation prompts use `whiptail` for TUI confirmations.
3. **Review System Info:** Header displays detected Debian version `DEBIAN_CODENAME`, `DEBIAN_VERSION` and hardware summary before each action.
4. **Repeat as Needed:** Return to main menu at any time or exit when done.

| Option | Description | What it does |
|--------|-------------|--------------|
| **1** | System Info | Show detected Os, CPU, RAM, GPU and others  |
| **2** | User Privileges & Feedback | Add user to sudo group, enable `pwfeedback` for password visibility |
| **3** | Configure Repositories | Setup official repos with/without backports (deb822 or classic format)|
| **4** | Setup Wireless & Firmware | Install WiFi firmware for Broadcom, Intel, and other chipsets|
| **5** | Configure Graphics Stack | AMD/Intel/NVIDIA drivers + monitoring tools |
| **6** | Update Kernel to Backports | Install latest stable kernel from Debian backports|
| **7** | Gaming Setup and Performance | Steam, Heroic Games Launcher, GameMode, MangoHud and others|
| **8** | Install ZRAM (compressed swap) | Configure compressed RAM for memory optimization|
| **9** | Install Programs and Software | Selection across 10 categories (Dev, Themes, System, etc.) |
| **10** | Exit | Return to terminal |

### Extra Applications Categories (Option 9)

The submenu offers 11 categories (`0-9` + Back):

| Option | Category | Description |
|--------|----------|-------------|
| **0** | Essential Pack | Quick install of common tools (compression, system info, VLC, MS fonts) |
| **1** | Customization System | Desktop themes, icon themes, cursor themes, and fonts|
| **2** | Download & Network | Downloaders (aria2, ytdlp, FileZilla) + Torrent clients (qBittorrent, Deluge, Transmission)|
| **3** | Internet | Browsers (Firefox/Mozilla, LibreWolf, Floorp, Chromium), email clients, VPN tools|
| **4** | Media Players | VLC and MPV|
| **5** | Multimedia & Design | GIMP, Kdenlive, Blender, OBS Studio, Audacity, Inkscape and HandBrake|
| **6** | Programming Applications | Development tools (Docker, Nginx/Apache, PostgreSQL/MariaDB, SSH, fail2ban, Python)|
| **7** | Security & Networking | Additional security and networking utilities |
| **8** | System Tools | htop, btop, ncdu, timeshift, tmux, flatpak, extrepo and virtualization tools|
| **9** | Fetch / System Info | Fastfetch/Neofetch, hyfetch, Linux logo and Screenfetch |
| **10** | Back to main menu | Return to the main script menu |

---

## File Structure

| Directory/File | Description |
|----------------|-------------|
| `./debianito.sh` | Main entry point; handles menu navigation and system detection. |
| `/modules/` | Modular scripts for specific tasks: sudo config, repos, firmware, gpu, kernel, gaming, zram. |
| `/modules/extras/` | Split-by-category sub-modules for the "Install Programs and Software" menu (Option 9). |

```bash
├── debianito.sh                  # Main entry point; TUI menu + system detection
└── modules/
    ├── utils.sh                  # System info helpers: CPU/RAM/GPU/WiFi detection, Debian version check ([`detect_debian_version()`](utils.sh#L79))
    ├── sudo_config.sh            # User group + pwfeedback setup
    ├── repos.sh                  # Repository configuration (deb822/classic format) with backup/restore
    ├── firmware.sh               # WiFi microcode and chipset-specific support via [`firmware-linux-nonfree`](modules/firmware.sh)
    ├── gpu.sh                    # AMD/Intel/NVIDIA driver handling ([`detect_gpu()`](utils.sh#L168)); NVIDIA Kepler/Turing detection veto (line 203+)
    ├── kernel.sh                 # Update Kernel to Backports with NVIDIA compatibility warnings
    ├── gaming.sh                 # Steam, GameMode, MangoHud, Heroic Games Launcher
    ├── extras.sh                 # Dispatcher for the "Extras" submenu (Option 9)
    ├── zram.sh                   # ZRAM compressed swap configuration
    └── extras/                   # Category modules organized by function
        ├── _helpers.sh           # Shared helpers: [`_inst()`](utils.sh#L418), [`_state()`] for package management
        ├── essential/            # Essential Pack (compression, system info, VLC, MS fonts)
        │   └── essential.sh     # One-click essentials installation
        ├── system/               # System Tools (htop, btop, ncdu, timeshift, tmux, flatpak, extrepo, virtualization tools)
        │   └── system.sh        # 25+ system utility packages
        ├── dev/                  # Development & Servers (Docker, Nginx/Apache, PostgreSQL/MariaDB, SSH, fail2ban, Python)
        │   └── dev.sh           # 15 development/server tools
        ├── players/              # Media Players (VLC, MPV)
        │   └── players.sh       # Video player packages
        ├── internet/             # Internet: Firefox (Mozilla), LibreWolf, Floorp, Chromium, Thunderbird, Riseup VPN, Tor Browser
        │   └── internet.sh      # Browsers, email clients, VPN tools
        ├── themes/               # Customization submenu with 4 options
        │   ├── themes.sh        # Submenu dispatcher for customization categories
        │   ├── desktop-themes/  # Desktop Themes (GTK/KDE): Arc, Numix, Breeze GTK, Bluebird, Blackbird, Greybird, Orchis
        │   │   └── desktop-themes.sh
        │   ├── icons/           # Icon Themes: Papirus, Numix, Elementary, Deepin, Suru, Obsidian, Breeze, Moka
        │   │   └── icons.sh     # 11-12 icon theme packages
        │   ├── cursors/         # Cursor Themes: Bibata, Breeze, Chameleon, DMZ, XCursor, Oxygen
        │   │   └── cursors.sh   # 6 cursor theme packages
        │   └── fonts/           # Fonts: Bebas Neue, Anonymous Pro, ADF Verana, 3270, Liberation, MS Core, Ubuntu, Recommended
        │       └── fonts.sh     # 8 font packages including MS Core fonts
        ├── fetch/                # Fetch Tools (Neofetch/Fastfetch, hyfetch, Linux logo, Screenfetch)
        │   └── fetch.sh         # System info display tools
        ├── download/             # Downloaders & Torrent Clients: aria2, ytdlp, FileZilla, qBittorrent, Deluge, Transmission, mktorrent
        │   └── download.sh      # Download manager + torrent client packages
        └── design/               # Multimedia & Design (GIMP, Kdenlive, Blender, OBS Studio, Audacity, Inkscape, HandBrake)
            └── design.sh        # 12+ creative applications
```

> 🤖 **AI-Assisted Development Note**  
> This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
> 🤖 AI-Assisted Development Note
This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
