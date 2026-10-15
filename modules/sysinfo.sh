#!/usr/bin/env bash

_show_sysinfo() {
    # Hardware state is detected on demand; populate it
    # before reading any DETECT_* global.
    _ensure_state_detected

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

    # ── GPU Block (cached by detect_gpu) ──
    if [ -n "${GPU_DESC:-}" ] && [ "$GPU_DESC" != "No GPU detected" ]; then
        msg+="GPU:      ${GPU_DESC}\n"
        msg+="          Driver: ${GPU_VERSION:-unknown}\n"
    else
        msg+="GPU:      No GPU detected\n"
    fi
    msg+="\n"

    # ── Network Block (cached by detect_network) ──
    msg+="─── Network ───\n"

    if ! command -v ip &>/dev/null; then
        msg+="(install iproute2 for interface details)\n"
    else
        local i desc
        local has_net=false

        # Ethernet interfaces (chipset from ETH_DESCS, parallel arrays)
        for i in "${!ETH_NAMES[@]}"; do
            has_net=true
            desc="${ETH_DESCS[$i]:-Unknown Ethernet chipset}"
            if [ "${ETH_STATES[$i]}" = "UP" ]; then
                msg+="${ETH_NAMES[$i]}:   ${desc}\n       ↑ ${ETH_IPS[$i]:-no IP}\n"
            else
                msg+="${ETH_NAMES[$i]}:   ${desc}\n       ↓\n"
            fi
        done

        # WiFi interfaces (chipset from WIFI_DESCS, parallel arrays)
        for i in "${!WIFI_NAMES[@]}"; do
            has_net=true
            desc="${WIFI_DESCS[$i]:-Unknown WiFi chipset}"
            if [ "${WIFI_STATES[$i]}" = "UP" ]; then
                msg+="${WIFI_NAMES[$i]}:   ${desc}\n       ↑ ${WIFI_IPS[$i]:-no IP}"
                [ -n "${WIFI_SSIDS[$i]:-}" ] && msg+="  \"${WIFI_SSIDS[$i]}\""
                msg+="\n"
            else
                msg+="${WIFI_NAMES[$i]}:   ${desc}\n       ↓\n"
            fi
        done

        # Chipsets with no live interface
        local chip shown
        for chip in "${ETH_DESCS[@]}"; do
            shown=false
            for i in "${!ETH_NAMES[@]}"; do
                [ "${ETH_DESCS[$i]}" = "$chip" ] && shown=true && break
            done
            $shown || msg+="Ethernet: ${chip}\n       (no active interface)\n"
        done
        for chip in "${WIFI_DESCS[@]}"; do
            shown=false
            for i in "${!WIFI_NAMES[@]}"; do
                [ "${WIFI_DESCS[$i]}" = "$chip" ] && shown=true && break
            done
            $shown || msg+="WiFi:     ${chip}\n       (no active interface)\n"
        done

        if ! $has_net && [ ${#ETH_DESCS[@]} -eq 0 ] && [ ${#WIFI_DESCS[@]} -eq 0 ]; then
            msg+="No network interfaces detected\n"
        fi
    fi

    # ════════════════════════════════════════════════════════════
    # Dynamic dimension calculation
    # ════════════════════════════════════════════════════════════

    local term_cols
    term_cols=$(tput cols 2>/dev/null || echo 80)
    [ "$term_cols" -lt 50 ] && term_cols=50

    local max_pct=$((term_cols * 95 / 100))
    [ "$max_pct" -lt 50 ] && max_pct=50

    local longest=0
    while IFS= read -r line; do
        local len=${#line}
        [ "$len" -gt "$longest" ] && longest=$len
    done < <(echo -e "$msg")

    local width=$((longest + 6))
    [ "$width" -lt 80 ] && width=80
    [ "$width" -gt "$max_pct" ] && width=$max_pct

    local truncated=""
    while IFS= read -r line; do
        if [ ${#line} -gt "$width" ]; then
            truncated+="${line:0:$((width - 4))}...\\n"
        else
            truncated+="${line}\\n"
        fi
    done < <(echo -e "$msg")

    local lines
    lines=$(echo -e "$truncated" | wc -l)
    local height=$((lines + 6))
    local max_height=$((${LINES:-24} - 4 > 10 ? ${LINES:-24} - 4 : 10))
    [ "$height" -gt "$max_height" ] && height=$max_height
    [ "$height" -lt 10 ] && height=10

    _msg "System Information" "$truncated" "$height" "$width"
}
