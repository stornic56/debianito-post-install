#!/usr/bin/env bash
# internet.sh — Browsers, email, VPN
# extrepo-powered: mozilla, floorp, palemoon, librewolf, tailscale, mullvad, protonvpn

# ── Helpers extrepo ──
_ensure_extrepo() {
    if ! command -v extrepo &>/dev/null; then
        _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
    fi
}

_enable_mozilla_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_mozilla.sources ]; then
        _ensure_extrepo
        _run_cmd "Mozilla" "sudo extrepo enable mozilla" "Enabling Mozilla repository..."
    fi
    if [ ! -f /etc/apt/preferences.d/mozilla ]; then
        sudo tee /etc/apt/preferences.d/mozilla > /dev/null << 'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_floorp_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_floorp.sources ]; then
        _ensure_extrepo
        _run_cmd "Floorp" "sudo extrepo enable floorp" "Enabling Floorp repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_palemoon_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_palemoon.sources ]; then
        _ensure_extrepo
        _run_cmd "Pale Moon" "sudo extrepo enable palemoon" "Enabling Pale Moon repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_librewolf_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_librewolf.sources ]; then
        _ensure_extrepo
        _run_cmd "LibreWolf" "sudo extrepo enable librewolf" "Enabling LibreWolf repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_tailscale_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_tailscale.sources ]; then
        _ensure_extrepo
        _run_cmd "Tailscale" "sudo extrepo enable tailscale" "Enabling Tailscale repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_mullvad_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_mullvad.sources ]; then
        _ensure_extrepo
        _run_cmd "Mullvad" "sudo extrepo enable mullvad" "Enabling Mullvad repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

_enable_protonvpn_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_protonvpn.sources ]; then
        _ensure_extrepo
        _run_cmd "ProtonVPN" "sudo extrepo enable protonvpn" "Enabling ProtonVPN repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

# ── Categories ──
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
    local palemoon_state;     palemoon_state=$(_state "palemoon")
    local privacybrowser_state; privacybrowser_state=$(_state "privacybrowser")
    local qutebrowser_state;  qutebrowser_state=$(_state "qutebrowser")
    local riseupvpn_state;    riseupvpn_state=$(_state "riseup-vpn")
    local thunderbird_state;  thunderbird_state=$(_state "thunderbird")
    local torbrowser_state;   torbrowser_state=$(_state "torbrowser-launcher")
    local w3m_state;          w3m_state=$(_state "w3m")
    local tailscale_state;    tailscale_state=$(_state "tailscale")
    local mullvad_state;      mullvad_state=$(_state "mullvad-vpn")
    local mullvadbrowser_state; mullvadbrowser_state=$(_state "mullvad-browser")
    local protonvpn_state;    protonvpn_state=$(_state "protonvpn")

    local choices
    choices=$(whiptail --title "Internet" --checklist \
        "Select browsers, email, and VPN tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "chromium"            "Chromium web browser$(_inst chromium)"                  "$chromium_state" \
        "dillo"               "Lightweight graphical browser$(_inst dillo)"            "$dillo_state" \
        "elinks"              "Text-mode web browser$(_inst elinks)"                   "$elinks_state" \
        "epiphany-browser"    "GNOME web browser$(_inst epiphany-browser)"             "$epiphany_state" \
        "falkon"              "KDE web browser (QtWebEngine)$(_inst falkon)"           "$falkon_state" \
        "firefox"             "Firefox from Mozilla (replaces ESR)"                    "$firefox_state" \
        "floorp"              "Firefox-based browser (extrepo)$(_inst floorp)"         "$floorp_state" \
        "konqueror"           "KDE file manager / web browser$(_inst konqueror)"       "$konqueror_state" \
        "librewolf"           "Privacy-focused Firefox fork (extrepo)$(_inst librewolf)" "$librewolf_state" \
        "palemoon"            "Classic Firefox-derived browser (extrepo)"              "$palemoon_state" \
        "privacybrowser"      "Privacy-focused web browser$(_inst privacybrowser)"     "$privacybrowser_state" \
        "qutebrowser"         "Keyboard-driven browser (Qt)$(_inst qutebrowser)"       "$qutebrowser_state" \
        "riseup-vpn"          "Riseup VPN client$(_inst riseup-vpn)"                   "$riseupvpn_state" \
        "thunderbird"         "Email client$(_inst thunderbird)"                       "$thunderbird_state" \
        "torbrowser-launcher" "Tor Browser launcher$(_inst torbrowser-launcher)"       "$torbrowser_state" \
        "w3m"                 "Text-mode browser + deps (w3m-img)$(_inst w3m)"         "$w3m_state" \
        "tailscale"           "Zero-config VPN & mesh networking$(_inst tailscale)"    "$tailscale_state" \
        "mullvad-vpn"         "Mullvad VPN client (WireGuard)$(_inst mullvad-vpn)"     "$mullvad_state" \
        "mullvad-browser"     "Mullvad privacy browser$(_inst mullvad-browser)"        "$mullvadbrowser_state" \
        "protonvpn"           "ProtonVPN client$(_inst protonvpn)"                     "$protonvpn_state" \
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
                _enable_floorp_repo
                _run_install floorp
                echo -e "${GREEN}Floorp installed.${NC}"
                ;;
            librewolf)
                _enable_librewolf_repo
                _run_install librewolf
                echo -e "${GREEN}LibreWolf installed.${NC}"
                ;;
            palemoon)
                _enable_palemoon_repo
                _run_install palemoon
                echo -e "${GREEN}Pale Moon installed.${NC}"
                ;;
            tailscale)
                _enable_tailscale_repo
                _run_install tailscale
                echo -e "${GREEN}Tailscale installed.${NC}"
                ;;
            mullvad-vpn)
                _enable_mullvad_repo
                _run_install mullvad-vpn
                echo -e "${GREEN}Mullvad VPN installed.${NC}"
                ;;
            mullvad-browser)
                _enable_mullvad_repo
                _run_install mullvad-browser
                echo -e "${GREEN}Mullvad Browser installed.${NC}"
                ;;
            protonvpn)
                _enable_protonvpn_repo
                _run_install protonvpn
                echo -e "${GREEN}ProtonVPN installed.${NC}"
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

    if is_installed "firefox-esr"; then
        if _confirm "Firefox ESR" "Firefox ESR is installed.\nRemove it before installing Mozilla Firefox?"; then
            echo "Removing Firefox ESR..."
            sudo apt remove -y firefox-esr
        else
            echo "Keeping Firefox ESR."
            return
        fi
    fi

    _enable_mozilla_repo
    _run_install firefox
    echo -e "${GREEN}Firefox (Mozilla) installed.${NC}"
}
