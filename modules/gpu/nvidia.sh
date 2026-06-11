#!/usr/bin/env bash
# NVIDIA GPU driver installation — 3-CASE dispatch
#
# CASE A : Trixie + backports kernel → Official NVIDIA CUDA Repo (Pinned v590)
# CASE B : Bookworm + backports kernel → Debian backports (-t bookworm-backports)
# CASE C : Kernel stable (any distro)  → Debian stable (optional backports)

install_nvidia_driver() {
    echo -e "${YELLOW}NVIDIA GPU detected.${NC}"
    NVIDIA_DRIVER_MODE=""

    local is_bpo_kernel;    is_bpo_kernel=$(is_backports_kernel)
    local is_kepler;        is_kepler=$(is_nvidia_kepler)
    local is_maxwell;       is_maxwell=$(is_nvidia_maxwell)
    local is_pascal;        is_pascal=$(is_nvidia_pascal)

    # ── Veto: Kepler en Trixie no tiene driver disponible ──
    if [ "$is_kepler" = "true" ] && [ "$DEBIAN_CODENAME" = "trixie" ]; then
        _msg "NVIDIA Kepler" \
            "Your GPU is NVIDIA Kepler architecture.\n\nThe nvidia-tesla-470 driver is not available\nin Debian 13 (Trixie).\n\nNo NVIDIA driver will be installed." 14 65
        return 1
    fi

    # ── Bloqueo: Maxwell/Pascal no son compatibles con v590 ──
    if [ "$DEBIAN_CODENAME" = "trixie" ] && [ "$is_bpo_kernel" = "true" ]; then
        if [ "$is_maxwell" = "true" ] || [ "$is_pascal" = "true" ]; then
            local gpu_gen="Maxwell"
            [ "$is_pascal" = "true" ] && gpu_gen="Pascal"
            local block_msg="INCOMPATIBILITY DETECTED: Your NVIDIA ${gpu_gen} GPU\n"
            block_msg+="is NOT supported by the modern v590 driver.\n\n"
            block_msg+="To run NVIDIA safely on Debian 13 (Trixie), you MUST use\n"
            block_msg+="the official Debian v550 driver, which requires the\n"
            block_msg+="standard STABLE Kernel.\n\n"
            block_msg+="The script will automatically downgrade your path to\n"
            block_msg+="Stable Kernel mode for NVIDIA."
            _msg "NVIDIA — Trixie + Backports" "$block_msg" 14 70
            is_bpo_kernel=false
        fi
    fi

    # ── Dispatch por casos ──
    if [ "$DEBIAN_CODENAME" = "trixie" ] && [ "$is_bpo_kernel" = "true" ]; then
        _install_nvidia_cuda_repo
    elif [ "$DEBIAN_CODENAME" = "bookworm" ] && [ "$is_bpo_kernel" = "true" ]; then
        _install_nvidia_bookworm_bpo
    else
        _install_nvidia_standard
    fi
}

# -------------------------------------------------------------------
# CASE A: Trixie + Backports Kernel → Official CUDA Repo (Pinned v590)
# -------------------------------------------------------------------
_install_nvidia_cuda_repo() {
    local i386_active=false
    dpkg --print-foreign-architectures | grep -q i386 && i386_active=true

    local warn="WARNING: Official Debian NVIDIA driver (v550)\n"
    warn+="fails to compile on Trixie Backports Kernels.\n\n"
    warn+="The script will configure the official NVIDIA CUDA\n"
    warn+="repository and force-install the stable production\n"
    warn+="branch v590.48.01 on your system.\n\n"
    warn+="Source: Official NVIDIA CUDA Repo (Pinned v590.*)\n"
    warn+="Driver: Production Branch 590.48.01 (Kernel 7.0+ Compliant)\n"
    warn+="[+] Full 64-bit Core & Compute Stack (DKMS)\n"
    if $i386_active; then
        warn+="[+] 32-bit Gaming Multiarch Libraries\n"
    fi
    warn+="[+] APT Pinning + Package Hold will be applied\n\n"
    warn+="Do you want to proceed at your own risk?"

    if ! _confirm_custom "NVIDIA Driver — Trixie + Backports" "$warn" "Proceed" "Abort" 18 70; then
        echo -e "${YELLOW}NVIDIA installation aborted by user.${NC}"
        return 1
    fi

    # Step 1: Download & install CUDA keyring
    _run_cmd "CUDA Keyring" \
        "wget -q https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb -O /tmp/cuda-keyring.deb && sudo dpkg -i /tmp/cuda-keyring.deb && rm -f /tmp/cuda-keyring.deb" \
        "Downloading and installing official CUDA keyring..."

    # Step 2: Create APT pinning to lock v590
    _run_cmd "APT Pinning" \
        'printf "%s\n" "Package: *nvidia*" "Package: *cuda*" "Package: libcuda1" "Package: firmware-nvidia-gsp" "Pin: version 590.*" "Pin-Priority: 1001" | sudo tee /etc/apt/preferences.d/block-nvidia > /dev/null' \
        "Creating APT pinning to lock NVIDIA to v590 branch..."

    # Step 3: Update package lists
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."

    # Step 4: Build version-locked package list
    local pkgs=(
        "cuda-drivers=590.48.01-1"
        "libcuda1=590.48.01-1"
        "nvidia-driver=590.48.01-1"
        "nvidia-driver-libs=590.48.01-1"
        "firmware-nvidia-gsp=590.48.01-1"
        "libegl-nvidia0=590.48.01-1"
        "libglx-nvidia0=590.48.01-1"
        "libnvidia-eglcore=590.48.01-1"
        "libnvidia-glcore=590.48.01-1"
        "libnvidia-glvkspirv=590.48.01-1"
        "libnvidia-ml1=590.48.01-1"
        "nvidia-egl-icd=590.48.01-1"
        "nvidia-vulkan-icd=590.48.01-1"
        "libnvcuvid1=590.48.01-1"
        "libnvidia-encode1=590.48.01-1"
        "nvidia-kernel-dkms=590.48.01-1"
        "nvidia-settings=590.48.01-1"
        "nvidia-smi=590.48.01-1"
    )

    if $i386_active; then
        pkgs+=(
            "libcuda1:i386=590.48.01-1"
            "nvidia-driver-libs:i386=590.48.01-1"
            "libegl-nvidia0:i386=590.48.01-1"
            "libglx-nvidia0:i386=590.48.01-1"
            "libnvidia-eglcore:i386=590.48.01-1"
            "libnvidia-glcore:i386=590.48.01-1"
            "libnvidia-glvkspirv:i386=590.48.01-1"
            "libnvidia-ml1:i386=590.48.01-1"
            "nvidia-egl-icd:i386=590.48.01-1"
            "nvidia-vulkan-icd:i386=590.48.01-1"
        )
    fi

    _run_cmd "NVIDIA CUDA" "sudo apt install -y ${pkgs[*]}" \
        "Installing NVIDIA Production Driver v590.48.01..."

    # Step 5: Hold critical packages
    _run_cmd "Package Hold" \
        "sudo apt-mark hold cuda-drivers libcuda1 firmware-nvidia-gsp" \
        "Locking v590 packages to prevent accidental upgrades..."

    NVIDIA_DRIVER_MODE="cuda-repo"
    echo -e "${GREEN}NVIDIA Production Driver v590 installed from CUDA repo. Reboot required.${NC}"
}

# -------------------------------------------------------------------
# CASE B: Bookworm + Backports Kernel → Debian backports
# -------------------------------------------------------------------
_install_nvidia_bookworm_bpo() {
    local nv_pkg=""
    local is_kepler
    is_kepler=$(is_nvidia_kepler)

    if [ "$is_kepler" = "true" ]; then
        nv_pkg="nvidia-tesla-470-driver"
    else
        local nd_ver
        nd_ver=$(apt-cache policy nvidia-detect 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if _confirm "NVIDIA Detect" "Install nvidia-detect to determine the correct driver?\n\n  nvidia-detect  ${nd_ver:-unknown}" 12 70; then
            _run_cmd "NVIDIA" "sudo apt install -y nvidia-detect" "Installing nvidia-detect..."
        else
            echo "Skipping NVIDIA driver detection."
            NVIDIA_DRIVER_MODE=""
            return 0
        fi
        local recommended
        recommended=$(nvidia-detect 2>/dev/null | grep -oP 'nvidia[\w-]+(?= package)')
        if [ -z "$recommended" ]; then
            echo -e "${RED}nvidia-detect could not determine a suitable driver.${NC}"
            return 1
        fi
        if [[ "$recommended" =~ legacy-390|legacy-340 ]]; then
            echo -e "${RED}Your GPU requires $recommended, which is not available.${NC}"
            return 1
        fi
        nv_pkg="$recommended"
    fi

    local nv_ver
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
    local msg="Source: Debian Bookworm-Backports\n"
    msg+="NVIDIA Driver: ${nv_pkg} ${nv_ver:-unknown}\n"
    msg+="           (Compatible with Kernel v6.12+)\n"
    msg+="[+] firmware-misc-nonfree\n"
    msg+="[+] nvidia-vaapi-driver"

    if ! _confirm "NVIDIA Driver — Backports" "$msg" 14 70; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    _run_cmd "NVIDIA" "sudo apt install -y -t bookworm-backports $nv_pkg firmware-misc-nonfree nvidia-vaapi-driver" \
        "Installing NVIDIA driver from backports..."

    NVIDIA_DRIVER_MODE="backports"
    echo -e "${GREEN}NVIDIA driver installed from backports. Reboot required.${NC}"
}

# -------------------------------------------------------------------
# Bookworm Kepler intercepción — fuerza nvidia-legacy-470xx-driver
# sin pasar por nvidia-detect (evita falsa recomendación rama 535)
# -------------------------------------------------------------------
_install_nvidia_bookworm_kepler() {
    local nv_pkg="nvidia-legacy-470xx-driver"
    local nv_ver
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')

    echo -e "${YELLOW}Kepler GPU detected — forcing ${nv_pkg}.${NC}"

    local msg="Kepler GPU detectada (GKxxx).\n\n"
    msg+="En Debian 12 Bookworm, Kepler requiere el driver legacy\n"
    msg+="en lugar del moderno. Se usará el paquete:\n"
    msg+="  ${nv_pkg}  ${nv_ver:-unknown}\n"
    msg+="para evitar fallos de pantalla negra.\n\n"
    msg+="  [SKIP] nvidia-detect (omitido — evita rama 535)\n"
    msg+="  [USE]  ${nv_pkg}\n"
    msg+="  [+]   firmware-misc-nonfree\n"
    msg+="  [+]   nvidia-settings\n\n"
    msg+="Instalar driver legacy para Kepler?"

    if ! _confirm_custom "NVIDIA Kepler — Bookworm" "$msg" "Install" "Skip" 14 70; then
        echo "Omitiendo driver Kepler."
        NVIDIA_DRIVER_MODE=""
        return 0
    fi

    _run_cmd "NVIDIA Kepler" \
        "sudo apt install -y $nv_pkg firmware-misc-nonfree nvidia-settings" \
        "Instalando nvidia-legacy-470xx-driver..."

    # Si backports está habilitado, ofrecer actualización
    if [ "$(is_backports_enabled)" == "true" ]; then
        local bpo_ver
        bpo_ver=$(apt-cache madison "$nv_pkg" 2>/dev/null | \
            grep "bookworm-backports" | awk '{print $3}' | head -1)
        if [ -n "$bpo_ver" ]; then
            local msg="Hay una versión en backports: ${bpo_ver}\n"
            msg+="Instalar desde bookworm-backports?"
            if _confirm "Kepler Backports" "$msg"; then
                _run_cmd "NVIDIA Kepler" \
                    "sudo apt install -y -t bookworm-backports $nv_pkg" \
                    "Actualizando Kepler driver desde backports..."
                NVIDIA_DRIVER_MODE="backports"
                echo -e "${GREEN}Kepler driver actualizado desde backports.${NC}"
            fi
        fi
    fi

    NVIDIA_DRIVER_MODE="${NVIDIA_DRIVER_MODE:-stable}"
    echo -e "${GREEN}Kepler driver (${nv_pkg}) installed. Reboot required.${NC}"
}

# -------------------------------------------------------------------
# CASE C: Kernel stable (any distro) → Debian stable, optional backports
# -------------------------------------------------------------------
_install_nvidia_standard() {
    local nv_pkg=""
    local use_bpo=false
    local is_kepler
    is_kepler=$(is_nvidia_kepler)

    if [ "$is_kepler" = "true" ]; then
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            _msg "NVIDIA Kepler" \
                "Your GPU is NVIDIA Kepler architecture.\n\nThe nvidia-tesla-470 driver is not available\nin Debian 13 (Trixie).\n\nOptions:\n  1. Use Debian 12 (Bookworm) with nvidia-tesla-470\n  2. Use open-source Nouveau driver (limited)\n\nNo NVIDIA driver will be installed." 14 65
            return 1
        fi
        nv_pkg="nvidia-tesla-470-driver"
        echo -e "${YELLOW}Kepler GPU detected. Will use ${nv_pkg}.${NC}"
    else
        local nd_ver
        nd_ver=$(apt-cache policy nvidia-detect 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if _confirm "NVIDIA Detect" "Install nvidia-detect to determine the correct driver?\n\n  nvidia-detect  ${nd_ver:-unknown}" 12 70; then
            _run_cmd "NVIDIA" "sudo apt install -y nvidia-detect" "Installing nvidia-detect..."
        else
            echo "Skipping NVIDIA driver detection."
            return 0
        fi
        local recommended
        recommended=$(nvidia-detect 2>/dev/null | grep -oP 'nvidia[\w-]+(?= package)')
        if [ -z "$recommended" ]; then
            echo -e "${RED}nvidia-detect could not determine a suitable driver.${NC}"
            return 1
        fi
        if [[ "$recommended" =~ legacy-390|legacy-340 ]]; then
            echo -e "${RED}Your GPU requires $recommended, which is not available.${NC}"
            return 1
        fi
        nv_pkg="$recommended"
    fi

    # Check for backports (optional, if repo enabled)
    local stable_nv_ver
    stable_nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
    if [ "$(is_backports_enabled)" == "true" ]; then
        local bpo_nv_ver
        bpo_nv_ver=$(apt-cache madison "$nv_pkg" 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
        if [ -n "$bpo_nv_ver" ]; then
            local msg="Source: Debian ${DEBIAN_CODENAME^} (Backports available)\n"
            msg+="NVIDIA Driver: ${nv_pkg}\n\n"
            msg+="  Backports: ${bpo_nv_ver}\n"
            msg+="  Stable:    ${stable_nv_ver:-unknown}\n\n"
            msg+="Choose version:"
            if _confirm_custom "NVIDIA Driver" "$msg" "Backports" "Stable" 14 70; then
                use_bpo=true
            fi
        fi
    fi

    local src_label="Debian ${DEBIAN_CODENAME^} Stable"
    $use_bpo && src_label="Debian ${DEBIAN_CODENAME^}-Backports"

    local msg="Source: ${src_label}\n"
    msg+="NVIDIA Driver: ${nv_pkg} ${stable_nv_ver:-unknown}\n"
    msg+="[+] firmware-misc-nonfree\n"
    msg+="[+] nvidia-vaapi-driver\n"
    msg+="[+] mesa-vdpau-drivers"

    if ! _confirm "NVIDIA Driver" "$msg" 14 70; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    local extra_pkgs="firmware-misc-nonfree nvidia-vaapi-driver mesa-vdpau-drivers"
    if $use_bpo; then
        _run_cmd "NVIDIA" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $nv_pkg $extra_pkgs" \
            "Installing NVIDIA driver from backports..."
        NVIDIA_DRIVER_MODE="backports"
    else
        _run_cmd "NVIDIA" "sudo apt install -y $nv_pkg $extra_pkgs" \
            "Installing NVIDIA driver from stable..."
        NVIDIA_DRIVER_MODE="stable"
    fi

    echo -e "${GREEN}NVIDIA driver installed. Reboot required.${NC}"
}
