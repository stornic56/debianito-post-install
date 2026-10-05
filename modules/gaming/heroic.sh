#!/usr/bin/env bash
# Heroic Games Launcher installation from GitHub releases

install_heroic() {
    local heroic_deb
    heroic_deb=$(mktemp "${TMPDIR:-/tmp}/heroic-XXXXXX.deb") || return 1
    # Remove the temp file on every exit path (RETURN
    # traps are not inherited by called functions).
    trap 'rm -f "$heroic_deb"' RETURN
    local ua="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    _run_cmd "Heroic" "sudo apt install -y curl jq" "Installing dependencies..."

    local json
    # -f: HTTP >= 400 must fail; --max-time bounds the
    # whole transfer (connect-timeout only covers the
    # connection phase).
    json=$(curl -fsS --connect-timeout 10 --max-time 30 -H "User-Agent: $ua" \
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

    # Strict URL validation before interpolating into a shell command (_run_cmd uses bash -c)
    [[ "$deb_url" =~ ^https://[A-Za-z0-9./_-]+\.deb$ ]] || { _msg "Error" "Invalid download URL: $deb_url"; return 1; }

    _run_cmd "Heroic" "curl -fsSL --max-time 300 -H 'User-Agent: $ua' -o '$heroic_deb' '$deb_url'" "Downloading Heroic..."

    # --info reads only the control archive; --contents
    # also walks the data archive, catching deb files
    # truncated after the control section.
    if ! dpkg-deb --info "$heroic_deb" >/dev/null 2>&1 || \
       ! dpkg-deb --contents "$heroic_deb" >/dev/null 2>&1; then
        _msg "Heroic Error" "Downloaded .deb is corrupted or truncated.\n\nRemoving file." 10 60
        rm -f "$heroic_deb"
        return 1
    fi

    echo -e "${GREEN}Package integrity verified.${NC}"
    if ! _run_cmd "Heroic" "sudo apt install -y '$heroic_deb'" "Installing Heroic..."; then
        rm -f "$heroic_deb"
        return 1
    fi
    rm -f "$heroic_deb"
    echo -e "${GREEN}Heroic Games Launcher installed.${NC}"
}
