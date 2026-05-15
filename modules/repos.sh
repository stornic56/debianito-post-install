#!/usr/bin/env bash

# State for backup/restore
REPO_BACKUP_DIR=""

backup_current_repos() {
    REPO_BACKUP_DIR=$(mktemp -d)
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do
        if [ -f "$f" ]; then
            cp "$f" "$REPO_BACKUP_DIR/$(basename "$f")"
        fi
    done
}

restore_previous_repos() {
    if [ -z "$REPO_BACKUP_DIR" ] || [ ! -d "$REPO_BACKUP_DIR" ]; then
        return
    fi
    echo -e "${RED}Restoring previous repository configuration...${NC}"
    if [ -f "$REPO_BACKUP_DIR/sources.list" ]; then
        sudo cp "$REPO_BACKUP_DIR/sources.list" /etc/apt/sources.list
    else
        sudo rm -f /etc/apt/sources.list
    fi
    if [ -f "$REPO_BACKUP_DIR/debian.sources" ]; then
        sudo cp "$REPO_BACKUP_DIR/debian.sources" /etc/apt/sources.list.d/debian.sources
    else
        sudo rm -f /etc/apt/sources.list.d/debian.sources
    fi
    sudo rm -f /etc/apt/sources.list.disabled
    rm -rf "$REPO_BACKUP_DIR"
    REPO_BACKUP_DIR=""
}

cleanup_repo_backup() {
    if [ -n "$REPO_BACKUP_DIR" ] && [ -d "$REPO_BACKUP_DIR" ]; then
        rm -rf "$REPO_BACKUP_DIR"
        REPO_BACKUP_DIR=""
    fi
}

finalize_deb822() {
    if [ -f /etc/apt/sources.list ]; then
        sudo mv /etc/apt/sources.list /etc/apt/sources.list.disabled
        echo "Classic sources.list disabled (renamed to sources.list.disabled)"
    fi
    cleanup_repo_backup
}

configure_repos() {
    echo -e "${YELLOW}Repository configuration...${NC}"

    local use_deb822=false
    if [ "$DEBIAN_CODENAME" = "trixie" ]; then
        if whiptail --title "Repository Format" --defaultno \
            --yesno "Use the modern .sources (deb822) format?\n(default is classic one-line style)" 10 60; then
            use_deb822=true
        fi
    fi

    local enable_backports
    if whiptail --title "Backports" \
        --yesno "Enable backports?\nBackports provide newer versions of some software (kernel, drivers, Mesa) for better hardware support.\nIt is recommended to enable it (default: Yes)." 12 70; then
        enable_backports=true
    else
        enable_backports=false
    fi

    if [ -z "$DEBIAN_CODENAME" ]; then
        echo -e "${RED}Error: Could not detect Debian codename. Aborting.${NC}"
        return 1
    fi

    sync_system_time

    backup_current_repos

    if $use_deb822; then
        generate_deb822_sources "$DEBIAN_CODENAME" "$enable_backports"
    else
        generate_classic_sources "$DEBIAN_CODENAME" "$enable_backports"
    fi

    echo "Updating package lists..."
    if sudo apt update; then
        REPOS_CONFIGURED=true
        echo -e "${GREEN}Repositories configured and updated successfully.${NC}"

        if $use_deb822; then
            finalize_deb822
        else
            cleanup_repo_backup
        fi

        local upgradable
        upgradable=$(apt list --upgradable 2>/dev/null | grep -c /)
        if [ "$upgradable" -gt 0 ]; then
            if whiptail --title "Upgrade System" \
                --yesno "There are $upgradable packages that can be upgraded.\n\nDo you want to upgrade them now?" 10 60; then
                sudo apt-mark hold tzdata 2>/dev/null || true
                sudo apt upgrade -y
                sudo apt-mark unhold tzdata 2>/dev/null || true
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

generate_classic_sources() {
    local codename="$1"
    local backports="$2"

    local content=""
    content="# Official repository\n"
    content+="deb https://deb.debian.org/debian ${codename} main contrib non-free non-free-firmware\n"
    content+="# deb-src https://deb.debian.org/debian ${codename} main contrib non-free non-free-firmware\n\n"

    content+="# Updates\n"
    content+="deb https://deb.debian.org/debian ${codename}-updates main contrib non-free non-free-firmware\n"
    content+="# deb-src https://deb.debian.org/debian ${codename}-updates main contrib non-free non-free-firmware\n\n"

    content+="# Security\n"
    content+="deb https://security.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware\n"
    content+="# deb-src https://security.debian.org/debian-security ${codename}-security main contrib non-free non-free-firmware\n\n"

    if $backports; then
        content+="# Backports (active)\n"
        content+="deb https://deb.debian.org/debian ${codename}-backports main contrib non-free non-free-firmware\n"
        content+="# deb-src https://deb.debian.org/debian ${codename}-backports main contrib non-free non-free-firmware\n"
    else
        content+="# Backports (not enabled)\n"
        content+="# deb https://deb.debian.org/debian ${codename}-backports main contrib non-free non-free-firmware\n"
    fi

    echo -e "$content" | sudo tee /etc/apt/sources.list > /dev/null
}

generate_deb822_sources() {
    local codename="$1"
    local backports="$2"

    sudo mkdir -p /etc/apt/sources.list.d

    local content=""
    content="Types: deb\n"
    content+="URIs: https://deb.debian.org/debian\n"
    content+="Suites: ${codename} ${codename}-updates\n"
    content+="Components: main contrib non-free non-free-firmware\n\n"

    content+="Types: deb\n"
    content+="URIs: https://security.debian.org/debian-security\n"
    content+="Suites: ${codename}-security\n"
    content+="Components: main contrib non-free non-free-firmware\n\n"

    if $backports; then
        content+="Types: deb\n"
        content+="URIs: https://deb.debian.org/debian\n"
        content+="Suites: ${codename}-backports\n"
        content+="Components: main contrib non-free non-free-firmware\n"
    fi

    echo -e "$content" | sudo tee /etc/apt/sources.list.d/debian.sources > /dev/null
}
