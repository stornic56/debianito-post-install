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
    echo -e "${YELLOW}Gaming setup (Bullseye)...${NC}"

    local choices
    choices=$(_checklist "Gaming Setup — Bullseye" \
        "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "i386"     "Enable 32-bit (i386) architecture" ON \
        "steam"    "Steam (requires 32-bit support)" ON \
        "mangohud" "Performance overlay (Vulkan/OpenGL)" ON \
        "gamemode" "Game performance optimization" OFF \
        "goverlay" "MangoHud config GUI" ON \
        "java"     "Minecraft Java Runtime" OFF \
        "lutris"   "Lutris + Wine (requires 32-bit support)" OFF \
        "retroarch" "RetroArch Emulator Frontend" OFF)

    if [ -z "$choices" ]; then
        echo "No gaming packages selected."
        _pause
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    local need_32bit=false
    for p in $cleaned; do
        case $p in steam|lutris) need_32bit=true ;; esac
    done
    echo "$cleaned" | grep -qw i386 && need_32bit=true

    local install_list
    install_list=$(echo "$cleaned" | tr ' ' '\n' | grep -v '^i386$' | tr '\n' ' ')
    install_list=${install_list% }

    if $need_32bit && ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        echo -e "${YELLOW}Enabling i386 architecture...${NC}"
        sudo dpkg --add-architecture i386
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    fi

    if $need_32bit; then
        echo "Installing 32-bit graphics drivers..."
        if [ "$GPU_TYPE" = "nvidia" ]; then
            _install_nvidia_32bit
        else
            _install_mesa_32bit
        fi
    fi

    for pkg in $install_list; do
        case $pkg in
            steam)
                if ensure_contrib_repo; then
                    install_steam
                else
                    echo -e "${YELLOW}Skipping Steam installation (contrib repository not enabled).${NC}"
                fi
                ;;
            java)     install_minecraft_java ;;
            mangohud) install_mangohud ;;
            gamemode) install_gamemode ;;
            goverlay) install_goverlay ;;
            lutris)   install_lutris ;;
            retroarch)  install_retroarch ;;
            *)        _run_install "$pkg" ;;
        esac
    done

    echo -e "${GREEN}Gaming setup complete.${NC}"
    _pause
}
