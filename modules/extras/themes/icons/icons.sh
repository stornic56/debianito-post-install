#!/usr/bin/env bash
# icons.sh — Icon themes

_cat_icons() {
    local headless=false
    _is_headless && headless=true
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
    local has_kf6=false
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        kf6_state=$(_state "kf6-breeze-icon-theme")
        has_kf6=true
    fi

    local items=(
        "breeze-icon-theme"     "Breeze icon theme$(_inst breeze-icon-theme)"           "$breeze_state"
        "deepin-icon-theme"     "Deepin icon theme$(_inst deepin-icon-theme)"           "$deepin_state"
        "elementary-icon-theme" "Elementary icon theme$(_inst elementary-icon-theme)"   "$ele_state"
        "elementary-xfce-icon-theme" "Elementary Xfce icons$(_inst elementary-xfce-icon-theme)" "$ele_xfce_state"
        "moka-icon-theme"       "Moka icon theme$(_inst moka-icon-theme)"               "$moka_state"
        "numix-icon-theme"      "Numix icon theme$(_inst numix-icon-theme)"             "$numix_state"
        "numix-icon-theme-circle" "Numix Circle icon theme$(_inst numix-icon-theme-circle)" "$numix_c_state"
        "obsidian-icon-theme"   "Obsidian icon theme$(_inst obsidian-icon-theme)"       "$obsidian_state"
        "papirus-icon-theme"    "Papirus icon theme$(_inst papirus-icon-theme)"         "$papirus_state"
        "paper-icon-theme"      "Paper icon theme$(_inst paper-icon-theme)"             "$paper_state"
        "suru-icon-theme"       "Suru icon theme$(_inst suru-icon-theme)"               "$suru_state"
    )
    if $has_kf6; then
        items+=("kf6-breeze-icon-theme" "KF6 Breeze icon theme$(_inst kf6-breeze-icon-theme)" "$kf6_state")
    fi

    local choices
    choices=$(whiptail --title "Icon Themes" --checklist \
        "Select icon themes to install:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "${items[@]}" \
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

    echo -e "${GREEN}Icon themes installed.${NC}"
}
