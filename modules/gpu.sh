#!/usr/bin/env bash
# Graphics Stack — sources submodules and provides install_gpu_drivers()

_GPU_DIR="${MODULES_DIR}/gpu"
source "${_GPU_DIR}/_helpers.sh"
source "${_GPU_DIR}/amd_intel.sh"
source "${_GPU_DIR}/nvidia.sh"

# Consumed by gaming.sh to know which NVIDIA driver path was taken
NVIDIA_DRIVER_MODE=""

install_gpu_drivers() {
    # ── Unknown GPU / VM block ──
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
                _run_cmd "Mesa" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${mesa_pkgs[*]}" \
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

    # ── Detectable GPU: build plan ──
    local plan="The script has automatically detected your graphics hardware\n"
    plan+="and prepared a personalized installation plan.\n\n"
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
    if $HAS_NVIDIA; then
        plan+="  [+] NVIDIA driver (proprietary)\n"
    fi
    plan+="  [+] Mesa (version selected in next step)\n"

    _msg "Graphics Stack — Plan" "$plan" 16 70

    if ! _confirm "Graphics Stack" "Install the planned components?"; then
        echo "Skipping Graphics Stack."
        return
    fi

    # ── Sequential firmware / driver installs ──
    if $HAS_INTEL; then
        install_intel_firmware
    fi

    if $HAS_AMD; then
        install_amd_firmware
    fi

    if $HAS_NVIDIA; then
        if [ "$DEBIAN_VERSION" = "11" ]; then
            if type install_nvidia_bullseye &>/dev/null; then
                install_nvidia_bullseye
            else
                install_nvidia_driver
            fi
        elif [ "$DEBIAN_VERSION" = "12" ]; then
            if [ "$(is_nvidia_kepler)" = "true" ]; then
                if type _install_nvidia_bookworm_kepler &>/dev/null; then
                    _install_nvidia_bookworm_kepler
                else
                    install_nvidia_driver
                fi
            elif [ "$(is_nvidia_fermi)" = "true" ]; then
                _msg "NVIDIA Fermi — Bookworm" \
                    "Fermi GPUs (GF1xx) are not supported\nin Debian 12 (Bookworm).\nThe nvidia-legacy-390xx driver is\nnot available in this version.\n\nNo NVIDIA driver will be installed."
                NVIDIA_DRIVER_MODE=""
            else
                install_nvidia_driver
            fi
        elif [ "$DEBIAN_VERSION" = "13" ]; then
            if [ "$(is_nvidia_kepler)" = "true" ] || [ "$(is_nvidia_fermi)" = "true" ]; then
                _msg "NVIDIA — Trixie" \
                    "Kepler and Fermi GPUs are not supported\nin Debian 13 (Trixie).\n\nThe nvidia-legacy drivers are not available\nin this version of Debian.\n\nNo NVIDIA driver will be installed."
                NVIDIA_DRIVER_MODE=""
            else
                install_nvidia_driver
            fi
        else
            install_nvidia_driver
        fi
    fi

    # ── Mesa (once) ──
    _install_mesa_backports

    # ── Refresh GPU_VERSION after Mesa install ──
    local mesa_ver
    mesa_ver=$(dpkg -l libgl1-mesa-dri 2>/dev/null | awk '/^ii/ {print $3; exit}' | sed 's/-.*//')
    [ -n "$mesa_ver" ] && GPU_VERSION="Mesa ${mesa_ver}"

    # ── Vendor-specific tools ──
    if $HAS_INTEL; then
        offer_intel_tools
    fi
    if $HAS_AMD; then
        offer_amd_tools
    fi
    if $HAS_NVIDIA; then
        offer_generic_tools
    fi

    # ── Build summary ──
    local summary=""
    summary+="Mesa:    ${GPU_VERSION:-not available}\n"
    if $HAS_NVIDIA; then
        local nv_mode="${NVIDIA_DRIVER_MODE:-unknown}"
        summary+="NVIDIA:  ${nv_mode}\n"
    fi
    summary+="Firmware: installed for detected GPUs\n"
    summary+="Tools:   installed per vendor selection"

    _msg "Graphics Stack — Complete" "$summary" 12 65
}
