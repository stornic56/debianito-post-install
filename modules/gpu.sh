#!/usr/bin/env bash
# Graphics Stack — sources submodules, provides AMD/Intel and NVIDIA top-level functions

_GPU_DIR="${MODULES_DIR}/gpu"
source "${_GPU_DIR}/_helpers.sh"
source "${_GPU_DIR}/amd_intel.sh"
source "${_GPU_DIR}/nvidia.sh"

# Consumed by gaming.sh to know which NVIDIA driver path was taken
NVIDIA_DRIVER_MODE=""

_install_amd_intel_stack() {
    if [ "$GPU_TYPE" = "unknown" ] || [ -z "$GPU_TYPE" ]; then
        local mesa_pkgs=(mesa-vulkan-drivers libgl1-mesa-dri libglx-mesa0 libegl-mesa0 mesa-va-drivers)
        local ref_ver
        ref_ver=$(apt-cache policy mesa-vulkan-drivers 2>/dev/null | awk 'NR==3 {print $2; exit}')
        local ref_bpo_ver
        ref_bpo_ver=$(apt-cache madison mesa-vulkan-drivers 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
        local comp_line="Components: Vulkan, OpenGL, GLX, EGL, VA-API (64-bit)"

        if [ -n "$ref_bpo_ver" ] && [ "$(is_backports_enabled)" == "true" ]; then
            local header="No dedicated GPU was detected (VM or headless).\n"
            header+="Install Mesa stack for compute / display acceleration?\n\n"
            header+="Source: Debian ${DEBIAN_CODENAME^}-Backports\n"
            header+="Mesa ${ref_bpo_ver}\n"
            header+="${comp_line}\n\n"
            header+="Choose version:"
            if _confirm_custom "No GPU Detected" "$header" "Backports" "Stable" 14 70; then
                local _bpo_list=()
                for _p in "${mesa_pkgs[@]}"; do
                    [ "$_p" != "mesa-va-drivers" ] && _bpo_list+=("$_p")
                done
                _run_cmd "Mesa" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${_bpo_list[*]}" \
                    "Installing Mesa from backports..."
            else
                _run_cmd "Mesa" "sudo apt install -y ${mesa_pkgs[*]}" \
                    "Installing Mesa from stable..."
            fi
        else
            if _confirm "No GPU Detected" \
                "No dedicated GPU was detected (VM or headless).\n\nInstall Mesa stack?\n\nSource: Debian Stable\nMesa ${ref_ver}\n${comp_line}" 14 70; then
                _run_cmd "Mesa" "sudo apt install -y ${mesa_pkgs[*]}" \
                    "Installing Mesa..."
            else
                echo "Skipping Mesa installation."
                offer_generic_tools
                return
            fi
        fi
        offer_generic_tools
        echo -e "${GREEN}Graphics stack setup complete.${NC}"
        return
    fi

    local plan="The script has detected your graphics hardware.\n\n"
    plan+="Detected GPUs:\n"
    local gpu_count=0
    while IFS= read -r gpu_line; do
        gpu_count=$((gpu_count + 1))
        local desc
        desc=$(echo "$gpu_line" | sed -E 's/.*: //; s/ *\(rev.*//')
        plan+="  GPU ${gpu_count}:  ${desc}\n"
    done < <(lspci -nn | grep -E "VGA|3D" || true)
    plan+="\nPlanned components:\n"
    if $HAS_INTEL; then
        local _gen; _gen=$(get_intel_generation)
        local _va;  [ "$_gen" = "gen7-" ] && _va="i965-va-driver-shaders" || _va="intel-media-va-driver-non-free"
        plan+="  [+] Intel firmware + ${_va}\n"
    fi
    if $HAS_AMD; then
        plan+="  [+] AMD firmware (firmware-amd-graphics)\n"
    fi
    plan+="  [+] Mesa (OpenGL/Vulkan/VA-API)\n"

    _msg "Graphics Stack — Plan" "$plan" 16 70

    if ! _confirm "Graphics Stack" "Install the planned components?"; then
        echo "Skipping Graphics Stack."
        return
    fi

    if $HAS_INTEL; then
        install_intel_firmware
    fi
    if $HAS_AMD; then
        install_amd_firmware
    fi

    _install_mesa_backports

    local mesa_ver
    mesa_ver=$(dpkg -l libgl1-mesa-dri 2>/dev/null | awk '/^ii/ {print $3; exit}' | sed 's/-.*//')
    [ -n "$mesa_ver" ] && GPU_VERSION="Mesa ${mesa_ver}"

    if $HAS_INTEL; then
        offer_intel_tools
    fi
    if $HAS_AMD; then
        offer_amd_tools
    fi
    if ! $HAS_INTEL && ! $HAS_AMD; then
        offer_generic_tools
    fi

    local summary="Mesa: ${GPU_VERSION:-not available}\n"
    summary+="Firmware: installed for detected GPUs\n"
    summary+="Tools: installed per vendor"
    _msg "Graphics Stack — Complete" "$summary" 12 65
}

_install_nvidia_stack() {
    if ! $HAS_NVIDIA; then
        _msg "NVIDIA Not Found" "No NVIDIA GPU was detected.\n\nPlease check your hardware and try again." 10 60
        return
    fi

    local plan="The script has detected your NVIDIA GPU.\n\n"
    plan+="Detected GPUs:\n"
    local gpu_count=0
    while IFS= read -r gpu_line; do
        gpu_count=$((gpu_count + 1))
        local desc
        desc=$(echo "$gpu_line" | sed -E 's/.*: //; s/ *\(rev.*//')
        plan+="  GPU ${gpu_count}:  ${desc}\n"
    done < <(lspci -nn | grep -E "VGA|3D" || true)
    plan+="\nPlanned:\n  [+] NVIDIA proprietary driver"

    _msg "NVIDIA Stack — Plan" "$plan" 14 65
    if ! _confirm "NVIDIA Stack" "Install the NVIDIA proprietary driver?"; then
        echo "Skipping NVIDIA driver installation."
        return
    fi

    NVIDIA_DRIVER_MODE=""

    if [ "$DEBIAN_VERSION" = "11" ]; then
        install_nvidia_bullseye

    elif [ "$DEBIAN_VERSION" = "12" ]; then
        if [ "$(is_nvidia_kepler)" = "true" ]; then
            if type _install_nvidia_bookworm_kepler &>/dev/null; then
                _install_nvidia_bookworm_kepler
            else
                _install_nvidia_standard
            fi
        elif [ "$(is_nvidia_fermi)" = "true" ]; then
            _msg "NVIDIA Fermi — Bookworm" \
                "Fermi GPUs (GF1xx) are not supported\nin Debian 12 (Bookworm).\nThe nvidia-legacy-390xx driver is\nnot available in this version.\n\nNo NVIDIA driver will be installed."
            NVIDIA_DRIVER_MODE=""
        elif [ "$(is_backports_kernel)" = "true" ]; then
            _install_nvidia_bookworm_bpo
        else
            _install_nvidia_standard
        fi

    elif [ "$DEBIAN_VERSION" = "13" ]; then
        if [ "$(is_nvidia_blackwell)" = "true" ]; then
            _install_nvidia_cuda_repo
        elif [ "$(is_nvidia_kepler)" = "true" ] || [ "$(is_nvidia_fermi)" = "true" ]; then
            _msg "NVIDIA — Trixie" \
                "Kepler and Fermi GPUs are not supported\nin Debian 13 (Trixie).\n\nThe nvidia-legacy drivers are not available\nin this version of Debian.\n\nNo NVIDIA driver will be installed."
            NVIDIA_DRIVER_MODE=""
        elif [ "$(is_backports_kernel)" = "true" ]; then
            if [ "$(is_nvidia_maxwell)" = "true" ] || [ "$(is_nvidia_pascal)" = "true" ]; then
                local gpu_gen="Maxwell"
                [ "$(is_nvidia_pascal)" = "true" ] && gpu_gen="Pascal"
                _msg "NVIDIA — Trixie + Backports" \
                    "INCOMPATIBILITY DETECTED: Your NVIDIA ${gpu_gen} GPU\n\
is NOT supported by the modern v590 driver.\n\n\
To run NVIDIA safely on Debian 13 (Trixie), you MUST use\n\
the official Debian v550 driver, which requires the\n\
standard STABLE Kernel.\n\n\
Forcing the stable driver path." 14 70
                _install_nvidia_standard
                NVIDIA_DRIVER_MODE="stable"
            else
                _install_nvidia_cuda_repo
            fi
        else
            _install_nvidia_standard
        fi

    else
        _install_nvidia_standard
    fi

    if [ -n "$NVIDIA_DRIVER_MODE" ]; then
        offer_generic_tools
        local summary="NVIDIA: ${NVIDIA_DRIVER_MODE}\n"
        summary+="Tools:  nvtop + vainfo"
        _msg "NVIDIA Stack — Complete" "$summary" 10 55
    fi
}
