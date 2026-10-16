#!/usr/bin/env bash
# desktop_gnome.sh — GNOME desktop installer (SP2)
# Full: gnome + gdm3 | Core: gnome-core + gdm3
# Debian ships GNOME 48 (13), 43 (12) and 3.38 (11).
# License GPL v3

gnome_menu() {
    while true; do
        local -a gn_items=()
        gn_items+=("1" "GNOME (Full Desktop)")
        gn_items+=("2" "GNOME Core (Minimal Install)")
        gn_items+=("3" "Back")
        local choice
        choice=$(_menu "GNOME" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${gn_items[@]}")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
        1) _install_gnome_full ;;
        2) _install_gnome_core ;;
        3) break ;;
        esac
    done
}

_install_gnome_full() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "GNOME Full Desktop" gnome gdm3 || return

    echo -e "${GREEN}Installing GNOME (Full Desktop)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="gdm3"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "gdm3" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    _run_cmd "GNOME Full" "sudo apt install -y gnome gdm3" \
        "Installing GNOME (Full Meta Package) + GDM3..."
    if [ "$target_dm" = "gdm3" ]; then
        sudo systemctl enable gdm3
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}GNOME installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}

_install_gnome_core() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "GNOME Core" gnome-core gdm3 || return

    echo -e "${GREEN}Installing GNOME Core (Minimal)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="gdm3"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "gdm3" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    _run_cmd "GNOME Core" "sudo apt install -y gnome-core gdm3" \
        "Installing GNOME Core (Minimal) + GDM3..."
    if [ "$target_dm" = "gdm3" ]; then
        sudo systemctl enable gdm3
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}GNOME Core installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}
