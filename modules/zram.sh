#!/usr/bin/env bash
# zram.sh - Configure compressed swap in RAM

install_zram() {
    echo -e "${YELLOW}ZRAM Configuration${NC}"

    if [ -z "$RAM_KB" ] || [ "$RAM_KB" -eq 0 ]; then
        echo -e "${RED}Could not determine RAM size. Aborting.${NC}"
        return 1
    fi

    local half_ram_mb=$((RAM_KB / 2 / 1024))

    local algo
    algo=$(whiptail --title "ZRAM Compression" --menu \
        "ZRAM compresses a portion of RAM to use as\nswap, effectively increasing available memory.\n\nChoose the compression algorithm:\n\nlz4:  Very fast, low CPU usage. Minimal latency.\n      Recommended for most users.\n\nzstd: Better compression ratio (10-20% more),\n      slightly higher CPU usage.\n\nPress Cancel to abort." \
        18 65 2 \
        "lz4"  "Fastest, lowest CPU usage (recommended)" \
        "zstd" "Best ratio, slightly more CPU" \
        3>&1 1>&2 2>&3)

    if [ -z "$algo" ]; then
        echo "ZRAM configuration cancelled."
        return 0
    fi

    local zram_size
    if whiptail --title "ZRAM Size" --yesno \
        "Use 50% of RAM for ZRAM? (${half_ram_mb} MB out of ${RAM_SUMMARY})\n\nChoose No to enter a custom size." 10 60; then
        zram_size=$half_ram_mb
    else
        zram_size=$(whiptail --title "ZRAM Size" --inputbox \
            "Enter ZRAM size in MB:" 8 60 "$half_ram_mb" 3>&1 1>&2 2>&3)
        if [ -z "$zram_size" ] || ! [[ "$zram_size" =~ ^[0-9]+$ ]]; then
            echo "ZRAM configuration cancelled."
            return 0
        fi
    fi

    if ! whiptail --title "ZRAM Summary" --yesno \
        "Algorithm:  ${algo}\nSize:       ${zram_size} MB (${RAM_SUMMARY} total)\nPriority:   100\n\nApply ZRAM configuration?" 13 60; then
        echo "ZRAM configuration cancelled."
        return 0
    fi

    echo -e "${YELLOW}Installing zram-tools...${NC}"
    sudo apt install -y zram-tools

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
}
