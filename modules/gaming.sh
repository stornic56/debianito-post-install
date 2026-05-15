#!/usr/bin/env bash
# Install gaming tools (Steam, gamemode, mangohud, etc.)

install_gaming() {
    echo -e "${YELLOW}Gaming setup...${NC}"

    local choices
    choices=$(whiptail --title "Gaming Setup" --checklist \
        "Select gaming packages to install:" 16 72 6 \
        "Steam" "Steam (official .deb from Valve, requires 32-bit)" ON \
        "Gamemode" "Optimise system for gaming" ON \
        "Mangohud" "Vulkan/OpenGL performance overlay" ON \
        "Heroic" "Heroic Games Launcher (Epic Games, GOG) - .deb" OFF \
        "Goverlay" "GUI for configuring MangoHud" ON \
        "Lutris" "Game launcher/runner" OFF \
        3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        echo "No gaming packages selected."
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    if echo "$cleaned" | grep -qw "steam"; then
        echo "Enabling 32-bit architecture (i386)..."
        sudo dpkg --add-architecture i386
        sudo apt update
    fi

    if [ "$(is_backports_enabled)" == true ]; then
        local mesa_pkgs
        mesa_pkgs=$(pkg_versions libgl1-mesa-dri mesa-vulkan-drivers)
        if whiptail --title "Backports Mesa" --yesno \
            "Install newer Mesa (GPU drivers) from backports?\n\n${mesa_pkgs}\nProceed?" 14 65; then
            sudo apt install -y -t "${DEBIAN_CODENAME}-backports" libgl1-mesa-dri mesa-vulkan-drivers
            if dpkg --print-foreign-architectures | grep -q i386; then
                sudo apt install -y -t "${DEBIAN_CODENAME}-backports" libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
            fi
        else
            echo "Skipping Mesa from backports."
        fi
    fi

    for pkg in $cleaned; do
        case $pkg in
            steam)
                echo "Downloading official Steam .deb..."
                local steam_deb="/tmp/steam_latest.deb"
                wget -O "$steam_deb" "https://cdn.fastly.steamstatic.com/client/installer/steam.deb"
                sudo apt install -y "$steam_deb"
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
