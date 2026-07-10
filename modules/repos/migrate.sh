#!/usr/bin/env bash
# migrate.sh — Stable → Testing / SID branch migration
# License GPL v3

_MIGRATE_BACKUP=""

_persistent_backup_repos() {
    local stamp
    stamp=$(date +%Y%m%d-%H%M%S)
    _MIGRATE_BACKUP="/var/backups/debianito-repos-${stamp}.tar.gz"
    sudo mkdir -p /var/backups
    local files=()
    [ -f /etc/apt/sources.list ] && files+=("/etc/apt/sources.list")
    [ -d /etc/apt/sources.list.d ] && files+=("/etc/apt/sources.list.d")
    [ ${#files[@]} -eq 0 ] && return 1
    sudo tar czf "$_MIGRATE_BACKUP" "${files[@]}" 2>/dev/null
    echo "Backup: $_MIGRATE_BACKUP"
}

_restore_backup() {
    if [ -z "$_MIGRATE_BACKUP" ] || [ ! -f "$_MIGRATE_BACKUP" ]; then
        _msg "Restore Error" "No backup found at $_MIGRATE_BACKUP.\nCannot restore. Your system may be in an inconsistent state." 10 70
        return 1
    fi
    echo -e "${YELLOW}Restoring repository backup...${NC}"
    sudo tar xzf "$_MIGRATE_BACKUP" -C / 2>/dev/null
    echo -e "${GREEN}Backup restored from $_MIGRATE_BACKUP${NC}"
}

_write_deb822_branch() {
    local target="$1"
    local main_file="/etc/apt/sources.list.d/debian.sources"

    local main_content=""
    if [ "$target" = "sid" ]; then
        main_content+="Types: deb\n"
        main_content+="URIs: https://deb.debian.org/debian\n"
        main_content+="Suites: sid\n"
        main_content+="Components: main contrib non-free non-free-firmware\n"
        main_content+="\n"
        main_content+="Types: deb\n"
        main_content+="URIs: https://security.debian.org/debian-security\n"
        main_content+="Suites: sid\n"
        main_content+="Components: main contrib non-free non-free-firmware\n"
    else
        # testing
        main_content+="Types: deb\n"
        main_content+="URIs: https://deb.debian.org/debian\n"
        main_content+="Suites: testing testing-updates\n"
        main_content+="Components: main contrib non-free non-free-firmware\n"
        main_content+="\n"
        main_content+="Types: deb\n"
        main_content+="URIs: https://security.debian.org/debian-security\n"
        main_content+="Suites: testing-security\n"
        main_content+="Components: main contrib non-free non-free-firmware\n"
    fi

    sudo mkdir -p /etc/apt/sources.list.d
    echo -e "$main_content" | sudo tee "$main_file" > /dev/null
    echo "Wrote $main_file"
}

_branch_migration() {
    # ── Screen 1: Risk warning ──
    _msg "WARNING: Branch Migration" \
"Migrating from Debian Stable to Testing or SID is a\n\
MAJOR change and CAN make your system UNBOOTABLE.\n\n\
Risks include:\n\
  • NVIDIA / DKMS drivers may break\n\
  • System may fail to boot after reboot\n\
  • Some packages may be removed or replaced\n\
  • SID (unstable) receives NO security updates\n\n\
A full persistent backup will be saved to /var/backups/\n\
so you can restore if things go wrong." 16 70 || true

    if ! _confirm "Branch Migration" "Do you want to proceed with the migration?"; then
        echo "Migration cancelled."
        return
    fi

    # ── Screen 2: Plan summary ──
    local plan="This operation will:\n\n"
    plan+="  1. Backup current APT sources to /var/backups/\n"
    plan+="  2. Remove any backports configuration\n"
    plan+="  3. Write new DEB822 sources for the target branch\n"
    plan+="  4. Run: apt update\n"
    plan+="  5. Run: apt upgrade -y\n"
    plan+="  6. Run: apt full-upgrade -y\n"
    plan+="  7. Run: apt autoremove -y\n\n"
    plan+="If apt update fails, the backup is restored immediately."

    _msg "Migration Plan" "$plan" 16 70 || true

    if ! _confirm "Migration Plan" "Proceed with the plan?"; then
        echo "Migration cancelled."
        return
    fi

    # ── Screen 3: Branch selection ──
    local branch
    branch=$(_inputbox "Target Branch" \
        "Type exactly TESTING or SID (case-sensitive):" 10 60 "")

    [ -z "$branch" ] && { echo "Migration cancelled."; return; }

    if [ "$branch" != "TESTING" ] && [ "$branch" != "SID" ]; then
        _msg "Invalid Branch" "You typed: $branch\n\nExpected: TESTING or SID (exact, case-sensitive).\nAborting." 10 60
        return
    fi

    # Normalize to lowercase for internal use
    local target
    target=$(echo "$branch" | tr '[:upper:]' '[:lower:]')

    # ── Screen 4: Execution ──
    echo -e "${YELLOW}Starting branch migration to ${target}...${NC}"

    # 4a. Persistent backup
    echo "Creating backup..."
    _persistent_backup_repos || {
        _msg "Backup Error" "Failed to create backup. Aborting." 8 60
        return
    }

    # 4b. Clean backports
    echo "Removing backports configuration..."
    [ -f /etc/apt/sources.list.d/debian-backports.sources ] && sudo rm -f /etc/apt/sources.list.d/debian-backports.sources
    [ -f /etc/apt/sources.list.d/debian-backports.list ] && sudo rm -f /etc/apt/sources.list.d/debian-backports.list

    # 4c. Remove any old classic source files to avoid conflicts
    [ -f /etc/apt/sources.list ] && sudo rm -f /etc/apt/sources.list

    # 4d. Write new sources
    _write_deb822_branch "$target"

    # 4e. SID guardrails: install bug alerts before upgrade
    if [ "$target" = "sid" ]; then
        echo -e "${YELLOW}Installing apt-listbugs and apt-listchanges (SID guardrails)...${NC}"
        sudo apt update -qq 2>/dev/null || true
        sudo DEBIAN_FRONTEND=noninteractive apt install -y apt-listbugs apt-listchanges || true
    fi

    # 4f. apt update with rollback on failure
    echo -e "${YELLOW}Running apt update...${NC}"
    if ! sudo apt update; then
        echo -e "${RED}apt update failed. Restoring backup...${NC}"
        _restore_backup
        _msg "Migration Failed" \
"apt update failed. Backup has been restored from:\n\
$_MIGRATE_BACKUP\n\n\
Your system should be back to its previous state.\n\
Run 'sudo apt update' manually to verify." 12 70
        return
    fi

    # 4g. Full upgrade
    _run_cmd "Upgrade" "sudo apt upgrade -y" "Upgrading packages..."
    _run_cmd "Full-Upgrade" "sudo apt full-upgrade -y" "Running full-upgrade..."
    _run_cmd "Autoremove" "sudo apt autoremove -y" "Removing obsolete packages..."

    # 4h. Re-run detection to reflect new branch
    echo -e "${YELLOW}Re-running system detection for new branch...${NC}"
    detect_debian_version
    detect_kernel
    detect_gpu
    detect_storage

    echo -e "${GREEN}Branch migration to ${target} completed successfully.${NC}"

    # ── Screen 5: Reboot reminder ──
    _msg "Migration Complete" \
"System has been migrated to ${target}.\n\n\
Backup saved at:\n  $_MIGRATE_BACKUP\n\n\
REBOOT your system.\nIf it fails to boot, restore the backup manually:\n\
  sudo tar xzf $_MIGRATE_BACKUP -C /\n  sudo apt update\n  sudo apt upgrade" 16 70
}
