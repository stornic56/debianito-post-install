# shellcheck disable=SC2148
# repo_detect.sh – Detection-only helpers for idempotent repository configuration.
# Part A of the two-part architecture. No user dialogs, no writes.

# Any active (non-commented) source of any format, in any file?
# Returns: 0 if at least one active source exists, 1 otherwise
has_active_deb_sources() {
    local apt_dir="${APT_DIR:-/etc/apt}"
    local f
    for f in "$apt_dir/sources.list" "$apt_dir/sources.list.d/"*.list; do
        [ -f "$f" ] || continue
        grep -qE '^[^#]*\bdeb\b' "$f" 2>/dev/null && return 0
    done
    for f in "$apt_dir/sources.list.d/"*.sources; do
        [ -f "$f" ] || continue
        grep -qE '^Types:.*\bdeb\b' "$f" 2>/dev/null && \
            grep -qE '^URIs:' "$f" 2>/dev/null && return 0
    done
    return 1
}

# Detect the format of the main repo file (content-aware).
# DEB822 is only valid on Debian 13 (Trixie); Debian 11/12 are classic-only.
# Returns: "deb822", "classic", or "none"
detect_repo_format() {
    local apt_dir="${APT_DIR:-/etc/apt}"
    if [ "$DEBIAN_VERSION" = "13" ] && [ -f "$apt_dir/sources.list.d/debian.sources" ] && \
       grep -qE '^Types:.*\bdeb\b' "$apt_dir/sources.list.d/debian.sources" 2>/dev/null; then
        echo "deb822"
    elif [ -f "$apt_dir/sources.list" ] && grep -qE '^[^#]*\bdeb\b' "$apt_dir/sources.list" 2>/dev/null; then
        echo "classic"
    else
        echo "none"
    fi
}

# Detect the components currently active in the main repo file
# Returns: components list (e.g. "main contrib non-free non-free-firmware")
detect_active_components() {
    local apt_dir="${APT_DIR:-/etc/apt}"
    if [ "$DEBIAN_VERSION" = "13" ] && [ -f "$apt_dir/sources.list.d/debian.sources" ]; then
        local comps
        comps=$(grep "^Components:" "$apt_dir/sources.list.d/debian.sources" 2>/dev/null | head -1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
        if [ -n "$comps" ]; then
            echo "$comps"
            return
        fi
    fi
    if [ -f "$apt_dir/sources.list" ]; then
        local comps
        comps=$(grep "^[^#]*deb .* main" "$apt_dir/sources.list" 2>/dev/null | head -1 | sed 's/.*main\s*//')
        if [ -n "$comps" ]; then
            echo "main $comps"
            return
        fi
    fi
    if [ "$DEBIAN_VERSION" = "11" ]; then
        echo "main contrib non-free"
    else
        echo "main contrib non-free non-free-firmware"
    fi
}

# Check whether backports are currently enabled (any format, any file)
# Returns: 0 if enabled, 1 otherwise
detect_backports_status() {
    local apt_dir="${APT_DIR:-/etc/apt}"
    local codename="$1"

    if [ "$DEBIAN_VERSION" = "13" ] && [ -f "$apt_dir/sources.list.d/debian.sources" ]; then
        grep -qE "^Suites:.*${codename}-backports" "$apt_dir/sources.list.d/debian.sources" 2>/dev/null && return 0
    fi
    if [ -f "$apt_dir/sources.list" ]; then
        grep -qE "^[^#]*${codename}-backports" "$apt_dir/sources.list" 2>/dev/null && return 0
    fi
    if [ -d "$apt_dir/sources.list.d" ]; then
        grep -qrE "^Suites:.*${codename}-backports" "$apt_dir/sources.list.d/"*.sources 2>/dev/null && return 0
        grep -qrE "^[^#]*${codename}-backports" "$apt_dir/sources.list.d/"*.list 2>/dev/null && return 0
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
    local apt_dir="${APT_DIR:-/etc/apt}"
    local codename="$1"

    if [ "$DEBIAN_VERSION" = "13" ] && [ -f "$apt_dir/sources.list.d/debian-backports.sources" ] && \
       grep -qE "^Suites:.*${codename}-backports" "$apt_dir/sources.list.d/debian-backports.sources" 2>/dev/null; then
        echo "standalone-deb822"
    elif [ -f "$apt_dir/sources.list.d/debian-backports.list" ] && \
         grep -qE "^[^#]*${codename}-backports" "$apt_dir/sources.list.d/debian-backports.list" 2>/dev/null; then
        echo "standalone-classic"
    elif [ "$DEBIAN_VERSION" = "13" ] && [ -f "$apt_dir/sources.list.d/debian.sources" ] && \
         grep -qE "^Suites:.*${codename}-backports" "$apt_dir/sources.list.d/debian.sources" 2>/dev/null; then
        echo "embedded-deb822"
    elif [ -f "$apt_dir/sources.list" ] && \
         grep -qE "^[^#]*${codename}-backports" "$apt_dir/sources.list" 2>/dev/null; then
        echo "embedded-classic"
    elif [ -d "$apt_dir/sources.list.d" ]; then
        if grep -qrE "^Suites:.*${codename}-backports" "$apt_dir/sources.list.d/"*.sources 2>/dev/null; then
            echo "embedded-deb822"
        elif grep -qrE "^[^#]*${codename}-backports" "$apt_dir/sources.list.d/"*.list 2>/dev/null; then
            echo "embedded-classic"
        else
            echo "none"
        fi
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
