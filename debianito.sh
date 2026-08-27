#!/usr/bin/env bash
# Debianito — simple configurator script
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# TUI dimensions — fixed centered size for whiptail dialogs
TUI_ALTO=20
TUI_ANCHO=78
TUI_ALTO_LISTA=10

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${SCRIPT_DIR}/modules"

source "${MODULES_DIR}/utils.sh"
[ -f "${MODULES_DIR}/sysinfo.sh" ] && source "${MODULES_DIR}/sysinfo.sh"
source "${MODULES_DIR}/sudo_config.sh"
source "${MODULES_DIR}/repos/repo_detect.sh"
source "${MODULES_DIR}/repos.sh"
[ -f "${MODULES_DIR}/firmware.sh" ] && source "${MODULES_DIR}/firmware.sh"
[ -f "${MODULES_DIR}/bluetooth.sh" ] && source "${MODULES_DIR}/bluetooth.sh"
[ -f "${MODULES_DIR}/gpu.sh" ] && source "${MODULES_DIR}/gpu.sh"
[ -f "${MODULES_DIR}/kernel.sh" ] && source "${MODULES_DIR}/kernel.sh"
[ -f "${MODULES_DIR}/gaming.sh" ] && source "${MODULES_DIR}/gaming.sh"
[ -f "${MODULES_DIR}/extras.sh" ] && source "${MODULES_DIR}/extras.sh"
[ -f "${MODULES_DIR}/zram.sh" ] && source "${MODULES_DIR}/zram.sh"
[ -f "${MODULES_DIR}/extras/java.sh" ] && source "${MODULES_DIR}/extras/java.sh"
[ -f "${MODULES_DIR}/rescue.sh" ] && source "${MODULES_DIR}/rescue.sh"
[ -f "${MODULES_DIR}/swap.sh" ] && source "${MODULES_DIR}/swap.sh"
[ -f "${MODULES_DIR}/desktop_display.sh" ] && source "${MODULES_DIR}/desktop_display.sh"
[ -f "${MODULES_DIR}/system/system_prefs.sh" ] && source "${MODULES_DIR}/system/system_prefs.sh"
[ -f "${MODULES_DIR}/system/audio.sh" ] && source "${MODULES_DIR}/system/audio.sh"

# ── Bullseye-specific modules (loaded only on Debian 11) ──
if [ -d "${MODULES_DIR}/bullseye" ]; then
    [ -f "${MODULES_DIR}/bullseye/legacy.sh" ] && source "${MODULES_DIR}/bullseye/legacy.sh"
    [ -f "${MODULES_DIR}/bullseye/repos.sh" ] && source "${MODULES_DIR}/bullseye/repos.sh"
    [ -f "${MODULES_DIR}/bullseye/extras.sh" ] && source "${MODULES_DIR}/bullseye/extras.sh"
fi

DEBIAN_VERSION=""
DEBIAN_CODENAME=""

main_menu() {
    # Auto-adjust TUI dimensions for small terminals
    if [ "${LINES:-24}" -lt $((TUI_ALTO + 6)) ] || [ "${COLUMNS:-80}" -lt $((TUI_ANCHO + 6)) ]; then
        TUI_ALTO=$((${LINES:-24} - 4 > 8 ? ${LINES:-24} - 4 : 8))
        TUI_ANCHO=$((${COLUMNS:-80} - 4 > 50 ? ${COLUMNS:-80} - 4 : 50))
        TUI_ALTO_LISTA=$((TUI_ALTO - 10 > 4 ? TUI_ALTO - 10 : 4))
    fi

    while true; do
        sudo -v >/dev/null 2>&1 || true
        local STATE_REFRESHED=false
        local choice
        choice=$(_menu "DEBIANITO — Simple Configurator Script" "" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "System Information" \
            "2" "User Privileges & Feedback" \
            "3" "System Preferences" \
            "4" "Configure Repositories" \
            "5" "Firmware, Wireless & Bluetooth" \
            "6" "Graphics Drivers & Mesa Stack" \
            "7" "Kernel" \
            "8" "Gaming Setup" \
            "9" "ZRAM" \
            "10" "Swap Management" \
            "11" "Install Programs and Software" \
            "12" "Boot Rescue + GRUB" \
            "13" "Desktop & Display" \
            "14" "Exit")

        clear

        case "$choice" in
        1) _show_sysinfo ;;
        2) config_sudo || true ;;
        3)
            _system_preferences_menu
            STATE_REFRESHED=true
            ;;
        4)
            if [ "$DEBIAN_VERSION" = "11" ] && type configure_repos_bullseye &>/dev/null; then
                configure_repos_bullseye || true
            else
                configure_repos || true
            fi
            STATE_REFRESHED=true
            ;;
        5)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_firmware_bullseye &>/dev/null; then
                install_firmware_bullseye || true
            else
                install_firmware || true
            fi
            STATE_REFRESHED=true
            ;;
        6)
            local gpu_sub
            gpu_sub=$(_menu "Graphics Drivers" "" 12 50 2 \
                "1" "Radeon/Intel Mesa" \
                "2" "NVIDIA Drivers")
            [ -z "$gpu_sub" ] && continue
            clear
            case $gpu_sub in
            1) _install_amd_intel_stack || true ;;
            2) _install_nvidia_stack || true ;;
            esac
            STATE_REFRESHED=true
            ;;
        7)
            show_kernel_menu || true
            STATE_REFRESHED=true
            ;;
        8)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_gaming_bullseye &>/dev/null; then
                install_gaming_bullseye || true
            else
                install_gaming || true
            fi
            STATE_REFRESHED=true
            ;;
        9)
            zram_menu || true
            STATE_REFRESHED=true
            ;;
        10)
            manage_swap || true
            STATE_REFRESHED=true
            ;;
        11)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_extras_bullseye &>/dev/null; then
                install_extras_bullseye || true
            else
                install_extras || true
            fi
            STATE_REFRESHED=true
            ;;
        12)
            rescue_boot || true
            STATE_REFRESHED=true
            ;;
        13)
            manage_desktop_display || true
            STATE_REFRESHED=true
            ;;
        14)
            echo "Exiting."
            exit 0
            ;;
        esac
        if $STATE_REFRESHED; then
            refresh_system_state
        fi
    done
}

check_root
check_sudo
if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${YELLOW}[+] whiptail not found. Installing required TUI dependencies...${NC}"
    _ensure_apt_updated && sudo apt-get install -y whiptail
fi
if ! _check_network; then
    echo -e "${YELLOW}──────────────────────────────────────────${NC}"
    echo -e "${YELLOW} No internet connectivity detected.${NC}"
    echo -e "${YELLOW} Package installation will fail without network.${NC}"
    echo -e "${YELLOW} You can use: System Info, User Privileges, and${NC}"
    echo -e "${YELLOW} other offline features.${NC}"
    echo -e "${YELLOW}──────────────────────────────────────────${NC}"
fi
_ensure_time_synced

detect_debian_version
detect_cpu_ram
detect_kernel
_init_lspci_cache
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
