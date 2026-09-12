# Option 3: System Preferences

## 1. What Does This Component Do?

The **System Preferences** module (`modules/system/system_prefs.sh` + `modules/system/audio.sh`) consolidates first-boot personalization into a single menu. It is the only place in Debianito where **locale, timezone, and audio** are configured together — settings that Debian's installer often leaves at generic defaults and that affect every subsequent module.

It groups three independent preference domains behind one entry point:

| Sub-menu | Script | What It Configures |
| ---------- | -------- | --------------------- |
| **Date, Time & Timezone** | `system_prefs.sh:_prefs_date_time` | System clock, NTP sync, `tzdata` |
| **Language, Locales & Keyboard** | `system_prefs.sh:_prefs_locale_keyboard` | `locales`, `keyboard-configuration` |
| **Audio & Sound Stack** | `system/audio.sh:_prefs_audio_menu` | PipeWire, ALSA, pavucontrol, pulsemixer, playerctl |

The menu itself is `_system_preferences_menu` in `system_prefs.sh` — a simple `while true` loop with `whiptail --menu`:

```
1  Date, Time & Timezone
2  Language, Locales & Keyboard
3  Audio & Sound Stack
4  Back to main menu
```

> **Note:** This option was added after the initial repository setup. The main `README.md` menu previously started directly at "Configure Repositories". All Quick Start guides now reference System Preferences as Step 3.

---

## 2. Date, Time & Timezone

### Function: `_prefs_date_time` (`system_prefs.sh`)

```
Current system date/time: 2026-03-15 14:22
Timezone: America/Santiago
  → Confirm "Change the system timezone (dpkg-reconfigure tzdata)?"
      → sudo dpkg-reconfigure tzdata
  → _ensure_time_synced
```

**What it does technically:**

1. Prints the current date/time (`date '+%Y-%m-%d %H:%M'`) and timezone (`timedatectl show -p Timezone --value`).
2. Prompts via `_confirm "Timezone"` to run `sudo dpkg-reconfigure tzdata` — the Debian-standard interactive timezone selector (ncurses).
3. Calls `_ensure_time_synced` from `utils.sh` regardless of the answer:
   - Forces `timedatectl set-ntp true`
   - Validates the timezone is not `n/a` or `Etc/UTC`; if it is and a display is available, opens `tzdata` again
   - Ensures `systemd-timesyncd` is installed, enabled and restarted
   - Waits 2 seconds and checks `timedatectl show --property=NTPSynchronized --value` for `yes`

**Why it matters:** An incorrect clock breaks APT GPG verification (`Release file is not valid yet`) and TLS certificates. The script runs a similar check automatically at startup (`_ensure_time_synced` in `debianito.sh` line 108), but this menu allows the user to fix timezone manually without re-running the whole script.

---

## 3. Language, Locales & Keyboard

### Function: `_prefs_locale_keyboard` (`system_prefs.sh`)

```bash
sudo dpkg-reconfigure locales
sudo dpkg-reconfigure keyboard-configuration
```

**What it does technically:**

- **`dpkg-reconfigure locales`** — Opens the Debian locales selector (e.g., `en_US.UTF-8`, `es_CL.UTF-8`). Generates the selected locales via `locale-gen` and updates `/etc/default/locale`. No reboot is required, but a re-login is needed for the new `LANG` to take effect.
- **`dpkg-reconfigure keyboard-configuration`** — Configures `/etc/default/keyboard` (`XKBMODEL`, `XKBLAYOUT`, `XKBVARIANT`, `XKBOPTIONS`) and, on console, the keymap via `setupcon`. This affects both X11/Wayland and TTY.

Both commands are run with `env LC_ALL=C LANGUAGE=C` to guarantee the debconf dialogs render in English even when the current locale is broken.

This option has **no detection logic** — it delegates entirely to Debian's standard tools. It is idempotent and safe to run repeatedly.

---

## 4. Audio & Sound Stack

### Function: `_prefs_audio_menu` (`system/audio.sh`)

This is the most complex sub-menu. It presents a checklist built dynamically based on system state:

#### 4.1 Menu Construction

```bash
items+=("pipewire-audio" "PipeWire Audio Stack (Bluetooth Hi-Res)" $state)
items+=("alsa-utils"     "ALSA Utilities (alsa-utils, alsa-ucm-conf)" $state)
# headless check — pavucontrol is GUI-only
if ! _is_headless; then
  items+=("pavucontrol"  "Volume Control GUI (pavucontrol)" $state)
fi
items+=("pulsemixer"     "Terminal audio mixer (pulsemixer)" $state)
items+=("playerctl"      "Multimedia key controller (playerctl)" $state)
```

- **`_state <pkg>`** (in `utils.sh`) returns `ON` if `dpkg -l <pkg>` shows `^ii`, otherwise `OFF`.
- **`_is_headless`** returns true when both `$DISPLAY` and `$WAYLAND_DISPLAY` are empty — in that case `pavucontrol` is hidden because it requires a GUI.
- Package name for PipeWire varies by Debian version:
  - Debian 11 Bullseye → `pipewire` (the `pipewire-audio` metapackage does not exist)
  - Debian 12/13 → `pipewire-audio`

The checklist is shown via `whiptail --checklist` with the title **"Audio & Sound"**.

#### 4.2 PipeWire Installation Logic: `_install_pipewire_standard`

This function handles the **PipeWire Audio Stack with Bluetooth Hi-Res codecs** — the core of modern Linux audio.

**Codec package resolution:**

```bash
bt_pkgs="libldacbt-abr2 libldacbt-enc2 libopenaptx0 libspa-0.2-bluetooth"
# Transitional package name: libfdk-aac2t64 on Trixie (64-bit time_t), libfdk-aac2 on older
if apt-cache show libfdk-aac2t64; then bt_pkgs+=" libfdk-aac2t64"
elif apt-cache show libfdk-aac2; then bt_pkgs+=" libfdk-aac2"
fi
```

These packages provide **LDAC** (Sony), **aptX** (Qualcomm), and **AAC** (via FDK) Bluetooth codecs that are not in the default PipeWire installation.

**Version selection (Trixie only, when backports is enabled):**

| Condition | Dialog | Effect |
| ----------- | -------- | -------- |
| Already installed + backports available | `Upgrade to backports vX?` (Yes/No) | `sudo apt install --reinstall -t trixie-backports pipewire-audio $bt_pkgs` + `systemctl --user restart wireplumber pipewire pipewire-pulse` |
| Not installed + backports available | `Backports vX` vs `Stable vY` (Backports/Stable buttons) | Installs from chosen repository; on Trixie `apt_target="-t trixie-backports"` if Backports chosen |
| No backports | `Install PipeWire vX with Hi-Res codecs?` | Installs from stable |

**Per-Debian-version install commands:**

```bash
# Debian 11 Bullseye
sudo apt install -y pipewire libspa-0.2-bluetooth pipewire-alsa libspa-0.2-jack $bt_pkgs

# Debian 12 Bookworm
sudo apt install -y pipewire-audio $bt_pkgs

# Debian 13 Trixie
sudo apt install -y [-t trixie-backports] pipewire-audio $bt_pkgs
```

After installation on Debian 12/13, user PipeWire services are restarted:

```bash
systemctl --user restart wireplumber pipewire pipewire-pulse
```

#### 4.3 Other Audio Packages

| Package | Purpose | Install Guard |
| --------- | --------- | --------------- |
| `alsa-utils` + `alsa-ucm-conf` | ALSA CLI tools (`aplay`, `amixer`, `alsamixer`) and UCM configs for modern sound cards | `is_installed alsa-utils` |
| `pavucontrol` | GTK GUI volume control (PulseAudio/PipeWire compatible). Hidden in headless mode. | `is_installed pavucontrol` |
| `pulsemixer` | Terminal (ncurses) mixer — works in TTY and headless | `is_installed pulsemixer` |
| `playerctl` | MPRIS CLI to control media players via keyboard shortcuts | `is_installed playerctl` |

Each package is installed via `_run_install <pkg>` which confirms the version via `apt-cache policy` before installing.

---

## 5. Logical Execution Flow

```
┌──────────────────────────────────────────────────────────┐
│           _system_preferences_menu (system_prefs.sh)     │
├──────────────────────────────────────────────────────────┤
│  whiptail --menu "System Preferences"                    │
│    1  Date, Time & Timezone                              │
│    2  Language, Locales & Keyboard                       │
│    3  Audio & Sound Stack                                │
│    4  Back to main menu                                  │
└──────────────────────────────────────────────────────────┘
         │              │                  │
         ▼              ▼                  ▼
   _prefs_date_time  _prefs_locale_   _prefs_audio
                     keyboard         → _prefs_audio_menu
         │              │                  │
         │              │          ┌───────┴────────┐
         │              │          │ Dynamic checklist│
         │              │          │ based on         │
         │              │          │ _state + headless│
         │              │          └───────┬────────┘
         │              │                  │
         │              │          pipewire-audio ──→ _install_pipewire_standard
         │              │          alsa-utils     ──→ apt install alsa-utils
         │              │          pavucontrol    ──→ apt install pavucontrol
         │              │          pulsemixer     ──→ apt install pulsemixer
         │              │          playerctl      ──→ apt install playerctl
```

---

## 6. Integration with Other Modules

- **Firmware (`firmware.sh`)** — Bluetooth firmware packages (`firmware-iwlwifi`, etc.) are separate from the Bluetooth *stack* (`bluez`). This menu complements firmware by ensuring the audio side of Bluetooth (PipeWire codecs) is ready.
- **Desktop & Display (`desktop_display.sh`)** — XFCE/LXDE installations often need audio configured afterwards. Running System Preferences → Audio after a new desktop ensures the correct mixer is available.
- **Gaming (`gaming.sh`)** — Many games require PipeWire/PulseAudio for voice chat. The gaming module assumes audio is already functional.
- **Time sync (`utils.sh:_ensure_time_synced`)** — Also called automatically at script startup. This menu is the manual override.

---

## 7. Detection & State Variables

| Variable / Function | Source | Used Here |
| --------------------- | -------- | ----------- |
| `DEBIAN_VERSION` (`11`/`12`/`13`) | `utils.sh:detect_debian_version` | PipeWire package name + install path |
| `AUDIO_SERVER` (`pipewire`/`pulseaudio`/`none`) | `utils.sh:detect_audio_server` | Bluetooth integration in `firmware.sh` |
| `is_backports_enabled` | `utils.sh:is_backports_enabled` | PipeWire backports version choice (Trixie) |
| `_is_headless` | `utils.sh:_is_headless` | Hides `pavucontrol` in TTY/SSH |
| `_state <pkg>` | `utils.sh:_state` | Checklist ON/OFF state |
| `_ensure_time_synced` | `utils.sh:_ensure_time_synced` | Called after timezone change |

---

## References

- [Debian TimeZone Config — wiki.debian.org/TimeZoneChanges](https://wiki.debian.org/TimeZoneChanges)
- [Debian Locales — wiki.debian.org/Locale](https://wiki.debian.org/Locale)
- [PipeWire — wiki.debian.org/PipeWire](https://wiki.debian.org/PipeWire)
- [PipeWire Bluetooth Codecs — GitLab PipeWire wiki](https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/FAQ#bluetooth)
