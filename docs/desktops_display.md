## Option 12: Desktop & Display

### 1. What does this component do?
This component manages display managers (the login screen you see before entering your desktop). It allows users to install and configure LightDM, GDM3, SDDM, or greetd. It handles autologin setup, user list visibility toggles, and a specific Wayland override for NVIDIA GPUs. Currently, Desktop Environment management is marked as "Coming Soon".

### 2. Logical Flow of Execution
The execution logic is divided into five functional blocks:

**Block 1 — Display Manager Selection**
- The main menu offers two primary options within Option 12: "Desktop Environment" (currently unavailable) and "Display Manager".
- Selecting "Display Manager" opens a submenu listing available display managers based on the Debian version.
- **Available Managers:**
  - LightDM (available on all Debian versions).
  - GDM3 (available on all Debian versions).
  - SDDM (available on all Debian versions).
  - greetd (available only on Debian 12 and 13).
- Each selected manager opens its own dedicated configuration submenu.

**Block 2 — LightDM Configuration**
- A checklist menu presents three options:
  1. Install LightDM + GTK Greeter (auto-selects the display manager via debconf-set-selections).
  2. Enable user list at login screen (writes `greeter-hide-users=false` to a configuration file in `.conf.d`).
  3. Enable autologin for current user (uncomments `autologin-user` and sets timeout to 0 in the main config).
- **Idempotency:** The script checks if `lightdm` and `lightdm-gtk-greeter-settings` are already installed before attempting installation, skipping redundant steps.

**Block 3 — GDM3 Configuration**
- A checklist menu presents up to four options:
  1. Install/Reinstall gdm3 (auto-selects via debconf).
  2. Toggle user list visibility (toggles `disable-user-list` in greeter.dconf-defaults).
  3. Configure autologin (prompts for a username via whiptail inputbox to set in daemon.conf).
  4. Force Enable Wayland on NVIDIA (Bookworm/Trixie + NVIDIA only).
     - **Mechanism:** Creates or removes a symlink: `/etc/udev/rules.d/61-gdm.rules` → `/dev/null`.
     - **Purpose:** This disables the udev rule that blocks GDM from using Wayland on NVIDIA GPUs.
     - **Risk Warning:** Displays a warning that this may break graphics or cause instability.
     - **Toggle Behavior:** If the symlink exists, removing it reverts to default behavior; if not present, creating it enables the override.

**Block 4 — SDDM Configuration**
- A submenu offers two options:
  1. Install SDDM (auto-selects via debconf).
  2. Enable Autologin:
     - **Session Detection:** Auto-detects the installed session by checking `.desktop` files in priority order: `plasmawayland` → `lxqt-wayland` → `plasma` → `lxqt`.
     - **Configuration:** Writes autologin settings to `/etc/sddm.conf.d/autologin.conf`.
     - **Fallback:** If no session is found, it enables autologin but warns that SDDM will use the default session.

**Block 5 — greetd Configuration**
- greetd is a minimal, modern display manager designed for Wayland environments.
- Submenu options vary by Debian version:
  - **All Versions:** Install base `greetd`, Install `greetd` + `tuigreet` (recommended TUI greeter).
  - **Debian 13 only:** Additional options to install `gtk-greet`, `nwg-hello`, or `wlgreet`.
- **Backports Handling:** On Bookworm, `tuigreet` is installed from backports if not enabled.
- **Important Warning:** greetd is installed but NOT configured by the script. The user must manually create `/etc/greetd/config.toml` to be able to log in. The script displays a warning with references to man pages for configuration details.

### 3. Smart Automations
The component utilizes several intelligent automation features:
- **debconf-set-selections:** Pre-selects the display manager as default before `apt install`, preventing the interactive "Configuring shared/default-x-display-manager" dialog that would otherwise pause the script execution.
- **Session Auto-Detection (SDDM):** Checks `.desktop` files in priority order (Wayland first, then X11) to set the correct session type for autologin configuration.
- **Wayland Toggle:** Creates or removes a udev rule symlink to `/dev/null`. This is a known workaround that disables the GDM rule blocking NVIDIA Wayland support.
- **greetd Backports:** On Bookworm, `tuigreet` is installed from backports (newer version) if not already enabled in the system.
- **Manual Config Warning:** The script explicitly informs users that greetd requires manual configuration and points to man pages for further details.
- **User Detection:** Uses `SUDO_USER` (the real user who ran sudo) instead of `$USER` (which is root during script execution). This ensures the correct user is set for automatic login across all display managers.

### 4. Packages and Resources Managed

**Display Manager Packages:**
| DM | Packages | Debian Versions |
|---|---|---|
| LightDM | lightdm, lightdm-gtk-greeter, lightdm-gtk-greeter-settings | All |
| GDM3 | gdm3 | All |
| SDDM | sddm | All |
| greetd (base) | greetd | 12, 13 |
| greetd + tuigreet | greetd, tuigreet | 12 (backports), 13 |
| greetd + gtk-greet | greetd, gtk-greet | 13 only |
| greetd + nwg-hello | greetd, nwg-hello | 13 only |
| greetd + wlgreet | greetd, wlgreet | 13 only |

**Configuration Files Modified:**
| DM | File Path | Configuration Purpose |
|---|---|---|
| LightDM | /etc/lightdm/lightdm.conf.d/50-debianito-userlist.conf | User list visibility toggle |
| LightDM | /etc/lightdm/lightdm.conf | Autologin user + timeout settings |
| GDM3 | /etc/gdm3/greeter.dconf-defaults | User list toggle (disable-user-list) |
| GDM3 | /etc/gdm3/daemon.conf | Autologin user and enable flag |
| GDM3 | /etc/udev/rules.d/61-gdm.rules | Wayland override (symlink to /dev/null) |
| SDDM | /etc/sddm.conf.d/autologin.conf | Autologin user + session type |

**Session Detection Priority (SDDM Autologin):**
| Priority | Session File | Session Type |
|---|---|---|
| 1 | /usr/share/wayland-sessions/plasmawayland.desktop | KDE Wayland |
| 2 | /usr/share/wayland-sessions/lxqt-wayland.desktop | LXQt Wayland |
| 3 | /usr/share/xsessions/plasma.desktop | KDE X11 |
| 4 | /usr/share/xsessions/lxqt.desktop | LXQt X11 |

> ⚠️ **Warning: Wayland on NVIDIA:** The "Force Enable Wayland on NVIDIA" option creates a symlink that disables the GDM udev rule. This is a known workaround but MAY cause graphics instability or breakage. To revert, remove `/etc/udev/rules.d/61-gdm.rules`.

> ⚠️ **Warning: greetd:** Unlike other display managers, greetd is installed but NOT configured by this script. You MUST manually create `/etc/greetd/config.toml` before you can log in. See `man greetd` and `man 5 greetd-sessions` for configuration details.

> ⚠️ **Warning: Autologin:** All autologin configurations use `SUDO_USER` (the user who ran sudo) instead of `$USER` (which is root during script execution). This ensures the correct user is set for automatic login.

> 💡 **Technical Note:** `debconf-set-selections` pre-selects the display manager before apt install, preventing the interactive "Configuring shared/default-x-display-manager" dialog that would otherwise pause the script.
