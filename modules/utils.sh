#!/usr/bin/env bash
# Common utility functions for the post-install script

# ------------------
# Global variables
# ------------------
readonly SCROLL_HINT="  [↑↓]"
CPU_SUMMARY=""
RAM_SUMMARY=""
GPU_TYPE=""
GPU_DESC=""
GPU_VERSION=""
INTEL_GPU_DEVICE_ID=""
NVIDIA_GPU_DEVICE_ID=""
HAS_NVIDIA=false
HAS_AMD=false
HAS_INTEL=false
KERNEL_VERSION=""
DISPLAY_SERVER="unknown"
STORAGE_SUMMARY=""
WIFI_CHIPSET=""
DESKTOP_ENV=""
AUDIO_SERVER=""

# --------------------------
# Pre-flight checks
# --------------------------
check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${RED}Do not run this script as root. Use a normal user with sudo.${NC}"
        exit 1
    fi
}

check_sudo() {
    if ! sudo -v; then
        echo -e "${RED}This script requires sudo privileges.${NC}"
        exit 1
    fi
}

# --------------------------------
# Time sync detection + NTP
# --------------------------------
check_system_time() {
    command -v timedatectl &>/dev/null || return

    local year
    year=$(date +%Y)

    if [ "$year" -lt 2025 ]; then
        local msg="System date/time appears to be incorrect\n"
        msg+="($(date '+%Y-%m-%d %H:%M')). This will prevent Debian\n"
        msg+="repositories from working properly.\n\n"
        msg+="Attempt automatic NTP synchronization?\n"
        msg+="(requires network access and timedatectl)"
        if _confirm "System Date" "$msg"; then
            sync_system_time
        else
            echo -e "${YELLOW}Warning: System time is incorrect. Package installations may fail.${NC}"
        fi
        return
    fi

    local ntp_active
    ntp_active=$(timedatectl show --property=NTP --value 2>/dev/null || echo "no")
    if [ "$ntp_active" != "yes" ]; then
        sync_system_time
    fi
}

sync_system_time() {
    command -v timedatectl &>/dev/null || return

    if ! is_installed systemd-timesyncd; then
        sudo DEBIAN_FRONTEND=noninteractive apt install -y systemd-timesyncd || true
    fi

    if ! systemctl is-enabled systemd-timesyncd &>/dev/null; then
        sudo systemctl enable systemd-timesyncd || true
    fi
    if ! systemctl is-active systemd-timesyncd &>/dev/null; then
        sudo systemctl start systemd-timesyncd || true
    fi

    sudo timedatectl set-ntp true || true
    sleep 4

    if timedatectl show --property=NTPSynchronized --value 2>/dev/null | grep -q yes; then
        echo -e "${GREEN}Time synchronized: $(date '+%Y-%m-%d %H:%M')${NC}"
    else
        echo -e "${YELLOW}NTP sync did not complete.${NC}"
    fi
}

# --------------------------------
# Debian version detection
# --------------------------------
detect_debian_version() {
    if ! command -v lsb_release &> /dev/null; then
        if [ -f /etc/os-release ]; then
            DEBIAN_CODENAME=$(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release 2>/dev/null || echo "")
        fi
        if [ -z "$DEBIAN_CODENAME" ]; then
            sync_system_time || true
            sudo apt update -qq 2>/dev/null && sudo apt install -y -qq lsb-release || true
        fi
    fi
    if [ -z "$DEBIAN_CODENAME" ]; then
        DEBIAN_CODENAME=$(lsb_release -cs 2>/dev/null || echo "")
    fi
    case "$DEBIAN_CODENAME" in
        bullseye) DEBIAN_VERSION="11" ;;
        bookworm) DEBIAN_VERSION="12" ;;
        trixie)   DEBIAN_VERSION="13" ;;
        *)
            echo -e "${RED}Unsupported Debian version: '$DEBIAN_CODENAME'. Only 11 (bullseye), 12 (bookworm) and 13 (trixie) are supported.${NC}"
            exit 1
            ;;
    esac
}

# ----------------------------------
# CPU and RAM info (cosmetic)
# ----------------------------------
detect_cpu_ram() {
    CPU_SUMMARY=$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')
    RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    RAM_GB=$(awk -v kb="$RAM_KB" 'BEGIN { printf "%.2f", kb / 1048576 }')
    RAM_SUMMARY="${RAM_GB} GB"
}

get_cpu_summary() {
    echo "$CPU_SUMMARY"
}

get_ram_summary() {
    echo "$RAM_SUMMARY"
}

# ----------------------------------
# Check if running backports kernel
# ----------------------------------
is_backports_kernel() {
    local kver
    kver=$(uname -r)
    if echo "$kver" | grep -q 'bpo'; then
        echo true
    else
        echo false
    fi
}

# ----------------------------------
# Package installed check
# ----------------------------------
is_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q '^ii'
}

_inst() {
    if is_installed "$1"; then echo " *"; else echo ""; fi
}

_state() {
    is_installed "$1" && echo "ON" || echo "OFF"
}

# ----------------------------------
# Package version lookup
# ----------------------------------
pkg_versions() {
    local result=""
    for pkg in "$@"; do
        local ver
        ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if [ -n "$ver" ] && [ "$ver" != "(none)" ]; then
            result+="  - ${pkg}  ${ver}\n"
        else
            result+="  - ${pkg}\n"
        fi
    done
    echo -e "$result"
}

# ----------------------------------
# Kernel version
# ----------------------------------
detect_kernel() {
    KERNEL_VERSION=$(uname -r)
}

# ----------------------------------
# GPU detection
# ----------------------------------
detect_gpu() {
    local gpu_lines
    gpu_lines=$(lspci -nn | grep -E "VGA|3D") || true
    if [ -z "$gpu_lines" ]; then
        GPU_TYPE="unknown"
        GPU_DESC="No GPU detected"
        return
    fi

    local has_nvidia=false has_amd=false has_intel=false
    local desc_lines="" nvidia_dev_id="" intel_dev_id=""

    while IFS= read -r line; do
        local desc
        desc=$(echo "$line" | sed -E 's/.*: //; s/ *\(rev.*//')
        [ -n "$desc_lines" ] && desc_lines+=" + "
        desc_lines+="$desc"

        if echo "$line" | grep -qi "nvidia"; then
            has_nvidia=true
            [ -z "$nvidia_dev_id" ] && nvidia_dev_id=$(echo "$line" | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
        elif echo "$line" | grep -qi "amd"; then
            has_amd=true
        elif echo "$line" | grep -qi "intel"; then
            has_intel=true
            [ -z "$intel_dev_id" ] && intel_dev_id=$(echo "$line" | grep -oP '8086:\K[0-9a-fA-F]+' | head -n1)
        fi
    done <<< "$gpu_lines"

    GPU_DESC="$desc_lines"
    HAS_NVIDIA=$has_nvidia
    HAS_AMD=$has_amd
    HAS_INTEL=$has_intel

    if $has_nvidia; then
        GPU_TYPE="nvidia"
        [ -n "$nvidia_dev_id" ] && NVIDIA_GPU_DEVICE_ID="$nvidia_dev_id"
    elif $has_amd; then
        GPU_TYPE="amd"
    elif $has_intel; then
        GPU_TYPE="intel"
        if [ -n "$intel_dev_id" ]; then
            INTEL_GPU_DEVICE_ID="0x${intel_dev_id,,}"
        fi
    else
        GPU_TYPE="unknown"
    fi

    if [ "$GPU_TYPE" = "nvidia" ]; then
        local nv_ver
        nv_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
        if [ -z "$nv_ver" ]; then
            nv_ver=$(dpkg -l nvidia-driver 2>/dev/null | awk '/^ii/ {print $3}' | sed 's/-.*//')
        fi
        [ -n "$nv_ver" ] && GPU_VERSION="NVIDIA $nv_ver"
    fi

    if [ -z "$GPU_VERSION" ]; then
        local mesa_ver
        mesa_ver=$(dpkg -l libgl1-mesa-dri 2>/dev/null | awk '/^ii/ {print $3; exit}' | sed 's/-.*//')
        [ -n "$mesa_ver" ] && GPU_VERSION="Mesa $mesa_ver"
    fi
}

get_gpu_summary() {
    if [ -n "$GPU_DESC" ]; then
        echo "$GPU_DESC"
    else
        echo "Unknown/Rare"
    fi
}

# -------------------------------------
# Network adapter detection
# -------------------------------------
WIFI_CHIPSET=""
WIFI_DESC=""
ETH_DESC=""

declare -a ETH_NAMES=()
declare -a ETH_DESCS=()
declare -a ETH_STATES=()
declare -a ETH_IPS=()

declare -a WIFI_NAMES=()
declare -a WIFI_DESCS=()
declare -a WIFI_STATES=()
declare -a WIFI_IPS=()
declare -a WIFI_SSIDS=()

detect_network() {
    local eth_line
    eth_line=$(lspci -nn | grep -i 'Ethernet controller' | head -n1) || true
    if [ -n "$eth_line" ]; then
        ETH_DESC=$(echo "$eth_line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
    fi

    local wifi_line
    # Layer 1: grep by PCI class description text
    wifi_line=$(lspci -nn 2>/dev/null | grep -iE 'network controller|wireless|wi-fi|wlan|802\.11' | head -n1) || true
    # Layer 2: grep by exact PCI class code 0x0280 (Network controller)
    if [ -z "$wifi_line" ]; then
        wifi_line=$(lspci -d ::0280 2>/dev/null | head -n1) || true
    fi
    # Layer 3: Broadcom vendor ID fallback (14e4)
    if [ -z "$wifi_line" ]; then
        wifi_line=$(lspci -nn 2>/dev/null | grep -i '14e4:' | head -n1) || true
    fi
    if [ -n "$wifi_line" ]; then
        WIFI_CHIPSET="$wifi_line"
        WIFI_DESC=$(echo "$wifi_line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
    fi
    # Layer 4: USB WiFi adapter (no PCI device)
    if [ -z "$wifi_line" ] && command -v lsusb &>/dev/null; then
        local usb_wifi
        usb_wifi=$(lsusb 2>/dev/null | grep -iE 'wireless|wifi|wlan|802\.11' | head -n1) || true
        if [ -n "$usb_wifi" ]; then
            WIFI_CHIPSET="$usb_wifi"
            WIFI_DESC=$(echo "$usb_wifi" | sed 's/^.*ID //')
        fi
    fi

    # ── Safeguard: if ip is not installed, skip runtime parsing ──
    if ! command -v ip &>/dev/null; then
        return
    fi

    local iface state ip4 ssid

    while IFS= read -r line; do
        iface=$(echo "$line" | awk -F': ' '{print $2}' | sed 's/@.*//')
        state=$(echo "$line" | awk '{print $9}')
        case "$iface" in
            eth*|enp*|ens*|enx*|eno*)
                ip4=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}')
                ETH_NAMES+=("$iface")
                ETH_STATES+=("$state")
                ETH_IPS+=("${ip4:-}")
                ETH_DESCS+=("${ETH_DESC:-}")
                ;;
            wl*|wlp*|wlo*|wlan*)
                ip4=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}')
                ssid=""
                [ "$state" = "UP" ] && ssid=$(iwgetid -r "$iface" 2>/dev/null || true)
                WIFI_NAMES+=("$iface")
                WIFI_STATES+=("$state")
                WIFI_IPS+=("${ip4:-}")
                WIFI_SSIDS+=("${ssid:-}")
                WIFI_DESCS+=("${WIFI_DESC:-}")
                ;;
        esac
    done < <(ip -o link show 2>/dev/null)
}

# ---------------------------------------
# Display Server detection (Wayland / X11 / tty)
# ---------------------------------------
detect_displayserver() {
    local st="${XDG_SESSION_TYPE:-}"
    case "$st" in
        wayland) DISPLAY_SERVER="Wayland" ;;
        x11)     DISPLAY_SERVER="X11" ;;
        tty)     DISPLAY_SERVER="none (tty)" ;;
        *)
            if [ -n "${WAYLAND_DISPLAY:-}" ]; then
                DISPLAY_SERVER="Wayland"
            elif [ -n "${DISPLAY:-}" ]; then
                DISPLAY_SERVER="X11"
            else
                DISPLAY_SERVER="unknown"
            fi
            ;;
    esac
}

# ---------------------------------------
# Storage summary via lsblk (NVMe / SSD / HDD / USB-SD)
# ---------------------------------------
detect_storage() {
    local parts=()
    local name size rota type rm

    while read -r name size rota type; do
        [ "$name" = "NAME" ] && continue
        echo "$name" | grep -q "zram" && continue
        [ "$type" = "loop" ] || [ "$type" = "rom" ] && continue

        if echo "$name" | grep -q "nvme"; then
            type="NVMe"
        elif [ "$rota" = "1" ]; then
            type="HDD"
        else
            rm=$(cat /sys/block/"$name"/removable 2>/dev/null || echo 0)
            if [ "$rm" = "1" ]; then
                type="USB/SD"
            else
                type="SSD"
            fi
        fi
        parts+=("${size} ${type}")
    done < <(lsblk -d -o NAME,SIZE,ROTA,TYPE -e 7,11 2>/dev/null || true)

    if [ ${#parts[@]} -eq 0 ]; then
        STORAGE_SUMMARY="No disks detected"
        return
    fi

    local result=""
    local p
    for p in "${parts[@]}"; do
        [ -n "$result" ] && result+=" + "
        result+="$p"
    done
    STORAGE_SUMMARY="$result"
}

# ---------------------------------------
# Desktop environment detection
# ---------------------------------------
detect_desktop_environment() {
    case "${XDG_CURRENT_DESKTOP:-}" in
        *GNOME*) DESKTOP_ENV="gnome" ;;
        *KDE*)   DESKTOP_ENV="kde" ;;
        *XFCE*)  DESKTOP_ENV="xfce" ;;
        *)       DESKTOP_ENV="other" ;;
    esac
}

# ---------------------------------------
# Audio server detection (PipeWire / PulseAudio)
# ---------------------------------------
detect_audio_server() {
    if command -v pw-cli &>/dev/null && pw-cli info &>/dev/null 2>&1; then
        AUDIO_SERVER="pipewire"
    elif command -v pactl &>/dev/null; then
        AUDIO_SERVER="pulseaudio"
    else
        AUDIO_SERVER="none"
    fi
}

# ---------------------------------------
# Intel HD Graphics generation detection
# ---------------------------------------
# Returns "gen7-" if Device ID < 0x1600, else "gen8+"
get_intel_generation() {
    if [ -z "$INTEL_GPU_DEVICE_ID" ]; then
        # fallback: assume gen8+
        echo "gen8+"
        return
    fi
    local dev_int
    dev_int=$(printf "%d" "$INTEL_GPU_DEVICE_ID")
    if [ "$dev_int" -lt 5632 ]; then  # 0x1600 = 5632
        echo "gen7-"
    else
        echo "gen8+"
    fi
}

# ----------------------------------------------------------------------
# Check if backports repository is enabled (active line without #)
# ----------------------------------------------------------------------
is_backports_enabled() {
    local codename="${DEBIAN_CODENAME:-}"
    [ -z "$codename" ] && { echo false; return; }

    local c_pattern="^[^#]*${codename}-backports[[:space:]]+"
    local d_pattern="Suites:.*${codename}-backports"

    # Classic embedded (sources.list)
    if [ -f /etc/apt/sources.list ] && grep -Eq "$c_pattern" /etc/apt/sources.list 2>/dev/null; then
        echo true; return
    fi

    # Classic standalone (new — debian-backports.list)
    if [ -f /etc/apt/sources.list.d/debian-backports.list ] && \
       grep -Eq "$c_pattern" /etc/apt/sources.list.d/debian-backports.list 2>/dev/null; then
        echo true; return
    fi

    # Deb822 any .sources file
    if grep -qr "$d_pattern" /etc/apt/sources.list.d/*.sources 2>/dev/null; then
        echo true; return
    fi

    echo false
}


install_backports_or_stable() {
    local pkg="$1"
    local pkg_desc="${2:-$pkg}"

    local bpo_ver=""
    if [ "$(is_backports_enabled)" == true ]; then
        bpo_ver=$(apt-cache madison "$pkg" 2>/dev/null | \
            grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    fi

    if is_installed "$pkg"; then
        if [ -n "$bpo_ver" ]; then
            local current_ver
            current_ver=$(dpkg -l "$pkg" 2>/dev/null | awk '/^ii/{print $3}')
            if _confirm "Backports: ${pkg}" \
                "${pkg} ${current_ver} installed.\nUpgrade to backports ${bpo_ver}?"; then
                _run_cmd "Backports" \
                    "sudo DEBIAN_FRONTEND=noninteractive apt install -y -t ${DEBIAN_CODENAME}-backports $pkg" \
                    "Upgrading $pkg..."
                return
            fi
        fi
        echo "$pkg already installed."
        return
    fi

    if [ -n "$bpo_ver" ]; then
        local stable_ver
        stable_ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if _confirm_custom "${pkg}" "Install ${pkg_desc}?\n\n  Backports: ${bpo_ver} (newer, recommended for gaming/newer HW)\n  Stable:    ${stable_ver:-N/A}\n\nChoose version:" "Backports" "Stable"; then
            _run_cmd "Backports" \
                "sudo DEBIAN_FRONTEND=noninteractive apt install -y -t ${DEBIAN_CODENAME}-backports $pkg" \
                "Installing $pkg from backports..."
            return
        fi
        _run_cmd "APT" "sudo DEBIAN_FRONTEND=noninteractive apt install -y $pkg" "Installing $pkg from stable..."
        return
    fi
    local stable_ver
    stable_ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
    if _confirm "Install: ${pkg}" "Install ${pkg} ${stable_ver:-}?"; then
        _run_cmd "APT" "sudo DEBIAN_FRONTEND=noninteractive apt install -y $pkg" "Installing $pkg..."
    fi
}

# ----------------------------------------------------------------------
# Whiptail helpers (4-block pattern)
# ----------------------------------------------------------------------

_confirm() {
    whiptail --title "$1" --yes-button "Yes" --no-button "No" \
        --yesno "$2" "${3:-10}" "${4:-65}"
}

_confirm_custom() {
    local title="$1" text="$2" yes_btn="$3" no_btn="$4"
    shift 4
    local height="${1:-20}"
    local width="${2:-78}"
    whiptail --title "$title" --yes-button "$yes_btn" --no-button "$no_btn" \
        --yesno "$text" "$height" "$width"
}

_msg() {
    whiptail --title "$1" --msgbox "$2" "${3:-10}" "${4:-65}" || true
}

_msg_red() {
    whiptail --colors --title "\Z1$1\Zn" --msgbox "\Z1$2\Zn" "${3:-12}" "${4:-70}" || true
}

_menu() {
    local title="$1" text="$2" h="$3" w="$4" lh="$5"; shift 5
    whiptail --title "$title" --menu "$text" "$h" "$w" "$lh" "$@" 3>&1 1>&2 2>&3 || true
}

_checklist() {
    local title="$1" text="$2" h="$3" w="$4" lh="$5"; shift 5
    whiptail --title "$title" --checklist "$text" "$h" "$w" "$lh" "$@" 3>&1 1>&2 2>&3 || true
}

_inputbox() {
    whiptail --title "$1" --inputbox "$2" "${3:-10}" "${4:-60}" "${5:-}" 3>&1 1>&2 2>&3 || true
}

_validate_sudoers() {
    local content="$1" dest="$2"
    local tmpfile
    tmpfile=$(mktemp) || return 1
    echo "$content" > "$tmpfile"
    if ! visudo -cf "$tmpfile" &>/dev/null; then
        local err
        err=$(visudo -cf "$tmpfile" 2>&1 || true)
        rm -f "$tmpfile"
        _msg "Sudoers Error" "Invalid sudoers syntax in:\n\n${err}\n\nFile was NOT written.\nThis prevents broken sudo access." 12 70
        return 1
    fi
    sudo cp "$tmpfile" "$dest"
    sudo chmod 0440 "$dest"
    rm -f "$tmpfile"
}

_pause() {
    local msg="${1:-Presiona OK para continuar.}"
    whiptail --title "Continuar" --msgbox "$msg" 8 50 3>&1 1>&2 2>&3 || true
}

# Blocks 2-4: clear → run → pause
_run_cmd() {
    local title="$1" command="$2" success_msg="${3:-Running...}"
    clear
    echo -e "${GREEN}[+]${NC} $success_msg"
    echo "──────────────────────────────────────────────"
    bash -c "$command"
    local rc=$?
    echo "──────────────────────────────────────────────"
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}[+]${NC} Done."
    else
        echo -e "${RED}[-]${NC} Failed (exit code: $rc)."
    fi
    _pause
}

# Blocks 1-4: confirm → clear → run → pause
_run() {
    if _confirm "$1" "$2"; then
        _run_cmd "$1" "$3" "$4"
    fi
}

_is_headless() {
    [ -z "${DISPLAY:-}" ] && [ -z "${WAYLAND_DISPLAY:-}" ]
}

_run_install() {
    local pkg="$1"
    local ver
    ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
    [ -z "$ver" ] && ver="(version unknown)"
    if _confirm "Install: ${pkg}" "Install ${pkg}\nVersion: ${ver}?"; then
        _run_cmd "Install" "sudo DEBIAN_FRONTEND=noninteractive apt install -y $pkg" "Installing $pkg..."
    fi
}

_run_install_batch() {
    local pkgs=("$@")
    [ ${#pkgs[@]} -eq 0 ] && return 0
    local ver_list=""
    for pkg in "${pkgs[@]}"; do
        local ver
        ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
        ver_list+="  - ${pkg}  ${ver:-unknown}\n"
    done
    if _confirm "Install" "Install these packages?\n${ver_list}"; then
        _run_cmd "Install" "sudo DEBIAN_FRONTEND=noninteractive apt install -y ${pkgs[*]}" "Installing..."
    fi
}

_run_install_pkg() {
    local pkg="$1"
    local ver
    ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
    [ -z "$ver" ] && ver="(unknown)"
    if _confirm "Install: ${pkg}" "Package: ${pkg}\nVersion: ${ver}\n\nProceed with installation?"; then
        _run_cmd "Install" "sudo DEBIAN_FRONTEND=noninteractive apt install -y $pkg" "Installing $pkg..."
    fi
}

get_backports_kernel_version() {
    local ver
    ver=$(apt-cache policy linux-image-amd64 2>/dev/null | \
          grep -E '^[[:space:]]+[0-9]+\.[0-9]+\.[0-9]+.*~bpo' | head -n1 | awk '{print $1}')
    if [ -n "$ver" ]; then
        echo "$ver"
    else
        echo "unknown"
    fi
}

# ----------------------------------
# Language helpers
# ----------------------------------
_detect_lang() {
    local sys_lang
    sys_lang=$(echo "${LANG:-en}" | cut -c1-2 | tr '[:upper:]' '[:lower:]')
    echo "$sys_lang"
}

_detect_lang_pkg() {
    local base="$1"
    local lang2
    lang2=$(_detect_lang)

    [ "$lang2" = "en" ] && echo "" && return

    local full="${LANG%%.*}"
    local hyphenated_full
    hyphenated_full=$(echo "$full" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    local pkg

    pkg=$(apt-cache search "^${base}-${hyphenated_full}$" 2>/dev/null | awk 'NR==1{print $1}')
    [ -z "$pkg" ] && pkg=$(apt-cache search "^${base}-${lang2}$" 2>/dev/null | awk 'NR==1{print $1}')
    [ -z "$pkg" ] && pkg=$(apt-cache search "^${base}-all$" 2>/dev/null | awk 'NR==1{print $1}')

    echo "$pkg"
}

# ----------------------------------
# Network connectivity check
# ----------------------------------
_check_network() {
    local target="${1:-deb.debian.org}"

    if command -v ping &>/dev/null; then
        ping -c 1 -W 3 "$target" &>/dev/null && return 0
    fi

    if command -v wget &>/dev/null; then
        wget -q --timeout=5 --spider "http://${target}" &>/dev/null && return 0
    fi

    if command -v curl &>/dev/null; then
        curl -s --connect-timeout 5 -o /dev/null "http://${target}" &>/dev/null && return 0
    fi

    return 1
}

# ----------------------------------
# LightDM configuration
# ----------------------------------
 _configure_lightdm() {
    command -v lightdm &>/dev/null || return 0

    if _confirm "LightDM" "Configure LightDM to show the user list on the login screen?\n\nThis disables greeter-hide-users."; then
        if ! is_installed lightdm-gtk-greeter-settings; then
            echo -e "${YELLOW}Installing lightdm-gtk-greeter-settings...${NC}"
            sudo DEBIAN_FRONTEND=noninteractive apt install -y lightdm-gtk-greeter-settings
        fi

        local conf_dir="/etc/lightdm/lightdm.conf.d"
        local conf_file="${conf_dir}/99-show-users.conf"

        if [ -f "$conf_file" ] && grep -q '^greeter-hide-users=false' "$conf_file"; then
            return
        fi

        sudo mkdir -p "$conf_dir"
        printf '[Seat:*]\ngreeter-hide-users=false\n' | sudo tee "$conf_file" > /dev/null
        echo -e "${GREEN}LightDM configured to show user list.${NC}"
    fi
}

# ── Lazy system state refresh ──
refresh_system_state() {
    detect_debian_version
    detect_gpu
    detect_cpu_ram
}
