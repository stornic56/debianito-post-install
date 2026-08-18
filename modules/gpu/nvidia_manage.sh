#!/usr/bin/env bash
# nvidia_manage.sh — NVIDIA management menu: install/change or remove

_nvidia_driver_installed() {
    dpkg -l 2>/dev/null | grep -qE "^ii  (nvidia-driver|nvidia-tesla-470-driver|nvidia-open|nvidia-kernel-dkms|nvidia-kernel-open-dkms|nvidia-open-kernel-dkms)"
}

_nvidia_manage_menu() {
    local choice
    choice=$(_menu "NVIDIA Driver" "Manage NVIDIA Driver" 12 70 4 \
        "1" "Install / Change NVIDIA Driver Version" \
        "2" "Remove NVIDIA Driver and Restore Nouveau")

    [ -z "$choice" ] && {
        echo "Skipping NVIDIA installation."
        return 1
    }

    case "$choice" in
        2)
            _nvidia_remove
            return 1
            ;;
        *) return 0 ;;
    esac
}

_nvidia_remove() {
    if ! _nvidia_driver_installed; then
        echo -e "${YELLOW}NVIDIA driver is not installed on this system.${NC}"
        return 0
    fi

    if ! _confirm "Remove NVIDIA" "This will:\n  - Purge the NVIDIA driver packages\n  - Remove script-generated configs\n  - Remove the CUDA repo sources\n  - Regenerate initramfs\n\nProceed?"; then
        echo "NVIDIA removal cancelled."
        return 0
    fi

    echo "Removing NVIDIA driver packages..."
    sudo apt purge -y nvidia-driver nvidia-kernel-dkms nvidia-open-kernel-dkms nvidia-open nvidia-kernel-open-dkms nvidia-tesla-470-driver nvidia-settings nvidia-vaapi-driver firmware-nvidia-gsp mesa-vdpau-drivers nvidia-driver-pinning-* || true

    echo "Cleaning up dependencies..."
    sudo apt autoremove --purge -y || true

    echo "Removing script-generated configuration..."
    sudo rm -f /etc/modprobe.d/nvidia-wayland.conf || true
    sudo rm -f /etc/modprobe.d/nvidia-open.conf || true
    sudo rm -f /etc/apt/preferences.d/block-nvidia || true
    sudo rm -f /etc/X11/xorg.conf.d/20-nvidia.conf || true

    echo "Removing NVIDIA repository sources..."
    sudo rm -f /etc/apt/sources.list.d/cuda-*.list || true
    sudo rm -f /etc/apt/sources.list.d/extrepo_nvidia-cuda.sources || true

    echo "Regenerating initramfs..."
    sudo update-initramfs -u || true

    echo -e "${GREEN}NVIDIA driver removed. Please reboot your system.${NC}"
    return 0
}
