#!/usr/bin/env bash
# kernel.sh

install_kernel_backports() {
    echo -e "${YELLOW}Kernel from Backports${NC}"

    # Check if backports are enabled at system level
    if [ "$(is_backports_enabled)" != "true" ]; then
        echo -e "${YELLOW}Backports repository is not enabled.${NC}"
        echo "Use option 2 (Configure repositories) to enable backports first."
        return 1
    fi

    local backports_kernel_ver
    backports_kernel_ver=$(get_backports_kernel_version)

    echo "This will install the latest stable kernel from backports."
    echo " - Newer hardware support"
    echo " - Potential performance improvements"
    if [ "$backports_kernel_ver" != "unknown" ]; then
        echo " - Kernel version available: $backports_kernel_ver"
    else
        echo " - Kernel version could not be determined at this time"
    fi
    echo ""

    # Extra warning if NVIDIA GPU is detected
    if [ "$GPU_TYPE" == "nvidia" ]; then
        echo -e "${RED}============================================${NC}"
        echo -e "${RED}  WARNING: NVIDIA GPU detected${NC}"
        echo -e "${RED}============================================${NC}"
        echo "Backports kernels (6.19+) can break the NVIDIA 550 driver."
        echo "If you installed the NVIDIA driver earlier, this may cause"
        echo "display issues or DKMS compilation failures."
        echo ""
    fi

    # Build the whiptail message dynamically
    local msg
    msg="Do you want to install the latest kernel from backports?\n\n"
    if [ "$backports_kernel_ver" != "unknown" ]; then
        msg+="Kernel version: $backports_kernel_ver\n\n"
    fi
    msg+="This replaces the current linux-image-amd64 metapackage.\n"
    msg+="You can still boot older kernels from GRUB.\n"

    if [ "$GPU_TYPE" == "nvidia" ]; then
        msg+="\n WARNING: NVIDIA GPU detected.\n"
        msg+="Backports kernels (6.19+) may break the NVIDIA 550 driver.\n"
    fi

    if ! whiptail --title "Install Kernel from Backports" \
        --yesno "$msg" 16 70; then
        echo "Skipping kernel installation."
        return
    fi

    echo "Installing kernel from backports..."
    sudo apt install -y -t "${DEBIAN_CODENAME}-backports" linux-image-amd64

    echo -e "${GREEN}Kernel from backports installed.${NC}"
    echo "Please reboot to use the new kernel."
}
