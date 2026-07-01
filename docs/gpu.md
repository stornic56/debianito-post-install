## Option 5: Graphics Drivers, Mesa Stack & Display Architecture

### 1. Philosophy of the Graphics Stack (Open-Source vs. Proprietary)

The `debianito` script adopts a **hybrid-first architecture philosophy**. It prioritizes the stability and security of the Linux kernel's native open-source drivers while maintaining the capability to inject proprietary solutions where necessary for performance or legacy support. This approach is implemented through three distinct layers:

1.  **DRM/KMS & Mesa (Open-Source Core)**: For Intel and AMD hardware, the script relies on the `i915`/`amdgpu` kernel drivers (KMS) paired with the `Mesa` user-space stack. This ensures that graphics acceleration is handled by the mainline Linux kernel without requiring third-party blobs or external repositories for basic functionality. The script explicitly installs the necessary Gallium3D drivers (`radeonsi`, `iris`) and Vulkan implementations (`RADV`).
2.  **Proprietary Injection (NVIDIA)**: For NVIDIA hardware, the open-source Nouveau driver is often insufficient for gaming or compute workloads. The script manages the installation of proprietary `.run` or DKMS modules via official NVIDIA repositories. This requires careful handling to ensure compatibility with the running kernel version, especially when using backports kernels.
3.  **Firmware & Microcode**: A critical prerequisite layer handled by `firmware.sh`. Before any driver can load, the correct firmware blobs (e.g., `iwlwifi`, `amdgpu`, `nvidia`) must be present in `/lib/firmware`. The script scans hardware via `lspci` and `lsusb` to populate a dynamic installation plan for these non-free components.

This philosophy ensures that users on standard Debian Stable releases get maximum compatibility, while advanced users can opt into backports kernels or enterprise NVIDIA repositories without breaking the base system integrity.

---

### 2. The Automatic GPU Detection Pipeline

The script utilizes a robust pre-flight detection sequence defined in `utils.sh` and executed within `gpu.sh`. This pipeline minimizes user interaction by automatically categorizing hardware before presenting installation options.

**Detection Flow:**
1.  **Hardware Scanning**: The function `detect_gpu()` executes `lspci -nn | grep -E "VGA|3D"`. It parses the output using `sed` and `grep` to identify vendor IDs (e.g., `8086` for Intel, `10de` for NVIDIA).
2.  **Variable State**: Global variables are populated immediately:
    *   `GPU_TYPE`: Set to `"intel"`, `"amd"`, or `"nvidia"`. If no GPU is found, it defaults to `"unknown"` (common in VMs or headless servers).
    *   `INTEL_GPU_DEVICE_ID` / `NVIDIA_GPU_DEVICE_ID`: Hexadecimal device IDs extracted for precise generation matching.
3.  **Logic Branching**: Inside `install_gpu_drivers()`, the script checks these variables:
    ```bash
    if [ "$GPU_TYPE" = "unknown" ]; then
        # Install generic Mesa stack (Safe fallback)
        install_mesa_generic_stack
    elif $HAS_INTEL; then
        # Route to Intel-specific logic (i915/Xe, VAAPI selection)
        install_intel_firmware && offer_intel_tools
    elif $HAS_AMD; then
        # Route to AMD-specific logic (amdgpu/radeonsi)
        install_amd_firmware && offer_amd_tools
    ```
4.  **Hybrid Support**: For laptops with hybrid graphics (e.g., Intel iGPU + NVIDIA dGPU), the script detects both `HAS_INTEL=true` and `HAS_NVIDIA=true`. It executes a sequential plan:
    *   Install Intel firmware/drivers first to ensure the base display server works.
    *   Install NVIDIA drivers second, configuring them for PRIME offloading if detected.

This "detect-then-deploy" model prevents users from installing unnecessary drivers (e.g., `i965` on an RTX 4090) and ensures that critical firmware is present before the driver installation phase begins.

---

### 3. **Intel Graphics Hardware**

| Architecture / Gen | Process Node | iGPU / dGPU | Kernel Driver (KMD) | OpenGL Driver | Vulkan Driver | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Gen4** (Broadwater) | 65nm | GMA X4500, GMA X4500HD | `i915` | `i915` | Not supported | Predecessor to HD Graphics. Very limited support. The i915 DRI driver is the original, now obsolete. |
| **Gen5** (Ironlake) | 32nm | HD Graphics (Westmere/Arrandale) | `i915` | `crocus` | Not supported | First generation "HD Graphics". OpenGL up to 3.3 only. Legacy driver `i965` was **removed** in Mesa 24.1, so `crocus` is now the only option. |
| **Gen6** (Sandy Bridge) | 32nm | HD Graphics 2000/3000 | `i915` | `crocus` | Not supported | Significant performance improvement. Maximum OpenGL 3.3. |
| **Gen7** (Ivy Bridge) | 22nm | HD Graphics 2500/4000 | `i915` | `crocus` | `ANV/HASVK` [(incomplete/broken)](https://www.reddit.com/r/vulkan/s/Hnf5zU8WZY) | First Gen at 22nm. `crocus` is the recommended OpenGL driver. Vulkan is exposed but completely non-conformant (0.0.0.0 ), lacks basic features (e.g., texture swizzle), and is [unusable for real-world tasks](https://www.phoronix.com/news/Intel-HasVK-Drop-Dead-Code).|
| **Gen7** (Bay Trail) | 22nm | HD Graphics (Bay Trail) | `i915` | `crocus` | `ANV`[(incomplete)](https://lists.debian.org/debian-user/2023/07/msg00550.html) | `conformanceVersion = 0.0.0.0` Support is experimental up to Vulkan 1.2, lacks basic extensions, and may cause instability. The separate HASVK driver exists but is not used on this system. |
| **Gen7.5** (Haswell) | 22nm | HD Graphics 4600, Iris Pro 5200 | `i915` | `crocus` | `hasvk` |  Vulkan support via community driver `hasvk` (Vulkan 1.3). |
| **Gen8** (Broadwell) | 14nm | HD Graphics 5300, Iris Pro 6200, Iris 6100 | `i915` | `iris/crocus` | `hasvk` | First generation at 14nm, `iris` becomes the main OpenGL driver. |
| **Gen9** (Skylake) | 14nm | HD Graphics 530, Iris 540/550 | `i915` | `iris` | `anv` | Mature architecture with strong Linux support. Major performance boost for iGPU. |
| **Gen9.5** (Kaby Lake, Coffee Lake, Comet Lake) | 14nm+ / 14nm++ | UHD Graphics 620/630, UHD 610/630 | `i915` | `iris` | `anv` | Process node optimization for 14nm. "UHD" replaces "HD" in naming convention. |
| **Gen11** (Ice Lake) | 10nm | UHD Graphics G1, Iris Plus G4/G7 | `i915` | `iris` | `anv` | First architecture at 10nm. Vulkan 1.3+ support. |
| **Gen12** (Xe-LP) (Tiger Lake, Alder Lake, Raptor Lake) | Intel 7 (10nm ESF) | Iris Xe G7, UHD Graphics 770/730 | `i915/xe` | `iris` | `anv` | Renamed to "Iris Xe". Vulkan 1.3 support. The xe module has technical support but i915 remains the standard and more stable for this generation. |
| **Xe-LPG** (Meteor Lake) | TSMC N5 | Arc Graphics (8 Xe-Cores) | `i915/xe` | `iris` | `anv` | First tile-based architecture iGPU. |
| **Xe2-LPG** (Lunar Lake) | TSMC N3B | Arc Graphics (Xe2-LPG - 8 Xe-Cores) | `i915?/xe` | `iris` | `anv` | First iGPU with Xe2 architecture (Battlemage). |
| **Xe3-LPG** (Panther Lake) | Intel 18A | Arc Graphics (Xe3 iGPU) | `i915?/xe` | `iris` | `anv` | High-power iGPU. Requires Kernel 6.19 and Mesa 26 as base. |
| **Xe-HPG** (Alchemist) | TSMC N6 | **Arc A380, A580, A750, A770** (dGPU) | `i915/xe` | `iris` | `anv` | First modern dGPU (Arc). Support since Kernel 6 and Mesa 22. |
| **Xe2-HPG** (Battlemage) | TSMC N5 | **Arc B570, B580** (dGPU) | [`i915/xe`](https://www.phoronix.com/review/intel-xe-i915-linux-619) | `iris` | `anv` | Second generation dGPU. Very solid day-one Linux support since Kernel 6.12 and Mesa 24.2 |

---

#### Intel Details: 

1.  **Kernel Driver Transition (`i915` to `xe`)**: The [`i915`](https://www.kernel.org/doc/html/v4.9/gpu/i915.html) driver is reaching its scalability limits. [Xe](https://www.kernel.org/doc/html/v6.8/gpu/rfc/xe.html) is the path for modern hardware, though it still requires forcing and is under development, it already shows significant improvements in various areas.
2.  **Mesa Drivers (User Space)**:
    *   **OpenGL**:
        *   **Legacy Hardware (Gen5-Gen8)**: The classic `i965` driver was **officially removed from Mesa in version 24.1**. **[`crocus`](https://www.phoronix.com/news/Intel-Crocus-Default-Gallium3D)** (Gallium3D) is the only active driver for this legacy hardware.
        *   **Modern Hardware (Gen9 and Xe)**: **`iris`** is the standard driver. It works excellently on both iGPUs and Arc dGPUs (Alchemist/Battlemage).
    *   **Vulkan**: 
        *   **Old Hardware about Ivy Bridge and Bay Trail (Gen7)**: Although the ANV/HASVK drivers expose these GPUs as Vulkan devices (reporting API versions as high as 1.2 or 1.3), their state is completely non-compliant (conformanceVersion = 0.0.0.0). The support is purely theoretical, it lacks basic hardware features (e.g., texture swizzle on Ivy Bridge) and is unstable or unusable for real-world applications. Because of this, in Mesa 22.3, the Gen7/Gen8 Vulkan code was separated from the main driver (ANV) and moved to the legacy HASVK driver to avoid hindering the development of modern hardware. You can read the technical details of this decision [here](https://www.phoronix.com/news/Intel-HASVK-Old-Vulkan-Gen7-8).
        *   **Legacy Hardware (Gen7.5 - Gen8)**: Uses **[`hasvk`](https://www.phoronix.com/news/Intel-ANV-HASVK-Split-Merged)**, a community-maintained driver (not directly by Intel engineers), offering Vulkan 1.2? on 2013-era hardware.
        *Additionally, in early 2024, the compiler code shared between `iris` and `anv` for [Gen8](https://www.phoronix.com/news/Intel-Mesa-Splitting-Gen8) was also isolated, following the same principle: to enable faster development for modern hardware without breaking Broadwell support*.
        *   **Modern Hardware (Gen9+)**: **[`anv`](https://docs.mesa3d.org/drivers/anv.html)** is Intel's official driver. On recent hardware (Gen12+, Arc) it reaches the **Vulkan 1.4 standard**.
3.  **New Hardware Support Status**: Support for very recent iGPUs (such as Lunar Lake and Panther Lake) often requires very recent versions of the Linux kernel (6.8/6.11 branch or higher) and Mesa library (24.2+), plus updated firmware (`linux-firmware`).

---

### 4. AMD Radeon Architecture Reference

AMD's open-source support is divided by architecture families, each mapped to a specific Gallium3D driver within Mesa.

| Architecture | Representative GPU Families | Kernel Driver (KMD) | OpenGL Driver (Mesa) | Vulkan Driver (Mesa) | Technical Notes & Particularities |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TeraScale 1**<br>*(R600/R700)* | Radeon HD 2000, HD 3000, HD 4000 | `radeon` | `r600` | **Not Applicable** | Starting point of the `r600` driver in Mesa. Supports up to OpenGL 3.3. Architecture is completely obsolete, only useful for very basic 2D/3D desktop graphics. |
| **TeraScale 2**<br>*(Evergreen)* | Radeon HD 5000, HD 6000<br>*(and some low-end HD 7000)* | `radeon` | `r600` | **Not Applicable** | Last evolution of TeraScale. OpenGL support stalled at version 3.3. **No Vulkan support exists or will exist** due to hardware architecture limitations. |
| **TeraScale 3**<br>*(Northern Islands)* | Radeon HD 6000, HD 7000 (low-end) | `radeon` | `r600` | **Not Applicable** | Intermediate architecture between TeraScale 2 and GCN. OpenGL support remains at 3.3. **No Vulkan support**. Last generation before the jump to GCN. |
| **GCN 1.0 / 1.1**<br>*(gfx6 / gfx7)* | Radeon HD 7700, R7 200, R9 200/300 | `radeon` (default)<br>`amdgpu` (forced) | `radeonsi` | `RADV` (Vulkan 1.3) | **⚠️ Requires manual configuration:** The kernel loads `radeon` by default. To use `radeonsi`/`RADV`, pass to the kernel: `amdgpu.si_support=1 amdgpu.cik_support=1 radeon.si_support=0 radeon.cik_support=0`. |
| **GCN 3.0**<br>*(gfx8 / gfx8.1)* | Radeon R9 285, R9 Fury X, R9 Nano | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Third generation of GCN, direct predecessor to Polaris. Introduces efficiency improvements and initial support for Vulkan 1.3. |
| **GCN 4.0**<br>*(Polaris, gfx8.0)* | Radeon RX 400, RX 500, Radeon Pro WX | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | First generation to use the `amdgpu` KMD natively and by default without tricks. Sweet spot for stability of older hardware in current Linux. No Ray Tracing hardware support. |
| **GCN 5.0**<br>*(Vega, gfx9)* | Radeon RX Vega, Radeon VII, APUs Raven Ridge | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Last GCN generation. Significant improvements to the `radeonsi` driver for this hardware. On Vega, using "Override" in RADV sometimes improves performance over default shader cache. |
| **RDNA 1**<br>*(gfx10)* | Radeon RX 5000 | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Architectural jump. Introduces Variable Rate Shading (VRS) support. Mesa drivers quickly achieved performance parity with the proprietary Windows driver on this generation. |
| **RDNA 2**<br>*(gfx10.3)* | Radeon RX 6000, Steam Deck (Van Gogh) | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | First generation with hardware **Ray Tracing** in AMD. In Mesa, this is handled through the `VK_KHR_ray_tracing_pipeline` extension. This architecture is in the Steam Deck, which massively accelerated RADV development. |
| **RDNA 3**<br>*(gfx11)* | Radeon RX 7000 | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Introduces **Mesh Shaders** in AMD hardware ([`VK_EXT_mesh_shader`](https://github.com/KhronosGroup/Vulkan-Docs/blob/main/proposals/VK_EXT_mesh_shader.adoc) extension). Requires a relatively recent Linux kernel (6.1+) for complete and stable graphics controller support. |
| **RDNA 3.5**<br>*(gfx11.5)* | APUs Strix Point/Halo, Krackan Point, Gorgon Halo| `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Intermediate update to RDNA 3. Shares many features with RDNA 3 (gfx11). Support in drivers (kernel, Mesa, LLVM) is integrated as part of the GFX11 family. |
| **RDNA 4**<br>*(gfx12)* | Radeon RX 9000 | `amdgpu` | `radeonsi` | `RADV` (Vulkan 1.4) | Latest generation to date. RADV jumps to full support for **Vulkan 1.4** across the entire GFX8+ line (GCN 3 onwards). **Current context:** AMD has officially discontinued their other open Vulkan driver (AMDVLK), leaving 

#### Additional notes & carifications

1.  **Regarding GCN Nomenclature**: Names like "GCN 1.0", "1.1", "1.2" were created by the press as a convenient abbreviation, since AMD only started officially numbering their GCN revisions (gen 1 to 4) later. The table now uses more standard terminology.
2.  **Relationship Between Drivers and Architectures**:
    *   The `radeonsi` driver (OpenGL) and `RADV` (Vulkan) are siblings within the Mesa 3D project. Both depend on the [`amdgpu` kernel](https://docs.kernel.org/gpu/amdgpu/index.html).
    *   The old [`radeon`](https://wiki.freedesktop.org/xorg/radeon/) driver (for TeraScale) is incompatible with modern Mesa drivers (`radeonsi`/`RADV`).
    *   **Important milestone**: Starting from Linux kernel 6.19, the `amdgpu` driver will include support for older generations of [AMD GPUs](https://wiki.gentoo.org/wiki/AMDGPU) (such as TeraScale and early GCN) that were previously only supported by the `radeon` driver, unifying support.
3.  **Vulkan Support in RADV**: Mesa documentation indicates that [RADV supports Vulkan 1.4 for all GFX8 GPUs (GCN 3 onwards) and newer](https://docs.mesa3d.org/drivers/radv.html#supported-hardware). This includes RDNA 3 and RDNA 3.5 architectures, not just RDNA 4. 
4.  **RDNA 3.5 Status**: It is an intermediate update that shares the architectural base of RDNA 3 (gfx11). The identifiers `gfx1150` and `gfx1151` correspond to this generation. Support in Mesa drivers and the kernel has been integrated progressively.

---

### 5. **NVIDIA Hardware & Driver Support**

#### Nvidia Legacy (Fermi to Pascal):
These generations depend **exclusively** on the proprietary driver and closed stack. There is no support for the open kernel module nor NVK.

| Architecture | Last Driver with Support | Kernel Module (KMD) | Proprietary Vulkan Support | NVK (Mesa) Support | Max CUDA Version | Notes and Particularities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Fermi**<br>*(GF100/110)* | **390.xx** (Legacy) | `nvidia` (Closed) | **Vulkan 1.0** | No | **CUDA 8.0** | Last driver to support this architecture. Has not received security fixes for years. Only viable for completely offline systems. |
| **Kepler**<br>*(GK100/110)* | **470.xx** (Legacy) | `nvidia` (Closed) | **Vulkan 1.2** | No | **CUDA 11.8** | Last generation to receive "Legacy" status. Good compatibility with OpenGL 4.6, but Vulkan support stalled at 1.2. |
| **Maxwell**<br>*(GM100/200)* | **580.xx** (Old Standard) | `nvidia` (Closed) | **Vulkan 1.3** | No | **CUDA 12.0** | Removed from official support in driver 580 (CUDA 12.1). |
| **Pascal**<br>*(GP100/102/104)* | **580.xx** (Old Standard) | `nvidia` (Closed) | **Vulkan 1.3** | No | **CUDA 12.0** | Shares same fate as Maxwell. Still very popular (GTX 1060/1080), but requires blocking packages (e.g., in Debian) to prevent updates that break graphics support. |

---

#### Nvidia: modern era and """Open Source""" (Turing to Blackwell):
Starting with Turing, NVIDIA introduced the **open kernel module**. From driver 525, this module is the default. Additionally, it's the range where community driver **NVK** (in Mesa) shines.

| Architecture | Compatible Active Drivers | Kernel Module (KMD) | Proprietary Vulkan Support | NVK (Mesa) Support | Max CUDA Version | Notes and Particularities |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Turing**<br>*(TU100/102/116)* | 525.xx to 610+ | `nvidia` (**Open Module**) | **Vulkan 1.3** | **Yes** (Vulkan 1.3) | **CUDA 12.8+** | First generation to use Open Kernel Module (introduced in 515, default in 525). *Note:* Security processor firmware (GSP) remains a closed blob. Excellent NVK support. |
| **Ampere**<br>*(GA100/102/104/107)* | 525.xx to 610+ | `nvidia` (**Open Module**) | **Vulkan 1.3** | **Yes** (Vulkan 1.3) | **CUDA 12.8+** | Mature support in both proprietary driver and NVK. For RTX 3060/3080/3090, NVK offers extremely competitive performance versus proprietary in many scenarios. |
| **Ada Lovelace**<br>*(AD100/102/103/104)* | 525.xx to 610+ | `nvidia` (**Open Module**) | **Vulkan 1.3** | **Yes** (Vulkan 1.3) | **CUDA 12.8+** | NVK added full Ada support recently. Proprietary driver still required if hardware Ray Tracing or DLSS 3 (Frame Generation) is needed, as NVK does not yet implement these proprietary extensions. |
| **Blackwell**<br>*(GB100/102/202)* | [570.xx](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-570-211-01/index.html) to 610+ | `nvidia` (**Open Module**) | **Vulkan 1.3** | **Yes** (In development) | **CUDA 12.8+** | Latest generation architecture (RTX 5090/5080). NVK support is landing in the most recent kernel versions (6.12+) and Mesa (24.3+). Requires very updated `linux-firmware`. |

#### 💡 Quick context glossary for documentation:
*   **Open Module:** Starting with driver 515, [NVIDIA releases code that interacts directly with the Linux kernel under MIT/GPL license](https://developer.nvidia.com/blog/nvidia-releases-open-source-gpu-kernel-modules/). However, the GPU still requires loading a proprietary closed microcode called **GSP (GPU System Processor)** to boot.
*   **NVK:** It is the open-source Vulkan driver developed by Red Hat and the community, integrated into the [Mesa project](https://docs.mesa3d.org/drivers/nvk.html). It's the 100% free alternative to `libGLX_nvidia.so`. Does not require NVIDIA proprietary driver installed to function (only kernel firmware).
*   **CUDA Drop:** When NVIDIA removes an architecture from new drivers (e.g., Pascal in 555), the CUDA version used by that GPU freezes forever (in this case, CUDA 12.0). Cannot run applications compiled for CUDA 12.1 or higher.

---

### 6. **Mesa Stack Optimization (AMD & Intel)**

When the script detects Intel or AMD hardware, it triggers a specific installation sequence designed to maximize [API support](https://mesamatrix.net/) (OpenGL/Vulkan/VA-API).

**Core Components Installed:**
*   **`libgl1-mesa-dri`**: Provides the core OpenGL implementation for 64-bit systems. The script ensures `libgl1-mesa-dri:i386` is included if Wine or legacy applications are required, preventing architecture mismatches.
*   **`mesa-vulkan-drivers`**: Installs `RADV` (AMD) and `anv` (Intel). This enables Vulkan 1.2/1.3 support on modern hardware.
*   **`va-driver-all` / `vdpau-va-driver`**: Ensures video decoding acceleration is available for media players like VLC or MPV.

**Vendor-Specific Logic:**

| Vendor | Kernel Driver (KMD) | Mesa User-Space Driver | VAAPI Backend Strategy |
| :--- | :--- | :--- | :--- |
| **Intel Gen < 8** | `i915` | `crocus` / `iris` | Installs [`i965-va-driver-shaders`](https://github.com/intel/intel-vaapi-driver/). Legacy path for older CPUs. |
| **Intel Gen 8+** | `i915` | `iris` / `anv` | Installs [`intel-media-va-driver-non-free](https://github.com/intel/media-driver). Modern, preferred backend for Broadwell+. |
| **AMD GCN/RDNA** | `amdgpu` | `radeonsi` (GL) + `RADV` (VK) | Uses standard `va-driver-all`. Requires kernel param tuning for older GCN. |

**Critical Consistency Check:**
The script enforces the installation of 32-bit Mesa libraries (`libgl1-mesa-dri:i386`) alongside the 64-bit packages. This is a mandatory requirement for running Proton (Steam) and Wine applications, which often rely on 32-bit OpenGL contexts even when running on a 64-bit OS.

---

### 7.**NVIDIA Driver Management & Kernel Compatibility**

The NVIDIA driver installation process is inherently complex due to proprietary components, kernel version constraints, and DKMS (Dynamic Kernel Module Support) module compilation. This section outlines how the script navigates these challenges by distinguishing between stable and backports kernels, handling Blackwell architecture GPUs via CUDA v590, and providing appropriate warnings for potential compatibility issues.

#### **Kernel Compatibility**
- **Stable Kernels**: Use `linux-image-amd64`. Compatible with standard NVIDIA `.deb` packages (e.g., `nvidia-driver-535`) and DKMS modules.
- **Backports Kernels**: Detected via `is_backports_kernel()`. Newer kernels may cause DKMS compilation failures due to driver version lag. The script warns users or suggests using the NVIDIA enterprise repository or manual header compilation (`linux-headers-$(uname -r)`).

#### **Blackwell Architecture & CUDA v590**
- **Detection**: `_helpers.sh` function `is_nvidia_blackwell()` identifies GPUs via PCI IDs `10de:24xx`, `0x2900–0x29BF`, and `0x2B80–0x31FF`.
- **Reason for v590**: Debian 13 (Trixie) stable drivers only support up to v550, which lacks Blackwell (GB20x) architecture. The NVIDIA CUDA repository provides production branch v590 with unified driver packages. Specifically, the goal is to install the latest version of the nvidia-driver from the 590 branch, which would be [590.48.01](https://download.nvidia.com/XFree86/Linux-x86_64/590.48.01/README/supportedchips.html).
- **Extrepo Mechanism**: Enables `nvidia-cuda` repository via `extrepo`, creates APT pinning in `/etc/apt/preferences.d/block-nvidia` to lock to version `590.*`, and installs `nvidia-driver-pinning-590`, `nvidia-driver`, and `firmware-nvidia-gsp`.

#### **Installation Flow**
```bash
if [ "$HAS_NVIDIA" = true ]; then
    if [ "$(is_backports_kernel)" == "true" ] && \
       { [ "$DEBIAN_CODENAME" != "trixie" ] || ! is_nvidia_blackwell; }; then
        
        # Warn about DKMS compatibility or use enterprise repo
        offer_nvidia_enterprise_repo
    fi
    
    if _confirm "NVIDIA Driver"; then
        install_nvidia_driver  # Installs latest stable (535/550) or v590 for Blackwell
    fi
fi
```
---

### 8.**NVIDIA Driver Management & Kernel Compatibility**

Depending on your GPU generation and your Debian ecosystem, you must select the appropriate legacy or current driver series. The following table details the verified compatibility matrix across different Debian versions and hardware architectures:

| Driver NVIDIA | Debian Version | Supported Architectures (Generations) | Notes |
| :--- | :--- | :--- | :--- |
| **[390.157](https://us.download.nvidia.com/XFree86/Linux-x86_64/390.157/README/supportedchips.html)** | **Debian 11** (Bullseye) | Fermi, Kepler, Maxwell, Pascal, Volta | Last driver with Fermi support. Stable for legacy hardware. |
| **[470.256.02](https://us.download.nvidia.com/XFree86/Linux-x86_64/470.256.02/README/supportedchips.html)** | Debian 11 / **Bookworm** | Kepler, Maxwell, Pascal, Volta, Turing *(Limited Ampere)* | Last driver supporting Kepler (GeForce). Quadro K-series often use Maxwell chips here. |
| **[535.247.01](https://us.download.nvidia.com/XFree86/Linux-x86_64/535.247.01/README/supportedchips.html)** | **Debian 12** (Bookworm) | Maxwell to Ada Lovelace | Kepler support dropped completely. Standard for RTX 3000/4000 series. |
| **[550.163.01](https://us.download.nvidia.com/XFree86/Linux-x86_64/550.163.01/README/supportedchips.html)** | **Debian 13** (Trixie) | Maxwell to Ada Lovelace | Current stable standard. Blackwell not officially supported yet. |

#### **Critical Hardware Notes:**
*   **Kepler (GeForce vs. Quadro)**: The last driver supporting true Kepler architecture is version **470**. If a user has a GTX 680 or similar, they must stay on Debian 11 or use the 470 driver branch in Bookworm/Trixie manually.
*   **Fermi (GTX 400/500)**: Support ended with driver 390. These GPUs are incompatible with modern kernels and drivers beyond Debian 11.
*   **Volta (Titan V / V100)**: Excellent longevity, supported from 390 through 550+.
*   **Blackwell (RTX 5000)**: Not officially supported by standard Debian drivers yet. The script provides a path to the Enterprise Repo for users who need this hardware to function immediately.

#### **Kepler Interception in Bookworm:**
When Kepler is detected on Bookworm, `nvidia.sh` bypasses `nvidia-detect` (which might recommend v535) and forces installation of `nvidia-tesla-470-driver`:
```bash
if [ "$is_kepler" = "true" ] && [ "$DEBIAN_CODENAME" = "bookworm" ]; then
    nv_pkg="nvidia-tesla-470-driver"
    # Avoids black screen issues by forcing legacy 470 branch
fi
```

---

### 9. Performance Monitoring & Telemetry Tools

To ensure the graphics stack is functioning correctly, `gpu.sh` offers an optional installation of telemetry tools. These allow users to verify GPU utilization, memory usage, and codec support post-installation.

*   **Universal ([`nvtop`](https://github.com/Syllo/nvtop))**:
    *   A cross-platform tool that displays real-time metrics for NVIDIA, AMD, and Intel GPUs in a terminal interface (similar to `htop`).
    *   **Debian 11 Constraint**: In Debian 11 Bullseye, `nvtop` support is limited primarily to NVIDIA GPUs. The script warns users of this limitation on older releases.
*   **AMD Specific ([`radeontop`](https://github.com/clbr/radeontop))**:
    *   Provides detailed metrics for AMD GPUs (GPU usage, memory utilization, power consumption). Essential for verifying that the `amdgpu` driver is active and not falling back to software rendering.
*   **Intel Specific ([`intel-gpu-tools`](https://github.com/ChrisCummins/intel-gpu-tools))**:
    *   Only installed if the detected Intel hardware supports it (Gen 6+). Provides information on GPU usage via `inotify` or `/sys/class/drm`.
*   **Codec Verification ([`vainfo`](https://github.com/intel/libva-utils))**:
    *   The script runs `vainfo` to verify that VAAPI is correctly configured. This confirms whether the system can utilize hardware acceleration for video decoding (e.g., H.264, HEVC) via Intel QuickSync or AMD Video Core Plus.

**Installation Command Logic:**
```bash
if _confirm "Install Telemetry Tools"; then
    case "$GPU_TYPE" in
        nvidia) install_pkg nvtop ;;
        amd)    install_pkg radeontop ;;
        intel)  install_pkg intel-gpu-tools ;;
        *)      echo "Skipping telemetry for unknown GPU." ;;
    esac
fi
```

This modular approach ensures that users can verify their installation immediately after running `debianito`, providing confidence in the performance of their graphics stack.
