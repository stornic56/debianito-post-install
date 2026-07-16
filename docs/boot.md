## Option 11: Boot Rescue & Repair

### 1. What does this component do?
This component serves as a comprehensive rescue toolkit designed to diagnose and fix boot-related issues on Debian systems, specifically targeting GRUB configuration, UEFI Secure Boot integrity, and initrd image validity. It provides three primary operations: configuring the GRUB boot menu behavior (including timeout adjustments and visibility settings), repairing UEFI Secure Boot by reinstalling signed bootloader packages after kernel or driver changes, and regenerating initramfs images to resolve missing driver errors. All modifications are protected by automatic backup creation before system files are altered, with built-in rollback mechanisms that restore the original state if any operation fails during execution.

### 2. Logical Execution Flow

**Block 1 — GRUB Boot Menu Settings**
- **Menu Options:** Users select from four presets or a custom option to control boot behavior:
    1. Hide GRUB menu entirely (Fastest boot, requires holding ESC during power-on).
    2. Show 3-second countdown (Faster boot).
    3. Show menu for 5 seconds (Default behavior).
    4. Custom timeout (User inputs specific seconds; -1 allows indefinite wait).
- **Variable Application:** Each selection updates three core variables: `GRUB_TIMEOUT`, `GRUB_TIMEOUT_STYLE`, and `GRUB_RECORDFAIL_TIMEOUT`. The custom option also allows setting `GRUB_DISABLE_OS_PROBER` to prevent extra entries.
- **Backup & Safety:** Before applying changes, the script creates a timestamped backup of `/etc/default/grub`. It writes an override configuration file at `/etc/default/grub.d/99_script_override.cfg` to ensure settings persist across updates.
- **Execution & Rollback:** The system runs `update-grub` to apply changes. If this command fails, the script automatically restores the timestamped backup and removes the override file to prevent boot issues.

**Block 2 — UEFI Secure Boot Repair**
- **Pre-checks:** Before proceeding, the script verifies two conditions:
    1. The system is running in UEFI mode (checks for existence of `/sys/firmware/efi`).
    2. Secure Boot is currently enabled (uses `mokutil --sb-state` to confirm status).
- **Skip Logic:** If either check fails, the process stops immediately with a message indicating no repair is needed or applicable.
- **Repair Steps:** Upon user confirmation:
    1. Reinstalls signed boot packages (`shim-signed`, `grub-efi-amd64-signed`, `linux-image-amd64`).
    2. Reinstalls GRUB to the EFI partition using `grub-install` with the appropriate target and directory detection (preferring `/boot/efi` over `/boot`).
    3. Regenerates the GRUB configuration via `update-grub`.

**Block 3 — Initramfs Regeneration**
- **Confirmation:** The script prompts for user confirmation before proceeding to avoid unintended rebuilds.
- **Execution:** Upon approval, it runs `update-initramfs -u -k all` to regenerate initrd images for all installed kernels.
- **Purpose:** This fixes boot issues caused by missing drivers or corrupted initrd images that prevent the system from loading properly.

### 3. Intelligent Automation

- **EFI Directory Detection:** The script intelligently detects the EFI partition, checking `/boot/efi` first and falling back to `/boot` if necessary.
- **Secure Boot State Verification:** Instead of assuming Secure Boot is active, it uses `mokutil --sb-state` to verify the actual state before attempting repairs on non-UEFI or disabled systems.
- **GRUB Backup Strategy:** A timestamped backup file (e.g., `/etc/default/grub.backup.YYYYMMDD_HHMMSS`) is created prior to any modification, ensuring a safe point for rollback.
- **Rollback Mechanism:** If `update-grub` fails during the GRUB settings or Secure Boot repair process, the script automatically restores the backup and cleans up temporary override files.
- **Override Persistence:** Configuration values are written to `/etc/default/grub.d/99_script_override.cfg`, ensuring that changes survive package updates which might otherwise reset `/etc/default/grub`.
- **Input Validation:** Custom timeout inputs are validated using regex matching for integers (e.g., `^-?[0-9]+$`), allowing negative numbers like -1 while rejecting invalid text.
- **Variable Handling Logic:** The `_set_grub_var()` function handles three distinct cases: updating an existing variable, uncommenting a commented variable, or appending a new variable if it does not exist in the configuration file.

### 4. Paquetes y Recursos Gestionados

**Boot Packages Reinstalled (Secure Boot Repair):**
| Package | Purpose |
|---|---|
| shim-signed | UEFI Secure Boot shim (first-stage bootloader) |
| grub-efi-amd64-signed | Signed GRUB for UEFI |
| linux-image-amd64 | Kernel image (re-signed) |

**GRUB Settings Modified:**
| Variable | Option 1 | Option 2 | Option 3 | Custom |
|---|---|---|---|---|
| GRUB_TIMEOUT | 0 | 3 | 5 | User value |
| GRUB_TIMEOUT_STYLE | hidden | menu | menu | menu |
| GRUB_RECORDFAIL_TIMEOUT | 0 | 3 | 5 | User value |
| GRUB_DISABLE_OS_PROBER | true | — | — | — |

**System Files Modified:**
| Package | Purpose |
|---|---|
| /etc/default/grub | Main GRUB configuration |
| /etc/default/grub.d/99_script_override.cfg | Persistent override (survives grub updates) |
| /etc/default/grub.backup.* | Timestamped backup (auto-created) |

>**Note UEFI:** The Secure Boot repair ONLY works on UEFI systems. The script checks for `/sys/firmware/efi` and `mokutil --sb-state` before attempting anything. Legacy BIOS systems are automatically skipped.

>**Note GRUB:** After hiding the GRUB menu (Option 1), you must hold ESC immediately after powering on to access the menu. There is no other way to reach it during boot.

> **Technical data:** The override file at `/etc/default/grub.d/99_script_override.cfg` persists across kernel updates because GRUB reads drop-in configs from that directory. This is more reliable than editing `/etc/default/grub` directly for values that should survive updates.

> **Technical data:** `GRUB_DISABLE_OS_PROBER=true` is set when hiding the menu to prevent OS prober from adding extra entries that would require the menu to appear. For multi-boot systems, use Option 3 or Custom instead.
