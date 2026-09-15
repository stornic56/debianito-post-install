#!/usr/bin/env bash
# AMD and Intel GPU firmware + tools

install_amd_firmware() {
    local fw_info
    fw_info=$(pkg_versions firmware-amd-graphics)
    if _confirm "AMD Firmware" "Install AMD GPU firmware?\n\n${fw_info}"; then
        if ! _run_cmd "AMD" "sudo apt install -y firmware-amd-graphics" "Installing AMD GPU firmware..."; then
            _msg_red "AMD Firmware" "Failed to install AMD GPU firmware."
        fi
    fi
}

offer_amd_tools() {
    local amd_tools=("radeontop")

    local pkgs
    if [ "$DEBIAN_VERSION" = "11" ]; then
        pkgs=$(pkg_versions "${amd_tools[@]}" vainfo)
    else
        pkgs=$(pkg_versions "${amd_tools[@]}" nvtop vainfo)
    fi

    if ! _confirm "AMD Tools" "Install AMD monitoring tools?\n\n${pkgs}"; then
        echo "Skipping AMD tools."
        return
    fi

    local tools_failed=false
    if [ "$DEBIAN_VERSION" = "11" ]; then
        if ! _run_cmd "AMD Tools" "sudo apt install -y ${amd_tools[*]} vainfo" "Installing AMD tools..."; then
            _msg_red "AMD Tools" "Failed to install AMD monitoring tools."
            tools_failed=true
        fi
    else
        if ! _run_cmd "AMD Tools" "sudo apt install -y ${amd_tools[*]} nvtop vainfo" "Installing AMD tools..."; then
            _msg_red "AMD Tools" "Failed to install AMD monitoring tools."
            tools_failed=true
        fi
    fi
    if command -v vainfo &>/dev/null; then
        vainfo
        _pause "vainfo output shown above."
    else
        echo -e "${YELLOW}vainfo not available, skipping report.${NC}"
    fi

    if $tools_failed; then
        echo -e "${RED}AMD tools installation failed.${NC}"
    else
        echo -e "${GREEN}AMD tools installed.${NC}"
    fi
}

install_intel_firmware() {
    local gen
    gen=$(get_intel_generation)
    local va_driver
    if [ "$gen" = "gen7-" ]; then
        va_driver="i965-va-driver-shaders"
    else
        va_driver="intel-media-va-driver-non-free"
    fi

    local fw_info
    fw_info=$(pkg_versions firmware-intel-graphics "$va_driver")
    if _confirm "Intel Firmware" "Install Intel GPU firmware?\n\n${fw_info}"; then
        if ! _run_cmd "Intel" "sudo apt install -y firmware-intel-graphics $va_driver" "Installing Intel GPU firmware..."; then
            _msg_red "Intel Firmware" "Failed to install Intel GPU firmware."
        fi
    fi
}

offer_intel_tools() {
    local driver_info=""
    local has_xe=false
    local has_i915=false
    local pkg_list=()
    local pkg_info=""

    [ -d "/sys/bus/pci/drivers/xe" ]   && has_xe=true
    [ -d "/sys/bus/pci/drivers/i915" ] && has_i915=true

    if [ "$DEBIAN_VERSION" = "11" ]; then
        if $has_xe; then
            echo "Intel Xe GPU detected. No monitoring tools available on Bullseye."
            return
        elif $has_i915; then
            driver_info="Classic Intel GPU detected (i915 driver)."
            pkg_list=("intel-gpu-tools")
        else
            echo "Intel GPU driver not identified. No monitoring tools available on Bullseye."
            return
        fi
    elif $has_xe; then
        driver_info="Modern Intel GPU detected (Xe driver).\nintel-gpu-tools is NOT compatible with Xe.\nOnly nvtop will be offered."
        pkg_list=("nvtop")
    elif $has_i915; then
        driver_info="Classic Intel GPU detected (i915 driver).\nintel-gpu-tools is compatible and will be offered."
        pkg_list=("intel-gpu-tools" "nvtop")
    else
        driver_info="Intel GPU driver not identified.\nOffering nvtop as a safe default."
        pkg_list=("nvtop")
    fi

    pkg_info=$(pkg_versions "${pkg_list[@]}" vainfo)

    if _confirm "Intel Tools" "Intel GPU monitoring tools\n\n${driver_info}\n\nPackages:\n${pkg_info}"; then
        local intel_failed=false
        if ! _run_cmd "Intel Tools" "sudo apt install -y ${pkg_list[*]} vainfo" "Installing Intel monitoring tools..."; then
            _msg_red "Intel Tools" "Failed to install Intel monitoring tools."
            intel_failed=true
        fi
        if command -v vainfo &>/dev/null; then
            vainfo
            _pause "vainfo output shown above."
        else
            echo -e "${YELLOW}vainfo not available, skipping report.${NC}"
        fi
        if $intel_failed; then
            echo -e "${RED}Intel monitoring tools installation failed.${NC}"
        fi
    else
        echo "Skipping Intel monitoring tools."
    fi
}
