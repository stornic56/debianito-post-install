#!/usr/bin/env bash
# Shared helpers for extras categories

_inst() {
    if is_installed "$1"; then echo " (installed)"; else echo ""; fi
}

_state() {
    is_installed "$1" && echo "ON" || echo "OFF"
}
