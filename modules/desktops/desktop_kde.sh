#!/usr/bin/env bash
# desktop_kde.sh — KDE Plasma desktop installer (SP2)
# Full: kde-standard + sddm | Minimal: kde-plasma-desktop + sddm
# Custom: kde-plasma-desktop + sddm + konsole + extras elegidos
# bookworm: Plasma 5.27.5 / KF5 / Qt5; SDDM defaults to
# X11 (plasma.desktop in xsessions); Wayland is optional
# via plasma-workspace-wayland (plasmawayland.desktop).
# trixie: Plasma 6.3.6 / KF6 / Qt6; Wayland is the
# primary session (plasma.desktop in wayland-sessions),
# X11 the alternative (plasmax11.desktop). sddm is only
# Recommends in the meta-kde chain, so the explicit sddm
# in both routes is what guarantees the DM (and
# xserver-xorg/xauth, hard deps of sddm in both releases).
# License GPL v3

# plasma-workspace-wayland exists only on bookworm:
# bookworm's plasma-workspace ships the X11 session only,
# and the Wayland session (plasmawayland.desktop) lives
# in this separate package (a Recommends of plasma-desktop,
# listed explicitly for the same determinism as the
# explicit sddm). trixie integrates Wayland into
# plasma-workspace itself and the package does not exist
# there (packages.debian.org/trixie/plasma-workspace-wayland),
# so naming it off-bookworm would fail the apt transaction.
_kde_wayland_pkg() {
    case "${DEBIAN_CODENAME:-}" in
    bookworm) printf '%s\n' "plasma-workspace-wayland" ;;
    *)        printf '%s\n' "" ;;
    esac
}
kde_menu() {
    while true; do
        local -a kd_items=()
        kd_items+=("1" "KDE Plasma (Full Desktop)")
        kd_items+=("2" "KDE Plasma Desktop (Minimal)")
        kd_items+=("3" "KDE Custom (Choose packages)")
        kd_items+=("4" "Back")
        local choice
        choice=$(_menu "KDE Plasma" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "${kd_items[@]}")
        [ -z "$choice" ] && break
        clear
        case "$choice" in
        1) _install_kde_full ;;
        2) _install_kde_minimal ;;
        3) _install_kde_custom ;;
        4) break ;;
        esac
    done
}

_install_kde_full() {
    # Pre-apply summary: confirm the selection before any
    # debconf or apt transaction starts. The Wayland
    # session package is resolved once (bookworm only;
    # the package does not exist on trixie) so the
    # summary lists exactly what apt will install.
    local wayland_pkg
    wayland_pkg=$(_kde_wayland_pkg)
    local -a pkgs=(kde-standard sddm)
    [ -n "$wayland_pkg" ] && pkgs+=("$wayland_pkg")
    _confirm_install_list "KDE Plasma Full" "${pkgs[@]}" || return

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
    _run_cmd "KDE Full" "sudo apt install -y ${pkgs[*]}" \
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
    # debconf or apt transaction starts. The Wayland
    # session package is resolved once (bookworm only;
    # the package does not exist on trixie) so the
    # summary lists exactly what apt will install.
    local wayland_pkg
    wayland_pkg=$(_kde_wayland_pkg)
    local -a pkgs=(kde-plasma-desktop sddm)
    [ -n "$wayland_pkg" ] && pkgs+=("$wayland_pkg")
    _confirm_install_list "KDE Plasma Minimal" "${pkgs[@]}" || return

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
    _run_cmd "KDE Minimal" "sudo apt install -y ${pkgs[*]}" \
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

_install_kde_custom() {
    # Fixed base (not selectable); extras chosen from the
    # checklist. konsole is pinned because it is only a
    # Recommends of kde-baseapps on trixie. All 17 extra
    # names are identical on bookworm and trixie
    # (packages.debian.org), so no per-release handling is
    # needed beyond the shared Wayland gate. knotes is gone
    # on trixie and konqueror/kwrite are legacy: excluded.
    local cleaned
    cleaned=$(_select_packages_checklist "KDE Custom" \
        "Select the extra KDE packages to install:" \
        "kate|advanced text editor" \
        "ark|archive manager" \
        "gwenview|image viewer" \
        "okular|document viewer" \
        "kcalc|calculator" \
        "kde-spectacle|screenshot capture" \
        "khelpcenter|documentation center" \
        "sweeper|history cleaner" \
        "print-manager|printer management" \
        "kwalletmanager|password manager" \
        "plasma-nm|network applet (needs NetworkManager)" \
        "juk|music player" \
        "dragonplayer|video player" \
        "kmail|email client" \
        "korganizer|calendar and tasks" \
        "kaddressbook|contacts address book" \
        "akregator|RSS feed reader")
    [ -z "$cleaned" ] && return
    # BH-004: reparse the space-separated selection into an array.
    local -a kde_pkgs=()
    local _pkg
    while IFS= read -r _pkg; do
        [ -n "$_pkg" ] && kde_pkgs+=("$_pkg")
    done < <(echo "$cleaned" | tr ' ' '\n')

    # Fixed base: kde-plasma-desktop + sddm + konsole, plus
    # the Wayland session package on bookworm only.
    local wayland_pkg
    wayland_pkg=$(_kde_wayland_pkg)
    local -a base_pkgs=(kde-plasma-desktop sddm konsole)
    [ -n "$wayland_pkg" ] && base_pkgs+=("$wayland_pkg")

    # Pre-apply summary: confirm base + selection before any
    # debconf or apt transaction starts.
    _confirm_install_list "KDE Custom" "${base_pkgs[@]}" "${kde_pkgs[@]}" || return

    echo -e "${GREEN}Installing KDE Plasma (Custom)...${NC}"

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
    _run_cmd "KDE Custom" "sudo apt install -y ${base_pkgs[*]} ${kde_pkgs[*]}" \
        "Installing KDE Plasma (Custom) + SDDM..."
    if [ "$target_dm" = "sddm" ]; then
        sudo systemctl enable sddm
    fi
    # Selection confirmed once above; release the
    # per-package prompt suppression.
    _SELECTION_CONFIRMED=0
    echo -e "${GREEN}KDE Plasma installed. Default display manager: ${target_dm}.${NC}"
    _offer_pipewire_after_desktop
}
