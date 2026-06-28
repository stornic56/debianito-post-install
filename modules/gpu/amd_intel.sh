#!/usr/bin/env bash
# AMD and Intel GPU firmware + tools

install_amd_firmware() {
    local fw_info
    fw_info=$(pkg_versions firmware-amd-graphics)
    if _confirm "AMD Firmware" "Install AMD GPU firmware?\n\n${fw_info}"; then
        _run_cmd "AMD" "sudo apt install -y firmware-amd-graphics" "Installing AMD GPU firmware..."
    fi
}

offer_amd_tools() {
    local amd_tools=("radeontop")
    local corectrl_available=false

    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        corectrl_available=true
    elif [ "$(is_backports_enabled)" = "true" ] && apt-cache madison corectrl 2>/dev/null | grep -q "bookworm-backports"; then
        corectrl_available=true
    fi

    local pkgs
    if [ "$DEBIAN_VERSION" = "11" ]; then
        pkgs=$(pkg_versions "${amd_tools[@]}" vainfo)
    else
        pkgs=$(pkg_versions "${amd_tools[@]}" nvtop vainfo)
    fi
    if $corectrl_available; then
        local ctrl_ver
        ctrl_ver=$(apt-cache policy corectrl 2>/dev/null | awk 'NR==3 {print $2; exit}')
        pkgs+="  - corectrl  ${ctrl_ver}\n"
    fi

    if ! _confirm "AMD Tools" "Install AMD monitoring and control tools?\n\n${pkgs}"; then
        echo "Skipping AMD tools."
        return
    fi

    if [ "$DEBIAN_VERSION" = "11" ]; then
        _run_cmd "AMD Tools" "sudo apt install -y ${amd_tools[*]} vainfo" "Installing AMD tools..."
    else
        _run_cmd "AMD Tools" "sudo apt install -y ${amd_tools[*]} nvtop vainfo" "Installing AMD tools..."
    fi
    vainfo
    _pause

    if $corectrl_available; then
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            _run_cmd "corectrl" "sudo apt install -y corectrl" "Installing corectrl..."
        else
            _run_cmd "corectrl" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports corectrl" "Installing corectrl from backports..."
        fi
    fi

    echo -e "${GREEN}AMD tools installed.${NC}"
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
        _run_cmd "Intel" "sudo apt install -y firmware-intel-graphics $va_driver" "Installing Intel GPU firmware..."
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
        _run_cmd "Intel Tools" "sudo apt install -y ${pkg_list[*]} vainfo" "Installing Intel monitoring tools..."
        vainfo
        _pause
    else
        echo "Skipping Intel monitoring tools."
    fi
}
