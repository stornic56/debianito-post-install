## Option 9: Swap

### 1. What does this component do?
This module is responsible for the secure management of disk-based swap space within the `debianito` environment. Unlike standard Linux tools that might overwrite existing configurations or conflict with memory compression features (like ZRAM), this script operates as a **priority-aware, persistent swap manager**.

Its primary functions include:
*   **Dynamic Allocation:** Creating and resizing swapfiles based on detected RAM capacity without requiring physical partition changes.
*   **Priority Integration:** Explicitly setting the swap priority (`pri=10`) to ensure it sits below ZRAM (which uses `priority=100`). This prevents the system from using disk I/O for memory swapping until compressed RAM is exhausted, optimizing performance.
*   **Persistence Management:** Safely editing `/etc/fstab` with a unique tag (`# debianito-managed-swap`) to ensure swap survives reboots without corrupting manual entries.
*   **Safety Locking:** Prevents concurrent operations using file locking mechanisms to avoid race conditions during active system usage.

### 2. How does it work?
The script leverages several advanced Linux subsystems and safety protocols:

1.  **File System Detection:** It identifies the filesystem type of the target partition (e.g., `ext4`, `btrfs`). For Btrfs, it applies specific flags (`chattr +C` for copy-on-write optimization) to prevent performance degradation during swap operations.
2.  **Allocation Strategy:** It prefers `fallocate` for instant space reservation on supported filesystems, falling back to `dd if=/dev/zero` for compatibility or zeroing requirements (like Btrfs).
3.  **Fstab Validation:** Before writing changes to `/etc/fstab`, it creates a temporary file and validates the syntax using `findmnt --verify`. If validation fails, the script aborts and restores the original state.
4.  **Concurrency Control:** It utilizes `flock` on `/run/lock/debianito-swap.lock`. This ensures that if another process is modifying swap settings (e.g., a system update), this script will wait or exit gracefully to prevent filesystem corruption.
5.  **Swappiness Tuning:** It configures `vm.swappiness` via both runtime (`sysctl -w`) and persistent (`/etc/sysctl.d/99-swappiness-debianito.conf`) mechanisms, defaulting to values that favor RAM usage over disk swapping (e.g., 10-20).

### 3. The Logical Decision Tree (Step by Step)
The execution flow follows a strict logical tree designed for safety and idempotency:

1.  **Initialization & Locking:**
    *   The `manage_swap()` function attempts to acquire an exclusive lock (`flock -n`). If the lock is held by another process, it immediately exits with a "Busy" message to prevent conflicts.

2.  **Menu Selection Loop:**
    *   Enters a continuous loop presenting options (Status, Create, Remove, Swappiness).
    *   Breaks only when the user selects "Back to main menu".

3.  **Action Execution Paths:**
    *   **Path A: Status Check (`_swap_current_status`)**
        *   Reads active swap entries via `swapon --show`.
        *   Reads current swappiness from `/proc/sys/vm/swappiness`.
        *   Parses `/etc/fstab` for managed tags.
    *   **Path B: Create/Resize (`_swap_create_file`)**
        *   **Recommendation:** Calculates optimal size based on RAM (e.g., 2GB for >16GB RAM, 4GB for 8-16GB).
        *   **Btrfs Check:** If the filesystem is Btrfs, it warns about `nodatacow` requirements and hibernation limitations.
        *   **Existence Check:** If `/swapfile` exists, it prompts to confirm recreation (deleting old data first via `swapoff`).
        *   **Allocation:** Uses `fallocate` or `dd` to zero the file. Sets permissions (`chmod 600`) and initializes swap (`mkswap`).
        *   **Persistence:** Attempts to write the new entry to `/etc/fstab`. If validation fails, it cleans up (removes file) before exiting.
    *   **Path C: Remove (`_swap_remove_file`)**
        *   Checks for the unique `SWAP_FSTAB_TAG` in fstab.
        *   Confirms user intent to delete.
        *   Executes `swapoff`, removes the fstab line, and deletes the physical file.
    *   **Path D: Swappiness (`_swap_set_swappiness`)**
        *   Validates input (0-100 integer).
        *   Writes a temporary sysctl config file.
        *   Applies changes immediately via `sysctl -w`.

### 4. What does each menu item do and what does it mean?
Each option in the swap management submenu serves a specific technical purpose:

*   **Option 1: Show current swap & swappiness**
    *   **Technical Action:** Aggregates data from `/proc/swaps`, `/proc/sys/vm/swappiness`, and `/etc/fstab`.
    *   **Significance:** Provides an audit trail of the current memory management state. It verifies if ZRAM is active (implied by priority check) and how much disk swap is currently in use.

*   **Option 2: Create / resize swapfile**
    *   **Technical Action:** Allocates a new block device file (`/swapfile`) or expands an existing one. Sets the `pri=10` flag to ensure it acts as a secondary memory layer after ZRAM fills up.
    *   **Significance:** Essential for systems with low RAM that need overflow protection without installing physical partitions. The "Resize" capability allows adapting to new hardware configurations dynamically.

*   **Option 3: Remove swapfile**
    *   **Technical Action:** Disables the swapfile (`swapoff`), removes it from `/etc/fstab`, and deletes the file from disk.
    *   **Significance:** Useful for troubleshooting, freeing up disk space (e.g., on SSDs where write cycles are a concern), or migrating to ZRAM-only configurations if RAM is sufficient.

*   **Option 4: Change swappiness**
    *   **Technical Action:** Modifies the kernel parameter `vm.swappiness`.
    *   **Significance:** Controls the "aggressiveness" of swapping. A lower value (e.g., 10) tells the kernel to keep data in RAM longer, only using swap as a last resort. This is critical for desktop performance and battery life on laptops.

*   **Option 5: Back to main menu**
    *   **Technical Action:** Releases the file lock (`exec 9>&-`) and terminates the submenu loop.
    *   **Significance:** Returns control to the user, ensuring no swap operations are running in the background before they navigate to other system configurations.
