#!/usr/bin/env bash
# java.sh — Adoptium Temurin repository setup (extrepo) and Java version selectors
# License GPL v3

_enable_temurin_repo() {
    if [ -f /etc/apt/sources.list.d/extrepo_temurin.sources ]; then
        return 0
    fi
    if ! command -v extrepo &>/dev/null; then
        _run_cmd "extrepo" "sudo apt install -y extrepo" "Installing extrepo..."
    fi
    _run_cmd "Temurin" "sudo extrepo enable temurin" "Enabling Adoptium Temurin repository..."
    _run_cmd "APT Update" "sudo apt update" "Updating package lists..."
}

install_minecraft_java() {
    local choices
    choices=$(whiptail --title "Java Runtimes for Minecraft" --checklist \
        "Select Java version(s) to install:" 14 65 3 \
        "8"  "Java 8  — Classic mods & Minecraft <= 1.16.5" OFF \
        "17" "Java 17 — Minecraft 1.17 to 1.20.4" ON \
        "21" "Java 21 — Modern Minecraft >= 1.20.5 & 1.21+" OFF \
        3>&1 1>&2 2>&3)
    [ -z "$choices" ] && { echo "No Java version selected."; return; }
    _enable_temurin_repo
    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')
    for ver in $cleaned; do
        _run_cmd "Java" "sudo apt install -y temurin-${ver}-jre" \
            "Installing Temurin JRE ${ver}..."
    done
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
    _enable_temurin_repo
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
