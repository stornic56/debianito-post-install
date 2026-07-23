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
        local -a dm_items=()
        dm_items+=("1" "LightDM")
        dm_items+=("2" "GDM3")
        dm_items+=("3" "SDDM")
        if [ "$DEBIAN_VERSION" = "12" ] || [ "$DEBIAN_VERSION" = "13" ]; then
            dm_items+=("4" "greetd")
            dm_items+=("5" "Back")
        else
            dm_items+=("4" "Back")
        fi
        local choice
        choice=$(_menu "Display Manager" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "${dm_items[@]}")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
            1) lightdm_config_menu ;;
            2) configure_gdm3 ;;
            3) configure_sddm ;;
            4)
                if [ "$DEBIAN_VERSION" = "12" ] || [ "$DEBIAN_VERSION" = "13" ]; then
                    configure_greetd
                else
                    break
                fi
                ;;
            5) break ;;
        esac
    done
}

lightdm_config_menu() {
    local -a items=()
    items+=("install_lightdm"   "Install LightDM & GTK Greeter" "$(_state lightdm)")
    items+=("enable_userlist"   "Enable user list at login screen" "OFF")
    items+=("enable_autologin"  "Enable autologin for current user" "OFF")
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
    if ! is_installed lightdm || ! is_installed lightdm-gtk-greeter-settings; then
        echo "lightdm shared/default-x-display-manager select lightdm" | sudo debconf-set-selections
        _run_cmd "LightDM" "sudo apt install -y lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings" "Installing LightDM & GTK Greeter..."
    else
        echo -e "${GREEN}[LightDM] LightDM and GTK Greeter settings are already installed, skipping...${NC}"
    fi
    ;;
            enable_userlist)
                local conf="/etc/lightdm/lightdm.conf.d/50-debianito-userlist.conf"
                sudo mkdir -p "$(dirname "$conf")"
                if echo "[Seat:*]
greeter-hide-users=false" | sudo tee "$conf" > /dev/null; then
                    echo -e "${GREEN}User list enabled in LightDM.${NC}"
                else
                    echo -e "${RED}Failed to write configuration.${NC}"
                fi
                ;;
            enable_autologin)
                local dm_conf="/etc/lightdm/lightdm.conf"
                local lightdm_user="${SUDO_USER:-$USER}"
                sudo sed -i 's/^#[[:space:]]*autologin-user[[:space:]=].*/autologin-user='"$lightdm_user"'/' "$dm_conf"
                sudo sed -i 's/^#[[:space:]]*autologin-user-timeout[[:space:]=].*/autologin-user-timeout=0/' "$dm_conf"
                echo -e "${GREEN}Autologin enabled for user: ${lightdm_user}${NC}"
                ;;
            esac
        done
        _pause
}

configure_greetd() {
    while true; do
        local -a gd_items=()
        gd_items+=("1" "Install base greetd")
        gd_items+=("2" "Install greetd + tuigreet (Recommended TUI greeter)")
        if [ "$DEBIAN_VERSION" = "13" ]; then
            gd_items+=("3" "Install gtkgreet (Requires manual setup)")
            gd_items+=("4" "Install nwg-hello (Requires manual setup)")
            gd_items+=("5" "Install wlgreet (Requires manual setup)")
            gd_items+=("6" "Back")
        else
            gd_items+=("3" "Back")
        fi
        local choice
        choice=$(_menu "greetd Configuration" \
            "Select an option:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${gd_items[@]}")
        [ -z "$choice" ] && return
        clear
        case "$choice" in
            1)
                echo "greetd shared/default-x-display-manager select greetd" | sudo debconf-set-selections
                _run_cmd "greetd" "sudo apt install -y greetd" "Installing greetd..."
                _msg "greetd" "Warning: greetd was installed but NOT configured.\n\nYou must manually create /etc/greetd/config.toml\nto be able to log in.\n\nSee 'man greetd' and 'man 5 greetd-sessions'."
                ;;
            2)
                if [ "$DEBIAN_VERSION" = "12" ]; then
                    if [ "$(is_backports_enabled)" != true ]; then
                        _write_deb822_backports "bookworm"
                        sudo apt update -qq
                    fi
                    _run_cmd "greetd" "sudo apt install -y -t bookworm-backports tuigreet greetd" "Installing greetd + tuigreet..."
                else
                    _run_cmd "greetd" "sudo apt install -y greetd tuigreet" "Installing greetd + tuigreet..."
                fi
                _msg "greetd" "Warning: greetd was installed but NOT configured.\n\nYou must manually create /etc/greetd/config.toml\nto be able to log in.\n\nSee 'man greetd' and 'man 5 greetd-sessions'."
                ;;
            3)
                if [ "$DEBIAN_VERSION" = "13" ]; then
                    echo "greetd shared/default-x-display-manager select greetd" | sudo debconf-set-selections
                    _run_cmd "greetd" "sudo apt install -y greetd gtkgreet" "Installing greetd + gtkgreet..."
                    _msg "greetd" "Warning: greetd was installed but NOT configured.\n\nYou must manually create /etc/greetd/config.toml\nto be able to log in.\n\nSee 'man greetd' and 'man 5 greetd-sessions'."
                else
                    return
                fi
                ;;
            4)
                if [ "$DEBIAN_VERSION" = "13" ]; then
                    echo "greetd shared/default-x-display-manager select greetd" | sudo debconf-set-selections
                    _run_cmd "greetd" "sudo apt install -y greetd nwg-hello" "Installing greetd + nwg-hello..."
                    _msg "greetd" "Warning: greetd was installed but NOT configured.\n\nYou must manually create /etc/greetd/config.toml\nto be able to log in.\n\nSee 'man greetd' and 'man 5 greetd-sessions'."
                fi
                ;;
            5)
                if [ "$DEBIAN_VERSION" = "13" ]; then
                    echo "greetd shared/default-x-display-manager select greetd" | sudo debconf-set-selections
                    _run_cmd "greetd" "sudo apt install -y greetd wlgreet" "Installing greetd + wlgreet..."
                    _msg "greetd" "Warning: greetd was installed but NOT configured.\n\nYou must manually create /etc/greetd/config.toml\nto be able to log in.\n\nSee 'man greetd' and 'man 5 greetd-sessions'."
                fi
                ;;
            6) return ;;
        esac
    done
}

configure_gdm3() {
    while true; do
        local items_enabled=()
        items_enabled+=("install"     "Install/Reinstall gdm3 (Set as default)" "$(_state gdm3)")
        items_enabled+=("userlist"    "Hide user list (disable-user-list)"      "OFF")
        items_enabled+=("autologin"   "Configure Autologin"                     "OFF")
        if [ "$DEBIAN_VERSION" = "12" ] || [ "$DEBIAN_VERSION" = "13" ]; then
            if [ "$HAS_NVIDIA" = true ]; then
                items_enabled+=("wayland"  "Force Enable Wayland on NVIDIA (Risk!)" "OFF")
            fi
        fi
        local choice
        choice=$(_checklist "GDM3 Configuration" \
            "Select options to apply:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${items_enabled[@]}")
        [ -z "$choice" ] && return
        clear

        local cleaned
        cleaned=$(echo "$choice" | tr -d '"')
        for item in $cleaned; do
            case $item in
                install)
                    echo "gdm3 shared/default-x-display-manager select gdm3" | sudo debconf-set-selections
                    _run_cmd "GDM3" "sudo apt install -y gdm3" "Installing gdm3..."
                    ;;
                userlist)
                    local greeter_conf="/etc/gdm3/greeter.dconf-defaults"
                    if sudo grep -q '^disable-user-list=true' "$greeter_conf" 2>/dev/null; then
                        sudo sed -i 's/^disable-user-list=true/# disable-user-list=true/' "$greeter_conf"
                        echo -e "${GREEN}User list is now VISIBLE.${NC}"
                    else
                        sudo sed -i 's/^#[[:space:]]*disable-user-list=true/disable-user-list=true/' "$greeter_conf"
                        echo -e "${GREEN}User list is now HIDDEN.${NC}"
                    fi
                    sudo dpkg-reconfigure gdm3 >/dev/null 2>&1
                    ;;
                autologin)
                    local daemon_conf="/etc/gdm3/daemon.conf"
                    local username
                    username=$(whiptail --title "GDM3 Autologin" \
                        --inputbox "Enter username to autologin (leave empty to DISABLE autologin):" \
                        10 60 "" 3>&1 1>&2 2>&3 || true)
                    if [ -n "$username" ]; then
                        sudo sed -i 's/^# *AutomaticLoginEnable[[:space:]=].*/AutomaticLoginEnable=true/' "$daemon_conf"
                        sudo sed -i 's/^# *AutomaticLogin[[:space:]=].*/AutomaticLogin='"$username"'/' "$daemon_conf"
                        echo -e "${GREEN}Autologin enabled for user: ${username}${NC}"
                    else
                        sudo sed -i 's/^AutomaticLoginEnable[[:space:]=].*/# AutomaticLoginEnable=false/' "$daemon_conf"
                        sudo sed -i 's/^AutomaticLogin[[:space:]=].*/# AutomaticLogin=/' "$daemon_conf"
                        echo -e "${GREEN}Autologin disabled.${NC}"
                    fi
                    ;;
                wayland)
                    local rules_link="/etc/udev/rules.d/61-gdm.rules"
                    if [ -L "$rules_link" ] || [ -f "$rules_link" ]; then
                        sudo rm -f "$rules_link"
                        echo -e "${GREEN}Reverted. Wayland will be disabled by default on next reboot.${NC}"
                    elif [ -f "/lib/udev/rules.d/61-gdm.rules" ]; then
                        if _confirm "Wayland on NVIDIA" \
                            "Force-enable Wayland on NVIDIA?\n\nRisk: This may break graphics or cause instability.\nProceed?"; then
                            sudo ln -s /dev/null "$rules_link"
                            echo -e "${GREEN}Wayland override created. Reboot required.${NC}"
                        fi
                    fi
                    ;;
            esac
        done
        _pause
    done
}

configure_sddm() {
    while true; do
        local choice
        choice=$(_menu "SDDM Configuration" \
            "Select an option:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "Install SDDM (Set as default)" \
            "2" "Enable Autologin" \
            "3" "Back")
        [ -z "$choice" ] && return
        clear
        case "$choice" in
            1)
                echo "sddm shared/default-x-display-manager select sddm" | sudo debconf-set-selections
                _run_cmd "SDDM" "sudo apt install -y sddm" "Installing SDDM..."
                ;;
            2)
                local sddm_session=""
                local sddm_user="${SUDO_USER:-$USER}"
                if [ -f /usr/share/wayland-sessions/plasmawayland.desktop ]; then
                    sddm_session="plasmawayland"
                elif [ -f /usr/share/wayland-sessions/lxqt-wayland.desktop ]; then
                    sddm_session="lxqt-wayland"
                elif [ -f /usr/share/xsessions/plasma.desktop ]; then
                    sddm_session="plasma"
                elif [ -f /usr/share/xsessions/lxqt.desktop ]; then
                    sddm_session="lxqt"
                fi
                sudo mkdir -p /etc/sddm.conf.d
                cat << EOF | sudo tee /etc/sddm.conf.d/autologin.conf > /dev/null
[Autologin]
User=${sddm_user}
Session=${sddm_session}
Relogin=false
EOF
                if [ -n "$sddm_session" ]; then
                    echo -e "${GREEN}Autologin enabled for user ${sddm_user}, session: ${sddm_session}.${NC}"
                else
                    echo -e "${YELLOW}Autologin enabled for user ${sddm_user}. No session set (SDDM will use default).${NC}"
                fi
                _pause
                ;;
            3) return ;;
        esac
    done
}
