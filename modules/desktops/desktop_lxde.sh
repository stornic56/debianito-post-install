#!/usr/bin/env bash
# desktop_lxde.sh — LXDE desktop installer (extracted from
# desktop_display.sh for architectural symmetry with
# desktop_gnome.sh and desktop_kde.sh).
# License GPL v3

lxde_menu() {
    local choice
    choice=$(_radiolist "LXDE" \
        "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "1" "LXDE (Full Desktop)" OFF \
        "2" "LXDE Core (Minimal Install)" OFF)
    [ -z "$choice" ] && return 0
    clear
    case "$(echo "$choice" | tr -d '"')" in
    1) _install_lxde_full ;;
    2) _install_lxde_core ;;
    esac
}

_install_lxde_full() {
    echo -e "${GREEN}Installing LXDE (Full) + LightDM...${NC}"
    echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
    _run_cmd "LXDE Full" "sudo apt install -y lxde lightdm" \
        "Installing LXDE (Full Meta Package) + LightDM..."
    sudo systemctl enable lightdm
    echo -e "${GREEN}LXDE installed. LightDM enabled.${NC}"
    _offer_pipewire_after_desktop
}

_install_lxde_core() {
    echo -e "${GREEN}Installing LXDE Core + LightDM...${NC}"
    echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
    _run_cmd "LXDE Core" "sudo apt install -y lxde-core lightdm" \
        "Installing LXDE Core (Minimal) + LightDM..."
    sudo systemctl enable lightdm
    echo -e "${GREEN}LXDE Core installed. LightDM enabled.${NC}"
    _offer_pipewire_after_desktop
}
