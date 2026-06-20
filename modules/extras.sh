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
        cat_choice=$(whiptail --title "Extra Software" --menu \
            "Select a category${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0" "Essential Pack" \
            "1" "Customization System" \
            "2" "Download & Network" \
            "3" "Internet (Browsers, Email, VPN)" \
            "4" "Media Players" \
            "5" "Multimedia & Design" \
            "6" "Code Editors & IDEs" \
            "7" "Servers & Dev Tools" \
            "8" "Security & Networking" \
            "9" "Software Centers" \
            "10" "Office & Productivity" \
            "11" "System Tools" \
            "12" "Fetch / System Info" \
            "13" "Back to main menu" \
            3>&1 1>&2 2>&3)

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            0)  _quick_install ;;
            1)  _cat_customization ;;
            2)  _cat_download ;;
            3)  _cat_internet ;;
            4)  _cat_players ;;
            5)  _cat_design ;;
            6)  _cat_programming ;;
            7)  _cat_dev ;;
            8)  _cat_security ;;
            9)  _cat_software_centers ;;
            10) _cat_office ;;
            11) _cat_general ;;
            12) _cat_fetch ;;
            13) return ;;
        esac
        clear
    done
}
