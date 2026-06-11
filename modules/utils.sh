#!/usr/bin/env bash
# Common utility functions for the post-install script

# ------------------
# Global variables
# ------------------
CPU_SUMMARY=""
RAM_SUMMARY=""
GPU_TYPE=""
GPU_DESC=""
GPU_VERSION=""
INTEL_GPU_DEVICE_ID=""
NVIDIA_GPU_DEVICE_ID=""
KERNEL_VERSION=""
WIFI_CHIPSET=""

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
    if ! command -v timedatectl &> /dev/null; then
        return
    fi
    local year
    year=$(date +%Y)
    if [ "$year" -lt 2026 ]; then
        local msg="Se ha detectado que la fecha/hora de su sistema está desconfigurada\n"
        msg+="($(date '+%Y-%m-%d %H:%M')), lo que impedirá que los repositorios\n"
        msg+="de Debian funcionen correctamente.\n\n"
        msg+="¿Desea que el script intente sincronizar la hora automáticamente\n"
        msg+="mediante la red (NTP) y configurar timedatectl?"
        if _confirm "System Date" "$msg"; then
            sync_system_time
            local new_year
            new_year=$(date +%Y)
            if [ "$new_year" -ge 2026 ]; then
                echo -e "${GREEN}Time synced: $(date '+%Y-%m-%d %H:%M')${NC}"
            else
                echo -e "${RED}Could not sync time automatically.${NC}"
                echo "You may need to set it manually: sudo date --set \"YYYY-MM-DD HH:MM:SS\""
            fi
        else
            echo -e "${YELLOW}Warning: System time is incorrect. Package installations may fail.${NC}"
        fi
    fi
}

sync_system_time() {
    if command -v timedatectl &> /dev/null; then
        local ntp_active
        ntp_active=$(timedatectl show --property=NTP --value 2>/dev/null || echo "no")
        if [ "$ntp_active" != "yes" ]; then
            echo -e "${YELLOW}NTP not active. Attempting to enable time sync...${NC}"
            sudo timedatectl set-ntp true 2>/dev/null || true
            sleep 4
        fi
    elif command -v hwclock &> /dev/null && command -v ntpd &> /dev/null; then
        sudo hwclock --hctosys 2>/dev/null || true
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
            echo -e "${YELLOW}Installing lsb-release...${NC}"
            sync_system_time
            sudo apt update -qq 2>/dev/null && sudo apt install -y -qq lsb-release
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
    local gpu_line
    gpu_line=$(lspci -nn | grep -E "VGA|3D" | head -n1) || true
    if [ -z "$gpu_line" ]; then
        GPU_TYPE="unknown"
        GPU_DESC="No GPU detected"
        return
    fi


    GPU_DESC=$(echo "$gpu_line" | sed -E 's/.*: //; s/ *\(rev.*//')

    if echo "$gpu_line" | grep -qi "AMD"; then
        GPU_TYPE="amd"
    elif echo "$gpu_line" | grep -qi "Intel"; then
        GPU_TYPE="intel"
        INTEL_GPU_DEVICE_ID=$(echo "$gpu_line" | grep -oP '8086:\K[0-9a-fA-F]+' | head -n1)
        if [ -n "$INTEL_GPU_DEVICE_ID" ]; then
            INTEL_GPU_DEVICE_ID="0x${INTEL_GPU_DEVICE_ID,,}"
        fi
    elif echo "$gpu_line" | grep -qi "NVIDIA"; then
        GPU_TYPE="nvidia"
        NVIDIA_GPU_DEVICE_ID=$(echo "$gpu_line" | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
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

detect_network() {
    local eth_line
    eth_line=$(lspci -nn | grep -i 'Ethernet controller' | head -n1) || true
    if [ -n "$eth_line" ]; then
        ETH_DESC=$(echo "$eth_line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
    fi

    local wifi_line
    wifi_line=$(lspci -nn | grep -i 'Network controller' | head -n1) || true
    if [ -n "$wifi_line" ]; then
        WIFI_CHIPSET="$wifi_line"
        WIFI_DESC=$(echo "$wifi_line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
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
    # Check classic sources.list
    if [ -f /etc/apt/sources.list ]; then
        if grep -Eq '^[^#]*[ \t]+bookworm-backports[ \t]+' /etc/apt/sources.list 2>/dev/null; then
            echo true
            return
        fi
        if grep -Eq '^[^#]*[ \t]+trixie-backports[ \t]+' /etc/apt/sources.list 2>/dev/null; then
            echo true
            return
        fi
    fi

    # Check deb822 .sources files
    if [ -d /etc/apt/sources.list.d ]; then
        if grep -qr 'Suites:.*-backports' /etc/apt/sources.list.d/*.sources 2>/dev/null; then
            echo true
            return
        fi
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
    whiptail --title "$1" --msgbox "$2" "${3:-10}" "${4:-65}"
}

# Blocks 2-4: clear → run → pause
_run_cmd() {
    local title="$1" command="$2" success_msg="${3:-Running...}"
    clear
    echo -e "${GREEN}[+]${NC} $success_msg"
    echo "──────────────────────────────────────────────"
    eval "$command"
    local rc=$?
    echo "──────────────────────────────────────────────"
    if [ $rc -eq 0 ]; then
        echo -e "${GREEN}[+]${NC} Done."
    else
        echo -e "${RED}[-]${NC} Failed (exit code: $rc)."
    fi
    echo "Press [ENTER] to continue..."
    read -r
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
