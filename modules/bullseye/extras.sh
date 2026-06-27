#!/usr/bin/env bash
# extras.sh — Bullseye: software purgado / solo repos oficiales
# License GPL v3

# ── Essential Pack (Bullseye) ──
_quick_install_bullseye() {
    _msg "Essential Pack — Bullseye" \
        "Install basic programs:\n\n\
  - Compression (zip, unrar, p7zip-full)\n\
  - System tools (htop, inxi, neofetch, bpytop)\n\
  - VLC media player\n\
  - Microsoft fonts" 13 60

    local quick_pkgs=(
        zip unzip rar unrar p7zip-full p7zip-rar
        neofetch bpytop htop inxi vlc
        ttf-mscorefonts-installer
    )
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
    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local sub
    sub=$(whiptail --title "Customization (Bullseye)" --menu \
        "Select type:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "1" "Desktop Themes (GTK/KDE)" \
        "2" "Icon Themes" \
        "3" "Cursor Themes" \
        "4" "Fonts" \
        3>&1 1>&2 2>&3)
    [ -z "$sub" ] && return
    case $sub in
        1)  _cat_themes_bullseye ;;
        2)  _cat_icons_bullseye ;;
        3)  _cat_cursors_bullseye ;;
        4)  _cat_fonts_bullseye ;;
    esac
}

_cat_themes_bullseye() {
    local choices
    choices=$(whiptail --title "Desktop Themes (Bullseye)" --checklist \
        "Select desktop themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "arc-theme"             "Arc GTK theme$(_inst arc-theme)"                     "$(_state arc-theme)" \
        "blackbird-gtk-theme"   "Blackbird GTK theme$(_inst blackbird-gtk-theme)"     "$(_state blackbird-gtk-theme)" \
        "bluebird-gtk-theme"    "Bluebird GTK theme$(_inst bluebird-gtk-theme)"       "$(_state bluebird-gtk-theme)" \
        "breeze-gtk-theme"      "Breeze GTK theme (KDE port)$(_inst breeze-gtk-theme)" "$(_state breeze-gtk-theme)" \
        "greybird-gtk-theme"    "Greybird GTK theme$(_inst greybird-gtk-theme)"       "$(_state greybird-gtk-theme)" \
        "numix-gtk-theme"       "Numix GTK theme$(_inst numix-gtk-theme)"             "$(_state numix-gtk-theme)" \
        3>&1 1>&2 2>&3)
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
        "breeze-icon-theme"         "Breeze icon theme$(_inst breeze-icon-theme)"               "$(_state breeze-icon-theme)"
        "deepin-icon-theme"         "Deepin icon theme$(_inst deepin-icon-theme)"               "$(_state deepin-icon-theme)"
        "moka-icon-theme"           "Moka icon theme$(_inst moka-icon-theme)"                   "$(_state moka-icon-theme)"
        "numix-icon-theme"          "Numix icon theme$(_inst numix-icon-theme)"                 "$(_state numix-icon-theme)"
        "numix-icon-theme-circle"   "Numix Circle icon theme$(_inst numix-icon-theme-circle)"   "$(_state numix-icon-theme-circle)"
        "obsidian-icon-theme"       "Obsidian icon theme$(_inst obsidian-icon-theme)"           "$(_state obsidian-icon-theme)"
        "papirus-icon-theme"        "Papirus icon theme$(_inst papirus-icon-theme)"             "$(_state papirus-icon-theme)"
        "paper-icon-theme"          "Paper icon theme$(_inst paper-icon-theme)"                 "$(_state paper-icon-theme)"
        "suru-icon-theme"           "Suru icon theme$(_inst suru-icon-theme)"                   "$(_state suru-icon-theme)"
    )
    local choices
    choices=$(whiptail --title "Icon Themes (Bullseye)" --checklist \
        "Select icon themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "${items[@]}" 3>&1 1>&2 2>&3)
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Icon themes installed.${NC}"
}

_cat_cursors_bullseye() {
    local choices
    choices=$(whiptail --title "Cursor Themes (Bullseye)" --checklist \
        "Select cursor themes${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "breeze-cursor-theme"    "Breeze cursors (KDE)$(_inst breeze-cursor-theme)"       "$(_state breeze-cursor-theme)" \
        "chameleon-cursor-theme" "Chameleon cursors$(_inst chameleon-cursor-theme)"       "$(_state chameleon-cursor-theme)" \
        "dmz-cursor-theme"       "DMZ cursors$(_inst dmz-cursor-theme)"                   "$(_state dmz-cursor-theme)" \
        "oxygencursors"          "Oxygen cursors (KDE legacy)$(_inst oxygencursors)"       "$(_state oxygencursors)" \
        "xcursor-themes"         "X11 base cursors$(_inst xcursor-themes)"                "$(_state xcursor-themes)" \
        3>&1 1>&2 2>&3)
    clear
    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        ! is_installed "$pkg" && _run_install "$pkg" || echo "$pkg already installed."
    done
    echo -e "${GREEN}Cursor themes installed.${NC}"
}

_cat_fonts_bullseye() {
    local choices
    choices=$(whiptail --title "Fonts (Bullseye)" --checklist \
        "Available fonts${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "fonts-firacode"    "Fira Code monospace font$(_inst fonts-firacode)"           "$(_state fonts-firacode)" \
        "fonts-noto"        "Noto fonts (Google)$(_inst fonts-noto)"                    "$(_state fonts-noto)" \
        "fonts-dejavu-core" "DejaVu core fonts$(_inst fonts-dejavu-core)"               "$(_state fonts-dejavu-core)" \
        "ttf-mscorefonts-installer" "Microsoft Core Fonts$(_inst ttf-mscorefonts-installer)" "$(_state ttf-mscorefonts-installer)" \
        3>&1 1>&2 2>&3)
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

    choices1=$(whiptail --title "Downloaders" --checklist \
        "Select download tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "aria2"      "Multiprotocol downloader (CLI)$(_inst aria2)"    "$(_state aria2)" \
        "filezilla"  "FTP/SFTP client (GUI)$(_inst filezilla)"        "$(_state filezilla)" \
        3>&1 1>&2 2>&3)
    clear

    choices2=$(whiptail --title "Torrent Clients" --checklist \
        "Select torrent clients${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "deluge"            "BitTorrent client (GTK)$(_inst deluge)"               "$(_state deluge)" \
        "deluged"           "BitTorrent daemon/server$(_inst deluged)"             "$(_state deluged)" \
        "mktorrent"         "Torrent metainfo creator (CLI)$(_inst mktorrent)"     "$(_state mktorrent)" \
        "qbittorrent"       "BitTorrent client (Qt)$(_inst qbittorrent)"           "$(_state qbittorrent)" \
        "qbittorrent-nox"   "BitTorrent WebUI/CLI$(_inst qbittorrent-nox)"        "$(_state qbittorrent-nox)" \
        "transmission-cli"  "BitTorrent client (CLI)$(_inst transmission-cli)"     "$(_state transmission-cli)" \
        "transmission-gtk"  "BitTorrent client (GTK)$(_inst transmission-gtk)"     "$(_state transmission-gtk)" \
        "transmission-qt"   "BitTorrent client (Qt)$(_inst transmission-qt)"       "$(_state transmission-qt)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Internet (Bullseye)" --checklist \
        "Select browsers, email${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "chromium"            "Chromium web browser$(_inst chromium)"                   "$(_state chromium)" \
        "dillo"               "Lightweight graphical browser$(_inst dillo)"             "$(_state dillo)" \
        "elinks"              "Text-mode web browser$(_inst elinks)"                    "$(_state elinks)" \
        "epiphany-browser"    "GNOME web browser$(_inst epiphany-browser)"             "$(_state epiphany-browser)" \
        "falkon"              "KDE web browser (QtWebEngine)$(_inst falkon)"            "$(_state falkon)" \
        "firefox-esr"         "Firefox ESR (official Debian)$(_inst firefox-esr)"      "$(_state firefox-esr)" \
        "konqueror"           "KDE file manager / web browser$(_inst konqueror)"       "$(_state konqueror)" \
        "qutebrowser"         "Keyboard-driven browser (Qt)$(_inst qutebrowser)"       "$(_state qutebrowser)" \
        "thunderbird"         "Email client$(_inst thunderbird)"                        "$(_state thunderbird)" \
        "torbrowser-launcher" "Tor Browser launcher$(_inst torbrowser-launcher)"       "$(_state torbrowser-launcher)" \
        "w3m"                 "Text-mode browser + deps$(_inst w3m)"                   "$(_state w3m)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Media Players (Bullseye)" --checklist \
        "Select media players${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "mpv"  "Lightweight media player$(_inst mpv)"  "$(_state mpv)" \
        "vlc"  "VLC media player$(_inst vlc)"          "$(_state vlc)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Multimedia & Design (Bullseye)" --checklist \
        "Select multimedia and design tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "ardour"      "Digital audio workstation$(_inst ardour)"                  "$(_state ardour)" \
        "audacity"    "Audio editor/recorder$(_inst audacity)"                   "$(_state audacity)" \
        "blender"     "3D modeling/animation suite$(_inst blender)"              "$(_state blender)" \
        "ffmpeg"      "Multimedia framework (CLI)$(_inst ffmpeg)"                "$(_state ffmpeg)" \
        "gimp"        "Image editor$(_inst gimp)"                                "$(_state gimp)" \
        "handbrake"   "Video transcoder (DVD ripper)$(_inst handbrake)"          "$(_state handbrake)" \
        "inkscape"    "Vector graphics editor$(_inst inkscape)"                  "$(_state inkscape)" \
        "kdenlive"    "Video editor (KDE)$(_inst kdenlive)"                      "$(_state kdenlive)" \
        "krita"       "Digital painting/illustration$(_inst krita)"              "$(_state krita)" \
        "obs-studio"  "Screen recording/streaming$(_inst obs-studio)"            "$(_state obs-studio)" \
        "openshot-qt" "Video editor (simple)$(_inst openshot-qt)"                "$(_state openshot-qt)" \
        "scribus"     "Desktop publishing (DTP)$(_inst scribus)"                 "$(_state scribus)" \
        "shotcut"     "Video editor (cross-platform)$(_inst shotcut)"            "$(_state shotcut)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Code Editors & IDEs (Bullseye)" --checklist \
        "Select editors and IDEs${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "vim"        "Classic terminal editor$(_inst vim)"          "$(_state vim)" \
        "vim-gtk3"   "Vim with GTK3 GUI$(_inst vim-gtk3)"         "$(_state vim-gtk3)" \
        "neovim"     "Modern vim fork$(_inst neovim)"              "$(_state neovim)" \
        "nano"       "Simple terminal editor$(_inst nano)"         "$(_state nano)" \
        "emacs"      "Extensible editor / IDE$(_inst emacs)"       "$(_state emacs)" \
        "kate"       "KDE advanced text editor$(_inst kate)"       "$(_state kate)" \
        "mousepad"   "Xfce text editor$(_inst mousepad)"           "$(_state mousepad)" \
        "gedit"      "GNOME text editor$(_inst gedit)"             "$(_state gedit)" \
        "geany"      "Lightweight IDE$(_inst geany)"               "$(_state geany)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Servers & Dev Tools (Bullseye)" --checklist \
        "Select development tools and servers${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "apache2"         "Apache web server$(_inst apache2)"                        "$(_state apache2)" \
        "build-essential" "C/C++ build tools (gcc, make)$(_inst build-essential)"   "$(_state build-essential)" \
        "docker"          "Docker container runtime$(_inst docker.io)"               "$(_state docker.io)" \
        "mariadb-server"  "MariaDB database server$(_inst mariadb-server)"           "$(_state mariadb-server)" \
        "netcat-openbsd"  "TCP/IP networking utility$(_inst netcat-openbsd)"         "$(_state netcat-openbsd)" \
        "nginx"           "Nginx web server$(_inst nginx)"                          "$(_state nginx)" \
        "openssh-server"  "SSH server$(_inst openssh-server)"                       "$(_state openssh-server)" \
        "openssl"         "OpenSSL cryptography toolkit$(_inst openssl)"             "$(_state openssl)" \
        "postgresql"      "PostgreSQL database server$(_inst postgresql)"            "$(_state postgresql)" \
        "python3-pip"     "Python 3 pip + venv + dev$(_inst python3-pip)"            "$(_state python3-pip)" \
        "redis-server"    "Redis key-value store$(_inst redis-server)"               "$(_state redis-server)" \
        "sqlite3"         "SQLite database engine$(_inst sqlite3)"                   "$(_state sqlite3)" \
        "jellyfin"        "Jellyfin Media Server (Web GUI on port 8096)$(_inst jellyfin)" OFF \
        "openjdk-dev-env" "Adoptium Temurin JDK (17, 21, 25 LTS)$(_any_jdk_installed_desc)" "$(_any_jdk_state)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "Security & Networking (Bullseye)" --checklist \
        "Select security and networking tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "wireshark"   "Network protocol analyzer (GUI)$(_inst wireshark)"       "$(_state wireshark)" \
        "tcpdump"     "Command-line packet analyzer$(_inst tcpdump)"            "$(_state tcpdump)" \
        "fail2ban"    "Brute-force protection daemon$(_inst fail2ban)"          "$(_state fail2ban)" \
        "ufw"         "Uncomplicated firewall$(_inst ufw)"                      "$(_state ufw)" \
        "clamav"      "Antivirus engine (ClamAV)$(_inst clamav)"                "$(_state clamav)" \
        3>&1 1>&2 2>&3)
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
    local choices
    choices=$(whiptail --title "System Tools (Bullseye)" --checklist \
        "Select system utilities${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "compress"           "Compression tools (zip, unrar, p7zip)$(_inst zip)"          "$(_state zip)" \
        "conky"              "System monitor for desktop$(_inst conky)"                    "$(_state conky)" \
        "cpu-x"              "CPU-X (alternative to CPU-Z)$(_inst cpu-x)"                  "$(_state cpu-x)" \
        "curl-wget"          "HTTP transfer tools (curl, wget)$(_inst curl)"               "$(_state curl)" \
        "flatpak"            "Flatpak sandbox (Bullseye native)$(_inst flatpak)"           "$(_state flatpak)" \
        "fwupd"              "Firmware update daemon$(_inst fwupd)"                        "$(_state fwupd)" \
        "gnome-disk-utility" "Disk management GUI$(_inst gnome-disk-utility)"              "$(_state gnome-disk-utility)" \
        "gparted"            "Partition editor$(_inst gparted)"                             "$(_state gparted)" \
        "htop"               "Interactive process viewer$(_inst htop)"                      "$(_state htop)" \
        "inxi"               "System information tool$(_inst inxi)"                         "$(_state inxi)" \
        "kvm"                "QEMU/KVM virtualization$(_inst virt-manager)"                 "$(_state virt-manager)" \
        "lshw"               "List hardware details$(_inst lshw)"                           "$(_state lshw)" \
        "mc"                 "Midnight Commander$(_inst mc)"                                "$(_state mc)" \
        "nvme-cli"           "NVMe SSD health monitoring$(_inst nvme-cli)"                   "$(_state nvme-cli)" \
        "ncdu"               "Disk usage analyzer$(_inst ncdu)"                             "$(_state ncdu)" \
        "psensor"            "Temperature monitor$(_inst psensor)"                          "$(_state psensor)" \
        "timeshift"          "System restore snapshots$(_inst timeshift)"                   "$(_state timeshift)" \
        "tmux"               "Terminal multiplexer$(_inst tmux)"                            "$(_state tmux)" \
        "wine"               "Windows compatibility layer$(_inst wine)"                     "$(_state wine)" \
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
                if ! is_installed "wine"; then
                    if ! dpkg --print-foreign-architectures 2>/dev/null | grep -q i386; then
                        sudo dpkg --add-architecture i386
                        _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
                    fi
                    _run_cmd "Wine" "sudo apt install -y wine wine32 wine64 libwine libwine:i386 fonts-wine" "Installing Wine..."
                    echo -e "${GREEN}Wine installed.${NC}"
                else
                    echo "Wine already installed."
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
        "neofetch"    "System info fetcher$(_inst neofetch)"        "$(_state neofetch)"
        "screenfetch" "System info (BSD/Linux)$(_inst screenfetch)" "$(_state screenfetch)"
        "linuxlogo"   "Linux logo + system info$(_inst linuxlogo)" "$(_state linuxlogo)"
    )
    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Fetch Tools (Bullseye)" --checklist \
        "Select system info tools:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "${items[@]}" 3>&1 1>&2 2>&3)
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
        cat_choice=$(whiptail --title "Extra Software — Bullseye" --menu \
            "Select a category${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0"  "Essential Pack" \
            "1"  "Customization System" \
            "2"  "Download & Network" \
            "3"  "Internet (Browsers, Email)" \
            "4"  "Media Players" \
            "5"  "Multimedia & Design" \
            "6"  "Code Editors & IDEs" \
            "7"  "Servers & Dev Tools" \
            "8"  "Security & Networking" \
            "9"  "Software Centers" \
            "10" "System Tools" \
            "11" "Fetch / System Info" \
            "12" "Back to main menu" \
            3>&1 1>&2 2>&3)

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            0)  _quick_install_bullseye ;;
            1)  _cat_customization_bullseye ;;
            2)  _cat_download_bullseye ;;
            3)  _cat_internet_bullseye ;;
            4)  _cat_players_bullseye ;;
            5)  _cat_design_bullseye ;;
            6)  _cat_programming_bullseye ;;
            7)  _cat_dev_bullseye ;;
            8)  _cat_security_bullseye ;;
            9)  _cat_software_centers_bullseye ;;
            10) _cat_general_bullseye ;;
            11) _cat_fetch_bullseye ;;
            12) return ;;
        esac
        clear
    done
}

_cat_software_centers_bullseye() {
    local sc_choice
    sc_choice=$(whiptail --title "Software Centers" --menu \
        "Choose a software store to install:" 12 65 2 \
        "gnome-software"   "Software Center for GNOME$(_inst gnome-software)" \
        "plasma-discover"  "Software manager for Plasma$(_inst plasma-discover)" \
        3>&1 1>&2 2>&3)
    [ -z "$sc_choice" ] && return

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
