#!/usr/bin/env bash
# Shared helpers for gaming submodules

_install_mesa_32bit() {
    local base_pkgs=(
        "mesa-vulkan-drivers"
        "libgl1-mesa-dri"
        "libglx-mesa0"
        "libegl-mesa0"
        "mesa-libgallium"
    )

    local i386_active=false
    dpkg --print-foreign-architectures 2>/dev/null | grep -q i386 && i386_active=true

    local install_list=()

    for p in "${base_pkgs[@]}"; do
        if apt-cache show "$p" >/dev/null 2>&1; then
            install_list+=("$p")
        fi
        if $i386_active && apt-cache show "${p}:i386" >/dev/null 2>&1; then
            install_list+=("${p}:i386")
        fi
    done

    if [ ${#install_list[@]} -eq 0 ]; then
        echo "No Mesa 32-bit packages available for installation."
        return
    fi

    # ── Resolve versions for display ──
    local rep_pkg="${base_pkgs[0]}"
    local stable_ver=""
    stable_ver=$(apt-cache policy "$rep_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
    local bpo_ver=""
    if [ "$DEBIAN_VERSION" = "13" ] && [ "$(is_backports_enabled)" = "true" ]; then
        bpo_ver=$(apt-cache madison "$rep_pkg" 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1) || true
    fi

    local check_pkg="libgl1-mesa-dri:i386"

    # ── Already installed branch ──
    if is_installed "$check_pkg"; then
        if [ -n "$bpo_ver" ]; then
            local current_ver
            current_ver=$(dpkg -l "$check_pkg" 2>/dev/null | awk '/^ii/{print $3}') || true
            if _confirm "Mesa 32-bit" \
                "Mesa 32-bit libraries ${current_ver:+v${current_ver} }already installed.\n\nReinstall from backports v${bpo_ver}?"; then
                echo "Reinstalling Mesa 32-bit from backports..."
                _run_cmd "Mesa 32-bit" \
                    "sudo apt install -y --reinstall -t ${DEBIAN_CODENAME}-backports ${install_list[*]}" \
                    "Reinstalling Mesa 32-bit from backports..."
                echo -e "${GREEN}Mesa 32-bit libraries reinstalled.${NC}"
                return
            fi
        fi
        echo "Mesa 32-bit libraries already installed."
        return
    fi

    # ── Not installed branch ──
    local apt_target=""
    if [ -n "$bpo_ver" ]; then
        local msg="Backports repository is enabled.\n\n"
        msg+="Available versions for Mesa 32-bit:\n"
        msg+="  - Stable:   v${stable_ver:-unknown}\n"
        msg+="  - Backports: v${bpo_ver}\n\n"
        msg+="Install from Backports or Stable?"
        if _confirm_custom "Mesa 32-bit" "$msg" "Backports" "Stable" 14 70; then
            apt_target="-t ${DEBIAN_CODENAME}-backports"
        fi
    fi

    _run_cmd "Mesa 32-bit" "sudo apt install -y $apt_target ${install_list[*]}" \
        "Installing Mesa drivers (${#install_list[@]} packages)..."
    echo -e "${GREEN}Mesa 32-bit libraries installed.${NC}"
}

apt_cache_exists() {
    apt-cache show "$1" >/dev/null 2>&1
}

_detect_installed_nvidia_driver() {
    dpkg -l 2>/dev/null | awk '
        /^ii/ && ($2=="nvidia-driver" || $2=="nvidia-open" ||
                  $2 ~ /^nvidia-legacy-[0-9]+xx-driver$/ ||
                  $2 ~ /^nvidia-tesla-[0-9]+-driver$/) {print $2; exit}'
}

_nvidia_libs_pkg() {
    case "$1" in
        nvidia-driver|nvidia-open) echo "nvidia-driver-libs" ;;
        *) echo "${1}-libs" ;;
    esac
}

_install_nvidia_32bit() {
    local drv_pkg
    drv_pkg=$(_detect_installed_nvidia_driver)
    if [ -z "$drv_pkg" ]; then
        _msg "NVIDIA 32-bit" \
            "No NVIDIA driver detected.\n\nRun Graphics Drivers (option 5) first,\nthen return to add 32-bit libraries." 10 60
        return 0
    fi

    local drv_ver
    drv_ver=$(dpkg -s "$drv_pkg" 2>/dev/null | sed -n 's/^Version: //p')
    local libs_pkg
    libs_pkg=$(_nvidia_libs_pkg "$drv_pkg")

    if ! apt_cache_exists "${libs_pkg}:i386"; then
        _msg "NVIDIA 32-bit" \
            "No ${libs_pkg}:i386 available for your driver (${drv_pkg}).\nSkipping 32-bit NVIDIA libraries." 10 60
        return 0
    fi

    if _confirm "NVIDIA 32-bit" \
        "Driver: ${drv_pkg} ${drv_ver}\n\nInstall ${libs_pkg}:i386 (same version to prevent ABI mismatch)." 12 70; then
        _run_cmd "NVIDIA 32-bit" "sudo apt install -y ${libs_pkg}:i386=${drv_ver}" \
            "Installing 32-bit NVIDIA libraries (${drv_ver})..."
    fi
}
