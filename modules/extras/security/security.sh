#!/usr/bin/env bash
# security.sh — Security & Networking

_cat_security() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local wireshark_state; wireshark_state=$(_state "wireshark")
        local zenmap_state;    zenmap_state=$(_state "zenmap")
        items+=(
            "wireshark" "Network protocol analyzer (GUI)"  "$wireshark_state"
            "zenmap"    "Network scanner GUI (Nmap frontend)" "$zenmap_state"
        )
    fi
    local tcpdump_state;  tcpdump_state=$(_state "tcpdump")
    local fail2ban_state; fail2ban_state=$(_state "fail2ban")
    local ufw_state;      ufw_state=$(_state "ufw")
    local clamav_state;   clamav_state=$(_state "clamav")
    items+=(
        "tcpdump" "Command-line packet analyzer"   "$tcpdump_state"
        "fail2ban" "Brute-force protection daemon" "$fail2ban_state"
        "ufw"      "Uncomplicated firewall"             "$ufw_state"
        "clamav"   "Antivirus engine (ClamAV)"       "$clamav_state"
    )

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Security & Networking" "Select security and networking tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" \
        )
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
