#!/usr/bin/env bash
# cursors.sh — Cursor themes

_cat_cursors() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local bibata_state;    bibata_state=$(_state "bibata-cursor-theme")
        local breeze_state;    breeze_state=$(_state "breeze-cursor-theme")
        local chameleon_state; chameleon_state=$(_state "chameleon-cursor-theme")
        local dmz_state;       dmz_state=$(_state "dmz-cursor-theme")
        local xcursor_state;   xcursor_state=$(_state "xcursor-themes")
        local oxygen_state;    oxygen_state=$(_state "oxygencursors")
        items+=(
            "bibata-cursor-theme"    "Bibata cursors"          "$bibata_state"
            "breeze-cursor-theme"    "Breeze cursors (KDE)"   "$breeze_state"
            "chameleon-cursor-theme" "Chameleon cursors"   "$chameleon_state"
            "dmz-cursor-theme"       "DMZ cursors"                "$dmz_state"
            "xcursor-themes"         "X11 base cursors"            "$xcursor_state"
            "oxygencursors"          "Oxygen cursors (KDE legacy)"  "$oxygen_state"
        )
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Cursor Themes" "Select cursor themes to install${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" \
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Cursor themes installed.${NC}"
}
