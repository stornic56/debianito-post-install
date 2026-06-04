#!/usr/bin/env bash
# essential.sh — one-click essentials pack

_quick_install() {
    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    _msg "Essential Pack" \
        "Install basic programs:\n\n  - Compression (zip, unrar, 7z)\n  - System tools (htop, inxi, ${fetch_pkg})\n  - VLC media player\n  - Microsoft fonts" 13 60

    local quick_pkgs=(
        zip unzip rar unrar p7zip-full p7zip-rar
        "$fetch_pkg" htop vlc inxi ttf-mscorefonts-installer
    )
    _run_install_batch "${quick_pkgs[@]}"
    echo -e "${GREEN}Essential Pack installed.${NC}"
}
