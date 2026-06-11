#!/usr/bin/env bash
# extras.sh — Bullseye: software purgado / solo repos oficiales
# License GPL v3

# ── Essential Pack (Bullseye) ──
_quick_install_bullseye() {
    _msg "Essential Pack — Bullseye" \
        "Instalar programas básicos:\n\n\
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
}

# ======================================================================
# EXTRA SOFTWARE CATEGORIES — Bullseye versions (purged/whitelisted)
# Only packages available in Debian 11 official repos.
# ======================================================================

_cat_customization_bullseye() {
    local items=()
    if [ -f "${MODULES_DIR}/extras/themes/icons/icons.sh" ]; then
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
    else
        _msg "Customization" "Themes submodules not found." 8 50
    fi
}

_cat_themes_bullseye() {
    local theme_state; theme_state=$(_state "breeze")
    local numix_state;  numix_state=$(_state "numix-gtk-theme")

    if [ "$theme_state" = "OFF" ] && [ "$numix_state" = "OFF" ]; then
        theme_state="ON"
    fi

    local choices
    choices=$(whiptail --title "Desktop Themes (Bullseye)" --checklist \
        "Available themes in Bullseye repos ($TUI_ALTO linea):" \
        $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "breeze"        "Breeze GTK theme (KDE)$(_inst breeze)"                "$theme_state" \
        "numix-gtk-theme" "Numix GTK theme$(_inst numix-gtk-theme)"              "$numix_state" \
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
    _msg "Icon Themes (Bullseye)" \
        "Adwaita, Humanity, DMZ y otros temas de iconos\n\
están disponibles desde los repos oficiales.\n\n\
Seleccione desde el menú de GNOME/KDE o instale\n\
el paquete 'gnome-icon-theme' o 'breeze-icon-theme'." 12 60

    local choices
    choices=$(whiptail --title "Icon Themes (Bullseye)" --checklist \
        "Available icon themes:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "gnome-icon-theme"  "GNOME icon theme$(_inst gnome-icon-theme)"          "$(_state gnome-icon-theme)" \
        "breeze-icon-theme" "Breeze icon theme$(_inst breeze-icon-theme)"        "$(_state breeze-icon-theme)" \
        "papirus-icon-theme" "Papirus icon theme$(_inst papirus-icon-theme)"      "$(_state papirus-icon-theme)" \
        3>&1 1>&2 2>&3)
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
        "Available cursor themes:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "dmz-cursor-theme"  "DMZ cursor theme$(_inst dmz-cursor-theme)"              "$(_state dmz-cursor-theme)" \
        "breeze-cursor-theme" "Breeze cursor theme$(_inst breeze-cursor-theme)"       "$(_state breeze-cursor-theme)" \
        "oxygen-cursor-theme" "Oxygen cursor theme$(_inst oxygen-cursor-theme)"       "$(_state oxygen-cursor-theme)" \
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
        "Available fonts:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
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
    local choices
    choices=$(whiptail --title "Download & Torrent (Bullseye)" --checklist \
        "Select download tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "aria2"            "Multiprotocol downloader (CLI)$(_inst aria2)"         "$(_state aria2)" \
        "filezilla"        "FTP/SFTP client (GUI)$(_inst filezilla)"              "$(_state filezilla)" \
        "qbittorrent"      "BitTorrent client (Qt)$(_inst qbittorrent)"           "$(_state qbittorrent)" \
        "transmission-gtk" "BitTorrent client (GTK)$(_inst transmission-gtk)"     "$(_state transmission-gtk)" \
        "transmission-qt"  "BitTorrent client (Qt)$(_inst transmission-qt)"       "$(_state transmission-qt)" \
        "deluge"           "BitTorrent client (GTK)$(_inst deluge)"               "$(_state deluge)" \
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
    echo -e "${GREEN}Download tools installed.${NC}"
}

_cat_internet_bullseye() {
    local ff_state; ff_state=$(_state "firefox-esr")
    local tbird_state; tbird_state=$(_state "thunderbird")
    local chr_state; chr_state=$(_state "chromium")

    local choices
    choices=$(whiptail --title "Internet (Bullseye)" --checklist \
        "Select browsers, email:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "firefox-esr"  "Firefox ESR (official Debian)$(_inst firefox-esr)"   "$ff_state" \
        "chromium"     "Chromium web browser$(_inst chromium)"                "$chr_state" \
        "thunderbird"  "Email client$(_inst thunderbird)"                    "$tbird_state" \
        "dillo"        "Lightweight graphical browser$(_inst dillo)"          "$(_state dillo)" \
        "elinks"       "Text-mode web browser$(_inst elinks)"                "$(_state elinks)" \
        "konqueror"    "KDE file manager / web browser$(_inst konqueror)"     "$(_state konqueror)" \
        "w3m"          "Text-mode browser + deps$(_inst w3m)"                "$(_state w3m)" \
        "torbrowser-launcher" "Tor Browser launcher$(_inst torbrowser-launcher)" "$(_state torbrowser-launcher)" \
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
    echo -e "${GREEN}Internet tools installed.${NC}"
}

_cat_players_bullseye() {
    local choices
    choices=$(whiptail --title "Media Players (Bullseye)" --checklist \
        "Select media players:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
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
        "Select multimedia and design tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "audacity"   "Audio editor/recorder$(_inst audacity)"       "$(_state audacity)" \
        "blender"    "3D modeling/animation suite$(_inst blender)"  "$(_state blender)" \
        "ffmpeg"     "Multimedia framework (CLI)$(_inst ffmpeg)"    "$(_state ffmpeg)" \
        "gimp"       "Image editor$(_inst gimp)"                   "$(_state gimp)" \
        "inkscape"   "Vector graphics editor$(_inst inkscape)"     "$(_state inkscape)" \
        "kdenlive"   "Video editor (KDE)$(_inst kdenlive)"         "$(_state kdenlive)" \
        "obs-studio" "Streaming/recording studio$(_inst obs-studio)" "$(_state obs-studio)" \
        "scribus"    "Desktop publishing$(_inst scribus)"           "$(_state scribus)" \
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
    echo -e "${GREEN}Design tools installed.${NC}"
}

_cat_programming_bullseye() {
    local choices
    choices=$(whiptail --title "Programming (Bullseye)" --checklist \
        "Select programming tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "build-essential" "GCC/Clang compilers$(_inst build-essential)"           "$(_state build-essential)" \
        "python3"         "Python 3 interpreter$(_inst python3)"                  "$(_state python3)" \
        "python3-pip"     "Python 3 package manager$(_inst python3-pip)"          "$(_state python3-pip)" \
        "nodejs"          "Node.js (Debian repo)$(_inst nodejs)"                  "$(_state nodejs)" \
        "npm"             "Node.js package manager$(_inst npm)"                   "$(_state npm)" \
        "openjdk-17-jdk"  "OpenJDK 17 JDK$(_inst openjdk-17-jdk)"                 "$(_state openjdk-17-jdk)" \
        "git"             "Version control system$(_inst git)"                    "$(_state git)" \
        "vim"             "Text editor (Vim)$(_inst vim)"                         "$(_state vim)" \
        "nano"            "Text editor (Nano)$(_inst nano)"                        "$(_state nano)" \
        "geany"           "Lightweight IDE$(_inst geany)"                          "$(_state geany)" \
        "codeblocks"      "Cross-platform IDE$(_inst codeblocks)"                  "$(_state codeblocks)" \
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
    echo -e "${GREEN}Programming tools installed.${NC}"
}

_cat_security_bullseye() {
    local choices
    choices=$(whiptail --title "Security & Networking (Bullseye)" --checklist \
        "Select security tools:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "nmap"              "Network scanner$(_inst nmap)"                         "$(_state nmap)" \
        "wireshark"         "Packet analyzer$(_inst wireshark)"                     "$(_state wireshark)" \
        "nikto"             "Web server scanner$(_inst nikto)"                      "$(_state nikto)" \
        "sqlmap"            "SQL injection tool$(_inst sqlmap)"                     "$(_state sqlmap)" \
        "gobuster"          "Directory/file brute-forcer$(_inst gobuster)"          "$(_state gobuster)" \
        "hydra"             "Login cracker$(_inst hydra)"                           "$(_state hydra)" \
        "john"              "John the Ripper password cracker$(_inst john)"         "$(_state john)" \
        "aircrack-ng"       "Wireless security tool$(_inst aircrack-ng)"            "$(_state aircrack-ng)" \
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
    echo -e "${GREEN}Security tools installed.${NC}"
}

_cat_general_bullseye() {
    local choices
    choices=$(whiptail --title "System Tools (Bullseye)" --checklist \
        "Select system utilities:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "compress"          "Compression tools (zip, unrar, p7zip)$(_inst zip)"    "$(_state zip)" \
        "conky"             "System monitor for desktop$(_inst conky)"              "$(_state conky)" \
        "cpu-x"             "CPU-X (alternative to CPU-Z)$(_inst cpu-x)"            "$(_state cpu-x)" \
        "curl-wget"         "HTTP transfer tools (curl, wget)$(_inst curl)"         "$(_state curl)" \
        "flatpak"           "Flatpak sandbox (Bullseye native)$(_inst flatpak)"     "$(_state flatpak)" \
        "fwupd"             "Firmware update daemon$(_inst fwupd)"                  "$(_state fwupd)" \
        "gnome-disk-utility" "Disk management GUI$(_inst gnome-disk-utility)"        "$(_state gnome-disk-utility)" \
        "gparted"           "Partition editor$(_inst gparted)"                       "$(_state gparted)" \
        "htop"              "Interactive process viewer$(_inst htop)"                "$(_state htop)" \
        "inxi"              "System information tool$(_inst inxi)"                   "$(_state inxi)" \
        "kvm"               "QEMU/KVM virtualization$(_inst virt-manager)"           "$(_state virt-manager)" \
        "lshw"              "List hardware details$(_inst lshw)"                     "$(_state lshw)" \
        "mc"                "Midnight Commander$(_inst mc)"                          "$(_state mc)" \
        "ncdu"              "Disk usage analyzer$(_inst ncdu)"                       "$(_state ncdu)" \
        "psensor"           "Temperature monitor$(_inst psensor)"                    "$(_state psensor)" \
        "timeshift"         "System restore snapshots$(_inst timeshift)"             "$(_state timeshift)" \
        "tmux"              "Terminal multiplexer$(_inst tmux)"                      "$(_state tmux)" \
        "wine"              "Windows compatibility layer$(_inst wine)"               "$(_state wine)" \
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
                fi
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
    echo -e "${GREEN}System tools installed.${NC}"
}

_cat_fetch_bullseye() {
    local items=(
        "neofetch"    "System info fetcher$(_inst neofetch)"      "$(_state neofetch)"
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

    while true; do
        local cat_choice
        cat_choice=$(whiptail --title "Extra Software — Bullseye" --menu \
            "Select a category:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "0" "Essential Pack" \
            "1" "Customization System" \
            "2" "Download & Network" \
            "3" "Internet (Browsers, Email)" \
            "4" "Media Players" \
            "5" "Multimedia & Design" \
            "6" "Programming Applications" \
            "7" "Security & Networking" \
            "8" "System Tools" \
            "9" "Fetch / System Info" \
            "10" "Back to main menu" \
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
            7)  _cat_security_bullseye ;;
            8)  _cat_general_bullseye ;;
            9)  _cat_fetch_bullseye ;;
            10) return ;;
        esac
        clear
    done
}
