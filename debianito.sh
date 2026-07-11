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
[ -f "${MODULES_DIR}/sysinfo.sh" ]   && source "${MODULES_DIR}/sysinfo.sh"
source "${MODULES_DIR}/sudo_config.sh"
source "${MODULES_DIR}/repos/repo_detect.sh"
source "${MODULES_DIR}/repos.sh"
[ -f "${MODULES_DIR}/firmware.sh" ]  && source "${MODULES_DIR}/firmware.sh"
[ -f "${MODULES_DIR}/bluetooth.sh" ] && source "${MODULES_DIR}/bluetooth.sh"
[ -f "${MODULES_DIR}/gpu.sh" ]       && source "${MODULES_DIR}/gpu.sh"
[ -f "${MODULES_DIR}/kernel.sh" ]    && source "${MODULES_DIR}/kernel.sh"
[ -f "${MODULES_DIR}/gaming.sh" ]    && source "${MODULES_DIR}/gaming.sh"
[ -f "${MODULES_DIR}/extras.sh" ]    && source "${MODULES_DIR}/extras.sh"
[ -f "${MODULES_DIR}/zram.sh" ]      && source "${MODULES_DIR}/zram.sh"
[ -f "${MODULES_DIR}/extras/java.sh" ] && source "${MODULES_DIR}/extras/java.sh"
[ -f "${MODULES_DIR}/rescue.sh" ]    && source "${MODULES_DIR}/rescue.sh"
[ -f "${MODULES_DIR}/swap.sh" ]     && source "${MODULES_DIR}/swap.sh"

# ── Bullseye-specific modules (loaded only on Debian 11) ──
if [ -d "${MODULES_DIR}/bullseye" ]; then
    [ -f "${MODULES_DIR}/bullseye/legacy.sh" ] && source "${MODULES_DIR}/bullseye/legacy.sh"
    [ -f "${MODULES_DIR}/bullseye/repos.sh" ]  && source "${MODULES_DIR}/bullseye/repos.sh"
    [ -f "${MODULES_DIR}/bullseye/extras.sh" ] && source "${MODULES_DIR}/bullseye/extras.sh"
fi

REPOS_CONFIGURED=false
DEBIAN_VERSION=""
DEBIAN_CODENAME=""

main_menu() {
    # Auto-adjust TUI dimensions for small terminals
    if [ "${LINES:-24}" -lt $((TUI_ALTO + 6)) ] || [ "${COLUMNS:-80}" -lt $((TUI_ANCHO + 6)) ]; then
        TUI_ALTO=$((LINES - 4 > 8 ? LINES - 4 : 8))
        TUI_ANCHO=$((COLUMNS - 4 > 50 ? COLUMNS - 4 : 50))
        TUI_ALTO_LISTA=$((TUI_ALTO - 10 > 4 ? TUI_ALTO - 10 : 4))
    fi

    while true; do
        sudo -v >/dev/null 2>&1 || true
        local STATE_REFRESHED=false
        local choice
        choice=$(_menu "DEBIANITO — simple configurator script" "" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "System Info" \
            "2" "User Privileges & Feedback" \
            "3" "Configure repositories" \
            "4" "Firmware, Wireless & Bluetooth" \
            "5" "Graphics Drivers & Mesa Stack" \
            "6" "Backports Kernel" \
            "7" "Gaming Setup" \
            "8" "ZRAM" \
            "9" "Swap Management" \
            "10" "Install Programs and Software" \
            "11" "Boot Rescue & Repair" \
            "12" "Exit")

        clear

        case "$choice" in
            1)  _show_sysinfo ;;
            2)  config_sudo || true ;;
            3)
                if [ "$DEBIAN_VERSION" = "11" ] && type configure_repos_bullseye &>/dev/null; then
                    configure_repos_bullseye || true
                else
                    configure_repos || true
                fi
                STATE_REFRESHED=true
                ;;
            4)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_firmware_bullseye &>/dev/null; then
                    install_firmware_bullseye || true
                else
                    install_firmware || true
                fi
                ;;
            5)  install_gpu_drivers || true; STATE_REFRESHED=true ;;
            6)
                if [ "$DEBIAN_VERSION" = "11" ]; then
                    _msg "Not Available" \
                        "Backports Kernel is not available on Debian 11 Bullseye.\n\n\
Ultra Minimalist Rescue Mode does not include third-party\n\
kernels. Use the stable kernel provided by Bullseye." 10 60
                else
                    install_kernel_backports || true
                fi
                STATE_REFRESHED=true
                ;;
            7)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_gaming_bullseye &>/dev/null; then
                    install_gaming_bullseye || true
                else
                    install_gaming || true
                fi
                STATE_REFRESHED=true
                ;;
            8)  install_zram || true ;;
            9)  manage_swap || true; STATE_REFRESHED=true ;;
            10)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_extras_bullseye &>/dev/null; then
                    install_extras_bullseye || true
                else
                    install_extras || true
                fi
                ;;
            11) rescue_boot || true ;;
            12) echo "Exiting."; exit 0 ;;
        esac
        if $STATE_REFRESHED; then
            refresh_system_state
        fi
    done
}

check_root
check_sudo
if ! _check_network; then
    echo -e "${YELLOW}──────────────────────────────────────────${NC}"
    echo -e "${YELLOW} No internet connectivity detected.${NC}"
    echo -e "${YELLOW} Package installation will fail without network.${NC}"
    echo -e "${YELLOW} You can use: System Info, User Privileges, and${NC}"
    echo -e "${YELLOW} other offline features.${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────${NC}"
fi
check_system_time

detect_debian_version
detect_cpu_ram
detect_kernel
detect_gpu
detect_network
detect_displayserver
detect_storage
detect_desktop_environment
_configure_lightdm
detect_audio_server

# ── Bullseye-specific init (archive phase) ──
if [ "$DEBIAN_VERSION" = "11" ] && type check_bullseye_archive_phase &>/dev/null; then
    check_bullseye_archive_phase
fi

main_menu
