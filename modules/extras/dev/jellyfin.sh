#!/usr/bin/env bash
# jellyfin.sh — Jellyfin Media Server installation (extrepo)

_enable_jellyfin_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_jellyfin.sources ]; then
        if ! command -v extrepo &>/dev/null; then
            _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
        fi
        _run_cmd "Jellyfin" "sudo extrepo enable jellyfin" "Enabling Jellyfin repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

install_jellyfin() {
    local ver
    ver=$(apt-cache policy jellyfin 2>/dev/null | awk 'NR==3 {print $2; exit}')

    if _confirm "Install: Jellyfin" "Install Jellyfin Media Server
Repository: repo.jellyfin.org/debian
Version:    ${ver:-unknown}"; then

        _enable_jellyfin_repo
        _run_cmd "Jellyfin" "sudo DEBIAN_FRONTEND=noninteractive apt install -y jellyfin" "Installing Jellyfin..."

        echo -e "${GREEN}Jellyfin Server installed. Web interface available at http://localhost:8096${NC}"
    fi
}
