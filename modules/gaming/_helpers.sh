#!/usr/bin/env bash
# Shared helpers for gaming submodules

_install_mesa_32bit() {
    local mesa_pkgs=(
        "mesa-vulkan-drivers" "mesa-vulkan-drivers:i386"
        "libgl1-mesa-dri"     "libgl1-mesa-dri:i386"
        "libglx-mesa0"        "libglx-mesa0:i386"
        "libegl-mesa0"        "libegl-mesa0:i386"
        "mesa-va-drivers"     "mesa-va-drivers:i386"
    )

    local ref_ver
    ref_ver=$(apt-cache policy mesa-vulkan-drivers:i386 2>/dev/null | awk 'NR==3 {print $2; exit}')
    local ref_bpo_ver
    ref_bpo_ver=$(apt-cache madison mesa-vulkan-drivers:i386 2>/dev/null | \
        grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    local comp_line="Components: Vulkan:i386, OpenGL:i386, GLX:i386, EGL:i386, VA-API:i386"

    if [ "$(is_backports_enabled)" == "true" ] && [ -n "$ref_bpo_ver" ]; then
        local bpo_pkgs=()
        local stable_pkgs=()

        for mpkg in "${mesa_pkgs[@]}"; do
            local bpo_ver
            bpo_ver=$(apt-cache madison "$mpkg" 2>/dev/null | \
                grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
            if [ -n "$bpo_ver" ]; then
                bpo_pkgs+=("$mpkg")
            else
                stable_pkgs+=("$mpkg")
            fi
        done

        local src_label="Debian ${DEBIAN_CODENAME^}-Backports"
        [ ${#stable_pkgs[@]} -gt 0 ] && src_label+=" + Stable"

        local msg="Mesa 32-bit drivers required for gaming.\n\n"
        msg+="Source: ${src_label}\n"
        msg+="Mesa ${ref_bpo_ver:-$ref_ver}\n"
        msg+="${comp_line}\n\n"
        [ ${#stable_pkgs[@]} -gt 0 ] && msg+="Some packages only available in stable.\n"
        msg+="Choose version:"

        if _confirm_custom "Mesa 32-bit" "$msg" "Backports" "Stable" 14 70; then
            _run_cmd "Mesa 32-bit" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${bpo_pkgs[*]}" \
                "Installing 32-bit Mesa from backports..."
            if [ ${#stable_pkgs[@]} -gt 0 ]; then
                _run_cmd "Mesa 32-bit" "sudo apt install -y ${stable_pkgs[*]}" \
                    "Installing remaining 32-bit Mesa from stable..."
            fi
        else
            _run_cmd "Mesa 32-bit" "sudo apt install -y ${mesa_pkgs[*]}" \
                "Installing 32-bit Mesa from stable..."
        fi
    else
        local msg="Mesa 32-bit drivers required for gaming.\n\n"
        msg+="Source: Debian Stable\n"
        msg+="Mesa ${ref_ver}\n"
        msg+="${comp_line}\n\n"
        msg+="Install Mesa 32-bit drivers?"
        if _confirm "Mesa 32-bit" "$msg" 14 70; then
            _run_cmd "Mesa 32-bit" "sudo apt install -y ${mesa_pkgs[*]}" \
                "Installing 32-bit Mesa..."
        fi
    fi
}
