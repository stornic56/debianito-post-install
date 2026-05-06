#!/usr/bin/env bash
# extras.sh

install_extras() {
    echo -e "${YELLOW}Extra software installation...${NC}"

    local fetch_pkg
    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        fetch_pkg="neofetch"
    else
        fetch_pkg="fastfetch"
    fi

    local choices
    choices=$(whiptail --title "Extra Software" --checklist \
        "Select programs to install (space to toggle, enter to confirm):" \
        22 75 15 \
        "lshw"       "List hardware details"                    ON  \
        "inxi"       "System information tool"                   ON  \
        "hardinfo"   "Graphical system profiler"                 OFF \
        "fetch"      "System info (${fetch_pkg})"                ON  \
        "cpufetch"   "CPU info fetcher"                          ON  \
        "cpu-x"      "CPU-X (GUI alternative to CPU-Z)"          ON  \
        "btop"       "Resource monitor (fancy top)"              ON  \
        "htop"       "Interactive process viewer"                ON  \
        "vlc"        "VLC media player"                          ON  \
        "mpv"        "Lightweight media player"                  OFF \
        "chromium"   "Chromium web browser"                      OFF \
        "ttf-mscorefonts-installer" "Microsoft TrueType fonts"   ON  \
        "fonts-ubuntu" "Ubuntu font family"                      OFF \
        "gparted"    "GNOME partition editor"                    OFF \
        "flatpak"    "Flatpak application sandbox"               OFF \
        "firefox"    "Firefox from Mozilla (replaces ESR)"       OFF \
        3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        echo "No extra programs selected."
        return
    fi

    local cleaned
    cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            fetch)
                sudo apt install -y "$fetch_pkg"
                ;;
            firefox)
                install_firefox_mozilla
                ;;
            *)
                sudo apt install -y "$pkg"
                ;;
        esac
    done

    echo -e "${GREEN}Extra software installed.${NC}"
}

# ---------------------------------------------
# Firefox from Mozilla official APT repository
# ---------------------------------------------
install_firefox_mozilla() {
    echo -e "${YELLOW}Installing Firefox from Mozilla...${NC}"

    sudo apt install -y wget gpg

    sudo install -d -m 0755 /etc/apt/keyrings

    if [ ! -f /etc/apt/keyrings/packages.mozilla.org.asc ]; then
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | \
            sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null
        echo "Mozilla signing key imported."
    else
        echo "Mozilla key already present."
    fi

    local fingerprint
    fingerprint=$(gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc 2>/dev/null | \
        awk '/pub/ { getline; gsub(/^ +| +$/, ""); print }')
    if [ "$fingerprint" != "35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3" ]; then
        echo -e "${RED}Warning: Mozilla signing key fingerprint mismatch!${NC}"
        echo "Expected: 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3"
        echo "Got: $fingerprint"
        echo "Aborting Firefox installation for security."
        return 1
    fi


    if [ "$DEBIAN_CODENAME" = "bookworm" ]; then
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | \
            sudo tee /etc/apt/sources.list.d/mozilla.list > /dev/null
    else
        sudo tee /etc/apt/sources.list.d/mozilla.sources > /dev/null <<EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc
EOF
    fi

    sudo tee /etc/apt/preferences.d/mozilla > /dev/null <<EOF
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

    sudo apt update
    sudo apt install -y firefox

    echo -e "${GREEN}Firefox from Mozilla installed.${NC}"

    if dpkg -l firefox-esr &> /dev/null; then
        if whiptail --title "Remove Firefox ESR" \
            --yesno "Firefox ESR is still installed. Do you want to remove it?" 8 60; then
            sudo apt remove -y firefox-esr
            echo "Firefox ESR removed."
        else
            echo "Keeping Firefox ESR alongside."
        fi
    fi
}
