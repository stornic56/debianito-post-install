# shellcheck disable=SC2148
# repo_detect.sh – Detection-only helpers for idempotent repository configuration.
# Part A of the two-part architecture. No user dialogs, no writes.

# Detect the format of the main repo file
# Returns: "deb822", "classic", or "none"
detect_repo_format() {
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        echo "deb822"
    elif [ -f /etc/apt/sources.list ]; then
        echo "classic"
    else
        echo "none"
    fi
}

# Check whether backports are currently enabled (any format)
# Returns: 0 if enabled, 1 otherwise
detect_backports_status() {
    local codename="$1"

    if [ -f /etc/apt/sources.list.d/debian.sources ]; then
        grep -qE "^Suites:.*${codename}-backports" /etc/apt/sources.list.d/debian.sources 2>/dev/null && return 0
    fi
    if [ -f /etc/apt/sources.list ]; then
        grep -qE "^[^#]*${codename}-backports" /etc/apt/sources.list 2>/dev/null && return 0
    fi
    if [ -f /etc/apt/sources.list.d/debian-backports.sources ]; then
        grep -qE "^Suites:.*${codename}-backports" /etc/apt/sources.list.d/debian-backports.sources 2>/dev/null && return 0
    fi
    if [ -f /etc/apt/sources.list.d/debian-backports.list ]; then
        grep -qE "^[^#]*${codename}-backports" /etc/apt/sources.list.d/debian-backports.list 2>/dev/null && return 0
    fi

    return 1
}

# Locate where backports are configured
# Returns: "standalone-deb822" (debian-backports.sources),
#          "standalone-classic" (debian-backports.list),
#          "embedded-deb822" (inside debian.sources),
#          "embedded-classic" (inside sources.list),
#          "none"
detect_backports_location() {
    local codename="$1"

    if [ -f /etc/apt/sources.list.d/debian-backports.sources ] && \
       grep -qE "^Suites:.*${codename}-backports" /etc/apt/sources.list.d/debian-backports.sources 2>/dev/null; then
        echo "standalone-deb822"
    elif [ -f /etc/apt/sources.list.d/debian-backports.list ] && \
         grep -qE "^[^#]*${codename}-backports" /etc/apt/sources.list.d/debian-backports.list 2>/dev/null; then
        echo "standalone-classic"
    elif [ -f /etc/apt/sources.list.d/debian.sources ] && \
         grep -qE "^Suites:.*${codename}-backports" /etc/apt/sources.list.d/debian.sources 2>/dev/null; then
        echo "embedded-deb822"
    elif [ -f /etc/apt/sources.list ] && \
         grep -qE "^[^#]*${codename}-backports" /etc/apt/sources.list 2>/dev/null; then
        echo "embedded-classic"
    else
        echo "none"
    fi
}

# Compare generated content vs existing file (idempotency check)
# Returns: 0 if content differs, 1 if identical
content_differs() {
    local file="$1"
    local content="$2"

    if [ ! -f "$file" ]; then
        return 0
    fi
    local current
    current=$(cat "$file")
    local generated
    generated=$(echo -e "$content")
    if [ "$current" = "$generated" ]; then
        return 1
    fi
    return 0
}
