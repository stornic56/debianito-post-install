#!/usr/bin/env bash

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

    local main_file="/etc/apt/sources.list.d/debian.sources"
    local main_content=""
    main_content+="Types: deb\n"
    main_content+="URIs: https://deb.debian.org/debian\n"
    main_content+="Suites: ${codename} ${codename}-updates\n"
    main_content+="Components: main contrib non-free non-free-firmware\n"
    main_content+="\n"
    main_content+="Types: deb\n"
    main_content+="URIs: https://security.debian.org/debian-security\n"
    main_content+="Suites: ${codename}-security\n"
    main_content+="Components: main contrib non-free non-free-firmware\n"

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

    local main_file="/etc/apt/sources.list"
    local main_content=""
    main_content+="# Official repository\n"
    main_content+="deb https://deb.debian.org/debian ${codename} main contrib non-free non-free-firmware\n"
    main_content+="# deb-src https://deb.debian.org/debian ${codename} main contrib non-free non-free-firmware\n"
    main_content+="\n"
    main_content+="# Updates\n"
    main_content+="deb https://deb.debian.org/debian ${codename}-updates main contrib non-free non-free-firmware\n"
    main_content+="# deb-src https://deb.debian.org/debian ${codename}-updates main contrib non-free non-free-firmware\n"
    main_content+="\n"
    main_content+="# Security\n"
    main_content+="deb https://security.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware\n"
    main_content+="# deb-src https://security.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware\n"

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

    # Detect current state
    local current_format
    current_format=$(detect_repo_format)
    local bp_status
    if detect_backports_status "$DEBIAN_CODENAME"; then
        bp_status="enabled"
    else
        bp_status="disabled"
    fi
    local bp_location
    bp_location=$(detect_backports_location "$DEBIAN_CODENAME")

    echo "Current format: ${current_format:-none}"
    echo "Backports: $bp_status (location: $bp_location)"

    # Choose format (only Trixie gets the choice)
    local use_deb822=false
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        local default_text="no"
        [ "$current_format" = "deb822" ] && default_text="yes"
        if whiptail --title "Repository Format" --defaultno --yesno "Use deb822 format (modern .sources)?" 8 60; then
            use_deb822=true
        fi
    elif [ "$current_format" = "deb822" ]; then
        use_deb822=true
    fi

    # Choose backports
    local enable_backports=false
    if _confirm "Backports" "Enable backports repository?\n\nProvides newer kernel, drivers, Mesa."; then
        enable_backports=true
    fi

    # Determine what to do
    local target_format
    $use_deb822 && target_format="deb822" || target_format="classic"

    if [ "$current_format" = "none" ]; then
        local action="write"
    elif [ "$target_format" != "$current_format" ]; then
        local action="migrate"
    else
        local action="update"
    fi

    # If nothing changed (same format + same backports state), skip
    if [ "$action" = "update" ] && [ "$enable_backports" = "$bp_status" ]; then
        # Check if backports location is correct (standalone)
        if $enable_backports; then
            local correct_location="standalone-deb822"
            $use_deb822 || correct_location="standalone-classic"
            if [ "$bp_location" = "$correct_location" ]; then
                # Also verify no embedded backports linger
                if [ "$target_format" = "deb822" ]; then
                    ! grep -qE "^Suites:.*${DEBIAN_CODENAME}-backports\b" /etc/apt/sources.list.d/debian.sources 2>/dev/null || { action="update"; true; }
                else
                    ! grep -qE "^[^#]*${DEBIAN_CODENAME}-backports\b" /etc/apt/sources.list 2>/dev/null || { action="update"; true; }
                fi
                if [ "$action" = "update" ]; then
                    echo "Repository configuration is already up-to-date. Skipping."
                    return 0
                fi
            fi
        else
            # Backports disabled: verify no backports files exist
            if [ ! -f /etc/apt/sources.list.d/debian-backports.sources ] && \
               [ ! -f /etc/apt/sources.list.d/debian-backports.list ]; then
                echo "Repository configuration is already up-to-date. Skipping."
                return 0
            fi
        fi
    fi

    backup_current_repos

    if $use_deb822; then
        _write_deb822 "$DEBIAN_CODENAME" "$action" "$enable_backports" "$bp_location"
    else
        _write_classic "$DEBIAN_CODENAME" "$action" "$enable_backports" "$bp_location"
    fi

    echo "Updating package lists..."
    sudo apt update
    local apt_rc=$?
    if [ $apt_rc -eq 0 ]; then
        REPOS_CONFIGURED=true
        echo -e "${GREEN}Repositories configured and updated successfully.${NC}"

        if $use_deb822; then
            # Remove any leftover disabled files from old classic format
            [ -f /etc/apt/sources.list.disabled ] && sudo rm -f /etc/apt/sources.list.disabled
        else
            [ -f /etc/apt/sources.list.d/debian.sources.disabled ] && sudo rm -f /etc/apt/sources.list.d/debian.sources.disabled
        fi

        cleanup_repo_backup

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
    else
        restore_previous_repos
        echo -e "${RED}apt update failed. Previous repository configuration restored.${NC}"
        return 1
    fi
}
