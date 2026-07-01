#!/usr/bin/env bash
# Gaming performance tools installation

install_mangohud() {
    local pkgs="mangohud"
    if dpkg --print-foreign-architectures | grep -q i386; then
        pkgs+=" mangohud:i386"
    fi
    _run_cmd "MangoHud" "sudo apt install -y $pkgs" "Installing MangoHud (64 + 32-bit)..."
}

install_gamemode() {
    _run_install gamemode
}

install_goverlay() {
    _run_install goverlay
}

install_lutris() {
    local pkgs="lutris wine64"
    if dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
        pkgs+=" wine32"
    fi
    _run_cmd "Lutris" "sudo apt install -y $pkgs" "Installing Lutris + Wine..."
}

install_openrgb() {
    local url
    if [ "$DEBIAN_VERSION" = "12" ]; then
        url="https://codeberg.org/OpenRGB/OpenRGB/releases/download/release_candidate_1.0rc2/openrgb_1.0rc2_amd64_bookworm_0fca93e.deb"
    elif [ "$DEBIAN_VERSION" = "13" ]; then
        url="https://codeberg.org/OpenRGB/OpenRGB/releases/download/release_candidate_1.0rc2/openrgb_1.0rc2_amd64_trixie_0fca93e.deb"
    else
        echo "OpenRGB requires Debian 12 (Bookworm) or 13 (Trixie)."
        return 1
    fi

    local deb_path="/tmp/openrgb.deb"
    local ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    _run_cmd "OpenRGB" "curl -L -o ${deb_path} -A '${ua}' '${url}'" "Downloading OpenRGB..."

    if [ ! -s "${deb_path}" ]; then
        echo -e "${RED}[-]${NC} Download failed: empty or missing file."
        rm -f "${deb_path}"
        return 1
    fi

    echo -e "${GREEN}[+]${NC} Installing OpenRGB package..."
    if ! sudo apt install -y "${deb_path}"; then
        rm -f "${deb_path}"
        echo -e "${RED}[-]${NC} Package installation failed."
        return 1
    fi

    sudo modprobe i2c-dev
    if ! grep -q "^i2c-dev" /etc/modules 2>/dev/null; then
        echo "i2c-dev" | sudo tee -a /etc/modules >/dev/null
    fi
    sudo usermod -aG i2c "$USER"
    sudo udevadm control --reload-rules && sudo udevadm trigger
    sudo setcap cap_sys_rawio=ep /usr/bin/openrgb 2>/dev/null || true

    rm -f "${deb_path}"
    echo -e "${GREEN}OpenRGB installed. NOTE: You must reboot or log out/in for the 'i2c' group to take effect.${NC}"
    _pause
}

install_retroarch() {
    if is_installed "retroarch"; then
        echo "RetroArch already installed."
        return
    fi

    _run_cmd "RetroArch" "sudo apt install -y retroarch libretro-mgba libretro-snes9x libretro-nestopia libretro-gambatte" "Installing RetroArch and classic cores (GBA, SNES, NES, GB)..."

    clear
    echo "================================================================="
    echo "  🎮  IMPORTANT RETROARCH NOTICE  🎮"
    echo "================================================================="
    echo "Good news! Nintendo (NES/SNES) and Game Boy (GB/GBA) cores"
    echo "have been automatically installed and are ready to play!"
    echo ""
    echo "⚠️ However, due to Debian open-source guidelines:"
    echo "   - Core auto-updates inside the app are disabled."
    echo "   - Heavy/arcade cores or those requiring proprietary BIOS"
    echo "     (like PlayStation or Arcade) must be handled manually."
    echo ""
    echo "👉 To learn how to unlock the internal Online Downloader:"
    echo "   Please check our repository's documentation or visit:"
    echo "   https://wiki.debian.org/RetroArch"
    echo "================================================================="
    _pause
}
