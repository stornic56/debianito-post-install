#!/usr/bin/env bash
# audio.sh — Audio & Sound (PipeWire, ALSA, PulseAudio tools)

_cat_audio() {
    local headless=false
    _is_headless && headless=true

    local -a items=()

    local pw_state; pw_state=$(_state "pipewire")
    items+=(
        "pipewire-standard" "PipeWire Audio Stack (Recommended)" "$pw_state"
    )

    if [ "$DEBIAN_VERSION" = "13" ]; then
        local bpo_state; bpo_state=$(_state "pipewire")
        items+=(
            "pipewire-backports" "PipeWire from Backports (v1.4.9)" "off"
        )
    fi

    local alsa_state; alsa_state=$(_state "alsa-utils")
    items+=(
        "alsa-utils" "ALSA Utilities (alsa-utils, alsa-ucm-conf)" "$alsa_state"
    )

    if ! $headless; then
        local pavu_state; pavu_state=$(_state "pavucontrol")
        items+=(
            "pavucontrol" "Volume Control GUI (pavucontrol)" "$pavu_state"
        )
    fi

    local pulsemixer_state; pulsemixer_state=$(_state "pulsemixer")
    local playerctl_state;  playerctl_state=$(_state "playerctl")
    items+=(
        "pulsemixer" "Terminal audio mixer (pulsemixer)" "$pulsemixer_state"
        "playerctl"  "Multimedia key controller (playerctl)" "$playerctl_state"
    )

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Audio & Sound" "Check [*] the packages you want installed.\n" \
        $TUI_ALTO $TUI_ANCHO $lista_alto "${items[@]}")
    clear
    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    local do_pipewire_standard=false
    local do_pipewire_backports=false

    for pkg in $cleaned; do
        case $pkg in
            pipewire-standard) do_pipewire_standard=true ;;
            pipewire-backports) do_pipewire_backports=true ;;
        esac
    done

    for pkg in $cleaned; do
        case $pkg in
            pipewire-standard)
                if $do_pipewire_backports; then
                    continue
                fi
                _install_pipewire_standard
                ;;
            pipewire-backports)
                _install_pipewire_backports
                ;;
            alsa-utils)
                if ! is_installed "alsa-utils"; then
                    _run_install "alsa-utils alsa-ucm-conf"
                else
                    echo "alsa-utils already installed."
                fi
                ;;
            pavucontrol)
                if ! is_installed "pavucontrol"; then
                    _run_install "pavucontrol"
                else
                    echo "pavucontrol already installed."
                fi
                ;;
            pulsemixer)
                if ! is_installed "pulsemixer"; then
                    _run_install "pulsemixer"
                else
                    echo "pulsemixer already installed."
                fi
                ;;
            playerctl)
                if ! is_installed "playerctl"; then
                    _run_install "playerctl"
                else
                    echo "playerctl already installed."
                fi
                ;;
        esac
    done

    if $do_pipewire_standard || $do_pipewire_backports; then
        if [ "$DEBIAN_VERSION" != "11" ]; then
            echo "Restarting PipeWire services..."
            systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
            echo -e "${GREEN}PipeWire services restarted.${NC}"
        fi
    fi

    echo -e "${GREEN}Audio & Sound setup complete.${NC}"
}

_install_pipewire_standard() {
    case "$DEBIAN_VERSION" in
        11)
            if ! is_installed "pipewire"; then
                _run_cmd "PipeWire" \
                    "sudo apt install -y pipewire libspa-0.2-bluetooth pipewire-alsa libspa-0.2-jack" \
                    "Installing PipeWire (Bullseye basic mode)..."
                echo -e "${GREEN}PipeWire installed (Bullseye basic mode).${NC}"
            else
                echo "PipeWire already installed."
            fi
            ;;
        12)
            if ! is_installed "pipewire-audio"; then
                _run_cmd "PipeWire" \
                    "sudo apt install -y pipewire-audio" \
                    "Installing pipewire-audio meta-package (Bookworm)..."
                echo -e "${GREEN}PipeWire audio stack installed.${NC}"
            else
                echo "pipewire-audio already installed."
            fi
            ;;
        13)
            if ! is_installed "pipewire-audio"; then
                _run_cmd "PipeWire" \
                    "sudo apt install -y pipewire-audio" \
                    "Installing pipewire-audio meta-package (Trixie)..."
                echo -e "${GREEN}PipeWire audio stack installed.${NC}"
            else
                echo "pipewire-audio already installed."
            fi
            ;;
    esac
}

_install_pipewire_backports() {
    if [ "$DEBIAN_VERSION" != "13" ]; then
        echo -e "${YELLOW}Backports install is only available on Debian 13 (Trixie). Skipping.${NC}"
        return
    fi

    if ! is_backports_enabled; then
        _msg "Backports Required" \
            "Trixie-backports is not enabled.\n\nEnable it first via:\n  Main Menu → 3 → Configure Repositories" 12 65
        echo -e "${YELLOW}Skipping PipeWire from backports.${NC}"
        return
    fi

    if ! is_installed "pipewire-audio"; then
        _run_cmd "PipeWire Backports" \
            "sudo apt install -y -t ${DEBIAN_CODENAME}-backports pipewire-audio" \
            "Installing PipeWire from trixie-backports (v1.4.9)..."
    else
        echo "pipewire-audio already installed."
    fi
}
