#!/usr/bin/env bash
# icons.sh — Icon themes

_cat_icons() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local breeze_state;     breeze_state=$(_state "breeze-icon-theme")
        local deepin_state;     deepin_state=$(_state "deepin-icon-theme")
        local ele_state;        ele_state=$(_state "elementary-icon-theme")
        local ele_xfce_state;   ele_xfce_state=$(_state "elementary-xfce-icon-theme")
        local moka_state;       moka_state=$(_state "moka-icon-theme")
        local numix_state;      numix_state=$(_state "numix-icon-theme")
        local numix_c_state;    numix_c_state=$(_state "numix-icon-theme-circle")
        local obsidian_state;   obsidian_state=$(_state "obsidian-icon-theme")
        local papirus_state;    papirus_state=$(_state "papirus-icon-theme")
        local paper_state;      paper_state=$(_state "paper-icon-theme")
        local suru_state;       suru_state=$(_state "suru-icon-theme")

        local kf6_state="OFF"
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            kf6_state=$(_state "kf6-breeze-icon-theme")
        fi

        items=(
            "breeze-icon-theme"     "Breeze icon theme"           "$breeze_state"
            "deepin-icon-theme"     "Deepin icon theme"           "$deepin_state"
            "elementary-icon-theme" "Elementary icon theme"   "$ele_state"
            "elementary-xfce-icon-theme" "Elementary Xfce icons" "$ele_xfce_state"
            "moka-icon-theme"       "Moka icon theme"               "$moka_state"
            "numix-icon-theme"      "Numix icon theme"             "$numix_state"
            "numix-icon-theme-circle" "Numix Circle icon theme" "$numix_c_state"
            "obsidian-icon-theme"   "Obsidian icon theme"       "$obsidian_state"
            "papirus-icon-theme"    "Papirus icon theme"         "$papirus_state"
            "paper-icon-theme"      "Paper icon theme"             "$paper_state"
            "suru-icon-theme"       "Suru icon theme"               "$suru_state"
        )
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            items+=("kf6-breeze-icon-theme" "KF6 Breeze icon theme" "$kf6_state")
        fi
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Icon Themes" "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $lista_alto \
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

    echo -e "${GREEN}Icon themes installed.${NC}"
}
