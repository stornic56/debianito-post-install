#!/usr/bin/env bash
# fonts.sh — Fonts

_cat_fonts() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local bebas_state;       bebas_state=$(_state "fonts-bebas-neue")
        local anon_state;        anon_state=$(_state "fonts-anonymous-pro")
        local verana_state;      verana_state=$(_state "fonts-adf-verana")
        local f3270_state;       f3270_state=$(_state "fonts-3270")
        local liberation_state;  liberation_state=$(_state "fonts-liberation")
        local mscore_state;      mscore_state=$(_state "ttf-mscorefonts-installer")
        local ubuntu_state;      ubuntu_state=$(_state "fonts-ubuntu")
        local recommended_state; recommended_state=$(_state "fonts-recommended")
        items+=(
            "fonts-bebas-neue"           "Bebas Neue (display)"                       "$bebas_state"
            "fonts-anonymous-pro"        "Anonymous Pro (monospace)"               "$anon_state"
            "fonts-adf-verana"           "ADF Verana (sans-serif)"                    "$verana_state"
            "fonts-3270"                 "IBM 3270 terminal font"                          "$f3270_state"
            "fonts-liberation"           "Liberation (MS-compatible)"                "$liberation_state"
            "ttf-mscorefonts-installer"  "Microsoft fonts (EULA required)" "$mscore_state"
            "fonts-ubuntu"               "Ubuntu font family"                             "$ubuntu_state"
            "fonts-recommended"          "Debian recommended fonts"                "$recommended_state"
        )
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Fonts" "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $lista_alto \
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

    echo -e "${GREEN}Fonts installed.${NC}"
}
