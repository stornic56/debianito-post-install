#!/usr/bin/env bash

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

        local found_active_wifi=false
        for i in "${!WIFI_NAMES[@]}"; do
            found_active_wifi=true
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

        if ! $found_active_wifi && [ -n "$WIFI_DESC" ]; then
            has_network=true
            msg+="WiFi:     ${WIFI_DESC}\n"
            msg+="          (no driver — use Firmware option in main menu)\n"
        fi

        if ! $has_network; then
            msg+="No active interfaces detected\n"
        fi
    fi

    _msg "System Information" "$msg" 22 76
}
