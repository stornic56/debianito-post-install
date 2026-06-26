#!/usr/bin/env bash
# office.sh — Office & Productivity (OnlyOffice via extrepo, LibreOffice backports)
# License GPL v3

# ── OnlyOffice ──
_enable_onlyoffice_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_onlyoffice-desktopeditors.sources ]; then
        if ! command -v extrepo &>/dev/null; then
            _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
        fi
        _run_cmd "OnlyOffice" "sudo extrepo enable onlyoffice-desktopeditors" "Enabling OnlyOffice repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

install_onlyoffice() {
    local ver
    ver=$(apt-cache policy onlyoffice-desktopeditors 2>/dev/null | awk 'NR==3 {print $2; exit}')

    if _confirm "Install: OnlyOffice" "Install OnlyOffice Desktop Editors
Repository: download.onlyoffice.com
Version:    ${ver:-unknown}"; then
        _enable_onlyoffice_repo
        _run_cmd "OnlyOffice" "sudo DEBIAN_FRONTEND=noninteractive apt install -y onlyoffice-desktopeditors" "Installing OnlyOffice..." || echo -e "${RED}OnlyOffice servers are currently slow or down. Please try again later.${NC}"
        echo -e "${GREEN}OnlyOffice installed.${NC}"
    fi
}

# ── LibreOffice (backports) ──
install_libreoffice_bpo() {
    if [ "$DEBIAN_VERSION" != "12" ] && [ "$DEBIAN_VERSION" != "13" ]; then
        _msg "LibreOffice" "LibreOffice backports only available on Debian 12+."
        return
    fi

    local lang_pkg
    lang_pkg=$(_detect_lang_pkg "libreoffice-l10n")

    local ver
    ver=$(apt-cache policy libreoffice 2>/dev/null | awk 'NR==3 {print $2; exit}')
    local bpo_ver
    bpo_ver=$(apt-cache madison libreoffice 2>/dev/null | grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)

    local msg="Install LibreOffice?\n\n"
    msg+="  Stable:    ${ver:-unknown}\n"
    msg+="  Backports: ${bpo_ver:-unavailable}\n"
    [ -n "$lang_pkg" ] && msg+="  Language:  ${lang_pkg}\n"

    if _confirm "LibreOffice" "$msg"; then
        local pkgs="libreoffice${lang_pkg:+ $lang_pkg}"
        if [ -n "$bpo_ver" ]; then
            _run_cmd "LibreOffice" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $pkgs" \
                "Installing LibreOffice from backports..."
        else
            _run_cmd "LibreOffice" "sudo apt install -y $pkgs" \
                "Installing LibreOffice from stable..."
        fi
        echo -e "${GREEN}LibreOffice installed.${NC}"
    fi
}

_cat_office() {
    local choices
    choices=$(whiptail --title "Office & Productivity" --checklist \
        "Select office applications${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "onlyoffice"    "OnlyOffice Desktop Editors (extrepo)" OFF \
        "libreoffice"   "LibreOffice (backports on Bookworm/Trixie)" OFF \
        3>&1 1>&2 2>&3)

    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            onlyoffice)  install_onlyoffice ;;
            libreoffice) install_libreoffice_bpo ;;
        esac
    done
}
