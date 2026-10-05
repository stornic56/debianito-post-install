#!/usr/bin/env bash
# test_helper.bash — Setup and offline system mocks for the
# debianito BATS test suite.
#
# Layout
# ------
#   load_utils()      Safe loading of the modules under test.
#   _mock_*()         Mock implementations (one per command).
#   _install_mocks()  Serializes the _mock_* functions into
#                     standalone executables under $MOCK_BIN_DIR.
#   mock_reset()      Per-test fixture reset + PATH setup.
#
# Why PATH-based mock scripts instead of plain shell functions?
# ------------------------------------------------------------
# _init_lspci_cache() runs `timeout 2 lspci -nn` and
# detect_network() runs `timeout 2 ip -o link show`,
# `timeout 2 ip -4 -o addr show <iface>` and
# `timeout 2 iwgetid -r <iface>`.  timeout(1) execs its
# target as a CHILD PROCESS, and a child process cannot see
# the shell functions of its parent.  The _mock_* functions
# are therefore written to disk as real executables
# (self-contained: shebang + `declare -f` output + dispatch
# line) and $MOCK_BIN_DIR is prepended to PATH, so both
# direct calls and timeout-wrapped calls hit the mocks.
#
# Everything here is 100% offline: no network, no apt
# update, and no real package is installed or removed.
#
# shellcheck disable=SC2148

# ── Locations ──────────────────────────────────────────────────
[ -n "${BATS_TEST_DIRNAME:-}" ] || {
    echo "test_helper.bash must be loaded from a BATS test file" >&2
    return 1 2>/dev/null || exit 1
}

TEST_PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export TEST_PROJECT_ROOT

# Holds the generated mock executables (created once per
# load; the OS cleans /tmp, so no per-test cleanup needed).
MOCK_BIN_DIR="$(mktemp -d "${TMPDIR:-/tmp}/debianito-mocks.XXXXXX")"
export MOCK_BIN_DIR

# ── Safe module loading ────────────────────────────────────────
# Contract (verified against the current sources):
#   * modules/utils.sh and modules/repos/repo_detect.sh
#     contain ONLY function definitions and variable
#     assignments — no top-level command execution — so
#     sourcing them is side-effect free.
#   * debianito.sh itself must NEVER be sourced from tests:
#     it executes the module chain and the menu at top
#     level.
load_utils() {
    local f
    for f in modules/utils.sh modules/repos/repo_detect.sh; do
        if [ ! -f "${TEST_PROJECT_ROOT}/${f}" ]; then
            echo "load_utils: missing ${TEST_PROJECT_ROOT}/${f}" >&2
            return 1
        fi
    done

    # shellcheck source=modules/utils.sh
    source "${TEST_PROJECT_ROOT}/modules/utils.sh"
    # shellcheck source=modules/repos/repo_detect.sh
    source "${TEST_PROJECT_ROOT}/modules/repos/repo_detect.sh"

    # Note: sourcing from inside a function makes the
    # top-level `declare -a ETH_NAMES=()` & co. of utils.sh
    # function-local; they vanish when load_utils() returns.
    # That is harmless — the functions under test assign
    # those arrays as globals at call time (e.g. the BH-013
    # reset at the top of detect_network()), so their
    # behaviour is unchanged.
    :
}

# ── Globals that debianito.sh normally defines ───────────────
# The modules consume them at call time only.  Colour codes
# are kept EMPTY on purpose so output assertions stay clean.
export RED="" GREEN="" YELLOW="" CYAN="" NC=""
export DEBIAN_CODENAME="bookworm"
export DEBIAN_VERSION="12"
export MODULES_DIR="${TEST_PROJECT_ROOT}/modules"

# ════════════════════════════════════════════════════════════
# Mock implementations
#
# Each mock reads its canned data from MOCK_* environment
# variables, so a test injects predictable output with a
# plain assignment (the vars are exported by mock_reset, and
# assigning to an exported var keeps the export attribute):
#
#   MOCK_DPKG_INSTALLED             space-separated "installed" packages
#   MOCK_DPKG_VERSION               version reported for installed pkgs
#   MOCK_APT_CACHE_POLICY_OUTPUT    `apt-cache policy <pkg>` output
#   MOCK_APT_CACHE_MADISON_OUTPUT   `apt-cache madison <pkg>` output
#   MOCK_APT_CACHE_SEARCH_OUTPUT    `apt-cache search <re>` output
#   MOCK_LSPCI_OUTPUT               `lspci -nn` output
#   MOCK_LSUSB_OUTPUT               `lsusb` output
#   MOCK_IP_LINK_OUTPUT             `ip -o link show` output
#   MOCK_IP_ADDR_OUTPUT             "iface cidr" lines for
#                                     `ip -4 -o addr show <iface>`
#   MOCK_SSID_OUTPUT                `iwgetid -r <iface>` output
#   MOCK_TIMEZONE_OUTPUT            `timedatectl show -p Timezone --value`
#   MOCK_NTP_SYNC_OUTPUT            `timedatectl show --property=NTPSynchronized --value`
#   MOCK_WHIPTAIL_OUTPUT / _RC      whiptail stdout / exit code
#   MOCK_SUDO_DRY_RUN               1 = log-only sudo (see _mock_sudo)
#   MOCK_SUDO_LOG                   log file for dry-run sudo
#   MOCK_APT_ROOT                   per-test fixture mirror of /etc/apt,
#                                     exported to the code under test as
#                                     APT_DIR (see the APT_DIR
#                                     indirection in utils.sh and
#                                     repos/repo_detect.sh)
# ════════════════════════════════════════════════════════════

# ── dpkg(1) ───────────────────────────────────────────────────
# `dpkg -l <pkg>` prints an "ii" status line and exits 0
# when <pkg> is listed in $MOCK_DPKG_INSTALLED; prints
# nothing and exits 1 otherwise (real dpkg -l reports
# "no packages found" with status 1).  is_installed()
# greps for a leading "ii", so the line prefix is what
# matters — both are implemented faithfully anyway.
_mock_dpkg() {
    local pkg="${@: -1}"    # last argument
    local installed
    for installed in ${MOCK_DPKG_INSTALLED:-}; do
        if [ "$installed" = "$pkg" ]; then
            printf 'ii  %s  %s  all  mock package\n' \
                "$pkg" "${MOCK_DPKG_VERSION:-1.0.0-mock}"
            return 0
        fi
    done
    return 1
}

# ── apt-cache(8) ──────────────────────────────────────────────
# Canned output per subcommand.  The policy fixture needs at
# least 3 lines: _get_pkg_version() parses field 2 of line
# 3 (the "Candidate:" line in real output).
_mock_apt_cache() {
    local sub="${1:-}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        policy)
            [ -n "${MOCK_APT_CACHE_POLICY_OUTPUT:-}" ] &&
                printf '%s\n' "${MOCK_APT_CACHE_POLICY_OUTPUT}"
            ;;
        madison)
            [ -n "${MOCK_APT_CACHE_MADISON_OUTPUT:-}" ] &&
                printf '%s\n' "${MOCK_APT_CACHE_MADISON_OUTPUT}"
            ;;
        search)
            [ -n "${MOCK_APT_CACHE_SEARCH_OUTPUT:-}" ] &&
                printf '%s\n' "${MOCK_APT_CACHE_SEARCH_OUTPUT}"
            ;;
    esac
    return 0
}

# ── lspci(8) ──────────────────────────────────────────────────
# Prints $MOCK_LSPCI_OUTPUT verbatim; arguments (-nn) are
# ignored.  Served through the PATH wrapper because
# _init_lspci_cache() captures `timeout 2 lspci -nn`.
_mock_lspci() {
    printf '%s' "${MOCK_LSPCI_OUTPUT:-}"
    return 0
}

# ── lsusb(8) ──────────────────────────────────────────────────
# Prints $MOCK_LSUSB_OUTPUT verbatim.  detect_network()
# uses it as the USB-WiFi fallback (layer 4) when no PCI
# wireless device exists.
_mock_lsusb() {
    printf '%s' "${MOCK_LSUSB_OUTPUT:-}"
    return 0
}

# ── ip(8) ─────────────────────────────────────────────────────
# Just enough for detect_network():
#   ip -o link show              → one line per interface
#                                    ($MOCK_IP_LINK_OUTPUT)
#   ip -4 -o addr show <iface>  → a full "ip -o" line whose
#                                    4th whitespace field is
#                                    the IPv4 CIDR of <iface>,
#                                    looked up from the
#                                    "iface cidr" lines of
#                                    $MOCK_IP_ADDR_OUTPUT
_mock_ip() {
    case "$1 $2" in
        "-o link")
            # Real `ip` terminates its output with a newline;
            # `while read` loops (detect_network) drop the last
            # line of an unterminated stream, so the mock must
            # terminate it too.
            if [ -n "${MOCK_IP_LINK_OUTPUT:-}" ]; then
                printf '%s\n' "${MOCK_IP_LINK_OUTPUT:-}"
            fi
            ;;
        "-4 -o")
            local iface="${5:-}" name cidr
            [ -z "$iface" ] && return 0
            while IFS=' ' read -r name cidr; do
                if [ "$name" = "$iface" ]; then
                    printf '2: %s inet %s brd 192.168.1.255 scope global dynamic %s\n' \
                        "$iface" "$cidr" "$iface"
                    return 0
                fi
            done <<EOF
${MOCK_IP_ADDR_OUTPUT:-}
EOF
            ;;
    esac
    return 0
}

# ── iwgetid(1) ────────────────────────────────────────────────
# Prints $MOCK_SSID_OUTPUT.  detect_network() calls it only
# for interfaces whose link state is UP.
_mock_iwgetid() {
    printf '%s' "${MOCK_SSID_OUTPUT:-}"
    return 0
}

# ── timedatectl(1) ────────────────────────────────────────────
# Just enough for _ensure_time_synced():
#   show -p Timezone --value              → $MOCK_TIMEZONE_OUTPUT
#   show --property=NTPSynchronized --value → $MOCK_NTP_SYNC_OUTPUT
_mock_timedatectl() {
    case "$1 $2" in
        "show -p")
            printf '%s\n' "${MOCK_TIMEZONE_OUTPUT:-UTC}"
            ;;
        "show --property="*)
            printf '%s\n' "${MOCK_NTP_SYNC_OUTPUT:-no}"
            ;;
    esac
    return 0
}

# ── sudo(8) ───────────────────────────────────────────────────
# Spec behaviour: execute the command it receives, without
# asking for a password.  sudo's own flags (-v, -n, -H, …)
# are stripped; the rest runs through env(1) so that
# `sudo VAR=val cmd` prefixes work too.
#
# ⚠ WARNING: the command executes FOR REAL.  Only exercise
# sudo code paths with benign commands (file copies, echo,
# true, …).  Set MOCK_SUDO_DRY_RUN=1 to switch to
# logging-only mode: the invocation is appended to
# $MOCK_SUDO_LOG and the mock exits 0 without executing
# anything — the safe choice for tests that touch
# privileged code paths.
_mock_sudo() {
    if [ "${MOCK_SUDO_DRY_RUN:-0}" = "1" ]; then
        printf '%s\n' "$*" >>"${MOCK_SUDO_LOG:-/tmp/debianito-sudo-mock.log}"
        return 0
    fi
    while [ $# -gt 0 ]; do
        case "$1" in
            -*) shift ;;
            *)  break ;;
        esac
    done
    [ $# -eq 0 ] && return 0    # e.g. `sudo -v`
    env "$@"
}

# ── whiptail(1) ───────────────────────────────────────────────
# Prints $MOCK_WHIPTAIL_OUTPUT on stdout and exits with
# $MOCK_WHIPTAIL_RC (default 0 = "Yes" for confirm
# dialogs).  Not used by the current tests; future-proofs
# the _confirm / _menu / _checklist helpers.
_mock_whiptail() {
    printf '%s' "${MOCK_WHIPTAIL_OUTPUT:-}"
    return "${MOCK_WHIPTAIL_RC:-0}"
}

# ── Mock installation ─────────────────────────────────────────
# Serializes every _mock_* function into a standalone
# executable under $MOCK_BIN_DIR (shebang + `declare -f`
# output + dispatch line).  See the header comment for why
# PATH scripts are required.
_install_mocks() {
    local name func
    for name in dpkg apt-cache lspci lsusb ip iwgetid timedatectl sudo whiptail; do
        func="_mock_${name//-/_}"    # apt-cache → _mock_apt_cache
        if ! declare -f "$func" >/dev/null; then
            echo "test_helper.bash: mock function ${func} is not defined" >&2
            return 1
        fi
        {
            printf '#!/usr/bin/env bash\n'
            declare -f "$func"
            printf '%s "$@"\n' "$func"
        } >"${MOCK_BIN_DIR}/${name}"
        chmod +x "${MOCK_BIN_DIR}/${name}"
    done
}

# ── Per-test reset ────────────────────────────────────────────
# Restores every fixture to a predictable empty state and
# puts the mock bin dir first on PATH.  Call from setup() in
# each .bats file: BATS runs every test in a fresh subshell,
# so PATH changes never leak between tests.
mock_reset() {
    # dpkg(1)
    export MOCK_DPKG_INSTALLED=""
    export MOCK_DPKG_VERSION="1.0.0-mock"

    # apt-cache(8)
    export MOCK_APT_CACHE_POLICY_OUTPUT=""
    export MOCK_APT_CACHE_MADISON_OUTPUT=""
    export MOCK_APT_CACHE_SEARCH_OUTPUT=""

    # hardware
    export MOCK_LSPCI_OUTPUT=""
    export MOCK_LSUSB_OUTPUT=""
    export MOCK_IP_LINK_OUTPUT=""
    export MOCK_IP_ADDR_OUTPUT=""
    export MOCK_SSID_OUTPUT=""

    # systemd
    export MOCK_TIMEZONE_OUTPUT="UTC"
    export MOCK_NTP_SYNC_OUTPUT="no"

    # dialogs
    export MOCK_WHIPTAIL_OUTPUT=""
    export MOCK_WHIPTAIL_RC="0"

    # sudo(8)
    export MOCK_SUDO_DRY_RUN="0"
    export MOCK_SUDO_LOG="$(mktemp)"

    # /etc/apt(5) fixture mirror.  The modules under test read
    # ${APT_DIR:-/etc/apt} (APT_DIR indirection added for
    # testability), so tests build fixture trees inside
    # $MOCK_APT_ROOT instead of touching the real /etc/apt.
    # Fresh per test: fixtures never leak between tests.
    export MOCK_APT_ROOT="$(mktemp -d)"
    export APT_DIR="${MOCK_APT_ROOT}"

    export PATH="${MOCK_BIN_DIR}:${PATH}"
}

# Generate the mock executables once, when this helper is
# loaded.
_install_mocks
