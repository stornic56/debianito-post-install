#!/usr/bin/env bash

# ── Global arrays ──
PCI_NET_DEVS=()
USB_WIFI_DEVS=()
PCI_BT_DEVS=()
USB_BT_DEVS=()
_DETECTED_FW_PKGS=()
_FW_PLAN_HW_LINES=()
_FW_PLAN_PKG_LINES=()

# ── Network device detection (PCI + USB) ──
_detect_all_network_devices() {
    ! is_installed pciutils && _run_install_pkg pciutils
    ! is_installed usbutils && _run_install_pkg usbutils

    PCI_NET_DEVS=()
    while IFS= read -r line; do
        PCI_NET_DEVS+=("$line")
    done < <(timeout 2 lspci -nn 2>/dev/null | grep -iE 'network controller|ethernet controller' || true)

    USB_WIFI_DEVS=()
    while IFS= read -r line; do
        if echo "$line" | grep -qiE 'wireless|wifi|802\.11|bluetooth|wlan'; then
            USB_WIFI_DEVS+=("$line")
        fi
    done < <(lsusb 2>/dev/null || true)

    PCI_BT_DEVS=()
    while IFS= read -r line; do
        PCI_BT_DEVS+=("$line")
    done < <(timeout 2 lspci -nn 2>/dev/null | grep -i 'Bluetooth controller' || true)

    USB_BT_DEVS=()
    while IFS= read -r line; do
        if echo "$line" | grep -qi 'bluetooth'; then
            if ! echo "$line" | grep -qiE 'wireless|wifi|802\.11|wlan'; then
                USB_BT_DEVS+=("$line")
            fi
        fi
    done < <(lsusb 2>/dev/null || true)

    _FW_PLAN_HW_LINES=()
    for dev in "${PCI_NET_DEVS[@]}"; do
        local desc dev_type
        desc=$(echo "$dev" | sed -E 's/^[^ ]+ [^:]+: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev.*\)//')
        if echo "$dev" | grep -qiE 'network controller|wireless|wi-fi|wlan|802\.11'; then
            dev_type="WiFi PCI"
        else
            dev_type="Ethernet PCI"
        fi
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (${dev_type})")
    done
    for dev in "${USB_WIFI_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed 's/^.*ID //')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (USB)")
    done

    for dev in "${PCI_BT_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed -E 's/^[^ ]+ [^:]+: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev.*\)//')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (Bluetooth PCI)")
    done
    for dev in "${USB_BT_DEVS[@]}"; do
        local desc
        desc=$(echo "$dev" | sed 's/^.*ID //')
        _FW_PLAN_HW_LINES+=("  \xe2\x97\x8f ${desc} (Bluetooth USB)")
    done
}

# ── Firmware package mapping ──
_detect_firmware_needs() {
    local -A pkg_info
    _DETECTED_FW_PKGS=()
    _FW_PLAN_PKG_LINES=()

    local dev_list
    dev_list=("${PCI_NET_DEVS[@]}" "${USB_WIFI_DEVS[@]}")

    for dev in "${dev_list[@]}"; do
        local raw_desc vendor_lc pkg
        raw_desc=$(echo "$dev" | sed -E 's/^[^ ]+ [^:]+: //; s/ \[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]//; s/ \(rev.*\)//')
        vendor_lc=$(echo "$dev" | sed -n 's/^.*]: //p' | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

        [[ "$vendor_lc" != *intel* && "$vendor_lc" != *realtek* && "$vendor_lc" != *atheros* && "$vendor_lc" != *qualcomm* && "$vendor_lc" != *mediatek* ]] && continue

        case "$vendor_lc" in
            *intel*)
                if echo "$dev" | grep -qiE 'wireless|wi-fi|wlan|802\.11'; then
                    pkg="firmware-iwlwifi"
                else
                    pkg="firmware-intel-misc"
                fi
                ;;
            *realtek*)       pkg="firmware-realtek" ;;
            *atheros*|*qualcomm*) pkg="firmware-atheros" ;;
            *mediatek*)      pkg="firmware-mediatek" ;;
        esac

        local short_dev
        short_dev=$(echo "$raw_desc" | sed 's/ *\[[^]]*\]//g; s/  */ /g')
        if [ -z "${pkg_info[$pkg]-}" ]; then
            pkg_info[$pkg]="$short_dev"
        else
            pkg_info[$pkg]+=", $short_dev"
        fi
    done

    for pkg in "${!pkg_info[@]}"; do
        _DETECTED_FW_PKGS+=("$pkg")
        _FW_PLAN_PKG_LINES+=("  [+] ${pkg}  \xe2\x86\x90 ${pkg_info[$pkg]}")
    done

    mapfile -t _DETECTED_FW_PKGS < <(printf '%s\n' "${_DETECTED_FW_PKGS[@]}" | sort -u)
}

# ── Build plan string ──
_build_firmware_plan() {
    local plan=""
    plan+="This section installs the essential non-free firmware stack\n"
    plan+="for Debian (including CPU microcode, GPU, network, and core\n"
    plan+="drivers). The script has scanned your hardware to prepare\n"
    plan+="the setup:\n\n"

    plan+="Detected controllers:\n"
    if [ ${#_FW_PLAN_HW_LINES[@]} -eq 0 ]; then
        plan+="  (none detected)\n"
    else
        for line in "${_FW_PLAN_HW_LINES[@]}"; do
            plan+="${line}\n"
        done
    fi

    plan+="\nPlanned firmware packages:\n"
    local fw_line
    if is_installed firmware-linux-nonfree; then
        local cur_ver
        cur_ver=$(dpkg -l firmware-linux-nonfree 2>/dev/null | awk '/^ii/{print $3}')
        fw_line="  [+] firmware-linux-nonfree ${cur_ver} (already installed)"
    else
        fw_line="  [+] firmware-linux-nonfree (base meta-package)"
    fi
    plan+="${fw_line}\n"

    for line in "${_FW_PLAN_PKG_LINES[@]}"; do
        plan+="${line}\n"
    done

    local has_bt=false
    [ ${#PCI_BT_DEVS[@]} -gt 0 ] && has_bt=true
    [ ${#USB_BT_DEVS[@]} -gt 0 ] && has_bt=true
    if ! $has_bt; then
        for dev in "${USB_WIFI_DEVS[@]}"; do
            if echo "$dev" | grep -qi 'bluetooth'; then
                has_bt=true; break
            fi
        done
    fi

    plan+="\nBluetooth:\n"
    if $has_bt; then
        if is_installed bluez; then
            plan+="  [+] bluez (already installed)\n"
        else
            plan+="  [+] bluez + bluez-tools + bluez-obexd (base stack)\n"
        fi
        case "${DESKTOP_ENV:-other}" in
            kde)   plan+="  [+] bluedevil (KDE applet)\n"
                   if [ "${AUDIO_SERVER:-}" = "pipewire" ]; then
                       plan+="  → pipewire-pulse + wireplumber (if missing)\n"
                   fi
                   ;;
            gnome) plan+="  (already in gnome-control-center)\n" ;;
            *)     plan+="  [+] blueman (GTK Bluetooth manager)\n" ;;
        esac
        plan+="  → Bluetooth service will be enabled\n"
    else
        plan+="  (no Bluetooth hardware detected)\n"
    fi

    plan+="\nInstallation order:\n"
    plan+="  1. Base firmware (firmware-linux-nonfree)\n"
    plan+="  2. Network firmware (realtek, iwlwifi, ...)\n"
    plan+="  3. Broadcom / Bluetooth firmware\n"

    echo -e "$plan"
}

# ── Install detected firmware packages ──
_install_detected_firmware() {
    local to_install=()
    for pkg in "${_DETECTED_FW_PKGS[@]}"; do
        if is_installed "$pkg"; then
            echo "  --> $pkg already installed."
            continue
        fi
        local ver
        ver=$(apt-cache policy "$pkg" 2>/dev/null | awk 'NR==3 {print $2; exit}')
        if [ -z "$ver" ] || [ "$ver" = "(none)" ]; then
            echo "  --> $pkg not available in repositories, skipping."
            continue
        fi
        to_install+=("$pkg")
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        _run_cmd "Firmware" "sudo DEBIAN_FRONTEND=noninteractive apt install -y ${to_install[*]}" \
            "Installing network firmware packages..."
    fi
}

# ── Wireless handler (Broadcom single-path wl) ──
_handle_wireless() {
    local installed_any=false
    local wl_build_failed=false

    if [ ${#PCI_NET_DEVS[@]} -eq 0 ] && [ ${#USB_WIFI_DEVS[@]} -eq 0 ]; then
        _detect_all_network_devices
    fi

    for dev in "${PCI_NET_DEVS[@]}"; do
        local bcm_id dev_id
        bcm_id=$(echo "$dev" | grep -oP '14e4:[0-9a-fA-F]+' || true)
        [ -z "$bcm_id" ] && continue
        dev_id=$(echo "$bcm_id" | cut -d: -f2 | tr '[:upper:]' '[:lower:]')

        # --- Verificación de headers ---
        if ! apt-cache policy linux-headers-amd64 2>/dev/null | grep -q "Candidate: [^ (none)]"; then
            _msg "Broadcom Error" "linux-headers-amd64 is not available. Cannot compile Broadcom driver.\n\nEnsure non-free repositories are enabled and run:\n  sudo apt install linux-headers-amd64"
            _pause
            continue
        fi

        # --- Confirmación ---
        local bcm_ver header_ver
        bcm_ver=$(apt-cache policy broadcom-sta-dkms 2>/dev/null | awk 'NR==3 {print $2}')
        header_ver=$(apt-cache policy linux-headers-amd64 2>/dev/null | awk 'NR==3 {print $2}')
        if ! _confirm "Broadcom WiFi" "Detected Broadcom wireless device.\n\nInstall broadcom-sta-dkms ${bcm_ver} + linux-headers-amd64 ${header_ver}?"; then
            continue
        fi

        # --- Instalación ---
        _run_cmd "Broadcom" "sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64 broadcom-sta-dkms" || true

        # --- Combo BT (sin cambios respecto al código actual) ---
        local has_broadcom_bt=false
        local btdev
        for btdev in "${PCI_BT_DEVS[@]}"; do
            if echo "$btdev" | grep -qi 'broadcom'; then
                has_broadcom_bt=true
                break
            fi
        done
        if $has_broadcom_bt; then
            echo -e "${YELLOW}[+] Broadcom WiFi+BT combo card detected.${NC}"
            sudo mkdir -p /etc/modprobe.d
            printf 'softdep wl post: btusb\n' | sudo tee /etc/modprobe.d/broadcom-combo.conf >/dev/null
            echo -e "${YELLOW}    A reboot may be required for Bluetooth support.${NC}"
        fi

        # --- Post-DKMS verification (Fix 5, sin cambios) ---
        if ! ls /lib/modules/$(uname -r)/updates/dkms/wl.ko* 2>/dev/null | grep -q .; then
            _msg "Broadcom DKMS Build Failed" "The wl module was not built by DKMS.\n\nPossible causes:\n- Missing build tools (build-essential, dkms)\n- Kernel update without headers\n- Incompatible kernel version\n\nTry: sudo dpkg-reconfigure broadcom-sta-dkms"
            if _confirm "Broadcom" "Rebuild the Broadcom driver now?"; then
                _run_cmd "Broadcom" "sudo dpkg-reconfigure broadcom-sta-dkms" || true
                if ls /lib/modules/$(uname -r)/updates/dkms/wl.ko* 2>/dev/null | grep -q .; then
                    # wl.ko existe tras reconfigure → continuar a limpieza/carga
                    :
                else
                    local dmesg_out
                    dmesg_out=$(sudo dmesg | tail -20 2>/dev/null || echo "(dmesg unavailable)")
                    _msg "Broadcom DKMS Still Failed" "dpkg-reconfigure did not produce wl.ko either.\n\nLast kernel messages:\n${dmesg_out}\n\nYou may need to check build logs or report a bug against broadcom-sta-dkms."
                    _pause
                    wl_build_failed=true
                    continue
                fi
            else
                wl_build_failed=true
                continue
            fi
        fi

        # --- Limpieza de módulos conflictivos + carga wl (patrón Mint) ---
        sudo modprobe -r b43 b43legacy b44 bcma brcmsmac brcmfmac ssb wl 2>/dev/null || true
        sudo modprobe wl 2>/dev/null

        # --- Verificación de carga ---
        if lsmod | grep -q '^wl '; then
            echo -e "${GREEN}[+] Broadcom WiFi activated (wl module loaded).${NC}"
            _pause
            installed_any=true
        else
            echo -e "${YELLOW}[+] Broadcom driver installed but wl module did not load.${NC}"
            echo -e "${YELLOW}    A system reboot is required.${NC}"
            _pause
            installed_any=true
        fi
    done

    # --- USB Broadcom (sin cambios) ---
    local usb_dev
    for usb_dev in "${USB_WIFI_DEVS[@]}"; do
        if echo "$usb_dev" | grep -qi '0a5c'; then
            _msg "USB Broadcom" "USB Broadcom device detected (0a5c).\n\nLinux does not have native drivers for most USB Broadcom WiFi chips.\nndiswrapper may be needed as a last resort."
            _pause
        fi
    done

    # --- Mensaje final (sin cambios) ---
    if ! $installed_any && ! $wl_build_failed; then
        echo "No special WiFi firmware needed -- base firmware-linux-nonfree covers this system."
        _pause
    fi
}

# ── Ensure non-free repository is enabled ──
# Token-exact check for the "non-free" component. "non-free-firmware"
# contains the substring but is a different component, so word-boundary
# matching (\b) would produce false positives.
_has_nonfree_component() {
    local file="$1"
    grep -qE '^[^#]*[[:space:]]non-free([[:space:]]|$)' "$file" 2>/dev/null
}

_ensure_nonfree_repo() {
    local nonfree_found=false
    if [ -f /etc/apt/sources.list ] && _has_nonfree_component /etc/apt/sources.list; then
        nonfree_found=true
    fi
    if ! $nonfree_found && [ -d /etc/apt/sources.list.d ]; then
        for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] || continue
            if _has_nonfree_component "$f"; then
                nonfree_found=true
                break
            fi
        done
    fi
    if $nonfree_found; then
        return 0
    fi

    if ! _confirm "non-free Repository" "Component 'non-free' (and 'non-free-firmware') is required for WiFi/Bluetooth/GPU firmware.\n\nAdd them to your APT repositories?"; then
        return 1
    fi

    # No active sources at all → bootstrap a complete configuration
    if ! has_active_deb_sources; then
        backup_current_repos
        if ! bootstrap_repositories "main contrib non-free non-free-firmware"; then
            return 1
        fi
    else
        if [ -f /etc/apt/sources.list ]; then
            # Add each missing component after "main", never duplicating
            sudo sed -i -E '/^deb / { /(^|[[:space:]])non-free([[:space:]]|$)/! s/(main[^[:space:]]*)/\1 non-free/ }' /etc/apt/sources.list
            # non-free-firmware does not exist on Bullseye
            if [ "$DEBIAN_VERSION" != "11" ]; then
                sudo sed -i -E '/^deb / { /(^|[[:space:]])non-free-firmware([[:space:]]|$)/! s/(main[^[:space:]]*)/\1 non-free-firmware/ }' /etc/apt/sources.list
            fi
        fi
        if [ -d /etc/apt/sources.list.d ]; then
            for f in /etc/apt/sources.list.d/*.sources; do
                [ -f "$f" ] || continue
                sudo sed -i -E '/^Components:/ { /(^|[[:space:]])non-free([[:space:]]|$)/! s/$/ non-free/ }' "$f"
                if [ "$DEBIAN_VERSION" != "11" ]; then
                    sudo sed -i -E '/^Components:/ { /(^|[[:space:]])non-free-firmware([[:space:]]|$)/! s/$/ non-free-firmware/ }' "$f"
                fi
            done
        fi
    fi

    # Verify the component was actually added before reporting success
    local nonfree_ok=false
    [ -f /etc/apt/sources.list ] && _has_nonfree_component /etc/apt/sources.list && nonfree_ok=true
    if ! $nonfree_ok && [ -d /etc/apt/sources.list.d ]; then
        for f in /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list; do
            [ -f "$f" ] || continue
            if _has_nonfree_component "$f"; then
                nonfree_ok=true
                break
            fi
        done
    fi
    if ! $nonfree_ok; then
        echo -e "${RED}Failed to enable non-free repository. Check your APT sources.${NC}"
        return 1
    fi

    sudo apt update
    echo -e "${GREEN}non-free repository enabled.${NC}"
    return 0
}

# ── Main entry point ──
install_firmware() {
    echo -e "${YELLOW}Base firmware check...${NC}"

    if ! _ensure_nonfree_repo; then
        _msg "Error" "No 'non-free' repositories were enabled and the user declined to add them.\nPlease enable non-free manually or accept the prompt in the Firmware option." 10 65
        return 1
    fi

    # 1. Detect
    _detect_all_network_devices
    _detect_firmware_needs

    # 2. Plan
    local plan
    plan=$(_build_firmware_plan)
    _msg "Firmware, Wireless & Bluetooth Setup" "$plan" 22 72

    # 3. Confirm
    if ! _confirm "Firmware" "Apply the network & firmware plan?"; then
        echo "Firmware installation skipped."
        return
    fi

    # 4. Install base firmware meta-package (unchanged logic)
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
    else
        local msg="firmware-linux-nonfree provides hardware drivers for:\n"
        msg+="  WiFi, Bluetooth, GPU, audio, webcams, and more.\n\n"
        if [ -n "$fw_bpo" ]; then
            msg+="  ● Stable:        ${fw_stable}\n"
            msg+="                     Ultra tested, but may lack support for\n"
            msg+="                     very recent hardware.\n\n"
            msg+="  ● Backports:     ${fw_bpo} (Recommended)\n"
            msg+="                     Updated firmware for modern hardware from\n"
            msg+="                     2025/2026: recent GPUs, processors, WiFi.\n\n"
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
    fi

    # 5. Install specific network firmware packages
    _install_detected_firmware

    # 6. Broadcom wireless handler
    _handle_wireless

    # 7. Bluetooth stack
    _install_bluetooth_stack

    # 8. Summary
    echo -e "${GREEN}Network & firmware setup complete.${NC}"
    _pause
}
