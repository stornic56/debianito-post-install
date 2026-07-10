#!/usr/bin/env bash
# sudo_config.sh — User Privileges & Feedback submenu
# License GPL v3

config_sudo() {
    echo -e "${YELLOW}User Privileges & Feedback${NC}"

    while true; do
        local choice
        choice=$(_menu "User Privileges & Feedback" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "1" "Sudo Group Membership" \
            "2" "Passwordless Sudo (maintenance commands)" \
            "3" "Repair Home Directory Ownership" \
            "4" "Sudo Password Feedback (asterisks)" \
            "5" "Back to main menu")

        [ -z "$choice" ] && return
        clear

        case "$choice" in
            1) _check_sudo_group ;;
            2) _configure_nopasswd ;;
            3) _repair_home_ownership ;;
            4) _toggle_pwfeedback ;;
            5) return ;;
        esac
    done
}

# ── Option 1: Sudo Group Membership ──
_check_sudo_group() {
    if groups "$USER" | grep -qE '\bsudo\b'; then
        _msg "Sudo Group" "User '$USER' is already in the sudo group."
    else
        if _confirm "Sudo Group" \
            "User '$USER' is NOT in the sudo group.\n\nAdd to sudo group?"; then
            if sudo usermod -aG sudo "$USER"; then
                _msg "Sudo Group" \
                    "User added to sudo group.\n\nLog out and back in for\ngroup changes to take effect." 10 60
            else
                _msg "Sudo Group" "Failed to add user to sudo group." 7 60
                return 1
            fi
        fi
    fi
}

# ── Option 2: Passwordless Sudo (NOPASSWD) ──
_configure_nopasswd() {
    local nopasswd_file="/etc/sudoers.d/${USER}-nopasswd"

    if [ -f "$nopasswd_file" ]; then
        if _confirm "NOPASSWD" \
            "Passwordless sudo is already configured.\n\nRemove it to restore password prompts?"; then
            sudo rm -f "$nopasswd_file"
            echo -e "${GREEN}Passwordless sudo removed.${NC}"
        fi
        return
    fi

    if _confirm "NOPASSWD" \
        "Configure passwordless sudo for maintenance commands?\n\n\
  - apt / apt-get (package management)\n\
  - systemctl (service management)\n\
  - shutdown / reboot / halt (power commands)\n\n\
Useful for automation but reduces security." 14 70; then
        local choices
        choices=$(_checklist "NOPASSWD Commands" \
            "Select commands to allow without password:" 12 60 3 \
            "apt"       "APT package management" ON \
            "systemctl" "Systemd service management" ON \
            "power"     "Shutdown, reboot, halt" ON)
        clear

        [ -z "$choices" ] && { echo "No commands selected."; return; }
        local cleaned; cleaned=$(echo "$choices" | tr -d '"')

        local content=""
        for cmd in $cleaned; do
            case $cmd in
                apt)
                    content+="${USER} ALL=(root) NOPASSWD: /usr/bin/apt, /usr/bin/apt-get, /bin/apt, /bin/apt-get\n"
                    ;;
                systemctl)
                    content+="${USER} ALL=(root) NOPASSWD: /usr/bin/systemctl, /bin/systemctl\n"
                    ;;
                power)
                    content+="${USER} ALL=(root) NOPASSWD: /usr/sbin/shutdown, /sbin/shutdown, /usr/sbin/reboot, /sbin/reboot, /usr/sbin/halt, /sbin/halt\n"
                    ;;
            esac
        done

        local content_str; content_str=$(echo -e "$content")
        if _validate_sudoers "$content_str" "$nopasswd_file"; then
            echo -e "${GREEN}Passwordless sudo configured for selected commands.${NC}"
        else
            return 1
        fi
    fi
}

# ── Option 3: Repair Home Directory Ownership ──
_repair_home_ownership() {
    local home
    home=$(eval echo "~$USER")

    if [ ! -d "$home" ]; then
        _msg "Home Directory" "Home directory '$home' does not exist." 8 60
        return 1
    fi

    local uid uid_owner
    uid=$(id -u "$USER" 2>/dev/null)
    uid_owner=$(stat -c '%u' "$home" 2>/dev/null || echo "0")

    if [ "$uid_owner" != "$uid" ]; then
        local expected_user
        expected_user=$(id -nu "$uid_owner" 2>/dev/null || echo "UID $uid_owner")
        if _confirm "Home Permissions" \
            "Home directory '$home' is owned by\n'$expected_user' (expected: '$USER').\n\nRepair ownership?" 12 65; then
            if sudo chown -R "$USER:$USER" "$home"; then
                echo -e "${GREEN}Home directory ownership repaired.${NC}"
            else
                echo -e "${RED}Failed to repair home directory ownership.${NC}"
                return 1
            fi
        fi
    else
        _msg "Home Permissions" "Home directory ownership is correct\n(owner: $USER)." 8 60
    fi
}

# ── Option 4: Sudo Password Feedback (pwfeedback) ──
_toggle_pwfeedback() {
    local fb_file="/etc/sudoers.d/pwfeedback"

    if [ -f "$fb_file" ]; then
        if _confirm "Password Feedback" \
            "Asterisks are currently ENABLED when typing sudo password.\n\nDisable them?"; then
            sudo rm -f "$fb_file"
            echo -e "${GREEN}Password feedback disabled.${NC}"
        fi
    else
        if _confirm "Password Feedback" \
            "Show asterisks when typing the sudo password?"; then
            if _validate_sudoers 'Defaults pwfeedback' "$fb_file"; then
                echo -e "${GREEN}Password feedback enabled.${NC}"
            else
                return 1
            fi
        fi
    fi
}
