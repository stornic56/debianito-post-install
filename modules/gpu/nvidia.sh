#!/usr/bin/env bash
# NVIDIA GPU driver installation
#
# CASE A : Trixie + backports kernel → Official NVIDIA CUDA Repo (Pinned v590)
# CASE B : Kernel stable (any distro) → Debian stable
#
# Note: Debian 12 (Bookworm) backports reached EOL (2026-08-09);
# the NVIDIA flow only uses the stable repo for Debian 12.

# -------------------------------------------------------------------
# Shared helper: enable NVIDIA CUDA repo
#   Debian 13 (Trixie): cuda-keyring (official method — broken extrepo)
#   Debian 12 (Bookworm): extrepo nvidia-cuda (works)
# -------------------------------------------------------------------
_enable_cuda_repo() {
    _is_cuda_repo_ready && return 0

    if [ "$DEBIAN_VERSION" = "13" ]; then
        # Official NVIDIA method: cuda-keyring (extrepo does not
        # configure the repo correctly on Trixie)
        if dpkg -s cuda-keyring &>/dev/null; then
            return 0 # already installed → its .list already exists
        fi
        local tmp_deb
        tmp_deb=$(mktemp "${TMPDIR:-/tmp}/cuda-keyring.XXXXXX.deb") || return 1
        if ! wget -q "https://developer.download.nvidia.com/compute/cuda/repos/debian13/x86_64/cuda-keyring_1.1-1_all.deb" \
            -O "$tmp_deb"; then
            rm -f "$tmp_deb"
            _msg "CUDA Repo — Error" "Failed to download cuda-keyring.\n\nNo NVIDIA driver was installed." 10 60
            return 1
        fi
        if ! sudo dpkg -i "$tmp_deb"; then
            rm -f "$tmp_deb"
            _msg "CUDA Repo — Error" "Failed to install cuda-keyring.\n\nNo NVIDIA driver was installed." 10 60
            return 1
        fi
        rm -f "$tmp_deb"
        return 0
    fi

    # Debian 12 (y otros): extrepo nvidia-cuda
    if ! command -v extrepo &>/dev/null; then
        _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..." || return 1
    fi
    _run_cmd "CUDA Repo" \
        "sudo extrepo enable nvidia-cuda" \
        "Enabling official NVIDIA CUDA repository..." || return 1
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

# Non-fatal notice: the DKMS module is compiled but NOT signed.
# Advanced users can sign it with MOK; novices need to know why
# they will see a black screen after reboot. If mokutil is missing,
# nothing is shown (mokutil is not preinstalled on Debian).
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
    [ -f /etc/apt/sources.list.d/extrepo_nvidia-cuda.sources ] ||
        grep -qr 'developer.download.nvidia.com' /etc/apt/sources.list.d/ 2>/dev/null
}

_show_nvidia_version_menu() {
    local choice
    if [ "$DEBIAN_VERSION" = "12" ]; then
        choice=$(_menu "Select NVIDIA Driver for Debian 12 (Bookworm):" "Choose the NVIDIA driver version:" 12 70 3 \
            "535" "v535 — Debian Official (Recommended)" \
            "470" "v470 — Debian Legacy (Kepler Support)")
    elif [ "$DEBIAN_VERSION" = "13" ]; then
        choice=$(_menu "Select NVIDIA Driver for Debian 13 (Trixie):" "Choose the NVIDIA driver version:" 14 70 5 \
            "550" "v550 — Debian Official (Recommended)" \
            "590" "v590 — NVIDIA CUDA Repo (Production Branch)" \
            "595" "v595 — NVIDIA CUDA Repo (Newest Stable)")
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
# Architecture and hybrid detection are ORTHOGONAL:
#   - Architecture → affects ONLY fbdev (kepler: the 470 does not
#     support it) and the color/info message.
#   - Hybrid vs desktop → affects NVreg (Preserve / kernel suspend
#     notifier), INDEPENDENT of architecture.
# 590/595 add the kernel suspend notifier (complements, never
# replaces, NVreg_PreserveVideoMemoryAllocations).
# -------------------------------------------------------------------
_configure_nvidia_wayland() {
    local ver="${1:-$NVIDIA_SELECTED_VERSION}"
    local conf="/etc/modprobe.d/nvidia-wayland.conf"
    local arch
    local content=""
    local color="${GREEN}"
    local msg="Wayland config (desktop): KMS + video memory preservation enabled."
    arch=$(_get_nvidia_arch_family)

    # ── Architecture: fbdev only and color message ──
    case "$arch" in
    kepler)
        color="${RED}"
        msg="WARNING: Wayland not supported on Kepler. Use X11 (Xorg)."
        ;;
    maxwell | pascal)
        color="${YELLOW}"
        msg="Wayland support on ${arch} is experimental. X11 recommended."
        ;;
    esac

    # ── Hybrid vs desktop: NVreg independent of architecture ──
    if _is_hybrid_laptop; then
        content="options nvidia-drm modeset=1"$'\n'
        [ "$arch" != "kepler" ] && content+="options nvidia-drm fbdev=1"$'\n'
        color="${GREEN}"
        msg="Wayland config (hybrid laptop): KMS enabled — NVreg omitted."
    else
        content="options nvidia NVreg_PreserveVideoMemoryAllocations=1"$'\n'
        case "$ver" in
        590 | 595) content+="options nvidia NVreg_UseKernelSuspendNotifiers=1"$'\n' ;;
        esac
        content+="options nvidia-drm modeset=1"$'\n'
        [ "$arch" != "kepler" ] && content+="options nvidia-drm fbdev=1"$'\n'
    fi

    printf "%b" "$content" | sudo tee "$conf" >/dev/null || return 1
    echo -e "${color}${msg}${NC}"
}

# -------------------------------------------------------------------
# CASE A: Trixie + Backports Kernel → Official CUDA Repo (Pinned v590)
# -------------------------------------------------------------------
_install_nvidia_cuda_repo() {
    local ver="${1:-590}"
    local warn="WARNING: You are about to install NVIDIA v${ver} from\n"
    warn+="the official NVIDIA CUDA repository.\n\n"
    warn+="Source: Official NVIDIA CUDA Repo\n"
    warn+="Driver: Production Branch v${ver} (unified metapackage)\n"
    warn+="[+] nvidia-driver-pinning-${ver} (version lock)\n"
    warn+="[+] nvidia-open (driver + open kernel modules)\n\n"
    warn+="Do you want to proceed at your own risk?"

    if ! _confirm_custom "NVIDIA Driver — v${ver}" "$warn" "Proceed" "Abort" 18 70; then
        echo -e "${YELLOW}NVIDIA installation aborted by user.${NC}"
        return 1
    fi

    # Step 1: Enable CUDA repo (cuda-keyring Trixie / extrepo Bookworm)
    if ! _enable_cuda_repo; then
        _msg "CUDA Repo — Error" "Failed to enable the official NVIDIA CUDA repository.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Step 2: explicit apt update — without an updated index the repo
    # is invisible and apt would resolve the Debian candidate (v550)
    # instead of v${ver}.
    if ! _run_cmd "CUDA Repo" "sudo apt update" \
        "Updating package lists after enabling CUDA repository..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "CUDA Repo — Error" "Failed to update APT after enabling CUDA repo.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Step 3: Official pinning — INDEPENDENT and mandatory APT
    # transaction. APT reads /etc/apt/preferences.d/ at startup, not
    # during the transaction: the pinning must be installed BEFORE
    # installing the driver. If the repo does not publish it, it is
    # an NVIDIA repo problem: abort cleanly instead of installing a
    # version the user did not choose.
    if ! _run_cmd "NVIDIA Pinning" \
        "sudo apt install -y nvidia-driver-pinning-${ver}" \
        "Installing NVIDIA version pinning (${ver})..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA — Error" "Failed to install NVIDIA driver pinning ${ver}.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Step 4: Install the metapackage (pinning already active). If it
    # fails, the pinning remains installed (config only, not a problem).
    # firmware-nvidia-gsp arrives as a mandatory transitive dependency
    # (nvidia-open → nvidia-kernel-open-dkms → firmware-nvidia-gsp),
    # aligned with the official docs: apt -V install nvidia-open.
    if ! _run_cmd "NVIDIA CUDA" \
        "sudo apt install -y nvidia-open" \
        "Installing NVIDIA driver from CUDA repository..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA — Error" "NVIDIA driver installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    # Post-install: the installed DKMS module must match the ${ver} branch
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
# Bookworm Kepler interception — forces nvidia-legacy-470xx-driver
# -------------------------------------------------------------------
_install_nvidia_bookworm_kepler() {
    local nv_pkg="nvidia-tesla-470-driver"
    local nv_ver
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true

    echo -e "${YELLOW}Kepler GPU detected — forcing ${nv_pkg}.${NC}"

    local msg="Kepler GPU detected (GKxxx).\n\n"
    msg+="On Debian 12 Bookworm, Kepler requires the legacy\n"
    msg+="driver instead of the modern one. Using package:\n"
    msg+="  ${nv_pkg}  ${nv_ver:-unknown}\n"
    msg+="to avoid black-screen failures.\n\n"
    msg+="  [USE]  ${nv_pkg}\n"
    msg+="  [+]   linux-headers-amd64\n"
    msg+="  [+]   firmware-misc-nonfree\n"
    msg+="  [+]   nvidia-settings\n\n"
    msg+="Install the legacy driver for Kepler?"

    if ! _confirm_custom "NVIDIA Kepler — Bookworm" "$msg" "Install" "Skip" 14 70; then
        echo "Skipping Kepler driver."
        NVIDIA_DRIVER_MODE=""
        return 0
    fi

    if ! _run_cmd "NVIDIA Kepler" \
        "sudo apt install -y linux-headers-amd64 $nv_pkg firmware-misc-nonfree nvidia-settings" \
        "Installing nvidia-legacy-470xx-driver..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA Kepler — Error" "Kepler driver installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi

    NVIDIA_DRIVER_MODE="${NVIDIA_DRIVER_MODE:-stable}"
    echo -e "${GREEN}Kepler driver (${nv_pkg}) installed. Reboot required.${NC}"

    _verify_nvidia_dkms_build nvidia-tesla-470-kernel-dkms || true
}

# -------------------------------------------------------------------
# CASE B: Kernel stable (any distro) → Debian stable
# -------------------------------------------------------------------
_install_nvidia_standard() {
    # --- 1. ARCHITECTURE → KERNEL MODULE ---
    # Only Turing+ (known) uses the open module. Unknown/empty or
    # old architecture (Kepler/Fermi/Maxwell/Pascal/Volta) →
    # closed module as safe fallback.
    local fam
    fam=$(_get_nvidia_arch_family)
    local kernel_pkg="nvidia-kernel-dkms"
    case "$fam" in
    turing | ampere | ada | blackwell) kernel_pkg="nvidia-open-kernel-dkms" ;;
    esac

    # --- 2. PACKAGES — a single apt install ---
    local extra_pkgs="linux-headers-amd64 nvidia-driver firmware-nvidia-gsp nvidia-vaapi-driver"
    [ "$DEBIAN_VERSION" = "12" ] && extra_pkgs+=" mesa-vdpau-drivers"
    local install_pkgs="$kernel_pkg $extra_pkgs"

    # --- 3. CONFIRMATION MESSAGE ---
    local kernel_ver msg
    kernel_ver=$(apt-cache policy "$kernel_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true

    msg="Source: Debian ${DEBIAN_CODENAME^} Stable\n"
    msg+="Kernel Module: ${kernel_pkg} ${kernel_ver:-unknown} (arch: ${fam:-unknown})\n"
    msg+="[+] linux-headers-amd64\n"
    msg+="[+] firmware-nvidia-gsp\n"
    msg+="[+] nvidia-vaapi-driver"
    [ "$DEBIAN_VERSION" = "12" ] && msg+="\n[+] mesa-vdpau-drivers"

    if ! _confirm "NVIDIA Driver" "$msg" 14 70; then
        echo "Skipping NVIDIA driver installation."
        return 0
    fi

    # --- 4. EXECUTION ---
    if ! _run_cmd "NVIDIA" "sudo apt install -y $install_pkgs" \
        "Installing NVIDIA driver from stable..."; then
        NVIDIA_DRIVER_MODE=""
        _msg "NVIDIA — Error" "NVIDIA driver installation FAILED.\n\nNo NVIDIA driver was installed." 10 60
        return 1
    fi
    NVIDIA_DRIVER_MODE="stable"

    # Mandatory fix for Debian 12 with the open module
    if [ "$DEBIAN_VERSION" = "12" ] && [[ "$kernel_pkg" == *"open"* ]]; then
        echo "options nvidia NVreg_OpenRmEnableUnsupportedGpus=1" | sudo tee /etc/modprobe.d/nvidia-open.conf >/dev/null
        echo "Applied required Open RM parameter for Debian 12."
    fi

    # --- 5. DKMS POST-INSTALL VERIFICATION ---
    echo -e "${GREEN}NVIDIA driver installed. Reboot required.${NC}"
    _verify_nvidia_dkms_build "$kernel_pkg" || true
}
