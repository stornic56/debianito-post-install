# software_centers.sh — Standalone Software Center installer

_cat_software_centers() {
    local headless=false
    _is_headless && headless=true
    if $headless; then
        echo "Software centers require a GUI — skipping."
        return
    fi
    local de_type
    de_type=$(_detect_desktop_type)
    local sc_choice
    sc_choice=$(_menu "Software Centers" "Choose a software store to install:" 12 65 2 \
        "gnome-software"   "Software Center for GNOME$(_inst gnome-software)" \
        "plasma-discover"  "Software manager for Plasma$(_inst plasma-discover)" \
        )
    [ -z "$sc_choice" ] && return

    if { [ "$de_type" = "qt" ] && [ "$sc_choice" = "gnome-software" ]; } || \
       { [ "$de_type" = "gtk" ] && [ "$sc_choice" = "plasma-discover" ]; }; then
        _msg "Warning" "Warning: This store requires extra background libraries \
and may look visually inconsistent with your current desktop environment."
        ! _confirm "Continue?" "Install anyway?" && return
    fi

    _run_cmd "Install" "sudo apt install -y $sc_choice" "Installing ${sc_choice}..."

    if _confirm "Flatpak Support" "Do you want to enable Flatpak support for this software center?"; then
        local bpkg
        if [ "$sc_choice" = "gnome-software" ]; then
            bpkg="gnome-software-plugin-flatpak"
        else
            bpkg="plasma-discover-backend-flatpak"
        fi
        if ! is_installed "flatpak"; then
            _run_cmd "Flatpak" "sudo apt install -y flatpak" "Installing Flatpak..."
        fi
        _run_cmd "Plugin" "sudo apt install -y $bpkg" "Installing $bpkg..."
        flatpak remote-add --if-not-exists flathub \
            https://dl.flathub.org/repo/flathub.flatpakrepo
        echo "Flathub repository added."
    fi

    echo -e "${GREEN}Software store installed.${NC}"
}
