#!/usr/bin/env bash
# internet.sh — Browsers, email, VPN
# extrepo-powered: mozilla, floorp, palemoon, librewolf, tailscale, mullvad, protonvpn
# firefox-esr from Debian repos (with locale auto-detect)

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

install_palemoon() {
    if [ "$DEBIAN_VERSION" -lt 12 ] 2>/dev/null; then
        _msg "Pale Moon" "Pale Moon is only available on\nDebian 12 (Bookworm) and 13 (Trixie).\n\nSkipping installation." 10 60
        return 1
    fi

    local cpu_flags cpu_label REPO_PALEMOON
    cpu_flags=$(grep -m1 '^flags' /proc/cpuinfo 2>/dev/null)

    if echo "$cpu_flags" | grep -q 'avx2'; then
        REPO_PALEMOON="palemoon_avx2_gtk3"
        cpu_label="AVX2"
    elif echo "$cpu_flags" | grep -q 'avx'; then
        REPO_PALEMOON="palemoon_avx_gtk3"
        cpu_label="AVX"
    else
        REPO_PALEMOON="palemoon_sse2_gtk3"
        cpu_label="SSE2"
    fi

    _msg "Pale Moon" "CPU detected: ${cpu_label} support.\n\nEnabling optimized repository:\n  ${REPO_PALEMOON}" 10 60

    if ls /etc/apt/sources.list.d/extrepo_palemoon_*.sources &>/dev/null; then
        echo "Pale Moon repository already enabled."
    else
        _ensure_extrepo
        _run_cmd "Pale Moon" "sudo extrepo enable ${REPO_PALEMOON}" "Enabling ${REPO_PALEMOON}..."
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    fi

    if ! is_installed "palemoon"; then
        _run_cmd "Pale Moon" "sudo apt install -y palemoon" "Installing Pale Moon..."
        echo -e "${GREEN}Pale Moon installed.${NC}"
    else
        echo "Pale Moon already installed."
    fi
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

install_protonvpn() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_protonvpn.sources ]; then
        _ensure_extrepo
        _run_cmd "ProtonVPN" "sudo extrepo enable protonvpn stable" "Enabling ProtonVPN repository (stable suite)..."
        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    else
        echo "ProtonVPN repository already enabled."
    fi

    if ! is_installed "proton-vpn-gtk-app"; then
        _msg "ProtonVPN" "Installing Proton VPN GTK client\nfrom the official Proton repository." 10 60
        _run_cmd "ProtonVPN" "sudo apt install -y proton-vpn-gtk-app" "Installing Proton VPN GTK app..."
        echo -e "${GREEN}ProtonVPN installed.${NC}"
    else
        echo "Proton VPN GTK app already installed."
    fi
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
    if command -v firefox &>/dev/null && ! is_installed "firefox-esr"; then
        firefox_state="ON"
    fi
    local firefox_esr_state
    firefox_esr_state=$(_state "firefox-esr")
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
    choices=$(_checklist "Internet" "Select browsers, email, and VPN tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "chromium"            "Chromium web browser$(_inst chromium)"                  "$chromium_state" \
        "dillo"               "Lightweight graphical browser$(_inst dillo)"            "$dillo_state" \
        "elinks"              "Text-mode web browser$(_inst elinks)"                   "$elinks_state" \
        "epiphany-browser"    "GNOME web browser$(_inst epiphany-browser)"             "$epiphany_state" \
        "falkon"              "KDE web browser (QtWebEngine)$(_inst falkon)"           "$falkon_state" \
        "firefox"             "Firefox from Mozilla (replaces ESR)"                    "$firefox_state" \
        "firefox-esr"         "Firefox ESR (official Debian + locale auto)"            "$firefox_esr_state" \
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
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    if echo "$cleaned" | grep -q "firefox" && echo "$cleaned" | grep -q "firefox-esr"; then
        _msg "Firefox" "You selected both Firefox (Mozilla) and Firefox ESR.\nPlease choose only one Firefox variant." 10 60
        return
    fi

    for pkg in $cleaned; do
        case $pkg in
            firefox)
                install_firefox_mozilla
                ;;
            firefox-esr)
                install_firefox_esr
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
                install_palemoon
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
                install_protonvpn
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
    if [ "$DEBIAN_VERSION" -lt 12 ] 2>/dev/null; then
        _msg "Firefox" "Mozilla Firefox is only available on\nDebian 12 (Bookworm) and 13 (Trixie).\n\nSkipping installation." 10 60
        return 1
    fi

    if command -v firefox &>/dev/null && ! is_installed "firefox-esr"; then
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
    _run_cmd "Firefox" "sudo apt install -y firefox" "Installing Firefox (Mozilla)..."
    echo -e "${GREEN}Firefox (Mozilla) installed.${NC}"
}

install_firefox_esr() {
    if is_installed "firefox-esr"; then
        echo "Firefox ESR is already installed."
        return
    fi

    if command -v firefox &>/dev/null; then
        if _confirm "Firefox" "Mozilla Firefox is installed.\nRemove it before installing Firefox ESR?"; then
            echo "Removing Mozilla Firefox..."
            sudo apt remove -y firefox
        else
            echo "Keeping Mozilla Firefox."
            return
        fi
    fi

    _run_cmd "Firefox ESR" "sudo apt install -y firefox-esr" "Installing Firefox ESR..."

    local lang_pkg
    lang_pkg=$(_detect_lang_pkg "firefox-esr-l10n")
    if [ -n "$lang_pkg" ]; then
        _run_cmd "Firefox ESR Locale" "sudo apt install -y ${lang_pkg}" \
            "Installing locale: ${lang_pkg}..."
    else
        echo "No matching locale package found for your language."
    fi

    echo -e "${GREEN}Firefox ESR installed.${NC}"
}
