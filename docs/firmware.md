# Option 5: Firmware, Wireless & Bluetooth

## 1. The Hidden Debian "Problem"

In standard Debian packaging, the meta-package `firmware-linux-nonfree` serves as a generic aggregator for hardware blobs. However, due to internal dependency resolution rules and conservative versioning strategies within the repository, this package often fails to automatically include vendor-specific firmware drivers for newer or niche network controllers (specifically Realtek Wi-Fi/Bluetooth and Intel Ethernet/Wi-Fi variants).

This script acts as an intelligent injector to bridge that gap. It does not rely solely on the meta-package's `Recommends` field; instead, it actively scans the hardware topology to identify missing dependencies. By decoupling the detection from the installation logic, the architecture ensures that even if the base package is installed, specific vendor blobs (e.g., `firmware-iwlwifi`, `firmware-realtek`) are explicitly pulled in only when their corresponding hardware IDs are confirmed present on the system. This prevents "half-baked" network connectivity where the interface exists but lacks the necessary firmware to initialize.

## 2. Dual Scan Engine (PCI & USB)

To ensure comprehensive hardware detection while minimizing false positives, the script utilizes a dual-scan engine that interrogates both PCI and USB buses with strict filtering logic:

* **PCI Bus Scanning (`lspci`):** The engine parses `lspci -nn` output specifically targeting lines containing "network controller" or "ethernet controller". This captures both wireless adapters (e.g., Intel AX200) and wired NICs (e.g., Realtek RTL8125 2.5GbE), ensuring that Ethernet firmware requirements are also met during the process.
* **USB Bus Scanning (`lsusb`):** The USB scan applies keyword filtering to ignore peripherals unrelated to networking, such as audio devices or card readers. It specifically looks for terms like "wireless", "wifi", "802.11", and "wlan". Bluetooth devices are also detected separately through `PCI_BT_DEVS` and `USB_BT_DEVS`.
* **Deduplication:** The collected device lists are merged into a single array (`dev_list`) to prevent duplicate processing of the same hardware instance across different bus categories, ensuring a clean plan generation.

## 3. Dynamic Hardware Mapping Matrix

The script employs an associative mapping strategy in `_detect_firmware_needs` to translate raw vendor strings from `lspci`/`lsusb` into specific Debian package names. This matrix is critical for handling the "Intel Split" and other vendor-specific requirements:

* **Vendor Filtering:** The engine first filters out generic or unsupported vendors (e.g., non-Realtek, non-Intel, non-Atheros) to avoid unnecessary package pulls.
* **Package Assignment Logic:**
  * **Intel Wi-Fi Hardware** ➔ `firmware-iwlwifi` (Specific driver for wireless chips).
  * **Intel Ethernet Hardware** ➔ `firmware-intel-misc` (Often pulled via `Recommends` of the base package, but explicitly tracked here).
  * **Realtek Hardware** ➔ `firmware-realtek`.
  * **MediaTek / Ralink Hardware** ➔ `firmware-mediatek`.
  * **Atheros / Qualcomm Hardware** ➔ `firmware-atheros`.

This mapping ensures that if a system contains an Intel Wi-Fi 6 card, the script explicitly queues `firmware-iwlwifi` regardless of whether the base meta-package claims to cover it. The output is rendered as a deduplicated plan with visual indicators (e.g., `[+] package ← hardware`) for user clarity.

## 4. Installation Execution Flow (Atomic Pipeline)

The installation process follows a strict atomic pipeline defined in `install_firmware`, ensuring system stability and version consistency:

1. **Repository Validation:** The script first verifies that `/etc/apt/sources.list` or `.d/` contains the `non-free` component. If absent, it halts to prevent installation failures.
2. **Plan Rendering & Confirmation:** A diagnostic tree is generated showing detected controllers and planned packages. The user must explicitly confirm ("Apply the network & firmware plan?") before proceeding.
3. **Base Meta-Package Selection (Backports vs. Stable):**
    * If `firmware-linux-nonfree` is already installed, the script checks for a newer version in backports (`${DEBIAN_CODENAME}-backports`). It prompts to upgrade if available, as backports often contain firmware for very recent hardware not yet in stable.
    * If not installed, it presents a choice between Stable (Ultra-tested) and Backports (Recommended for modern hardware).
4. **Sequential Injection:** After the base package is secured, the script iterates through `_DETECTED_FW_PKGS`. It uses `apt-cache policy` to validate availability before installing specific vendor packages (`firmware-realtek`, etc.), skipping those already present or unavailable in repositories.

## 5. Broadcom Wireless Support (DKMS Single-Path)

Broadcom chipsets require proprietary handling because no open-source driver covers most `14e4:*` devices on modern kernels. The current implementation in `firmware.sh:_handle_wireless` uses a **single-path DKMS flow** (`broadcom-sta-dkms` + `wl` module) — not a 3-tier fallback:

1. **Device detection** — Iterates `PCI_NET_DEVS` (parsed from `lspci -nn` at startup) and extracts the Broadcom ID `14e4:XXXX`. Non-Broadcom devices are skipped.
2. **Dependency guard** — Verifies `linux-headers-amd64` and `dkms` are available via `apt-cache show`. If missing, shows: `"linux-headers-amd64 or dkms are not available in your repositories."`
3. **User confirmation** — `whiptail --yesno "Install broadcom-sta-dkms, dkms, and wireless-tools?"`
4. **Step-by-step install** (allows partial failure without aborting the whole module):

   ```bash
   _run_cmd "Broadcom Dependencies" "sudo DEBIAN_FRONTEND=noninteractive apt install -y dkms wireless-tools linux-headers-amd64" || true
   _run_cmd "Broadcom Driver" "sudo DEBIAN_FRONTEND=noninteractive apt install -y broadcom-sta-dkms" || true
   ```

5. **Blacklist persistence** — Writes `/etc/modprobe.d/blacklist-broadcom.conf`:

   ```
   blacklist b43
   blacklist b43legacy
   blacklist brcmsmac
   blacklist bcma
   blacklist ssb
   ```

6. **SSH Warning + Module Switch** — Before unloading current WiFi modules, the script warns about SSH disconnection. Then removes conflicting modules and loads the Broadcom driver:

   ```bash
   _msg "Network Warning" "The script is about to unload current WiFi kernel modules to load the Broadcom driver.

If you are connected via SSH over WiFi, YOUR CONNECTION WILL DROP. Please reconnect after a few seconds."
   _run_cmd "Modprobe" "sudo modprobe -r b43 b43legacy b44 bcma brcmsmac brcmfmac ssb wl 2>/dev/null || true" || true
   _run_cmd "Modprobe" "sudo modprobe wl" || true

   ```

7. **Initramfs** — Rebuilds the initramfs to include the new `wl` module:

   ```bash
   _run_cmd "Initramfs" "sudo update-initramfs -u" || true
   ```

1. **Combo BT handling** — If a Broadcom Bluetooth device is also present (`PCI_BT_DEVS` grep `broadcom`), writes `softdep wl post: btusb` to `/etc/modprobe.d/broadcom-combo.conf`

2. **Post-DKMS verification** — Checks for `/lib/modules/$(uname -r)/updates/dkms/wl.ko*`. If missing, shows the last 20 lines of `dmesg` and offers `dpkg-reconfigure broadcom-sta-dkms`. On success, verifies `lsmod | grep ^wl` and reports `Broadcom WiFi activated (wl module loaded)` or `driver installed but wl module did not load — reboot required`.

USB Broadcom (`0a5c` vendor, `lsusb`) is detected but **not auto-installed** — the script shows a message that Linux lacks native drivers for most USB Broadcom WiFi chips and that `ndiswrapper` may be needed.

> **Historical note:** Earlier drafts of this document described a 3-tier system (`firmware-brcm80211` → `firmware-b43-installer` → `broadcom-sta-dkms`). The current script has consolidated to the DKMS path only. The other firmware packages are still available via the base `firmware-linux-nonfree` metapackage and vendor-specific packages (`firmware-realtek`, etc.).

## 6. Bluetooth Stack Integration

Bluetooth support is handled through a dedicated module (`bluetooth.sh`) that integrates seamlessly with the firmware detection process:

* **Hardware Detection:** The script identifies both PCI and USB Bluetooth controllers using `PCI_BT_DEVS` and `USB_BT_DEVS` arrays, ensuring comprehensive coverage of all Bluetooth hardware types.
* **Base Stack Installation:** When Bluetooth hardware is detected, the system installs the core stack (`bluez`, `bluez-utils`, `bluez-obexd`) if not already present.
* **Desktop Environment Optimization:** Based on the detected desktop environment:
  * **KDE:** Installs `bluedevil` and optionally `pipewire-pulse` + `wireplumber` for Pipewire audio server integration.
  * **GNOME:** Uses built-in GNOME Bluetooth support in `gnome-control-center`.
  * **XFCE/Other:** Installs `blueman` as the GTK Bluetooth manager.
* **Service Management:** The script ensures the Bluetooth service is enabled and started automatically on boot, with session restart or reboot recommendation for desktop applets to load properly.

This modular approach keeps Bluetooth handling separate from network firmware while maintaining tight integration through shared device detection arrays and coordinated installation flow.
