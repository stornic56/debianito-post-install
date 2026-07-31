#!/usr/bin/env bash
# NVIDIA GPU driver installation — 3-CASE dispatch
#
# CASE A : Trixie + backports kernel → Official NVIDIA CUDA Repo (Pinned v590)
# CASE B : Bookworm + backports kernel → Debian backports (-t bookworm-backports)
# CASE C : Kernel stable (any distro)  → Debian stable (optional backports)

# --- DEPRECATED (Replaced by _install_nvidia_stack in gpu.sh) ---
install_nvidia_driver() {
    echo -e "${YELLOW}NVIDIA GPU detected.${NC}"
    NVIDIA_DRIVER_MODE=""

    local is_bpo_kernel;    is_bpo_kernel=$(is_backports_kernel)
    local nv_arch;          nv_arch=$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")
    local is_kepler="false";   [[ "$nv_arch" == "legacy" ]] && _is_nvidia_kepler_id "$NVIDIA_GPU_DEVICE_ID" && is_kepler="true"
    local is_maxwell;       is_maxwell=$(is_nvidia_maxwell)
    local is_pascal;        is_pascal=$(is_nvidia_pascal)
    local is_blackwell;     is_blackwell=$(is_nvidia_blackwell)

    # ── Blackwell: v550 no soporta GB20x → CUDA repo v590 ──
    if [ "$DEBIAN_CODENAME" = "trixie" ] && [ "$is_blackwell" = "true" ]; then
        _msg "NVIDIA Blackwell" \
            "Your GPU is NVIDIA Blackwell architecture.\n\nDebian 13's nvidia-driver (v550) does not\nsupport Blackwell GPUs.\n\n\
The script will enable the official NVIDIA CUDA\nrepository and install the v590 production branch,\nwhich fully supports Blackwell (GB20x)." 14 65
        _install_nvidia_cuda_repo
        return
    fi

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
# Shared helper: enable NVIDIA CUDA repo via extrepo
# -------------------------------------------------------------------
_enable_cuda_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_nvidia-cuda.sources ] && \
       ! grep -qr 'developer.download.nvidia.com' /etc/apt/sources.list.d/ 2>/dev/null; then
        if ! command -v extrepo &>/dev/null; then
            _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
        fi
        _run_cmd "CUDA Repo" \
            "sudo extrepo enable nvidia-cuda" \
            "Enabling official NVIDIA CUDA repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

# -------------------------------------------------------------------
# CASE A: Trixie + Backports Kernel → Official CUDA Repo (Pinned v590)
# -------------------------------------------------------------------
_install_nvidia_cuda_repo() {
    local warn="WARNING: Official Debian NVIDIA driver (v550)\n"
    warn+="fails to compile on Trixie Backports Kernels.\n\n"
    warn+="The script will enable the official NVIDIA CUDA\n"
    warn+="repository and install the production branch v590\n"
    warn+="using NVIDIA's unified driver pinning packages.\n\n"
    warn+="Source: Official NVIDIA CUDA Repo (Pinned v590.*)\n"
    warn+="Driver: Production Branch v590 (unified metapackage)\n"
    warn+="[+] nvidia-driver (full 64-bit compute + graphics)\n"
    warn+="[+] firmware-nvidia-gsp\n"
    warn+="[+] nvidia-driver-pinning-590 (branch locking)\n"
    warn+="[+] APT Pinning (version 590.*)\n\n"
    warn+="Do you want to proceed at your own risk?"

    if ! _confirm_custom "NVIDIA Driver — Trixie + Backports" "$warn" "Proceed" "Abort" 18 70; then
        echo -e "${YELLOW}NVIDIA installation aborted by user.${NC}"
        return 1
    fi

    # Step 1: Enable CUDA repo via extrepo
    _enable_cuda_repo

    # Step 2: Create APT pinning to lock v590
    _run_cmd "APT Pinning" \
        'printf "%s\n" "Package: *nvidia*" "Package: *cuda*" "Package: libcuda1" "Package: firmware-nvidia-gsp" "Pin: version 590.*" "Pin-Priority: 1001" | sudo tee /etc/apt/preferences.d/block-nvidia > /dev/null' \
        "Creating APT pinning to lock NVIDIA to v590 branch..."

    # Step 3: Install NVIDIA unified metapackages (driver pinning)
    _run_cmd "NVIDIA CUDA" \
        "sudo apt install -y nvidia-driver-pinning-590 nvidia-driver firmware-nvidia-gsp" \
        "Installing NVIDIA v590 production driver via unified metapackages..."

    NVIDIA_DRIVER_MODE="cuda-repo"
    echo -e "${GREEN}NVIDIA Production Driver v590 installed from CUDA repo. Reboot required.${NC}"

    echo ""
    echo "──────────────────────────────────────────────"
    echo "Verifying DKMS module compilation:"
    if command -v dkms &>/dev/null; then
        dkms status 2>/dev/null | grep nvidia || echo "(no nvidia DKMS module found)"
    else
        echo "(dkms not installed)"
    fi
    echo ""
    echo "If the line ends with 'installed' → module is OK."
    echo "Otherwise check: dmesg | grep nvidia"
    echo "──────────────────────────────────────────────"
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
        nd_ver=$(apt-cache policy nvidia-detect 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
        if _confirm "NVIDIA Detect" "Install nvidia-detect to determine the correct driver?\n\n  nvidia-detect  ${nd_ver:-unknown}" 12 70; then
            _run_cmd "NVIDIA" "sudo apt install -y nvidia-detect" "Installing nvidia-detect..."
        else
            echo "Skipping NVIDIA driver detection."
            NVIDIA_DRIVER_MODE=""
            return 0
        fi
        local recommended
        recommended=$(nvidia-detect 2>/dev/null | grep -oP 'nvidia[\w-]+(?= package)') || true
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
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
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

    echo ""
    echo "──────────────────────────────────────────────"
    echo "Verifying DKMS module compilation:"
    if command -v dkms &>/dev/null; then
        dkms status 2>/dev/null | grep nvidia || echo "(no nvidia DKMS module found)"
    else
        echo "(dkms not installed)"
    fi
    echo ""
    echo "If the line ends with 'installed' → module is OK."
    echo "Otherwise check: dmesg | grep nvidia"
    echo "──────────────────────────────────────────────"
}

# -------------------------------------------------------------------
# Bookworm Kepler intercepción — fuerza nvidia-legacy-470xx-driver
# sin pasar por nvidia-detect (evita falsa recomendación rama 535)
# -------------------------------------------------------------------
_install_nvidia_bookworm_kepler() {
    local nv_pkg="nvidia-tesla-470-driver"
    local nv_ver
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true

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
            grep "bookworm-backports" | awk '{print $3}' | head -1) || true
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

    echo ""
    echo "──────────────────────────────────────────────"
    echo "Verifying DKMS module compilation:"
    if command -v dkms &>/dev/null; then
        dkms status 2>/dev/null | grep nvidia || echo "(no nvidia DKMS module found)"
    else
        echo "(dkms not installed)"
    fi
    echo ""
    echo "If the line ends with 'installed' → module is OK."
    echo "Otherwise check: dmesg | grep nvidia"
    echo "──────────────────────────────────────────────"
}

# -------------------------------------------------------------------
# CASE C: Kernel stable (any distro) → Debian stable, optional backports
# -------------------------------------------------------------------
_install_nvidia_standard() {
    # --- 1. DETERMINAR PAQUETES BASADO EN LA SEÑAL ---
    local nv_pkg="nvidia-driver"
    local kernel_pkg=""
    local use_bpo=false

    case "${NVIDIA_DRIVER_MODE:-auto}" in
        open)
            kernel_pkg="nvidia-open-kernel-dkms"
            ;;
        classic|stable|backports)
            kernel_pkg="nvidia-kernel-dkms"
            ;;
        auto)
            kernel_pkg="$(nvidia-detect 2>/dev/null | grep -oP 'nvidia-kernel-dkms' || echo "")"
            [ -z "$kernel_pkg" ] && kernel_pkg="nvidia-kernel-dkms"
            ;;
    esac

    # --- 2. DIÁLOGO DE BACKPORTS ---
    if [ "$(is_backports_enabled)" == "true" ] && [ "${NVIDIA_DRIVER_MODE:-auto}" != "stable" ]; then
        local stable_nv_ver bpo_nv_ver msg
        stable_nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
        bpo_nv_ver=$(apt-cache madison "$nv_pkg" 2>/dev/null | grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1) || true

        if [ -n "$bpo_nv_ver" ]; then
            msg="Source: Debian ${DEBIAN_CODENAME^} (Backports available)\n"
            msg+="NVIDIA Driver: ${nv_pkg}\n\n"
            msg+="  Backports: ${bpo_nv_ver}\n"
            msg+="  Stable:    ${stable_nv_ver:-unknown}\n\n"
            msg+="Choose version:"
            if _confirm_custom "NVIDIA Driver" "$msg" "Backports" "Stable" 14 70; then
                use_bpo=true
            fi
        fi
    fi

    # --- 3. MENSAJE DE CONFIRMACIÓN ---
    local src_label="Debian ${DEBIAN_CODENAME^} Stable"
    $use_bpo && src_label="Debian ${DEBIAN_CODENAME^}-Backports"

    local stable_nv_ver kernel_ver msg
    stable_nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
    kernel_ver=$(apt-cache policy "$kernel_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true

    msg="Source: ${src_label}\n"
    msg+="NVIDIA Driver: ${nv_pkg} ${stable_nv_ver:-unknown}\n"
    msg+="Kernel Module: ${kernel_pkg} ${kernel_ver:-unknown}\n"
    msg+="[+] firmware-misc-nonfree (o firmware-nvidia-gsp en Trixie)\n"
    msg+="[+] nvidia-vaapi-driver\n"
    msg+="[+] mesa-vdpau-drivers"

    if ! _confirm "NVIDIA Driver" "$msg" 14 70; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    # --- 4. EJECUCIÓN ---
    local extra_pkgs="firmware-misc-nonfree nvidia-vaapi-driver mesa-vdpau-drivers"
    local install_pkgs="$kernel_pkg $nv_pkg $extra_pkgs"

    if $use_bpo; then
        _run_cmd "NVIDIA" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $install_pkgs" \
            "Installing NVIDIA driver from backports..."
        NVIDIA_DRIVER_MODE="backports"
    else
        _run_cmd "NVIDIA" "sudo apt install -y $install_pkgs" \
            "Installing NVIDIA driver from stable..."
        NVIDIA_DRIVER_MODE="stable"
    fi

    # --- 5. VERIFICACIÓN DKMS ---
    echo -e "${GREEN}NVIDIA driver installed. Reboot required.${NC}"
    echo "──────────────────────────────────────────────"
    echo "Verifying DKMS module compilation:"
    command -v dkms &>/dev/null && dkms status 2>/dev/null | grep nvidia || echo "(no nvidia DKMS module found)"
    echo "If the line ends with 'installed' → module is OK."
    echo "──────────────────────────────────────────────"
}
