#!/usr/bin/env bash
# players.sh — Media Players (handbrake moved to Multimedia & Design)

_cat_players() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local mpv_state; mpv_state=$(_state "mpv")
        local vlc_state; vlc_state=$(_state "vlc")
        items+=(
            "mpv"  "Lightweight media player"  "$mpv_state"
            "vlc"  "VLC media player"           "$vlc_state"
        )
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Media Players" "Select media players:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" \
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    # BH-004: Convert to array to avoid word splitting and injection.
    local -a _pkgs=()
    while IFS= read -r _pkg; do
        [ -n "$_pkg" ] && _pkgs+=("$_pkg")
    done < <(echo "$cleaned" | tr ' ' '\n')

    # Pre-apply summary: confirm the selection once,
    # before any apt transaction starts.
    _confirm_install_list "Media Players" "${_pkgs[@]}" || return
    for pkg in "${_pkgs[@]}"; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    # Release the per-package prompt suppression.
    _SELECTION_CONFIRMED=0

    echo -e "${GREEN}Media players installed.${NC}"
}
