# Option 1: Hardware Detection & System Information

### 1. What Does This Component Do?

This component performs the hardware enumeration, OS validation and environment checks that the rest of the script builds on. It runs in "cold" mode, before any configuration change is made, and the other menu options read the state it initializes instead of re-detecting everything.

**Initialization** (boot checks in `debianito.sh`, hardware state on demand via `_ensure_state_detected`):

1. **Dependency auto-install**: The script checks for `whiptail` and `lsb-release`, installing them automatically if missing, so the TUI and version detection work on minimal systems.
2. **`lspci` guard and cache**: `command -v lspci &>/dev/null` validates availability before execution. If present, the full `lspci -nn` output is captured once into the global variable `LSPCI_OUTPUT`. All subsequent GPU, Ethernet, and network detection reads from this cache, avoiding redundant `lspci` invocations and keeping the data consistent throughout the session.
3. **APT update deduplication**: The helper `_ensure_apt_updated` prevents redundant `apt update` calls by tracking whether the package lists have been refreshed recently. This matters for performance when multiple modules (repos, firmware, GPU, kernel) each need to verify repository state.
4. **State refresh flag**: `STATE_REFRESHED=true` is set before `;;` in every `case` branch of the main menu loop, ensuring that each menu entry starts with a clean, consistent state rather than stale cached data.

The variables it populates (`DEBIAN_VERSION`, `GPU_TYPE`, `CPU_SUMMARY`, network interface states) give the later menu options real context, so the user is not asked to make blind decisions: installing proprietary drivers on hardware that is not there, or selecting repositories that do not match the current Debian codename.

### 2. System Commands Used (Technical Mapping)

The table below maps each piece of diagnostic data to the standard Linux tool `utils.sh` reads it from; none of it needs proprietary binaries.

| Feature | Command / Tool | Technical Purpose & Logic |
| :--- | :--- | :--- |
| **OS Version** | `lsb_release -cs`, `/etc/os-release` | Parses `VERSION_CODENAME` to determine Debian release (Bullseye, Bookworm, Trixie). Critical for selecting correct repository backports. |
| **CPU Info** | `/proc/cpuinfo` | Reads `model name` and counts cores/threads. Provides cosmetic summary without needing heavy tools like `lscpu`. |
| **Memory** | `/proc/meminfo` | Extracts `MemTotal` to calculate RAM in GB. Used for compatibility warnings with specific software packages. |
| **GPU Detection** | `command -v lspci` guard → cached `LSPCI_OUTPUT` | `lspci -nn` output is cached in the global variable `LSPCI_OUTPUT` on first hardware access (`_ensure_state_detected`). All subsequent GPU detection (PCI/USB buses, Ethernet, network) reads from this cache instead of re-running `lspci`. Identifies VGA/3D controllers via PCI IDs (`10de` for NVIDIA). Checks driver versions via `dpkg` if `nvidia-smi` fails. |
| **Network (Eth)** | `ip -o link show` | Enumerates Ethernet interfaces, state (UP/DOWN), and IP addresses using the `iproute2` suite. |
| **Network (Wi-Fi)** | `iwgetid`, `lspci` | Identifies wireless chipsets via PCI and retrieves SSID/Connection status for network diagnostics. |
| **Storage** | `lsblk -d -o NAME,SIZE,ROTA` | Distinguishes between NVMe (`nvme`), SSD (RoT=0), and HDD (RoT=1) to provide storage topology summary. |
| **Display Server** | Environment Vars (`XDG_SESSION_TYPE`) | Checks `WAYLAND_DISPLAY` vs `DISPLAY` variables to determine if the system is running Wayland, X11, or TTY. |

### 3. Why Detection Matters

Each check protects a different part of the script:

* **Context-Aware Configuration:** The detection of `HAS_NVIDIA`, `HAS_AMD`, or `HAS_INTEL` directly dictates which sub-modules are loaded in `debianito.sh`. If no GPU is detected, graphics driver menus are skipped. This prevents "false positive" installation prompts that confuse the user.
* **Repository Compatibility Guardrails:** The `detect_debian_version` function validates the OS against supported codenames (11, 12, 13). It specifically triggers Bullseye-specific logic (`configure_repos_bullseye`) only when necessary, preventing repository errors on newer or older distributions.
* **APT Update Deduplication:** The `_ensure_apt_updated` helper tracks whether `apt update` has been run recently. Multiple modules (repos, firmware, GPU, kernel) share a single update cycle, preventing redundant network calls and inconsistent package state between modules.
* **State Refresh Consistency:** `STATE_REFRESHED=true` is set before `;;` in every `case` branch of the main menu loop, ensuring each menu entry starts with a clean state and preventing stale variable propagation between sequential selections.
* **Time Synchronization Safety:** The `check_system_time` function prevents package installation failures caused by clock skew, which breaks APT's GPG signatures. It offers an automated NTP sync before proceeding so the signatures verify again.
* **Root/Sudo Enforcement:** Early execution of `check_root` and `check_sudo` enforces security best practices. It prevents accidental privilege escalation or silent failures that often occur when scripts run with incorrect permissions.

### 4. Formatting and UX in the Terminal

The raw data collected by these functions is processed into a human-readable format before being passed to the TUI (Text User Interface) via `whiptail`.

* **Structured String Assembly:** Functions like `_show_sysinfo` build multi-line strings (`msg+="...")`, appending newlines and conditional logic. This ensures that if multiple GPUs are found, they are listed sequentially with drivers identified below each entry.
* **Visual Hierarchy:** The data is organized into logical blocks (OS, Hardware, GPU, Network) with clear separators (`───`). This allows the user to quickly scan specific subsystems without scrolling through a monolithic log.
* **Conditional Rendering:** The script checks for command availability (e.g., `if ! command -v lspci &>/dev/null` guards GPU detection, `if ! command -v ip &>/dev/null` guards network data). If tools are missing, it gracefully degrades to a warning message rather than crashing the TUI. When `lspci` is present, its output is cached in `LSPCI_OUTPUT` for all subsequent detection calls.
* **TUI Integration:** The final formatted string is passed to `_msg`, which wraps the output in a `whiptail --msgbox`. This makes the diagnostic information appear as a modal dialog with consistent dimensions and styling (colors defined globally in `debianito.sh`), regardless of the underlying terminal emulator.
