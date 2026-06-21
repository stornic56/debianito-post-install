# Installing New Cores in RetroArch on Debian

RetroArch installed via the official Debian repositories (`apt`) has a few key restrictions: the internal core downloader and updater are **disabled** by default, and cores are stored in system‑wide, read‑only directories. This guide explains two reliable ways to add new emulation cores (e.g., PPSSPP, Dolphin, MAME) to your Debian system, along with the necessary supporting files and configuration tweaks.

---

## Understanding RetroArch’s Directory Structure on Debian

When installed via `apt`, RetroArch uses these locations:

| **Component**               | **Default Path** (system‑wide)                          |
|-----------------------------|---------------------------------------------------------|
| Cores (`.so` files)         | `/usr/lib/x86_64-linux-gnu/libretro/`                   |
| Core info (`.info` files)   | `/usr/share/libretro/info/`                             |
| System/BIOS/Assets          | `~/.config/retroarch/system/` (user‑writable)           |
| Saves, States, Config       | `~/.config/retroarch/` (user‑writable)                  |

Because the core and info directories are owned by root, you cannot write to them without `sudo`.  
You have two options:

1. **Manual installation** – download cores and info files yourself and copy them with `sudo`.  
2. **Reconfigure RetroArch** to use user‑writable folders, then use the built‑in **Core Downloader**.

Both methods work; choose the one that suits you best.

---

## Method 1 – Manual Core Installation (Recommended for Reliability)

This method guarantees that you can add any core, even if the online updater is blocked.

### 1. Download and Install the Core (`.so`)

The core is a shared library. For 64‑bit Linux, get it from the official Libretro buildbot:

```bash
# Example: PPSSPP core
wget https://buildbot.libretro.com/nightly/linux/x86_64/latest/ppsspp_libretro.so.zip
unzip ppsspp_libretro.so.zip
sudo mv ppsspp_libretro.so /usr/lib/x86_64-linux-gnu/libretro/
rm ppsspp_libretro.so.zip
```

> **Replace `ppsspp` with any core name** – e.g., `mame_libretro`, `dolphin_libretro`, etc.  
> Browse all available cores at:  
> [https://buildbot.libretro.com/nightly/linux/x86_64/latest/](https://buildbot.libretro.com/nightly/linux/x86_64/latest/)

### 2. Download and Install the Core Info (`.info`)

RetroArch will not recognise the core without its corresponding `.info` file.

```bash
wget https://raw.githubusercontent.com/libretro/libretro-core-info/master/ppsspp_libretro.info
sudo mkdir -p /usr/share/libretro/info/
sudo mv ppsspp_libretro.info /usr/share/libretro/info/
```

> The `.info` files for all cores are maintained at:  
> [https://github.com/libretro/libretro-core-info](https://github.com/libretro/libretro-core-info)  
> You can also download directly: `https://raw.githubusercontent.com/libretro/libretro-core-info/master/<core_name>.info`

---

## Method 2 – Enable the Built‑in Core Downloader

If you prefer using RetroArch’s graphical interface to download cores, you can change the core directories to writable locations.

### Step 1 – Edit RetroArch Configuration

Create or edit `~/.config/retroarch/retroarch.cfg` and add these lines:

```
libretro_directory = "~/.config/retroarch/libretro/"
libretro_info_path = "~/.config/retroarch/libretro-info/"
menu_show_core_updater = "true"
```

Now create the directories:

```bash
mkdir -p ~/.config/retroarch/libretro
mkdir -p ~/.config/retroarch/libretro-info
```

### Step 2 – Update Core Info Files

- Launch RetroArch.
- Go to **Online Updater** → **Update Core Info Files**.
- Wait for the update to complete.

### Step 3 – Download Cores

- Go to **Online Updater** → **Core Downloader**.
- Select the core you want (e.g., PPSSPP).
- The core will be downloaded to your user directory and will appear in the core list.

> ⚠️ **Note:** Some cores may require additional system files (BIOS/assets). These are still placed in `~/.config/retroarch/system/` – you’ll need to obtain them separately (see below).

---

## Essential Configuration for Graphics

The default video driver (`gl`) often causes black screens or crashes with many cores (especially PPSSPP). **Change the driver** to `vulkan` (preferred) or `glcore`.

1. In RetroArch, go to **Settings** → **Drivers** → **Video**.
2. Select **vulkan** (or **glcore** if Vulkan is not available).
3. Return to the main menu, go to **Configuration File** → **Save Current Configuration**.
4. **Restart RetroArch** for the change to take effect.

> If you’re on older hardware, you may need to install Vulkan drivers:  
> `sudo apt install mesa-vulkan-drivers`

---

## Installing Additional System Files (Assets / BIOS)

Some emulators require extra files (fonts, sound banks, BIOS images) to work correctly. These always go into your **user** system directory:

```
~/.config/retroarch/system/
```

For **PPSSPP**, you need its asset bundle:

```bash
mkdir -p ~/.config/retroarch/system/PPSSPP
wget https://buildbot.libretro.com/assets/system/PPSSPP.zip
unzip PPSSPP.zip -d ~/.config/retroarch/system/
```

After extraction, you should see subfolders like `flash0/`, `lang/`, `themes/`, etc.

For other systems (e.g., **Dolphin**, **PCSX2**), check the official Libretro documentation for required BIOS files and place them in the appropriate subdirectory under `system/`.  
You can find many asset packs at:  
[https://buildbot.libretro.com/assets/system/](https://buildbot.libretro.com/assets/system/)

---

## ROM / Game File Formats

- **Supported formats** for PPSSPP: `.iso`, `.cso`, `.chd`, `.pbp`.
- **Always decompress your ROMs** – do not leave them in `.zip`, `.rar`, or `.7z` archives; the cores cannot read compressed archives directly.

---

## Useful References

| Resource | URL |
|----------|-----|
| Core builds (nightly, Linux x86_64) | [https://buildbot.libretro.com/nightly/linux/x86_64/latest/](https://buildbot.libretro.com/nightly/linux/x86_64/latest/) |
| Core info files (GitHub) | [https://github.com/libretro/libretro-core-info](https://github.com/libretro/libretro-core-info) |
| System assets (BIOS, firmware, etc.) | [https://buildbot.libretro.com/assets/system/](https://buildbot.libretro.com/assets/system/) |
| Official RetroArch documentation | [https://docs.libretro.com/](https://docs.libretro.com/) |
| Debian Wiki – RetroArch | [https://wiki.debian.org/RetroArch](https://wiki.debian.org/RetroArch) |

---

## Final Notes

- The Debian package disables auto‑updates and the core downloader **by default** – this is intentional for stability.
- Manual installation (Method 1) is the most straightforward and works for **any** core, regardless of distribution restrictions.
- If you choose Method 2, remember that you may still need to manually place BIOS/asset files in `~/.config/retroarch/system/`.
- Always test your video driver setting; `vulkan` is recommended for PPSSPP and other 3D‑heavy cores.
