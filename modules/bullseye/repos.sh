#!/usr/bin/env bash
# repos.sh — Bullseye: repos clásicos con archive phase
# License GPL v3

configure_repos_bullseye() {
    while true; do
        local repo_choice
        repo_choice=$(_menu "Configure Repositories — Bullseye" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "1" "Enable Contrib & Non-Free Components" \
            "2" "Migrate to SID/Testing branch" \
            "3" "Back to main menu")
        [ -z "$repo_choice" ] && break
        clear
        case "$repo_choice" in
            1) _repos_enable_components ;;
            2) _branch_migration || true ;;
            3) break ;;
        esac
    done
}
