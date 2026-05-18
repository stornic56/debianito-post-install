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

    ! command -v dialog &>/dev/null && sudo apt install -y dialog 2>/dev/null || true

    if dialog --title "Quick Install" --yesno \
        "Install recommended tools?\n\n  - Compression tools (zip, unzip, rar, 7z)\n  - ${fetch_pkg} (system info)\n  - htop (process viewer)\n  - VLC (media player)\n  - inxi (system information)\n  - Microsoft fonts (Times New Roman, Arial)\n\n[Yes - Quick Install]  [No - Select individually]" 16 65; then
        echo "Installing recommended tools..."
        local quick_pkgs=()
        ! is_installed "zip" && quick_pkgs+=("zip")
        ! is_installed "unzip" && quick_pkgs+=("unzip")
        ! is_installed "rar" && quick_pkgs+=("rar")
        ! is_installed "unrar" && quick_pkgs+=("unrar")
        ! is_installed "p7zip-full" && quick_pkgs+=("p7zip-full")
        ! is_installed "p7zip-rar" && quick_pkgs+=("p7zip-rar")
        ! is_installed "$fetch_pkg" && quick_pkgs+=("$fetch_pkg")
        ! is_installed "htop" && quick_pkgs+=("htop")
        ! is_installed "vlc" && quick_pkgs+=("vlc")
        ! is_installed "inxi" && quick_pkgs+=("inxi")
        ! is_installed "ttf-mscorefonts-installer" && quick_pkgs+=("ttf-mscorefonts-installer")
        if [ ${#quick_pkgs[@]} -gt 0 ]; then
            sudo apt install -y "${quick_pkgs[@]}"
        else
            echo "All recommended tools are already installed."
        fi
        echo -e "${GREEN}Recommended tools installed.${NC}"
        return
    fi

    while true; do
        local cat_choice
        cat_choice=$(dialog --title "Extra Software" --menu \
            "Select a category:" 16 60 7 \
            "1" "System Tools" \
            "2" "Development & Servers" \
            "3" "Media & Browsers" \
            "4" "GTK Themes" \
            "5" "Icon Themes" \
            "6" "Fetch / System Info" \
            "7" "Back to main menu" \
            3>&1 1>&2 2>&3)

        [ -z "$cat_choice" ] && return
        clear

        case "$cat_choice" in
            1) _cat_general ;;
            2) _cat_dev ;;
            3) _cat_media ;;
            4) _cat_themes ;;
            5) _cat_icons ;;
            6) _cat_fetch ;;
            7) return ;;
        esac
        clear
    done
}

_cat_general() {
    local htop_state="OFF";  is_installed "htop" && htop_state="ON"
    local btop_state="OFF";  is_installed "btop" && btop_state="ON"
    local tmux_state="OFF";  is_installed "tmux" && tmux_state="ON"
    local ncdu_state="OFF";  is_installed "ncdu" && ncdu_state="ON"
    local mc_state="OFF";    is_installed "mc" && mc_state="ON"
    local psensor_state="OFF"; is_installed "psensor" && psensor_state="ON"
    local conky_state="OFF"; is_installed "conky" && conky_state="ON"
    local cpufetch_state="OFF"; is_installed "cpufetch" && cpufetch_state="ON"
    local cpu_x_state="OFF"; is_installed "cpu-x" && cpu_x_state="ON"
    local lshw_state="OFF";  is_installed "lshw" && lshw_state="ON"
    local inxi_state="OFF";  is_installed "inxi" && inxi_state="ON"
    local hardinfo_state="OFF"; is_installed "hardinfo" && hardinfo_state="ON"
    local nala_state="OFF";  is_installed "nala" && nala_state="ON"
    local fwupd_state="OFF"; is_installed "fwupd" && fwupd_state="ON"
    local gparted_state="OFF"; is_installed "gparted" && gparted_state="ON"
    local disks_state="OFF"; is_installed "gnome-disk-utility" && disks_state="ON"
    local timeshift_state="OFF"; is_installed "timeshift" && timeshift_state="ON"
    local compress_state="OFF"; is_installed "zip" && is_installed "unzip" && is_installed "p7zip-full" && compress_state="ON"
    local curl_wget_state="OFF"; is_installed "curl" && is_installed "wget" && curl_wget_state="ON"
    local flatpak_state="OFF"; is_installed "flatpak" && flatpak_state="ON"

    local alacritty_state="OFF"; is_installed "alacritty" && alacritty_state="ON"
    local kitty_state="OFF"; is_installed "kitty" && kitty_state="ON"
    local kvm_state="OFF";   is_installed "virt-manager" && kvm_state="ON"
    local ttf_state="OFF";   is_installed "ttf-mscorefonts-installer" && ttf_state="ON"
    local fonts_state="OFF"; is_installed "fonts-ubuntu" && fonts_state="ON"

    local choices
    choices=$(dialog --title "System Tools" --checklist \
        "Select system utilities to install:" 30 72 25 \
        "htop"      "Interactive process viewer$(_inst htop)"          "$htop_state" \
        "btop"      "Resource monitor (fancy top)$(_inst btop)"        "$btop_state" \
        "tmux"      "Terminal multiplexer$(_inst tmux)"                "$tmux_state" \
        "ncdu"      "Disk usage analyzer (ncurses)$(_inst ncdu)"       "$ncdu_state" \
        "mc"        "Midnight Commander (file manager)$(_inst mc)"     "$mc_state" \
        "psensor"   "Hardware temperature monitor$(_inst psensor)"     "$psensor_state" \
        "conky"     "System monitor for desktop$(_inst conky)"         "$conky_state" \
        "cpufetch"  "CPU info fetcher$(_inst cpufetch)"                "$cpufetch_state" \
        "cpu-x"     "CPU-X (alternative to CPU-Z)$(_inst cpu-x)"       "$cpu_x_state" \
        "lshw"      "List hardware details$(_inst lshw)"               "$lshw_state" \
        "inxi"      "System information tool$(_inst inxi)"             "$inxi_state" \
        "hardinfo"  "Graphical system profiler$(_inst hardinfo)"       "$hardinfo_state" \
        "nala"      "APT frontend (parallel downloads)$(_inst nala)"   "$nala_state" \
        "fwupd"     "Firmware update daemon$(_inst fwupd)"             "$fwupd_state" \
        "gparted"   "GNOME partition editor$(_inst gparted)"           "$gparted_state" \
        "gnome-disk-utility" "Disk management GUI$(_inst gnome-disk-utility)" "$disks_state" \
        "timeshift" "System restore snapshots$(_inst timeshift)"       "$timeshift_state" \
        "alacritty" "GPU-accelerated terminal$(_inst alacritty)"       "$alacritty_state" \
        "kitty"     "GPU-based terminal emulator$(_inst kitty)"        "$kitty_state" \
        "kvm"       "QEMU/KVM virtualization$(_inst virt-manager)"     "$kvm_state" \
        "compress"  "Compression tools (zip, unrar, 7z)$(_inst zip)"   "$compress_state" \
        "curl-wget" "HTTP transfer tools (curl, wget)$(_inst curl)"    "$curl_wget_state" \
        "flatpak"   "Flatpak sandbox + Flathub$(_inst flatpak)"        "$flatpak_state" \
        "ttf-mscorefonts-installer" "Microsoft fonts (Times, Arial)$(_inst ttf-mscorefonts-installer)" "$ttf_state" \
        "fonts-ubuntu" "Ubuntu font family$(_inst fonts-ubuntu)"       "$fonts_state" \
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
                    echo "Installing compression utilities..."
                    sudo apt install -y "${need[@]}"
                    echo -e "${GREEN}Compression utilities installed.${NC}"
                fi
                ;;
            curl-wget)
                local need=()
                ! is_installed "curl" && need+=("curl")
                ! is_installed "wget" && need+=("wget")
                if [ ${#need[@]} -gt 0 ]; then
                    echo "Installing HTTP tools..."
                    sudo apt install -y "${need[@]}"
                else
                    echo "curl and wget already installed."
                fi
                ;;
            flatpak)
                if ! is_installed "flatpak"; then
                    echo "Installing Flatpak..."
                    sudo apt install -y flatpak
                    if command -v plasma-discover &>/dev/null; then
                        sudo apt install -y plasma-discover-backend-flatpak
                        echo "Flatpak backend for Discover installed."
                    elif command -v gnome-software &>/dev/null; then
                        sudo apt install -y gnome-software-plugin-flatpak
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
                    echo "Installing QEMU/KVM virtualization..."
                    sudo apt install -y qemu-system-x86 qemu-utils libvirt-daemon-system \
                        libvirt-clients bridge-utils virt-manager
                    sudo adduser "$USER" libvirt 2>/dev/null || true
                    sudo adduser "$USER" kvm 2>/dev/null || true
                    echo -e "${GREEN}QEMU/KVM installed. A reboot is recommended.${NC}"
                else
                    echo "QEMU/KVM already installed."
                fi
                ;;
            *)
                if ! is_installed "$pkg"; then
                    sudo apt install -y "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}System tools installed.${NC}"
}

_cat_dev() {
    local build_state="OFF";  is_installed "build-essential" && build_state="ON"
    local pip_state="OFF";    is_installed "python3-pip" && pip_state="ON"
    local docker_state="OFF"; is_installed "docker.io" && docker_state="ON"
    local apache_state="OFF"; is_installed "apache2" && apache_state="ON"
    local nginx_state="OFF";  is_installed "nginx" && nginx_state="ON"
    local mariadb_state="OFF"; is_installed "mariadb-server" && mariadb_state="ON"
    local pg_state="OFF";     is_installed "postgresql" && pg_state="ON"
    local sqlite_state="OFF"; is_installed "sqlite3" && sqlite_state="ON"
    local redis_state="OFF";  is_installed "redis-server" && redis_state="ON"
    local extrepo_state="OFF"; is_installed "extrepo" && extrepo_state="ON"
    local props_state="OFF";  is_installed "software-properties-common" && props_state="ON"
    local openssl_state="OFF"; is_installed "openssl" && openssl_state="ON"
    local netcat_state="OFF"; is_installed "netcat-openbsd" && netcat_state="ON"
    local certbot_state="OFF"; is_installed "certbot" && certbot_state="ON"
    local ufw_state="OFF";     is_installed "ufw" && ufw_state="ON"
    local fail2ban_state="OFF"; is_installed "fail2ban" && fail2ban_state="ON"
    local ssh_state="OFF";     is_installed "openssh-server" && ssh_state="ON"

    local choices
    choices=$(dialog --title "Development & Servers" --checklist \
        "Select development tools and servers:" 26 72 17 \
        "build-essential"           "C/C++ build tools (gcc, make)$(_inst build-essential)"        "$build_state" \
        "python3-pip"               "Python 3 pip + venv + dev$(_inst python3-pip)"                "$pip_state" \
        "docker"                    "Docker + docker-compose$(_inst docker.io)"                    "$docker_state" \
        "apache2"                   "Apache web server$(_inst apache2)"                            "$apache_state" \
        "nginx"                     "Nginx web server$(_inst nginx)"                               "$nginx_state" \
        "mariadb-server"            "MariaDB database server$(_inst mariadb-server)"               "$mariadb_state" \
        "postgresql"                "PostgreSQL database server$(_inst postgresql)"                 "$pg_state" \
        "sqlite3"                   "SQLite database engine$(_inst sqlite3)"                       "$sqlite_state" \
        "redis-server"              "Redis key-value store$(_inst redis-server)"                   "$redis_state" \
        "extrepo"                   "External repository manager$(_inst extrepo)"                  "$extrepo_state" \
        "software-properties-common" "Repository management (PPA)$(_inst software-properties-common)" "$props_state" \
        "openssl"                   "OpenSSL cryptography toolkit$(_inst openssl)"                 "$openssl_state" \
        "netcat-openbsd"            "TCP/IP networking utility$(_inst netcat-openbsd)"             "$netcat_state" \
        "certbot"                   "Let's Encrypt TLS certificates$(_inst certbot)"               "$certbot_state" \
        "ufw"                       "Uncomplicated firewall$(_inst ufw)"                           "$ufw_state" \
        "fail2ban"                  "Brute-force protection$(_inst fail2ban)"                      "$fail2ban_state" \
        "openssh-server"            "SSH server$(_inst openssh-server)"                            "$ssh_state" \
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
                    echo "Installing Python 3 development tools..."
                    sudo apt install -y "${need[@]}"
                else
                    echo "Python 3 tools already installed."
                fi
                ;;
            docker)
                local need=()
                ! is_installed "docker.io" && need+=("docker.io")
                ! is_installed "docker-compose" && need+=("docker-compose")
                if [ ${#need[@]} -gt 0 ]; then
                    echo "Installing Docker..."
                    sudo apt install -y "${need[@]}"
                else
                    echo "Docker already installed."
                fi
                ;;
            *)
                if ! is_installed "$pkg"; then
                    sudo apt install -y "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Development tools and servers installed.${NC}"
}

_cat_media() {
    local vlc_state="OFF";          is_installed "vlc" && vlc_state="ON"
    local mpv_state="OFF";          is_installed "mpv" && mpv_state="ON"
    local chromium_state="OFF";     is_installed "chromium" && chromium_state="ON"
    local thunderbird_state="OFF";  is_installed "thunderbird" && thunderbird_state="ON"
    local firefox_state="OFF"
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        firefox_state="ON"
    fi
    local librewolf_state="OFF";    is_installed "librewolf" && librewolf_state="ON"

    local choices
    choices=$(dialog --title "Media & Browsers" --checklist \
        "Select media players and browsers:" 16 72 6 \
        "vlc"       "VLC media player$(_inst vlc)"                     "$vlc_state" \
        "mpv"       "Lightweight media player$(_inst mpv)"             "$mpv_state" \
        "chromium"  "Chromium web browser$(_inst chromium)"            "$chromium_state" \
        "firefox"   "Firefox from Mozilla (replaces ESR)"              "$firefox_state" \
        "thunderbird" "Email client$(_inst thunderbird)"               "$thunderbird_state" \
        "librewolf" "Privacy-focused Firefox fork$(_inst librewolf)"   "$librewolf_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            firefox)
                install_firefox_mozilla
                ;;
            librewolf)
                if ! is_installed "librewolf"; then
                    echo "Installing LibreWolf..."
                    sudo apt install -y extrepo
                    sudo extrepo enable librewolf 2>/dev/null || true
                    sudo apt update
                    sudo apt install -y librewolf
                    echo -e "${GREEN}LibreWolf installed.${NC}"
                else
                    echo "LibreWolf already installed."
                fi
                ;;
            *)
                if ! is_installed "$pkg"; then
                    sudo apt install -y "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Media & browsers installed.${NC}"
}

_cat_themes() {
    local arc_state="OFF";         is_installed "arc-theme" && arc_state="ON"
    local orchis_state="OFF";      is_installed "orchis-gtk-theme" && orchis_state="ON"
    local numix_gtk_state="OFF";   is_installed "numix-gtk-theme" && numix_gtk_state="ON"
    local breeze_gtk_state="OFF";  is_installed "breeze-gtk-theme" && breeze_gtk_state="ON"
    local blackbird_state="OFF";   is_installed "blackbird-gtk-theme" && blackbird_state="ON"
    local bluebird_state="OFF";    is_installed "bluebird-gtk-theme" && bluebird_state="ON"
    local greybird_state="OFF";    is_installed "greybird-gtk-theme" && greybird_state="ON"

    local choices
    choices=$(dialog --title "GTK Themes" --checklist \
        "Select GTK themes to install:" 16 72 7 \
        "arc-theme"          "Arc GTK theme$(_inst arc-theme)"                 "$arc_state" \
        "orchis-gtk-theme"   "Orchis GTK theme$(_inst orchis-gtk-theme)"       "$orchis_state" \
        "numix-gtk-theme"    "Numix GTK theme$(_inst numix-gtk-theme)"         "$numix_gtk_state" \
        "breeze-gtk-theme"   "Breeze GTK theme$(_inst breeze-gtk-theme)"       "$breeze_gtk_state" \
        "blackbird-gtk-theme" "Blackbird GTK theme$(_inst blackbird-gtk-theme)" "$blackbird_state" \
        "bluebird-gtk-theme"  "Bluebird GTK theme$(_inst bluebird-gtk-theme)"   "$bluebird_state" \
        "greybird-gtk-theme"  "Greybird GTK theme$(_inst greybird-gtk-theme)"   "$greybird_state" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            sudo apt install -y "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}GTK themes installed.${NC}"
}

_cat_icons() {
    local papirus_state="OFF"; is_installed "papirus-icon-theme" && papirus_state="ON"
    local numix_state="OFF";   is_installed "numix-icon-theme" && numix_state="ON"
    local numix_c_state="OFF"; is_installed "numix-icon-theme-circle" && numix_c_state="ON"
    local breeze_state="OFF";  is_installed "breeze-icon-theme" && breeze_state="ON"
    local deepin_state="OFF";  is_installed "deepin-icon-theme" && deepin_state="ON"
    local ele_state="OFF";     is_installed "elementary-icon-theme" && ele_state="ON"
    local ele_xfce_state="OFF"; is_installed "elementary-xfce-icon-theme" && ele_xfce_state="ON"
    local moka_state="OFF";    is_installed "moka-icon-theme" && moka_state="ON"
    local paper_state="OFF";   is_installed "paper-icon-theme" && paper_state="ON"
    local suru_state="OFF";    is_installed "suru-icon-theme" && suru_state="ON"
    local obsidian_state="OFF"; is_installed "obsidian-icon-theme" && obsidian_state="ON"

    local kf6_state="OFF"
    local has_kf6=false
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        is_installed "kf6-breeze-icon-theme" && kf6_state="ON"
        has_kf6=true
    fi

    local height=18
    local list_height=12
    local items=(
        "papirus-icon-theme"    "Papirus icon theme$(_inst papirus-icon-theme)"         "$papirus_state"
        "numix-icon-theme"      "Numix icon theme$(_inst numix-icon-theme)"             "$numix_state"
        "numix-icon-theme-circle" "Numix Circle icon theme$(_inst numix-icon-theme-circle)" "$numix_c_state"
        "breeze-icon-theme"     "Breeze icon theme$(_inst breeze-icon-theme)"           "$breeze_state"
        "deepin-icon-theme"     "Deepin icon theme$(_inst deepin-icon-theme)"           "$deepin_state"
        "elementary-icon-theme" "Elementary icon theme$(_inst elementary-icon-theme)"   "$ele_state"
        "elementary-xfce-icon-theme" "Elementary Xfce icons$(_inst elementary-xfce-icon-theme)" "$ele_xfce_state"
        "moka-icon-theme"       "Moka icon theme$(_inst moka-icon-theme)"               "$moka_state"
        "paper-icon-theme"      "Paper icon theme$(_inst paper-icon-theme)"             "$paper_state"
        "suru-icon-theme"       "Suru icon theme$(_inst suru-icon-theme)"               "$suru_state"
        "obsidian-icon-theme"   "Obsidian icon theme$(_inst obsidian-icon-theme)"       "$obsidian_state"
    )
    if $has_kf6; then
        items+=("kf6-breeze-icon-theme" "KF6 Breeze icon theme$(_inst kf6-breeze-icon-theme)" "$kf6_state")
        height=20
        list_height=13
    fi

    local choices
    choices=$(dialog --title "Icon Themes" --checklist \
        "Select icon themes to install:" "$height" 72 "$list_height" \
        "${items[@]}" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            sudo apt install -y "$pkg"
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
    local screenfetch_state="OFF"; is_installed "screenfetch" && screenfetch_state="ON"
    local linuxlogo_state="OFF"; is_installed "linuxlogo" && linuxlogo_state="ON"

    local items=(
        "${fetch_pkg}" "System info fetcher$(_inst $fetch_pkg)" "$fetch_state"
        "screenfetch"  "System info (BSD/Linux)$(_inst screenfetch)" "$screenfetch_state"
        "linuxlogo"    "Linux logo + system info$(_inst linuxlogo)" "$linuxlogo_state"
    )

    local height=14
    local list_height=3
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        local hyfetch_state="OFF"; is_installed "hyfetch" && hyfetch_state="ON"
        items+=("hyfetch" "Neofetch with pride flags$(_inst hyfetch)" "$hyfetch_state")
        height=16
        list_height=4
    fi

    local choices
    choices=$(dialog --title "Fetch Tools" --checklist \
        "Select system info tools:" "$height" 72 "$list_height" \
        "${items[@]}" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            neofetch|fastfetch)
                if ! is_installed "$pkg"; then
                    sudo apt install -y "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
            *)
                if ! is_installed "$pkg"; then
                    sudo apt install -y "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Fetch tools installed.${NC}"
}

install_firefox_mozilla() {
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        echo "Firefox (Mozilla) is already installed."
        return
    fi

    echo "Setting up Mozilla APT repository for Firefox..."

    if is_installed "firefox-esr"; then
        if whiptail --title "Firefox ESR" --yesno \
            "Firefox ESR is installed.\n\nRemove it before installing Mozilla Firefox?\n\nChoose No to keep both Firefox versions." 11 60; then
            echo "Removing Firefox ESR..."
            sudo apt remove -y firefox-esr
        else
            echo "Keeping Firefox ESR."
        fi
    fi

    ! is_installed "wget" && sudo apt install -y wget
    ! is_installed "gpg" && sudo apt install -y gpg

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

    sudo apt update
    sudo apt install -y firefox

    echo -e "${GREEN}Firefox (Mozilla) installed.${NC}"
}
