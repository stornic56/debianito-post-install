#!/usr/bin/env bash

source "${MODULES_DIR}/repos/migrate.sh" 2>/dev/null || true

# State for backup/restore
REPO_BACKUP_DIR=""

backup_current_repos() {
    REPO_BACKUP_DIR=$(mktemp -d)
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources \
             /etc/apt/sources.list.d/debian-backports.list /etc/apt/sources.list.d/debian-backports.sources; do
        if [ -f "$f" ]; then
            mkdir -p "$REPO_BACKUP_DIR/$(dirname "${f#/etc/apt/}")"
            cp "$f" "$REPO_BACKUP_DIR/$(dirname "${f#/etc/apt/}")/$(basename "$f")"
        fi
    done
}

restore_previous_repos() {
    if [ -z "$REPO_BACKUP_DIR" ] || [ ! -d "$REPO_BACKUP_DIR" ]; then
        return
    fi
    echo -e "${RED}Restoring previous repository configuration...${NC}"
    local found=false
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources \
             /etc/apt/sources.list.d/debian-backports.list /etc/apt/sources.list.d/debian-backports.sources; do
        local rel="${f#/etc/apt/}"
        local backup_file="$REPO_BACKUP_DIR/$rel"
        if [ -f "$backup_file" ]; then
            sudo cp "$backup_file" "$f"
            found=true
        elif [ -f "$f" ]; then
            sudo rm -f "$f"
            found=true
        fi
    done
    if $found; then
        sudo rm -f /etc/apt/sources.list.disabled
    fi
    rm -rf "$REPO_BACKUP_DIR"
    REPO_BACKUP_DIR=""
}

cleanup_repo_backup() {
    if [ -n "$REPO_BACKUP_DIR" ] && [ -d "$REPO_BACKUP_DIR" ]; then
        rm -rf "$REPO_BACKUP_DIR"
        REPO_BACKUP_DIR=""
    fi
}

# ---------------------------------------------------------------------------
# Cleanup helpers for embedded backports
# ---------------------------------------------------------------------------

_clean_embedded_backports_classic() {
    local codename="$1"
    local file="/etc/apt/sources.list"
    [ ! -f "$file" ] && return
    grep -qE "^[^#]*${codename}-backports\b" "$file" 2>/dev/null || return
    if _confirm "Clean Classic Sources" "Remove backports line from ${file}?"; then
        sudo sed -i "/${codename}-backports/d" "$file"
        echo "Removed backports from ${file}"
    fi
}

_clean_embedded_backports_deb822() {
    local codename="$1"
    local file="/etc/apt/sources.list.d/debian.sources"
    [ ! -f "$file" ] && return

    # Only proceed if the Suites line contains the backports token
    grep -qE "^Suites:.*${codename}-backports\b" "$file" 2>/dev/null || return

    if _confirm "Clean deb822 Sources" "Remove backports suite from ${file}?"; then
        # Remove only the backports token, leaving other suites intact
        sudo sed -i "s/[[:space:]]*${codename}-backports[[:space:]]*/ /g" "$file"
        # Clean up whitespace on Suites lines
        sudo sed -i '/^Suites:[[:space:]]*$/d' "$file" 2>/dev/null || true
        echo "Removed backports suite from ${file}"
    fi
}

# ---------------------------------------------------------------------------
# Write functions – idempotent, with _confirm dialogs
# ---------------------------------------------------------------------------

_write_deb822() {
    local codename="$1" action="$2" bp_enabled="$3" bp_location="$4"
    local components="${5:-main contrib non-free non-free-firmware}"

    local main_file="/etc/apt/sources.list.d/debian.sources"
    local main_content=""
    main_content+="Types: deb\n"
    main_content+="URIs: https://deb.debian.org/debian\n"
    main_content+="Suites: ${codename} ${codename}-updates\n"
    main_content+="Components: ${components}\n"
    main_content+="\n"
    main_content+="Types: deb\n"
    main_content+="URIs: https://security.debian.org/debian-security\n"
    main_content+="Suites: ${codename}-security\n"
    main_content+="Components: ${components}\n"

    if content_differs "$main_file" "$main_content"; then
        if _confirm "Deb822 Sources" "Write main deb822 configuration to ${main_file}?"; then
            sudo mkdir -p /etc/apt/sources.list.d
            echo -e "$main_content" | sudo tee "$main_file" > /dev/null
            echo "Wrote ${main_file}"
        else
            echo "Main repository configuration skipped."
            return 1
        fi
    fi

    # Backports: always in separate file
    if [ "$bp_enabled" = true ]; then
        _write_deb822_backports "$codename"
    else
        _remove_deb822_backports "$codename"
    fi

    # On migration from classic, disable the old file
    if [ "$action" = "migrate" ] && [ "$bp_location" = "embedded-classic" -o "$bp_location" = "standalone-classic" ]; then
        if [ -f /etc/apt/sources.list ]; then
            if _confirm "Disable Classic" "Migrating to deb822. Disable /etc/apt/sources.list?"; then
                sudo mv /etc/apt/sources.list /etc/apt/sources.list.disabled
                echo "Classic sources.list disabled (renamed to sources.list.disabled)"
            fi
        fi
    fi

    # Clean embedded backports from old classic file if they existed there
    if [ "$bp_location" = "embedded-classic" ]; then
        _clean_embedded_backports_classic "$codename"
    fi
}

_write_deb822_backports() {
    local codename="$1"
    local bp_file="/etc/apt/sources.list.d/debian-backports.sources"
    local bp_content=""
    bp_content+="Types: deb\n"
    bp_content+="URIs: https://deb.debian.org/debian\n"
    bp_content+="Suites: ${codename}-backports\n"
    bp_content+="Components: main contrib non-free non-free-firmware\n"

    if content_differs "$bp_file" "$bp_content"; then
        if _confirm "Deb822 Backports" "Write backports to ${bp_file}?"; then
            sudo mkdir -p /etc/apt/sources.list.d
            echo -e "$bp_content" | sudo tee "$bp_file" > /dev/null
            echo "Wrote ${bp_file}"
        fi
    fi

    # If backports were formerly embedded in debian.sources, clean them
    grep -qE "^Suites:.*${codename}-backports\b" /etc/apt/sources.list.d/debian.sources 2>/dev/null && \
        _clean_embedded_backports_deb822 "$codename"
}

_remove_deb822_backports() {
    local codename="$1"
    local bp_file="/etc/apt/sources.list.d/debian-backports.sources"

    if [ -f "$bp_file" ]; then
        if _confirm "Remove Backports" "Remove ${bp_file}?"; then
            sudo rm -f "$bp_file"
            echo "Removed ${bp_file}"
        fi
    fi

    # Also clean any embedded backports in main debian.sources
    grep -qE "^Suites:.*${codename}-backports\b" /etc/apt/sources.list.d/debian.sources 2>/dev/null && \
        _clean_embedded_backports_deb822 "$codename"

    # Clean embedded backports from classic file too (safety net)
    _clean_embedded_backports_classic "$codename"
}

_write_classic() {
    local codename="$1" action="$2" bp_enabled="$3" bp_location="$4"
    local components="${5:-main contrib non-free non-free-firmware}"

    local main_file="/etc/apt/sources.list"
    local main_content=""
    main_content+="# Official repository\n"
    main_content+="deb https://deb.debian.org/debian ${codename} ${components}\n"
    main_content+="# deb-src https://deb.debian.org/debian ${codename} ${components}\n"
    main_content+="\n"
    main_content+="# Updates\n"
    main_content+="deb https://deb.debian.org/debian ${codename}-updates ${components}\n"
    main_content+="# deb-src https://deb.debian.org/debian ${codename}-updates ${components}\n"
    main_content+="\n"
    main_content+="# Security\n"
    main_content+="deb https://security.debian.org/debian-security ${codename}-security ${components}\n"
    main_content+="# deb-src https://security.debian.org/debian-security ${codename}-security ${components}\n"

    if content_differs "$main_file" "$main_content"; then
        if _confirm "Classic Sources" "Write main classic configuration to ${main_file}?"; then
            echo -e "$main_content" | sudo tee "$main_file" > /dev/null
            echo "Wrote ${main_file}"
        else
            echo "Main repository configuration skipped."
            return 1
        fi
    fi

    # Backports: always in separate file
    if [ "$bp_enabled" = true ]; then
        _write_classic_backports "$codename"
    else
        _remove_classic_backports "$codename"
    fi

    # On migration from deb822, disable the old file
    if [ "$action" = "migrate" ]; then
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then
            if _confirm "Disable Deb822" "Migrating to classic format. Disable /etc/apt/sources.list.d/debian.sources?"; then
                sudo mv /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list.d/debian.sources.disabled
                echo "Deb822 sources disabled (renamed to debian.sources.disabled)"
            fi
        fi
    fi

    # Clean embedded backports from old deb822 file if they existed there
    if [ "$bp_location" = "embedded-deb822" ]; then
        _clean_embedded_backports_deb822 "$codename"
    fi
}

_write_classic_backports() {
    local codename="$1"
    local bp_file="/etc/apt/sources.list.d/debian-backports.list"
    local bp_content=""
    bp_content+="# Backports\n"
    bp_content+="deb https://deb.debian.org/debian ${codename}-backports main contrib non-free non-free-firmware\n"

    if content_differs "$bp_file" "$bp_content"; then
        if _confirm "Classic Backports" "Write backports to ${bp_file}?"; then
            sudo mkdir -p /etc/apt/sources.list.d
            echo -e "$bp_content" | sudo tee "$bp_file" > /dev/null
            echo "Wrote ${bp_file}"
        fi
    fi

    # If backports were formerly embedded in sources.list, clean them
    grep -qE "^[^#]*${codename}-backports\b" /etc/apt/sources.list 2>/dev/null && \
        _clean_embedded_backports_classic "$codename"
}

_remove_classic_backports() {
    local codename="$1"
    local bp_file="/etc/apt/sources.list.d/debian-backports.list"

    if [ -f "$bp_file" ]; then
        if _confirm "Remove Backports" "Remove ${bp_file}?"; then
            sudo rm -f "$bp_file"
            echo "Removed ${bp_file}"
        fi
    fi

    # Also clean any embedded backports in main sources.list
    grep -qE "^[^#]*${codename}-backports\b" /etc/apt/sources.list 2>/dev/null && \
        _clean_embedded_backports_classic "$codename"

    # Clean embedded backports from deb822 file too (safety net)
    _clean_embedded_backports_deb822 "$codename"
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

configure_repos() {
    echo -e "${YELLOW}Repository configuration...${NC}"

    if [ -z "$DEBIAN_CODENAME" ]; then
        echo -e "${RED}Error: Could not detect Debian codename. Aborting.${NC}"
        return 1
    fi

    # ── Repositories submenu ──
    while true; do
        local repo_choice

        if [ "$DEBIAN_CODENAME" = "sid" ]; then
            repo_choice=$(_menu "Repositories" \
                "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
                "1" "Enable Contrib & Non-Free Components" \
                "2" "Migrate traditional sources.list to DEB822 format" \
                "3" "Back to main menu")
        else
            repo_choice=$(_menu "Repositories" \
                "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
                "1" "Enable Contrib & Non-Free Components" \
                "2" "Migrate traditional sources.list to DEB822 format" \
                "3" "Setup/Update Backports repositories" \
                "4" "[ADVANCED] Upgrade system branch (Testing / SID)" \
                "5" "Back to main menu")
        fi

        [ -z "$repo_choice" ] && break
        clear

        case "$repo_choice" in
            1) _repos_enable_components ;;
            2) _repos_migrate_format ;;
            3)
                if [ "$DEBIAN_CODENAME" = "sid" ]; then
                    break
                else
                    _repos_setup_backports
                fi
                ;;
            4) _branch_migration || true ;;
            5) break ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Submenu helpers
# ---------------------------------------------------------------------------

_components_enabled() {
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        grep -qE "^Components:.*\b(contrib|non-free)\b" /etc/apt/sources.list.d/debian.sources 2>/dev/null && return 0
    fi
    if [ -f /etc/apt/sources.list ]; then
        grep -qE "^[^#]*\b(contrib|non-free)\b" /etc/apt/sources.list 2>/dev/null && return 0
    fi
    return 1
}

_repos_offer_upgrade() {
    local upgradable
    upgradable=$(apt list --upgradable 2>/dev/null | grep -c /)
    if [ "$upgradable" -gt 0 ]; then
        if _confirm "Upgrade System" "$upgradable packages can be upgraded. Upgrade now?"; then
            sudo apt-mark hold tzdata 2>/dev/null || true
            _run_cmd "Upgrade" "sudo apt upgrade -y" "Upgrading system..."
            sudo apt-mark unhold tzdata 2>/dev/null || true
            sudo apt autoremove -y
            sudo apt autoclean
            echo -e "${GREEN}System upgraded.${NC}"
        else
            echo "Skipping upgrade."
        fi
    fi
}

_repos_enable_components() {
    local current_format bp_enabled bp_location components
    current_format=$(detect_repo_format)

    if _components_enabled; then
        if ! _confirm "Disable Components" \
            "Contrib and non-free are already enabled. Disable them?"; then
            echo "No changes made."
            _pause
            return
        fi
        components="main"
    else
        if ! _confirm "Enable Components" \
            "Enable contrib and non-free components?\n\n\
Needed for proprietary drivers, firmware, and other popular\n\
software (like gaming platforms and proprietary tools)." 12 60; then
            echo "No changes made."
            _pause
            return
        fi
        components="main contrib non-free non-free-firmware"
    fi

    bp_enabled=false
    bp_location="none"
    if detect_backports_status "$DEBIAN_CODENAME"; then
        bp_enabled=true
        bp_location=$(detect_backports_location "$DEBIAN_CODENAME")
    fi

    backup_current_repos

    if [ "$current_format" = "deb822" ] || [ "$current_format" = "none" ]; then
        _write_deb822 "$DEBIAN_CODENAME" "write" "$bp_enabled" "$bp_location" "$components"
    else
        _write_classic "$DEBIAN_CODENAME" "write" "$bp_enabled" "$bp_location" "$components"
    fi

    echo "Updating package lists..."
    if sudo apt update; then
        REPOS_CONFIGURED=true
        cleanup_repo_backup
        echo -e "${GREEN}Repository components configured.${NC}"
        _repos_offer_upgrade
    else
        restore_previous_repos
        echo -e "${RED}apt update failed. Previous configuration restored.${NC}"
    fi
    _pause
}

_repos_migrate_format() {
    local current_format bp_enabled bp_location
    current_format=$(detect_repo_format)

    if [ "$current_format" != "classic" ]; then
        echo "Repositories are already in DEB822 format."
        _pause
        return
    fi

    if [ "$DEBIAN_CODENAME" != "trixie" ]; then
        echo "Format migration is only relevant for Debian 13 (Trixie)."
        _pause
        return
    fi

    # Preserve existing backports state across format migration
    bp_enabled=false
    bp_location="none"
    if detect_backports_status "$DEBIAN_CODENAME"; then
        bp_enabled=true
        bp_location=$(detect_backports_location "$DEBIAN_CODENAME")
    fi

    backup_current_repos
    _write_deb822 "$DEBIAN_CODENAME" "migrate" "$bp_enabled" "$bp_location"

    echo "Updating package lists..."
    if sudo apt update; then
        REPOS_CONFIGURED=true
        cleanup_repo_backup
        echo -e "${GREEN}Repository format migrated to DEB822.${NC}"
    else
        restore_previous_repos
        echo -e "${RED}apt update failed. Backup restored.${NC}"
    fi
    _pause
}

_repos_setup_backports() {
    local current_format bp_status bp_location
    current_format=$(detect_repo_format)

    if detect_backports_status "$DEBIAN_CODENAME"; then
        bp_status="enabled"
    else
        bp_status="disabled"
    fi
    bp_location=$(detect_backports_location "$DEBIAN_CODENAME")

    echo "Backports are currently $bp_status."

    local enable_backports=false
    if _confirm "Backports" "Do you want to enable the official Debian Backports repository?\n\n\
Backports provides newer, selectively updated packages from the next\n\
Debian testing branch, recompiled to run stably on your current system.\n\n\
Answer NO to disable or remove backports if they are currently enabled." 16 70; then
        enable_backports=true
    fi

    # Nothing to do — already in desired state
    if { $enable_backports && [ "$bp_status" = "enabled" ]; } || \
       { ! $enable_backports && [ "$bp_status" = "disabled" ]; }; then
        echo "Backports are already configured as requested."
        _pause
        return
    fi

    backup_current_repos

    if $enable_backports; then
        if [ "$current_format" = "deb822" ]; then
            _write_deb822_backports "$DEBIAN_CODENAME"
        else
            _write_classic_backports "$DEBIAN_CODENAME"
        fi
    else
        if [ "$current_format" = "deb822" ]; then
            _remove_deb822_backports "$DEBIAN_CODENAME"
        else
            _remove_classic_backports "$DEBIAN_CODENAME"
        fi
    fi

    echo "Updating package lists..."
    if sudo apt update; then
        cleanup_repo_backup
        echo -e "${GREEN}Backports configured.${NC}"
    else
        restore_previous_repos
        echo -e "${RED}apt update failed. Backup restored.${NC}"
    fi
    _pause
}
