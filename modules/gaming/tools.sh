#!/usr/bin/env bash
# Gaming performance tools installation

install_mangohud() {
    _run_cmd "MangoHud" "sudo apt install -y mangohud" "Installing MangoHud..."
    if dpkg --print-foreign-architectures | grep -q i386; then
        echo "Installing 32-bit MangoHud..."
        _run_cmd "MangoHud" "sudo apt install -y mangohud:i386" "Installing 32-bit MangoHud..."
    fi
}

install_gamemode() {
    _run_install gamemode
}

install_goverlay() {
    _run_install goverlay
}

install_lutris() {
    _run_install lutris
}
