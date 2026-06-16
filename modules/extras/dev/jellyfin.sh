# jellyfin.sh — Jellyfin Media Server installation

install_jellyfin() {
    local tmpdir="/tmp/jellyfin_install"
    mkdir -p "${tmpdir}"

    _run_cmd "Jellyfin" "curl -sSL -o ${tmpdir}/install-debuntu.sh https://repo.jellyfin.org/install-debuntu.sh" "Downloading Jellyfin repository script..."
    _run_cmd "Jellyfin" "curl -sSL -o ${tmpdir}/install-debuntu.sh.sha256sum https://repo.jellyfin.org/install-debuntu.sh.sha256sum" "Downloading checksum..."

    if [ ! -s "${tmpdir}/install-debuntu.sh" ] || [ ! -s "${tmpdir}/install-debuntu.sh.sha256sum" ]; then
        echo -e "${RED}[-]${NC} Download failed: script or checksum is empty or missing."
        rm -rf "${tmpdir}"
        return 1
    fi

    echo -e "${GREEN}[+]${NC} Verifying checksum..."
    if ! (cd "${tmpdir}" && sha256sum -c install-debuntu.sh.sha256sum); then
        echo -e "${RED}[-]${NC} Checksum verification failed. The downloaded script may be corrupted."
        rm -rf "${tmpdir}"
        return 1
    fi

    echo -e "${GREEN}[+]${NC} Running Jellyfin repository setup..."
    if ! sudo bash "${tmpdir}/install-debuntu.sh"; then
        echo -e "${RED}[-]${NC} Jellyfin installation failed."
        rm -rf "${tmpdir}"
        return 1
    fi

    rm -rf "${tmpdir}"
    echo -e "${GREEN}Jellyfin Server installed. Web interface available at http://localhost:8096${NC}"
}
