#!/usr/bin/env bash
# Common utility functions for the post-install script

# ------------------
# Global variables
# ------------------
CPU_SUMMARY=""
RAM_SUMMARY=""
GPU_TYPE=""
GPU_DESC=""
INTEL_GPU_DEVICE_ID=""
NVIDIA_GPU_DEVICE_ID=""
WIFI_SUMMARY="Not detected"
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
# Debian version detection
# --------------------------------
detect_debian_version() {
    if ! command -v lsb_release &> /dev/null; then
        echo -e "${YELLOW}Installing lsb-release...${NC}"
        sudo apt update -qq && sudo apt install -y -qq lsb-release
    fi
    DEBIAN_CODENAME=$(lsb_release -cs)
    case "$DEBIAN_CODENAME" in
        bookworm) DEBIAN_VERSION="12" ;;
        trixie)   DEBIAN_VERSION="13" ;;
        *)
            echo -e "${RED}Unsupported Debian version: $DEBIAN_CODENAME. Only 12 (bookworm) and 13 (trixie) are supported.${NC}"
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
    RAM_GB=$((RAM_KB / 1024 / 1024))
    RAM_SUMMARY="${RAM_GB} GB"
}

get_cpu_summary() {
    echo "$CPU_SUMMARY"
}

get_ram_summary() {
    echo "$RAM_SUMMARY"
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
}

get_gpu_summary() {
    if [ -n "$GPU_DESC" ]; then
        echo "$GPU_DESC"
    else
        echo "Unknown/Rare"
    fi
}

# -------------------------------------
# WiFi chipset detection
# -------------------------------------
WIFI_SUMMARY="Not detected"
WIFI_CHIPSET=""
WIFI_DESC=""

detect_wifi_chipset() {
    local net_line
    net_line=$(lspci -nn | grep -i 'Network controller' | head -n1) || true
    if [ -z "$net_line" ]; then
        WIFI_SUMMARY="No WiFi adapter found"
        WIFI_CHIPSET=""
        WIFI_DESC=""
        return
    fi
    WIFI_CHIPSET="$net_line"
    WIFI_DESC=$(echo "$net_line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
    WIFI_SUMMARY="$WIFI_DESC"
}

get_wifi_summary() {
    echo "$WIFI_SUMMARY"
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
