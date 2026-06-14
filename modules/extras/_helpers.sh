#!/usr/bin/env bash
# Shared helpers for extras categories

_inst() {
    if is_installed "$1"; then echo " (installed)"; else echo ""; fi
}

_state() {
    is_installed "$1" && echo "ON" || echo "OFF"
}

_install_clamav() {
    if is_installed "clamav"; then
        echo "ClamAV already installed."
        return
    fi
    _run_install "clamav"
    echo -e "${GREEN}ClamAV installed.${NC}"

    if _confirm "ClamAV" "Update virus signatures now (freshclam)?"; then
        sudo systemctl stop clamav-freshclam 2>/dev/null || true
        sudo freshclam || true
        sudo systemctl start clamav-freshclam 2>/dev/null || true
    fi

    if _confirm "ClamAV" "Run quick scan on /bin to verify engine works?"; then
        echo "Running background scan on /bin..."
        sudo clamscan --recursive --infected /bin &
        echo "Scan running in background (PID $!). Check results later."
    fi
}
