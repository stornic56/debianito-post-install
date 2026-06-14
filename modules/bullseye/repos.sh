#!/usr/bin/env bash
# repos.sh — Bullseye: repos clásicos con archive phase
# License GPL v3

configure_repos_bullseye() {
    echo -e "${YELLOW}Repository configuration — Debian 11 Bullseye${NC}"

    local info="Repository configuration for Debian 11 Bullseye.\n\n"
    info+="Official repositories will be used with components\n"
    info+="main, contrib and non-free (non-free-firmware excluded).\n"
    info+="DEB822 format is not used.\n"
    if $BULLSEYE_USE_ARCHIVE; then
        info+="\nArchive Mode: URLs will point to archive.debian.org\n"
        info+="(Bullseye LTS ended on 31 Aug 2026)."
    fi
    _msg "Repositories — Bullseye" "$info" 12 65

    if [ -f /etc/apt/sources.list ]; then
        if ! _confirm "Repositories" "/etc/apt/sources.list already exists.\n\nOverwrite with Bullseye configuration?"; then
            echo "Keeping current configuration."
            return 0
        fi
    fi

    local base_uri="https://deb.debian.org/debian"
    local security_uri="https://security.debian.org/debian-security"
    if $BULLSEYE_USE_ARCHIVE; then
        base_uri="https://archive.debian.org/debian"
        security_uri="https://archive.debian.org/debian-security"
    fi

    local content=""
    content="# Oficial Repo\n"
    content+="deb ${base_uri} bullseye main contrib non-free\n"
    content+="#deb-src ${base_uri} bullseye main contrib non-free\n\n"

    content+="# Security\n"
    content+="deb ${security_uri} bullseye-security main contrib non-free\n"
    content+="#deb-src ${security_uri} bullseye-security main contrib non-free\n"

    echo -e "$content" | sudo tee /etc/apt/sources.list > /dev/null

    echo "Updating package lists..."
    if sudo apt update; then
        echo -e "${GREEN}Debian 11 Bullseye repositories configured.${NC}"
    else
        echo -e "${RED}apt update failed. Check your network connection.${NC}"
        return 1
    fi
}
