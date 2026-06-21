# Option 4: Advanced Firmware & Wireless Architecture

## 1. The Hidden Debian "Problem"
In standard Debian packaging, the meta-package `firmware-linux-nonfree` serves as a generic aggregator for hardware blobs. However, due to internal dependency resolution rules and conservative versioning strategies within the repository, this package often fails to automatically include vendor-specific firmware drivers for newer or niche network controllers (specifically Realtek Wi-Fi/Bluetooth and Intel Ethernet/Wi-Fi variants).

This script acts as an intelligent injector to bridge that gap. It does not rely solely on the meta-package's `Recommends` field; instead, it actively scans the hardware topology to identify missing dependencies. By decoupling the detection from the installation logic, the architecture ensures that even if the base package is installed, specific vendor blobs (e.g., `firmware-iwlwifi`, `firmware-realtek`) are explicitly pulled in only when their corresponding hardware IDs are confirmed present on the system. This prevents "half-baked" network connectivity where the interface exists but lacks the necessary firmware to initialize.

## 2. Dual Scan Engine (PCI & USB)
To ensure comprehensive hardware detection while minimizing false positives, the script utilizes a dual-scan engine that interrogates both PCI and USB buses with strict filtering logic:

*   **PCI Bus Scanning (`lspci`):** The engine parses `lspci -nn` output specifically targeting lines containing "network controller" or "ethernet controller". This captures both wireless adapters (e.g., Intel AX200) and wired NICs (e.g., Realtek RTL8125 2.5GbE), ensuring that Ethernet firmware requirements are also met during the process.
*   **USB Bus Scanning (`lsusb`):** The USB scan applies keyword filtering to ignore peripherals unrelated to networking, such as audio devices or card readers. It specifically looks for terms like "wireless", "wifi", "802.11", and "wlan". Bluetooth devices are also detected separately through `PCI_BT_DEVS` and `USB_BT_DEVS`.
*   **Deduplication:** The collected device lists are merged into a single array (`dev_list`) to prevent duplicate processing of the same hardware instance across different bus categories, ensuring a clean plan generation.

## 3. Dynamic Hardware Mapping Matrix
The script employs an associative mapping strategy in `_detect_firmware_needs` to translate raw vendor strings from `lspci`/`lsusb` into specific Debian package names. This matrix is critical for handling the "Intel Split" and other vendor-specific requirements:

*   **Vendor Filtering:** The engine first filters out generic or unsupported vendors (e.g., non-Realtek, non-Intel, non-Atheros) to avoid unnecessary package pulls.
*   **Package Assignment Logic:**
    *   **Intel Wi-Fi Hardware** ➔ `firmware-iwlwifi` (Specific driver for wireless chips).
    *   **Intel Ethernet Hardware** ➔ `firmware-intel-misc` (Often pulled via `Recommends` of the base package, but explicitly tracked here).
    *   **Realtek Hardware** ➔ `firmware-realtek`.
    *   **MediaTek / Ralink Hardware** ➔ `firmware-mediatek`.
    *   **Atheros / Qualcomm Hardware** ➔ `firmware-atheros`.

This mapping ensures that if a system contains an Intel Wi-Fi 6 card, the script explicitly queues `firmware-iwlwifi` regardless of whether the base meta-package claims to cover it. The output is rendered as a deduplicated plan with visual indicators (e.g., `[+] package ← hardware`) for user clarity.

## 4. Installation Execution Flow (Atomic Pipeline)
The installation process follows a strict atomic pipeline defined in `install_firmware`, ensuring system stability and version consistency:

1.  **Repository Validation:** The script first verifies that `/etc/apt/sources.list` or `.d/` contains the `non-free` component. If absent, it halts to prevent installation failures.
2.  **Plan Rendering & Confirmation:** A diagnostic tree is generated showing detected controllers and planned packages. The user must explicitly confirm ("Apply the network & firmware plan?") before proceeding.
3.  **Base Meta-Package Selection (Backports vs. Stable):**
    *   If `firmware-linux-nonfree` is already installed, the script checks for a newer version in backports (`${DEBIAN_CODENAME}-backports`). It prompts to upgrade if available, as backports often contain firmware for very recent hardware not yet in stable.
    *   If not installed, it presents a choice between Stable (Ultra-tested) and Backports (Recommended for modern hardware).
4.  **Sequential Injection:** After the base package is secured, the script iterates through `_DETECTED_FW_PKGS`. It uses `apt-cache policy` to validate availability before installing specific vendor packages (`firmware-realtek`, etc.), skipping those already present or unavailable in repositories.

## 5. Broadcom Redundancy System (3-Tier Support)
Broadcom chipsets require complex handling due to their mix of open-source and proprietary driver support. The `_handle_wireless` function implements a three-tier logic to maximize compatibility without breaking the kernel:

*   **Tier 1 (Open/Non-Free Direct):** For supported chips, it attempts to install `firmware-brcm80211`. This is preferred as it uses standard DKMS modules provided by Debian.
*   **Tier 2 (Firmware Emulation):** If Tier 1 fails or the chipset requires firmware emulation (e.g., older B43 chips), the script installs `firmware-b43-installer` or `firmware-b43legacy-installer`. This is a fallback for hardware that cannot be driven by standard kernel modules.
*   **Tier 3 (Proprietary DKMS):** For unsupported chipsets where open-source drivers are insufficient, the system falls back to compiling proprietary drivers (`broadcom-sta-dkms`). The script explicitly checks for `linux-headers` availability before attempting this compilation, as it requires kernel headers matching the running version. It warns the user that a reboot may be required after installation.

This tiered approach ensures that even if one method fails (e.g., proprietary driver compilation errors), the system attempts other supported methods to restore network functionality.

## 6. Bluetooth Stack Integration
Bluetooth support is handled through a dedicated module (`bluetooth.sh`) that integrates seamlessly with the firmware detection process:

*   **Hardware Detection:** The script identifies both PCI and USB Bluetooth controllers using `PCI_BT_DEVS` and `USB_BT_DEVS` arrays, ensuring comprehensive coverage of all Bluetooth hardware types.
*   **Base Stack Installation:** When Bluetooth hardware is detected, the system installs the core stack (`bluez`, `bluez-utils`, `bluez-obexd`) if not already present.
*   **Desktop Environment Optimization:** Based on the detected desktop environment:
    *   **KDE:** Installs `bluedevil` and optionally `pipewire-pulse` + `wireplumber` for Pipewire audio server integration.
    *   **GNOME:** Uses built-in GNOME Bluetooth support in `gnome-control-center`.
    *   **XFCE/Other:** Installs `blueman` as the GTK Bluetooth manager.
*   **Service Management:** The script ensures the Bluetooth service is enabled and started automatically on boot, with session restart or reboot recommendation for desktop applets to load properly.

This modular approach keeps Bluetooth handling separate from network firmware while maintaining tight integration through shared device detection arrays and coordinated installation flow.
