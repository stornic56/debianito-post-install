#!/usr/bin/env bash
# extras.sh — Bullseye: software purgado / solo repos oficiales
# License GPL v3

# ── Essential Pack (Bullseye) ──
_quick_install_bullseye() {
    _msg "Essential Pack" \
        "Install basic programs:\n\n\
  - Compression (zip, unrar, 7z)\n\
  - System tools (htop, inxi, neofetch)\n\
  - Networking (curl, wget, ufw)\n\
  - CA certs & GPG\n\
  - VLC media player" 13 60

    local quick_pkgs=(
        zip unzip rar unrar p7zip-full p7zip-rar
        neofetch htop inxi curl wget ufw
        ca-certificates gnupg lsb-release
    )
    _is_headless || quick_pkgs+=(vlc)
    _run_install_batch "${quick_pkgs[@]}"
    echo -e "${GREEN}Essential Pack installed.${NC}"
}

# ── Firmware (Bullseye) ──
install_firmware_bullseye() {
    echo -e "${YELLOW}Installing firmware-linux-nonfree (Bullseye)...${NC}"

    # ── Safeguard: non-free repos must be enabled ──
    if ! grep -qr "non-free" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
        _msg "Error" "Error: No 'non-free' repositories were detected.\n\
Please first run the 'Configure repositories' option in the\n\
main menu to install proprietary firmwares." 10 65
        return 1
    fi

    if is_installed "firmware-linux-nonfree"; then
        echo "firmware-linux-nonfree already installed."
        return
    fi

    local fw_ver
    fw_ver=$(apt-cache policy firmware-linux-nonfree 2>/dev/null | awk 'NR==3 {print $2; exit}')

    if _confirm "Firmware" \
        "firmware-linux-nonfree proporciona drivers para:\n\
  WiFi, Bluetooth, GPU, audio, webcams, etc.\n\n\
  Version: ${fw_ver:-unknown}\n\n\
Instalar?"; then
        _run_cmd "Firmware" "sudo apt install -y firmware-linux-nonfree" \
            "Installing firmware-linux-nonfree..."
        echo -e "${GREEN}Firmware installed.${NC}"
    fi
    type _handle_wireless &>/dev/null && _handle_wireless
}

# ======================================================================
# EXTRA SOFTWARE CATEGORIES — Bullseye versions (purged/whitelisted)
# Only packages available in Debian 11 official repos.
# ======================================================================

_cat_customization_bullseye() {
    local sub
    sub=$(_menu "Customization (Bullseye)" "Select type:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "1" "Desktop Themes (GTK/KDE)" \
        "2" "Icon Themes" \
        "3" "Cursor Themes" \
        "4" "Fonts" \
        "5" "Terminals" \
        )
    [ -z "$sub" ] && return
    case $sub in
        1)  _cat_themes_bullseye ;;
        2)  _cat_icons_bullseye ;;
        3)  _cat_cursors_bullseye ;;
        4)  _cat_fonts_bullseye ;;
        5)  _cat_terminals ;;
    esac
}

_cat_themes_bullseye() {
    local item_count=6
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Desktop Themes (Bullseye)" "Select desktop themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "arc-theme"             "Arc GTK theme"                     "$(_state arc-theme)" \
        "blackbird-gtk-theme"   "Blackbird GTK theme"     "$(_state blackbird-gtk-theme)" \
        "bluebird-gtk-theme"    "Bluebird GTK theme"       "$(_state bluebird-gtk-theme)" \
        "breeze-gtk-theme"      "Breeze GTK theme (KDE port)" "$(_state breeze-gtk-theme)" \
        "greybird-gtk-theme"    "Greybird GTK theme"       "$(_state greybird-gtk-theme)" \
        "numix-gtk-theme"       "Numix GTK theme"             "$(_state numix-gtk-theme)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Desktop themes installed.${NC}"
}

_cat_icons_bullseye() {
    local items=(
        "breeze-icon-theme"         "Breeze icon theme"               "$(_state breeze-icon-theme)"
        "deepin-icon-theme"         "Deepin icon theme"               "$(_state deepin-icon-theme)"
        "moka-icon-theme"           "Moka icon theme"                   "$(_state moka-icon-theme)"
        "numix-icon-theme"          "Numix icon theme"                 "$(_state numix-icon-theme)"
        "numix-icon-theme-circle"   "Numix Circle icon theme"   "$(_state numix-icon-theme-circle)"
        "obsidian-icon-theme"       "Obsidian icon theme"           "$(_state obsidian-icon-theme)"
        "papirus-icon-theme"        "Papirus icon theme"             "$(_state papirus-icon-theme)"
        "paper-icon-theme"          "Paper icon theme"                 "$(_state paper-icon-theme)"
        "suru-icon-theme"           "Suru icon theme"                   "$(_state suru-icon-theme)"
    )
    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Icon Themes (Bullseye)" "Select icon themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Icon themes installed.${NC}"
}

_cat_cursors_bullseye() {
    local item_count=5
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Cursor Themes (Bullseye)" "Select cursor themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "breeze-cursor-theme"    "Breeze cursors (KDE)"       "$(_state breeze-cursor-theme)" \
        "chameleon-cursor-theme" "Chameleon cursors"       "$(_state chameleon-cursor-theme)" \
        "dmz-cursor-theme"       "DMZ cursors"                   "$(_state dmz-cursor-theme)" \
        "oxygencursors"          "Oxygen cursors (KDE legacy)"       "$(_state oxygencursors)" \
        "xcursor-themes"         "X11 base cursors"                "$(_state xcursor-themes)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Cursor themes installed.${NC}"
}

_cat_fonts_bullseye() {
    local item_count=4
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Fonts (Bullseye)" "Available fonts${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "fonts-firacode"    "Fira Code monospace font"           "$(_state fonts-firacode)" \
        "fonts-noto"        "Noto fonts (Google)"                    "$(_state fonts-noto)" \
        "fonts-dejavu-core" "DejaVu core fonts"               "$(_state fonts-dejavu-core)" \
        "ttf-mscorefonts-installer" "Microsoft Core Fonts" "$(_state ttf-mscorefonts-installer)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Fonts installed.${NC}"
}

_cat_download_bullseye() {
    local choices1 choices2=""

    local item_count1=2
    local lista_alto1=$((item_count1 > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count1))
    choices1=$(_checklist "Downloaders" "Select download tools:" $TUI_ALTO $TUI_ANCHO $lista_alto1 \
        "aria2"      "Multiprotocol downloader (CLI)"    "$(_state aria2)" \
        "filezilla"  "FTP/SFTP client (GUI)"        "$(_state filezilla)" \
        )
    clear

    local item_count2=8
    local lista_alto2=$((item_count2 > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count2))
    choices2=$(_checklist "Torrent Clients" "Select torrent clients${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto2 \
        "deluge"            "BitTorrent client (GTK)"               "$(_state deluge)" \
        "deluged"           "BitTorrent daemon/server"             "$(_state deluged)" \
        "mktorrent"         "Torrent metainfo creator (CLI)"     "$(_state mktorrent)" \
        "qbittorrent"       "BitTorrent client (Qt)"           "$(_state qbittorrent)" \
        "qbittorrent-nox"   "BitTorrent WebUI/CLI"        "$(_state qbittorrent-nox)" \
        "transmission-cli"  "BitTorrent client (CLI)"     "$(_state transmission-cli)" \
        "transmission-gtk"  "BitTorrent client (GTK)"     "$(_state transmission-gtk)" \
        "transmission-qt"   "BitTorrent client (Qt)"       "$(_state transmission-qt)" \
        )
    clear

    local cleaned
    cleaned=$(echo "$choices1 $choices2" | tr -d '"')
    [ -z "$cleaned" ] && { echo "No download tools selected."; return; }

    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Download & network tools installed.${NC}"
}

_cat_internet_bullseye() {
    local item_count=11
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Internet (Bullseye)" "Select browsers, email${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "chromium"            "Chromium web browser"                   "$(_state chromium)" \
        "dillo"               "Lightweight graphical browser"             "$(_state dillo)" \
        "elinks"              "Text-mode web browser"                    "$(_state elinks)" \
        "epiphany-browser"    "GNOME web browser"             "$(_state epiphany-browser)" \
        "falkon"              "KDE web browser (QtWebEngine)"            "$(_state falkon)" \
        "firefox-esr"         "Firefox ESR (official Debian)"      "$(_state firefox-esr)" \
        "konqueror"           "KDE file manager / web browser"       "$(_state konqueror)" \
        "qutebrowser"         "Keyboard-driven browser (Qt)"       "$(_state qutebrowser)" \
        "thunderbird"         "Email client"                        "$(_state thunderbird)" \
        "torbrowser-launcher" "Tor Browser launcher"       "$(_state torbrowser-launcher)" \
        "w3m"                 "Text-mode browser + deps"                   "$(_state w3m)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        case $pkg in
            w3m)
                local need=()
                ! is_installed "w3m" && need+=("w3m")
                ! is_installed "w3m-img" && need+=("w3m-img")
                ! is_installed "ca-certificates" && need+=("ca-certificates")
                ! is_installed "xsel" && need+=("xsel")
                [ ${#need[@]} -gt 0 ] && _run_install_batch "${need[@]}" || echo "Already installed."
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
    echo -e "${GREEN}Internet tools installed.${NC}"
}

_cat_players_bullseye() {
    local item_count=2
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Media Players (Bullseye)" "Select media players${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "mpv"  "Lightweight media player"  "$(_state mpv)" \
        "vlc"  "VLC media player"          "$(_state vlc)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Media players installed.${NC}"
}

_cat_design_bullseye() {
    local item_count=13
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Multimedia & Design (Bullseye)" "Select multimedia and design tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "ardour"      "Digital audio workstation"                  "$(_state ardour)" \
        "audacity"    "Audio editor/recorder"                   "$(_state audacity)" \
        "blender"     "3D modeling/animation suite"              "$(_state blender)" \
        "ffmpeg"      "Multimedia framework (CLI)"                "$(_state ffmpeg)" \
        "gimp"        "Image editor"                                "$(_state gimp)" \
        "handbrake"   "Video transcoder (DVD ripper)"          "$(_state handbrake)" \
        "inkscape"    "Vector graphics editor"                  "$(_state inkscape)" \
        "kdenlive"    "Video editor (KDE)"                      "$(_state kdenlive)" \
        "krita"       "Digital painting/illustration"              "$(_state krita)" \
        "obs-studio"  "Screen recording/streaming"            "$(_state obs-studio)" \
        "openshot-qt" "Video editor (simple)"                "$(_state openshot-qt)" \
        "scribus"     "Desktop publishing (DTP)"                 "$(_state scribus)" \
        "shotcut"     "Video editor (cross-platform)"            "$(_state shotcut)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Multimedia & design tools installed.${NC}"
}

_cat_programming_bullseye() {
    local item_count=9
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Code Editors & IDEs (Bullseye)" "Select editors and IDEs${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "vim"        "Classic terminal editor"          "$(_state vim)" \
        "vim-gtk3"   "Vim with GTK3 GUI"         "$(_state vim-gtk3)" \
        "neovim"     "Modern vim fork"              "$(_state neovim)" \
        "nano"       "Simple terminal editor"         "$(_state nano)" \
        "emacs"      "Extensible editor / IDE"       "$(_state emacs)" \
        "kate"       "KDE advanced text editor"       "$(_state kate)" \
        "mousepad"   "Xfce text editor"           "$(_state mousepad)" \
        "gedit"      "GNOME text editor"             "$(_state gedit)" \
        "geany"      "Lightweight IDE"               "$(_state geany)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Code editors & IDEs installed.${NC}"
}

_cat_dev_bullseye() {
    local item_count=14
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Servers & Dev Tools (Bullseye)" "Select development tools and servers${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "apache2"         "Apache web server"                        "$(_state apache2)" \
        "build-essential" "C/C++ build tools (gcc, make)"   "$(_state build-essential)" \
        "docker"          "Docker container runtime"               "$(_state docker.io)" \
        "mariadb-server"  "MariaDB database server"           "$(_state mariadb-server)" \
        "netcat-openbsd"  "TCP/IP networking utility"         "$(_state netcat-openbsd)" \
        "nginx"           "Nginx web server"                          "$(_state nginx)" \
        "openssh-server"  "SSH server"                       "$(_state openssh-server)" \
        "openssl"         "OpenSSL cryptography toolkit"             "$(_state openssl)" \
        "postgresql"      "PostgreSQL database server"            "$(_state postgresql)" \
        "python3-pip"     "Python 3 pip + venv + dev"            "$(_state python3-pip)" \
        "redis-server"    "Redis key-value store"               "$(_state redis-server)" \
        "sqlite3"         "SQLite database engine"                   "$(_state sqlite3)" \
        "jellyfin"        "Jellyfin Media Server (Web GUI on port 8096)" OFF \
        "openjdk-dev-env" "Adoptium Temurin JDK (17, 21, 25 LTS)$(_any_jdk_installed_desc)" "$(_any_jdk_state)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        case $pkg in
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
            jellyfin)
                install_jellyfin
                ;;
            openjdk-dev-env)
                _install_dev_java
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
    echo -e "${GREEN}Servers & dev tools installed.${NC}"
}
_cat_security_bullseye() {
    local item_count=5
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Security & Networking (Bullseye)" "Select security and networking tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "wireshark"   "Network protocol analyzer (GUI)"       "$(_state wireshark)" \
        "tcpdump"     "Command-line packet analyzer"            "$(_state tcpdump)" \
        "fail2ban"    "Brute-force protection daemon"          "$(_state fail2ban)" \
        "ufw"         "Uncomplicated firewall"                      "$(_state ufw)" \
        "clamav"      "Antivirus engine (ClamAV)"                "$(_state clamav)" \
        )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        case $pkg in
            clamav)
                _install_clamav
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
    echo -e "${GREEN}Security & networking tools installed.${NC}"
}

_cat_general_bullseye() {
    local item_count=22
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "System Tools (Bullseye)" "Select system utilities${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "compress"           "Compression tools (zip, unrar, p7zip)"          "$(_state zip)" \
        "conky"              "System monitor for desktop"                    "$(_state conky)" \
        "cpu-x"              "CPU-X (alternative to CPU-Z)"                  "$(_state cpu-x)" \
        "curl-wget"          "HTTP transfer tools (curl, wget)"               "$(_state curl)" \
        "flatpak"            "Flatpak sandbox (Bullseye native)"           "$(_state flatpak)" \
        "fwupd"              "Firmware update daemon"                        "$(_state fwupd)" \
        "gnome-disk-utility" "Disk management GUI"              "$(_state gnome-disk-utility)" \
        "gparted"            "Partition editor"                             "$(_state gparted)" \
        "htop"               "Interactive process viewer"                      "$(_state htop)" \
        "inxi"               "System information tool"                         "$(_state inxi)" \
        "jq"                 "JSON command-line processor"                     "$(_state jq)" \
        "kvm"                "QEMU/KVM virtualization"                 "$(_state virt-manager)" \
        "lshw"               "List hardware details"                           "$(_state lshw)" \
        "mc"                 "Midnight Commander"                                "$(_state mc)" \
        "nvme-cli"           "NVMe SSD health monitoring"                   "$(_state nvme-cli)" \
        "ncdu"               "Disk usage analyzer"                             "$(_state ncdu)" \
        "psensor"            "Temperature monitor"                          "$(_state psensor)" \
        "timeshift"          "System restore snapshots"                   "$(_state timeshift)" \
        "tmux"               "Terminal multiplexer"                            "$(_state tmux)" \
        "wine"               "Windows compatibility layer"                     "$(_state wine)" \
        "bleachbit"          "System cleaner (GUI)"                           "$(_state bleachbit)" \
        "gdebi"              "Install .deb packages with deps (GUI)"           "$(_state gdebi)" \
        )
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
                [ ${#need[@]} -gt 0 ] && _run_install_batch "${need[@]}"
                ;;
            curl-wget)
                local need=()
                ! is_installed "curl" && need+=("curl")
                ! is_installed "wget" && need+=("wget")
                [ ${#need[@]} -gt 0 ] && _run_install_batch "${need[@]}" || echo "Already installed."
                ;;
            kvm)
                if ! is_installed "virt-manager"; then
                    _run_cmd "KVM" "sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients bridge-utils virt-manager" "Installing KVM..."
                    sudo adduser "$USER" libvirt 2>/dev/null || true
                    sudo adduser "$USER" kvm 2>/dev/null || true
                else
                    echo "QEMU/KVM already installed."
                fi
                ;;
            flatpak)
                if ! is_installed "flatpak"; then
                    _run_cmd "Flatpak" "sudo apt install -y flatpak" "Installing Flatpak..."
                    flatpak remote-add --if-not-exists flathub \
                        https://dl.flathub.org/repo/flathub.flatpakrepo
                    echo -e "${GREEN}Flatpak + Flathub installed.${NC}"
                else
                    echo "Flatpak already installed."
                fi
                ;;
            wine)
                if ! is_installed "wine64"; then
                    _run_cmd "Wine" "sudo apt install -y --no-install-recommends wine64 fonts-wine" "Installing Wine (64-bit only)..."
                    local wine_ver
                    wine_ver=$(wine --version 2>/dev/null)
                    if [ -n "$wine_ver" ]; then
                        echo -e "${GREEN}Wine (64-bit) installed: ${wine_ver}${NC}"
                    else
                        echo -e "${YELLOW}Wine installed but version check failed.${NC}"
                    fi
                else
                    echo "Wine64 already installed."
                fi
                ;;
            fwupd)
                if ! is_installed "fwupd"; then
                    _run_cmd "fwupd" "sudo apt install -y fwupd" "Installing fwupd..."
                fi
                if _confirm "Firmware Scan" "Scan for firmware updates now?"; then
                    sudo fwupdmgr refresh --force 2>/dev/null || true
                    sudo fwupdmgr get-updates 2>&1 || true
                    _pause
                fi
                ;;
            nvme-cli)
                _run_install "nvme-cli"
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
    echo -e "${GREEN}System tools installed.${NC}"
    _pause
}

_cat_fetch_bullseye() {
    local items=(
        "neofetch"    "System info fetcher"        "$(_state neofetch)"
        "screenfetch" "System info (BSD/Linux)" "$(_state screenfetch)"
        "linuxlogo"   "Linux logo + system info" "$(_state linuxlogo)"
    )
    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Fetch Tools (Bullseye)" "Select system info tools:" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" )
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done
    echo -e "${GREEN}Fetch tools installed.${NC}"
}

# ======================================================================
# master installer — replaces install_extras() on Bullseye
# ======================================================================
install_extras_bullseye() {
    echo -e "${YELLOW}Extra software — Bullseye mode (official repos only).${NC}"
    _load_extras

    while true; do
        local cat_choice
    cat_choice=$(_menu "Extra Software — Bullseye" "Select a category${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0"  "Essential Pack" \
            "1"  "Customization System" \
            "2"  "Download & Network" \
            "3"  "Internet (Browsers, Email)" \
            "4"  "Communication" \
            "5"  "Media Players" \
            "6"  "Multimedia & Design" \
            "7"  "Code Editors & IDEs" \
            "8"  "Servers & Dev Tools" \
            "9"  "Security & Networking" \
            "10" "Software Centers" \
            "11" "System Tools" \
            "12" "Fetch / System Info" \
            "13" "Back to main menu" \
            )

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            0)  _quick_install_bullseye ;;
            1)  _cat_customization_bullseye ;;
            2)  _cat_download_bullseye ;;
            3)  _cat_internet_bullseye ;;
            4)  _cat_communication ;;
            5)  _cat_players_bullseye ;;
            6)  _cat_design_bullseye ;;
            7)  _cat_programming_bullseye ;;
            8)  _cat_dev_bullseye ;;
            9)  _cat_security_bullseye ;;
            10) _cat_software_centers_bullseye ;;
            11) _cat_general_bullseye ;;
            12) _cat_fetch_bullseye ;;
            13) return ;;
        esac
        clear
    done
}

_cat_software_centers_bullseye() {
    local sc_choice
    sc_choice=$(_menu "Software Centers" "Choose a software store to install:" 12 65 3 \
        "gnome-software"   "Software Center for GNOME" \
        "plasma-discover"  "Software manager for Plasma" \
        "synaptic"         "Classic APT package manager (GTK)" \
        )
    [ -z "$sc_choice" ] && return

    if [ "$sc_choice" = "synaptic" ]; then
        _run_cmd "Install" "sudo apt install -y synaptic" "Installing synaptic..."
        echo -e "${GREEN}synaptic installed.${NC}"
        return
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
