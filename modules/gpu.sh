#!/usr/bin/env bash
# Detects and installs GPU firmwares for AMD, Intel, and NVIDIA

install_gpu_drivers() {
    case "$GPU_TYPE" in
        amd)    install_amd ;;
        intel)  install_intel ;;
        nvidia) install_nvidia ;;
        *)
            _msg "GPU" "No dedicated GPU detected.\n\nIf you are in a virtual machine, GPU acceleration\ndepends on VM configuration (SPICE, VirtIO).\n\nNo additional drivers will be installed." 12 60
            return
            ;;
    esac

    if [ "$GPU_TYPE" != "nvidia" ] && [ "$(is_backports_enabled)" == true ]; then
        local mesa_pkgs=""
        for mpkg in libgl1-mesa-dri mesa-vulkan-drivers; do
            local bpo_ver
            bpo_ver=$(apt-cache madison "$mpkg" 2>/dev/null | \
                grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
            if [ -n "$bpo_ver" ]; then
                mesa_pkgs+="  - ${mpkg}  ${bpo_ver} (backports)\n"
            else
                mesa_pkgs+="  - ${mpkg}  (from stable)\n"
            fi
        done
        if _confirm_custom "Mesa Backports" "Install Mesa?\n${mesa_pkgs}" "Backports" "Stable"; then
            _run_cmd "Mesa" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports libgl1-mesa-dri mesa-vulkan-drivers" "Installing Mesa from backports..."
        else
            _run_cmd "Mesa" "sudo apt install -y libgl1-mesa-dri mesa-vulkan-drivers" "Installing Mesa from stable..."
        fi
    fi

    local tool_pkgs
    tool_pkgs=$(pkg_versions nvtop vainfo)
    if _confirm "GPU Tools" "Install monitoring tools?\n${tool_pkgs}"; then
        _run_cmd "GPU Tools" "sudo apt install -y nvtop vainfo" "Installing GPU tools..."
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
    if ! _confirm "AMD GPU" "Install AMD drivers?\n${pkgs}"; then
        echo "Skipping AMD GPU drivers."
        return
    fi
    _run_cmd "AMD" "sudo apt install -y firmware-amd-graphics radeontop" "Installing AMD drivers..."
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
    if ! _confirm "Intel GPU" "Install Intel drivers?\n${pkgs}"; then
        echo "Skipping Intel GPU drivers."
        return
    fi

    _run_cmd "Intel" "sudo apt install -y firmware-intel-graphics" "Installing Intel firmware..."

    echo "Detected Intel GPU generation: $gen"
    echo "Installing ${va_driver}..."
    _run_cmd "Intel" "sudo apt install -y $va_driver" "Installing Intel VA driver..."

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

        if ! _confirm "NVIDIA + Backports" "Backports kernel (6.19+) may break NVIDIA driver.\nContinue with stable NVIDIA driver?"; then
            echo "Skipping NVIDIA driver installation."
            return 0
        fi
    fi

    _run_cmd "NVIDIA" "sudo apt install -y nvidia-detect" "Installing nvidia-detect..."

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
    if ! _confirm "NVIDIA Driver" "Install NVIDIA driver?\n${nv_pkgs}\nReboot required."; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    _run_cmd "NVIDIA" "sudo apt install -y $recommended firmware-misc-nonfree nvidia-vaapi-driver" "Installing NVIDIA driver..."
    echo -e "${GREEN}NVIDIA drivers installed. Reboot required.${NC}"
}
