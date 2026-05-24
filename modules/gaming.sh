#!/usr/bin/env bash
# Install gaming tools (Steam, gamemode, mangohud, etc.)

install_gaming() {
    echo -e "${YELLOW}Gaming setup...${NC}"

    # 1. 32-bit support prompt FIRST
    local enable_32bit=false
    if _confirm "32-bit Support" "Enable i386 for 32-bit games?\n\nRequired by Steam/Proton.\nInstalls matching 32-bit graphics drivers."; then
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
            _run_cmd "32-bit" "sudo apt install -y nvidia-driver-libs:i386" "Installing 32-bit NVIDIA drivers..."
        else
            _run_cmd "32-bit" "sudo apt install -y mesa-vulkan-drivers libglx-mesa0:i386 mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386" "Installing 32-bit Mesa drivers..."
        fi
    fi

    # 2. Gaming packages checklist
    local choices
    choices=$(whiptail --title "Gaming Setup" --checklist \
        "Select gaming packages to install:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "steam"    "Steam (official .deb, needs 32-bit)" ON \
        "gamemode" "Game performance optimization" ON \
        "mangohud" "Performance overlay (Vulkan/GL)" ON \
        "heroic"   "Heroic Launcher (Epic/GOG) .deb" OFF \
        "goverlay" "MangoHud config GUI" ON \
        "lutris"   "Game launcher/manager" OFF \
        3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        echo "No gaming packages selected."
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
                local steam_deb="/tmp/steam_latest.deb"
                _run_cmd "Steam" "wget -O $steam_deb https://cdn.fastly.steamstatic.com/client/installer/steam.deb" "Downloading Steam..."
                _run_cmd "Steam" "sudo apt install -y $steam_deb" "Installing Steam..."
                echo -e "${GREEN}Steam installed.${NC}"
                ;;
            mangohud)
                _run_cmd "MangoHud" "sudo apt install -y mangohud" "Installing MangoHud..."
                if $enable_32bit; then
                    echo "Installing 32-bit MangoHud..."
                    _run_cmd "MangoHud" "sudo apt install -y mangohud:i386" "Installing 32-bit MangoHud..."
                fi
                ;;
            heroic)
                local heroic_deb="/tmp/heroic.deb"
                _run_cmd "Heroic" "sudo apt install -y curl wget" "Installing dependencies..."
                local gh_url
                gh_url=$(curl -s --connect-timeout 10 https://api.github.com/repos/Heroic-Games-Launcher/\
HeroicGamesLauncher/releases/latest | \
                    grep -oP 'https://[^"]+amd64\.deb' | head -1)
                if [ -z "$gh_url" ]; then
                    echo -e "${RED}Could not determine latest Heroic release.${NC}"
                else
                    _run_cmd "Heroic" "wget -O $heroic_deb $gh_url" "Downloading Heroic..."
                    _run_cmd "Heroic" "sudo apt install -y $heroic_deb" "Installing Heroic..."
                    rm -f "$heroic_deb"
                    echo -e "${GREEN}Heroic Games Launcher installed.${NC}"
                fi
                ;;
            *)
                _run_install "$pkg"
                ;;
        esac
    done

    echo -e "${GREEN}Gaming setup complete.${NC}"
}
