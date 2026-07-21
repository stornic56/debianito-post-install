#!/usr/bin/env bash
# zram.sh — ZRAM submenu: view, create/reconfigure, remove

zram_menu() {
    while true; do
        local choice
        choice=$(_menu "ZRAM Configuration" \
            "Select an operation:" $TUI_ALTO $TUI_ANCHO 4 \
            "1" "View ZRAM status" \
            "2" "Create / Reconfigure ZRAM" \
            "3" "Remove ZRAM" \
            "4" "Back to main menu")

        [ -z "$choice" ] && break
        clear

        case "$choice" in
            1) _zram_view ;;
            2) _zram_create ;;
            3) _zram_remove ;;
            4) break ;;
        esac
    done
}

_zram_view() {
    if ! is_installed "zram-tools"; then
        _msg "ZRAM Status" "ZRAM is not installed.\n\nUse option 2 (Create / Reconfigure ZRAM)\nto set it up." 10 55
        return
    fi

    local algo="" size="" priority=""
    if [ -f /etc/default/zramswap ]; then
        while IFS='=' read -r key val; do
            case "$key" in
                ALGO)      algo=$val ;;
                SIZE)      size=$val ;;
                PRIORITY)  priority=$val ;;
            esac
        done < /etc/default/zramswap
    fi

    local info="ZRAM Configuration:\n"
    info+="  Algorithm:  ${algo:-not set}\n"
    info+="  Size:       ${size:-not set} MB\n"
    info+="  Priority:   ${priority:-not set}\n\n"
    info+="Active ZRAM devices:\n"

    local zram_out
    zram_out=$(sudo zramctl 2>/dev/null || true)
    if [ -n "$zram_out" ]; then
        info+="$zram_out"
    else
        info+="  (none — service may be stopped)"
    fi

    _msg "ZRAM Status" "$info" 16 70
}

_zram_create() {
    if [ -z "$RAM_KB" ] || [ "$RAM_KB" -eq 0 ]; then
        echo -e "${RED}Could not determine RAM size. Aborting.${NC}"
        return 1
    fi

    if is_installed "zram-tools"; then
        local cur_algo="" cur_size="" cur_prio=""
        if [ -f /etc/default/zramswap ]; then
            while IFS='=' read -r key val; do
                case "$key" in
                    ALGO)     cur_algo=$val ;;
                    SIZE)     cur_size=$val ;;
                    PRIORITY) cur_prio=$val ;;
                esac
            done < /etc/default/zramswap
        fi
        local cur="ZRAM is already configured:\n"
        cur+="  Algorithm:  ${cur_algo:-not set}\n"
        cur+="  Size:       ${cur_size:-not set} MB\n"
        cur+="  Priority:   ${cur_prio:-not set}\n\n"
        cur+="Continuing will overwrite this configuration."
        if ! _confirm "ZRAM — Reconfigure" "$cur"; then
            echo "ZRAM reconfiguration cancelled."
            return
        fi
    fi

    local half_ram_mb=$(( ((RAM_KB / 1024 / 1024 + 1) / 2) * 1024 ))

    local algo
    algo=$(_menu "ZRAM Configuration" \
        "ZRAM creates a compressed swap device in RAM to reduce disk I/O and boost speed. Data is stored compressed in memory. Choose an algorithm below to balance CPU usage and compression ratio:" \
        $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "lz4"  "Fastest compression. Lowest CPU overhead. (Default)" \
        "zstd" "Higher compression ratio. Saves more RAM, uses more CPU.")

    if [ -z "$algo" ]; then
        echo "ZRAM configuration cancelled."
        return
    fi

    local zram_size
    if _confirm "ZRAM Size" "Use recommended size for ZRAM? (${half_ram_mb} MB out of ${RAM_SUMMARY})"; then
        zram_size=$half_ram_mb
    else
        zram_size=$(_inputbox "ZRAM Size" "Enter ZRAM size in MB:" 8 60 "$half_ram_mb")
        if [ -z "$zram_size" ] || ! [[ "$zram_size" =~ ^[0-9]+$ ]] || [ "$zram_size" -eq 0 ]; then
            echo "ZRAM configuration cancelled."
            return
        fi
    fi

    if ! _confirm "ZRAM Summary" "Algorithm: ${algo}\nSize: ${zram_size} MB\nPriority: 100\n\nApply?"; then
        echo "ZRAM configuration cancelled."
        return
    fi

    _run_cmd "ZRAM" "sudo apt install -y zram-tools" "Installing zram-tools..."

    echo "Writing configuration..."
    sudo tee /etc/default/zramswap > /dev/null <<EOF
ALGO=$algo
SIZE=$zram_size
PRIORITY=100
EOF

    echo "Restarting zramswap service..."
    sudo systemctl restart zramswap

    echo ""
    echo -e "${GREEN}ZRAM configured successfully.${NC}"
    echo ""
    sudo zramctl
    echo ""
    echo -e "${GREEN}You can verify with: sudo zramctl${NC}"
    _pause
}

_zram_remove() {
    if ! is_installed "zram-tools"; then
        _msg "ZRAM Remove" "ZRAM is not installed.\n\nNothing to remove." 10 50
        return
    fi

    if ! _confirm "Remove ZRAM" \
        "This will:\n  - Stop the zramswap service\n  - Purge zram-tools\n  - Remove /etc/default/zramswap\n\nProceed?"; then
        echo "ZRAM removal cancelled."
        return
    fi

    echo "Stopping zramswap service..."
    sudo systemctl stop zramswap || true

    _run_cmd "ZRAM" "sudo apt purge -y zram-tools" "Purging zram-tools..."

    echo "Removing configuration..."
    sudo rm -f /etc/default/zramswap

    _msg "ZRAM Removed" "ZRAM has been removed successfully.\n\nThe zramswap service is stopped and disabled." 10 55
}
