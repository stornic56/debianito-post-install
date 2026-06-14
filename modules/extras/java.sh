#!/usr/bin/env bash
# java.sh — Adoptium Temurin repository setup and Java version selectors
# License GPL v3

_ensure_adoptium_repo() {
    [ -f /etc/apt/sources.list.d/adoptium.list ] && return 0

    local deps=()
    ! is_installed "wget"                && deps+=("wget")
    ! is_installed "apt-transport-https" && deps+=("apt-transport-https")
    ! is_installed "gpg"                 && deps+=("gpg")
    [ ${#deps[@]} -gt 0 ] && _run_install_batch "${deps[@]}"

    wget -qO - "https://packages.adoptium.net/artifactory/api/gpg/key/public" \
        | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg 2>/dev/null

    local codename
    codename=$(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release)
    echo "deb https://packages.adoptium.net/artifactory/deb ${codename} main" \
        | sudo tee /etc/apt/sources.list.d/adoptium.list > /dev/null

    sudo apt update \
        -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/adoptium.list \
        -o Dir::Etc::sourceparts="-" \
        2>/dev/null || true
}

_install_gaming_java() {
    local ver
    ver=$(whiptail --title "Java Runtimes for Gaming" --menu \
        "Select Java version:" 12 65 3 \
        "8"  "Java 8  — For classic mods & Minecraft <= 1.16.5" \
        "17" "Java 17 — For Minecraft era 1.17 to 1.20.4" \
        "21" "Java 21 — For modern Minecraft >= 1.20.5 & 1.21+" \
        3>&1 1>&2 2>&3)
    [ -z "$ver" ] && { echo "No Java version selected."; return; }
    _ensure_adoptium_repo
    _run_install "temurin-${ver}-jre"
}

_install_dev_java() {
    local ver
    ver=$(whiptail --title "Java Development Kits (JDK)" --menu \
        "Select JDK version:" 12 60 3 \
        "17" "Java 17 LTS Development Kit" \
        "21" "Java 21 LTS Development Kit" \
        "25" "Java 25 LTS Development Kit" \
        3>&1 1>&2 2>&3)
    [ -z "$ver" ] && { echo "No JDK version selected."; return; }
    _ensure_adoptium_repo
    _run_install "temurin-${ver}-jdk"
}

_any_jdk_installed_desc() {
    local inst
    inst=$(dpkg -l 'temurin-*-jdk' 2>/dev/null | awk '/^ii/ {print $2; exit}')
    [ -n "$inst" ] && echo " ($inst installed)" || echo ""
}

_any_jdk_state() {
    dpkg -l 'temurin-*-jdk' 2>/dev/null | grep -q '^ii' && echo "ON" || echo "OFF"
}
