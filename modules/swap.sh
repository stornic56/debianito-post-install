#!/usr/bin/env bash
# swap.sh — Disk-based swap management (swapfile + swappiness)
# Independent of zram.sh. Uses pri=10 to coexist with ZRAM priority=100.

readonly SWAP_FILE="/swapfile"
readonly SWAP_FSTAB_TAG="# debianito-managed-swap"
readonly SWAP_PRIORITY="10"
readonly SWAP_CONF="/etc/sysctl.d/99-swappiness-debianito.conf"
readonly SWAP_LOCK="/run/lock/debianito-swap.lock"

# ── Helpers ──

_swap_valid_fstab() {
    local tmp="$1"
    sudo findmnt --verify --fstab "$tmp" >/dev/null 2>&1
}

_swap_safe_write_fstab() {
    local line="$1"
    local tmp
    tmp=$(mktemp) || return 1
    sudo cp /etc/fstab "$tmp"
    sudo sed -i "/$SWAP_FSTAB_TAG/d" "$tmp"
    [ -n "$line" ] && printf '%s\n' "$line" >> "$tmp"
    if _swap_valid_fstab "$tmp"; then
        sudo install -o root -g root -m 0644 "$tmp" /etc/fstab
    else
        local err
        err=$(sudo findmnt --verify --fstab "$tmp" 2>&1 || true)
        rm -f "$tmp"
        _msg "fstab Error" "Validation failed — changes NOT applied.\n\n$err" 12 70
        return 1
    fi
    rm -f "$tmp"
}

_swap_recommend_gb() {
    if [ -z "${RAM_GB:-}" ]; then
        echo 2
        return
    fi
    local ram
    ram=$(echo "$RAM_GB" | awk '{print int($1)}')
    if [ "$ram" -ge 16 ]; then
        echo 2
    elif [ "$ram" -ge 8 ]; then
        echo 4
    else
        local rec
        rec=$((ram * 2))
        [ "$rec" -lt 1 ] && rec=1
        echo "$rec"
    fi
}

# ── Menu options ──

_swap_current_status() {
    local info="── Current swap ──\n"
    info+="$(sudo swapon --show 2>/dev/null || echo '(none active)')\n\n"
    info+="swappiness: $(cat /proc/sys/vm/swappiness)\n\n"
    info+="fstab swap entries:\n"
    info+="$(grep -E 'swap|SWAP' /etc/fstab 2>/dev/null || echo '(none in fstab)')"
    _msg "Swap Status" "$info" 14 65
}

_swap_create_file() {
    local fstype rec_gb
    fstype=$(stat -f -c %T "$(dirname "$SWAP_FILE")" 2>/dev/null || echo "ext4")
    rec_gb=$(_swap_recommend_gb)

    local warn=""
    if [ "$fstype" = "btrfs" ]; then
        warn="Filesystem: Btrfs\nSwapfile on Btrfs needs extra steps (nodatacow).\nHibernation requires swap ≥ RAM and manual resume= config.\n\n"
    fi
    warn+="ZRAM (priority 100) is used first.\nDisk swap (priority $SWAP_PRIORITY) is only consumed after ZRAM fills."

    _msg "Swapfile Info" "$warn" 14 65

    local size_gb
    size_gb=$(_inputbox "Swapfile Size" "Size in GB for $SWAP_FILE:" 10 60 "$rec_gb")
    [ -z "$size_gb" ] && return
    [[ "$size_gb" =~ ^[0-9]+$ ]] && [ "$size_gb" -gt 0 ] || {
        _msg "Error" "Enter a positive integer." 8 40
        return
    }

    if [ -f "$SWAP_FILE" ]; then
        _confirm "Swapfile exists" "$SWAP_FILE already exists.\nRecreate it (${size_gb} GB)?" || return
        sudo swapoff "$SWAP_FILE" 2>/dev/null || true
        sudo rm -f "$SWAP_FILE"
    fi

    echo -e "${YELLOW}Allocating ${size_gb}G swapfile...${NC}"
    if [ "$fstype" = "btrfs" ]; then
        sudo touch "$SWAP_FILE"
        sudo chattr +C "$SWAP_FILE" 2>/dev/null || true
        sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((size_gb * 1024)) status=progress
    else
        sudo fallocate -l "${size_gb}G" "$SWAP_FILE" || \
            sudo dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$((size_gb * 1024)) status=progress
    fi

    sudo chmod 600 "$SWAP_FILE"
    sudo mkswap "$SWAP_FILE" >/dev/null
    sudo swapon "$SWAP_FILE"

    local fstab_line
    fstab_line="$SWAP_FILE none swap sw,pri=$SWAP_PRIORITY 0 0 $SWAP_FSTAB_TAG  # pri=$SWAP_PRIORITY (below zram 100)"
    if _swap_safe_write_fstab "$fstab_line"; then
        _msg "Swapfile" "Swapfile created and added to fstab (persistent).\n\nPriority: $SWAP_PRIORITY (below ZRAM 100)." 12 65
    else
        sudo swapoff "$SWAP_FILE" 2>/dev/null || true
        sudo rm -f "$SWAP_FILE"
    fi
}

_swap_remove_file() {
    local has_tag
    has_tag=$(grep -c "$SWAP_FSTAB_TAG" /etc/fstab 2>/dev/null || echo 0)
    [ "$has_tag" -eq 0 ] && [ ! -f "$SWAP_FILE" ] && {
        _msg "Swap" "No managed swapfile found." 8 50
        return
    }

    _confirm "Remove Swapfile" "Disable and delete $SWAP_FILE?\n\nRemoves fstab entry and deletes the file." || return

    sudo swapoff "$SWAP_FILE" 2>/dev/null || true
    _swap_safe_write_fstab ""
    sudo rm -f "$SWAP_FILE"
    _msg "Swap" "Swapfile removed and fstab entry cleaned." 8 60
}

_swap_set_swappiness() {
    local cur val
    cur=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 60)
    val=$(_inputbox "Swappiness" "Current value: $cur\nEnter new value (0-100):" 10 60 "$cur")
    [ -z "$val" ] && return
    [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -le 100 ] || {
        _msg "Error" "Value must be 0-100." 8 40
        return
    }

    local tmp
    tmp=$(mktemp) || return
    printf 'vm.swappiness=%s\n' "$val" > "$tmp"
    sudo install -o root -g root -m 0644 "$tmp" "$SWAP_CONF"
    sudo sysctl -w "vm.swappiness=$val" >/dev/null
    rm -f "$tmp"
    _msg "Swappiness" "swappiness set to $val (persistent)." 8 60
}

# ── Entry point ──

manage_swap() {
    exec 9>"$SWAP_LOCK"
    flock -n 9 || {
        _msg "Busy" "Another swap operation is already running." 8 55
        return
    }

    while true; do
        local choice
        choice=$(_menu "Swap Management (disk)" \
            "Select an option:" $TUI_ALTO $TUI_ANCHO 6 \
            "1" "Show current swap & swappiness" \
            "2" "Create / resize swapfile" \
            "3" "Remove swapfile" \
            "4" "Change swappiness" \
            "5" "Back to main menu")

        [ -z "$choice" ] && break
        clear

        case "$choice" in
            1) _swap_current_status ;;
            2) _swap_create_file ;;
            3) _swap_remove_file ;;
            4) _swap_set_swappiness ;;
            5) break ;;
        esac
    done

    exec 9>&-
}
