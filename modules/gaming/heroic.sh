#!/usr/bin/env bash
# Heroic Games Launcher installation from GitHub releases

install_heroic() {
    local heroic_deb="/tmp/heroic.deb"
    local ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    _run_cmd "Heroic" "sudo apt install -y curl jq" "Installing dependencies..."

    local json
    json=$(curl -s --connect-timeout 10 -H "User-Agent: $ua" \
        "https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest") || {
        _msg "Heroic Error" "Could not fetch release data from GitHub API." 8 60
        return 1
    }

    local deb_url
    deb_url=$(echo "$json" | jq -r '
        .assets[] | select(.name | endswith("amd64.deb")) | .browser_download_url
    ' 2>/dev/null || true)

    if [ -z "$deb_url" ]; then
        _msg "Heroic Error" "Could not find amd64.deb asset in latest release." 10 60
        return 1
    fi

    _run_cmd "Heroic" "curl -sL -H 'User-Agent: $ua' -o '$heroic_deb' '$deb_url'" "Downloading Heroic..."

    if ! dpkg-deb --info "$heroic_deb" >/dev/null 2>&1; then
        _msg "Heroic Error" "Downloaded .deb is corrupted or truncated.\n\nRemoving file." 10 60
        rm -f "$heroic_deb"
        return 1
    fi

    echo -e "${GREEN}Package integrity verified.${NC}"
    _run_cmd "Heroic" "sudo apt install -y '$heroic_deb'" "Installing Heroic..."
    rm -f "$heroic_deb"
    echo -e "${GREEN}Heroic Games Launcher installed.${NC}"
}
