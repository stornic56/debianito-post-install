#!/usr/bin/env bash
# Detects and installs GPU firmwares for AMD, Intel, and NVIDIA

install_gpu_drivers() {
    case "$GPU_TYPE" in
        amd)    install_amd ;;
        intel)  install_intel ;;
        nvidia) install_nvidia ;;
        *)
            echo -e "${YELLOW}No supported GPU detected or unknown GPU type.${NC}"
            echo "You can install GPU drivers manually later."
            return
            ;;
    esac

    local tool_pkgs
    tool_pkgs=$(pkg_versions nvtop vainfo)
    if whiptail --title "GPU Tools" --yesno \
        "Install the following packages?\n\n${tool_pkgs}\nProceed?" 14 65; then
        sudo apt install -y nvtop vainfo
        echo ""
        vainfo
    else
        echo "Skipping GPU monitoring tools."
    fi
    echo -e "${GREEN}GPU setup complete.${NC}"
}

# ----------------------------------------------------------------------
# AMD GPU
# ----------------------------------------------------------------------
install_amd() {
    local pkgs
    pkgs=$(pkg_versions firmware-amd-graphics radeontop)
    if ! whiptail --title "AMD GPU" --yesno \
        "Install the following packages?\n\n${pkgs}\nProceed?" 14 65; then
        echo "Skipping AMD GPU drivers."
        return
    fi
    echo -e "${YELLOW}Installing AMD GPU drivers and firmware...${NC}"
    sudo apt install -y firmware-amd-graphics radeontop
    echo -e "${GREEN}AMD drivers installed.${NC}"
}

# ----------------------------------------------------------------------
# Intel GPU
# ----------------------------------------------------------------------
install_intel() {
    local gen
    gen=$(get_intel_generation)
    local va_driver
    if [ "$gen" = "gen7-" ]; then
        va_driver="i965-va-driver-shaders"
    else
        va_driver="intel-media-va-driver-non-free"
    fi

    local pkgs
    pkgs=$(pkg_versions firmware-intel-graphics "$va_driver")
    if ! whiptail --title "Intel GPU" --yesno \
        "Install the following packages?\n\n${pkgs}\nProceed?" 14 65; then
        echo "Skipping Intel GPU drivers."
        return
    fi

    echo -e "${YELLOW}Installing Intel GPU firmware and drivers...${NC}"

    sudo apt install -y firmware-intel-graphics

    echo "Detected Intel GPU generation: $gen"
    echo "Installing ${va_driver}..."
    sudo apt install -y "$va_driver"

    echo -e "${GREEN}Intel GPU drivers installed.${NC}"
}

# ----------------------------------------------------------------------
# NVIDIA GPU
# ----------------------------------------------------------------------
install_nvidia() {
    echo -e "${YELLOW}NVIDIA GPU detected.${NC}"

    # --- WARNING CHECK: Backports vs NVIDIA ---
    if [ "$(is_backports_enabled)" == true ]; then
        echo -e "${YELLOW}============================================${NC}"
        echo -e "${YELLOW}  IMPORTANT: Backports are currently enabled${NC}"
        echo -e "${YELLOW}============================================${NC}"
        echo ""
        echo "If you are using a backports kernel (e.g., 6.19+), the NVIDIA"
        echo "driver (especially the 550 series on Debian Trixie) may fail to"
        echo "compile via DKMS due to kernel incompatibilities."
        echo ""
        echo "We strongly recommend using the stable Debian kernel with the"
        echo "NVIDIA driver. The script will now install the recommended driver"
        echo "from the STABLE repositories only, NOT from backports."

        if ! whiptail --title "NVIDIA + Backports Warning" \
            --yesno "You have backports enabled.\n\nThere is a known conflict between backports kernels (6.19+) and the NVIDIA driver.\n\nDo you want to continue using the stable NVIDIA driver?\n\n(Choose No to skip NVIDIA installation)" 15 70; then
            echo "Skipping NVIDIA driver installation."
            return 0
        fi
    fi

    # Install nvidia-detect
    echo "Installing nvidia-detect..."
    sudo apt install -y nvidia-detect

    # Run nvidia-detect and parse the recommended package
    echo "Detecting recommended NVIDIA driver..."
    local recommended
    recommended=$(nvidia-detect 2>/dev/null | grep -oP 'nvidia[\w-]+(?= package)')

    if [ -z "$recommended" ]; then
        echo -e "${RED}nvidia-detect could not determine a suitable driver.${NC}"
        echo "Your GPU may not be supported by current Debian packages."
        return 1
    fi

    echo "Recommended driver package: $recommended"

    # --- CHECK FOR UNSUPPORTED LEGACY DRIVERS ---
    if [[ "$recommended" =~ tesla-470|legacy-390|legacy-340 ]]; then
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            echo -e "${RED}============================================${NC}"
            echo -e "${RED}  NVIDIA DRIVER NOT AVAILABLE${NC}"
            echo -e "${RED}============================================${NC}"
            echo ""
            echo "Your GPU requires the $recommended driver, which is not available"
            echo "in Debian 13 (Trixie)."
            echo ""
            echo "Options:"
            echo "  1. Install Debian 12 (Bookworm) where $recommended is still available"
            echo "  2. Use Debian Sid (Unstable) which may still provide $recommended"
            echo "  3. Use the open-source Nouveau driver (limited performance)"
            echo ""
            echo "No driver will be installed."
            return 1
        else
            if [[ "$recommended" =~ legacy-390|legacy-340 ]]; then
                echo -e "${RED}Your GPU requires $recommended, which is not available.${NC}"
                echo "No driver will be installed."
                return 1
            fi
        fi
    fi

    local nv_pkgs
    nv_pkgs=$(pkg_versions "$recommended" firmware-misc-nonfree nvidia-vaapi-driver)
    if ! whiptail --title "NVIDIA Driver" --yesno \
        "Install the following packages?\n\n${nv_pkgs}\nA reboot will be required.\n\nProceed?" 14 65; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    sudo apt install -y "$recommended" firmware-misc-nonfree nvidia-vaapi-driver

    echo -e "${GREEN}NVIDIA drivers installed.${NC}"
    echo "A reboot is required to load the NVIDIA kernel module."
    echo "After reboot, run 'nvidia-smi' to verify the installation."
}
