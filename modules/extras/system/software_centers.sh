# software_centers.sh — Standalone Software Center + Flatpak installer

_cat_software_centers() {
    local headless=false
    _is_headless && headless=true
    if $headless; then
        echo "Software centers require a GUI — skipping."
        return
    fi

    local de_type
    de_type=$(_detect_desktop_type)

    local -a items=()
    local gs_state; gs_state=$(_state "gnome-software")
    local pd_state; pd_state=$(_state "plasma-discover")
    local sy_state; sy_state=$(_state "synaptic")
    local fp_state; fp_state=$(_state "flatpak")
    items+=(
        "gnome-software"   "Software Center for GNOME"               "$gs_state"
        "plasma-discover"  "Software manager for Plasma"             "$pd_state"
        "synaptic"         "Classic APT package manager (GTK)"       "$sy_state"
        "flatpak"          "Flatpak sandbox + Flathub"               "$fp_state"
    )

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Software Center & Flatpak" \
        "Check [*] the packages you want installed.\n" \
        $TUI_ALTO $TUI_ANCHO $lista_alto "${items[@]}")
    clear
    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            gnome-software)
                if [ "$de_type" = "qt" ]; then
                    _msg "Warning" "Warning: This store requires extra background libraries \
and may look visually inconsistent with your current desktop environment."
                    ! _confirm "Continue?" "Install anyway?" && continue
                fi
                _run_cmd "Install" "sudo apt install -y gnome-software" "Installing GNOME Software..."
                echo -e "${GREEN}gnome-software installed.${NC}"
                ;;
            plasma-discover)
                if [ "$de_type" = "gtk" ]; then
                    _msg "Warning" "Warning: This store requires extra background libraries \
and may look visually inconsistent with your current desktop environment."
                    ! _confirm "Continue?" "Install anyway?" && continue
                fi
                _run_cmd "Install" "sudo apt install -y plasma-discover" "Installing Plasma Discover..."
                echo -e "${GREEN}plasma-discover installed.${NC}"
                ;;
            synaptic)
                _run_cmd "Install" "sudo apt install -y synaptic" "Installing synaptic..."
                echo -e "${GREEN}synaptic installed.${NC}"
                ;;
            flatpak)
                if ! is_installed "flatpak"; then
                    _run_cmd "Flatpak" "sudo apt install -y flatpak" "Installing Flatpak..."
                else
                    echo "Flatpak already installed."
                fi
                flatpak remote-add --if-not-exists flathub \
                    https://dl.flathub.org/repo/flathub.flatpakrepo
                echo "Flathub repository added."

                if command -v plasma-discover &>/dev/null; then
                    if ! is_installed "plasma-discover-backend-flatpak" 2>/dev/null; then
                        if _confirm "Discover Backend" "Install Flatpak backend for Plasma Discover?"; then
                            _run_cmd "Backend" "sudo apt install -y plasma-discover-backend-flatpak" "Installing Flatpak backend..."
                        fi
                    fi
                elif command -v gnome-software &>/dev/null; then
                    if ! is_installed "gnome-software-plugin-flatpak" 2>/dev/null; then
                        if _confirm "GNOME Plugin" "Install Flatpak plugin for GNOME Software?"; then
                            _run_cmd "Plugin" "sudo apt install -y gnome-software-plugin-flatpak" "Installing Flatpak plugin..."
                        fi
                    fi
                else
                    if [ "$de_type" = "qt" ]; then
                        if _confirm "Software Center" "Install Plasma Discover for Flatpak management?"; then
                            _run_cmd "Discover" "sudo apt install -y plasma-discover plasma-discover-backend-flatpak" "Installing Discover..."
                        fi
                    else
                        if _confirm "Software Center" "Install GNOME Software for Flatpak management?"; then
                            _run_cmd "GNOME Software" "sudo apt install -y gnome-software gnome-software-plugin-flatpak" "Installing GNOME Software..."
                        fi
                    fi
                fi
                echo -e "${GREEN}A reboot is recommended.${NC}"
                ;;
        esac
    done

    echo -e "${GREEN}Software center & Flatpak setup complete.${NC}"
}
