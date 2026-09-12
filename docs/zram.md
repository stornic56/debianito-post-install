# Option 9: ZRAM Configuration & Memory Optimization

## 1. The Science of ZRAM vs. Traditional Swap

### Core Concept: CPU Cycles vs. Disk I/O

Traditional swap storage operates on a fundamental latency gap that becomes critical under memory pressure:

| Storage Medium | Latency Range | Write Amplification | SSD Wear Impact |
| --------------- | --------------- | --------------------- | ----------------- |
| **DRAM (RAM)** | ~10–50 nanoseconds | None | Zero |
| **NVMe SSD** | ~20–70 microseconds | 1.2x–3.0x | Moderate to High |
| **SATA SSD** | ~100–200 microseconds | 1.5x–4.0x | High |
| **HDD** | ~5–10 milliseconds | N/A (mechanical) | Irrelevant |

When a Linux system experiences memory pressure, the kernel must decide what to swap out. Traditional swap writes pages directly to disk storage:

- **Time Cost**: Each 4 KiB page write takes microseconds (NVMe) to milliseconds (HDD)
- **Wear Cost**: Every write consumes P/E (Program/Erase) cycles from NAND flash cells, reducing TBW (Terabytes Written) lifespan
- **System Impact**: High latency causes "thrashing" where the system spends more time waiting for disk I/O than executing actual work

### ZRAM's Solution: Compression in RAM

ZRAM creates a compressed block device entirely within physical memory. When pages need to be swapped, they are:

1. **Compressed on-the-fly** using CPU algorithms (LZ4 or ZSTD)
2. **Stored in RAM pool** at compressed size (typically 2:1 to 3:1 ratio)
3. **Decompressed instantly** when needed (microseconds vs milliseconds)

The trade-off is explicit: **CPU cycles for reduced I/O latency**. Modern CPUs can compress/decompress pages in microseconds, making this far cheaper than any disk operation.

### Why Only LZ4 and ZSTD?

The script offers only two algorithms because they represent the optimal balance points:

| Algorithm | Compression Ratio | Speed | CPU Overhead | Best Use Case |
|-----------|------------------|-------|--------------|---------------|
| **LZ4**   | ~2:1–3:1         | Fastest | Lowest | Gaming, real-time workloads |
| **ZSTD**  | ~3:1–5:1         | Medium | Moderate | General use, better memory savings |

- **LZ4**: Prioritizes speed over compression ratio. Ideal for systems where CPU availability is limited or latency-sensitive (gaming servers).
- **ZSTD**: Offers superior compression ratios with acceptable overhead. Best for systems prioritizing maximum effective RAM capacity.

The kernel supports additional algorithms (lzo-rle, deflate, lz4hc), but these are either deprecated, slower, or offer diminishing returns compared to LZ4/ZSTD in modern hardware.

### Extending SSD Lifespan Through Reduced Writes

By intercepting swap writes before they reach physical storage:

- **Write Reduction**: Pages that would write to disk now compress in RAM
- **TBW Conservation**: Each avoided write preserves P/E cycles on NAND flash cells
- **System Longevity**: Critical for systems with limited SSD endurance ratings (e.g., 100 TBW consumer drives)

As the Linux kernel documentation states: *"Users with SSDs as swap devices can extend device lifespan by drastically reducing writes that shorten its life."*

---

## 2. Injection Flow and Configuration Logic (`zram-tools`)

### Pipeline Execution Sequence

The script follows a deterministic flow to ensure safe, reproducible configuration:

```
┌─────────────────────────────────────────────────────────────┐
│                    install_zram() Function                  │
├─────────────────────────────────────────────────────────────┤
│ 1. Validate RAM Detection                                   │
│    └─ Check if RAM_KB is available and non-zero             │
│                                                             │
│ 2. Compression Algorithm Selection                          │
│    ├─ Present menu: LZ4 (fast) vs ZSTD (better ratio)       │
│    └─ User choice stored in $algo variable                  │
│                                                             │
│ 3. Size Calculation Logic                                   │
│    ┌──────────────────────────────────────────────┐         │
│    │ ram_gb <= 8 ? 50% : 4096 MB fixed      │         │
│    │ recommended_mb = (ram_gb <= 8)              │         │
│    │                ? (RAM_KB/1024/1024 + 1)      │         │
│    │                  / 2 * 1024                 │         │
│    │                : 4096                       │         │
│    └──────────────────────────────────────────────┘         │
│    └─ Result: 50% RAM if ≤8 GB, else fixed 4096 MB      │
│                                                             │
│ 4. Configuration Confirmation                               │
│    ├─ Display summary with algorithm, size, priority=100    │
│    └─ User must confirm before applying                     │
│                                                             │
│ 5. Package Installation                                     │
│    sudo apt install -y zram-tools                           │
│                                                             │
│ 6. Reset Existing ZRAM Device                               │
│    sudo swapoff /dev/zram0 (ignore errors)                  │
│    sudo modprobe -r zram (ignore errors)                    │
│    └─ Guarantees the old device is released before          │
│       applying the new configuration                        │
│                                                             │
│ 7. Configuration File Write                                 │
│    /etc/default/zramswap                                    │
│    ALGO=$algo                                               │
│    SIZE=$zram_size                                          │
│    PRIORITY=100                                             │
│                                                             │
│ 8. Service Restart                                          │
│    sudo systemctl restart zramswap || true || true                  │
│    └─ Verify: comp_algorithm shows [algo]; sudo zramctl     │
└─────────────────────────────────────────────────────────────┘
```

### Mathematical Size Calculation

The script uses this formula to determine ZRAM size:

```bash
ram_gb=$(( RAM_KB / 1024 / 1024 ))
if [ "$ram_gb" -le 8 ]; then
    recommended_mb=$(( ((RAM_KB / 1024 / 1024 + 1) / 2) * 1024 ))
else
    recommended_mb=4096
fi
```

**Breakdown:**

- `RAM_KB`: Total RAM in kilobytes from `/proc/meminfo`
- `/ 1024 / 1024`: Convert KB to GB
- `+ 1`: Add rounding buffer for odd values
- **≤8 GB**: Target 50% of total RAM (generous swap for low-memory systems)
- **>8 GB**: Fixed 4096 MB — avoids excessive RAM reservation on high-memory machines while still providing meaningful swap space

**Examples:**

```
System with 4 GB (4194304 KB) RAM (<=8 GB):
recommended_mb = ((4194304 / 1024 / 1024 + 1) / 2) * 1024
              = ((4 + 1) / 2) * 1024
              = (5 / 2) * 1024
              = 2 * 1024
              = 2048 MB (2 GB)

System with 8 GB (8388608 KB) RAM (<=8 GB):
recommended_mb = ((8388608 / 1024 / 1024 + 1) / 2) * 1024
              = ((8 + 1) / 2) * 1024
              = (9 / 2) * 1024
              = 4 * 1024
              = 4096 MB (4 GB)

System with 16 GB (16777216 KB) RAM (>8 GB):
recommended_mb = 4096 MB (fixed)

System with 32 GB (33554432 KB) RAM (>8 GB):
recommended_mb = 4096 MB (fixed)
```

### Priority Configuration (`PRIORITY=100`)

The `swapon` priority determines which swap device the kernel prefers when multiple devices exist:

- **Higher number** = Higher preference (used first by kernel)
- **Default system swap**: Typically 0–60
- **ZRAM with PRIORITY=100**: Ensures ZRAM is used before physical disk swap

This prevents thrashing where pages bounce between slow disk swap and fast RAM-based ZRAM.

---

## 3. Priority & Swappiness Integration

### How ZRAM Coexists with Disk Swap

The script does **not** hardcode `vm.swappiness` or watermark tuning. Instead, it uses a **priority-based swap hierarchy** combined with an explicit swappiness control in the Swap module:

| Swap Device | Priority | Config Location | When It Is Used |
|-------------|----------|-----------------|-----------------|
| **ZRAM** | `100` | `/etc/default/zramswap` (`PRIORITY=100`) | **First** — kernel prefers higher priority |
| **Disk swapfile** (`/swapfile`) | `10` | `/etc/fstab` (`pri=10`) + `# debianito-managed-swap` tag | **Second** — only after ZRAM device is full |

This is implemented in `zram.sh:_zram_create` (writes `PRIORITY=100`) and `swap.sh:_swap_create_file` (writes `pri=10`). Priority is the canonical Linux `swapon` mechanism: `swapon --show` lists `PRIO` and the kernel always fills the highest-priority device first.

### Swappiness Is Managed Separately

Swappiness (`vm.swappiness`, 0–100, default 60 on Debian) controls **how eagerly the kernel swaps at all**, regardless of which device is preferred.

- The ZRAM module **does not change swappiness**. Changing it would affect both ZRAM and disk swap in ways that are workload-specific.
- To tune it, use **Option 10 → Swap Management → 4. Change swappiness** (`swap.sh:_swap_set_swappiness`):

  ```bash
  cat /proc/sys/vm/swappiness          # current value
  # Persistent config
  /etc/sysctl.d/99-swappiness-debianito.conf  → vm.swappiness=<value>
  # Applied immediately
  sudo sysctl -w vm.swappiness=<value>
  ```

- Recommended starting points (not enforced by the script):
  - **General desktop**: `60` (Debian default)
  - **Gaming / 8 GB or less**: `80–100` — allows ZRAM to be used earlier, trading CPU for reduced disk I/O
  - **ZRAM-only, no disk swap**: `100–150` is safe because swap *is* RAM (compressed); there is no SSD wear cost

> **Previous documentation** recommended `vm.swappiness = 180` plus `watermark_*` and `page-cluster` tuning for ZRAM. Those values are **not written by the current script** and are omitted here to avoid drifting from the implemented behavior. If you need watermark tuning, add it manually to `/etc/sysctl.d/` and validate with your workload.

### Verifying the Hierarchy

```bash
sudo swapon --show
# NAME       TYPE      SIZE USED PRIO
# /dev/zram0 partition   4G   0B  100
# /swapfile  file        4G   0B   10
cat /proc/sys/vm/swappiness
```

---

## 4. Service Lifecycle and Validation

### Safe Service Initialization

```bash
sudo systemctl restart zramswap || true
```

**Why `restart` instead of `start`:**

- Ensures previous configuration is cleanly terminated
- Prevents orphaned processes from conflicting with new settings
- Reloads systemd unit files if they were modified during installation

### User Verification Commands

#### Primary: `zramctl` (util-linux)

```bash
sudo zramctl
```

**Output Interpretation:**

```
NAME       ALGORITHM DISKSIZE  DATA   COMPR    TOTAL STREAMS MOUNTPOINT
/dev/zram0 lz4           4G     2.1G 318.6M 424.9M        [SWAP]
```

| Column | Meaning |
| -------- | --------- |
| **NAME** | Device identifier (/dev/zram0) |
| **ALGORITHM** | Active compression algorithm (lz4, zstd, etc.) |
| **DISKSIZE** | Maximum uncompressed data capacity configured |
| **DATA** | Currently stored uncompressed pages in ZRAM |
| **COMPR** | Actual compressed size using physical RAM |
| **TOTAL** | Total memory used including metadata overhead |
| **STREAMS** | Number of active swap streams (typically 4) |

#### Secondary: `swapon --show`

```bash
sudo swapon --show
```

Shows all active swap devices with priority levels. ZRAM should appear with priority matching the configured value (100 in this script).

### Real-Time Monitoring

For continuous monitoring of compression effectiveness:

```bash
# Watch compression ratio changes over time
watch -n 5 'zramctl | grep /dev/zram'

# Monitor memory pressure and swap usage
watch -n 5 'free -h && zramctl'
```

### Troubleshooting Indicators

| Symptom | Likely Cause | Solution |
| --------- | -------------- | ---------- |
| `DATA` equals `DISKSIZE` but `COMPR` is near zero | System under memory pressure, ZRAM not being used | Increase `vm.swappiness` or check if physical swap has lower priority |
| High CPU usage with low compression ratio | Incompressible data (e.g., encrypted files) | Consider backing device for incompressible pages |
| Service fails to start | Missing dependencies (`zram-tools`, kernel module) | Run `sudo apt install zram-tools` and verify `modprobe zram` |

### Permanent Configuration

To ensure ZRAM persists across reboots, the script writes configuration to `/etc/default/zramswap`. This file is read by systemd's `zramswap.service` unit at boot time. Additionally, adding the following ensures the kernel module loads:

```bash
echo "zram" | sudo tee /etc/modules-load.d/zram.conf
```

### References

- [https://docs.kernel.org/admin-guide/blockdev/zram.html](https://docs.kernel.org/admin-guide/blockdev/zram.html)
- [https://wiki.debian.org/ZRam](https://wiki.debian.org/ZRam)
- [https://wiki.archlinux.org/title/Zram](https://wiki.archlinux.org/title/Zram)
- [https://wiki.gentoo.org/wiki/Zram](https://wiki.gentoo.org/wiki/Zram)
