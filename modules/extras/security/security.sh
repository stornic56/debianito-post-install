#!/usr/bin/env bash
# security.sh — Security & Networking

_cat_security() {
    local headless=false
    _is_headless && headless=true
    local wireshark_state;  wireshark_state=$(_state "wireshark")
    local tcpdump_state;    tcpdump_state=$(_state "tcpdump")
    local zenmap_state;     zenmap_state=$(_state "zenmap")
    local fail2ban_state;   fail2ban_state=$(_state "fail2ban")
    local ufw_state;        ufw_state=$(_state "ufw")
    local clamav_state;     clamav_state=$(_state "clamav")

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Security & Networking" --checklist \
        "Select security and networking tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "wireshark"   "Network protocol analyzer (GUI)$(_inst wireshark)"            "$wireshark_state" \
        "tcpdump"     "Command-line packet analyzer$(_inst tcpdump)"                 "$tcpdump_state" \
        "zenmap"      "Network scanner GUI (Nmap frontend)$(_inst zenmap)"            "$zenmap_state" \
        "fail2ban"    "Brute-force protection daemon$(_inst fail2ban)"               "$fail2ban_state" \
        "ufw"         "Uncomplicated firewall$(_inst ufw)"                            "$ufw_state" \
        "clamav"      "Antivirus engine (ClamAV)$(_inst clamav)"                     "$clamav_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            zenmap)
                install_backports_or_stable zenmap
                ;;
            clamav)
                _install_clamav
                ;;
            *)
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Security & networking tools installed.${NC}"
}
