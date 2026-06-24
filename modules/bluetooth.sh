#!/usr/bin/env bash

# modules/bluetooth.sh
# Requires: modules/utils.sh (globals + helpers), modules/firmware.sh (PCI_BT_DEVS, USB_BT_DEVS, USB_WIFI_DEVS)

_install_bluetooth_stack() {
    local has_bt=false
    [ ${#PCI_BT_DEVS[@]} -gt 0 ] && has_bt=true
    [ ${#USB_BT_DEVS[@]} -gt 0 ] && has_bt=true
    if ! $has_bt; then
        for dev in "${USB_WIFI_DEVS[@]}"; do
            if echo "$dev" | grep -qi 'bluetooth'; then
                has_bt=true; break
            fi
        done
    fi
    if ! $has_bt; then
        echo "  → No Bluetooth hardware detected, skipping."
        return
    fi

    if is_installed bluez; then
        echo "  → Bluetooth stack already installed."
        service_enable_only=true
    fi

    if [ ! ${service_enable_only:-false} = true ]; then
        local bt_pkgs=()
        ! is_installed bluez       && bt_pkgs+=(bluez)
        ! is_installed bluez-tools  && bt_pkgs+=(bluez-tools)
        ! is_installed bluez-obexd  && bt_pkgs+=(bluez-obexd)
        if [ ${#bt_pkgs[@]} -gt 0 ]; then
            _run_cmd "Bluetooth" "sudo DEBIAN_FRONTEND=noninteractive apt install -y ${bt_pkgs[*]}" "Installing Bluetooth stack..."
        fi
    fi

    if command -v rfkill &>/dev/null; then
        if rfkill list bluetooth 2>/dev/null | grep -q "Soft blocked: yes"; then
            echo "  → Unblocking Bluetooth (rfkill)..."
            sudo rfkill unblock bluetooth
        fi
    fi

    case "${DESKTOP_ENV:-other}" in
        kde)
            if ! is_installed bluedevil; then
                _run_cmd "Bluetooth" "sudo DEBIAN_FRONTEND=noninteractive apt install -y bluedevil" "Installing bluedevil..."
            fi
            if [ "${AUDIO_SERVER:-}" = "pipewire" ]; then
                ! is_installed pipewire-pulse && _run_cmd "Bluetooth" "sudo DEBIAN_FRONTEND=noninteractive apt install -y pipewire-pulse" "Installing pipewire-pulse..."
                ! is_installed wireplumber && _run_cmd "Bluetooth" "sudo DEBIAN_FRONTEND=noninteractive apt install -y wireplumber" "Installing wireplumber..."
            fi
            ;;
        gnome)
            echo "  → GNOME Bluetooth support already in gnome-control-center."
            ;;
        xfce|other)
            if ! is_installed blueman; then
                _run_cmd "Bluetooth" "sudo DEBIAN_FRONTEND=noninteractive apt install -y blueman" "Installing blueman..."
            fi
            ;;
    esac

    if ! systemctl is-enabled bluetooth &>/dev/null 2>&1; then
        sudo systemctl enable bluetooth 2>/dev/null || true
    fi
    if ! systemctl is-active bluetooth &>/dev/null 2>&1; then
        sudo systemctl start bluetooth 2>/dev/null || true
    fi

    _msg "Bluetooth Setup" "Bluetooth stack installed.\n\nA session restart or reboot is\nrecommended to load the desktop\napplets and tray icons." 10 60
}
