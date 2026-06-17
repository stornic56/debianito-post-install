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
source "${MODULES_DIR}/repos/repo_detect.sh"
source "${MODULES_DIR}/repos.sh"
[ -f "${MODULES_DIR}/firmware.sh" ] && source "${MODULES_DIR}/firmware.sh"
[ -f "${MODULES_DIR}/gpu.sh" ]       && source "${MODULES_DIR}/gpu.sh"
[ -f "${MODULES_DIR}/kernel.sh" ]    && source "${MODULES_DIR}/kernel.sh"
[ -f "${MODULES_DIR}/gaming.sh" ]    && source "${MODULES_DIR}/gaming.sh"
[ -f "${MODULES_DIR}/extras.sh" ]    && source "${MODULES_DIR}/extras.sh"
[ -f "${MODULES_DIR}/zram.sh" ]      && source "${MODULES_DIR}/zram.sh"
[ -f "${MODULES_DIR}/extras/java.sh" ] && source "${MODULES_DIR}/extras/java.sh"

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
            "4" "Firmware & Wireless Drivers" \
            "5" "Graphics Drivers & Mesa Stack" \
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
            3)
                if [ "$DEBIAN_VERSION" = "11" ] && type configure_repos_bullseye &>/dev/null; then
                    configure_repos_bullseye || true
                else
                    configure_repos || true
                fi
                ;;
            4)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_firmware_bullseye &>/dev/null; then
                    install_firmware_bullseye || true
                else
                    install_firmware || true
                fi
                ;;
            5)  install_gpu_drivers || true ;;
            6)
                if [ "$DEBIAN_VERSION" = "11" ]; then
                    _msg "Not Available" \
                        "Backports Kernel is not available on Debian 11 Bullseye.\n\n\
Ultra Minimalist Rescue Mode does not include third-party\n\
kernels. Use the stable kernel provided by Bullseye." 10 60
                else
                    install_kernel_backports || true
                fi
                ;;
            7)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_gaming_bullseye &>/dev/null; then
                    install_gaming_bullseye || true
                else
                    install_gaming || true
                fi
                ;;
            8)  install_zram || true ;;
            9)
                if [ "$DEBIAN_VERSION" = "11" ] && type install_extras_bullseye &>/dev/null; then
                    install_extras_bullseye || true
                else
                    install_extras || true
                fi
                ;;
            10) echo "Exiting."; exit 0 ;;
        esac
    done
}

_show_sysinfo() {
    local msg=""

    # ── OS Block ──
    msg+="OS:       ${DEBIAN_VERSION} (${DEBIAN_CODENAME})\n"
    msg+="Kernel:   ${KERNEL_VERSION}\n"
    msg+="Display:  ${DISPLAY_SERVER}\n"
    msg+="\n"

    # ── Hardware Block ──
    msg+="CPU:      ${CPU_SUMMARY}\n"
    msg+="RAM:      ${RAM_SUMMARY}\n"
    msg+="Storage:  ${STORAGE_SUMMARY}\n"
    msg+="\n"

    # ── GPU Block ──
    local found_gpu=false
    if command -v lspci &>/dev/null; then
        local gpu_count=0
        while IFS= read -r gpu_line; do
            found_gpu=true
            gpu_count=$((gpu_count + 1))
            local desc
            desc=$(echo "$gpu_line" | sed -E 's/.*: //; s/ *\(rev.*//')

            if echo "$gpu_line" | grep -qi "nvidia"; then
                local nv_ver=""
                nv_ver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1)
                [ -z "$nv_ver" ] && nv_ver=$(dpkg -l nvidia-driver 2>/dev/null | awk '/^ii/ {print $3}' | sed 's/-.*//')
                msg+="GPU ${gpu_count}:    ${desc}\n"
                msg+="          Driver: ${nv_ver:+NVIDIA }${nv_ver:-not installed}\n"
            else
                local mesa_ver=""
                mesa_ver=$(dpkg -l libgl1-mesa-dri 2>/dev/null | awk '/^ii/ {print $3; exit}' | sed 's/-.*//')
                msg+="GPU ${gpu_count}:    ${desc}\n"
                msg+="          Driver: ${mesa_ver:+Mesa }${mesa_ver:-unknown}\n"
            fi
        done < <(lspci -nn | grep -E "VGA|3D" || true)
    fi

    if ! $found_gpu; then
        msg+="GPU:      No GPU detected\n"
    fi
    msg+="\n"

    # ── Network Block ──
    msg+="─── Network ───\n"
    local has_network=false
    local i

    if ! command -v ip &>/dev/null; then
        msg+="(install iproute2 for interface details)\n"
    else
        for i in "${!ETH_NAMES[@]}"; do
            has_network=true
            local e_iface="${ETH_NAMES[$i]}"
            local e_desc="${ETH_DESCS[$i]:-$ETH_DESC}"
            local e_state="${ETH_STATES[$i]}"
            local e_ip4="${ETH_IPS[$i]}"
            if [ "$e_state" = "UP" ]; then
                msg+="${e_iface}:   ${e_desc}\n       ↑ ${e_ip4:-no IP}\n"
            else
                msg+="${e_iface}:   ${e_desc}\n       ↓\n"
            fi
        done

        for i in "${!WIFI_NAMES[@]}"; do
            has_network=true
            local w_iface="${WIFI_NAMES[$i]}"
            local w_desc="${WIFI_DESCS[$i]:-$WIFI_DESC}"
            local w_state="${WIFI_STATES[$i]}"
            local w_ip4="${WIFI_IPS[$i]}"
            local w_ssid="${WIFI_SSIDS[$i]}"
            if [ "$w_state" = "UP" ]; then
                msg+="${w_iface}:   ${w_desc}\n       ↑ ${w_ip4:-no IP}"
                [ -n "$w_ssid" ] && msg+="  \"${w_ssid}\""
                msg+="\n"
            else
                msg+="${w_iface}:   ${w_desc}\n       ↓\n"
            fi
        done

        if ! $has_network; then
            msg+="No active interfaces detected\n"
        fi
    fi

    _msg "System Information" "$msg" 22 76
}

check_root
check_sudo
check_system_time
sync_system_time

detect_debian_version
detect_cpu_ram
detect_kernel
detect_gpu
detect_network
detect_displayserver
detect_storage

# ── Bullseye-specific init (archive phase) ──
if [ "$DEBIAN_VERSION" = "11" ] && type check_bullseye_archive_phase &>/dev/null; then
    check_bullseye_archive_phase
fi

main_menu
