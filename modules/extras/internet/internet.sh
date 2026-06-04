#!/usr/bin/env bash
# internet.sh — Browsers, email, VPN (was _cat_browsers, now includes riseup-vpn)

_cat_internet() {
    local headless=false
    _is_headless && headless=true
    local chromium_state;     chromium_state=$(_state "chromium")
    local dillo_state;        dillo_state=$(_state "dillo")
    local elinks_state;       elinks_state=$(_state "elinks")
    local epiphany_state;     epiphany_state=$(_state "epiphany-browser")
    local falkon_state;       falkon_state=$(_state "falkon")
    local firefox_state="OFF"
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        firefox_state="ON"
    fi
    local floorp_state;       floorp_state=$(_state "floorp")
    local konqueror_state;    konqueror_state=$(_state "konqueror")
    local librewolf_state;    librewolf_state=$(_state "librewolf")
    local privacybrowser_state; privacybrowser_state=$(_state "privacybrowser")
    local qutebrowser_state;  qutebrowser_state=$(_state "qutebrowser")
    local riseupvpn_state;    riseupvpn_state=$(_state "riseup-vpn")
    local thunderbird_state;  thunderbird_state=$(_state "thunderbird")
    local torbrowser_state;   torbrowser_state=$(_state "torbrowser-launcher")
    local w3m_state;          w3m_state=$(_state "w3m")

    local choices
    choices=$(whiptail --title "Internet" --checklist \
        "Select browsers, email, and VPN tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "chromium"            "Chromium web browser$(_inst chromium)"                  "$chromium_state" \
        "dillo"               "Lightweight graphical browser$(_inst dillo)"            "$dillo_state" \
        "elinks"              "Text-mode web browser$(_inst elinks)"                   "$elinks_state" \
        "epiphany-browser"    "GNOME web browser$(_inst epiphany-browser)"             "$epiphany_state" \
        "falkon"              "KDE web browser (QtWebEngine)$(_inst falkon)"           "$falkon_state" \
        "firefox"             "Firefox from Mozilla (replaces ESR)"                    "$firefox_state" \
        "floorp"              "Firefox-based browser (external repo)"                  "$floorp_state" \
        "konqueror"           "KDE file manager / web browser$(_inst konqueror)"       "$konqueror_state" \
        "librewolf"           "Privacy-focused Firefox fork$(_inst librewolf)"         "$librewolf_state" \
        "privacybrowser"      "Privacy-focused web browser$(_inst privacybrowser)"     "$privacybrowser_state" \
        "qutebrowser"         "Keyboard-driven browser (Qt)$(_inst qutebrowser)"       "$qutebrowser_state" \
        "riseup-vpn"          "Riseup VPN client$(_inst riseup-vpn)"                    "$riseupvpn_state" \
        "thunderbird"         "Email client$(_inst thunderbird)"                       "$thunderbird_state" \
        "torbrowser-launcher" "Tor Browser launcher$(_inst torbrowser-launcher)"       "$torbrowser_state" \
        "w3m"                 "Text-mode browser + deps (w3m-img)$(_inst w3m)"         "$w3m_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            firefox)
                install_firefox_mozilla
                ;;
            floorp)
                if ! is_installed "floorp"; then
                    echo "Setting up Floorp repository..."
                    ! is_installed "curl" && _run_install curl
                    ! is_installed "gpg" && _run_install gpg
                    sudo install -d -m 0755 /etc/apt/keyrings
                    curl -fsSL https://ppa.floorp.app/KEY.gpg | \
                        sudo gpg --dearmor -o /usr/share/keyrings/Floorp.gpg
                    sudo curl -sS --compressed -o /etc/apt/sources.list.d/Floorp.list \
                        'https://ppa.floorp.app/Floorp.list'
                    sudo tee /etc/apt/preferences.d/floorp > /dev/null << EOF
Package: *
Pin: origin ppa.floorp.app
Pin-Priority: 1000
EOF
                    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
                    _run_install floorp
                    echo -e "${GREEN}Floorp installed.${NC}"
                else
                    echo "Floorp already installed."
                fi
                ;;
            librewolf)
                if ! is_installed "librewolf"; then
                    echo "Installing LibreWolf..."
                    install_backports_or_stable extrepo
                    sudo extrepo enable librewolf 2>/dev/null || true
                    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
                    _run_install librewolf
                    echo -e "${GREEN}LibreWolf installed.${NC}"
                else
                    echo "LibreWolf already installed."
                fi
                ;;
            riseup-vpn)
                install_backports_or_stable riseup-vpn
                ;;
            w3m)
                local need=()
                ! is_installed "w3m" && need+=("w3m")
                ! is_installed "w3m-img" && need+=("w3m-img")
                ! is_installed "ca-certificates" && need+=("ca-certificates")
                ! is_installed "xsel" && need+=("xsel")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch w3m w3m-img ca-certificates xsel
                else
                    echo "w3m already installed."
                fi
                ;;
            *)
                if $headless; then
                    echo "Skipping $pkg (headless mode)"
                    continue
                fi
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Internet tools installed.${NC}"
}

install_firefox_mozilla() {
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        echo "Firefox (Mozilla) is already installed."
        return
    fi

    echo "Setting up Mozilla APT repository for Firefox..."

    if is_installed "firefox-esr"; then
        if _confirm "Firefox ESR" "Firefox ESR is installed.\nRemove it before installing Mozilla Firefox?"; then
            echo "Removing Firefox ESR..."
            sudo apt remove -y firefox-esr
        else
            echo "Keeping Firefox ESR."
        fi
    fi

    ! is_installed "wget" && _run_install wget
    ! is_installed "gpg" && _run_install gpg

    sudo install -d -m 0755 /etc/apt/keyrings

    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
        sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

    local fp
    fp=$(gpg -n -q --import --import-options import-show \
        /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | \
        awk '/pub/{getline; gsub(/^ +| +$/,""); print}')
    if [ "$fp" != "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" ]; then
        echo -e "${YELLOW}Warning: Mozilla key fingerprint does not match expected value.${NC}"
    fi

    local use_deb822=false
    [ -f /etc/apt/sources.list.d/debian.sources ] && use_deb822=true

    if $use_deb822; then
        sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null << EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
    else
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | \
            sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    fi

    sudo tee /etc/apt/preferences.d/mozilla > /dev/null << EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    _run_install firefox

    echo -e "${GREEN}Firefox (Mozilla) installed.${NC}"
}
