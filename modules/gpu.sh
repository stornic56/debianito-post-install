#!/usr/bin/env bash
# Graphics Stack — sources submodules and provides install_gpu_drivers()

_GPU_DIR="${MODULES_DIR}/gpu"
source "${_GPU_DIR}/_helpers.sh"
source "${_GPU_DIR}/amd_intel.sh"
source "${_GPU_DIR}/nvidia.sh"

# Consumed by gaming.sh to know which NVIDIA driver path was taken
NVIDIA_DRIVER_MODE=""

install_gpu_drivers() {
    local info="This section installs the latest Mesa graphics stack\n"
    info+="from Debian backports (or stable), plus GPU firmware\n"
    info+="and monitoring tools tailored to your hardware.\n\n"
    info+="Components:\n"
    info+="  Mesa (OpenGL / Vulkan / VA-API)\n"
    if [ "$GPU_TYPE" != "unknown" ]; then
        info+="  GPU firmware for ${GPU_DESC}\n"
    fi
    info+="  Monitoring tools (nvtop, vainfo, ...)"

    if ! _confirm "Graphics Stack" "$info"; then
        echo "Skipping Graphics Stack."
        return
    fi

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
    local ref_ver
    ref_ver=$(apt-cache policy mesa-vulkan-drivers 2>/dev/null | awk 'NR==3 {print $2; exit}')
    local ref_bpo_ver
    ref_bpo_ver=$(apt-cache madison mesa-vulkan-drivers 2>/dev/null | \
        grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    local comp_line="Components: Vulkan, OpenGL, GLX, EGL, VA-API (64-bit)"

    local src_line="Source: Debian Stable"
    [ -n "$ref_bpo_ver" ] && [ "$(is_backports_enabled)" == "true" ] && src_line="Source: Debian ${DEBIAN_CODENAME^}-Backports"

    local plan="GPUs detected: ${GPU_DESC}\n\n"
    plan+="${src_line}\n"
    plan+="Mesa ${ref_bpo_ver:-$ref_ver}\n"
    plan+="${comp_line}\n\n"
    plan+="Components:\n"
    if $HAS_INTEL; then
        local _gen; _gen=$(get_intel_generation)
        local _va;  [ "$_gen" = "gen7-" ] && _va="i965-va-driver-shaders" || _va="intel-media-va-driver-non-free"
        plan+="  [+] Intel firmware + ${_va}\n"
    fi
    if $HAS_AMD; then
        plan+="  [+] AMD firmware (firmware-amd-graphics)\n"
    fi
    if $HAS_NVIDIA; then
        plan+="  [+] NVIDIA driver (details in next step)\n"
    fi

    if ! _confirm "Graphics Stack — ${GPU_DESC}" "$plan" 14 70; then
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
            else
                install_nvidia_driver
            fi
        elif [ "$DEBIAN_VERSION" = "13" ]; then
            if [ "$(is_nvidia_kepler)" = "true" ]; then
                _msg "NVIDIA Kepler — Trixie" \
                    "Your GPU is NVIDIA Kepler architecture.\nThe nvidia-tesla-470 driver is not available\nin Debian 13 (Trixie).\n\nNo NVIDIA driver will be installed for this GPU.\nOther GPUs (Intel/AMD) will still be configured."
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

    echo -e "${GREEN}Graphics stack setup complete.${NC}"
}
