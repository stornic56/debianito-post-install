# Debianito - Post-Installation Automation for Debian

<div align="center">

Debianito is a user-friendly post-installation automation script for Debian 12 (Bookworm) and Debian 13 (Trixie). It streamlines system configuration, driver installation, repository setup, gaming tools integration, and more with an interactive menu-driven interface.

[![License: AGPL v3](https://img.shields.io/badge/License--AGPLv3-green.svg "GNU Affero GPL 3.0")](https://github.com/stornic56/debianito-post-install/blob/main/LICENSE)

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

1. **Select Option:** Use arrow keys or type `1-8`.
2. **Confirm Actions:** For installation steps, you'll see a confirmation prompt (`whiptail`).
3. **Review System Info:** The header displays your detected Debian version and hardware summary before each action.
4. **Repeat as Needed:** Return to the main menu at any time or exit when done.

|Menu Option|What it does|
|-------------|------------------------------------------------------------------------------|
|User Privileges & Feedback|Add user to sudo group + password feedback|
|Repository Configuration|Setup official repos with/without backports|
|Wireless Support|Install WiFi firmware for Broadcom, Intel, etc.|
|Graphics Stack and Tools|AMD/Intel/NVIDIA drivers + monitoring tools (nvtop/radeontop)|
|Update Kernel to Backports|Installs a newer kernel version available in Debian's "Backports" repository|
|Gaming Setup|Steam installation + performance tools (gamemode/mangohud)|
|Extra Applications|Select system utilities like htop, btop, neofetch|

---

## File Structure

| Directory/File | Description |
|----------------|-------------|
| `./debianito.sh` | Main entry point; handles menu navigation and system detection. |
| `/modules/` | Modular scripts for specific tasks: `sudo_config`, `repos`, `firmware`, `gpu`, etc. |

```bash
├── ./debianito.sh          # Main script & menu logic
└── modules/
    ├── utils.sh             # System info helpers
    ├── sudo_config.sh       # User group + pwfeedback setup
    ├── repos.sh             # Repository configuration (classic/deb822)
    ├── firmware.sh          # WiFi microcode and chipset-specific support
    ├── gpu.sh               # AMD, Intel, NVIDIA driver/firmware handling
    ├── kernel.sh            # Update Kernel to Backports
    └── gaming.sh            # Steam installation & performance tools
```
> 🤖 AI-Assisted Development Note
This project was developed with assistance from large language models for code generation, documentation and testing suggestions. The author takes full responsibility for the accuracy of all scripts included in this repository. All modifications have been reviewed manually before inclusion to ensure compatibility with Debian systems.
