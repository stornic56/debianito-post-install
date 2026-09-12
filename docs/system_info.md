# Option 1: Hardware Detection & System Information

### 1. What Does This Component Do?

This component serves as the **System Abstraction Layer** and diagnostic engine of the Debianito script. It is not merely a display utility; it acts as the foundational state initializer that runs prior to the main menu loop (`main_menu`). Its primary function is to perform pre-flight hardware enumeration, OS validation, and environment checks in "cold" mode (before any configuration changes are made).

**Pre-flight initialization** (`debianito.sh` startup sequence):

1. **Dependency auto-install**: The script checks for `whiptail` and `lsb-release`, installing them automatically if missing — ensuring the TUI and version detection work on minimal systems.
2. **`lspci` guard and cache**: `command -v lspci &>/dev/null` validates availability before execution. If present, the full `lspci -nn` output is captured once into the global variable `LSPCI_OUTPUT`. All subsequent GPU, Ethernet, and network detection reads from this cache — avoiding redundant `lspci` invocations and ensuring consistent data throughout the session.
3. **APT update deduplication**: The helper `_ensure_apt_updated` prevents redundant `apt update` calls by tracking whether the package lists have been refreshed recently. This is critical for performance when multiple modules (repos, firmware, GPU, kernel) each need to verify repository state.
4. **State refresh flag**: `STATE_REFRESHED=true` is set before `;;` in every `case` branch of the main menu loop, ensuring that each menu entry starts with a clean, consistent state rather than stale cached data.

By populating global variables such as `DEBIAN_VERSION`, `GPU_TYPE`, `CPU_SUMMARY`, and network interface states, it ensures that the subsequent menu options have access to accurate context. This prevents the user from making blind decisions—for example, attempting to install proprietary drivers on a system without detected hardware or selecting repositories incompatible with the current Debian codename. It transforms raw kernel data into actionable configuration parameters.

### 2. System Commands Used (Technical Mapping)

The following table details the native Linux tools and file descriptors utilized by `utils.sh` to extract specific diagnostic data points. This mapping demonstrates reliance on standard, non-intrusive system utilities rather than proprietary binaries.

| Feature | Command / Tool | Technical Purpose & Logic |
| :--- | :--- | :--- |
| **OS Version** | `lsb_release -cs`, `/etc/os-release` | Parses `VERSION_CODENAME` to determine Debian release (Bullseye, Bookworm, Trixie). Critical for selecting correct repository backports. |
| **CPU Info** | `/proc/cpuinfo` | Reads `model name` and counts cores/threads. Provides cosmetic summary without needing heavy tools like `lscpu`. |
| **Memory** | `/proc/meminfo` | Extracts `MemTotal` to calculate RAM in GB. Used for compatibility warnings with specific software packages. |
| **GPU Detection** | `command -v lspci` guard → cached `LSPCI_OUTPUT` | `lspci -nn` output is cached in the global variable `LSPCI_OUTPUT` at startup. All subsequent GPU detection (PCI/USB buses, Ethernet, network) reads from this cache instead of re-running `lspci`. Identifies VGA/3D controllers via PCI IDs (`10de` for NVIDIA). Checks driver versions via `dpkg` if `nvidia-smi` fails. |
| **Network (Eth)** | `ip -o link show` | Enumerates Ethernet interfaces, state (UP/DOWN), and IP addresses using the `iproute2` suite. |
| **Network (Wi-Fi)** | `iwgetid`, `lspci` | Identifies wireless chipsets via PCI and retrieves SSID/Connection status for network diagnostics. |
| **Storage** | `lsblk -d -o NAME,SIZE,ROTA` | Distinguishes between NVMe (`nvme`), SSD (RoT=0), and HDD (RoT=1) to provide storage topology summary. |
| **Display Server** | Environment Vars (`XDG_SESSION_TYPE`) | Checks `WAYLAND_DISPLAY` vs `DISPLAY` variables to determine if the system is running Wayland, X11, or TTY. |

### 3. Strategic Importance for the Script

This diagnostic phase is vital for engineering stability and user experience (UX) integrity within the script architecture:

* **Context-Aware Configuration:** The detection of `HAS_NVIDIA`, `HAS_AMD`, or `HAS_INTEL` directly dictates which sub-modules are loaded in `debianito.sh`. If no GPU is detected, graphics driver menus are skipped. This prevents "false positive" installation prompts that confuse the user.
* **Repository Compatibility Guardrails:** The `detect_debian_version` function validates the OS against supported codenames (11, 12, 13). It specifically triggers Bullseye-specific logic (`configure_repos_bullseye`) only when necessary, preventing repository errors on newer or older distributions.
* **APT Update Deduplication:** The `_ensure_apt_updated` helper tracks whether `apt update` has been run recently. Multiple modules (repos, firmware, GPU, kernel) share a single update cycle, preventing redundant network calls and inconsistent package state between modules.
* **State Refresh Consistency:** `STATE_REFRESHED=true` is set before `;;` in every `case` branch of the main menu loop, ensuring each menu entry starts with a clean state and preventing stale variable propagation between sequential selections.
* **Time Synchronization Safety:** The `check_system_time` function prevents package installation failures caused by clock skew (which breaks GPG signatures in APT). By offering an automated NTP sync before proceeding, it ensures the integrity of the entire software supply chain within the script.
* **Root/Sudo Enforcement:** Early execution of `check_root` and `check_sudo` enforces security best practices. It prevents accidental privilege escalation or silent failures that often occur when scripts run with incorrect permissions.

### 4. Formatting and UX in the Terminal

The raw data collected by these functions is processed into a human-readable format before being passed to the TUI (Text User Interface) via `whiptail`.

* **Structured String Assembly:** Functions like `_show_sysinfo` build multi-line strings (`msg+="...")`, appending newlines and conditional logic. This ensures that if multiple GPUs are found, they are listed sequentially with drivers identified below each entry.
* **Visual Hierarchy:** The data is organized into logical blocks (OS, Hardware, GPU, Network) with clear separators (`───`). This allows the user to quickly scan specific subsystems without scrolling through a monolithic log.
* **Conditional Rendering:** The script checks for command availability (e.g., `if ! command -v lspci &>/dev/null` guards GPU detection, `if ! command -v ip &>/dev/null` guards network data). If tools are missing, it gracefully degrades to a warning message rather than crashing the TUI. When `lspci` is present, its output is cached in `LSPCI_OUTPUT` for all subsequent detection calls.
* **TUI Integration:** The final formatted string is passed to `_msg`, which wraps the output in a `whiptail --msgbox`. This ensures the diagnostic information appears as a modal dialog with consistent dimensions and styling (colors defined globally in `debianito.sh`), maintaining a professional look regardless of the underlying terminal emulator.
