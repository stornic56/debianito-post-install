#!/usr/bin/env bash
# Debianito
set -euo pipefail


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# -------------------
# Load modules
# -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"

source "${MODULES_DIR}/utils.sh"
source "${MODULES_DIR}/sudo_config.sh"
source "${MODULES_DIR}/repos.sh"
if [ -f "${MODULES_DIR}/firmware.sh" ]; then
    source "${MODULES_DIR}/firmware.sh"
fi
if [ -f "${MODULES_DIR}/gpu.sh" ]; then
    source "${MODULES_DIR}/gpu.sh"
fi
if [ -f "${MODULES_DIR}/kernel.sh" ]; then
    source "${MODULES_DIR}/kernel.sh"
fi
if [ -f "${MODULES_DIR}/gaming.sh" ]; then
    source "${MODULES_DIR}/gaming.sh"
fi
if [ -f "${MODULES_DIR}/extras.sh" ]; then
    source "${MODULES_DIR}/extras.sh"
fi

# --------------------------
# Global state
# --------------------------
REPOS_CONFIGURED=false
DEBIAN_VERSION=""
DEBIAN_CODENAME=""

# ---------------------------------
# menu
# ---------------------------------

if ! echo "╔" | grep -q "t"; then
    BOX_DRAWING=false
else
    BOX_DRAWING=true
fi

main_menu() {
    PS3="Select an option (1-8): "
    options=(
        "User Privileges & Feedback"
        "Configure repositories"
        "Setup Wireless & Firmware"
        "Configure Graphics Stack and Tools"
        "Update Kernel to Backports"
        "Gaming Setup"
        "Install extra applications"
        "Exit"
    )

    while true; do
        echo ""
        printf "${RED}╔═══════════════════════════════╗\n" >&2
        printf "║          DEBIANITO            ║\n" >&2
        printf "║   Debian Post-Install Setup   ║\n" >&2
        printf "╚═══════════════════════════════╝\n${NC}" >&2

        echo -e "\033[1;97m║─────────── SYSTEM INFO ─────┤\n${NC}\033[0m"
        echo "Detected: Debian ${DEBIAN_VERSION} (${DEBIAN_CODENAME})"
        echo "Kernel: ${KERNEL_VERSION}"
        echo "CPU: $(get_cpu_summary)"
        echo "RAM: $(get_ram_summary)"
        if [ -n "$GPU_VERSION" ]; then
            echo "GPU: ${GPU_DESC} (${GPU_VERSION})"
        else
            echo "GPU: ${GPU_DESC}"
        fi
        if [ -n "$ETH_DESC" ] && [ -n "$WIFI_DESC" ]; then
            echo "Network:"
            echo "  Ethernet: ${ETH_DESC}"
            echo "  WiFi: ${WIFI_DESC}"
        elif [ -n "$ETH_DESC" ]; then
            echo "Network: ${ETH_DESC}"
        elif [ -n "$WIFI_DESC" ]; then
            echo "Network: ${WIFI_DESC}"
        else
            echo "Network: No adapters detected"
        fi
        echo ""

        select opt in "${options[@]}"; do
            case $REPLY in
                1) config_sudo ;;
                2) configure_repos ;;
                3) install_firmware ;;
                4) install_gpu_drivers ;;
                5) install_kernel_backports ;;
                6) install_gaming ;;
                7) install_extras ;;
                8) echo "Exiting."; exit 0 ;;
                *) echo "Invalid choice. Please try again." ;;
            esac
            break
        done
    done
}

# ----------------
# Pre-run checks
# ----------------
check_root
check_sudo

detect_debian_version
detect_cpu_ram
detect_kernel
detect_gpu
detect_network

main_menu
