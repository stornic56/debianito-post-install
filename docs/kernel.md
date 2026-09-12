# Option 7: Kernel Variants (Stable, Backports, RT, Cloud)

## 1. What Does This Component Do?

The **Kernel** module (`modules/kernel.sh`) manages which Linux kernel your system boots. Unlike a simple `apt install`, it enforces **atomic installation of image + headers** and validates repository state before touching the boot chain. The menu (`show_kernel_menu`) offers four distinct kernel flavours plus a Backports path that is only available on Debian 13 (Trixie):

| Key | Variant | Package | Use Case |
| ----- | --------- | --------- | ---------- |
| `stable` | Stable | `linux-image-amd64` | Default Debian kernel (6.12 LTS on Trixie). Maximum stability. |
| `backports` | Backports | `linux-image-amd64` from `trixie-backports` | Newer kernel (e.g., 7.x) for recent hardware. **Trixie only**, requires backports enabled. |
| `rt` | Real-Time | `linux-image-rt-amd64` | Preempt-RT kernel for low-latency / audio production. Warns on NVIDIA. |
| `cloud` | Cloud | `linux-image-cloud-amd64` | Minimal kernel for VMs, containers, and cloud images. |

All variants install the matching **headers** package (`linux-headers-amd64`, `linux-headers-rt-amd64`, `linux-headers-cloud-amd64`) in the same transaction — critical for DKMS modules (NVIDIA, VirtualBox, ZFS).

> **Position in menu:** This is Option 7 in the current `debianito.sh` main menu. Previous documentation listed it as Option 6 (Backports only). The module was expanded to support RT and Cloud kernels after the initial release.

---

## 2. Why Offer Backports at All?

Debian Stable freezes its kernel at an LTS release (6.12 LTS on Trixie). This is intentional for reliability, but creates a hardware enablement gap for machines released in 2025-2026:

- **New CPUs** (Intel Arrow Lake / Panther Lake, AMD Zen 5) need scheduler hints, CXL, and microcode not in 6.12
- **New GPUs** (Intel Battlemage D3cold, NVIDIA Blackwell) need power-state and firmware support added after 6.12
- **Filesystem fixes** (XFS self-healing, Btrfs remap-tree) land only in newer kernels

The `trixie-backports` repository provides a **best-effort newer kernel** without moving the rest of the system to Testing. Debian backports kernels receive security updates but are not LTS themselves.

This is why the menu shows `backports` only when `DEBIAN_VERSION == 13` and greys it out otherwise. Bookworm backports is intentionally not offered — its EOL was 2026-08-09 and the NVIDIA path on Bookworm no longer uses backports.

---

## 3. The Installation Pipeline: Image + Headers Atomically

### Function: `_install_kernel_package` (`kernel.sh`)

```bash
_install_kernel_package "linux-image-amd64" "Backports" "-t trixie-backports"
_install_kernel_package "linux-image-rt-amd64" "RT" ""
```

Execution steps:

1. **Availability check** — `apt-cache show <pkg>` must succeed. If the package does not exist for the current Debian version, a whiptail message `Kernel not available` is shown and the function returns.
2. **Hardware warnings** (flavour-specific):
   - **Backports + NVIDIA** (`GPU_TYPE == "nvidia"`): `_confirm "Kernel" "WARNING: Backports kernel changes the kernel version. Your NVIDIA driver will need recompilation (DKMS)."`. Users can still proceed — DKMS will rebuild on next boot if headers match.
   - **RT + NVIDIA**: `_msg "Kernel — RT" "Ensure your NVIDIA driver supports the RT kernel. Some proprietary drivers may not work correctly."`. Not a blocker, but informs that some closed drivers fail with PREEMPT_RT.
3. **Version resolution** for the confirmation dialog:

   ```bash
   # Backports path
   ver=$(apt-cache madison linux-image-amd64 | grep trixie-backports | awk '{print $3}' | head -1)
   headers_ver=$(apt-cache madison linux-headers-amd64 | grep trixie-backports | awk '{print $3}' | head -1)
   # Stable/RT/Cloud path
   ver=$(apt-cache show linux-image-amd64 | sed -n 's/^Version: //p' | grep -v '~bpo' | head -1)
   ```

   The dialog shows `Image: linux-image-amd64 (6.12.22-1)` + `Headers: linux-headers-amd64 (6.12.22-1)` + `From: Trixie-backports` when a backports flag is present.
4. **User confirmation** — `whiptail --yesno "Install Backports kernel? Image: ... Headers: ..."` with the version string. Declining aborts with `Skipping.`.
5. **Atomic install**:

   ```bash
   sudo apt install -y [-t trixie-backports] linux-image-amd64 linux-headers-amd64
   sudo apt install -y linux-image-rt-amd64 linux-headers-rt-amd64
   sudo apt install -y linux-image-cloud-amd64 linux-headers-cloud-amd64
   ```

   Both image and headers are passed in a **single `apt` transaction**. This guarantees the symbol tables match and DKMS can rebuild. The helper `_run_cmd "Kernel"` prints the command, captures the exit code, and pauses for the user to review output.
6. **Post-install** — prints `Backports kernel installed. Reboot to use it.` and pauses. The new kernel is added to `/boot` alongside the old one; GRUB will show both at next boot. The script does not remove the old kernel — rollback is simply rebooting into the previous entry.

---

## 4. Menu Logic: `show_kernel_menu`

```bash
show_kernel_menu() {
  while true; do
    items=("stable" "Install linux-image-amd64")
    [ "$DEBIAN_VERSION" = "13" ] && items+=("backports" "Install from backports")
    items+=("rt" "Install linux-image-rt-amd64 (Preempt-RT)")
    items+=("cloud" "Install linux-image-cloud-amd64")
    items+=("back" "Return to main menu")
    choice=$(whiptail --menu "Kernel Installation" "Select kernel variant:" 16 65 5 "${items[@]}")

    case "$choice" in
      stable)    _install_kernel_package "linux-image-amd64" "Stable" "" ;;
      backports)
        if [ "$(is_backports_enabled)" != "true" ]; then
          whiptail --msgbox "Backports repository is not enabled.\nUse option 4 (Configure repositories) to enable backports before installing."
        else
          _install_kernel_package "linux-image-amd64" "Backports" "-t ${DEBIAN_CODENAME}-backports"
        fi ;;
      rt)        _install_kernel_package "linux-image-rt-amd64" "RT" "" ;;
      cloud)     _install_kernel_package "linux-image-cloud-amd64" "Cloud" "" ;;
      back) break ;;
    esac
  done
}
```

Key details:

- **Backports visibility** — The `backports` entry is only appended when `DEBIAN_VERSION == 13`. On Bullseye/Bookworm it does not appear.
- **Backports guard** — Selecting `backports` without backports enabled shows a message pointing to **Option 4 (Configure Repositories)**. No install is attempted.
- **Loop** — The menu is a `while true` loop; the user can install multiple variants sequentially (e.g., Stable + RT) before returning with `back` or `ESC`.

---

## 5. Safety Mechanisms

| Mechanism | How It Works |
| ----------- | -------------- |
| **Pre-flight `is_backports_enabled`** | `utils.sh:is_backports_enabled` greps `/etc/apt/sources.list` and `/etc/apt/sources.list.d/*.sources` / `*.list` for `trixie-backports`. Prevents `apt -t` from failing with `E: Release not found`. |
| **NVIDIA RT warning** | `utils.sh:GPU_TYPE` is set at startup by `detect_gpu` (lspci). RT kernels change scheduling semantics; some `nvidia.ko` builds reject `PREEMPT_RT`. |
| **Atomic image+headers** | Both packages in one `apt` call. If headers are missing, `dkms` will fail at boot — so they are never installed separately. |
| **Fallback preservation** | `apt` never removes the running kernel. `/boot` retains `vmlinuz-*` and `initrd.img-*` for both. GRUB keeps both entries; if the new kernel panics, select the old one. |
| **Version-aware messaging** | The confirmation dialog always shows the exact version string (`apt-cache madison` / `apt-cache show`) so users know they are not reinstalling the same package. |

GRUB update is **not** explicitly called — `linux-image-*` postinst triggers `update-grub` (or `kernel-install` on systemd-boot) automatically. If GRUB is broken, use **Option 12 (Boot Rescue + GRUB)** to rebuild it.

---

## 6. Interconnection with Other Modules

- **Option 4: Repositories** — Must enable `trixie-backports` before `Kernel → backports` is usable. The kernel menu explicitly checks `is_backports_enabled` and directs the user there if missing.
- **Option 5: Firmware** — Newer kernels expose new hardware IDs (e.g., `8086:7e40` for Panther Lake). Without updated `firmware-linux-nonfree` or `firmware-iwlwifi`, the new kernel will show the device but fail to load firmware. Run Firmware after a kernel upgrade if WiFi/storage is not recognized.
- **Option 6: Graphics Drivers** — NVIDIA `dkms` needs the exact `linux-headers-*` version. The atomic install ensures headers match. On Bookworm the NVIDIA path deliberately avoids backports kernels; on Trixie a backports kernel + Maxwell/Pascal GPU is forced to the stable NVIDIA driver (`v550`) to avoid `v590` incompatibility.
- **Gaming (`gaming.sh`)** — The backports kernel is sometimes recommended for gaming (scheduler latency, `SCHED_EXT`), but not required. Benchmarks show <3% difference for most titles; enable it only for newer hardware that needs it.

---

## 7. Verification After Installation

```bash
uname -r                      # Should show the new kernel after reboot
dpkg -l linux-image-amd64 | grep ^ii
dpkg -l linux-headers-amd64 | grep ^ii
ls -l /boot/vmlinuz-*         # Both old and new kernels present
grep -E 'menuentry' /boot/grub/grub.cfg | head -5  # GRUB entries
```

If the new kernel fails to boot, hold `ESC` (or `Shift` on BIOS) at power-on, select **Advanced options for Debian** → previous kernel version.

---

## References

- [Debian Backports — backports.debian.org](https://backports.debian.org/)
- [Debian Kernel Handbook](https://kernel-handbook.alioth.debian.org/)
- [PREEMPT_RT — wiki.debian.org/RealTime](https://wiki.debian.org/RealTime)
- [Installing a new kernel — wiki.debian.org/DebianKernel](https://wiki.debian.org/DebianKernel)
