#!/usr/bin/env bash
# Shared helpers for GPU submodules

declare -A NVIDIA_FAMILY_MAP=(
    # Fermi / Kepler (Legacy: el shim se encarga de separarlos)
    ["06"]="legacy" ["0D"]="legacy" ["0E"]="legacy" 
    ["0F"]="legacy" ["10"]="legacy" ["11"]="legacy" ["12"]="legacy"
    # Maxwell
    ["13"]="maxwell" ["14"]="maxwell" ["16"]="maxwell" ["17"]="maxwell"
    # Pascal + Volta (Misma política de driver clásico)
    ["15"]="pascal" ["1B"]="pascal" ["1C"]="pascal" ["1D"]="pascal"
    # Turing
    ["1E"]="turing" ["1F"]="turing" ["21"]="turing"
    # Ampere
    ["20"]="ampere" ["22"]="ampere" ["24"]="ampere" ["25"]="ampere"
    # Hopper
    ["23"]="hopper"
    # Ada Lovelace
    ["26"]="ada" ["27"]="ada" ["28"]="ada"
    # Blackwell
    ["29"]="blackwell" ["2B"]="blackwell" ["2C"]="blackwell" 
    ["2D"]="blackwell" ["2E"]="blackwell" ["31"]="blackwell"
)

detect_nvidia_arch() {
    local pci_id="$1"
    local prefix="${pci_id:0:2}"
    echo "${NVIDIA_FAMILY_MAP[$prefix]:-unknown}"
}

_is_nvidia_kepler_id() {
    local dev_id="$1"
    [ -z "$dev_id" ] && return 1
    local dev_int=$((16#${dev_id,,}))
    [ "$dev_int" -ge $((16#0FC0)) ] && [ "$dev_int" -le $((16#0FFF)) ] && return 0
    [ "$dev_int" -ge $((16#1000)) ] && [ "$dev_int" -le $((16#103F)) ] && return 0
    [ "$dev_int" -ge $((16#1180)) ] && [ "$dev_int" -le $((16#11FF)) ] && return 0
    [ "$dev_int" -ge $((16#1280)) ] && [ "$dev_int" -le $((16#12BF)) ] && return 0
    return 1
}

is_nvidia_kepler()   { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "legacy" ]] && _is_nvidia_kepler_id "$NVIDIA_GPU_DEVICE_ID" && echo true || echo false; }
is_nvidia_fermi()    { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "legacy" ]] && ! _is_nvidia_kepler_id "$NVIDIA_GPU_DEVICE_ID" && echo true || echo false; }
is_nvidia_legacy()   { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "legacy" ]] && echo true || echo false; }
is_nvidia_maxwell()  { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "maxwell" ]] && echo true || echo false; }
is_nvidia_pascal()   { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "pascal" ]] && echo true || echo false; }
is_nvidia_volta()    { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "volta" ]] && echo true || echo false; }
is_nvidia_turing()   { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "turing" ]] && echo true || echo false; }
is_nvidia_ampere()   { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "ampere" ]] && echo true || echo false; }
is_nvidia_ada()      { [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "ada" ]] && echo true || echo false; }
is_nvidia_blackwell(){ [ -n "$NVIDIA_GPU_DEVICE_ID" ] && [[ "$(detect_nvidia_arch "$NVIDIA_GPU_DEVICE_ID")" == "blackwell" ]] && echo true || echo false; }

is_amd_legacy_gcn() {
    local dev_id
    dev_id=$(timeout 2 lspci -nn | grep -iE "VGA|3D" | grep -i amd | grep -oP '1002:\K[0-9a-fA-F]{4}' | head -n1)
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
