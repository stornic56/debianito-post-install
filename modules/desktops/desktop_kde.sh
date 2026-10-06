#!/usr/bin/env bash
# desktop_kde.sh — KDE Plasma desktop installer (SP2)
# Full: kde-standard + sddm | Minimal: kde-plasma-desktop + sddm
# Bookworm ships Plasma 5.27.5; Wayland is the default
# session since Debian 12.
# License GPL v3

kde_menu() {
    local choice
    choice=$(_radiolist "KDE Plasma" \
        "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "1" "KDE Plasma (Full Desktop)" OFF \
        "2" "KDE Plasma Desktop (Minimal)" OFF \
        "3" "Back" OFF)
    [ -z "$choice" ] && return 0
    clear
    case "$(echo "$choice" | tr -d '"')" in
    1) _install_kde_full ;;
    2) _install_kde_minimal ;;
    3) return 0 ;;
    esac
}

_install_kde_full() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "KDE Plasma Full" kde-standard sddm || return

    echo -e "${GREEN}Installing KDE Plasma (Full)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="sddm"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "sddm" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    _run_cmd "KDE Full" "sudo apt install -y kde-standard sddm" \
        "Installing KDE Plasma (Full Meta Package) + SDDM..."
    if [ "$target_dm" = "sddm" ]; then
        sudo systemctl enable sddm
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}KDE Plasma installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}

_install_kde_minimal() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "KDE Plasma Minimal" kde-plasma-desktop sddm || return

    echo -e "${GREEN}Installing KDE Plasma Desktop (Minimal)...${NC}"

    # Keep an already-configured display manager intact.
    local target_dm="sddm"
    local keep_dm
    keep_dm=$(_existing_display_manager)
    if [ -n "$keep_dm" ] && [ "$keep_dm" != "sddm" ]; then
        echo -e "${YELLOW}Display manager '${keep_dm}' is already configured — keeping it as default.${NC}"
        target_dm="$keep_dm"
    fi
    echo "${target_dm} shared/default-x-display-manager select ${target_dm}" | sudo debconf-set-selections
    _ensure_apt_updated
    _run_cmd "KDE Minimal" "sudo apt install -y kde-plasma-desktop sddm" \
        "Installing KDE Plasma Desktop (Minimal) + SDDM..."
    if [ "$target_dm" = "sddm" ]; then
        sudo systemctl enable sddm
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}KDE Plasma Desktop installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}
