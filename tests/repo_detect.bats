#!/usr/bin/env bash
# repo_detect.bats — Offline tests for modules/repos/repo_detect.sh
# and is_backports_enabled() from modules/utils.sh.
#
# No `set -euo pipefail` here: BATS controls error handling
# per test.
#
# The modules under test read ${APT_DIR:-/etc/apt} (the APT_DIR
# indirection added for testability).  mock_reset() points APT_DIR
# at a fresh empty $MOCK_APT_ROOT per test, and every test builds
# its own fixture tree inside it — the real /etc/apt is never
# read, so the suite is 100% offline and hermetic.
#
# Every function under test answers via stdout (echo
# true/false/deb822/...), so `run` + `$output` is the natural
# assertion style.

load test_helper.bash

setup() {
    mock_reset
    load_utils
}

teardown() {
    if [ -n "${MOCK_SUDO_LOG:-}" ]; then
        rm -f "$MOCK_SUDO_LOG"
    fi
    if [ -n "${MOCK_APT_ROOT:-}" ]; then
        rm -rf "$MOCK_APT_ROOT"
    fi
}

# ── Fixture helper ───────────────────────────────────
# Write one fixture file inside the mock apt root, with one
# content line per argument:
#   _fixt_file sources.list "deb ... bookworm main" ...
#   _fixt_file sources.list.d/debian.sources "Types: deb" ...
_fixt_file() {
    local rel="$1"
    shift
    mkdir -p "${MOCK_APT_ROOT}/$(dirname "$rel")"
    printf '%s\n' "$@" >"${MOCK_APT_ROOT}/${rel}"
}

# ── is_backports_enabled (modules/utils.sh) ──────────
@test "is_backports_enabled returns true with backports in sources.list" {
    _fixt_file sources.list \
        "deb http://deb.debian.org/debian bookworm main" \
        "deb http://deb.debian.org/debian bookworm-updates main" \
        "deb http://deb.debian.org/debian bookworm-backports main"
    run is_backports_enabled
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "is_backports_enabled returns false without backports" {
    _fixt_file sources.list \
        "deb http://deb.debian.org/debian bookworm main" \
        "deb http://deb.debian.org/debian bookworm-updates main"
    run is_backports_enabled
    [ "$status" -eq 0 ]
    [ "$output" = "false" ]
}

@test "is_backports_enabled returns true with a standalone backports .list file" {
    _fixt_file sources.list.d/debian-backports.list \
        "deb http://deb.debian.org/debian bookworm-backports main"
    run is_backports_enabled
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

@test "is_backports_enabled returns true with a deb822 backports suite" {
    _fixt_file sources.list.d/debian-backports.sources \
        "Types: deb" \
        "URIs: http://deb.debian.org/debian" \
        "Suites: bookworm-backports" \
        "Components: main" \
        "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg"
    run is_backports_enabled
    [ "$status" -eq 0 ]
    [ "$output" = "true" ]
}

# ── detect_repo_format ───────────────────────────────
@test "detect_repo_format returns deb822 for a debian.sources file" {
    # DEB822 is only valid on Debian 13 (Trixie).
    DEBIAN_VERSION="13"
    _fixt_file sources.list.d/debian.sources \
        "Types: deb" \
        "URIs: http://deb.debian.org/debian" \
        "Suites: bookworm bookworm-updates" \
        "Components: main contrib non-free non-free-firmware" \
        "Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg"
    run detect_repo_format
    [ "$status" -eq 0 ]
    [ "$output" = "deb822" ]
}

@test "detect_repo_format returns classic for a classic sources.list" {
    _fixt_file sources.list \
        "deb http://deb.debian.org/debian bookworm main" \
        "deb http://deb.debian.org/debian bookworm-updates main"
    run detect_repo_format
    [ "$status" -eq 0 ]
    [ "$output" = "classic" ]
}

@test "detect_repo_format returns none for an empty apt root" {
    run detect_repo_format
    [ "$status" -eq 0 ]
    [ "$output" = "none" ]
}
