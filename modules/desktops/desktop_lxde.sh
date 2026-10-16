#!/usr/bin/env bash
# desktop_lxde.sh — LXDE desktop installer (extracted from
# desktop_display.sh for architectural symmetry with
# desktop_gnome.sh and desktop_kde.sh).
# License GPL v3

lxde_menu() {
    while true; do
        local -a lx_items=()
        lx_items+=("1" "LXDE (Full Desktop)")
        lx_items+=("2" "LXDE Core (Minimal Install)")
        lx_items+=("3" "LXDE Custom (Choose packages)")
        lx_items+=("4" "Back")
        local choice
        choice=$(_menu "LXDE" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${lx_items[@]}")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
        1) _install_lxde_full ;;
        2) _install_lxde_core ;;
        3) _install_lxde_custom ;;
        4) break ;;
        esac
    done
}

_install_lxde_full() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "LXDE Full Desktop" lxde lightdm || return

    echo -e "${GREEN}Installing LXDE (Full Desktop)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="lightdm"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "lightdm" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    if [ "$target_dm" = "lightdm" ]; then
        _run_cmd "LXDE Full" "sudo apt install -y lxde lightdm" \
            "Installing LXDE (Full Meta Package) + LightDM..."
        sudo systemctl enable lightdm
    else
        _run_cmd "LXDE Full" "sudo apt install -y lxde" \
            "Installing LXDE (Full Meta Package)..."
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}LXDE installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}

_install_lxde_core() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "LXDE Core" lxde-core lightdm || return

    echo -e "${GREEN}Installing LXDE Core (Minimal)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="lightdm"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "lightdm" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    if [ "$target_dm" = "lightdm" ]; then
        _run_cmd "LXDE Core" "sudo apt install -y lxde-core lightdm" \
            "Installing LXDE Core (Minimal) + LightDM..."
        sudo systemctl enable lightdm
    else
        _run_cmd "LXDE Core" "sudo apt install -y lxde-core" \
            "Installing LXDE Core (Minimal)..."
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}LXDE Core installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}

_install_lxde_custom() {
    # Fixed base (not selectable); extras chosen from the checklist.
    # lxterminal, polkitd, notification-daemon and light-locker are
    # intentionally absent: they arrive via lxde-core's Recommends
    # (verified on packages.debian.org/trixie, 2026-10-16).
    local cleaned
    cleaned=$(_select_packages_checklist "LXDE Custom" \
        "Select the extra LXDE packages to install:" \
        "lxappearance|Theme/appearance config" \
        "lxappearance-obconf|Openbox theme settings" \
        "lxrandr|Monitor configuration" \
        "lxinput|Keyboard/mouse settings" \
        "lxsession-edit|Session editor" \
        "lxhotkey-gtk|Keyboard shortcuts config" \
        "lxde-icon-theme|LXDE icon theme" \
        "gpicview|Image viewer" \
        "xarchiver|Archive manager" \
        "galculator|Calculator" \
        "mousepad|Text editor" \
        "lxpolkit|PolicyKit authentication agent" \
        "lxtask|Task manager" \
        "numlockx|Enable NumLock on startup" \
        "network-manager-applet|NetworkManager applet" \
        "gnome-disk-utility|Disk utility")
    [ -z "$cleaned" ] && return
    # BH-004: reparse the space-separated selection into an array.
    local -a lxde_pkgs=()
    local _pkg
    while IFS= read -r _pkg; do
        [ -n "$_pkg" ] && lxde_pkgs+=("$_pkg")
    done < <(echo "$cleaned" | tr ' ' '\n')
    if [ ${#lxde_pkgs[@]} -eq 0 ]; then
        _msg "LXDE Custom" "No extra packages selected — installing the\nfixed base only (equivalent to LXDE Core)." 10 60
    fi

    # Fixed base: lxde-core + xserver-xorg always; lightdm only
    # when no display manager is configured yet — never force it
    # over an existing one.
    local -a base_pkgs=(lxde-core xserver-xorg)
    local install_dm=0 keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -z "$keep_dm" ]; then
        base_pkgs+=(lightdm)
        install_dm=1
    else
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
    fi

    # Pre-apply summary: confirm base + selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "LXDE Custom" "${base_pkgs[@]}" "${lxde_pkgs[@]}" || return

    if [ "$install_dm" -eq 1 ]; then
        echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
    fi
    _ensure_apt_updated
    _run_cmd "LXDE Custom" "sudo apt install -y ${base_pkgs[*]} ${lxde_pkgs[*]}" \
        "Installing LXDE base + selected packages..."
    if [ "$install_dm" -eq 1 ]; then
        sudo systemctl enable lightdm
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}LXDE installed (base: ${base_pkgs[*]}).${NC}"
    _offer_pipewire_after_desktop
}
