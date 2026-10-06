#!/usr/bin/env bash
# desktops.bats — Offline tests for the desktop helpers in
# modules/desktop_display.sh (SP2) and the desktop module
# wiring in _load_module (SP2.5).
#
# No `set -euo pipefail` here: BATS controls error handling
# per test (see utils.bats).
#
# State-mutating functions are called DIRECTLY (a `run`
# subshell would lose their globals); pure-output helpers
# use `run`.
#
# 100% offline: dpkg and whiptail come from the PATH mocks
# in test_helper.bash, systemctl uses the helper mock,
# /etc/X11/default-display-manager is redirected through the
# DM_FILE fixture, and the real audio installer is replaced
# by a call-counter stub.

load test_helper.bash

# Stub for modules/system/audio.sh (never loaded here):
# count calls instead of running apt. Counter reset in setup().
_install_pipewire_standard() {
    PIPEWIRE_INSTALL_CALLS=$((PIPEWIRE_INSTALL_CALLS + 1))
}

setup() {
    mock_reset
    load_utils
    # load_utils() sources utils.sh inside a function, so the
    # top-level `declare -A _LOADED_MODULES` (utils.sh:48) was
    # function-local and vanished when it returned — the same
    # caveat the helper documents for the ETH_* arrays.
    # Re-declare it globally for the _load_module tests.
    declare -gA _LOADED_MODULES=()

    # Only function definitions at the top level: safe to source.
    source "${TEST_PROJECT_ROOT}/modules/desktop_display.sh"

    # Fixture redirect for /etc/X11/default-display-manager:
    # the file exists but is empty, so `-s` fails and the
    # systemctl fallback is exercised deterministically.
    DM_FILE="$(mktemp)"
    export DM_FILE

    PIPEWIRE_INSTALL_CALLS=0
}

teardown() {
    if [ -n "${DM_FILE:-}" ]; then
        rm -f "$DM_FILE"
    fi
    if [ -n "${MOCK_SUDO_LOG:-}" ]; then
        rm -f "$MOCK_SUDO_LOG"
    fi
    if [ -n "${MOCK_APT_ROOT:-}" ]; then
        rm -rf "$MOCK_APT_ROOT"
    fi
}

# ── _existing_display_manager ────────────────────────
@test "_existing_display_manager reads the default DM file" {
    printf '/usr/sbin/gdm3\n' >"$DM_FILE"
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ "$output" = "gdm3" ]
}

@test "_existing_display_manager prefers the DM file over an enabled unit" {
    printf '/usr/sbin/sddm\n' >"$DM_FILE"
    export MOCK_SYSTEMCTL_ENABLED="gdm3"
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ "$output" = "sddm" ]
}

@test "_existing_display_manager falls back to an enabled systemd unit" {
    # DM_FILE exists but is empty: `-s` must fail, not `-e`.
    export MOCK_SYSTEMCTL_ENABLED="lightdm"
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ "$output" = "lightdm" ]
}

@test "_existing_display_manager evaluates units in candidate order" {
    # gdm3 → lightdm → sddm → greetd → gdm, whatever order
    # systemctl reports them in.
    export MOCK_SYSTEMCTL_ENABLED="sddm lightdm"
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ "$output" = "lightdm" ]
}

@test "_existing_display_manager falls back when the DM file is missing" {
    rm -f "$DM_FILE"
    export MOCK_SYSTEMCTL_ENABLED="greetd"
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ "$output" = "greetd" ]
}

@test "_existing_display_manager prints nothing when nothing is configured" {
    run _existing_display_manager
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── _offer_pipewire_after_desktop ────────────────────
@test "_offer_pipewire_after_desktop skips without prompting when pipewire-audio is installed" {
    MOCK_DPKG_INSTALLED="pipewire-audio"
    WHIPTAIL_CALLS=0
    whiptail() { WHIPTAIL_CALLS=$((WHIPTAIL_CALLS + 1)); }
    _offer_pipewire_after_desktop
    [ "$WHIPTAIL_CALLS" -eq 0 ]
    [ "$PIPEWIRE_INSTALL_CALLS" -eq 0 ]
}

@test "_offer_pipewire_after_desktop installs the stack when accepted" {
    export MOCK_WHIPTAIL_RC=0 # user answers "Yes"
    _offer_pipewire_after_desktop
    [ "$PIPEWIRE_INSTALL_CALLS" -eq 1 ]
}

@test "_offer_pipewire_after_desktop returns 0 without installing when declined" {
    export MOCK_WHIPTAIL_RC=1 # user answers "No"
    offer_rc=0
    _offer_pipewire_after_desktop || offer_rc=$?
    [ "$offer_rc" -eq 0 ]
    [ "$PIPEWIRE_INSTALL_CALLS" -eq 0 ]
}

@test "_offer_pipewire_after_desktop checks the pipewire package on Bullseye" {
    export DEBIAN_VERSION="11"
    MOCK_DPKG_INSTALLED="pipewire" # Bullseye package name
    _offer_pipewire_after_desktop
    [ "$PIPEWIRE_INSTALL_CALLS" -eq 0 ]
}

@test "_offer_pipewire_after_desktop ignores pipewire-audio on Bullseye" {
    export DEBIAN_VERSION="11"
    MOCK_DPKG_INSTALLED="pipewire-audio" # wrong name on 11
    export MOCK_WHIPTAIL_RC=0            # user accepts
    _offer_pipewire_after_desktop
    [ "$PIPEWIRE_INSTALL_CALLS" -eq 1 ]
}

# ── _load_module: desktop wiring (SP2.5) ─────────────
# The dependency cascade is not under test here: mark the
# transitive deps of the desktop modules as loaded so only
# the module file itself is sourced.
_load_module_with_deps_marked() {
    local module="$1"
    declare -gA _LOADED_MODULES=(
        [desktop_display]=1
        [audio]=1
        [repos]=1
        [repo_detect]=1
    )
    _load_module "$module"
}

@test "_load_module xfce sources modules/desktops/desktop_xfce.sh" {
    _load_module_with_deps_marked xfce
    type xfce_menu >/dev/null
    type _install_xfce_custom >/dev/null
    type _xfce_polkit_rules >/dev/null
}

@test "_load_module lxde sources modules/desktops/desktop_lxde.sh" {
    _load_module_with_deps_marked lxde
    type lxde_menu >/dev/null
    type _install_lxde_full >/dev/null
}

@test "_load_module gnome sources modules/desktops/desktop_gnome.sh" {
    _load_module_with_deps_marked gnome
    type gnome_menu >/dev/null
    type _install_gnome_full >/dev/null
}

@test "_load_module kde sources modules/desktops/desktop_kde.sh" {
    _load_module_with_deps_marked kde
    type kde_menu >/dev/null
    type _install_kde_minimal >/dev/null
}

@test "_load_module returns 1 for an unknown module" {
    run _load_module no_such_module
    [ "$status" -eq 1 ]
}
