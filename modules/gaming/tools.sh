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
    local deb_suffix
    case "$DEBIAN_CODENAME" in
        bookworm) deb_suffix="bookworm" ;;
        trixie)   deb_suffix="trixie" ;;
        *)
            echo "OpenRGB requires Debian 12 (Bookworm) or 13 (Trixie)."
            return 1
            ;;
    esac

    local deb_path="/tmp/openrgb.deb"
    local ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    _run_cmd "OpenRGB" "sudo apt install -y curl jq" "Installing dependencies..."

    local json
    json=$(curl -s --connect-timeout 10 \
        "https://codeberg.org/api/v1/repos/OpenRGB/OpenRGB/releases?limit=1") || {
        echo -e "${RED}Could not fetch OpenRGB releases from Codeberg API.${NC}"
        return 1
    }

    local deb_url sha256
    while IFS=' ' read -r url hash; do
        deb_url="$url"
        sha256="$hash"
    done < <(echo "$json" | jq -r '
        .[0].assets[] | select(.name | contains("amd64_'"${deb_suffix}"'.deb")) |
        "\(.browser_download_url) \(.sha256 // "")"
    ' 2>/dev/null)

    if [ -z "$deb_url" ]; then
        echo -e "${RED}Could not find OpenRGB .deb for ${DEBIAN_CODENAME^}.${NC}"
        return 1
    fi

    _run_cmd "OpenRGB" "curl -L -o '${deb_path}' -A '${ua}' '${deb_url}'" "Downloading OpenRGB..."

    if [ -n "$sha256" ]; then
        if ! echo "$sha256  $deb_path" | sha256sum -c --strict; then
            echo -e "${RED}SHA256 mismatch! Downloaded file may be corrupted. Removing.${NC}"
            rm -f "$deb_path"
            return 1
        fi
        echo -e "${GREEN}SHA256 verified.${NC}"
    else
        if ! dpkg-deb --info "$deb_path" >/dev/null 2>&1; then
            echo -e "${RED}Downloaded .deb is corrupted. Removing.${NC}"
            rm -f "$deb_path"
            return 1
        fi
        echo -e "${YELLOW}No SHA256 in API, validated via dpkg-deb.${NC}"
    fi

    sudo apt install -y "$deb_path"
    rm -f "$deb_path"

    sudo modprobe i2c-dev
    if ! grep -q "^i2c-dev" /etc/modules 2>/dev/null; then
        echo "i2c-dev" | sudo tee -a /etc/modules >/dev/null
    fi
    sudo usermod -aG i2c "$USER"
    sudo udevadm control --reload-rules && sudo udevadm trigger
    sudo setcap cap_sys_rawio=ep /usr/bin/openrgb 2>/dev/null || true

    echo -e "${GREEN}OpenRGB installed. Reboot or log out/in for i2c group to take effect.${NC}"
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
