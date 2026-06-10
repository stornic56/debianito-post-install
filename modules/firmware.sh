#!/usr/bin/env bash

install_firmware() {
    echo -e "${YELLOW}Base firmware check...${NC}"

    local fw_pkg="firmware-linux-nonfree"
    local fw_bpo
    fw_bpo=$(apt-cache madison "$fw_pkg" 2>/dev/null | \
        grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)

    local fw_stable
    fw_stable=$(apt-cache policy "$fw_pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')

    if is_installed "$fw_pkg"; then
        if [ -n "$fw_bpo" ]; then
            local current_ver
            current_ver=$(dpkg -l "$fw_pkg" 2>/dev/null | awk '/^ii/{print $3}')
            if _confirm "Firmware" "firmware-linux-nonfree ${current_ver} already installed.\n\nUpgrade to backports version ${fw_bpo}?\n\nBackports often includes newer hardware support."; then
                _run_cmd "Firmware" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $fw_pkg" "Upgrading firmware..."
            fi
        else
            echo "$fw_pkg already installed."
        fi
        handle_wifi_firmware
        return
    fi

    local msg="firmware-linux-nonfree provides hardware drivers for:\n"
    msg+="  WiFi, Bluetooth, GPU, audio, webcams, and more.\n\n"
    if [ -n "$fw_bpo" ]; then
        msg+="  Backports: ${fw_bpo} (newer, recommended)\n"
        msg+="  Stable:    ${fw_stable}\n\n"
        msg+="Choose version:"
        if _confirm_custom "Firmware" "$msg" "Backports" "Stable"; then
            _run_cmd "Firmware" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports $fw_pkg" "Installing firmware from backports..."
        else
            _run_cmd "Firmware" "sudo apt install -y $fw_pkg" "Installing firmware from stable..."
        fi
    else
        msg+="  Version: ${fw_stable}\n\n"
        msg+="Install it?"
        if _confirm "Firmware" "$msg"; then
            _run_cmd "Firmware" "sudo apt install -y $fw_pkg" "Installing firmware..."
        fi
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
            _run_install_pkg firmware-brcm80211
        else
            # Offer to install broadcom-sta-dkms for older chips
            local bcm_ver
            bcm_ver=$(apt-cache policy broadcom-sta-dkms 2>/dev/null | awk 'NR==3 {print $2; exit}')
            local header_ver
            header_ver=$(apt-cache policy linux-headers-$(uname -r) 2>/dev/null | awk 'NR==3 {print $2; exit}')
            if _confirm "Broadcom WiFi" "Install Broadcom driver?\n\nRequired for this chipset. Compiles a kernel module.\n\n  broadcom-sta-dkms          ${bcm_ver:-unknown}\n  linux-headers-$(uname -r)  ${header_ver:-unknown}\n\nProceed?"; then
                _run_cmd "Broadcom" "sudo apt install -y linux-headers-$(uname -r) broadcom-sta-dkms" "Installing Broadcom driver..."
                echo "Broadcom proprietary driver installed. A reboot may be required."
            else
                echo "Skipping Broadcom driver installation."
            fi
        fi
    else
        echo "No special WiFi firmware needed for this adapter."
    fi
}
