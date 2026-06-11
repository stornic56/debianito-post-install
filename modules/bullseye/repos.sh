#!/usr/bin/env bash
# repos.sh — Bullseye: repos clásicos con archive phase
# License GPL v3

configure_repos_bullseye() {
    echo -e "${YELLOW}Repository configuration — Debian 11 Bullseye${NC}"

    local info="Configuración de repositorios para Debian 11 Bullseye.\n\n"
    info+="Se usarán los repositorios oficiales con componentes\n"
    info+="main, contrib y non-free (sin non-free-firmware).\n"
    info+="No se utiliza formato DEB822.\n"
    if $BULLSEYE_USE_ARCHIVE; then
        info+="\nModo Archive: Las URLs apuntarán a archive.debian.org\n"
        info+="(Bullseye LTS finalizó el 31 Ago 2026)."
    fi
    _msg "Repositorios — Bullseye" "$info" 12 65

    if [ -f /etc/apt/sources.list ]; then
        if ! _confirm "Repositorios" "Ya existe /etc/apt/sources.list.\n\nSobrescribir con la configuración de Bullseye?"; then
            echo "Manteniendo configuración actual."
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

    content+="# Updates\n"
    content+="deb ${base_uri} bullseye-updates main contrib non-free\n"
    content+="#deb-src ${base_uri} bullseye-updates main contrib non-free\n\n"

    content+="# Security\n"
    content+="deb ${security_uri} bullseye-security main contrib non-free\n"
    content+="#deb-src ${security_uri} bullseye-security main contrib non-free\n"

    echo -e "$content" | sudo tee /etc/apt/sources.list > /dev/null

    echo "Actualizando listas de paquetes..."
    if sudo apt update; then
        echo -e "${GREEN}Repositorios de Debian 11 Bullseye configurados.${NC}"
    else
        echo -e "${RED}apt update falló. Revise su conexión de red.${NC}"
        return 1
    fi
}
