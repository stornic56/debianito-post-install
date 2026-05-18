#!/usr/bin/env bash
# Install gaming tools (Steam, gamemode, mangohud, etc.)

install_gaming() {
    echo -e "${YELLOW}Gaming setup...${NC}"

    # 1. 32-bit support prompt FIRST
    local enable_32bit=false
    if whiptail --title "32-bit Support" --yesno \
        "Enable 32-bit architecture for gaming?\n\nThis enables i386 support and installs 32-bit\ngraphics drivers needed by Steam and Proton\nfor running 32-bit games with GPU acceleration.\n\nRequired for: Steam\nRecommended for: old games via Wine/Proton\n\nProceed?" 15 65; then
        enable_32bit=true
    fi

    if $enable_32bit; then
        echo "Enabling 32-bit architecture (i386)..."
        if ! dpkg --print-foreign-architectures | grep -q i386; then
            sudo dpkg --add-architecture i386
        fi
        sudo apt update

        echo "Installing 32-bit graphics drivers..."
        if [ "$GPU_TYPE" = "nvidia" ]; then
            sudo apt install -y nvidia-driver-libs:i386
        else
            sudo apt install -y mesa-vulkan-drivers libglx-mesa0:i386 mesa-vulkan-drivers:i386 libgl1-mesa-dri:i386
        fi
    fi

    # 2. Gaming packages checklist
    local choices
    choices=$(whiptail --title "Gaming Setup" --checklist \
        "Select gaming packages to install:" 16 72 6 \
        "steam" "Steam (official .deb from Valve, requires 32-bit)" ON \
        "gamemode" "Optimise system for gaming" ON \
        "mangohud" "Vulkan/OpenGL performance overlay" ON \
        "heroic" "Heroic Games Launcher (Epic Games, GOG) - .deb" OFF \
        "goverlay" "GUI for configuring MangoHud" ON \
        "lutris" "Game launcher/runner" OFF \
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
                echo "Downloading official Steam .deb..."
                local steam_deb="/tmp/steam_latest.deb"
                wget -O "$steam_deb" "https://cdn.fastly.steamstatic.com/client/installer/steam.deb"
                sudo apt install -y "$steam_deb"
                ;;
            mangohud)
                sudo apt install -y mangohud
                if $enable_32bit; then
                    echo "Installing 32-bit MangoHud..."
                    sudo apt install -y mangohud:i386
                fi
                ;;
            heroic)
                echo "Downloading Heroic Games Launcher..."
                sudo apt install -y curl wget 2>/dev/null || true
                local heroic_deb="/tmp/heroic.deb"
                local gh_url
                gh_url=$(curl -s https://api.github.com/repos/Heroic-Games-Launcher/\
HeroicGamesLauncher/releases/latest | \
                    grep -oP 'https://[^"]+amd64\.deb' | head -1)
                if [ -z "$gh_url" ]; then
                    echo -e "${RED}Could not determine latest Heroic release.${NC}"
                else
                    wget -O "$heroic_deb" "$gh_url"
                    sudo apt install -y "$heroic_deb"
                    rm -f "$heroic_deb"
                    echo -e "${GREEN}Heroic Games Launcher installed.${NC}"
                fi
                ;;
            *)
                sudo apt install -y "$pkg"
                ;;
        esac
    done

    echo -e "${GREEN}Gaming setup complete.${NC}"
}
