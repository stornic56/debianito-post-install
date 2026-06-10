#!/usr/bin/env bash
# Steam installation from Debian repos

install_steam() {
    _run_cmd "Steam" "sudo apt install -y steam-installer" "Installing Steam from Debian repos..."
    echo -e "${GREEN}Steam installed.${NC}"
}
