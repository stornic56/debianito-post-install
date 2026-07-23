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
    # Bloque 4: GK208/GK208B (completo) — 0x1280..0x12BF
    if [ "$dev_int" -ge $((16#1280)) ] && [ "$dev_int" -le $((16#12BF)) ]; then echo true; return; fi

    echo false
}

is_nvidia_fermi() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # GF100 / GF110 — GTX 480, GTX 580, Quadro 6000, Tesla C2050
    if [ "$dev_int" -ge $((16#06C0)) ] && [ "$dev_int" -le $((16#06DF)) ]; then echo true; return; fi
    # GF104 / GF114 — GTS 450, GTX 460M, GT 555M
    if [ "$dev_int" -ge $((16#0DC0)) ] && [ "$dev_int" -le $((16#0DCF)) ]; then echo true; return; fi
    # GF104 / GF108 — GT 445M, GT 435M, GT 550M
    if [ "$dev_int" -ge $((16#0DD0)) ] && [ "$dev_int" -le $((16#0DDF)) ]; then echo true; return; fi
    # GF108 — GT 440, GT 430, GT 520, GT 610, GT 620M, NVS 5400M
    if [ "$dev_int" -ge $((16#0DE0)) ] && [ "$dev_int" -le $((16#0DEF)) ]; then echo true; return; fi
    # GF108 — GT 525M, GT 540M, GT 550M, Quadro 600, Quadro 500M
    if [ "$dev_int" -ge $((16#0DF0)) ] && [ "$dev_int" -le $((16#0DFF)) ]; then echo true; return; fi
    # GF104 / GF114 — GTX 460, GTX 470M, GTX 485M
    if [ "$dev_int" -ge $((16#0E22)) ] && [ "$dev_int" -le $((16#0E31)) ]; then echo true; return; fi
    # GF119 — GT 520M, GT 610M, NVS 4200M
    if [ "$dev_int" -ge $((16#1050)) ] && [ "$dev_int" -le $((16#105F)) ]; then echo true; return; fi
    # GF110 — GTX 580, GTX 570, GTX 560 Ti, GTX 590
    if [ "$dev_int" -ge $((16#1080)) ] && [ "$dev_int" -le $((16#108F)) ]; then echo true; return; fi
    # GF110 — Tesla M2090, Quadro 5010M, Quadro 7000
    if [ "$dev_int" -ge $((16#1090)) ] && [ "$dev_int" -le $((16#109F)) ]; then echo true; return; fi
    # GF116 / GF119 — GTX 560, GTX 460 v2, GTX 555, GT 645
    if [ "$dev_int" -ge $((16#1200)) ] && [ "$dev_int" -le $((16#120F)) ]; then echo true; return; fi
    # GF116 / GF108 — GTX 550 Ti, GTS 450 rev, GT 545, GT 640 (Fermi)
    if [ "$dev_int" -ge $((16#1240)) ] && [ "$dev_int" -le $((16#124F)) ]; then echo true; return; fi
    echo false
}

is_nvidia_maxwell() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # GM108/GM107/GM204 — gama media/baja + Quadros M (incluye 980M/970M)
    if [ "$dev_int" -ge $((16#1340)) ] && [ "$dev_int" -le $((16#13FF)) ]; then echo true; return; fi
    # GM206 — GTX 960, GTX 950, Quadro M2000
    if [ "$dev_int" -ge $((16#1400)) ] && [ "$dev_int" -le $((16#14FF)) ]; then echo true; return; fi
    # GM200 — TITAN X, GTX 980 Ti
    if [ "$dev_int" -ge $((16#17C0)) ] && [ "$dev_int" -le $((16#17CF)) ]; then echo true; return; fi
    # GM200 profesional — Quadro M6000, Tesla M40
    if [ "$dev_int" -ge $((16#17F0)) ] && [ "$dev_int" -le $((16#17FF)) ]; then echo true; return; fi

    echo false
}

is_nvidia_pascal() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # GP100 — Tesla P100, Quadro GP100
    if [ "$dev_int" -ge $((16#15F0)) ] && [ "$dev_int" -le $((16#15FF)) ]; then echo true; return; fi
    # GP102 — TITAN Xp, GTX 1080 Ti, Tesla P40, Quadro P6000
    if [ "$dev_int" -ge $((16#1B00)) ] && [ "$dev_int" -le $((16#1B3F)) ]; then echo true; return; fi
    # GP104 — GTX 1080, GTX 1070, Quadro P5000/P4000/P5200/P4200
    if [ "$dev_int" -ge $((16#1B80)) ] && [ "$dev_int" -le $((16#1BBF)) ]; then echo true; return; fi
    # GP106 + GP107 — GTX 1060, GTX 1050 Ti, GTX 1050, Quadro P2000/P1000/P620/P600
    if [ "$dev_int" -ge $((16#1C00)) ] && [ "$dev_int" -le $((16#1CFF)) ]; then echo true; return; fi
    # GP108 — GT 1030, GT 1010, MX150/250/350/330, Quadro P520
    if [ "$dev_int" -ge $((16#1D00)) ] && [ "$dev_int" -le $((16#1D7F)) ]; then echo true; return; fi

    echo false
}

is_nvidia_blackwell() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i nvidia | grep -oP '10de:\K[0-9a-fA-F]+' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local dev_int
    dev_int=$((16#${dev_id,,}))

    # Blackwell (GB20x) rango bajo: 0x2900 – 0x29BF
    if [ "$dev_int" -ge $((16#2900)) ] && [ "$dev_int" -le $((16#29BF)) ]; then echo true; return; fi
    # Blackwell (GB20x) rango alto: 0x2B80 – 0x31DF
    if [ "$dev_int" -ge $((16#2B80)) ] && [ "$dev_int" -le $((16#31DF)) ]; then echo true; return; fi

    echo false
}

is_amd_legacy_gcn() {
    local dev_id
    dev_id=$(lspci -nn | grep -iE "VGA|3D" | grep -i amd | grep -oP '1002:\K[0-9a-fA-F]{4}' | head -n1)
    [ -z "$dev_id" ] && { echo false; return; }

    local legacy_ids
    legacy_ids="6660|6664|6665|6667|6780|6784|6788|678a|6798|679a|679e|679f|3000|3001|6808|6809|6810|6811|6816|6817|6818|6819|6828|6829|682b|682c|6835|6837|683d|683f|6608|6609|6610|6611|6613|6617|1dcf|983d|6646|6649|664d|6650|6651|6658|665c|665d|67a0|67a1|67a2|67a8|67a9|67aa|67b0|67b1|67b8|67be|9830|9831|9832|9833|9834|9835|9836|9837|9838|9839|1304|1305|1306|1307|1309|130a|130b|130c|130d|130e|130f|1310|1311|1312|1313|1315|1316|1317|1318|131b|131c|131d|9850|9851|9852|9853|9854|9855|9856|9857|9858|9859|985a|985b|985c|985d|985e|985f"

    if echo "$dev_id" | grep -qiE "^(${legacy_ids})$"; then
        echo true
    else
        echo false
    fi
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

    # Mesa >= 25.3.3 unificó VA-API dentro de mesa-libgallium.
    # mesa-va-drivers desde backports rompe con la nueva mesa-libgallium.
    local _bpo_filtered=()
    for _p in "${bpo_pkgs[@]}"; do
        [ "$_p" != "mesa-va-drivers" ] && _bpo_filtered+=("$_p")
    done
    bpo_pkgs=("${_bpo_filtered[@]}")

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
    if [ "$DEBIAN_VERSION" = "11" ]; then
        if ! lsmod 2>/dev/null | grep -q "^nvidia "; then
            echo "nvtop skipped on Bullseye — NVIDIA driver not loaded."
            return
        fi
    fi
    local tool_pkgs
    tool_pkgs=$(pkg_versions nvtop vainfo)
    if _confirm "GPU Tools" "Install monitoring and info tools?\n\n${tool_pkgs}"; then
        _run_cmd "GPU Tools" "sudo apt install -y nvtop vainfo" "Installing GPU tools..."
        vainfo
        _pause "vainfo output shown above."
    else
        echo "Skipping GPU monitoring tools."
    fi
}
