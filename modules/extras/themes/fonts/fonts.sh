#!/usr/bin/env bash
# fonts.sh — Fonts

_cat_fonts() {
    local bebas_state;       bebas_state=$(_state "fonts-bebas-neue")
    local anon_state;        anon_state=$(_state "fonts-anonymous-pro")
    local verana_state;      verana_state=$(_state "fonts-adf-verana")
    local f3270_state;       f3270_state=$(_state "fonts-3270")
    local liberation_state;  liberation_state=$(_state "fonts-liberation")
    local mscore_state;      mscore_state=$(_state "ttf-mscorefonts-installer")
    local ubuntu_state;      ubuntu_state=$(_state "fonts-ubuntu")
    local recommended_state; recommended_state=$(_state "fonts-recommended")

    local choices
    choices=$(whiptail --title "Fonts" --checklist \
        "Select fonts to install${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "fonts-bebas-neue"           "Bebas Neue (display)$(_inst fonts-bebas-neue)"                       "$bebas_state" \
        "fonts-anonymous-pro"        "Anonymous Pro (monospace)$(_inst fonts-anonymous-pro)"               "$anon_state" \
        "fonts-adf-verana"           "ADF Verana (sans-serif)$(_inst fonts-adf-verana)"                    "$verana_state" \
        "fonts-3270"                 "IBM 3270 terminal font$(_inst fonts-3270)"                          "$f3270_state" \
        "fonts-liberation"           "Liberation (MS-compatible)$(_inst fonts-liberation)"                "$liberation_state" \
        "ttf-mscorefonts-installer"  "Microsoft fonts (EULA required)$(_inst ttf-mscorefonts-installer)" "$mscore_state" \
        "fonts-ubuntu"               "Ubuntu font family$(_inst fonts-ubuntu)"                             "$ubuntu_state" \
        "fonts-recommended"          "Debian recommended fonts$(_inst fonts-recommended)"                "$recommended_state" \
        3>&1 1>&2 2>&3)
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

    echo -e "${GREEN}Fonts installed.${NC}"
}
