## Option 2: User Privileges & Feedback

### 1. What does this component do?
This component serves as a centralized utility suite designed to streamline administrative access, enhance usability during system maintenance, and correct common permission inconsistencies found in fresh Debian installations or environments where `sudo` usage has been mishandled. It acts as an automated "First-Time User" setup tool that bridges the gap between strict Linux security policies (where standard users cannot modify system files) and practical daily workflow needs (such as installing software without constant password prompts).

At a high level, it manages four critical aspects of user privilege:
1.  **Elevated Permissions:** Ensures the current user has membership in the `sudo` group.
2.  **Workflow Efficiency:** Configures specific commands to run without authentication (NOPASSWD) for maintenance tasks.
3.  **Data Integrity:** Repairs ownership issues on the home directory caused by accidental root-level file creation.
4.  **User Experience:** Modifies terminal behavior during password entry to provide visual feedback.

### 2. What exactly does it do and why
The script executes a sub-menu loop that allows the user to toggle between four distinct configurations. Each option addresses a specific pain point in Linux administration:

*   **Sudo Group Membership (Option 1):**
    *   **Action:** Checks if the current username exists within the `/etc/group` file under the `sudo` group entry. If absent, it adds the user via `usermod -aG sudo`.
    *   **Why:** By default, Debian creates a standard user without administrative rights to prevent accidental system damage. This ensures the user can execute privileged commands (`sudo`) immediately after installation or recovery.

*   **Passwordless Sudo (Option 2):**
    *   **Action:** Creates an isolated configuration file in `/etc/sudoers.d/` containing `NOPASSWD` rules for specific binaries (e.g., `/usr/bin/apt`, `/sbin/reboot`). It enforces strict path matching to prevent privilege escalation risks.
    *   **Why:** Frequent password prompts interrupt workflows during updates or system reboots. This allows automation and quick access for maintenance tasks without compromising security on other commands.

*   **Repair Home Directory Ownership (Option 3):**
    *   **Action:** Scans the user's home directory (`/home/$USER`) to verify if files are owned by `root` (UID 0) instead of the user. If a mismatch is found, it recursively resets ownership via `chown -R`.
    *   **Why:** Misconfigured file permissions often occur when users attempt to fix issues using root privileges directly in their home folders. This restores data integrity so applications can read/write their own configuration files without permission errors.

*   **Sudo Password Feedback (Option 4):**
    *   **Action:** Toggles the `Defaults pwfeedback` directive within a dedicated sudoers file. When enabled, typing a password displays asterisks (`****`) instead of being hidden.
    *   **Why:** Linux terminals hide input by default to prevent shoulder surfing. This option improves usability for users who need visual confirmation that their keystrokes are registering correctly, reducing the risk of typos in complex passwords.

### 3. The Logical Decision Tree (Step-by-Step)
The execution flow is governed by `sudo_config.sh`, which acts as a state machine within the main menu loop. Below is the chronological logic for each option:

**Entry Point:**
1.  The script enters the `config_sudo()` function and loops until the user selects "Back to main menu".
2.  It presents a Whiptail menu with options 1–5.

**Option 1: Sudo Group Membership (`_check_sudo_group`)**
*   **Step A:** Execute `groups "$USER"` via pipe to grep for `\bsudo\b`.
*   **Decision:**
    *   *If Match:* Display success message ("User is already in sudo group"). Exit function.
    *   *If No Match:* Prompt user with a confirmation dialog asking if they want to add the user to the `sudo` group.
        *   *On Confirm:* Execute `sudo usermod -aG sudo "$USER"`. If successful, display message instructing logout/login for changes to take effect. If failure, log error and return status 1.

**Option 2: Passwordless Sudo (`_configure_nopasswd`)**
*   **Step A:** Check if `/etc/sudoers.d/${USER}-nopasswd` exists.
    *   *If Exists:* Prompt to remove the configuration (restore password prompts). If confirmed, delete file and notify success. Return function.
    *   *If Not Exists:* Prompt user to configure NOPASSWD for maintenance commands.
        *   *On Confirm:* Display a checklist menu allowing selection of `apt`, `systemctl`, or `power` commands.
*   **Step B:** Process selected commands:
    *   Construct the content string based on selections, explicitly defining paths (e.g., `/usr/bin/apt`, `/sbin/shutdown`) to ensure compatibility across Debian versions.
*   **Step C:** Write configuration:
    *   Pipe content to `sudo tee /etc/sudoers.d/${USER}-nopasswd`.
    *   Set file permissions to `0440` (readable only by root and owner).
    *   Notify success or failure.

**Option 3: Repair Home Directory Ownership (`_repair_home_ownership`)**
*   **Step A:** Resolve the absolute path of `$HOME`. If directory does not exist, notify error and return status 1.
*   **Step B:** Retrieve User ID (UID) using `id -u "$USER"`.
*   **Step C:** Check current owner UID of `$HOME` using `stat -c '%u'`.
    *   *If Match:* Notify that ownership is correct and exit.
    *   *If Mismatch:* Identify the expected username for the conflicting UID. Prompt user to confirm repair.
        *   *On Confirm:* Execute `sudo chown -R "$USER:$USER" "$home"`. If successful, notify success. If failure, log error and return status 1.

**Option 4: Sudo Password Feedback (`_toggle_pwfeedback`)**
*   **Step A:** Check if `/etc/sudoers.d/pwfeedback` exists.
    *   *If Exists:* Prompt to disable asterisks (restore hidden input). If confirmed, delete file and notify success. Return function.
    *   *If Not Exists:* Prompt user to enable visual feedback.
        *   *On Confirm:* Write `Defaults pwfeedback` to `/etc/sudoers.d/pwfeedback`.
*   **Step B:** Verify write permission. If successful, notify success; otherwise, log error and return status 1.

### 4. Compatibility with all Debian
This module is designed for universal compatibility across the Debian family (Bullseye, Bookworm, Trixie, etc.) due to its reliance on standard POSIX-compliant tools and strict path handling.

*   **Architecture Independence:** The script utilizes `usermod`, `chown`, and `grep` which are available on all x86_64, arm64, and i386 Debian architectures.
*   **Version Agnosticism (Debian 11+):**
    *   **Sudoers Syntax:** The script writes to `/etc/sudoers.d/`, a directory introduced in `sudo` version 1.9.0p5 (available since Debian 7). It avoids editing the master file (`/etc/sudoers`) directly, preventing lockfile issues and syntax errors regardless of the specific Debian version's sudo configuration style.
    *   **Path Hardening:** The NOPASSWD logic explicitly includes both `/usr/bin` and `/bin` paths for commands like `apt`. This ensures that on older Debian versions (e.g., Bullseye) where binaries might reside in different locations or symlinks differ, the permissions remain valid.
*   **Security Best Practices:** By isolating configurations into separate files (`/etc/sudoers.d/`) and setting restrictive permissions (`0440`), it adheres to Debian's security guidelines for `sudo`. This ensures that even on older systems with stricter default policies, the configuration is accepted without requiring a full system reboot or sudo upgrade.
*   **Importance:** Consistent behavior across versions means users can migrate between Debian releases (e.g., from 11 to 12) without needing to manually reconfigure these specific privileges, ensuring a stable and secure environment regardless of the underlying OS version.
