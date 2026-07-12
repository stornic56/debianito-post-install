#!/usr/bin/env bash
# themes.sh — Customization submenu dispatcher

_cat_customization() {
    local sub
    sub=$(_menu "Customization System" "Select type:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "1" "Desktop Themes (GTK/KDE)" \
        "2" "Icon Themes" \
        "3" "Cursor Themes" \
        "4" "Fonts" \
        )
    [ -z "$sub" ] && return
    case $sub in
        1) _cat_themes ;;
        2) _cat_icons ;;
        3) _cat_cursors ;;
        4) _cat_fonts ;;
    esac
}
