#!/usr/bin/env bash
# system.sh — System Tools (extrepo moved here from Dev & Servers)

_detect_desktop_type() {
    local desktop
    desktop="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    desktop="${desktop,,}"

    case "$desktop" in
        *kde*|*lxqt*|*razor*|*plasma*)
            echo "qt"; return ;;
        *gnome*|*xfce*|*cinnamon*|*mate*|*lxde*|*budgie*|*sway*|*hyprland*|*i3*|*bspwm*|*openbox*|*fluxbox*)
            echo "gtk"; return ;;
    esac

    echo "gtk"
}

_cat_general() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    local btop_state;      btop_state=$(_state "btop")
    local compress_state
    if is_installed "zip" && is_installed "unzip" && is_installed "p7zip-full"; then
        compress_state="ON"
    else
        compress_state="OFF"
    fi
    local cpufetch_state;  cpufetch_state=$(_state "cpufetch")
    local cpu_x_state;     cpu_x_state=$(_state "cpu-x")
    local curl_wget_state
    if is_installed "curl" && is_installed "wget"; then
        curl_wget_state="ON"
    else
        curl_wget_state="OFF"
    fi
    local extrepo_state;   extrepo_state=$(_state "extrepo")
    local flatpak_state;   flatpak_state=$(_state "flatpak")
    local fwupd_state;     fwupd_state=$(_state "fwupd")
    local htop_state;      htop_state=$(_state "htop")
    local inxi_state;      inxi_state=$(_state "inxi")
    local jq_state;        jq_state=$(_state "jq")
    local kvm_state;       kvm_state=$(_state "virt-manager")
    local lshw_state;      lshw_state=$(_state "lshw")
    local mc_state;        mc_state=$(_state "mc")
    local nala_state;      nala_state=$(_state "nala")
    local ncdu_state;      ncdu_state=$(_state "ncdu")
    local tmux_state;      tmux_state=$(_state "tmux")
    local wine_state;      wine_state=$(_state "wine")
    local nvme_state;      nvme_state=$(_state "nvme-cli")
    items+=(
        "btop"            "Resource monitor (fancy top)"             "$btop_state"
        "compress"        "Compression tools (zip, unrar, 7z)"        "$compress_state"
        "cpufetch"        "CPU info fetcher"                     "$cpufetch_state"
        "cpu-x"           "CPU-X (alternative to CPU-Z)"            "$cpu_x_state"
        "curl-wget"       "HTTP transfer tools (curl, wget)"         "$curl_wget_state"
        "extrepo"         "External repository manager"           "$extrepo_state"
        "flatpak"         "Flatpak sandbox + Flathub"             "$flatpak_state"
        "fwupd"           "Firmware update daemon"                  "$fwupd_state"
        "htop"            "Interactive process viewer"               "$htop_state"
        "inxi"            "System information tool"                  "$inxi_state"
        "jq"              "JSON command-line processor"              "$jq_state"
        "kvm"             "QEMU/KVM virtualization"          "$kvm_state"
        "lshw"            "List hardware details"                    "$lshw_state"
        "mc"              "Midnight Commander (file manager)"          "$mc_state"
        "nala"            "APT frontend (parallel downloads)"        "$nala_state"
        "ncdu"            "Disk usage analyzer (ncurses)"            "$ncdu_state"
        "nvme-cli"        "NVMe SSD health monitoring"           "$nvme_state"
        "tmux"            "Terminal multiplexer"                     "$tmux_state"
        "wine"            "Windows compatibility layer"              "$wine_state"
    )
    if ! $headless; then
        local bleachbit_state; bleachbit_state=$(_state "bleachbit")
        local conky_state;     conky_state=$(_state "conky")
        local gdebi_state;     gdebi_state=$(_state "gdebi")
        local corectrl_state;  corectrl_state=$(_state "corectrl")
        local dcgtk_state;     dcgtk_state=$(_state "doublecmd-gtk")
        local dcqt_state;      dcqt_state=$(_state "doublecmd-qt")
        local disks_state;     disks_state=$(_state "gnome-disk-utility")
        local gparted_state;   gparted_state=$(_state "gparted")
        local hardinfo_state;  hardinfo_state=$(_state "hardinfo")
        local psensor_state;   psensor_state=$(_state "psensor")
        local timeshift_state; timeshift_state=$(_state "timeshift")
        items+=(
            "bleachbit"       "System cleaner (GUI)"                "$bleachbit_state"
            "conky"           "System monitor for desktop"              "$conky_state"
            "gdebi"           "Install .deb packages with deps"         "$gdebi_state"
            "corectrl"        "AMD GPU control (CoreCtrl)"           "$corectrl_state"
            "doublecmd-gtk"   "Dual-panel file manager (GTK)"  "$dcgtk_state"
            "doublecmd-qt"    "Dual-panel file manager (Qt)"     "$dcqt_state"
            "gnome-disk-utility" "Disk management GUI"     "$disks_state"
            "gparted"         "GNOME partition editor"                "$gparted_state"
            "hardinfo"        "Graphical system profiler"            "$hardinfo_state"
            "psensor"         "Hardware temperature monitor"          "$psensor_state"
            "timeshift"       "System restore snapshots"            "$timeshift_state"
        )
    fi

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "System Tools" "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $lista_alto \
        "${items[@]}" \
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
            extrepo)
                install_backports_or_stable extrepo
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
                    local de_type
                    de_type=$(_detect_desktop_type)
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
            fwupd)
                if ! is_installed "fwupd"; then
                    _run_cmd "fwupd" "sudo apt install -y fwupd" "Installing fwupd..."
                else
                    echo "fwupd already installed."
                fi
                if _confirm "Firmware Scan" "Scan for firmware updates now?\n\nThis will run:\n  fwupdmgr refresh\n  fwupdmgr get-updates\n  fwupdmgr update (if available)"; then
                    _run_cmd "fwupd" "sudo fwupdmgr refresh --force" "Refreshing firmware metadata..."
                    echo ""
                    echo "Checking for firmware updates..."
                    sudo fwupdmgr get-updates 2>&1 || true
                    if sudo fwupdmgr get-updates 2>&1 | grep -q "available"; then
                        if _confirm "Firmware Update" "Firmware updates are available.\nInstall them now?"; then
                            _run_cmd "fwupd" "sudo fwupdmgr update -y" "Installing firmware updates..."
                        else
                            echo "Skipping firmware update."
                            _pause
                        fi
                    else
                        echo "No firmware updates available."
                    _pause
                    fi
                fi
                echo -e "${GREEN}fwupd setup complete.${NC}"
                _pause
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
            nvme-cli)
                if ! lsblk -d -o TRAN 2>/dev/null | grep -q "^nvme$"; then
                    echo "No NVMe controller detected. Skipping."
                    continue
                fi
                if ! is_installed "nvme-cli"; then
                    _run_cmd "nvme-cli" "sudo apt install -y nvme-cli" "Installing nvme-cli..."
                fi
                local nvme_devs=()
                while read -r dev; do
                    nvme_devs+=("$dev")
                done < <(lsblk -d -o NAME,TRAN 2>/dev/null | awk '$2 == "nvme" {print $1}')
                if [ ${#nvme_devs[@]} -eq 0 ]; then
                    echo "No NVMe block devices found for health check."
                    continue
                fi
                local dev_list=""
                local dev
                for dev in "${nvme_devs[@]}"; do
                    [ -n "$dev_list" ] && dev_list+=", "
                    dev_list+="/dev/${dev}"
                done
                if _confirm "NVMe Health" "Run smart-log on ${#nvme_devs[@]} NVMe device(s): ${dev_list}?"; then
                    echo ""
                    for dev in "${nvme_devs[@]}"; do
                        local cw="" temp="" pu=""
                        while IFS= read -r line; do
                            case "$line" in
                                *critical_warning*) cw="${line##*: }" ;;
                                *temperature*)      temp="${line##*: }" ;;
                                *percentage_used*)  pu="${line##*: }" ;;
                            esac
                        done < <(sudo nvme smart-log "/dev/${dev}" 2>/dev/null || true)
                        echo -e "${YELLOW}━━━ /dev/${dev} ━━━${NC}"
                        echo -e "  ${GREEN}Critical Warning:${NC}  ${cw:-N/A}"
                        echo -e "  ${GREEN}Temperature:${NC}      ${temp:-N/A}"
                        echo -e "  ${GREEN}Percentage Used:${NC}   ${pu:-N/A}"
                        echo ""
                    done
                    _pause
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
    _pause
}

