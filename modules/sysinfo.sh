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

    # ── Network Block (PCI class + live interfaces) ──
    msg+="─── Network ───\n"

    # ── 1. Detect ALL Ethernet chipsets (class 0x0200) ──
    declare -a pci_eth_lines=()
    while IFS= read -r line; do
        pci_eth_lines+=("$line")
    done < <(lspci -d ::0200 2>/dev/null || true)

    # ── 2. Detect ALL WiFi chipsets (class 0x0280 + vendor fallbacks) ──
    declare -a pci_wifi_lines=()
    while IFS= read -r line; do
        pci_wifi_lines+=("$line")
    done < <(lspci -d ::0280 2>/dev/null || true)

    # Broadcom vendor-ID fallback (14e4) — include only if not already captured
    while IFS= read -r line; do
        if echo "$line" | grep -qi '14e4:'; then
            local already=false
            for existing in "${pci_wifi_lines[@]}"; do
                [ "$existing" = "$line" ] && already=true && break
            done
            ! $already && pci_wifi_lines+=("$line")
        fi
    done < <(lspci -nn 2>/dev/null || true)

    # USB WiFi fallback
    local usb_wifi_lines=()
    while IFS= read -r line; do
        usb_wifi_lines+=("$line")
    done < <(lsusb 2>/dev/null | grep -iE 'wireless|wifi|wlan|802\.11' || true)

    # ── 3. Build chipset description arrays ──
    local -a eth_descs=()
    local -a wifi_descs=()
    local line desc

    for line in "${pci_eth_lines[@]}"; do
        desc=$(echo "$line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
        eth_descs+=("$desc")
    done
    for line in "${pci_wifi_lines[@]}"; do
        desc=$(echo "$line" | sed -E 's/^.*\]: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev [0-9a-fA-F]+\)//')
        wifi_descs+=("$desc")
    done
    for line in "${usb_wifi_lines[@]}"; do
        desc=$(echo "$line" | sed 's/^.*ID //')
        wifi_descs+=("$desc")
    done

    # ── 4. Enumerate live interfaces ──
    local -a shown_eth_descs=()
    local -a shown_wifi_descs=()
    local has_eth=false has_wifi=false has_other=false

    if ! command -v ip &>/dev/null; then
        msg+="(install iproute2 for interface details)\n"
    else
        while IFS= read -r line; do
            local iface state ip4 ssid
            iface=$(echo "$line" | awk -F': ' '{print $2}' | sed 's/@.*//')
            state=$(echo "$line" | awk '{print $9}')

            case "$iface" in
                lo|docker*|veth*|br-*|virbr*|tun*|tap*|bond*) continue ;;
            esac

            ip4=$(ip -4 -o addr show "$iface" 2>/dev/null | awk '{print $4}')

            # Determine type by PCI class (most reliable)
            local pci_class=""
            pci_class=$(cat "/sys/class/net/${iface}/device/class" 2>/dev/null || true)

            case "$pci_class" in
                0x0200*)
                    has_eth=true
                    desc="${eth_descs[0]:-Unknown Ethernet chipset}"
                    shown_eth_descs+=("${eth_descs[0]}")
                    ;;
                0x0280*)
                    has_wifi=true
                    desc="${wifi_descs[0]:-Unknown WiFi chipset}"
                    shown_wifi_descs+=("${wifi_descs[0]}")
                    ssid=""
                    [ "$state" = "UP" ] && ssid=$(iwgetid -r "$iface" 2>/dev/null || true)
                    ;;
                *)
                    # Fallback: classify by interface name pattern
                    case "$iface" in
                        wl*|wlp*|wlo*|wlan*)
                            has_wifi=true
                            desc="${wifi_descs[0]:-Unknown WiFi chipset}"
                            shown_wifi_descs+=("${wifi_descs[0]}")
                            ssid=""
                            [ "$state" = "UP" ] && ssid=$(iwgetid -r "$iface" 2>/dev/null || true)
                            ;;
                        eth*|enp*|ens*|enx*|eno*)
                            has_eth=true
                            desc="${eth_descs[0]:-Unknown Ethernet chipset}"
                            shown_eth_descs+=("${eth_descs[0]}")
                            ;;
                        *)
                            has_other=true
                            desc="(network interface)"
                            ;;
                    esac
                    ;;
            esac

            if [ "$state" = "UP" ]; then
                msg+="${iface}:   ${desc}\n       ↑ ${ip4:-no IP}"
                if [ "$pci_class" = "0x0280" ] || [[ "$iface" == wl* ]]; then
                    [ -n "${ssid:-}" ] && msg+="  \"${ssid}\""
                fi
                msg+="\n"
            else
                msg+="${iface}:   ${desc}\n       ↓\n"
            fi
        done < <(ip -o link show 2>/dev/null)
    fi

    # ── 5. Show chipsets without an active interface ──
    local chip

    for chip in "${eth_descs[@]}"; do
        local found=false
        for shown in "${shown_eth_descs[@]}"; do
            [ "$chip" = "$shown" ] && found=true && break
        done
        if ! $found; then
            msg+="Ethernet: ${chip}\n       (no active interface)\n"
            shown_eth_descs+=("$chip")
        fi
    done

    for chip in "${wifi_descs[@]}"; do
        local found=false
        for shown in "${shown_wifi_descs[@]}"; do
            [ "$chip" = "$shown" ] && found=true && break
        done
        if ! $found; then
            msg+="WiFi:     ${chip}\n       (no active interface)\n"
            shown_wifi_descs+=("$chip")
        fi
    done

    # ── 6. Nothing at all ──
    if ! $has_eth && ! $has_wifi && ! $has_other && [ ${#eth_descs[@]} -eq 0 ] && [ ${#wifi_descs[@]} -eq 0 ]; then
        if command -v ip &>/dev/null; then
            msg+="No network interfaces detected\n"
        else
            msg+="(install iproute2 for interface details)\n"
        fi
    fi

    # ════════════════════════════════════════════════════════════
    # Dynamic dimension calculation
    # ════════════════════════════════════════════════════════════

    local term_cols
    term_cols=$(tput cols 2>/dev/null || echo 80)
    [ "$term_cols" -lt 50 ] && term_cols=50

    local max_pct=$(( term_cols * 95 / 100 ))
    [ "$max_pct" -lt 50 ] && max_pct=50

    local longest=0
    while IFS= read -r line; do
        local len=${#line}
        [ "$len" -gt "$longest" ] && longest=$len
    done < <(echo -e "$msg")

    local width=$(( longest + 6 ))
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
    local height=$(( lines + 6 ))
    [ "$height" -gt 22 ] && height=22
    [ "$height" -lt 10 ] && height=10

    _msg "System Information" "$truncated" "$height" "$width"
}
