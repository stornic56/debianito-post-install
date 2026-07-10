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

rescue_boot() {
    while true; do
        local choice
        choice=$(_menu "Boot Rescue & Repair" \
            "Select a rescue operation${SCROLL_HINT}:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "Refirm Secure Boot (shim + GRUB)" \
            "2" "Regenerate initramfs (all kernels)" \
            "3" "Return to main menu")

        [ -z "$choice" ] && return
        clear

        case "$choice" in
            1) _rescue_boot_sb ;;
            2) _rescue_initramfs ;;
            3) return ;;
        esac
    done
}
