#!/usr/bin/env bash
# audio.sh — Audio & Sound (PipeWire, ALSA, PulseAudio tools)

_cat_audio() {
    local headless=false
    _is_headless && headless=true

    local -a items=()

    local pw_label="PipeWire Audio Stack (Bluetooth Hi-Res)"

    local pw_state; pw_state=$(_state "pipewire-audio")
    items+=(
        "pipewire-audio" "$pw_label" "$pw_state"
    )

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

    for pkg in $cleaned; do
        case $pkg in
            pipewire-audio) _install_pipewire_standard ;;
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

    echo -e "${GREEN}Audio & Sound setup complete.${NC}"
}

_install_pipewire_standard() {
    local bt_pkgs="libldacbt-abr2 libldacbt-enc2 libopenaptx0 libspa-0.2-bluetooth"
    if apt-cache show libfdk-aac2t64 &>/dev/null; then
        bt_pkgs+=" libfdk-aac2t64"
    elif apt-cache show libfdk-aac2 &>/dev/null; then
        bt_pkgs+=" libfdk-aac2"
    fi

    # ── Resolve versions (needed for both installed and not-installed branches) ──
    local stable_ver=""
    stable_ver=$(apt-cache policy pipewire-audio 2>/dev/null | awk 'NR==3 {print $2; exit}') || true
    local bpo_ver=""
    if [ "$DEBIAN_VERSION" = "13" ] && [ "$(is_backports_enabled)" = "true" ]; then
        bpo_ver=$(apt-cache madison pipewire-audio 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1) || true
    fi

    local pkg_check="pipewire-audio"
    [ "$DEBIAN_VERSION" = "11" ] && pkg_check="pipewire"

    # ── Already installed branch ──
    if is_installed "$pkg_check"; then
        if [ -n "$bpo_ver" ]; then
            local current_ver
            current_ver=$(dpkg -l "$pkg_check" 2>/dev/null | awk '/^ii/{print $3}') || true
            if _confirm "PipeWire" \
                "PipeWire ${current_ver:+v${current_ver} }already installed.\n\nUpgrade to backports version v${bpo_ver}?"; then
                echo "Upgrading PipeWire Audio Stack..."
                echo "-> Target version: v${bpo_ver} (from ${DEBIAN_CODENAME}-backports)"
                echo "-> Including Bluetooth Hi-Res codecs (LDAC, aptX, AAC)"
                _run_cmd "PipeWire" \
                    "sudo apt install -y --reinstall -t ${DEBIAN_CODENAME}-backports pipewire-audio $bt_pkgs" \
                    "Upgrading PipeWire from backports..."
                if [ "$DEBIAN_VERSION" != "11" ]; then
                    echo "Restarting PipeWire services..."
                    systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
                    echo -e "${GREEN}PipeWire services restarted.${NC}"
                fi
                return
            fi
        fi
        echo "$pkg_check already installed."
        return
    fi

    # ── Confirm dialog ──
    local apt_target="" pw_ver="" pw_src=""
    if [ -n "$bpo_ver" ]; then
        local msg="Backports repository is enabled.\n\n"
        msg+="Available versions:\n"
        msg+="  - Stable:   v${stable_ver:-unknown}\n"
        msg+="  - Backports: v${bpo_ver}\n\n"
        msg+="Install from Backports (Recommended for newer hardware)\nor from Stable (more conservative)?"
        if _confirm_custom "PipeWire Install" "$msg" "Backports" "Stable" 14 70; then
            apt_target="-t ${DEBIAN_CODENAME}-backports"
            pw_ver="$bpo_ver"
            pw_src="from ${DEBIAN_CODENAME}-backports"
        else
            pw_ver="$stable_ver"
        fi
    else
        local msg="PipeWire Audio Stack (v${stable_ver:-unknown})\n"
        msg+="will be installed along with Bluetooth Hi-Res\n"
        msg+="codecs (LDAC, aptX, AAC).\n\n"
        msg+="Continue with installation?"
        if ! _confirm "PipeWire Install" "$msg" 12 65; then
            echo "PipeWire installation cancelled."
            return
        fi
        pw_ver="$stable_ver"
    fi

    echo "Installing PipeWire Audio Stack..."
    echo "-> Detected version: ${pw_ver:-unknown} ${pw_src:+($pw_src)}"
    echo "-> Including Bluetooth Hi-Res codecs (LDAC, aptX, AAC)"

    case "$DEBIAN_VERSION" in
        11)
            _run_cmd "PipeWire" \
                "sudo apt install -y pipewire libspa-0.2-bluetooth pipewire-alsa libspa-0.2-jack $bt_pkgs" \
                "Installing PipeWire (Bullseye basic mode)..."
            echo -e "${GREEN}PipeWire installed (Bullseye basic mode).${NC}"
            ;;
        12)
            _run_cmd "PipeWire" \
                "sudo apt install -y pipewire-audio $bt_pkgs" \
                "Installing pipewire-audio meta-package (Bookworm)..."
            echo -e "${GREEN}PipeWire audio stack installed.${NC}"
            ;;
        13)
            _run_cmd "PipeWire" \
                "sudo apt install -y $apt_target pipewire-audio $bt_pkgs" \
                "Installing pipewire-audio meta-package (Trixie)..."
            echo -e "${GREEN}PipeWire audio stack installed.${NC}"
            ;;
    esac

    if [ "$DEBIAN_VERSION" != "11" ]; then
        echo "Restarting PipeWire services..."
        systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null || true
        echo -e "${GREEN}PipeWire services restarted.${NC}"
    fi
}
