#!/usr/bin/env bash
# kernel.sh — Submenu for kernel variants: Stable, RT, Cloud, Backports

show_kernel_menu() {
    while true; do
        local items=("stable" "Install linux-image-amd64")
        [ "$DEBIAN_VERSION" != "11" ] && items+=("backports" "Install from backports")
        items+=("rt" "Install linux-image-rt-amd64 (Preempt-RT)")
        items+=("cloud" "Install linux-image-cloud-amd64")
        items+=("back" "Return to main menu")

        local choice
        choice=$(_menu "Kernel Installation" "Select kernel variant:" \
            16 65 5 "${items[@]}")
        [ -z "$choice" ] && break
        clear

        case "$choice" in
            stable)    _install_kernel_package "linux-image-amd64" "Stable" "" ;;
            rt)        _install_kernel_package "linux-image-rt-amd64" "RT" "" ;;
            cloud)     _install_kernel_package "linux-image-cloud-amd64" "Cloud" "" ;;
            backports)
                if [ "$(is_backports_enabled)" != "true" ]; then
                    _msg "Kernel" "Backports repository is not enabled.\n\nUse option 3 (Configure repositories) to enable backports\nbefore installing the backports kernel."
                else
                    _install_kernel_package "linux-image-amd64" "Backports" \
                        "-t ${DEBIAN_CODENAME}-backports"
                fi
                ;;
            back) break ;;
        esac
    done
}

_install_kernel_package() {
    local pkg_base="$1"
    local flavor="$2"
    local bpo_flag="$3"

    if ! apt-cache show "$pkg_base" >/dev/null 2>&1; then
        _msg "Kernel" "Kernel not available for your current version of Debian.\n\nPackage: ${pkg_base}" 10 60
        return
    fi

    if [ "$flavor" = "Backports" ] && [ "$GPU_TYPE" = "nvidia" ]; then
        if ! _confirm "Kernel" "WARNING: Backports kernel changes the kernel version.\nYour NVIDIA driver will need recompilation (DKMS).\n\nProceed?"; then
            echo "Skipping."; return
        fi
    fi
    if [ "$flavor" = "RT" ] && [ "$GPU_TYPE" = "nvidia" ]; then
        _msg "Kernel — RT" "Note: Ensure your NVIDIA driver supports the RT (Preempt-RT) kernel.\nSome proprietary drivers may not work correctly." 10 60
    fi

    local headers_pkg="${pkg_base/linux-image-/linux-headers-}"
    local ver headers_ver
    if [ -n "$bpo_flag" ]; then
        ver=$(apt-cache madison "$pkg_base" 2>/dev/null | grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
        headers_ver=$(apt-cache madison "$headers_pkg" 2>/dev/null | grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    else
        ver=$(apt-cache show "$pkg_base" 2>/dev/null | sed -n 's/^Version: //p' | grep -v '~bpo' | head -1)
        headers_ver=$(apt-cache show "$headers_pkg" 2>/dev/null | sed -n 's/^Version: //p' | grep -v '~bpo' | head -1)
    fi
    [ -n "$ver" ] && ver=" ($ver)"
    [ -n "$headers_ver" ] && headers_ver=" ($headers_ver)"
    local summary="Install ${flavor} kernel?\n  Image:   ${pkg_base}${ver}\n  Headers: ${headers_pkg}${headers_ver}"
    [ -n "$bpo_flag" ] && summary+="\n  From:    ${DEBIAN_CODENAME^}-backports"

    if ! _confirm "Kernel — ${flavor}" "$summary"; then
        echo "Skipping."; return
    fi

    _run_cmd "Kernel" "sudo apt install -y ${bpo_flag} ${pkg_base} ${headers_pkg}" \
        "Installing ${flavor} kernel + headers..."

    echo -e "${GREEN}${flavor} kernel installed. Reboot to use it.${NC}"
    _pause
}
