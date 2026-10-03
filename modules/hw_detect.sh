#!/usr/bin/env bash
# hw_detect.sh — Shared hardware device detection (PCI + USB)
# License GPL v3

# ── Global arrays (populated by _detect_all_network_devices) ──
PCI_NET_DEVS=()
USB_WIFI_DEVS=()
PCI_BT_DEVS=()
USB_BT_DEVS=()
_FW_PLAN_HW_LINES=()

# ── Network device detection (PCI + USB) ──
_detect_all_network_devices() {
    ! is_installed pciutils && _install_pkg pciutils
    ! is_installed usbutils && _install_pkg usbutils

    PCI_NET_DEVS=()
    while IFS= read -r line; do
        PCI_NET_DEVS+=("$line")
    done < <(echo "$LSPCI_OUTPUT" | grep -iE 'network controller|ethernet controller' || true)

    USB_WIFI_DEVS=()
    while IFS= read -r line; do
        # Exclude Bluetooth dongles: many report e.g. "Bluetooth wireless
        # interface" and would otherwise be classified as WiFi and mapped
        # to firmware-iwlwifi.
        if echo "$line" | grep -qiE 'wireless|wifi|802\.11|wlan' &&
            ! echo "$line" | grep -qi 'bluetooth'; then
            USB_WIFI_DEVS+=("$line")
        fi
    done < <(lsusb 2>/dev/null || true)

    PCI_BT_DEVS=()
    while IFS= read -r line; do
        PCI_BT_DEVS+=("$line")
    done < <(echo "$LSPCI_OUTPUT" | grep -i 'Bluetooth controller' || true)

    USB_BT_DEVS=()
    while IFS= read -r line; do
        # All Bluetooth dongles belong here (the WiFi filter above now
        # excludes anything containing "bluetooth").
        if echo "$line" | grep -qi 'bluetooth'; then
            USB_BT_DEVS+=("$line")
        fi
    done < <(lsusb 2>/dev/null || true)

    _FW_PLAN_HW_LINES=()
    for dev in "${PCI_NET_DEVS[@]}"; do
        local desc dev_type
        desc=$(echo "$dev" | sed -E 's/^[^ ]+ [^:]+: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev.*\)//')
        if echo "$dev" | grep -qiE 'network controller|wireless|wi-fi|wlan|802\.11'; then
            dev_type="WiFi PCI"
        else
            dev_type="Ethernet PCI"
        fi
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (${dev_type})")
    done
    for dev in "${USB_WIFI_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed 's/^.*ID //')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (USB)")
    done

    for dev in "${PCI_BT_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed -E 's/^[^ ]+ [^:]+: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev.*\)//')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (Bluetooth PCI)")
    done
    for dev in "${USB_BT_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed 's/^.*ID //')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (Bluetooth USB)")
    done
}
