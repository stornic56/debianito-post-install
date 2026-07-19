#!/usr/bin/env bash
# essential.sh — one-click essentials pack

_quick_install() {
    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        fetch_pkg="fastfetch"
    else
        fetch_pkg="neofetch"
    fi

    local comp_pkgs
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        comp_pkgs="7zip 7zip-rar"
    else
        comp_pkgs="p7zip-full p7zip-rar"
    fi

    _msg "Essential Pack" \
        "Install basic programs:\n\n  - Compression (zip, unrar, 7z)\n  - System tools (htop, inxi, ${fetch_pkg})\n  - Networking (curl, wget, ufw)\n  - CA certs & GPG\n  - VLC media player" 13 60

    local quick_pkgs=(
        zip unzip rar unrar
        $comp_pkgs
        "$fetch_pkg" htop inxi curl wget ufw
        ca-certificates gnupg lsb-release
    )
    _is_headless || quick_pkgs+=(vlc)
    _run_install_batch "${quick_pkgs[@]}"
    echo -e "${GREEN}Essential Pack installed.${NC}"
}
