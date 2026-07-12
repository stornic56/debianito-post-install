#!/usr/bin/env bash
# desktop-themes.sh — GTK and KDE desktop themes

_cat_themes() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local arc_state;        arc_state=$(_state "arc-theme")
        local blackbird_state;  blackbird_state=$(_state "blackbird-gtk-theme")
        local bluebird_state;   bluebird_state=$(_state "bluebird-gtk-theme")
        local breeze_gtk_state; breeze_gtk_state=$(_state "breeze-gtk-theme")
        local greybird_state;   greybird_state=$(_state "greybird-gtk-theme")
        local numix_gtk_state;  numix_gtk_state=$(_state "numix-gtk-theme")
        local orchis_state;     orchis_state=$(_state "orchis-gtk-theme")
        items+=(
            "arc-theme"           "Arc GTK theme"                 "$arc_state"
            "blackbird-gtk-theme" "Blackbird GTK theme" "$blackbird_state"
            "bluebird-gtk-theme"  "Bluebird GTK theme"   "$bluebird_state"
            "breeze-gtk-theme"    "Breeze GTK theme (KDE port)" "$breeze_gtk_state"
            "greybird-gtk-theme"  "Greybird GTK theme"   "$greybird_state"
            "numix-gtk-theme"     "Numix GTK theme"         "$numix_gtk_state"
            "orchis-gtk-theme"    "Orchis GTK theme"       "$orchis_state"
        )
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Desktop Themes (GTK/KDE)" "Select desktop themes to install${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
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

    echo -e "${GREEN}Desktop themes installed.${NC}"
}
