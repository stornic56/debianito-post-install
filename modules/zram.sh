#!/usr/bin/env bash
# zram.sh - Configure compressed swap in RAM

install_zram() {
    echo -e "${YELLOW}ZRAM Configuration${NC}"

    if [ -z "$RAM_KB" ] || [ "$RAM_KB" -eq 0 ]; then
        echo -e "${RED}Could not determine RAM size. Aborting.${NC}"
        return 1
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
        return 0
    fi

    local zram_size
    if _confirm "ZRAM Size" "Use recommended size for ZRAM? (${half_ram_mb} MB out of ${RAM_SUMMARY})"; then
        zram_size=$half_ram_mb
    else
        zram_size=$(_inputbox "ZRAM Size" "Enter ZRAM size in MB:" 8 60 "$half_ram_mb")
        if [ -z "$zram_size" ] || ! [[ "$zram_size" =~ ^[0-9]+$ ]] || [ "$zram_size" -eq 0 ]; then
            echo "ZRAM configuration cancelled."
            return 0
        fi
    fi

    if ! _confirm "ZRAM Summary" "Algorithm: ${algo}\nSize: ${zram_size} MB\nPriority: 100\n\nApply?"; then
        echo "ZRAM configuration cancelled."
        return 0
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
