#!/usr/bin/env bash
# programming.sh — Programming Applications (text editors + IDEs)

_cat_programming() {
    local headless=false
    _is_headless && headless=true
    local vim_state;        vim_state=$(_state "vim")
    local vimgtk_state;     vimgtk_state=$(_state "vim-gtk3")
    local neovim_state;     neovim_state=$(_state "neovim")
    local hx_state;         hx_state=$(_state "hx")
    local nano_state;       nano_state=$(_state "nano")
    local emacs_state;      emacs_state=$(_state "emacs")
    local kate_state;       kate_state=$(_state "kate")
    local mousepad_state;   mousepad_state=$(_state "mousepad")
    local gedit_state;      gedit_state=$(_state "gedit")
    local geany_state;      geany_state=$(_state "geany")
    local gte_state;        gte_state=$(_state "gnome-text-editor")
    local codium_state="OFF"
    if command -v codium &>/dev/null; then
        codium_state="ON"
    fi

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Programming Applications" --checklist \
        "Select editors and IDEs (12 items, ↑↓ scroll):" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "vim"                "Classic terminal editor$(_inst vim)"                        "$vim_state" \
        "vim-gtk3"           "Vim with GTK3 GUI$(_inst vim-gtk3)"                        "$vimgtk_state" \
        "neovim"             "Modern vim fork$(_inst neovim)"                             "$neovim_state" \
        "hx"                 "Helix modal editor (Rust)$(_inst hx)"                      "$hx_state" \
        "nano"               "Simple terminal editor$(_inst nano)"                       "$nano_state" \
        "emacs"              "Extensible editor / IDE$(_inst emacs)"                     "$emacs_state" \
        "kate"               "KDE advanced text editor$(_inst kate)"                     "$kate_state" \
        "mousepad"           "Xfce text editor$(_inst mousepad)"                         "$mousepad_state" \
        "gedit"              "GNOME text editor$(_inst gedit)"                            "$gedit_state" \
        "geany"              "Lightweight IDE$(_inst geany)"                              "$geany_state" \
        "gnome-text-editor"  "GNOME modern text editor$(_inst gnome-text-editor)"       "$gte_state" \
        "vscodium"           "VS Code open-source (external repo)$(_inst codium)"       "$codium_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            vscodium)
                install_vscodium
                ;;
            *)
                if $headless; then
                    echo "Skipping $pkg (headless mode)"
                    continue
                fi
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Programming applications installed.${NC}"
}

install_vscodium() {
    if command -v codium &>/dev/null; then
        echo "VSCodium is already installed."
        return
    fi

    echo "Setting up VSCodium repository..."

    ! is_installed "wget" && _run_install wget
    ! is_installed "gpg" && _run_install gpg

    sudo install -d -m 0755 /usr/share/keyrings

    wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
        | gpg --dearmor \
        | sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg 2>/dev/null

    local use_deb822=false
    [ -f /etc/apt/sources.list.d/debian.sources ] && use_deb822=true

    if $use_deb822; then
        sudo tee /etc/apt/sources.list.d/vscodium.sources > /dev/null << 'EOF'
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64 arm64
Signed-by: /usr/share/keyrings/vscodium-archive-keyring.gpg
EOF
    else
        echo "deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main" \
            | sudo tee /etc/apt/sources.list.d/vscodium.list > /dev/null
    fi

    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    _run_install codium

    echo -e "${GREEN}VSCodium installed.${NC}"
}
