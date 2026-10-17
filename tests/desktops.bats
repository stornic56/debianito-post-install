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
    # Only function definitions at the top level: safe to source.
    source "${TEST_PROJECT_ROOT}/modules/desktop_display.sh"
    # The GNOME installers are pure function definitions too;
    # desktop_display.sh (their DM/pipewire collaborators) is
    # already sourced above.
    source "${TEST_PROJECT_ROOT}/modules/desktops/desktop_gnome.sh"
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
    if [ -n "${SESSION_FIXTURE:-}" ]; then
        rm -rf "$SESSION_FIXTURE"
    fi
    unset SESSION_DIR_WAYLAND SESSION_DIR_X11
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

# ── terminal selection: ptyxis on trixie ──────────────
# gnome-core declares the OR-dep "gnome-terminal or
# gnome-console or ptyxis"; apt resolves an unset OR-dep
# with the first alternative, so listing the terminal
# explicitly in the same apt transaction is what steers
# the resolver. These tests assert the exact package
# that lands in the apt command.
#
# _gnome_capture_apt_cmd runs one installer with every
# external effect stubbed: _run_cmd is replaced so the
# apt command is captured instead of executed, and the
# PATH sudo mock stays in dry-run mode so debconf and
# systemctl invocations are logged, not executed.
_gnome_capture_apt_cmd() {
    local installer="$1"
    GNOME_APT_CMD=""
    _confirm_install_list() { return 0; }
    _ensure_apt_updated() { :; }
    _run_cmd() { GNOME_APT_CMD="$2"; }
    "$installer"
    printf '%s\n' "$GNOME_APT_CMD"
}

@test "GNOME Full installs ptyxis on trixie" {
    export DEBIAN_CODENAME="trixie"
    export MOCK_SUDO_DRY_RUN=1
    run _gnome_capture_apt_cmd _install_gnome_full
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y gnome gdm3 ptyxis"* ]]
    [[ "$output" != *gnome-terminal* ]]
}

@test "GNOME Core installs ptyxis on trixie" {
    export DEBIAN_CODENAME="trixie"
    export MOCK_SUDO_DRY_RUN=1
    run _gnome_capture_apt_cmd _install_gnome_core
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y gnome-core gdm3 ptyxis"* ]]
    [[ "$output" != *gnome-terminal* ]]
}

@test "GNOME Full falls back to gnome-terminal off trixie" {
    export DEBIAN_CODENAME="bookworm"
    export MOCK_SUDO_DRY_RUN=1
    run _gnome_capture_apt_cmd _install_gnome_full
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y gnome gdm3 gnome-terminal"* ]]
    [[ "$output" != *ptyxis* ]]
}

@test "GNOME falls back to gnome-terminal when the codename is empty" {
    # /etc/os-release missing or without VERSION_CODENAME
    # leaves DEBIAN_CODENAME unset: the safe default is the
    # historical behaviour.
    export DEBIAN_CODENAME=""
    export MOCK_SUDO_DRY_RUN=1
    run _gnome_capture_apt_cmd _install_gnome_full
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y gnome gdm3 gnome-terminal"* ]]
    [[ "$output" != *ptyxis* ]]
}

# ── KDE Plasma: bookworm Wayland gate ─────────────
# plasma-workspace-wayland exists only on bookworm:
# bookworm's plasma-workspace ships the X11 session
# only, so the explicit listing keeps the Wayland
# session in the transaction deterministically; off
# bookworm the package does not exist and nothing is
# named in the apt command.

# _kde_capture_apt_cmd runs one KDE installer with
# every external effect stubbed (same shape as the
# GNOME capture helper): the apt command is captured
# instead of executed, and the PATH sudo mock stays
# in dry-run mode so debconf and systemctl invocations
# are logged, not executed.
_kde_capture_apt_cmd() {
    local installer="$1"
    _load_module_with_deps_marked kde
    KDE_APT_CMD=""
    _confirm_install_list() { return 0; }
    _ensure_apt_updated() { :; }
    _run_cmd() { KDE_APT_CMD="$2"; }
    "$installer"
    printf '%s\n' "$KDE_APT_CMD"
}

# _kde_capture_confirm runs one KDE installer with the
# pre-apply summary captured instead of shown: _confirm
# records the list _confirm_install_list builds, so the
# summary content (never an empty package line) can be
# asserted directly. The pipewire follow-up offer is
# stubbed so the recorded list is the package summary.
_kde_capture_confirm() {
    local installer="$1"
    _load_module_with_deps_marked kde
    KDE_CONFIRM_LIST=""
    _confirm() { KDE_CONFIRM_LIST="$2"; return 0; }
    _ensure_apt_updated() { :; }
    _run_cmd() { :; }
    _offer_pipewire_after_desktop() { :; }
    "$installer"
    printf '%s\n' "$KDE_CONFIRM_LIST"
}

@test "_kde_wayland_pkg prints plasma-workspace-wayland on bookworm" {
    export DEBIAN_CODENAME="bookworm"
    _load_module_with_deps_marked kde
    run _kde_wayland_pkg
    [ "$status" -eq 0 ]
    [ "$output" = "plasma-workspace-wayland" ]
}

@test "_kde_wayland_pkg prints nothing off bookworm" {
    export DEBIAN_CODENAME="trixie"
    _load_module_with_deps_marked kde
    run _kde_wayland_pkg
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "KDE Full installs the Wayland session package on bookworm" {
    export DEBIAN_CODENAME="bookworm"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_apt_cmd _install_kde_full
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y kde-standard sddm plasma-workspace-wayland"* ]]
}

@test "KDE Full omits the Wayland session package off bookworm" {
    export DEBIAN_CODENAME="trixie"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_apt_cmd _install_kde_full
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y kde-standard sddm"* ]]
    [[ "$output" != *"plasma-workspace-wayland"* ]]
}

@test "KDE Minimal installs the Wayland session package on bookworm" {
    export DEBIAN_CODENAME="bookworm"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_apt_cmd _install_kde_minimal
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y kde-plasma-desktop sddm plasma-workspace-wayland"* ]]
}

@test "KDE Minimal omits the Wayland session package off bookworm" {
    export DEBIAN_CODENAME="trixie"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_apt_cmd _install_kde_minimal
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt install -y kde-plasma-desktop sddm"* ]]
    [[ "$output" != *"plasma-workspace-wayland"* ]]
}

@test "KDE Minimal summary lists the Wayland session package on bookworm" {
    export DEBIAN_CODENAME="bookworm"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_confirm _install_kde_minimal
    [ "$status" -eq 0 ]
    [[ "$output" == *"plasma-workspace-wayland"* ]]
}

@test "KDE Minimal summary shows no empty package line off bookworm" {
    export DEBIAN_CODENAME="trixie"
    export MOCK_SUDO_DRY_RUN=1
    run _kde_capture_confirm _install_kde_minimal
    [ "$status" -eq 0 ]
    [[ "$output" == *"kde-plasma-desktop"* ]]
    [[ "$output" == *"sddm"* ]]
    [[ "$output" != *"plasma-workspace-wayland"* ]]
    [[ "$output" != *"- "$'\n'* ]]
}

# ── _sddm_session_candidates: ordered session probe ──
# Existence decides (no codename gates) and Wayland is
# preferred. The roots are redirected to a per-test
# fixture tree through SESSION_DIR_WAYLAND /
# SESSION_DIR_X11 (same spirit as the DM_FILE fixture),
# so the probe never touches the real /usr/share tree.

_sddm_session_fixture() {
    SESSION_FIXTURE="$(mktemp -d)"
    mkdir -p "$SESSION_FIXTURE/wayland" "$SESSION_FIXTURE/x11"
    SESSION_DIR_WAYLAND="$SESSION_FIXTURE/wayland"
    SESSION_DIR_X11="$SESSION_FIXTURE/x11"
    export SESSION_DIR_WAYLAND SESSION_DIR_X11
}

@test "SDDM session probe prefers bookworm Wayland (plasmawayland)" {
    _sddm_session_fixture
    : >"$SESSION_DIR_WAYLAND/plasmawayland.desktop"
    : >"$SESSION_DIR_X11/plasma.desktop"
    run _sddm_session_candidates
    [ "$status" -eq 0 ]
    [ "$output" = "plasmawayland" ]
}

@test "SDDM session probe picks trixie Wayland (plasma.desktop)" {
    _sddm_session_fixture
    : >"$SESSION_DIR_WAYLAND/plasma.desktop"
    : >"$SESSION_DIR_X11/plasmax11.desktop"
    run _sddm_session_candidates
    [ "$status" -eq 0 ]
    [ "$output" = "plasma" ]
}

@test "SDDM session probe falls back to trixie X11 (plasmax11)" {
    _sddm_session_fixture
    : >"$SESSION_DIR_X11/plasmax11.desktop"
    run _sddm_session_candidates
    [ "$status" -eq 0 ]
    [ "$output" = "plasmax11" ]
}

@test "SDDM session probe keeps LXQt last when no KDE session exists" {
    _sddm_session_fixture
    : >"$SESSION_DIR_WAYLAND/lxqt-wayland.desktop"
    : >"$SESSION_DIR_X11/lxqt.desktop"
    run _sddm_session_candidates
    [ "$status" -eq 0 ]
    [ "$output" = "lxqt-wayland" ]
}

@test "SDDM session probe returns empty when no session file exists" {
    _sddm_session_fixture
    run _sddm_session_candidates
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
