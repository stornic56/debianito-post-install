#!/usr/bin/env bash
# Graphics Stack — sources submodules, provides AMD/Intel and NVIDIA top-level functions

_GPU_DIR="${MODULES_DIR}/gpu"
source "${_GPU_DIR}/_helpers.sh"
source "${_GPU_DIR}/amd_intel.sh"
source "${_GPU_DIR}/nvidia.sh"
source "${_GPU_DIR}/nvidia_manage.sh"

# Consumed by gaming.sh to know which NVIDIA driver path was taken
NVIDIA_DRIVER_MODE=""
# Set by _show_nvidia_version_menu(): "470" | "535" | "550" | "590" | "595" | "auto"
NVIDIA_SELECTED_VERSION=""

# Aviso informativo post-instalación NVIDIA: Debian bug #1109409
# (GDM3 + NVIDIA + Wayland → pantalla negra). Solo informa, nunca
# cambia configuración de GDM3 ni aborta la instalación.
_warn_nvidia_gnome_wayland() {
    command -v gdm3 &>/dev/null || return 0
    gnome-shell --version 2>/dev/null | grep -qi "shell 4[0-9]" || return 0
    case "$NVIDIA_DRIVER_MODE" in
        stable|backports|cuda-repo|extrepo) ;;
        *) return 0 ;;
    esac
    echo -e "${YELLOW}WARNING: Debian bug #1109409 may affect GDM3 + NVIDIA + Wayland.${NC}"
    echo -e "${YELLOW}If you see a black screen after reboot, select 'GNOME on Xorg' at login.${NC}"
    echo -e "${YELLOW}Or temporarily disable Wayland: sudo nano /etc/gdm3/daemon.conf${NC}"
}

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
    done < <(timeout 2 lspci -nn | grep -E "VGA|3D" || true)
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

    if $HAS_AMD_LEGACY_GCN; then
        local msg="An AMD GCN 1.0/GCN 1.1 GPU has been detected.\n\n"
        msg+="These old GPUs use the legacy 'radeon' driver by default,\n"
        msg+="but the modern 'amdgpu' driver offers better performance\n"
        msg+="and Mesa support.\n\n"
        msg+="Would you like to FORCE the amdgpu driver?\n"
        msg+="(adds radeon.si_support=0 radeon.cik_support=0\n"
        msg+=" amdgpu.si_support=1 amdgpu.cik_support=1 to GRUB)"
        if _confirm "AMD Legacy GCN" "$msg" 16 72; then
            _apply_amd_gcn_grub_fix
        else
            echo "Skipping amdgpu migration."
        fi
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

_apply_amd_gcn_grub_fix() {
    local file="/etc/default/grub"
    local backup="${file}.backup.gcn.$(date +%Y%m%d_%H%M%S)"
    local params="radeon.si_support=0 radeon.cik_support=0 amdgpu.si_support=1 amdgpu.cik_support=1"

    if grep -q "amdgpu.si_support=1" "$file" 2>/dev/null; then
        _msg "AMD GCN" "amdgpu parameters already present in GRUB.\nNo changes made." 8 50
        return
    fi

    sudo cp "$file" "$backup"

    sudo sed -i "/^GRUB_CMDLINE_LINUX_DEFAULT=/ s/\"$*/${params}&/" "$file"

    if _confirm "AMD GCN — GRUB" "Parameters added:\n\n  ${params}\n\nRun update-grub now?" 12 65; then
        if sudo update-grub >/dev/null 2>&1; then
            _msg "AMD GCN — Complete" "amdgpu parameters added to GRUB.\n\nBackup: ${backup}\n\nReboot to apply."
        else
            echo -e "${RED}update-grub failed. Restoring backup...${NC}"
            sudo cp "$backup" "$file"
            _msg "Error" "update-grub failed.\nBackup restored."
        fi
    else
        _msg "AMD GCN" "Parameters written to ${file}.\nRun 'sudo update-grub' manually."
    fi
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
    done < <(timeout 2 lspci -nn | grep -E "VGA|3D" || true)
    plan+="\nPlanned:\n  [+] NVIDIA proprietary driver"

    _msg "NVIDIA Stack — Plan" "$plan" 14 65
    _pause "Press Enter to continue..."

    NVIDIA_DRIVER_MODE=""

    if _nvidia_driver_installed; then
        if ! _nvidia_manage_menu; then
            return
        fi
    fi

    if [ "$DEBIAN_VERSION" = "11" ]; then
        if type install_nvidia_bullseye &>/dev/null; then
            install_nvidia_bullseye
        else
            _msg "NVIDIA — Bullseye" "The Bullseye NVIDIA module is not available.\n\nNo NVIDIA driver was installed." 10 60
            NVIDIA_DRIVER_MODE=""
        fi

    else
        if ! _show_nvidia_version_menu; then
            echo "Skipping NVIDIA driver installation."
            return
        fi

        local nv_arch=""
        case "$NVIDIA_SELECTED_VERSION" in
            470)
                # Legacy 470 (Kepler/Tesla) — forced, regardless of auto-detection
                _install_nvidia_bookworm_kepler
                ;;
            535)
                if [ "$(is_nvidia_kepler)" = "true" ]; then
                    _install_nvidia_bookworm_kepler
                elif [ "$(is_nvidia_fermi)" = "true" ]; then
                    _msg "NVIDIA Fermi — Bookworm" \
                        "Fermi GPUs (GF1xx) are not supported\nin Debian 12 (Bookworm).\nThe nvidia-legacy-390xx driver is\nnot available in this version.\n\nNo NVIDIA driver will be installed."
                    NVIDIA_DRIVER_MODE=""
                else
                    _install_nvidia_standard
                fi
                ;;
            550)
                nv_arch=$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")
                case "$nv_arch" in
                    legacy)
                        _msg "NVIDIA — Trixie" \
                            "Kepler and Fermi GPUs are not supported\nin Debian 13 (Trixie).\n\nThe nvidia-legacy drivers are not available\nin this version of Debian.\n\nNo NVIDIA driver will be installed."
                        NVIDIA_DRIVER_MODE=""
                        ;;
                    blackwell)
                        _msg "NVIDIA — Blackwell (v550)" \
                            "Your Blackwell GPU is NOT supported by the official\nDebian v550 driver.\n\nPlease select v590 or v595 (NVIDIA CUDA Repo)\nin the driver menu." 14 65
                        NVIDIA_DRIVER_MODE=""
                        ;;
                    maxwell|pascal|volta)
                        if [ "$(is_backports_kernel)" = "true" ]; then
                            local gpu_gen="Maxwell"
                            [ "$nv_arch" = "pascal" ] && gpu_gen="Pascal"
                            [ "$nv_arch" = "volta" ] && gpu_gen="Volta"
                            _msg "NVIDIA — Trixie + Backports" \
                                "INCOMPATIBILITY DETECTED: Your NVIDIA ${gpu_gen} GPU\n\
is NOT supported by the modern v590 driver.\n\n\
To run NVIDIA safely on Debian 13 (Trixie), you MUST use\n\
the official Debian v550 driver, which requires the\n\
standard STABLE Kernel.\n\n\
Forcing the stable driver path." 14 70
                            if ! _install_nvidia_standard; then
                                NVIDIA_DRIVER_MODE=""
                                return 1
                            fi
                            NVIDIA_DRIVER_MODE="stable"
                        else
                            _install_nvidia_standard
                        fi
                        ;;
                    turing|ampere|ada)
                        _install_nvidia_standard
                        ;;
                    *)
                        if [ "$(is_backports_kernel)" = "true" ]; then
                            _install_nvidia_cuda_repo
                        else
                            _install_nvidia_standard
                        fi
                        ;;
                esac
                ;;
            590|595)
                nv_arch=$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")
                if [ "$nv_arch" = "maxwell" ] || [ "$nv_arch" = "pascal" ] || [ "$nv_arch" = "legacy" ]; then
                    local gpu_gen="Kepler/Fermi"
                    [ "$nv_arch" = "maxwell" ] && gpu_gen="Maxwell"
                    [ "$nv_arch" = "pascal" ] && gpu_gen="Pascal"
                    _msg "NVIDIA — v${NVIDIA_SELECTED_VERSION}" \
                        "Your NVIDIA ${gpu_gen} GPU is NOT supported by\nNVIDIA driver v${NVIDIA_SELECTED_VERSION}.\n\n\
Only Turing, Ampere, Ada and Blackwell GPUs are supported.\n\n\
No NVIDIA driver will be installed." 14 65
                    NVIDIA_DRIVER_MODE=""
                else
                    if ! _enable_cuda_repo; then
                        NVIDIA_DRIVER_MODE=""
                        _msg "CUDA Repo — Error" "Failed to enable the official NVIDIA CUDA repository.\n\nNo NVIDIA driver was installed." 10 60
                        return 1
                    fi
                    if _install_nvidia_cuda_repo "$NVIDIA_SELECTED_VERSION"; then
                        NVIDIA_DRIVER_MODE="cuda-repo"
                    else
                        NVIDIA_DRIVER_MODE=""
                    fi
                fi
                ;;
            *)
                _install_nvidia_standard
                ;;
        esac
    fi

    if [ -n "$NVIDIA_DRIVER_MODE" ]; then
        _configure_nvidia_wayland "$NVIDIA_SELECTED_VERSION"
        if _is_hybrid_laptop; then
            echo -e "${CYAN}[INFO] Hybrid GPU (Optimus) detected.${NC}"
            echo -e "PRIME offload is auto-configured by X.Org 1.20.7+ when using X11."
            echo -e "After reboot, verify with: ${YELLOW}xrandr --listproviders | grep NVIDIA-G0${NC}"
            echo -e "If not found, ensure BIOS boots on iGPU and nvidia-drm is loaded."
        fi
        offer_generic_tools
        _warn_nvidia_gnome_wayland
        local summary="NVIDIA: ${NVIDIA_DRIVER_MODE}\n"
        summary+="Tools:  nvtop + vainfo"
        _msg "NVIDIA Stack — Complete" "$summary" 10 55
    fi
}
