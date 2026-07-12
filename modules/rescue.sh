#!/usr/bin/env bash
# rescue.sh — UEFI boot repair and system rescue utilities

_rescue_boot_sb() {
    echo -e "${YELLOW}UEFI Secure Boot repair...${NC}"

    if [ ! -d /sys/firmware/efi ]; then
        echo -e "${RED}Not a UEFI system. Skipping.${NC}"
        _pause
        return
    fi

    local sb_state
    sb_state=$(mokutil --sb-state 2>/dev/null)
    if ! echo "$sb_state" | grep -qi "enabled"; then
        echo -e "${YELLOW}Secure Boot is not enabled. No refirm needed.${NC}"
        _pause
        return
    fi

    if ! _confirm "Secure Boot Repair" \
        "Secure Boot is enabled.\n\nReinstall and refirm shim-signed + GRUB?\n\nThis fixes boot issues where Debian is skipped\nin UEFI after kernel/driver changes."; then
        echo "Skipped."
        _pause
        return
    fi

    local efi_dir="/boot/efi"
    [ ! -d "$efi_dir" ] && efi_dir="/boot"

    _run_cmd "Refirm" \
        "sudo apt install --reinstall -y shim-signed grub-efi-amd64-signed linux-image-amd64" \
        "Reinstalling signed boot packages..."
    _run_cmd "GRUB Install" \
        "sudo grub-install --target=x86_64-efi --efi-directory=$efi_dir --bootloader-id=debian --recheck" \
        "Reinstalling GRUB to EFI partition..."
    _run_cmd "GRUB Config" \
        "sudo update-grub" \
        "Regenerating GRUB configuration..."

    echo -e "${GREEN}Boot repair complete. Reboot to verify.${NC}"
    _pause
}

_rescue_initramfs() {
    if ! _confirm "Initramfs" "Regenerate initramfs for all kernels?\n\nFixes boot issues caused by missing drivers\nor corrupted initrd images."; then
        echo "Skipped."
        _pause
        return
    fi
    _run_cmd "Initramfs" "sudo update-initramfs -u -k all" "Regenerating initramfs for all kernels..."
    echo -e "${GREEN}Initramfs regenerated.${NC}"
    _pause
}

# ----------------------------------------------------------------------
# GRUB helpers
# ----------------------------------------------------------------------

_set_grub_var() {
    local var="$1" val="$2" file="/etc/default/grub"
    if grep -q "^${var}=" "$file" 2>/dev/null; then
        sudo sed -i "s/^${var}=.*/${var}=${val}/" "$file"
    elif grep -q "^#${var}=" "$file" 2>/dev/null; then
        sudo sed -i "s/^#${var}=.*/${var}=${val}/" "$file"
    else
        echo "${var}=${val}" | sudo tee -a "$file" >/dev/null
    fi
}

_apply_grub_setting() {
    local timeout="$1" style="$2" recordfail="$3" os_prober="$4"
    local file="/etc/default/grub"
    local backup="${file}.backup.$(date +%Y%m%d_%H%M%S)"
    local override="/etc/default/grub.d/99_script_override.cfg"

    sudo cp "$file" "$backup"

    _set_grub_var GRUB_TIMEOUT "$timeout"
    _set_grub_var GRUB_TIMEOUT_STYLE "$style"
    _set_grub_var GRUB_RECORDFAIL_TIMEOUT "$recordfail"
    [ -n "$os_prober" ] && _set_grub_var GRUB_DISABLE_OS_PROBER "$os_prober"

    sudo mkdir -p /etc/default/grub.d
    if [ -n "$os_prober" ]; then
        cat << EOF | sudo tee "$override" > /dev/null
GRUB_TIMEOUT_STYLE=$style
GRUB_TIMEOUT=$timeout
GRUB_RECORDFAIL_TIMEOUT=$recordfail
GRUB_DISABLE_OS_PROBER=$os_prober
EOF
    else
        cat << EOF | sudo tee "$override" > /dev/null
GRUB_TIMEOUT=$timeout
GRUB_TIMEOUT_STYLE=$style
GRUB_RECORDFAIL_TIMEOUT=$recordfail
EOF
    fi

    local summary
    summary="Settings applied:\n\n"
    summary+="  GRUB_TIMEOUT=$timeout\n"
    summary+="  GRUB_TIMEOUT_STYLE=$style\n"
    summary+="  GRUB_RECORDFAIL_TIMEOUT=$recordfail\n"
    [ -n "$os_prober" ] && summary+="  GRUB_DISABLE_OS_PROBER=$os_prober\n"
    summary+="\nRunning update-grub..."

    echo -e "$summary"

    if sudo update-grub >/dev/null 2>&1; then
        _msg "GRUB Settings" \
            "GRUB settings applied successfully!\n\nBackup saved: ${backup}\n\nReboot to see the changes."
    else
        echo -e "${RED}update-grub failed. Restoring backup...${NC}"
        sudo cp "$backup" "$file"
        sudo rm -f "$override"
        _msg "Error" "update-grub failed.\nBackup restored from ${backup}\nOverride removed: ${override}."
    fi
}

_grub_menu_settings() {
    while true; do
        local choice
        choice=$(_menu "GRUB Boot Menu Settings" \
            "Configure when and how the GRUB menu appears${SCROLL_HINT}:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "Disable GRUB menu on start (Fastest boot)" \
            "2" "Faster boot (Show 3-sec countdown)" \
            "3" "Default boot (Show menu for 5 secs)" \
            "4" "Custom timeout (Input seconds)" \
            "5" "Back")

        [ -z "$choice" ] && return
        clear

        case "$choice" in
            1)
                if _confirm "Disable GRUB Menu" \
                    "GRUB menu will be hidden entirely for fastest boot.\n\nTo access the menu on next boot, press and hold ESC\nimmediately after powering on.\n\nProceed?"; then
                    _apply_grub_setting 0 hidden 0 true
                fi
                ;;
            2)
                _apply_grub_setting 3 menu 3 ""
                ;;
            3)
                _apply_grub_setting 5 menu 5 ""
                ;;
            4)
                local custom_timeout
                custom_timeout=$(whiptail --title "Custom GRUB Timeout" \
                    --inputbox "Enter the GRUB timeout in seconds.\n\nUse -1 for indefinite wait." \
                    10 60 "" 3>&1 1>&2 2>&3 || true)
                if [ -n "$custom_timeout" ]; then
                    if [[ "$custom_timeout" =~ ^-?[0-9]+$ ]]; then
                        _apply_grub_setting "$custom_timeout" menu "$custom_timeout" ""
                    else
                        _msg "Invalid Input" "Please enter a valid integer (e.g. 0, 5, -1)."
                    fi
                fi
                ;;
            5) return ;;
        esac
    done
}

rescue_boot() {
    while true; do
        local choice
        choice=$(_menu "Boot Rescue + GRUB Configuration" \
            "Select an operation${SCROLL_HINT}:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "GRUB Boot Menu Settings" \
            "2" "Refirm Secure Boot (shim + GRUB)" \
            "3" "Regenerate initramfs (all kernels)" \
            "4" "Return to main menu")

        [ -z "$choice" ] && return
        clear

        case "$choice" in
            1) _grub_menu_settings ;;
            2) _rescue_boot_sb ;;
            3) _rescue_initramfs ;;
            4) return ;;
        esac
    done
}
