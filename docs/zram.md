# Option 8: ZRAM Configuration & Memory Optimization

## 1. The Science of ZRAM vs. Traditional Swap

### Core Concept: CPU Cycles vs. Disk I/O

Traditional swap storage operates on a fundamental latency gap that becomes critical under memory pressure:

| Storage Medium | Latency Range | Write Amplification | SSD Wear Impact |
|---------------|---------------|---------------------|-----------------|
| **DRAM (RAM)** | ~10–50 nanoseconds | None | Zero |
| **NVMe SSD**   | ~20–70 microseconds | 1.2x–3.0x | Moderate to High |
| **SATA SSD**   | ~100–200 microseconds | 1.5x–4.0x | High |
| **HDD**        | ~5–10 milliseconds | N/A (mechanical) | Irrelevant |

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
│    │ half_ram_mb = ((RAM_KB / 1024 / 1024 + 1)   │          │
│    │                / 2) * 1024                   │         │
│    └──────────────────────────────────────────────┘         │
│    └─ Result: ~50% of total physical RAM in MB              │
│                                                             │
│ 4. Configuration Confirmation                               │
│    ├─ Display summary with algorithm, size, priority=100    │
│    └─ User must confirm before applying                     │
│                                                             │
│ 5. Package Installation                                     │
│    sudo apt install -y zram-tools                           │
│                                                             │
│ 6. Configuration File Write                                 │
│    /etc/default/zramswap                                    │
│    ALGO=$algo                                               │
│    SIZE=$zram_size                                          │
│    PRIORITY=100                                             │
│                                                             │
│ 7. Service Restart                                          │
│    sudo systemctl restart zramswap                          │
└─────────────────────────────────────────────────────────────┘
```

### Mathematical Size Calculation

The script uses this formula to determine ZRAM size:

```bash
half_ram_mb=$(( ((RAM_KB / 1024 / 1024 + 1) / 2) * 1024 ))
```

**Breakdown:**
- `RAM_KB`: Total RAM in kilobytes from `/proc/meminfo`
- `/ 1024 / 1024`: Convert KB to MB
- `+ 1`: Add rounding buffer for odd values
- `/ 2`: Target approximately 50% of total RAM
- `* 1024`: Round back to nearest MB

**Example:**
```
System with 8 GB (8388608 KB) RAM:
half_ram_mb = ((8388608 / 1024 / 1024 + 1) / 2) * 1024
            = ((8 + 1) / 2) * 1024
            = (9 / 2) * 1024
            = 4.5 * 1024
            = 4608 MB (~4.5 GB)
```

### Priority Configuration (`PRIORITY=100`)

The `swapon` priority determines which swap device the kernel prefers when multiple devices exist:

- **Higher number** = Higher preference (used first by kernel)
- **Default system swap**: Typically 0–60
- **ZRAM with PRIORITY=100**: Ensures ZRAM is used before physical disk swap

This prevents thrashing where pages bounce between slow disk swap and fast RAM-based ZRAM.

---

## 3. Kernel Parameter Tuning (`sysctl`)

### Essential VM Parameters for Aggressive ZRAM Usage

While the current script focuses on `zram-tools` configuration, optimal performance requires complementary kernel parameter tuning:

```bash
# Recommended sysctl configuration for ZRAM systems
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
```

### Parameter Explanations

| Parameter | Value | Purpose |
|-----------|-------|---------|
| **`vm.swappiness`** | `180–200` | Aggressively prefer swap over keeping pages in RAM. Higher values (up to 200) are ideal for ZRAM because it's faster than disk swap. Default 60 is too conservative for memory-constrained systems. |
| **`vm.watermark_boost_factor`** | `0` | Disable additional watermark boosting that could cause premature page reclaim |
| **`vm.watermark_scale_factor`** | `125` | Adjust low-memory watermark thresholds to trigger swap earlier when RAM is constrained |
| **`vm.page-cluster`** | `0` | Disable page clustering. Research shows this reduces unnecessary sequential reads during swap operations, improving ZRAM efficiency by ~15% in gaming workloads |

### Why High Swappiness for ZRAM?

Traditional wisdom suggests keeping swappiness low (20–40) to avoid swapping frequently. However:

- **ZRAM is faster than disk**: Microseconds vs milliseconds
- **Thrashing prevention**: Higher swappiness moves pages to ZRAM before they hit slow disk swap
- **Effective RAM expansion**: Compressed pages in ZRAM can store 2–3x more data, effectively increasing available memory

The Pop!_OS project and Linux kernel documentation both recommend values beyond 100 for in-memory swap scenarios like ZRAM/ZSWAP.

---

## 4. Service Lifecycle and Validation

### Safe Service Initialization

```bash
sudo systemctl restart zramswap
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
|--------|---------|
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
|---------|--------------|----------|
| `DATA` equals `DISKSIZE` but `COMPR` is near zero | System under memory pressure, ZRAM not being used | Increase `vm.swappiness` or check if physical swap has lower priority |
| High CPU usage with low compression ratio | Incompressible data (e.g., encrypted files) | Consider backing device for incompressible pages |
| Service fails to start | Missing dependencies (`zram-tools`, kernel module) | Run `sudo apt install zram-tools` and verify `modprobe zram` |

### Permanent Configuration

To ensure ZRAM persists across reboots, the script writes configuration to `/etc/default/zramswap`. This file is read by systemd's `zramswap.service` unit at boot time. Additionally, adding the following ensures the kernel module loads:

```bash
echo "zram" | sudo tee /etc/modules-load.d/zram.conf
```
