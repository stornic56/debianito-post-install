#!/usr/bin/env bash
# communication.sh — Signal, Telegram, HexChat

_install_signal() {
    _ensure_extrepo
    if [ ! -f /etc/apt/sources.list.d/extrepo_signal.sources ]; then
        _run_cmd "Signal" "sudo extrepo enable signal" "Enabling Signal repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    if ! is_installed "signal-desktop"; then
        _run_cmd "Signal" "sudo apt install -y signal-desktop" "Installing Signal..."
        echo -e "${GREEN}Signal installed.${NC}"
    else
        echo "Signal already installed."
    fi
}

_install_telegram() {
    if [ "$DEBIAN_VERSION" = "13" ]; then
        if ! is_backports_enabled; then
            _msg "telegram-desktop" \
                "telegram-desktop is only available in Trixie-backports.\n\n\
Please enable backports first via:\n  Main Menu → 3  Configure Repositories" 12 65
            echo -e "${YELLOW}Skipping telegram-desktop.${NC}"
            return
        fi
        if ! is_installed "telegram-desktop"; then
            _run_cmd "Telegram" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports telegram-desktop" \
                "Installing telegram-desktop from backports..."
            echo -e "${GREEN}telegram-desktop installed.${NC}"
        else
            echo "telegram-desktop already installed."
        fi
    else
        if ! is_installed "telegram-desktop"; then
            _run_install "telegram-desktop"
            echo -e "${GREEN}telegram-desktop installed.${NC}"
        else
            echo "telegram-desktop already installed."
        fi
    fi
}

_cat_communication() {
    local headless=false
    _is_headless && headless=true
    if $headless; then
        echo "Communication apps require a GUI — skipping."
        return
    fi

    local -a items=()
    local signal_state;   signal_state=$(_state "signal-desktop")
    local telegram_state; telegram_state=$(_state "telegram-desktop")
    local hexchat_state;  hexchat_state=$(_state "hexchat")
    items+=(
        "signal-desktop"   "Signal Private Messenger (extrepo)"   "$signal_state"
        "telegram-desktop" "Telegram Desktop messaging"           "$telegram_state"
        "hexchat"          "IRC client (HexChat)"                 "$hexchat_state"
    )

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Communication" "Select communication apps${SCROLL_HINT}:" \
        $TUI_ALTO $TUI_ANCHO $lista_alto "${items[@]}")
    clear
    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        case $pkg in
            signal-desktop)   _install_signal ;;
            telegram-desktop) _install_telegram ;;
            hexchat)
                if ! is_installed "hexchat"; then
                    _run_install "hexchat"
                    echo -e "${GREEN}hexchat installed.${NC}"
                else
                    echo "hexchat already installed."
                fi
                ;;
        esac
    done
    echo -e "${GREEN}Communication tools installed.${NC}"
}
