#!/usr/bin/env bash
# programming.sh — Programming Applications (text editors + IDEs)

_cat_programming() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    local vim_state;    vim_state=$(_state "vim")
    local neovim_state; neovim_state=$(_state "neovim")
    local hx_state;     hx_state=$(_state "hx")
    local nano_state;   nano_state=$(_state "nano")
    local emacs_state;  emacs_state=$(_state "emacs")
    items+=(
        "vim"    "Classic terminal editor$(_inst vim)"    "$vim_state"
        "neovim" "Modern vim fork$(_inst neovim)"         "$neovim_state"
        "hx"     "Helix modal editor (Rust)$(_inst hx)"   "$hx_state"
        "nano"   "Simple terminal editor$(_inst nano)"    "$nano_state"
        "emacs"  "Extensible editor / IDE$(_inst emacs)"  "$emacs_state"
    )
    if ! $headless; then
        local vimgtk_state;   vimgtk_state=$(_state "vim-gtk3")
        local kate_state;     kate_state=$(_state "kate")
        local mousepad_state; mousepad_state=$(_state "mousepad")
        local gedit_state;    gedit_state=$(_state "gedit")
        local geany_state;    geany_state=$(_state "geany")
        local gte_state;      gte_state=$(_state "gnome-text-editor")
        local codium_state="OFF"
        if command -v codium &>/dev/null; then
            codium_state="ON"
        fi
        items+=(
            "vim-gtk3"          "Vim with GTK3 GUI$(_inst vim-gtk3)"                    "$vimgtk_state"
            "kate"              "KDE advanced text editor$(_inst kate)"                 "$kate_state"
            "mousepad"          "Xfce text editor$(_inst mousepad)"                     "$mousepad_state"
            "gedit"             "GNOME text editor$(_inst gedit)"                       "$gedit_state"
            "geany"             "Lightweight IDE$(_inst geany)"                         "$geany_state"
            "gnome-text-editor" "GNOME modern text editor$(_inst gnome-text-editor)"    "$gte_state"
            "vscodium"          "VS Code open-source (extrepo)$(_inst codium)"          "$codium_state"
        )
    fi

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(_checklist "Programming Applications" "Select editors and IDEs${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "${items[@]}" \
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            vscodium)
                install_vscodium
                ;;
            *)
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

_enable_vscodium_repo() {
    if [ ! -f /etc/apt/sources.list.d/extrepo_vscodium.sources ]; then
        if ! command -v extrepo &>/dev/null; then
            _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
        fi
        _run_cmd "VSCodium" "sudo extrepo enable vscodium" "Enabling VSCodium repository..."
    fi
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

install_vscodium() {
    if command -v codium &>/dev/null; then
        echo "VSCodium is already installed."
        return
    fi

    _enable_vscodium_repo
    _run_install codium

    echo -e "${GREEN}VSCodium installed.${NC}"
}
