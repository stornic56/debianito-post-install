#!/usr/bin/env bash
# utils.bats — Offline tests for modules/utils.sh.
#
# No `set -euo pipefail` here: BATS controls error handling
# per test — any failing command in a test body fails the
# test, and `run` already isolates the commands under test.
#
# `run` executes its command in a SUBSHELL, so global side
# effects would be lost.  The state-mutating functions
# (_init_lspci_cache, detect_network) are therefore called
# DIRECTLY and the globals they set (LSPCI_OUTPUT, the
# ETH_* / WIFI_* arrays) are asserted afterwards.

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

# ── Shared fixtures ─────────────────────────────────────
# Hardware view for the detect_network tests: one Intel
# Ethernet controller, one Intel Wi-Fi 6 controller, and
# `ip -o link show` output with lo (UNKNOWN), eth0 (UP)
# and wlan0 (UP, with IPv4 address and SSID).
_setup_detect_network_fixtures() {
    MOCK_LSPCI_OUTPUT="00:19.0 Ethernet controller [0200]: Intel Corporation Ethernet Connection (7) I219-LM [8086:1533] (rev 10)
01:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX200 [8086:2725] (rev 1a)"
    MOCK_IP_LINK_OUTPUT="1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
3: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000"
    MOCK_IP_ADDR_OUTPUT="eth0 192.168.1.10/24
wlan0 10.0.0.5/24"
    MOCK_SSID_OUTPUT="CasaWiFi"

    # Populate the global cache from the lspci mock
    # (exercises the timeout-wrapped PATH mock chain).
    LSPCI_OUTPUT=""
    _init_lspci_cache
}

# ── is_installed ────────────────────────────────────────
@test "is_installed returns 0 for an installed package" {
    MOCK_DPKG_INSTALLED="curl wget"
    run is_installed curl
    [ "$status" -eq 0 ]
}

@test "is_installed returns 1 for a missing package" {
    MOCK_DPKG_INSTALLED="curl wget"
    run is_installed vim
    [ "$status" -eq 1 ]
}

# ── _get_pkg_version ────────────────────────────────────
@test "_get_pkg_version parses the candidate from policy line 3" {
    MOCK_APT_CACHE_POLICY_OUTPUT="curl:
  Installed: 1.2.3-1
  Candidate: 1.2.3"
    run _get_pkg_version curl
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3" ]
}

# ── _get_backports_version ──────────────────────────────
@test "_get_backports_version returns the backports version" {
    MOCK_APT_CACHE_MADISON_OUTPUT=" curl | 1.2.3-1 | https://deb.debian.org/debian bookworm/main amd64 Packages
 curl | 1.2.3-1~bpo12+1 | https://deb.debian.org/debian bookworm-backports/main amd64 Packages"
    run _get_backports_version curl bookworm
    [ "$status" -eq 0 ]
    [ "$output" = "1.2.3-1~bpo12+1" ]
}

@test "_get_backports_version defaults the codename to DEBIAN_CODENAME" {
    MOCK_APT_CACHE_MADISON_OUTPUT=" curl | 1.2.3-1~bpo12+1 | https://deb.debian.org/debian bookworm-backports/main amd64 Packages"
    run _get_backports_version curl
    [ "$output" = "1.2.3-1~bpo12+1" ]
}

@test "_get_backports_version prints nothing without a backports entry" {
    MOCK_APT_CACHE_MADISON_OUTPUT=" curl | 1.2.3-1 | https://deb.debian.org/debian bookworm/main amd64 Packages"
    run _get_backports_version curl bookworm
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── _state ──────────────────────────────────────────────
@test "_state prints ON for an installed package" {
    MOCK_DPKG_INSTALLED="curl"
    run _state curl
    [ "$output" = "ON" ]
}

@test "_state prints OFF for a missing package" {
    MOCK_DPKG_INSTALLED=""
    run _state curl
    [ "$output" = "OFF" ]
}

# ── detect_network ──────────────────────────────────────
@test "detect_network fills ETH_NAMES and WIFI_NAMES from mocked hardware" {
    _setup_detect_network_fixtures
    detect_network

    # Ethernet (PCI) interface
    [ "${#ETH_NAMES[@]}" -eq 1 ]
    [ "${ETH_NAMES[0]}" = "eth0" ]
    [ "${ETH_STATES[0]}" = "UP" ]
    [ "${ETH_IPS[0]}" = "192.168.1.10/24" ]
    [ "$ETH_DESC" = "Intel Corporation Ethernet Connection (7) I219-LM" ]

    # WiFi (PCI) interface
    [ "${#WIFI_NAMES[@]}" -eq 1 ]
    [ "${WIFI_NAMES[0]}" = "wlan0" ]
    [ "${WIFI_STATES[0]}" = "UP" ]
    [ "${WIFI_IPS[0]}" = "10.0.0.5/24" ]
    [ "${WIFI_SSIDS[0]}" = "CasaWiFi" ]
    [ "$WIFI_DESC" = "Intel Corporation Wi-Fi 6 AX200" ]
}

@test "detect_network does not duplicate arrays when called twice (BH-013)" {
    _setup_detect_network_fixtures

    detect_network
    local eth_count=${#ETH_NAMES[@]}
    local wifi_count=${#WIFI_NAMES[@]}

    detect_network

    # BH-013: the arrays must be reset and refilled, never appended to.
    [ "${#ETH_NAMES[@]}" -eq "$eth_count" ]
    [ "${#WIFI_NAMES[@]}" -eq "$wifi_count" ]
    [ "${#ETH_NAMES[@]}" -eq 1 ]
    [ "${#WIFI_NAMES[@]}" -eq 1 ]
    [ "${ETH_NAMES[0]}" = "eth0" ]
    [ "${WIFI_NAMES[0]}" = "wlan0" ]
}
