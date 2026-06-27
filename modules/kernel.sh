#!/usr/bin/env bash
# kernel.sh

install_kernel_backports() {
    if [ "$(is_backports_enabled)" != "true" ]; then
        _msg "Kernel" "Backports repository is not enabled.\n\nUse option 3 (Configure repositories) to enable backports\nbefore installing the backports kernel."
        return 1
    fi

    local backports_kernel_ver
    backports_kernel_ver=$(get_backports_kernel_version)

    local msg="Install the latest kernel from backports?"
    if [ "$backports_kernel_ver" != "unknown" ]; then
        msg+="\n\nVersion: $backports_kernel_ver"
    fi
    msg+="\nOlder kernels remain available in GRUB."

    if [ "$GPU_TYPE" == "nvidia" ]; then
        msg+="\n\nWARNING: may break NVIDIA driver."
    fi

    if ! _confirm "Backports Kernel" "$msg"; then
        echo "Skipping kernel installation."
        return
    fi

    _run_cmd "Kernel" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports linux-image-amd64" "Installing kernel from backports..."
    echo -e "${GREEN}Kernel installed. Reboot to use it.${NC}"
    _pause
}
