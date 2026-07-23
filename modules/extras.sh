#!/usr/bin/env bash
# extras.sh — Dispatcher: loads extras category modules and shows submenu

_EXTRAS_DIR="${MODULES_DIR}/extras"

_load_extras() {
    [ -n "${_EXTRAS_LOADED:-}" ] && return
    [ -f "${_EXTRAS_DIR}/_helpers.sh" ] && source "${_EXTRAS_DIR}/_helpers.sh"
    shopt -s nullglob
    for _mod in "${_EXTRAS_DIR}"/*/*.sh "${_EXTRAS_DIR}"/*/*/*.sh; do
        [ -f "$_mod" ] || continue
        source "$_mod"
    done
    shopt -u nullglob
    unset _mod
    _EXTRAS_LOADED=1
}

install_extras() {
    _load_extras

    echo -e "${YELLOW}Extra software installation...${NC}"

    if _is_headless; then
        _msg "Headless Mode" "No graphical display detected.\n\nOnly terminal-friendly packages will be shown.\nGUI applications (browsers, media players, design tools)\nwill be skipped automatically." 12 60
    fi

    while true; do
        local cat_choice
        cat_choice=$(_menu "Install Programs and Software" \
            "Select a category:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0" "Essential Pack" \
            "1" "Customization System" \
            "2" "Download & Network" \
            "3" "Internet (Browsers, Email, VPN)" \
            "4" "Communication" \
            "5" "Media Players" \
            "6" "Multimedia & Design" \
            "7" "Code Editors & IDEs" \
            "8" "Servers & Dev Tools" \
            "9" "Security & Networking" \
            "10" "Software Centers" \
            "11" "Office & Productivity" \
            "12" "System Tools" \
            "13" "Fetch / System Info" \
            "14" "Back to main menu")

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            0)  _quick_install ;;
            1)  _cat_customization ;;
            2)  _cat_download ;;
            3)  _cat_internet ;;
            4)  _cat_communication ;;
            5)  _cat_players ;;
            6)  _cat_design ;;
            7)  _cat_programming ;;
            8)  _cat_dev ;;
            9)  _cat_security ;;
            10) _cat_software_centers ;;
            11) _cat_office ;;
            12) _cat_general ;;
            13) _cat_fetch ;;
            14) return ;;
        esac
        clear
    done
}
