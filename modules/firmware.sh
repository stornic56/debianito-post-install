#!/usr/bin/env bash

install_firmware() {
    echo -e "${YELLOW}Installing base firmware...${NC}"
    local pkg="firmware-linux-nonfree"
    if [ "$(is_backports_enabled)" == true ]; then
        if whiptail --title "Firmware Backports" \
            --yesno "Backports is enabled.\nInstall firmware-linux-nonfree from backports (newer version)?" 10 60; then
            sudo apt install -y -t "${DEBIAN_CODENAME}-backports" $pkg
        else
            sudo apt install -y $pkg
        fi
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
