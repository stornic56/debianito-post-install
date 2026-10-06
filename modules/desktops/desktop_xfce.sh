#!/usr/bin/env bash
# desktop_xfce.sh — XFCE desktop installer (extracted from
# desktop_display.sh for architectural symmetry with
# desktop_gnome.sh and desktop_kde.sh).
# License GPL v3

xfce_menu() {
    while true; do
        local -a xf_items=()
        xf_items+=("1" "XFCE (Full Meta Package)")
        xf_items+=("2" "XFCE (Minimal Core)")
        [ "$DEBIAN_VERSION" = "13" ] && xf_items+=("3" "XFCE Wayland (Experimental — labwc)")
        xf_items+=("4" "XFCE Custom (Choose packages)")
        xf_items+=("5" "Back")
        local choice
        choice=$(_menu "XFCE" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${xf_items[@]}")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
        1) _install_xfce_full ;;
        2) _install_xfce_minimal ;;
        3) _install_xfce_wayland ;;
        4) _install_xfce_custom ;;
        5) break ;;
        esac
    done
}

_install_xfce_full() {
    _run_cmd "XFCE Full" "sudo apt install -y xfce4 xfce4-goodies xfce4-power-manager" \
        "Installing XFCE (Full Meta Package)..."
    _xfce_polkit_rules
    _offer_pipewire_after_desktop
}

_install_xfce_minimal() {
    _run_cmd "XFCE Minimal" "sudo apt install -y xfce4" \
        "Installing XFCE (Minimal Core)..."
    _xfce_polkit_rules
    _offer_pipewire_after_desktop
}

_install_xfce_wayland() {
    _run_cmd "XFCE Wayland" "sudo apt install -y xfce4 labwc" \
        "Installing XFCE + labwc (Wayland, experimental)..."
    _msg "XFCE Wayland" "labwc is EXPERIMENTAL on XFCE 4.20.\n\nAfter reboot, select the Wayland session\nfrom the login screen." 12 65
    _xfce_polkit_rules
    _offer_pipewire_after_desktop
}

_install_xfce_custom() {
    local -a items=()
    for pkg in thunar xfdesktop4 xfwm4 xfce4-panel xfce4-terminal \
        xfce4-screenshooter ristretto mousepad xfce4-session \
        xfce4-settings xfce4-power-manager; do
        items+=("$pkg" "$pkg" "$(_state "$pkg")")
    done
    local choices
    choices=$(_checklist "XFCE Custom" \
        "Select the XFCE packages to install:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "${items[@]}")
    [ -z "$choices" ] && return
    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')
    [ -z "$cleaned" ] && return

    # BH-004: Convert to array to avoid word splitting and injection.
    local -a xfce_pkgs=()
    while IFS= read -r _pkg; do
        [ -n "$_pkg" ] && xfce_pkgs+=("$_pkg")
    done < <(echo "$cleaned" | tr ' ' '\n')

    # Pre-apply summary: confirm the selection before
    # the batch apt transaction starts.
    _confirm_install_list "XFCE Custom" "${xfce_pkgs[@]}" || return

    _run_cmd "XFCE Custom" "sudo apt install -y ${xfce_pkgs[*]}" \
        "Installing selected XFCE packages..."
    # Release the per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    _xfce_polkit_rules
    _offer_pipewire_after_desktop
}

_xfce_polkit_rules() {
    is_installed xfce4-power-manager || return 0

    local rules_dir="/etc/polkit-1/rules.d"
    sudo mkdir -p "$rules_dir"

    cat <<'EOF' | sudo tee "$rules_dir/85-suspend.rules" >/dev/null
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.login1.suspend" &&
        subject.isInGroup("users")) {
        return polkit.Result.YES;
    }
});
EOF
    cat <<'EOF' | sudo tee "$rules_dir/89-backlight.rules" >/dev/null
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.upower.backlight" &&
        subject.isInGroup("backlight")) {
        return polkit.Result.YES;
    }
});
EOF

    if ! getent group backlight >/dev/null 2>&1; then
        sudo groupadd --system backlight || true
    fi
    # SECURITY: Validate that the target user is a real login user, not root.
    # If SUDO_USER is empty (script run directly as root), fall back to the
    # first non-system user from /etc/passwd, never to root.
    local de_user="${SUDO_USER:-}"
    if [ -z "$de_user" ] || [ "$de_user" = "root" ]; then
        de_user=$(awk -F: '$3>=1000 && $3<65534 {print $1}' /etc/passwd | head -1)
    fi
    if [ -n "$de_user" ] && ! id -nG "$de_user" 2>/dev/null | grep -qw backlight; then
        sudo usermod -aG backlight "$de_user" || true
    fi
    sudo systemctl restart polkit.service 2>/dev/null || true
    echo -e "${GREEN}Polkit rules installed (suspend + backlight). User '${de_user}' added to 'backlight' group.${NC}"
}
