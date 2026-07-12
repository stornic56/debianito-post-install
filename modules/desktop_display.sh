#!/usr/bin/env bash

manage_desktop_display() {
    while true; do
        local choice
        choice=$(_menu "Desktop & Display" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "1" "Desktop Environment" \
            "2" "Display Manager" \
            "3" "Back to main menu")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
            1) _msg "Coming Soon" "Desktop Environment management will be available in a future update." 10 60 ;;
            2) display_manager_menu ;;
            3) break ;;
        esac
    done
}

display_manager_menu() {
    while true; do
        local choice
        choice=$(_menu "Display Manager" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "1" "LightDM" \
            "2" "Back")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
            1) lightdm_config_menu ;;
            2) break ;;
        esac
    done
}

lightdm_config_menu() {
    local -a items=()
    items+=("install_lightdm"   "Install LightDM & GTK Greeter" "$(_state lightdm)")
    items+=("enable_userlist"   "Enable user list"             "OFF")
    local choices
    choices=$(_checklist "LightDM Configuration" \
        "Select options to apply:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "${items[@]}")
    if [ -z "$choices" ]; then
        echo "No changes."
        _pause
        return
    fi
    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')
    for item in $cleaned; do
        case $item in
            install_lightdm)
                if is_installed lightdm; then
                    echo -e "${GREEN}LightDM is already installed.${NC}"
                else
                    _run_cmd "LightDM" "sudo apt install -y lightdm lightdm-gtk-greeter-settings" "Installing LightDM..."
                fi
                ;;
            enable_userlist)
                local conf="/etc/lightdm/lightdm.conf.d/50-debianito-userlist.conf"
                if echo "[Seat:*]
greeter-hide-users=false" | sudo tee "$conf" > /dev/null; then
                    echo -e "${GREEN}User list enabled in LightDM.${NC}"
                else
                    echo -e "${RED}Failed to write configuration.${NC}"
                fi
                ;;
        esac
    done
    _pause
}
