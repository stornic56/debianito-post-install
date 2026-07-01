#!/usr/bin/env bash
# legacy.sh — Bullseye: hardware detection, NVIDIA legacy drivers, lightweight gaming
# License GPL v3

BULLSEYE_USE_ARCHIVE=false
BULLSEYE_USE_ARCHIVE_CHECKED=false

check_bullseye_archive_phase() {
    $BULLSEYE_USE_ARCHIVE_CHECKED && return
    BULLSEYE_USE_ARCHIVE_CHECKED=true

    local current_year
    local current_month
    current_year=$(date +%Y)
    current_month=$(date +%-m)

    if [ "$current_year" -gt 2026 ] || \
       { [ "$current_year" -eq 2026 ] && [ "$current_month" -ge 9 ]; }; then
        BULLSEYE_USE_ARCHIVE=true
    fi

    if $BULLSEYE_USE_ARCHIVE; then
        _msg "Debian 11 — Archive Phase" \
            "Bullseye LTS support ended on 31 Aug 2026.\n\n\
The script will use archive.debian.org mirrors.\n\
No security updates will be available." 12 60
    fi
}

# ---------------------------------------------------------------------------
# NVIDIA driver installer for Bullseye (Kepler → 470, Fermi → 390)
# ---------------------------------------------------------------------------
install_nvidia_bullseye() {
    echo -e "${YELLOW}NVIDIA GPU detected (Bullseye mode).${NC}"

    local is_fermi;   is_fermi=$(is_nvidia_fermi)

    local nv_pkg=""
    local gpu_gen=""

    if [ "$is_fermi" = "true" ]; then
        nv_pkg="nvidia-legacy-390xx-driver"
        gpu_gen="Fermi"
    else
        # Bullseye: cualquier otra NVIDIA (Kepler incl.) → nvidia-driver (470)
        nv_pkg="nvidia-driver"
        gpu_gen="NVIDIA"
    fi

    local nv_ver
    nv_ver=$(apt-cache policy "$nv_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')

    local msg="Source: Debian Bullseye Stable\n"
    msg+="Driver: ${gpu_gen} — ${nv_pkg} ${nv_ver:-unknown}\n"
    msg+="[+] firmware-misc-nonfree\n"
    msg+="[+] nvidia-settings\n\n"
    msg+="Instalar driver NVIDIA?"

    if ! _confirm "NVIDIA — Bullseye" "$msg" 14 70; then
        echo "Omitiendo driver NVIDIA."
        NVIDIA_DRIVER_MODE=""
        return 0
    fi

    _run_cmd "NVIDIA" \
        "sudo apt install -y $nv_pkg firmware-misc-nonfree nvidia-settings" \
        "Instalando driver NVIDIA ${gpu_gen}..."

    local i386_active=false
    dpkg --print-foreign-architectures | grep -q i386 && i386_active=true
    if $i386_active; then
        local nv32_pkg="${nv_pkg}:i386"
        local nv32_ver
        nv32_ver=$(apt-cache policy "$nv32_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if [ -n "$nv32_ver" ] && [ "$nv32_ver" != "(none)" ]; then
            echo "Installing 32-bit compatibility for ${nv_pkg}..."
            _run_cmd "NVIDIA 32-bit" "sudo apt install -y $nv32_pkg" \
                "Installing NVIDIA 32-bit libraries..."
        else
            echo "No 32-bit compatibility package available for ${nv_pkg} on Bullseye."
        fi
    fi

    NVIDIA_DRIVER_MODE="stable"
    echo -e "${GREEN}Driver NVIDIA ${nv_pkg} instalado. Requiere reinicio.${NC}"

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

# ---------------------------------------------------------------------------
# Lightweight Gaming for Bullseye — sin Steam, sin Heroic
# 32-bit Mesa/NVIDIA + gamemode + mangohud + goverlay + lutris
# ---------------------------------------------------------------------------
install_gaming_bullseye() {
    echo -e "${YELLOW}Lightweight Gaming (Bullseye mode).${NC}"

    local enable_32bit=false
    if _confirm "32-bit Support" \
        "Enable i386 architecture for 32-bit games?\n\n\
Required by Steam/Proton for 32-bit games.\n\
Installs matching 32-bit graphics drivers."; then
        enable_32bit=true
    fi

    if $enable_32bit; then
        echo "Enabling i386 multi-architecture support..."
        if ! dpkg --print-foreign-architectures | grep -q i386; then
            sudo dpkg --add-architecture i386
        fi
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."

        if [ "$GPU_TYPE" = "nvidia" ]; then
            local nv32_pkg="nvidia-driver-libs:i386"
            local nv32_ver
            nv32_ver=$(apt-cache policy "$nv32_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
            if [ -n "$nv32_ver" ] && [ "$nv32_ver" != "(none)" ]; then
                local msg="Source: Debian Bullseye Stable\n"
                msg+="NVIDIA 32-bit Libraries ${nv32_ver}\n\n"
                msg+="[+] nvidia-driver-libs:i386"
                if _confirm "NVIDIA 32-bit" "$msg" 12 70; then
                    _run_cmd "32-bit NVIDIA" "sudo apt install -y ${nv32_pkg}" \
                        "Installing NVIDIA 32-bit libraries..."
                fi
            else
                echo "nvidia-driver-libs:i386 not available on Bullseye."
            fi
        else
            # Mesa 32-bit
            local mesa_32=(
                "mesa-vulkan-drivers:i386"
                "libgl1-mesa-dri:i386"
                "libglx-mesa0:i386"
                "libegl-mesa0:i386"
                "mesa-va-drivers:i386"
            )
            local ref_ver
            ref_ver=$(apt-cache policy "mesa-vulkan-drivers:i386" 2>/dev/null | \
                awk 'NR==3 {print $2; exit}')
            local comp_line="Components: Vulkan:i386, OpenGL:i386, GLX:i386, EGL:i386, VA-API:i386"

            local msg="Mesa 32-bit drivers for gaming.\n\n"
            msg+="Source: Debian Bullseye Stable\n"
            msg+="Mesa ${ref_ver}\n"
            msg+="${comp_line}\n\n"
            msg+="Install 32-bit drivers?"

            if _confirm "Mesa 32-bit" "$msg" 14 70; then
                _run_cmd "Mesa 32-bit" "sudo apt install -y ${mesa_32[*]}" \
                    "Installing Mesa 32-bit..."
            fi
        fi
    fi

    # Gaming tools checklist (no Steam, no Heroic)
    local choices
    choices=$(whiptail --title "Gaming Tools — Bullseye" --checklist \
        "Select gaming optimization tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "gamemode" "Game performance optimization" ON \
        "mangohud" "Performance overlay (Vulkan/OpenGL)" ON \
        "goverlay" "MangoHud config GUI" ON \
        "lutris"   "Game launcher/manager" OFF \
        "java"     "Java Runtimes (8, 17, 21)" OFF \
        3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        echo "No gaming tools selected."
        _pause
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            mangohud)
                local mh_pkgs="mangohud"
                if $enable_32bit; then
                    local mh32_ver
                    mh32_ver=$(apt-cache policy mangohud:i386 2>/dev/null | \
                        awk 'NR==3 {print $2; exit}')
                    if [ -n "$mh32_ver" ] && [ "$mh32_ver" != "(none)" ]; then
                        mh_pkgs+=" mangohud:i386"
                    fi
                fi
                _run_cmd "MangoHud" "sudo apt install -y $mh_pkgs" "Installing MangoHud (64 + 32-bit)..."
                ;;
            gamemode)  _run_cmd "GameMode" "sudo apt install -y gamemode" "Installing GameMode..." ;;
            goverlay)  _run_cmd "GOverlay" "sudo apt install -y goverlay" "Installing GOverlay..." ;;
            lutris)
                local pkgs="lutris wine64"
                if dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
                    pkgs+=" wine32"
                fi
                _run_cmd "Lutris" "sudo apt install -y $pkgs" "Installing Lutris + Wine..."
                ;;
            java)      _install_gaming_java ;;
            *)         _run_install "$pkg" ;;
        esac
    done

    echo -e "${GREEN}Lightweight gaming setup complete.${NC}"
    _pause
}
