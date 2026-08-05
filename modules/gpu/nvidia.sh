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
    if ! _is_cuda_repo_ready; then
        if ! command -v extrepo &>/dev/null; then
            _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..." || return 1
        fi
        _run_cmd "CUDA Repo" \
            "sudo extrepo enable nvidia-cuda" \
            "Enabling official NVIDIA CUDA repository..." || return 1
    fi
}

# -------------------------------------------------------------------
# Shared DKMS helpers: verify the NVIDIA module compiled for the
# currently running kernel; repair via dpkg-reconfigure if not
# -------------------------------------------------------------------
# Returns: 0 if the NVIDIA DKMS module shows "installed" for $(uname -r)
_nvidia_dkms_installed() {
    local kernel line
    kernel=$(uname -r)
    line=$(dkms status 2>/dev/null | grep "^nvidia" | grep -F "$kernel" | grep ": installed" | head -1)
    [ -n "$line" ]
}

# Returns 0 if Secure Boot is active (mokutil present and enabled)
_nvidia_secure_boot_enabled() {
    command -v mokutil &>/dev/null || return 1
    mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"
}

# Aviso no fatal: el módulo DKMS está compilado pero NO firmado.
# El usuario avanzado puede firmarlo con MOK; el novato necesita saber
# por qué verá pantalla negra tras reiniciar. Si mokutil falta, no se
# muestra nada (mokutil no viene preinstalado en Debian).
_warn_secure_boot() {
    if _nvidia_secure_boot_enabled; then
        echo -e "${RED}WARNING: Secure Boot is enabled. The NVIDIA DKMS module is compiled but NOT signed.${NC}"
        echo -e "${RED}You MUST sign the module with MOK or disable Secure Boot in BIOS before rebooting.${NC}"
        echo -e "${RED}See: https://wiki.debian.org/SecureBoot#Signing_kernel_modules${NC}"
    fi
}

# Verify the DKMS build for the current kernel and repair it if needed.
# $@ = candidate dkms packages to reconfigure, in priority order
# (the first installed one is used for dpkg-reconfigure).
_verify_nvidia_dkms_build() {
    local kernel
    kernel=$(uname -r)

    echo ""
    echo "──────────────────────────────────────────────"
    echo "Verifying DKMS module compilation for ${kernel}:"

    if ! command -v dkms &>/dev/null; then
        echo -e "${RED}(dkms not installed — DKMS build cannot be verified)${NC}"
        echo "──────────────────────────────────────────────"
        return 1
    fi

    dkms status 2>/dev/null | grep "^nvidia" || echo "(no nvidia DKMS module found)"

    if _nvidia_dkms_installed; then
        _warn_secure_boot
        echo -e "${GREEN}DKMS module compiled for ${kernel}. Reboot required.${NC}"
        echo "──────────────────────────────────────────────"
        return 0
    fi

    echo -e "${YELLOW}DKMS module NOT compiled for ${kernel}. Repairing...${NC}"
    local pkg repaired=false
    for pkg in "$@"; do
        if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            _run_cmd "NVIDIA" "sudo dpkg-reconfigure $pkg" "Reconfiguring $pkg..."
            repaired=true
            break
        fi
    done
    if ! $repaired; then
        echo -e "${RED}No DKMS package found to reconfigure.${NC}"
    fi

    if _nvidia_dkms_installed; then
        _warn_secure_boot
        echo -e "${GREEN}DKMS module compiled successfully for ${kernel}. Reboot required.${NC}"
        echo "──────────────────────────────────────────────"
        return 0
    else
        echo -e "${RED}DKMS module still not compiled for ${kernel}.${NC}"
        echo "Check the build log manually:"
        echo "  /var/lib/dkms/nvidia*/.../build/make.log"
        echo "  dmesg | grep nvidia"
        echo "──────────────────────────────────────────────"
        return 1
    fi
}

# -------------------------------------------------------------------
# NVIDIA driver version selection (Debian 12/13)
# Sets the global NVIDIA_SELECTED_VERSION; first option is the default.
# Returns: 0 if a version was chosen, 1 if the user cancelled
# -------------------------------------------------------------------
_is_cuda_repo_ready() {
    [ -f /etc/apt/sources.list.d/extrepo_nvidia-cuda.sources ] || \
        grep -qr 'developer.download.nvidia.com' /etc/apt/sources.list.d/ 2>/dev/null
}

_show_nvidia_version_menu() {
    local choice
    if [ "$DEBIAN_VERSION" = "12" ]; then
        choice=$(_menu "NVIDIA Driver Version" "Select the NVIDIA driver version for Debian 12 (Bookworm):" 12 70 3 \
            "535" "Official NVIDIA driver (Recommended)" \
            "470" "Legacy 470 (Kepler/Tesla GPUs)")
    elif [ "$DEBIAN_VERSION" = "13" ]; then
        choice=$(_menu "NVIDIA Driver Version" "Select the NVIDIA driver version for Debian 13 (Trixie):" 14 70 5 \
            "550" "Official Debian driver (Recommended)" \
            "590" "NVIDIA Repo v590 (Turing/Ampere/Ada/Blackwell)" \
            "595" "NVIDIA Repo v595 (Latest)")
    else
        NVIDIA_SELECTED_VERSION="auto"
        return 0
    fi
    [ -z "$choice" ] && return 1
    NVIDIA_SELECTED_VERSION="$choice"
    return 0
}

# -------------------------------------------------------------------
# NVIDIA Wayland/KMS base configuration (/etc/modprobe.d/nvidia-wayland.conf)
# Applies on Debian 12/13, any driver version (535/550/590/595).
# Arquitectura y detección híbrida son ORTOGONALES:
#   - Arquitectura → afecta SOLO fbdev (kepler: el 470 no lo soporta)
#     y el color/mensaje informativo.
#   - Híbrida vs desktop → afecta NVreg (Preserve / kernel suspend
#     notifier), INDEPENDIENTE de la arquitectura.
# 590/595 añaden el kernel suspend notifier (complementa, nunca
# reemplaza, NVreg_PreserveVideoMemoryAllocations).
# -------------------------------------------------------------------
_configure_nvidia_wayland() {
    local ver="${1:-$NVIDIA_SELECTED_VERSION}"
    local conf="/etc/modprobe.d/nvidia-wayland.conf"
    local arch
    local content=""
    local color="${GREEN}"
    local msg="Wayland config (desktop): KMS + video memory preservation enabled."
    arch=$(_get_nvidia_arch_family)

    # ── Arquitectura: solo fbdev y mensaje de color ──
    case "$arch" in
        kepler)
            color="${RED}"
            msg="WARNING: Wayland not supported on Kepler. Use X11 (Xorg)."
            ;;
        maxwell|pascal)
            color="${YELLOW}"
            msg="Wayland support on ${arch} is experimental. X11 recommended."
            ;;
    esac

    # ── Híbrida vs desktop: NVreg independiente de la arquitectura ──
    if _is_hybrid_laptop; then
        content="options nvidia-drm modeset=1"$'\n'
        [ "$arch" != "kepler" ] && content+="options nvidia-drm fbdev=1"$'\n'
        color="${GREEN}"
        msg="Wayland config (hybrid laptop): KMS enabled — NVreg omitted."
    else
        content="options nvidia NVreg_PreserveVideoMemoryAllocations=1"$'\n'
        case "$ver" in
            590|595) content+="options nvidia NVreg_UseKernelSuspendNotifiers=1"$'\n' ;;
        esac
        content+="options nvidia-drm modeset=1"$'\n'
        [ "$arch" != "kepler" ] && content+="options nvidia-drm fbdev=1"$'\n'
    fi

    printf "%b" "$content" | sudo tee "$conf" >/dev/null
    echo -e "${color}${msg}${NC}"
}

# -------------------------------------------------------------------
# CASE A: Trixie + Backports Kernel → Official CUDA Repo (Pinned v590)
# -------------------------------------------------------------------
_install_nvidia_cuda_repo() {
    local ver="${1:-590}"
    local warn="WARNING: You are about to install NVIDIA v${ver} from\n"
    warn+="the official NVIDIA CUDA repository.\n\n"
    warn+="Source: Official NVIDIA CUDA Repo (Pinned v${ver}.*)\n"
    warn+="Driver: Production Branch v${ver} (unified metapackage)\n"
    warn+="[+] nvidia-driver (full 64-bit compute + graphics)\n"
    warn+="[+] nvidia-kernel-dkms / nvidia-kernel-open-dkms (vía metapaquete)\n"
    warn+="[+] firmware-nvidia-gsp\n"
    warn+="[+] nvidia-driver-pinning-${ver} (if available)\n"
    warn+="[+] APT Pinning (version ${ver}.*)\n\n"
    warn+="Do you want to proceed at your own risk?"

    if ! _confirm_custom "NVIDIA Driver — v${ver}" "$warn" "Proceed" "Abort" 18 70; then
        echo -e "${YELLOW}NVIDIA installation aborted by user.${NC}"
        return 1
    fi

    # Step 1: Enable CUDA repo via extrepo
    if ! _enable_cuda_repo; then
        _msg "CUDA Repo — Error" "Failed to enable the official NVIDIA CUDA repository.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Step 2: Create APT pinning to lock to the selected branch
    if ! _run_cmd "APT Pinning" \
        "printf '%s\n' \"Package: *nvidia*\" \"Package: *cuda*\" \"Package: libcuda1\" \"Package: firmware-nvidia-gsp\" \"Pin: version ${ver}.*\" \"Pin-Priority: 1001\" | sudo tee /etc/apt/preferences.d/block-nvidia > /dev/null" \
        "Creating APT pinning to lock NVIDIA to v${ver} branch..."; then
        _msg "APT Pinning — Error" "Failed to write APT pinning.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Step 3: Install NVIDIA unified metapackages (driver pinning)
    local pin_meta="nvidia-driver-pinning-${ver}"
    local install_cmd="nvidia-driver firmware-nvidia-gsp"
    if apt-cache policy "$pin_meta" 2>/dev/null | grep -q "Candidate: [^ (none)]"; then
        install_cmd="$pin_meta $install_cmd"
    else
        echo -e "${YELLOW}${pin_meta} not available in the NVIDIA repo — using APT pinning only.${NC}"
    fi
    if ! _run_cmd "NVIDIA CUDA" \
        "sudo apt install -y $install_cmd" \
        "Installing NVIDIA v${ver} production driver via unified metapackages..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA — Error" "NVIDIA v${ver} installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Post-install: el módulo DKMS instalado debe coincidir con la rama ${ver}
    local dkms_ver
    dkms_ver=$(dpkg -l nvidia-kernel-dkms nvidia-kernel-open-dkms 2>/dev/null | awk '$1=="ii" {print $3; exit}')
    if [[ "$dkms_ver" == ${ver}.* ]]; then
        echo -e "${GREEN}DKMS module ${dkms_ver} matches branch v${ver}.${NC}"
    else
        echo -e "${RED}WARNING: DKMS package (${dkms_ver:-none}) does not match v${ver}.*${NC}"
    fi

    NVIDIA_DRIVER_MODE="cuda-repo"
    echo -e "${GREEN}NVIDIA Production Driver v${ver} installed from CUDA repo. Reboot required.${NC}"

    _verify_nvidia_dkms_build nvidia-kernel-open-dkms nvidia-kernel-dkms || true
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

    if ! _run_cmd "NVIDIA" "sudo apt install -y -t bookworm-backports $nv_pkg firmware-misc-nonfree nvidia-vaapi-driver" \
        "Installing NVIDIA driver from backports..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA — Error" "NVIDIA backports installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    NVIDIA_DRIVER_MODE="backports"
    echo -e "${GREEN}NVIDIA driver installed from backports. Reboot required.${NC}"

    _verify_nvidia_dkms_build nvidia-kernel-dkms nvidia-tesla-470-kernel-dkms || true
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
    msg+="  [+]   linux-headers-amd64\n"
    msg+="  [+]   firmware-misc-nonfree\n"
    msg+="  [+]   nvidia-settings\n\n"
    msg+="Instalar driver legacy para Kepler?"

    if ! _confirm_custom "NVIDIA Kepler — Bookworm" "$msg" "Install" "Skip" 14 70; then
        echo "Omitiendo driver Kepler."
        NVIDIA_DRIVER_MODE=""
        return 0
    fi

    if ! _run_cmd "NVIDIA Kepler" \
        "sudo apt install -y linux-headers-amd64 $nv_pkg firmware-misc-nonfree nvidia-settings" \
        "Instalando nvidia-legacy-470xx-driver..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA Kepler — Error" "Kepler driver installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Si backports está habilitado, ofrecer actualización
    if [ "$(is_backports_enabled)" == "true" ]; then
        local bpo_ver
        bpo_ver=$(apt-cache madison "$nv_pkg" 2>/dev/null | \
            grep "bookworm-backports" | awk '{print $3}' | head -1) || true
        if [ -n "$bpo_ver" ]; then
            local msg="Hay una versión en backports: ${bpo_ver}\n"
            msg+="Instalar desde bookworm-backports?"
            if _confirm "Kepler Backports" "$msg"; then
                if _run_cmd "NVIDIA Kepler" \
                    "sudo apt install -y -t bookworm-backports $nv_pkg" \
                    "Actualizando Kepler driver desde backports..."; then
                    NVIDIA_DRIVER_MODE="backports"
                    echo -e "${GREEN}Kepler driver actualizado desde backports.${NC}"
                else
                    echo -e "${RED}Kepler backports upgrade failed — keeping the stable version.${NC}"
                fi
            fi
        fi
    fi

    NVIDIA_DRIVER_MODE="${NVIDIA_DRIVER_MODE:-stable}"
    echo -e "${GREEN}Kepler driver (${nv_pkg}) installed. Reboot required.${NC}"

    _verify_nvidia_dkms_build nvidia-tesla-470-kernel-dkms || true
}

# -------------------------------------------------------------------
# CASE C: Kernel stable (any distro) → Debian stable, optional backports
# -------------------------------------------------------------------
_install_nvidia_standard() {
    # --- 1. DETERMINAR PAQUETES BASADO EN LA SEÑAL ---
    # $1 = modo solicitado por el dispatcher ("open" para 550+Turing+);
    #     si no se pasa, se usa NVIDIA_DRIVER_MODE o auto-detección.
    local requested_mode="${1:-${NVIDIA_DRIVER_MODE:-auto}}"
    local nv_pkg="nvidia-driver"
    local kernel_pkg=""
    local use_bpo=false

    case "$requested_mode" in
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
    msg+="[+] linux-headers-amd64\n"
    msg+="[+] firmware-misc-nonfree (o firmware-nvidia-gsp en Trixie)\n"
    msg+="[+] nvidia-vaapi-driver"
    [ "$DEBIAN_VERSION" = "12" ] && msg+="\n[+] mesa-vdpau-drivers"

    if ! _confirm "NVIDIA Driver" "$msg" 14 70; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    # --- 4. EJECUCIÓN ---
    local extra_pkgs="linux-headers-amd64 firmware-misc-nonfree nvidia-vaapi-driver"
    [ "$DEBIAN_VERSION" = "12" ] && extra_pkgs+=" mesa-vdpau-drivers"
    local install_pkgs="$kernel_pkg $nv_pkg $extra_pkgs"

    if $use_bpo; then
        if ! _run_cmd "NVIDIA" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $install_pkgs" \
            "Installing NVIDIA driver from backports..."; then
            NVIDIA_DRIVER_MODE=""
            _msg "NVIDIA — Error" "NVIDIA driver installation from backports FAILED.\n\nNo NVIDIA driver was installed." 10 60
            return 1
        fi
        NVIDIA_DRIVER_MODE="backports"
    else
        if ! _run_cmd "NVIDIA" "sudo apt install -y $install_pkgs" \
            "Installing NVIDIA driver from stable..."; then
            NVIDIA_DRIVER_MODE=""
            _msg "NVIDIA — Error" "NVIDIA driver installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
            return 1
        fi
        NVIDIA_DRIVER_MODE="stable"
    fi

    # Fix obligatorio para Debian 12 con módulo abierto
    if [ "$DEBIAN_VERSION" = "12" ] && [[ "$kernel_pkg" == *"open"* ]]; then
        echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" | sudo tee /etc/modprobe.d/nvidia-open.conf > /dev/null
        echo "Applied required Open RM parameter for Debian 12."
    fi

    # --- 5. VERIFICACIÓN DKMS POST-INSTALL ---
    echo -e "${GREEN}NVIDIA driver installed. Reboot required.${NC}"
    _verify_nvidia_dkms_build "$kernel_pkg" || true
}
