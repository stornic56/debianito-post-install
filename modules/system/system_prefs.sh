#!/usr/bin/env bash
# system_prefs.sh — System Preferences: time, locale, keyboard, audio

_prefs_date_time() {
    echo -e "${YELLOW}Current system date/time:${NC} $(date '+%Y-%m-%d %H:%M')"
    echo -e "${YELLOW}Timezone:${NC} $(timedatectl show -p Timezone --value 2>/dev/null || echo unknown)"

    if _confirm "Timezone" "Change the system timezone (dpkg-reconfigure tzdata)?"; then
        sudo env LC_ALL=C LANGUAGE=C dpkg-reconfigure tzdata || true
        echo -e "${GREEN}Timezone: $(timedatectl show -p Timezone --value 2>/dev/null)${NC}"
    fi
    _ensure_time_synced
}

_prefs_locale_keyboard() {
    sudo env LC_ALL=C LANGUAGE=C dpkg-reconfigure locales || true
    sudo env LC_ALL=C LANGUAGE=C dpkg-reconfigure keyboard-configuration || true
    echo -e "${GREEN}Language, locales and keyboard configured.${NC}"
}

_prefs_audio() { _prefs_audio_menu; }

_system_preferences_menu() {
    while true; do
        local choice
        choice=$(_menu "System Preferences" "Select a preference group:" \
            $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
            "1" "Date, Time & Timezone" \
            "2" "Language, Locales & Keyboard" \
            "3" "Audio & Sound Stack" \
            "4" "Back to main menu")
        [ -z "$choice" ] && return
        clear
        case "$choice" in
            1) _prefs_date_time ;;
            2) _prefs_locale_keyboard ;;
            3) _prefs_audio ;;
            4) return ;;
        esac
    done
}