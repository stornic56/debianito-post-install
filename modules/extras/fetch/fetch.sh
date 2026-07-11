#!/usr/bin/env bash
# fetch.sh — System info / fetch tools

_cat_fetch() {
    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    local fetch_state;    fetch_state=$(_state "$fetch_pkg")
    local linuxlogo_state; linuxlogo_state=$(_state "linuxlogo")
    local screenfetch_state; screenfetch_state=$(_state "screenfetch")

    local hyfetch_state="OFF"
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        hyfetch_state=$(_state "hyfetch")
    fi

    local -a items=()

    if [ "$fetch_pkg" = "fastfetch" ]; then
        items+=("fastfetch" "System info fetcher$(_inst fastfetch)" "$fetch_state")
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            items+=("hyfetch" "Neofetch with pride flags$(_inst hyfetch)" "$hyfetch_state")
        fi
    fi
    items+=("linuxlogo" "Linux logo + system info$(_inst linuxlogo)" "$linuxlogo_state")
    if [ "$fetch_pkg" = "neofetch" ]; then
        items+=("neofetch" "System info fetcher$(_inst neofetch)" "$fetch_state")
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            items+=("hyfetch" "Neofetch with pride flags$(_inst hyfetch)" "$hyfetch_state")
        fi
    fi
    items+=("screenfetch" "System info (BSD/Linux)$(_inst screenfetch)" "$screenfetch_state")

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(_checklist "Fetch Tools" "Select system info tools:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "${items[@]}" \
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            neofetch|fastfetch)
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
            *)
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Fetch tools installed.${NC}"
}
