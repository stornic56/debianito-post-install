#!/usr/bin/env bash
# extras.sh

install_extras() {
    echo -e "${YELLOW}Extra software installation...${NC}"

    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    ! command -v dialog &>/dev/null && sudo apt install -y dialog 2>/dev/null || true

    # Quick Install prompt
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

    # Helper: mark installed packages
    mk_inst() {
        if is_installed "$1"; then
            echo " (installed)"
        else
            echo ""
        fi
    }

    # Dynamic states for all packages (keeps installed ones pre-marked)
    local compress_state="OFF"
    is_installed "zip" && is_installed "unzip" && is_installed "p7zip-full" && compress_state="ON"

    local fetch_state="OFF";  is_installed "$fetch_pkg" && fetch_state="ON"
    local lshw_state="OFF";   is_installed "lshw" && lshw_state="ON"
    local inxi_state="OFF";   is_installed "inxi" && inxi_state="ON"
    local hardinfo_state="OFF"; is_installed "hardinfo" && hardinfo_state="ON"
    local cpufetch_state="OFF"; is_installed "cpufetch" && cpufetch_state="ON"
    local cpu_x_state="OFF";  is_installed "cpu-x" && cpu_x_state="ON"
    local btop_state="OFF";   is_installed "btop" && btop_state="ON"
    local htop_state="OFF";   is_installed "htop" && htop_state="ON"
    local vlc_state="OFF";    is_installed "vlc" && vlc_state="ON"
    local mpv_state="OFF";    is_installed "mpv" && mpv_state="ON"
    local chromium_state="OFF"; is_installed "chromium" && chromium_state="ON"
    local ttf_state="OFF";    is_installed "ttf-mscorefonts-installer" && ttf_state="ON"
    local fonts_state="OFF";  is_installed "fonts-ubuntu" && fonts_state="ON"
    local gparted_state="OFF"; is_installed "gparted" && gparted_state="ON"
    local flatpak_state="OFF"; is_installed "flatpak" && flatpak_state="ON"
    local fwupd_state="OFF";  is_installed "fwupd" && fwupd_state="ON"
    local nala_state="OFF";   is_installed "nala" && nala_state="ON"
    local ssh_state="OFF";    is_installed "openssh-server" && ssh_state="ON"
    local timeshift_state="OFF"; is_installed "timeshift" && timeshift_state="ON"
    local kitty_state="OFF";  is_installed "kitty" && kitty_state="ON"
    local alacritty_state="OFF"; is_installed "alacritty" && alacritty_state="ON"
    local psensor_state="OFF"; is_installed "psensor" && psensor_state="ON"
    local mc_state="OFF";     is_installed "mc" && mc_state="ON"
    local disks_state="OFF";  is_installed "gnome-disk-utility" && disks_state="ON"
    local build_state="OFF";  is_installed "build-essential" && build_state="ON"
    local props_state="OFF";  is_installed "software-properties-common" && props_state="ON"
    local thunderbird_state="OFF"; is_installed "thunderbird" && thunderbird_state="ON"
    local curl_wget_state="OFF"; is_installed "curl" && is_installed "wget" && curl_wget_state="ON"
    local extrepo_state="OFF"; is_installed "extrepo" && extrepo_state="ON"
    local conky_state="OFF";  is_installed "conky" && conky_state="ON"

    local firefox_state="OFF"
    if command -v firefox &>/dev/null && ! command -v firefox-esr &>/dev/null; then
        firefox_state="ON"
    fi

    local kvm_state="OFF";    is_installed "virt-manager" && kvm_state="ON"
    local librewolf_state="OFF"; is_installed "librewolf" && librewolf_state="ON"

    local choices
    choices=$(dialog --title "Extra Software" --checklist \
        "Select programs to install (space to toggle, enter to confirm):" \
        26 72 23 \
        "alacritty"     "GPU-accelerated terminal$(mk_inst alacritty)"          "$alacritty_state" \
        "btop"          "Resource monitor (fancy top)$(mk_inst btop)"          "$btop_state" \
        "build-essential" "C/C++ build tools (gcc, make)$(mk_inst build-essential)" "$build_state" \
        "chromium"      "Chromium web browser$(mk_inst chromium)"              "$chromium_state" \
        "compress"      "Compression tools (zip, unrar, 7z)$(mk_inst zip)"    "$compress_state" \
        "conky"         "System monitor for desktop$(mk_inst conky)"           "$conky_state" \
        "cpufetch"      "CPU info fetcher$(mk_inst cpufetch)"                  "$cpufetch_state" \
        "cpu-x"         "CPU-X (alternative to CPU-Z)$(mk_inst cpu-x)"         "$cpu_x_state" \
        "curl-wget"     "HTTP transfer tools (curl, wget)$(mk_inst curl)"      "$curl_wget_state" \
        "extrepo"       "External repository manager$(mk_inst extrepo)"        "$extrepo_state" \
        "${fetch_pkg}"  "Show system info$(mk_inst $fetch_pkg)"                "$fetch_state" \
        "firefox"       "Firefox from Mozilla (replaces ESR)"                  "$firefox_state" \
        "flatpak"       "Flatpak sandbox + Flathub$(mk_inst flatpak)"          "$flatpak_state" \
        "fonts-ubuntu"  "Ubuntu font family$(mk_inst fonts-ubuntu)"            "$fonts_state" \
        "fwupd"         "Firmware update daemon$(mk_inst fwupd)"               "$fwupd_state" \
        "gnome-disk-utility" "Disk management GUI$(mk_inst gnome-disk-utility)" "$disks_state" \
        "gparted"       "GNOME partition editor$(mk_inst gparted)"             "$gparted_state" \
        "hardinfo"      "Graphical system profiler$(mk_inst hardinfo)"         "$hardinfo_state" \
        "htop"          "Interactive process viewer$(mk_inst htop)"            "$htop_state" \
        "inxi"          "System information tool$(mk_inst inxi)"               "$inxi_state" \
        "kitty"         "GPU-based terminal emulator$(mk_inst kitty)"          "$kitty_state" \
        "kvm"           "QEMU/KVM virtualization$(mk_inst virt-manager)"       "$kvm_state" \
        "librewolf"     "Privacy-focused Firefox fork$(mk_inst librewolf)"     "$librewolf_state" \
        "lshw"          "List hardware details$(mk_inst lshw)"                 "$lshw_state" \
        "mc"            "Midnight Commander (file manager)$(mk_inst mc)"       "$mc_state" \
        "mpv"           "Lightweight media player$(mk_inst mpv)"               "$mpv_state" \
        "nala"          "APT frontend with parallel downloads$(mk_inst nala)"  "$nala_state" \
        "openssh-server" "SSH server$(mk_inst openssh-server)"                 "$ssh_state" \
        "psensor"       "Hardware temperature monitor$(mk_inst psensor)"       "$psensor_state" \
        "software-properties-common" "Repository management (PPA)$(mk_inst software-properties-common)" "$props_state" \
        "thunderbird"   "Email client$(mk_inst thunderbird)"                   "$thunderbird_state" \
        "timeshift"     "System restore snapshots$(mk_inst timeshift)"         "$timeshift_state" \
        "ttf-mscorefonts-installer" "Microsoft fonts (Times, Arial)$(mk_inst ttf-mscorefonts-installer)" "$ttf_state" \
        "vlc"           "VLC media player$(mk_inst vlc)"                       "$vlc_state" \
        3>&1 1>&2 2>&3)
    clear

    if [ -z "$choices" ]; then
        echo "No extra programs selected."
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

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
                local need_cw=()
                ! is_installed "curl" && need_cw+=("curl")
                ! is_installed "wget" && need_cw+=("wget")
                if [ ${#need_cw[@]} -gt 0 ]; then
                    echo "Installing HTTP transfer tools..."
                    sudo apt install -y "${need_cw[@]}"
                else
                    echo "curl and wget already installed."
                fi
                ;;
            firefox)
                install_firefox_mozilla
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

    echo -e "${GREEN}Extra software installed.${NC}"
}
