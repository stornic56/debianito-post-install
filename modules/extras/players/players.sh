#!/usr/bin/env bash
# players.sh — Media Players (handbrake moved to Multimedia & Design)

_cat_players() {
    local headless=false
    _is_headless && headless=true
    local mpv_state; mpv_state=$(_state "mpv")
    local vlc_state; vlc_state=$(_state "vlc")

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Media Players" --checklist \
        "Select media players:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "mpv"  "Lightweight media player$(_inst mpv)"  "$mpv_state" \
        "vlc"  "VLC media player$(_inst vlc)"           "$vlc_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Media players installed.${NC}"
}
