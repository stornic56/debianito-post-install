#!/usr/bin/env bash
# Graphics Stack — sources submodules and provides install_gpu_drivers()

_GPU_DIR="${MODULES_DIR}/gpu"
source "${_GPU_DIR}/_helpers.sh"
source "${_GPU_DIR}/amd_intel.sh"
source "${_GPU_DIR}/nvidia.sh"

# Consumed by gaming.sh to know which NVIDIA driver path was taken
NVIDIA_DRIVER_MODE=""

install_gpu_drivers() {
    # Step 1: Info banner
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

    # Step 2: GPU detected?
    if [ "$GPU_TYPE" = "unknown" ] || [ -z "$GPU_TYPE" ]; then
        # --- BLOQUE B: No GPU / VM (inline, no _install_mesa_backports) ---
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
    else
        # --- BLOQUE A: GPU detectada (AMD / Intel / NVIDIA) ---
        local ref_ver
        ref_ver=$(apt-cache policy mesa-vulkan-drivers 2>/dev/null | awk 'NR==3 {print $2; exit}')
        local ref_bpo_ver
        ref_bpo_ver=$(apt-cache madison mesa-vulkan-drivers 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
        local comp_line="Components: Vulkan, OpenGL, GLX, EGL, VA-API (64-bit)"

        local src_line="Source: Debian Stable"
        [ -n "$ref_bpo_ver" ] && [ "$(is_backports_enabled)" == "true" ] && src_line="Source: Debian ${DEBIAN_CODENAME^}-Backports"

        local plan="GPU detected: ${GPU_DESC}\n\n"
        plan+="${src_line}\n"
        plan+="Mesa ${ref_bpo_ver:-$ref_ver}\n"
        plan+="${comp_line}\n"

        case "$GPU_TYPE" in
            amd)    plan+="[+] Firmware: firmware-amd-graphics\n" ;;
            intel)
                local _gen; _gen=$(get_intel_generation)
                local _va;  [ "$_gen" = "gen7-" ] && _va="i965-va-driver-shaders" || _va="intel-media-va-driver-non-free"
                plan+="[+] Firmware: firmware-intel-graphics + ${_va}\n"
                ;;
            nvidia) plan+="[+] NVIDIA driver (details in next step)\n" ;;
        esac

        if ! _confirm "Graphics Stack — ${GPU_DESC}" "$plan" 14 70; then
            echo "Skipping Graphics Stack."
            return
        fi

        # 3. _run_cmd (via vendor functions — each with its own pkg_versions + _confirm)
        case "$GPU_TYPE" in
            amd)    install_amd_firmware ;;
            intel)  install_intel_firmware ;;
            nvidia) install_nvidia_driver ;;
        esac

        # Mesa (backports / stable)
        _install_mesa_backports

        # Vendor-specific tools
        case "$GPU_TYPE" in
            amd)    offer_amd_tools ;;
            intel)  offer_intel_tools ;;
            nvidia) offer_generic_tools ;;
        esac
    fi

    echo -e "${GREEN}Graphics stack setup complete.${NC}"
}
