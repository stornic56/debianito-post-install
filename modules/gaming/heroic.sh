#!/usr/bin/env bash
# Heroic Games Launcher installation from GitHub releases

install_heroic() {
    local heroic_deb="/tmp/heroic.deb"
    _run_cmd "Heroic" "sudo apt install -y curl wget" "Installing dependencies..."
    local gh_url
    gh_url=$(curl -s --connect-timeout 10 https://api.github.com/repos/Heroic-Games-Launcher/\
HeroicGamesLauncher/releases/latest | \
        grep -oP 'https://[^"]+amd64\.deb' | head -1)
    if [ -z "$gh_url" ]; then
        echo -e "${RED}Could not determine latest Heroic release.${NC}"
    else
        _run_cmd "Heroic" "wget -O $heroic_deb $gh_url" "Downloading Heroic..."
        _run_cmd "Heroic" "sudo apt install -y $heroic_deb" "Installing Heroic..."
        rm -f "$heroic_deb"
        echo -e "${GREEN}Heroic Games Launcher installed.${NC}"
    fi
}
