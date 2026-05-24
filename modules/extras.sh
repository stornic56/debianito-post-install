#!/usr/bin/env bash
# extras.sh

_inst() {
    if is_installed "$1"; then echo " (installed)"; else echo ""; fi
}

install_extras() {
    echo -e "${YELLOW}Extra software installation...${NC}"

    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    if _is_headless; then
        _msg "Headless Mode" "No graphical display detected.\n\nOnly terminal-friendly packages will be shown.\nGUI applications (browsers, media players, design tools)\nwill be skipped automatically." 12 60
    fi

    while true; do
        local cat_choice
        cat_choice=$(whiptail --title "Extra Software" --menu \
            "Select a category:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0" "Essential Pack" \
            "1" "System Tools" \
            "2" "Development & Servers" \
            "3" "Media Players" \
            "4" "Web Browsers" \
            "5" "Customization System" \
            "6" "Fetch / System Info" \
            "7" "Download & Network" \
            "8" "Multimedia & Design" \
            "9" "Back to main menu" \
            3>&1 1>&2 2>&3)

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            0) _quick_install ;;
            1) _cat_general ;;
            2) _cat_dev ;;
            3) _cat_players ;;
            4) _cat_browsers ;;
            5) _cat_customization ;;
            6) _cat_fetch ;;
            7) _cat_download ;;
            8) _cat_design ;;
            9) return ;;
        esac
        clear
    done
}

_quick_install() {
    _msg "Essential Pack" \
        "Install basic programs:\n\n  - Compression (zip, unrar, 7z)\n  - System tools (htop, inxi, fastfetch)\n  - VLC media player\n  - Microsoft fonts" 13 60

    local quick_pkgs=(
        zip unzip rar unrar p7zip-full p7zip-rar
        "$fetch_pkg" htop vlc inxi ttf-mscorefonts-installer
    )
    _run_install_batch "${quick_pkgs[@]}"
    echo -e "${GREEN}Essential Pack installed.${NC}"
}

_cat_general() {
    local headless=false
    _is_headless && headless=true
    local alacritty_state="OFF"; is_installed "alacritty" && alacritty_state="ON"
    local btop_state="OFF";  is_installed "btop" && btop_state="ON"
    local compress_state="OFF"; is_installed "zip" && is_installed "unzip" && is_installed "p7zip-full" && compress_state="ON"
    local conky_state="OFF"; is_installed "conky" && conky_state="ON"
    local corectrl_state="OFF"; is_installed "corectrl" && corectrl_state="ON"
    local cpufetch_state="OFF"; is_installed "cpufetch" && cpufetch_state="ON"
    local cpu_x_state="OFF"; is_installed "cpu-x" && cpu_x_state="ON"
    local curl_wget_state="OFF"; is_installed "curl" && is_installed "wget" && curl_wget_state="ON"
    local flatpak_state="OFF"; is_installed "flatpak" && flatpak_state="ON"
    local fonts_state="OFF"; is_installed "fonts-ubuntu" && fonts_state="ON"
    local fwupd_state="OFF"; is_installed "fwupd" && fwupd_state="ON"
    local disks_state="OFF"; is_installed "gnome-disk-utility" && disks_state="ON"
    local gparted_state="OFF"; is_installed "gparted" && gparted_state="ON"
    local hardinfo_state="OFF"; is_installed "hardinfo" && hardinfo_state="ON"
    local htop_state="OFF";  is_installed "htop" && htop_state="ON"
    local inxi_state="OFF";  is_installed "inxi" && inxi_state="ON"
    local kitty_state="OFF"; is_installed "kitty" && kitty_state="ON"
    local kvm_state="OFF";   is_installed "virt-manager" && kvm_state="ON"
    local lshw_state="OFF";  is_installed "lshw" && lshw_state="ON"
    local mc_state="OFF";    is_installed "mc" && mc_state="ON"
    local nala_state="OFF";  is_installed "nala" && nala_state="ON"
    local ncdu_state="OFF";  is_installed "ncdu" && ncdu_state="ON"
    local psensor_state="OFF"; is_installed "psensor" && psensor_state="ON"
    local timeshift_state="OFF"; is_installed "timeshift" && timeshift_state="ON"
    local tmux_state="OFF";  is_installed "tmux" && tmux_state="ON"
    local ttf_state="OFF";   is_installed "ttf-mscorefonts-installer" && ttf_state="ON"

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "System Tools" --checklist \
        "Select system utilities to install (26 items, ↑↓ scroll):" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "alacritty"       "GPU-accelerated terminal$(_inst alacritty)"            "$alacritty_state" \
        "btop"            "Resource monitor (fancy top)$(_inst btop)"             "$btop_state" \
        "compress"        "Compression tools (zip, unrar, 7z)$(_inst zip)"        "$compress_state" \
        "conky"           "System monitor for desktop$(_inst conky)"              "$conky_state" \
        "corectrl"        "AMD GPU control (CoreCtrl)$(_inst corectrl)"           "$corectrl_state" \
        "cpufetch"        "CPU info fetcher$(_inst cpufetch)"                     "$cpufetch_state" \
        "cpu-x"           "CPU-X (alternative to CPU-Z)$(_inst cpu-x)"            "$cpu_x_state" \
        "curl-wget"       "HTTP transfer tools (curl, wget)$(_inst curl)"         "$curl_wget_state" \
        "flatpak"         "Flatpak sandbox + Flathub$(_inst flatpak)"             "$flatpak_state" \
        "fonts-ubuntu"    "Ubuntu font family$(_inst fonts-ubuntu)"               "$fonts_state" \
        "fwupd"           "Firmware update daemon$(_inst fwupd)"                  "$fwupd_state" \
        "gnome-disk-utility" "Disk management GUI$(_inst gnome-disk-utility)"     "$disks_state" \
        "gparted"         "GNOME partition editor$(_inst gparted)"                "$gparted_state" \
        "hardinfo"        "Graphical system profiler$(_inst hardinfo)"            "$hardinfo_state" \
        "htop"            "Interactive process viewer$(_inst htop)"               "$htop_state" \
        "inxi"            "System information tool$(_inst inxi)"                  "$inxi_state" \
        "kitty"           "GPU-based terminal emulator$(_inst kitty)"             "$kitty_state" \
        "kvm"             "QEMU/KVM virtualization$(_inst virt-manager)"          "$kvm_state" \
        "lshw"            "List hardware details$(_inst lshw)"                    "$lshw_state" \
        "mc"              "Midnight Commander (file manager)$(_inst mc)"          "$mc_state" \
        "nala"            "APT frontend (parallel downloads)$(_inst nala)"        "$nala_state" \
        "ncdu"            "Disk usage analyzer (ncurses)$(_inst ncdu)"            "$ncdu_state" \
        "psensor"         "Hardware temperature monitor$(_inst psensor)"          "$psensor_state" \
        "timeshift"       "System restore snapshots$(_inst timeshift)"            "$timeshift_state" \
        "tmux"            "Terminal multiplexer$(_inst tmux)"                     "$tmux_state" \
        "ttf-mscorefonts-installer" "Microsoft fonts (Times, Arial)$(_inst ttf-mscorefonts-installer)" "$ttf_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            compress)
                local need=()
                ! is_installed "zip" && need+=("zip")
                ! is_installed "unzip" && need+=("unzip")
                ! is_installed "rar" && need+=("rar")
                ! is_installed "unrar" && need+=("unrar")
                ! is_installed "p7zip-full" && need+=("p7zip-full")
                ! is_installed "p7zip-rar" && need+=("p7zip-rar")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                    echo -e "${GREEN}Compression utilities installed.${NC}"
                fi
                ;;
            curl-wget)
                local need=()
                ! is_installed "curl" && need+=("curl")
                ! is_installed "wget" && need+=("wget")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                else
                    echo "curl and wget already installed."
                fi
                ;;
            flatpak)
                if ! is_installed "flatpak"; then
                    _run_cmd "Flatpak" "sudo apt install -y flatpak" "Installing Flatpak..."
                    if command -v plasma-discover &>/dev/null; then
                        _run_cmd "Flatpak" "sudo apt install -y plasma-discover-backend-flatpak" "Installing Flatpak backend..."
                        echo "Flatpak backend for Discover installed."
                    elif command -v gnome-software &>/dev/null; then
                        _run_cmd "Flatpak" "sudo apt install -y gnome-software-plugin-flatpak" "Installing Flatpak plugin..."
                        echo "Flatpak plugin for GNOME Software installed."
                    fi
                else
                    echo "Flatpak already installed."
                fi
                flatpak remote-add --if-not-exists flathub \
                    https://dl.flathub.org/repo/flathub.flatpakrepo
                echo "Flathub repository added."
                echo -e "${GREEN}A reboot is recommended.${NC}"
                ;;
            kvm)
                if ! is_installed "virt-manager"; then
                    _run_cmd "KVM" "sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager" "Installing KVM..."
                    sudo adduser "$USER" libvirt 2>/dev/null || true
                    sudo adduser "$USER" kvm 2>/dev/null || true
                    echo -e "${GREEN}QEMU/KVM installed. A reboot is recommended.${NC}"
                else
                    echo "QEMU/KVM already installed."
                fi
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

    echo -e "${GREEN}System tools installed.${NC}"
}

_cat_dev() {
    local headless=false
    _is_headless && headless=true
    local apache_state="OFF"; is_installed "apache2" && apache_state="ON"
    local build_state="OFF";  is_installed "build-essential" && build_state="ON"
    local certbot_state="OFF"; is_installed "certbot" && certbot_state="ON"
    local docker_state="OFF"; is_installed "docker.io" && docker_state="ON"
    local extrepo_state="OFF"; is_installed "extrepo" && extrepo_state="ON"
    local fail2ban_state="OFF"; is_installed "fail2ban" && fail2ban_state="ON"
    local mariadb_state="OFF"; is_installed "mariadb-server" && mariadb_state="ON"
    local netcat_state="OFF"; is_installed "netcat-openbsd" && netcat_state="ON"
    local nginx_state="OFF";  is_installed "nginx" && nginx_state="ON"
    local ssh_state="OFF";     is_installed "openssh-server" && ssh_state="ON"
    local openssl_state="OFF"; is_installed "openssl" && openssl_state="ON"
    local pg_state="OFF";     is_installed "postgresql" && pg_state="ON"
    local pip_state="OFF";    is_installed "python3-pip" && pip_state="ON"
    local redis_state="OFF";  is_installed "redis-server" && redis_state="ON"
    local props_state="OFF";  is_installed "software-properties-common" && props_state="ON"
    local sqlite_state="OFF"; is_installed "sqlite3" && sqlite_state="ON"
    local ufw_state="OFF";     is_installed "ufw" && ufw_state="ON"
    local zenmap_state="OFF"; is_installed "zenmap" && zenmap_state="ON"

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    choices=$(whiptail --title "Development & Servers" --checklist \
        "Select development tools and servers (18 items, ↑↓ scroll):" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "apache2"                   "Apache web server$(_inst apache2)"                            "$apache_state" \
        "build-essential"           "C/C++ build tools (gcc, make)$(_inst build-essential)"        "$build_state" \
        "certbot"                   "Let's Encrypt TLS certificates$(_inst certbot)"               "$certbot_state" \
        "docker"                    "Docker + docker-compose$(_inst docker.io)"                    "$docker_state" \
        "extrepo"                   "External repository manager$(_inst extrepo)"                  "$extrepo_state" \
        "fail2ban"                  "Brute-force protection$(_inst fail2ban)"                      "$fail2ban_state" \
        "mariadb-server"            "MariaDB database server$(_inst mariadb-server)"               "$mariadb_state" \
        "netcat-openbsd"            "TCP/IP networking utility$(_inst netcat-openbsd)"             "$netcat_state" \
        "nginx"                     "Nginx web server$(_inst nginx)"                               "$nginx_state" \
        "openssh-server"            "SSH server$(_inst openssh-server)"                            "$ssh_state" \
        "openssl"                   "OpenSSL cryptography toolkit$(_inst openssl)"                 "$openssl_state" \
        "postgresql"                "PostgreSQL database server$(_inst postgresql)"                 "$pg_state" \
        "python3-pip"               "Python 3 pip + venv + dev$(_inst python3-pip)"                "$pip_state" \
        "redis-server"              "Redis key-value store$(_inst redis-server)"                   "$redis_state" \
        "software-properties-common" "Repository management (PPA)$(_inst software-properties-common)" "$props_state" \
        "sqlite3"                   "SQLite database engine$(_inst sqlite3)"                       "$sqlite_state" \
        "ufw"                       "Uncomplicated firewall$(_inst ufw)"                           "$ufw_state" \
        "zenmap"                    "Network scanner GUI (Nmap frontend)$(_inst zenmap)"            "$zenmap_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            python3-pip)
                local need=()
                ! is_installed "python3-pip" && need+=("python3-pip")
                ! is_installed "python3-venv" && need+=("python3-venv")
                ! is_installed "python3-dev" && need+=("python3-dev")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                else
                    echo "Python 3 tools already installed."
                fi
                ;;
            docker)
                local need=()
                ! is_installed "docker.io" && need+=("docker.io")
                ! is_installed "docker-compose" && need+=("docker-compose")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                else
                    echo "Docker already installed."
                fi
                ;;
            zenmap)
                install_backports_or_stable zenmap
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

    echo -e "${GREEN}Development tools and servers installed.${NC}"
}

_cat_players() {
    local headless=false
    _is_headless && headless=true
    local handbrake_state="OFF"; is_installed "handbrake" && handbrake_state="ON"
    local mpv_state="OFF";       is_installed "mpv" && mpv_state="ON"
    local vlc_state="OFF";       is_installed "vlc" && vlc_state="ON"

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Media Players" --checklist \
        "Select media players:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "handbrake"  "Video transcoder (DVD ripper)$(_inst handbrake)"    "$handbrake_state" \
        "mpv"        "Lightweight media player$(_inst mpv)"               "$mpv_state" \
        "vlc"        "VLC media player$(_inst vlc)"                       "$vlc_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Media players installed.${NC}"
}

_cat_browsers() {
    local headless=false
    _is_headless && headless=true
    local chromium_state="OFF";     is_installed "chromium" && chromium_state="ON"
    local dillo_state="OFF";        is_installed "dillo" && dillo_state="ON"
    local elinks_state="OFF";       is_installed "elinks" && elinks_state="ON"
    local epiphany_state="OFF";     is_installed "epiphany-browser" && epiphany_state="ON"
    local falkon_state="OFF";       is_installed "falkon" && falkon_state="ON"
    local firefox_state="OFF"
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        firefox_state="ON"
    fi
    local floorp_state="OFF";       is_installed "floorp" && floorp_state="ON"
    local konqueror_state="OFF";    is_installed "konqueror" && konqueror_state="ON"
    local librewolf_state="OFF";    is_installed "librewolf" && librewolf_state="ON"
    local privacybrowser_state="OFF"; is_installed "privacybrowser" && privacybrowser_state="ON"
    local qutebrowser_state="OFF";  is_installed "qutebrowser" && qutebrowser_state="ON"
    local thunderbird_state="OFF";  is_installed "thunderbird" && thunderbird_state="ON"
    local torbrowser_state="OFF";   is_installed "torbrowser-launcher" && torbrowser_state="ON"
    local w3m_state="OFF";          is_installed "w3m" && w3m_state="ON"

    local choices
    choices=$(whiptail --title "Web Browsers" --checklist \
        "Select web browsers:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "chromium"          "Chromium web browser$(_inst chromium)"                  "$chromium_state" \
        "dillo"             "Lightweight graphical browser$(_inst dillo)"            "$dillo_state" \
        "elinks"            "Text-mode web browser$(_inst elinks)"                   "$elinks_state" \
        "epiphany-browser"  "GNOME web browser$(_inst epiphany-browser)"             "$epiphany_state" \
        "falkon"            "KDE web browser (QtWebEngine)$(_inst falkon)"           "$falkon_state" \
        "firefox"           "Firefox from Mozilla (replaces ESR)"                    "$firefox_state" \
        "floorp"            "Firefox-based browser (external repo)"                  "$floorp_state" \
        "konqueror"         "KDE file manager / web browser$(_inst konqueror)"       "$konqueror_state" \
        "librewolf"         "Privacy-focused Firefox fork$(_inst librewolf)"         "$librewolf_state" \
        "privacybrowser"    "Privacy-focused web browser$(_inst privacybrowser)"     "$privacybrowser_state" \
        "qutebrowser"       "Keyboard-driven browser (Qt)$(_inst qutebrowser)"       "$qutebrowser_state" \
        "thunderbird"       "Email client$(_inst thunderbird)"                       "$thunderbird_state" \
        "torbrowser-launcher" "Tor Browser launcher$(_inst torbrowser-launcher)"     "$torbrowser_state" \
        "w3m"               "Text-mode browser + deps (w3m-img)$(_inst w3m)"         "$w3m_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            firefox)
                install_firefox_mozilla
                ;;
            floorp)
                if ! is_installed "floorp"; then
                    echo "Setting up Floorp repository..."
                    ! is_installed "curl" && _run_install curl
                    ! is_installed "gpg" && _run_install gpg
                    sudo install -d -m 0755 /etc/apt/keyrings
                    curl -fsSL https://ppa.floorp.app/KEY.gpg | \
                        sudo gpg --dearmor -o /usr/share/keyrings/Floorp.gpg
                    sudo curl -sS --compressed -o /etc/apt/sources.list.d/Floorp.list \
                        'https://ppa.floorp.app/Floorp.list'
                    sudo tee /etc/apt/preferences.d/floorp > /dev/null << EOF
Package: *
Pin: origin ppa.floorp.app
Pin-Priority: 1000
EOF
                    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
                    _run_install floorp
                    echo -e "${GREEN}Floorp installed.${NC}"
                else
                    echo "Floorp already installed."
                fi
                ;;
            librewolf)
                if ! is_installed "librewolf"; then
                    echo "Installing LibreWolf..."
                    _run_install extrepo
                    sudo extrepo enable librewolf 2>/dev/null || true
                    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
                    _run_install librewolf
                    echo -e "${GREEN}LibreWolf installed.${NC}"
                else
                    echo "LibreWolf already installed."
                fi
                ;;
            w3m)
                local need=()
                ! is_installed "w3m" && need+=("w3m")
                ! is_installed "w3m-img" && need+=("w3m-img")
                ! is_installed "ca-certificates" && need+=("ca-certificates")
                ! is_installed "xsel" && need+=("xsel")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch w3m w3m-img ca-certificates xsel
                else
                    echo "w3m already installed."
                fi
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

    echo -e "${GREEN}Web browsers installed.${NC}"
}

_cat_customization() {
    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local sub
    sub=$(whiptail --title "Customization System" --menu \
        "Select type:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "1" "GTK Themes" \
        "2" "Icon Themes" \
        3>&1 1>&2 2>&3)
    [ -z "$sub" ] && return
    case $sub in
        1) _cat_themes ;;
        2) _cat_icons ;;
    esac
}

_cat_themes() {
    local headless=false
    _is_headless && headless=true
    local arc_state="OFF";         is_installed "arc-theme" && arc_state="ON"
    local blackbird_state="OFF";   is_installed "blackbird-gtk-theme" && blackbird_state="ON"
    local bluebird_state="OFF";    is_installed "bluebird-gtk-theme" && bluebird_state="ON"
    local breeze_gtk_state="OFF";  is_installed "breeze-gtk-theme" && breeze_gtk_state="ON"
    local greybird_state="OFF";    is_installed "greybird-gtk-theme" && greybird_state="ON"
    local numix_gtk_state="OFF";   is_installed "numix-gtk-theme" && numix_gtk_state="ON"
    local orchis_state="OFF";      is_installed "orchis-gtk-theme" && orchis_state="ON"

    local choices
    choices=$(whiptail --title "GTK Themes" --checklist \
        "Select GTK themes to install:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "arc-theme"          "Arc GTK theme$(_inst arc-theme)"                 "$arc_state" \
        "blackbird-gtk-theme" "Blackbird GTK theme$(_inst blackbird-gtk-theme)" "$blackbird_state" \
        "bluebird-gtk-theme"  "Bluebird GTK theme$(_inst bluebird-gtk-theme)"   "$bluebird_state" \
        "breeze-gtk-theme"   "Breeze GTK theme$(_inst breeze-gtk-theme)"       "$breeze_gtk_state" \
        "greybird-gtk-theme"  "Greybird GTK theme$(_inst greybird-gtk-theme)"   "$greybird_state" \
        "numix-gtk-theme"    "Numix GTK theme$(_inst numix-gtk-theme)"         "$numix_gtk_state" \
        "orchis-gtk-theme"   "Orchis GTK theme$(_inst orchis-gtk-theme)"       "$orchis_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}GTK themes installed.${NC}"
}

_cat_icons() {
    local headless=false
    _is_headless && headless=true
    local breeze_state="OFF";  is_installed "breeze-icon-theme" && breeze_state="ON"
    local deepin_state="OFF";  is_installed "deepin-icon-theme" && deepin_state="ON"
    local ele_state="OFF";     is_installed "elementary-icon-theme" && ele_state="ON"
    local ele_xfce_state="OFF"; is_installed "elementary-xfce-icon-theme" && ele_xfce_state="ON"
    local moka_state="OFF";    is_installed "moka-icon-theme" && moka_state="ON"
    local numix_state="OFF";   is_installed "numix-icon-theme" && numix_state="ON"
    local numix_c_state="OFF"; is_installed "numix-icon-theme-circle" && numix_c_state="ON"
    local obsidian_state="OFF"; is_installed "obsidian-icon-theme" && obsidian_state="ON"
    local papirus_state="OFF"; is_installed "papirus-icon-theme" && papirus_state="ON"
    local paper_state="OFF";   is_installed "paper-icon-theme" && paper_state="ON"
    local suru_state="OFF";    is_installed "suru-icon-theme" && suru_state="ON"

    local kf6_state="OFF"
    local has_kf6=false
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        is_installed "kf6-breeze-icon-theme" && kf6_state="ON"
        has_kf6=true
    fi

    local items=(
        "breeze-icon-theme"     "Breeze icon theme$(_inst breeze-icon-theme)"           "$breeze_state"
        "deepin-icon-theme"     "Deepin icon theme$(_inst deepin-icon-theme)"           "$deepin_state"
        "elementary-icon-theme" "Elementary icon theme$(_inst elementary-icon-theme)"   "$ele_state"
        "elementary-xfce-icon-theme" "Elementary Xfce icons$(_inst elementary-xfce-icon-theme)" "$ele_xfce_state"
        "moka-icon-theme"       "Moka icon theme$(_inst moka-icon-theme)"               "$moka_state"
        "numix-icon-theme"      "Numix icon theme$(_inst numix-icon-theme)"             "$numix_state"
        "numix-icon-theme-circle" "Numix Circle icon theme$(_inst numix-icon-theme-circle)" "$numix_c_state"
        "obsidian-icon-theme"   "Obsidian icon theme$(_inst obsidian-icon-theme)"       "$obsidian_state"
        "papirus-icon-theme"    "Papirus icon theme$(_inst papirus-icon-theme)"         "$papirus_state"
        "paper-icon-theme"      "Paper icon theme$(_inst paper-icon-theme)"             "$paper_state"
        "suru-icon-theme"       "Suru icon theme$(_inst suru-icon-theme)"               "$suru_state"
    )
    if $has_kf6; then
        items+=("kf6-breeze-icon-theme" "KF6 Breeze icon theme$(_inst kf6-breeze-icon-theme)" "$kf6_state")
    fi

    local choices
    choices=$(whiptail --title "Icon Themes" --checklist \
        "Select icon themes to install:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "${items[@]}" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Icon themes installed.${NC}"
}

_cat_fetch() {
    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    local fetch_state="OFF";  is_installed "$fetch_pkg" && fetch_state="ON"
    local linuxlogo_state="OFF"; is_installed "linuxlogo" && linuxlogo_state="ON"
    local screenfetch_state="OFF"; is_installed "screenfetch" && screenfetch_state="ON"

    local hyfetch_state="OFF"
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        is_installed "hyfetch" && hyfetch_state="ON"
    fi

    local items=()

    if [ "$fetch_pkg" = "fastfetch" ]; then
        items+=("fastfetch" "System info fetcher$(_inst fastfetch)" "$fetch_state")
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            items+=("hyfetch" "Neofetch with pride flags$(_inst hyfetch)" "$hyfetch_state")
        fi
    fi
    items+=("linuxlogo" "Linux logo + system info$(_inst linuxlogo)" "$linuxlogo_state")
    if [ "$fetch_pkg" = "neofetch" ]; then
        items+=("neofetch" "System info fetcher$(_inst neofetch)" "$fetch_state")
        if [ "$DEBIAN_CODENAME" = "trixie" ]; then
            items+=("hyfetch" "Neofetch with pride flags$(_inst hyfetch)" "$hyfetch_state")
        fi
    fi
    items+=("screenfetch" "System info (BSD/Linux)$(_inst screenfetch)" "$screenfetch_state")

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Fetch Tools" --checklist \
        "Select system info tools:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "${items[@]}" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            neofetch|fastfetch)
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
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

    echo -e "${GREEN}Fetch tools installed.${NC}"
}

_cat_download() {
    local headless=false
    _is_headless && headless=true
    local aria2_state="OFF";       is_installed "aria2" && aria2_state="ON"
    local filezilla_state="OFF";   is_installed "filezilla" && filezilla_state="ON"
    local riseupvpn_state="OFF";   is_installed "riseup-vpn" && riseupvpn_state="ON"
    local ytdlp_state="OFF";       is_installed "yt-dlp" && ytdlp_state="ON"
    local ytdlp_gui_state="OFF";   is_installed "youtubedl-gui" && ytdlp_gui_state="ON"

    local deluge_state="OFF";      is_installed "deluge" && deluge_state="ON"
    local deluged_state="OFF";     is_installed "deluged" && deluged_state="ON"
    local mktorrent_state="OFF";   is_installed "mktorrent" && mktorrent_state="ON"
    local qbit_state="OFF";        is_installed "qbittorrent" && qbit_state="ON"
    local qbitnox_state="OFF";     is_installed "qbittorrent-nox" && qbitnox_state="ON"
    local tr_cli_state="OFF";      is_installed "transmission-cli" && tr_cli_state="ON"
    local tr_gtk_state="OFF";      is_installed "transmission-gtk" && tr_gtk_state="ON"
    local tr_qt_state="OFF";       is_installed "transmission-qt" && tr_qt_state="ON"

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices1 choices2=""

    choices1=$(whiptail --title "Download & Network — Downloaders" --checklist \
        "Select download tools:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "aria2"             "Multiprotocol downloader (CLI)$(_inst aria2)"               "$aria2_state" \
        "filezilla"         "FTP/SFTP client (GUI)$(_inst filezilla)"                    "$filezilla_state" \
        "riseup-vpn"        "Riseup VPN client$(_inst riseup-vpn)"                        "$riseupvpn_state" \
        "yt-dlp"            "Video downloader CLI$(_inst yt-dlp)"                         "$ytdlp_state" \
        "youtubedl-gui"     "GUI for yt-dlp$(_inst youtubedl-gui)"                       "$ytdlp_gui_state" \
        3>&1 1>&2 2>&3)
    clear

    choices2=$(whiptail --title "Download & Network — Torrent Clients" --checklist \
        "Select torrent clients:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "deluge"            "BitTorrent client (GTK)$(_inst deluge)"                      "$deluge_state" \
        "deluged"           "BitTorrent daemon/server$(_inst deluged)"                    "$deluged_state" \
        "mktorrent"         "Torrent metainfo creator (CLI)$(_inst mktorrent)"            "$mktorrent_state" \
        "qbittorrent"       "BitTorrent client (Qt)$(_inst qbittorrent)"                  "$qbit_state" \
        "qbittorrent-nox"   "BitTorrent WebUI/CLI$(_inst qbittorrent-nox)"               "$qbitnox_state" \
        "transmission-cli"  "BitTorrent client (CLI)$(_inst transmission-cli)"            "$tr_cli_state" \
        "transmission-gtk"  "BitTorrent client (GTK)$(_inst transmission-gtk)"            "$tr_gtk_state" \
        "transmission-qt"   "BitTorrent client (Qt)$(_inst transmission-qt)"              "$tr_qt_state" \
        3>&1 1>&2 2>&3)
    clear

    local cleaned
    cleaned=$(echo "$choices1 $choices2" | tr -d '"')

    [ -z "$cleaned" ] && { echo "No download tools selected."; return; }

    for pkg in $cleaned; do
        case $pkg in
            riseup-vpn)
                install_backports_or_stable riseup-vpn
                ;;
            yt-dlp)
                install_backports_or_stable yt-dlp
                ;;
            qbittorrent)
                install_backports_or_stable qbittorrent
                ;;
            qbittorrent-nox)
                install_backports_or_stable qbittorrent-nox
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

    echo -e "${GREEN}Download & network tools installed.${NC}"
}

_cat_design() {
    local headless=false
    _is_headless && headless=true
    local audacity_state="OFF";  is_installed "audacity" && audacity_state="ON"
    local ardour_state="OFF";    is_installed "ardour" && ardour_state="ON"
    local blender_state="OFF";   is_installed "blender" && blender_state="ON"
    local ffmpeg_state="OFF";    is_installed "ffmpeg" && ffmpeg_state="ON"
    local gimp_state="OFF";      is_installed "gimp" && gimp_state="ON"
    local inkscape_state="OFF";  is_installed "inkscape" && inkscape_state="ON"
    local kdenlive_state="OFF";  is_installed "kdenlive" && kdenlive_state="ON"
    local krita_state="OFF";     is_installed "krita" && krita_state="ON"
    local obs_state="OFF";       is_installed "obs-studio" && obs_state="ON"
    local openshot_state="OFF";  is_installed "openshot-qt" && openshot_state="ON"
    local scribus_state="OFF";   is_installed "scribus" && scribus_state="ON"
    local shotcut_state="OFF";   is_installed "shotcut" && shotcut_state="ON"

    local choices
    choices=$(whiptail --title "Multimedia & Design" --checklist \
        "Select multimedia and design tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "audacity"   "Audio editor/recorder$(_inst audacity)"         "$audacity_state" \
        "ardour"     "Digital audio workstation$(_inst ardour)"       "$ardour_state" \
        "blender"    "3D modeling/animation suite$(_inst blender)"    "$blender_state" \
        "ffmpeg"     "Multimedia framework (CLI)$(_inst ffmpeg)"      "$ffmpeg_state" \
        "gimp"       "Image editor (Photoshop alternative)$(_inst gimp)" "$gimp_state" \
        "inkscape"   "Vector graphics editor$(_inst inkscape)"        "$inkscape_state" \
        "kdenlive"   "Video editor (KDE)$(_inst kdenlive)"            "$kdenlive_state" \
        "krita"      "Digital painting/illustration$(_inst krita)"    "$krita_state" \
        "obs-studio" "Screen recording/streaming$(_inst obs-studio)"  "$obs_state" \
        "openshot-qt" "Video editor (simple)$(_inst openshot-qt)"     "$openshot_state" \
        "scribus"    "Desktop publishing (DTP)$(_inst scribus)"       "$scribus_state" \
        "shotcut"    "Video editor (cross-platform)$(_inst shotcut)"  "$shotcut_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Multimedia & design tools installed.${NC}"
}

install_firefox_mozilla() {
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        echo "Firefox (Mozilla) is already installed."
        return
    fi

    echo "Setting up Mozilla APT repository for Firefox..."

    if is_installed "firefox-esr"; then
        if _confirm "Firefox ESR" "Firefox ESR is installed.\nRemove it before installing Mozilla Firefox?"; then
            echo "Removing Firefox ESR..."
            sudo apt remove -y firefox-esr
        else
            echo "Keeping Firefox ESR."
        fi
    fi

    ! is_installed "wget" && _run_install wget
    ! is_installed "gpg" && _run_install gpg

    sudo install -d -m 0755 /etc/apt/keyrings

    wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
        sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null

    local fp
    fp=$(gpg -n -q --import --import-options import-show \
        /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | \
        awk '/pub/{getline; gsub(/^ +| +$/,""); print}')
    if [ "$fp" != "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" ]; then
        echo -e "${YELLOW}Warning: Mozilla key fingerprint does not match expected value.${NC}"
    fi

    local use_deb822=false
    [ -f /etc/apt/sources.list.d/debian.sources ] && use_deb822=true

    if $use_deb822; then
        sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null << EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
    else
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | \
            sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    fi

    sudo tee /etc/apt/preferences.d/mozilla > /dev/null << EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
    _run_install firefox

    echo -e "${GREEN}Firefox (Mozilla) installed.${NC}"
}
