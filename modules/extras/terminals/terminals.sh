#!/usr/bin/env bash
# terminals.sh — Terminal emulators

_cat_terminals() {
    local headless=false
    _is_headless && headless=true
    if $headless; then
        echo "Terminals require a GUI — skipping."
        return
    fi

    local -a items=()
    for t in kitty deepin-terminal gnome-terminal lxterminal mate-terminal \
             qterminal xfce4-terminal konsole terminator guake cool-retro-term \
             tilix yakuake terminology rxvt-unicode xterm; do
        items+=("$t" "" "$(_state "$t")")
    done

    if [ "$DEBIAN_VERSION" = "12" ] || [ "$DEBIAN_VERSION" = "13" ]; then
        items+=("alacritty" "" "$(_state alacritty)")
    fi
    if [ "$DEBIAN_VERSION" = "13" ]; then
        items+=("blackbox-terminal" "" "$(_state blackbox-terminal)")
        items+=("ptyxis"            "" "$(_state ptyxis)")
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Terminals" "Select terminal emulators${SCROLL_HINT}:" \
        $TUI_ALTO $TUI_ANCHO $lista_alto "${items[@]}")
    clear
    [ -z "$choices" ] && return

    for pkg in $(echo "$choices" | tr -d '"'); do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Terminals installed.${NC}"
}
