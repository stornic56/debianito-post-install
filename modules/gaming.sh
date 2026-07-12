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

    # 1. Single checklist with ALL options (including i386 toggle)
    local choices
    choices=$(_checklist "Gaming Setup" \
        "Select gaming packages to install${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "steam"    "Steam (requires 32-bit support)" ON \
        "gamemode" "Game performance optimization" ON \
        "mangohud" "Performance overlay (Vulkan/OpenGL)" ON \
        "goverlay" "MangoHud config GUI" ON \
        "heroic"   "Heroic Launcher (Epic/GOG)" OFF \
        "java"     "Minecraft Java Runtime" OFF \
        "openrgb"  "OpenRGB (RGB lighting control)" OFF \
        "lutris"   "Lutris + Wine (requires 32-bit support)" OFF \
        "retroarch" "RetroArch Emulator Frontend" OFF \
        "i386"     "Enable 32-bit (i386) architecture" ON)

    if [ -z "$choices" ]; then
        echo "No gaming packages selected."
        _pause
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    # 2. Determine if 32-bit is needed (steam, lutris, or explicit i386 toggle)
    local need_32bit=false
    for p in $cleaned; do
        case $p in steam|lutris) need_32bit=true ;; esac
    done
    echo "$cleaned" | grep -qw i386 && need_32bit=true

    # Strip pseudo-entry "i386" from the install list
    local install_list
    install_list=$(echo "$cleaned" | tr ' ' '\n' | grep -v '^i386$' | tr '\n' ' ')
    install_list=${install_list% }

    # 3. Enable i386 architecture if needed
    if $need_32bit && ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        echo -e "${YELLOW}Enabling i386 architecture (required by selection)...${NC}"
        sudo dpkg --add-architecture i386
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    fi

    # 4. Install 32-bit graphics drivers only if 32-bit is needed
    if $need_32bit; then
        echo "Installing 32-bit graphics drivers..."
        if [ "$GPU_TYPE" = "nvidia" ]; then
            _install_nvidia_32bit
        else
            _install_mesa_32bit
        fi
    fi

    # 5. Install selected packages
    for pkg in $install_list; do
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
