# jellyfin.sh — Jellyfin Media Server installation (native repo)

install_jellyfin() {
    local ver
    ver=$(apt-cache policy jellyfin 2>/dev/null | awk 'NR==3 {print $2; exit}')

    if _confirm "Install: Jellyfin" "Install Jellyfin Media Server
Repository: repo.jellyfin.org/debian
Version:    ${ver:-unknown}"; then

        # 1. Prerequisites
        ! is_installed "curl" && _run_install "curl"
        ! is_installed "gpg"  && _run_install "gpg"
        sudo install -d -m 0755 /etc/apt/keyrings

        # 2. GPG key
        echo -e "${GREEN}[+]${NC} Adding Jellyfin GPG key..."
        curl -fsSL "https://repo.jellyfin.org/jellyfin_team.gpg.key" \
            | sudo gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg

        # 3. Deb822 .sources file
        echo -e "${GREEN}[+]${NC} Adding Jellyfin repository..."
        sudo tee /etc/apt/sources.list.d/jellyfin.sources > /dev/null << EOF
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: ${DEBIAN_CODENAME}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF

        # 4. Update + install
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
        _run_cmd "Jellyfin" "sudo DEBIAN_FRONTEND=noninteractive apt install -y jellyfin" "Installing Jellyfin..."

        echo -e "${GREEN}Jellyfin Server installed. Web interface available at http://localhost:8096${NC}"
    fi
}
