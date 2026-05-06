#!/usr/bin/env bash

configure_repos() {
    echo -e "${YELLOW}Repository configuration...${NC}"


    local use_deb822
    if whiptail --title "Repository Format" --defaultno \
        --yesno "Use the modern .sources (deb822) format?\n(default is classic one-line style)" 10 60; then
        use_deb822=true
    else
        use_deb822=false
    fi


    local enable_backports
    if whiptail --title "Backports" \
        --yesno "Enable backports?\nBackports provide newer versions of some software (kernel, drivers, Mesa) for better hardware support.\nIt is recommended to enable it (default: Yes)." 12 70; then
        enable_backports=true
    else
        enable_backports=false
    fi


    if $use_deb822; then
        generate_deb822_sources "$DEBIAN_CODENAME" "$enable_backports"
    else
        generate_classic_sources "$DEBIAN_CODENAME" "$enable_backports"
    fi


    echo "Updating package lists..."
    if sudo apt update; then
        REPOS_CONFIGURED=true
        echo -e "${GREEN}Repositories configured and updated successfully.${NC}"

        local upgradable
        upgradable=$(apt list --upgradable 2>/dev/null | grep -c /)
        if [ "$upgradable" -gt 0 ]; then
            if whiptail --title "Upgrade System" \
                --yesno "There are $upgradable packages that can be upgraded.\n\nDo you want to upgrade them now?" 10 60; then
                sudo apt upgrade -y
                echo -e "${GREEN}System upgraded.${NC}"
            else
                echo "Skipping upgrade."
            fi
        fi
    else
        echo -e "${RED}apt update failed. Please check your network and repository configuration.${NC}"
        return 1
    fi
}

# ----------------------------------------------------------------------
# Generate classic sources.list
# ----------------------------------------------------------------------
generate_classic_sources() {
    local codename="$1"
    local backports="$2"


    if [ -f /etc/apt/sources.list ]; then
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        echo "Backup of sources.list saved as sources.list.bak"
    fi


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

# ----------------------------------------------------------------------
# Generate deb822 .sources format
# ----------------------------------------------------------------------
generate_deb822_sources() {
    local codename="$1"
    local backports="$2"


    sudo mkdir -p /etc/apt/sources.list.d


    sudo rm -f /etc/apt/sources.list.d/debian.sources


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
    else

        true
    fi

    echo -e "$content" | sudo tee /etc/apt/sources.list.d/debian.sources > /dev/null


    if [ -f /etc/apt/sources.list ]; then
        sudo mv /etc/apt/sources.list /etc/apt/sources.list.disabled
        echo "Classic sources.list disabled (renamed to sources.list.disabled)"
    fi
}
