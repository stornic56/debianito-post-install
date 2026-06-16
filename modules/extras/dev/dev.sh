#!/usr/bin/env bash
# dev.sh — Development & Servers (extrepo, zenmap, fail2ban, ufw moved out)

_cat_dev() {
    local headless=false
    _is_headless && headless=true
    local apache_state;   apache_state=$(_state "apache2")
    local build_state;    build_state=$(_state "build-essential")
    local certbot_state;  certbot_state=$(_state "certbot")
    local docker_state;   docker_state=$(_state "docker.io")
    local mariadb_state;  mariadb_state=$(_state "mariadb-server")
    local netcat_state;   netcat_state=$(_state "netcat-openbsd")
    local nginx_state;    nginx_state=$(_state "nginx")
    local ssh_state;      ssh_state=$(_state "openssh-server")
    local openssl_state;  openssl_state=$(_state "openssl")
    local pg_state;       pg_state=$(_state "postgresql")
    local pip_state;      pip_state=$(_state "python3-pip")
    local redis_state;    redis_state=$(_state "redis-server")
    local sqlite_state;   sqlite_state=$(_state "sqlite3")
    local jdk_desc;       jdk_desc=$(_any_jdk_installed_desc)
    local jdk_state;      jdk_state=$(_any_jdk_state)

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices
    choices=$(whiptail --title "Development & Servers" --checklist \
        "Select development tools and servers${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "apache2"                   "Apache web server$(_inst apache2)"                            "$apache_state" \
        "build-essential"           "C/C++ build tools (gcc, make)$(_inst build-essential)"        "$build_state" \
        "certbot"                   "Let's Encrypt TLS certificates$(_inst certbot)"               "$certbot_state" \
        "docker"                    "Docker + docker-compose$(_inst docker.io)"                    "$docker_state" \
        "mariadb-server"            "MariaDB database server$(_inst mariadb-server)"               "$mariadb_state" \
        "netcat-openbsd"            "TCP/IP networking utility$(_inst netcat-openbsd)"             "$netcat_state" \
        "nginx"                     "Nginx web server$(_inst nginx)"                               "$nginx_state" \
        "openssh-server"            "SSH server$(_inst openssh-server)"                            "$ssh_state" \
        "openssl"                   "OpenSSL cryptography toolkit$(_inst openssl)"                 "$openssl_state" \
        "postgresql"                "PostgreSQL database server$(_inst postgresql)"                 "$pg_state" \
        "python3-pip"               "Python 3 pip + venv + dev$(_inst python3-pip)"                "$pip_state" \
        "redis-server"              "Redis key-value store$(_inst redis-server)"                   "$redis_state" \
        "sqlite3"                   "SQLite database engine$(_inst sqlite3)"                       "$sqlite_state" \
        "jellyfin"                  "Jellyfin Media Server (Web GUI on port 8096)$(_inst jellyfin)" OFF \
        "openjdk-dev-env"           "Adoptium Temurin JDK (17, 21, 25 LTS)${jdk_desc}"             "${jdk_state}" \
        3>&1 1>&2 2>&3)
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        case $pkg in
            python3-pip)
                local need=()
                ! is_installed "python3-pip" && need+=("python3-pip")
                ! is_installed "python3-venv" && need+=("python3-venv")
                ! is_installed "python3-dev" && need+=("python3-dev")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                else
                    echo "Python 3 tools already installed."
                fi
                ;;
            docker)
                local need=()
                ! is_installed "docker.io" && need+=("docker.io")
                ! is_installed "docker-compose" && need+=("docker-compose")
                if [ ${#need[@]} -gt 0 ]; then
                    _run_install_batch "${need[@]}"
                else
                    echo "Docker already installed."
                fi
                ;;
            jellyfin)
                install_jellyfin
                ;;
            openjdk-dev-env)
                _install_dev_java
                ;;
            *)
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Development tools and servers installed.${NC}"
}
