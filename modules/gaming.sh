#!/usr/bin/env bash
# Gaming dispatcher — sources submodules and provides install_gaming()

_GAMING_DIR="${MODULES_DIR}/gaming"
source "${_GAMING_DIR}/_helpers.sh"
source "${_GAMING_DIR}/steam.sh"
source "${_GAMING_DIR}/heroic.sh"
source "${_GAMING_DIR}/tools.sh"

# Check if 'contrib' component is enabled; offer to add if missing
ensure_contrib_repo() {
    local contrib_found=false

    if [ -f /etc/apt/sources.list ]; then
        if grep -Eq '^[^#]*\bcontrib\b' /etc/apt/sources.list 2>/dev/null; then
            contrib_found=true
        fi
    fi

    if ! $contrib_found && [ -d /etc/apt/sources.list.d ]; then
        if grep -qr 'Components:.*\bcontrib\b' /etc/apt/sources.list.d/*.sources 2>/dev/null; then
            contrib_found=true
        fi
    fi

    if $contrib_found; then
        return 0
    fi

    if _confirm "contrib Repository" "Component 'contrib' is required for Steam.\n\nAdd 'contrib' to your APT repositories?"; then
        if [ -f /etc/apt/sources.list ]; then
            sudo sed -i '/^deb / { /contrib/! s/main/main contrib/ }' /etc/apt/sources.list
        fi
        if [ -d /etc/apt/sources.list.d ]; then
            for f in /etc/apt/sources.list.d/*.sources; do
                [ -f "$f" ] || continue
                sudo sed -i '/^Components:/ { /contrib/! s/$/ contrib/ }' "$f"
            done
        fi
        sudo apt update
        echo -e "${GREEN}contrib repository enabled.${NC}"
        return 0
    fi

    echo -e "${YELLOW}contrib repository not enabled. Steam installation may fail.${NC}"
    return 1
}

install_gaming() {
    echo -e "${YELLOW}Gaming setup...${NC}"

    # 1. 32-bit support prompt FIRST
    local enable_32bit=false
    if _confirm "32-bit Support" "Enable i386 architecture for 32-bit games?\n\nRequired by Steam/Proton for 32-bit games.\nInstalls matching 32-bit graphics drivers."; then
        enable_32bit=true
    fi

    if $enable_32bit; then
        echo "Enabling 32-bit architecture (i386)..."
        if ! dpkg --print-foreign-architectures | grep -q i386; then
            sudo dpkg --add-architecture i386
        fi
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."

        echo "Installing 32-bit graphics drivers..."
        if [ "$GPU_TYPE" = "nvidia" ]; then
            case "${NVIDIA_DRIVER_MODE:-stable}" in
                cuda-repo)
                    local nv32_pkg="nvidia-driver-libs:i386"
                    local nv32_ver
                    nv32_ver=$(dpkg -l "$nv32_pkg" 2>/dev/null | awk '/^ii/ {print $3}')
                    if [ -z "$nv32_ver" ] || ! echo "$nv32_ver" | grep -q "^590"; then
                        local msg="Source: NVIDIA CUDA Repository (Pinned v590)\n"
                        msg+="NVIDIA 32-bit Libraries (v590 branch)\n\n"
                        msg+="[+] nvidia-driver-libs:i386"
                        if _confirm "NVIDIA 32-bit" "$msg" 12 70; then
                            _run_cmd "32-bit NVIDIA" \
                                "sudo apt install -y ${nv32_pkg}" \
                                "Installing 32-bit NVIDIA libraries from CUDA repo..."
                        fi
                    else
                        _msg "NVIDIA 32-bit" \
                            "32-bit NVIDIA CUDA libraries already deployed.\n\nv590 ${nv32_ver}" 10 70
                    fi
                    ;;
                backports)
                    local nv32_pkg="nvidia-driver-libs:i386"
                    local nv32_ver
                    nv32_ver=$(apt-cache policy "$nv32_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
                    local msg="Source: Debian ${DEBIAN_CODENAME^}-Backports\n"
                    msg+="NVIDIA 32-bit Libraries ${nv32_ver:-unknown}\n\n"
                    msg+="[+] nvidia-driver-libs:i386"
                    if _confirm "NVIDIA 32-bit" "$msg" 12 70; then
                        _run_cmd "32-bit NVIDIA" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${nv32_pkg}" \
                            "Installing 32-bit NVIDIA drivers from backports..."
                    fi
                    ;;
                stable)
                    local nv32_pkg="nvidia-driver-libs:i386"
                    local nv32_ver
                    nv32_ver=$(apt-cache policy "$nv32_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
                    local use_bpo32=false
                    if [ "$(is_backports_enabled)" == "true" ]; then
                        local bpo_nv32_ver
                        bpo_nv32_ver=$(apt-cache madison "$nv32_pkg" 2>/dev/null | \
                            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
                        if [ -n "$bpo_nv32_ver" ]; then
                            local msg="Source: Debian ${DEBIAN_CODENAME^} (Backports available)\n"
                            msg+="NVIDIA 32-bit Libraries: ${nv32_pkg}\n\n"
                            msg+="  Backports: ${bpo_nv32_ver}\n"
                            msg+="  Stable:    ${nv32_ver:-unknown}\n\n"
                            msg+="Choose version:"
                            if _confirm_custom "NVIDIA 32-bit" "$msg" "Backports" "Stable" 14 70; then
                                use_bpo32=true
                            fi
                        fi
                    fi
                    if $use_bpo32; then
                        _run_cmd "32-bit NVIDIA" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${nv32_pkg}" \
                            "Installing 32-bit NVIDIA drivers from backports..."
                    else
                        local msg="Source: Debian ${DEBIAN_CODENAME^} Stable\n"
                        msg+="NVIDIA 32-bit Libraries ${nv32_ver:-unknown}\n\n"
                        msg+="[+] nvidia-driver-libs:i386"
                        if _confirm "NVIDIA 32-bit" "$msg" 12 70; then
                            _run_cmd "32-bit NVIDIA" "sudo apt install -y ${nv32_pkg}" \
                                "Installing 32-bit NVIDIA drivers..."
                        fi
                    fi
                    ;;
            esac
        else
            _install_mesa_32bit
        fi
    fi

    # 2. Gaming packages checklist
    local choices
    choices=$(whiptail --title "Gaming Setup" --checklist \
        "Select gaming packages to install${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "steam"    "Steam (requires 32-bit support)" ON \
        "gamemode" "Game performance optimization" ON \
        "mangohud" "Performance overlay (Vulkan/OpenGL)" ON \
        "heroic"   "Heroic Launcher (Epic/GOG)" OFF \
        "java"     "Java Runtimes (8, 17, 21)" OFF \
        "goverlay" "MangoHud config GUI" ON \
        "openrgb"  "OpenRGB (RGB lighting control)$(_inst openrgb)" OFF \
        "lutris"   "Game launcher/manager" OFF \
        "retroarch" "RetroArch Emulator Frontend$(_inst retroarch)" OFF \
        3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        echo "No gaming packages selected."
        _pause
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    # 3. Warn if Steam selected without 32-bit
    if echo "$cleaned" | grep -qw "steam" && ! $enable_32bit; then
        echo -e "${YELLOW}Warning: Steam requires 32-bit support.${NC}"
        echo "Installation may fail. Re-run this option and enable 32-bit support."
    fi

    # 4. Install selected packages
    for pkg in $cleaned; do
        case $pkg in
            steam)
                if ensure_contrib_repo; then
                    install_steam
                else
                    echo -e "${YELLOW}Skipping Steam installation (contrib repository not enabled).${NC}"
                fi
                ;;
            heroic)   install_heroic ;;
            java)     install_minecraft_java ;;
            mangohud) install_mangohud ;;
            gamemode) install_gamemode ;;
            goverlay) install_goverlay ;;
            openrgb)
                if [ "$DEBIAN_VERSION" = "11" ]; then
                    echo "OpenRGB requires Debian 12+."
                    continue
                fi
                install_openrgb
                ;;
            lutris)   install_lutris ;;
            retroarch)  install_retroarch ;;
            *)        _run_install "$pkg" ;;
        esac
    done

    echo -e "${GREEN}Gaming setup complete.${NC}"
    _pause
}
