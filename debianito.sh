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

# Boot profiling: DEBIANITO_PROFILE=1 stamps each boot
# step to stderr for before/after comparison.
_boot_mark() {
    [ "${DEBIANITO_PROFILE:-0}" = "1" ] || return 0
    printf '[%s] %s\n' "$(date +%s%N)" "$*" >&2
}

_boot_mark "boot: start (before module sources)"

# Eager core only: utils.sh holds every boot function
# and TUI helper; hw_detect.sh declares the global
# device arrays (PCI_NET_DEVS, ...) that lazily-loaded
# modules read under `set -u`. All other modules are
# sourced on demand via _load_module() in main_menu().
source "${MODULES_DIR}/utils.sh"
source "${MODULES_DIR}/hw_detect.sh"

# ── Bullseye-specific modules (loaded only on Debian 11) ──
# Eager-conditional: the menu dispatch branches on
# `type install_*_bullseye`, so these must be defined
# before main_menu() runs.
if [ -d "${MODULES_DIR}/bullseye" ]; then
    [ -f "${MODULES_DIR}/bullseye/legacy.sh" ] && source "${MODULES_DIR}/bullseye/legacy.sh"
    [ -f "${MODULES_DIR}/bullseye/repos.sh" ] && source "${MODULES_DIR}/bullseye/repos.sh"
    [ -f "${MODULES_DIR}/bullseye/extras.sh" ] && source "${MODULES_DIR}/bullseye/extras.sh"
fi

_boot_mark "boot: core modules loaded"

# ── Interrupt safety: restore repository state on Ctrl+C / TERM ──
_on_interrupt() {
    echo -e "${RED}[!] Interrupted. Restoring repository state if possible...${NC}"
    if type restore_previous_repos &>/dev/null; then
        restore_previous_repos 2>/dev/null || true
    fi

    # Clean up temporary files created during execution
    rm -rf /tmp/debianito.* 2>/dev/null || true

    echo -e "${YELLOW}[!] Temp files cleaned.${NC}"

    exit 130
}
trap _on_interrupt INT TERM

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
        1)
            _load_module sysinfo || continue
            _show_sysinfo
            ;;
        2)
            _load_module sudo_config || continue
            config_sudo || true
            ;;
        3)
            _load_module system_prefs || continue
            _system_preferences_menu
            STATE_REFRESHED=true
            ;;
        4)
            if [ "$DEBIAN_VERSION" = "11" ] && type configure_repos_bullseye &>/dev/null; then
                configure_repos_bullseye || true
            else
                _load_module repos || continue
                configure_repos || true
            fi
            STATE_REFRESHED=true
            ;;
        5)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_firmware_bullseye &>/dev/null; then
                # Bullseye flow calls _handle_wireless
                # from firmware.sh: load the module
                # (cascades repo_detect, bluetooth, repos).
                _load_module firmware || continue
                install_firmware_bullseye || true
            else
                _load_module firmware || continue
                install_firmware || true
            fi
            STATE_REFRESHED=true
            ;;
        6)
            _load_module gpu || continue
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
            _load_module kernel || continue
            show_kernel_menu || true
            STATE_REFRESHED=true
            ;;
        8)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_gaming_bullseye &>/dev/null; then
                # Bullseye flow calls the gaming bundle
                # (ensure_contrib_repo, install_steam,
                # install_mangohud, ...) and java.sh:
                # load the bundle (cascades repo_detect,
                # java, repos).
                _load_module gaming || continue
                install_gaming_bullseye || true
            else
                _load_module gaming || continue
                install_gaming || true
            fi
            STATE_REFRESHED=true
            ;;
        9)
            _load_module zram || continue
            zram_menu || true
            STATE_REFRESHED=true
            ;;
        10)
            _load_module swap || continue
            manage_swap || true
            STATE_REFRESHED=true
            ;;
        11)
            if [ "$DEBIAN_VERSION" = "11" ] && type install_extras_bullseye &>/dev/null; then
                # Bullseye flow calls _install_dev_java
                # from extras/java.sh: load it explicitly.
                _load_module java || continue
                install_extras_bullseye || true
            else
                _load_module extras || continue
                install_extras || true
            fi
            STATE_REFRESHED=true
            ;;
        12)
            _load_module rescue || continue
            rescue_boot || true
            STATE_REFRESHED=true
            ;;
        13)
            _load_module desktop_display || continue
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

_boot_mark "boot: pre-flight checks"
check_root
check_sudo
if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${YELLOW}[+] whiptail not found. Installing required TUI dependencies...${NC}"
    if _ensure_apt_updated && sudo apt-get install -y whiptail; then
        echo -e "${GREEN}[+] whiptail installed.${NC}"
    else
        echo -e "${RED}[-] Could not install whiptail (no network?).${NC}" >&2
        echo -e "${RED}    The TUI menu requires it; install manually and re-run.${NC}" >&2
    fi
fi

# Hardware detection is deferred on demand via
# _ensure_state_detected(); only the OS version is
# eager because the menu dispatch branches on it.
_boot_mark "boot: os detection"
detect_debian_version

# ── Bullseye-specific init (archive phase) ──
if [ "$DEBIAN_VERSION" = "11" ] && type check_bullseye_archive_phase &>/dev/null; then
    check_bullseye_archive_phase
fi

if ! command -v whiptail >/dev/null 2>&1; then
    echo -e "${RED}[-] whiptail is required for the TUI menu. Aborting.${NC}" >&2
    exit 1
fi

_boot_mark "boot: entering main menu"
main_menu
