#!/usr/bin/env bash

install_firmware() {
    local fw_pkgs=""
    local fw_bpo
    fw_bpo=$(apt-cache madison firmware-linux-nonfree 2>/dev/null | \
        grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    if [ -n "$fw_bpo" ]; then
        local fw_stable
        fw_stable=$(apt-cache policy firmware-linux-nonfree 2>/dev/null | awk 'NR==3 {print $2; exit}')
        fw_pkgs="  - firmware-linux-nonfree  ${fw_bpo} (backports) / ${fw_stable} (stable)\n"
    else
        local fw_ver
        fw_ver=$(apt-cache policy firmware-linux-nonfree 2>/dev/null | awk 'NR==3 {print $2; exit}')
        fw_pkgs="  - firmware-linux-nonfree  ${fw_ver}\n"
    fi
    if ! whiptail --title "Base Firmware" --yesno \
        "Install the following package?\n\n${fw_pkgs}\nProvides firmware for various hardware components.\n\nProceed?" 14 65; then
        echo "Skipping base firmware."
        return
    fi

    echo -e "${YELLOW}Installing base firmware...${NC}"
    local pkg="firmware-linux-nonfree"
    if [ "$(is_backports_enabled)" == true ] && [ -n "$fw_bpo" ]; then
        sudo apt install -y -t "${DEBIAN_CODENAME}-backports" $pkg
    else
        sudo apt install -y $pkg
    fi

    echo -e "${GREEN}Base firmware installed.${NC}"

    handle_wifi_firmware
}

# ---------------------------
# Specific WiFi firmware
# ---------------------------
handle_wifi_firmware() {
    if [ -z "$WIFI_CHIPSET" ] || [ "$WIFI_CHIPSET" = "No WiFi adapter found" ]; then
        echo "No WiFi adapter to configure."
        return
    fi

    echo "Detected WiFi: $WIFI_CHIPSET"

    # Broadcom IDs often start with 14e4:
    local broadcom_id
    broadcom_id=$(lspci -nn | grep -i network | grep -oP '14e4:[0-9a-fA-F]+' | head -n1)
    if [ -n "$broadcom_id" ]; then
        echo -e "${YELLOW}Broadcom wireless device found (ID: $broadcom_id)${NC}"

        # List of device IDs supported by brcmsmac/brcmfmac
        local supported_ids="4357 4358 4360 4727 43a0 43a1 43a2 43b1"
        local device_id
        device_id=$(echo "$broadcom_id" | cut -d: -f2)

        if echo "$supported_ids" | grep -qw "$device_id"; then
            echo "Chipset supported by firmware-brcm80211. Installing..."
            sudo apt install -y firmware-brcm80211
        else
            # Offer to install broadcom-sta-dkms for older chips
            if whiptail --title "Broadcom WiFi" \
                --yesno "Your Broadcom chipset may require the proprietary driver (broadcom-sta-dkms).\nThis will also install linux-headers and compile a kernel module.\n\nInstall broadcom-sta-dkms?" 12 70; then
                sudo apt install -y linux-headers-$(uname -r) broadcom-sta-dkms
                echo "Broadcom proprietary driver installed. A reboot may be required."
            else
                echo "Skipping Broadcom driver installation."
            fi
        fi
    else
        echo "No special WiFi firmware needed for this adapter."
    fi
}
