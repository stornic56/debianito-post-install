#!/usr/bin/env bash
# Install gaming tools (Steam, gamemode, mangohud, etc.)

install_gaming() {
    echo -e "${YELLOW}Gaming setup...${NC}"

    local choices
    choices=$(whiptail --title "Gaming Setup" --checklist \
        "Select gaming packages to install:" 15 70 5 \
        "steam" "Steam (official .deb from Valve, requires 32-bit)" ON \
        "gamemode" "Optimise system for gaming" ON \
        "mangohud" "Vulkan/OpenGL performance overlay" ON \
        "goverlay" "GUI for configuring MangoHud" OFF \
        "lutris" "Game launcher/runner" OFF \
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
        echo "Backports enabled. Installing newer Mesa from backports..."
        sudo apt install -y -t "${DEBIAN_CODENAME}-backports" libgl1-mesa-dri mesa-vulkan-drivers
        if dpkg --print-foreign-architectures | grep -q i386; then
            sudo apt install -y -t "${DEBIAN_CODENAME}-backports" libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386
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
            *)
                sudo apt install -y "$pkg"
                ;;
        esac
    done

    echo -e "${GREEN}Gaming setup complete.${NC}"
}
