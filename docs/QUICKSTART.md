# Debianito — Quick Start Visual Guide

> **Scope:** Fresh Debian 11 / 12 / 13 installation → fully configured desktop in ~15-20 minutes.
> **Prerequisites:** Normal user with `sudo` access. Do **not** run the script as root.
> **Related:** [README Overview](../README.md) · [System Info](system_info.md) · [Repositories](repos_config.md) · [Firmware](firmware.md) · [GPU](gpu.md) · [Kernel](kernel.md) · [Gaming](gaming.md)

---

## Before You Start

```bash
git clone https://github.com/stornic56/debianito-post-install
cd debianito-post-install
chmod +x debianito.sh && ./debianito.sh
```

The script automatically checks for `whiptail` and `lsb-release`, installs them if missing, verifies `sudo` access, checks network connectivity, and synchronizes the system clock (`systemd-timesyncd` + `tzdata`).

> **Screenshot placeholder:** `media/screenshots/00-main-menu.png` — Main menu (14 options, whiptail centered at 78×20).

---

## Recommended Order

Each step builds on the previous one. Steps 1-5 + 10 are the essential path; 6-9 are optional.

### Step 1 — Know Your System

**Menu:** `1  System Information`

Opens a whiptail message box populated by `utils.sh` detection functions (`detect_cpu_ram`, `detect_gpu`, `detect_network`, `detect_storage`, `detect_displayserver`, `detect_desktop_environment`).

You will see:

- Debian version and codename
- CPU model and RAM size
- GPU vendor(s) and device IDs (e.g., `10de:2684` for NVIDIA)
- Network adapters (Ethernet + WiFi chipset) and their state/IP
- Storage topology (NVMe / SSD / HDD / USB-SD)
- Display server (Wayland / X11 / tty) and desktop environment

Write down the **GPU line** (Intel / AMD / NVIDIA) and any **WiFi chipset** — you will need them in Steps 4-5.

> **Screenshot placeholder:** `media/screenshots/01-system-info.png` — System Information dialog with hardware summary.
> **Tip:** If `GPU: No GPU detected` appears, you are on a VM or headless server — skip Step 5 (Graphics Drivers).

### Step 2 — Fix Permissions Early (Optional but Recommended)

**Menu:** `2  User Privileges & Feedback`

A sub-menu with four toggles:

| Option | What It Does | When to Enable |
| -------- | -------------- | ---------------- |
| Sudo group membership | `usermod -aG sudo $USER` | Fresh install where the first user is not in `sudo` |
| Passwordless sudo | Creates `/etc/sudoers.d/$USER-nopasswd` with `NOPASSWD` for `apt`, `systemctl`, etc. | Lab / personal machine; skip on shared systems |
| Repair home ownership | `chown -R $USER:$USER $HOME` | Home files owned by root after a mishandled `sudo` |
| Sudo password feedback | Writes `Defaults pwfeedback` to `/etc/sudoers.d/pwfeedback` — shows `****` while typing | **Enable now** to avoid typos during the many installs that follow |

> **Screenshot placeholder:** `media/screenshots/02-user-privileges.png` — User Privileges & Feedback menu.
> **Screenshot placeholder:** `media/screenshots/02b-pwfeedback.png` — Confirmation dialog for "Sudo Password Feedback" with asterisk preview.

### Step 3 — System Preferences (Optional)

**Menu:** `3  System Preferences`

```
1  Date, Time & Timezone
2  Language, Locales & Keyboard
3  Audio & Sound Stack
4  Back to main menu
```

- **Date, Time & Timezone** — Runs `dpkg-reconfigure tzdata` and then `_ensure_time_synced` (NTP + `systemd-timesyncd`). Fix timezone before `apt update` — a wrong clock breaks GPG verification.
- **Language, Locales & Keyboard** — Runs `dpkg-reconfigure locales` and `keyboard-configuration`. Requires re-login to apply `LANG`.
- **Audio & Sound Stack** — Checklist with `pipewire-audio` (or `pipewire` on Bullseye), `alsa-utils`, `pavucontrol` (hidden on TTY), `pulsemixer`, `playerctl`. PipeWire on Trixie offers a Backports vs Stable choice and installs Bluetooth Hi-Res codecs (`LDAC`, `aptX`, `AAC`). See [system_prefs.md](system_prefs.md).

> **Screenshot placeholder:** `media/screenshots/03-system-prefs.png` — System Preferences menu.
> **Screenshot placeholder:** `media/screenshots/03b-audio.png` — Audio & Sound checklist with PipeWire selected.

### Step 4 — Configure Repositories (Required)

**Menu:** `4  Configure Repositories`

```
1  Enable Contrib & Non-Free Components
2  Migrate traditional sources.list to DEB822 format
3  Setup/Update Backports repositories
4  [ADVANCED] Upgrade system branch (Testing / SID)
5  Back to main menu
```

1. Choose **1. Enable Contrib & Non-Free** — adds `contrib`, `non-free`, `non-free-firmware` (Bookworm/Trixie). Required for firmware, NVIDIA drivers, and Steam (`contrib`). The script handles both `/etc/apt/sources.list` (classic) and `/etc/apt/sources.list.d/debian.sources` (DEB822) and validates via `apt update` with automatic rollback.
2. Choose **3. Setup/Update Backports** — answers `Yes` to enable `trixie-backports` / `bookworm-backports` in a separate file (`debian-backports.sources` or `.list`). Backports gives newer kernels, Mesa, and firmware. See [repos_config.md](repos_config.md).

> ⚠️ Without `non-free` and `contrib`, Steps 5 and 8 will fail. Do not skip.
> **Screenshot placeholder:** `media/screenshots/04-repos.png` — Repositories menu.
> **Screenshot placeholder:** `media/screenshots/04b-backports.png` — Backports confirmation dialog.

### Step 5 — Install Firmware & Wireless Drivers

**Menu:** `5  Firmware, Wireless & Bluetooth`

The script:

- Scans **all** network hardware (PCI `lspci -nn` + USB `lsusb`, filtered for Realtek/Intel/Mediatek/Atheros/Qualcomm) and Bluetooth controllers
- Maps vendors to packages: `firmware-iwlwifi`, `firmware-realtek`, `firmware-mediatek`, `firmware-atheros`, `firmware-intel-misc` — plus `firmware-linux-nonfree` as the base meta-package
- Builds a plan showing detected controllers and planned packages, including Bluetooth handling (KDE → `bluedevil`, XFCE → `blueman`, GNOME → built-in, plus `pipewire-pulse`/`wireplumber` if PipeWire is active)
- Asks for confirmation before installing; offers Stable vs Backports for the base firmware

Accept the plan it shows — it is based on your actual hardware. Broadcom wireless (if present) is handled via `broadcom-sta-dkms` with DKMS build checks and `update-initramfs` + `modprobe wl`.

> ⚠️ You need internet for this step. If WiFi does not work after firmware install, **reboot** first — the driver needs a fresh load.
> **Screenshot placeholder:** `media/screenshots/05-firmware-plan.png` — Firmware plan dialog with hardware + package list.
> **Screenshot placeholder:** `media/screenshots/05b-bluetooth.png` — Bluetooth section of the plan (if applicable).

### Step 6 — Install Graphics Drivers

**Menu:** `6  Graphics Drivers & Mesa Stack`

Whiptail radiolist with two options:

```
1  Radeon/Intel Mesa
2  NVIDIA Drivers
```

#### Path A — Radeon/Intel Mesa

Shows a plan with detected GPUs (`Intel firmware + intel-media-va-driver-non-free` or `i965-va-driver-shaders` for Gen7-, `firmware-amd-graphics` for AMD, plus `Mesa Vulkan/OpenGL/VA-API`). Offers legacy AMD GCN 1.0/1.1 migration to `amdgpu` via GRUB params (`radeon.si_support=0 ... amdgpu.si_support=1`). Installs Mesa from Backports or Stable (`_install_mesa_backports`), verifies `mesa-vulkan-drivers`, and offers vendor-specific telemetry (`radeontop`, `intel-gpu-tools`, `vainfo`).

#### Path B — NVIDIA Drivers

Shows detected NVIDIA GPUs and a two-stage menu:

1. **Manage menu** (if a driver is already installed): *Install / Change Driver Version* vs *Remove Driver and Restore Nouveau*.
2. **Version menu** (depends on Debian version):
   - Bookworm: `v535` (Recommended) or `v470` (Kepler legacy via `nvidia-tesla-470-driver`)
   - Trixie: `v550` (Debian stable, Recommended), `v590` or `v595` (NVIDIA CUDA Repo with `cuda-keyring` + `nvidia-open` + `firmware-nvidia-gsp`)

The script auto-detects the GPU architecture (`kepler` / `fermi` / `maxwell` / `pascal` / `turing` / `ampere` / `ada` / `blackwell`) and enforces compatibility — e.g., Blackwell requires `v590+` on Trixie, Maxwell/Pascal on Trixie + backports kernel is forced to `v550` stable, Fermi is vetoed on Bookworm/Trixie with an explanatory message.

> **Screenshot placeholder:** `media/screenshots/06-gpu-choice.png` — GPU type selector (Radeon/Intel vs NVIDIA).
> **Screenshot placeholder:** `media/screenshots/06b-nvidia-version.png` — NVIDIA version menu (535 / 470 or 550 / 590 / 595).
> **Tip:** After installation, **reboot** before testing. NVIDIA drivers need a fresh kernel load.

### Step 7 — Kernel Configuration (Optional)

**Menu:** `7  Kernel`

```
stable     Install linux-image-amd64 (Stable)
backports  Install from backports (Trixie only)
rt         Install linux-image-rt-amd64 (Preempt-RT)
cloud      Install linux-image-cloud-amd64
back       Return to main menu
```

- **Stable** — default Debian kernel (6.12 LTS on Trixie).
- **Backports** — only on Trixie; requires `trixie-backports` enabled in Step 4. Newer kernel (e.g., 7.x) for Intel Arrow Lake / AMD Zen 5, Battlemage D3cold, etc.
- **RT** — Preempt-RT low-latency kernel. Warns if `GPU_TYPE == nvidia` (proprietary drivers may not support RT).
- **Cloud** — minimal kernel for VMs/containers (`linux-image-cloud-amd64`).

Each variant installs the matching `linux-headers-*` package atomically (`sudo apt install -y [-t trixie-backports] linux-image-* linux-headers-*`). The script warns about DKMS recompilation if NVIDIA is present.

> **Screenshot placeholder:** `media/screenshots/07-kernel.png` — Kernel menu with four variants.
> See [kernel.md](kernel.md) for backports rationale and bootloader details.

### Step 8 — Gaming Setup (Optional)

**Menu:** `8  Gaming Setup`

A single checklist with all options:

```
[*] i386      Enable 32-bit (i386) architecture
[*] steam     Steam (requires 32-bit support)
[*] mangohud  Performance overlay (Vulkan/OpenGL)
[ ] gamemode  Game performance optimization
[*] goverlay  MangoHud config GUI
[ ] heroic    Heroic Launcher (Epic/GOG)
[ ] java      Minecraft Java Runtime
[ ] openrgb   OpenRGB (RGB lighting control)
[ ] lutris    Lutris + Wine (requires 32-bit support)
[ ] retroarch RetroArch Emulator Frontend
```

- If `steam`, `lutris`, or `i386` is checked, the script runs `dpkg --add-architecture i386` + `apt update`, then installs 32-bit graphics libraries (`_install_nvidia_32bit` or `_install_mesa_32bit`).
- `steam` checks `contrib` (`ensure_contrib_repo`) and installs `steam-installer`.
- `heroic` fetches the latest `.deb` from GitHub releases (`api.github.com`).
- `openrgb` is Bookworm/Trixie only; handles `i2c-dev`, udev, `i2c` group, and `setcap`.
- `java` offers Temurin 8 / 17 / 21 / 25 via `extrepo adoptium`.
- Requires GUI for some installers (skipped on headless).

> **Screenshot placeholder:** `media/screenshots/08-gaming.png` — Gaming checklist with i386 + Steam + MangoHud checked.
> See [gaming.md](gaming.md) and [retroarch.md](retroarch.md).

### Step 9 — ZRAM Compressed Swap (Optional)

**Menu:** `9  ZRAM`

```
1  View ZRAM status
2  Create / Reconfigure ZRAM
3  Remove ZRAM
4  Back to main menu
```

- **View** — Shows `/etc/default/zramswap` (`ALGO`, `SIZE`, `PRIORITY`) and `zramctl` output.
- **Create / Reconfigure** — Choice of `lz4` (fastest, gaming) vs `zstd` (better ratio). Recommended size is 50% of RAM (≤8 GB) or 4096 MB fixed (>8 GB), configurable. Writes to `/etc/default/zramswap` (`ALGO`, `SIZE`, `PRIORITY=100`) and `systemctl restart zramswap || true`. Priority 100 ensures ZRAM is used before any disk swap (priority 10).
- **Remove** — `systemctl stop zramswap`, `swapoff /dev/zram0`, `modprobe -r zram`, `apt purge zram-tools`, removes `/etc/default/zramswap`.

> **Screenshot placeholder:** `media/screenshots/09-zram-algo.png` — Algorithm choice (lz4 vs zstd).
> **Screenshot placeholder:** `media/screenshots/09b-zram-status.png` — `zramctl` status output in whiptail.
> See [zram.md](zram.md).

### Step 10 — Swap Management (Optional)

**Menu:** `10  Swap Management`

```
1  Show current swap & swappiness
2  Create / resize swapfile
3  Remove swapfile
4  Change swappiness
5  Back to main menu
```

- Uses `/swapfile` with `pri=10` (below ZRAM's 100) and tag `# debianito-managed-swap` in `/etc/fstab`.
- Btrfs: warns about `nodatacow` (`chattr +C`) and hibernation limitations; uses `dd` instead of `fallocate`.
- Fstab is written via a temp file and validated with `findmnt --verify` before replacing `/etc/fstab`.
- Concurrency is guarded by `flock /run/lock/debianito-swap.lock`.

> **Screenshot placeholder:** `media/screenshots/10-swap.png` — Swap Management menu.
> See [swap.md](swap.md).

### Step 11 — Essential Software

**Menu:** `11  Install Programs and Software` → `0  Essential Pack`

One-click install of `htop`, `inxi`, `neofetch`/`fastfetch`, `vlc`, `ufw`, `zip`, `unrar`, `p7zip`, plus `lsb-release` fixes.

After this, browse the other categories as needed:

| Category | Example Packages |
| ---------- | ------------------ |
| Customization System | Desktop themes, icons, cursors, fonts |
| Download & Network | aria2, ytdlp, qBittorrent, Deluge |
| Internet | Firefox, LibreWolf, Chromium, Tor, Thunderbird, RiseUp/Mullvad VPN |
| Communication | Signal, Telegram, HexChat |
| Media Players | VLC, MPV |
| Multimedia & Design | GIMP, Kdenlive, Blender, Audacity, Inkscape |
| Code Editors & IDEs | Neovim, Helix, Emacs, VSCodium, Geany |
| Servers & Dev Tools | Nginx, PostgreSQL, Docker, Temurin JDK, Jellyfin |
| Security & Networking | Wireshark, ClamAV, UFW, fail2ban |
| Software Center & Flatpak | GNOME Software, KDE Discover, Flatpak |
| Office & Productivity | LibreOffice, document tools |
| System Tools | htop/btop, Timeshift, extension-manager, virt-manager |
| Fetch / System Info | fastfetch, neofetch, hyfetch, screenfetch |

> **Screenshot placeholder:** `media/screenshots/11-essentials.png` — Category menu with 0-14 options.
> **Screenshot placeholder:** `media/screenshots/11b-essential-pack.png` — Essential Pack confirmation.

### Step 12 — Boot Rescue

**Menu:** `12  Boot Rescue + GRUB`

- **GRUB boot menu settings** — 4 presets (hidden 0s / 3s / 5s / custom) writing `GRUB_TIMEOUT`, `GRUB_TIMEOUT_STYLE`, `GRUB_RECORDFAIL_TIMEOUT`, `GRUB_DISABLE_OS_PROBER` to `/etc/default/grub.d/99_script_override.cfg` with `update-grub` + backup/rollback.
- **UEFI Secure Boot repair** — reinstalls `shim-signed`, `grub-efi-amd64-signed`, `linux-image-amd64`, runs `grub-install` + `update-grub` (UEFI only, checked via `/sys/firmware/efi` + `mokutil`).
- **Initramfs regeneration** — `update-initramfs -u -k all || true`.

> See [boot.md](boot.md).

### Step 13 — Desktop & Display

**Menu:** `13  Desktop & Display`

```
1  Desktop Environment
2  Display Manager
3  Back to main menu
```

- **Desktop Environment** — XFCE (full / minimal / Wayland `labwc` on Trixie / custom checklist) or LXDE (full / core). Installs polkit rules (`85-suspend.rules`, `89-backlight.rules`) + `backlight` group.
- **Display Manager** — LightDM (GTK greeter, user list, autologin), GDM3 (user list, autologin, NVIDIA Wayland override via `61-gdm.rules → /dev/null`), SDDM (autologin with session auto-detection `plasmawayland → lxqt-wayland → plasma → lxqt`), greetd (base / tuigreet / gtkgreet / nwg-hello / wlgreet — manual `/etc/greetd/config.toml` required).

> See [desktops_display.md](desktops_display.md).

---

## After the Script

1. **Reboot** if you installed firmware, GPU drivers, or a new kernel.
2. Verify:

   ```bash
   sudo zramctl              # ZRAM active?
   sudo swapon --show        # Swap with correct priorities?
   vainfo                    # VA-API acceleration?
   nvidia-smi                # NVIDIA driver loaded?
   systemctl status bluetooth # Bluetooth active?
   ```

3. For gaming, enable `i386` was handled — verify with `dpkg --print-foreign-architectures | grep i386`.

---

## Troubleshooting Quick Answers

| Symptom | Fix |
| --------- | ----- |
| **WiFi not working after firmware** | Reboot. Check `lspci -nn \| grep Network` and verify the package (`firmware-iwlwifi` etc.) is `ii` via `dpkg -l`. Ensure `non-free` + `non-free-firmware` were enabled in Step 4. |
| **Black screen after NVIDIA + Wayland (GNOME/GDM3)** | At login, select *GNOME on Xorg* (gear icon) or disable Wayland: `sudo nano /etc/gdm3/daemon.conf` → `WaylandEnable=false`. The script only warns about Debian bug #1109409, it does not force X11. |
| **GRUB menu hidden and cannot enter** | Hold `ESC` immediately after power-on. Or boot a live USB, `chroot`, and run `12  Boot Rescue → GRUB boot menu settings → Show 5 seconds`. |
| **Steam fails to start** | Verify `i386` is enabled: `dpkg --print-foreign-architectures`. Check `contrib` is in `/etc/apt/sources.list`. Re-run `8  Gaming Setup` and ensure the checklist had `i386` + `steam` checked. |
| **greetd installed but cannot log in** | This is expected — you must create `/etc/greetd/config.toml` manually. See `man greetd` and `man 5 greetd-sessions`. |
| **Bluetooth tray icon missing** | Reboot or `systemctl restart bluetooth`. Ensure `bluez`, `bluedevil` (KDE) or `blueman` (XFCE) is installed. For PipeWire, check `systemctl --user status pipewire pipewire-pulse wireplumber`. |
| **PipeWire crackling / no Bluetooth Hi-Res codec** | Re-run `3  System Preferences → Audio & Sound → PipeWire Audio Stack`. Verify `libldacbt-*`, `libopenaptx0`, `libfdk-aac2t64` are installed (`dpkg -l \| grep -E 'ldac\|aptx\|fdk'`). |

---

## Taking Screenshots for This Guide

Screenshots are taken from `whiptail` dialogs. To capture them:

1. Run the script inside a terminal that supports image export (e.g., `gnome-terminal` + `gnome-screenshot`, or `asciinema`).
2. For whiptail, press `PrintScreen` or use `import -window root screenshot.png` (ImageMagick).
3. Save under `media/screenshots/` with the filenames referenced above (`01-system-info.png`, `04-repos.png`, etc.).
4. Keep width ≈ 800px; the script uses fixed `TUI_ANCHO=78` and `TUI_ALTO=20` centered dialogs.

> **Note:** Until real screenshots are added, the placeholders above describe the expected content of each image.
