#!/usr/bin/env bash
# Shared helpers for GPU submodules

is_nvidia_kepler() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # Bloque 1: GK107 (escritorio + móvil) — 0x0FC0..0x0FFF
    if [ "$dev_int" -ge $((16#0FC0)) ] && [ "$dev_int" -le $((16#0FFF)) ]; then echo true; return; fi
    # Bloque 2: GK110/GK110B/GK210 acotado puro — 0x1000..0x103F
    if [ "$dev_int" -ge $((16#1000)) ] && [ "$dev_int" -le $((16#103F)) ]; then echo true; return; fi
    # Bloque 3: GK104/GK106 (completo) — 0x1180..0x11FF
    if [ "$dev_int" -ge $((16#1180)) ] && [ "$dev_int" -le $((16#11FF)) ]; then echo true; return; fi
    # Bloque 4: GK208/GK208B acotado — 0x1280..0x12BF
    if [ "$dev_int" -ge $((16#1280)) ] && [ "$dev_int" -le $((16#12BF)) ]; then echo true; return; fi

    echo false
}

is_nvidia_maxwell() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # GM108 (GT 830M, GT 840M, GT 940M)
    if [ "$dev_int" -ge $((16#1340)) ] && [ "$dev_int" -le $((16#134F)) ]; then echo true; return; fi
    # GM107 (GTX 750 Ti, GTX 860M)
    if [ "$dev_int" -ge $((16#1380)) ] && [ "$dev_int" -le $((16#138F)) ]; then echo true; return; fi
    # GM200 (TITAN X, GTX 980 Ti)
    if [ "$dev_int" -ge $((16#13C0)) ] && [ "$dev_int" -le $((16#13CF)) ]; then echo true; return; fi
    # GM204 (GTX 980, GTX 970)
    if [ "$dev_int" -ge $((16#13D0)) ] && [ "$dev_int" -le $((16#13DF)) ]; then echo true; return; fi
    # GM206 (GTX 960, GTX 950)
    if [ "$dev_int" -ge $((16#1480)) ] && [ "$dev_int" -le $((16#148F)) ]; then echo true; return; fi

    echo false
}

is_nvidia_pascal() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # GP100 (Tesla P100, Quadro GP100)
    if [ "$dev_int" -ge $((16#15F0)) ] && [ "$dev_int" -le $((16#15FF)) ]; then echo true; return; fi
    # GP104 (GTX 1080, GTX 1070)
    if [ "$dev_int" -ge $((16#1B00)) ] && [ "$dev_int" -le $((16#1B1F)) ]; then echo true; return; fi
    # GP102 (TITAN Xp, GTX 1080 Ti)
    if [ "$dev_int" -ge $((16#1B80)) ] && [ "$dev_int" -le $((16#1B8F)) ]; then echo true; return; fi
    # GP106 (GTX 1060)
    if [ "$dev_int" -ge $((16#1C00)) ] && [ "$dev_int" -le $((16#1C2F)) ]; then echo true; return; fi
    # GP107 (GTX 1050 Ti, GTX 1050)
    if [ "$dev_int" -ge $((16#1C80)) ] && [ "$dev_int" -le $((16#1C8F)) ]; then echo true; return; fi
    # GP108 (GT 1030, GT 1010)
    if [ "$dev_int" -ge $((16#1D00)) ] && [ "$dev_int" -le $((16#1DFF)) ]; then echo true; return; fi

    echo false
}

_install_mesa_backports() {
    if [ "$(is_backports_enabled)" != "true" ]; then
        install_mesa_stable
        return
    fi

    local mesa_pkgs=("mesa-vulkan-drivers" "libgl1-mesa-dri" "libglx-mesa0" "libegl-mesa0" "mesa-va-drivers")
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

    local ref_ver
    ref_ver=$(apt-cache policy mesa-vulkan-drivers 2>/dev/null | awk 'NR==3 {print $2; exit}')
    local ref_bpo_ver
    ref_bpo_ver=$(apt-cache madison mesa-vulkan-drivers 2>/dev/null | \
        grep "${DEBIAN_CODENAME}-backports" | awk '{print $3}' | head -1)
    local comp_line="Components: Vulkan, OpenGL, GLX, EGL, VA-API (64-bit)"

    if [ ${#bpo_pkgs[@]} -gt 0 ]; then
        local src_label="Debian ${DEBIAN_CODENAME^}-Backports"
        [ ${#stable_pkgs[@]} -gt 0 ] && src_label+=" + Stable"
        local msg="Mesa provides OpenGL/Vulkan/VA-API acceleration.\n\n"
        msg+="Source: ${src_label}\n"
        msg+="Mesa ${ref_bpo_ver:-$ref_ver}\n"
        msg+="${comp_line}\n\n"
        [ ${#stable_pkgs[@]} -gt 0 ] && msg+="Some packages only available in stable.\n"
        msg+="Choose version for backports-capable packages:"
        if _confirm_custom "Mesa (Graphics)" "$msg" "Backports" "Stable" 14 70; then
            _run_cmd "Mesa (backports)" "sudo apt install -y -t ${DEBIAN_CODENAME}-backports ${bpo_pkgs[*]}" \
                "Installing Mesa from backports..."
            if [ ${#stable_pkgs[@]} -gt 0 ]; then
                _run_cmd "Mesa (stable)" "sudo apt install -y ${stable_pkgs[*]}" \
                    "Installing remaining Mesa packages from stable..."
            fi
        else
            _run_cmd "Mesa" "sudo apt install -y ${mesa_pkgs[*]}" \
                "Installing Mesa from stable..."
        fi
    else
        local msg="Mesa provides OpenGL/Vulkan/VA-API acceleration.\n\n"
        msg+="Source: Debian Stable\n"
        msg+="Mesa ${ref_ver}\n"
        msg+="${comp_line}\n\n"
        msg+="Install Mesa from available repositories?"
        if _confirm "Mesa (Graphics)" "$msg" 14 70; then
            _run_cmd "Mesa" "sudo apt install -y ${mesa_pkgs[*]}" \
                "Installing Mesa..."
        fi
    fi
}

install_mesa_stable() {
    local mesa_pkgs=("mesa-vulkan-drivers" "libgl1-mesa-dri" "libglx-mesa0" "libegl-mesa0" "mesa-va-drivers")
    _run_cmd "Mesa" "sudo apt install -y ${mesa_pkgs[*]}" "Installing Mesa from stable..."
}

offer_generic_tools() {
    local tool_pkgs
    tool_pkgs=$(pkg_versions nvtop vainfo)
    if _confirm "GPU Tools" "Install monitoring and info tools?\n\n${tool_pkgs}"; then
        _run_cmd "GPU Tools" "sudo apt install -y nvtop vainfo" "Installing GPU tools..."
        vainfo
    else
        echo "Skipping GPU monitoring tools."
    fi
}
