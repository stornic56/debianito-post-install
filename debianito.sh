#!/usr/bin/env bash
# Debianito — simple configurator script
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# TUI dimensions — fixed centered size for whiptail dialogs
TUI_ALTO=20
TUI_ANCHO=78
TUI_ALTO_LISTA=10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"

source "${MODULES_DIR}/utils.sh"
source "${MODULES_DIR}/sudo_config.sh"
source "${MODULES_DIR}/repos.sh"
[ -f "${MODULES_DIR}/firmware.sh" ] && source "${MODULES_DIR}/firmware.sh"
[ -f "${MODULES_DIR}/gpu.sh" ]       && source "${MODULES_DIR}/gpu.sh"
[ -f "${MODULES_DIR}/kernel.sh" ]    && source "${MODULES_DIR}/kernel.sh"
[ -f "${MODULES_DIR}/gaming.sh" ]    && source "${MODULES_DIR}/gaming.sh"
[ -f "${MODULES_DIR}/extras.sh" ]    && source "${MODULES_DIR}/extras.sh"
[ -f "${MODULES_DIR}/zram.sh" ]      && source "${MODULES_DIR}/zram.sh"

REPOS_CONFIGURED=false
DEBIAN_VERSION=""
DEBIAN_CODENAME=""

main_menu() {
    # Auto-adjust TUI dimensions for small terminals
    if [ "$LINES" -lt $((TUI_ALTO + 6)) ] || [ "$COLUMNS" -lt $((TUI_ANCHO + 6)) ]; then
        TUI_ALTO=$((LINES - 4 > 8 ? LINES - 4 : 8))
        TUI_ANCHO=$((COLUMNS - 4 > 50 ? COLUMNS - 4 : 50))
        TUI_ALTO_LISTA=$((TUI_ALTO - 10 > 4 ? TUI_ALTO - 10 : 4))
    fi

    while true; do
        local choice
        choice=$(whiptail --title "DEBIANITO — simple configurator script" --menu "" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "System Info" \
            "2" "User Privileges & Feedback" \
            "3" "Configure repositories" \
            "4" "Wireless & Firmware" \
            "5" "Graphics Stack" \
            "6" "Backports Kernel" \
            "7" "Gaming Setup" \
            "8" "ZRAM (Swap)" \
            "9" "Install Programs and Software" \
            "10" "Exit" \
            3>&1 1>&2 2>&3)

        clear

        case "$choice" in
            1)  _show_sysinfo ;;
            2)  config_sudo || true ;;
            3)  configure_repos || true ;;
            4)  install_firmware || true ;;
            5)  install_gpu_drivers || true ;;
            6)  install_kernel_backports || true ;;
            7)  install_gaming || true ;;
            8)  install_zram || true ;;
            9)  install_extras || true ;;
            10) echo "Exiting."; exit 0 ;;
        esac
    done
}

_show_sysinfo() {
    local gpu_info="${GPU_DESC}"
    [ -n "$GPU_VERSION" ] && gpu_info+=" (${GPU_VERSION})"

    local network_info
    if [ -n "$ETH_DESC" ] && [ -n "$WIFI_DESC" ]; then
        network_info="Ethernet: ${ETH_DESC}\nWiFi: ${WIFI_DESC}"
    elif [ -n "$ETH_DESC" ]; then
        network_info="${ETH_DESC}"
    elif [ -n "$WIFI_DESC" ]; then
        network_info="${WIFI_DESC}"
    else
        network_info="No adapters detected"
    fi

    _msg "System Information" \
        "Debian:   ${DEBIAN_VERSION} (${DEBIAN_CODENAME})
Kernel:   ${KERNEL_VERSION}
CPU:      $(get_cpu_summary)
RAM:      $(get_ram_summary)
GPU:      ${gpu_info}
Network:  ${network_info}" 13 65
}

check_root
check_sudo
check_system_time

detect_debian_version
detect_cpu_ram
detect_kernel
detect_gpu
detect_network

main_menu
