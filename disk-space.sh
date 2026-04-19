#!/bin/bash
# disk-space.sh — Mostra espaco disponivel nos discos com identificacao de tipo (SSD/NVMe/HDD) (Linux)
# Uso: ./disk-space.sh [opcoes]
# Opcoes:
#   --all|-a         Inclui pseudo-filesystems e loop devices
#   --help|-h        Mostra esta ajuda
#   --version|-V     Mostra versao

set -euo pipefail

readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "lsblk" "$INSTALLER" "util-linux"
fi



EXCLUDE_FS="tmpfs devtmpfs squashfs overlay proc sysfs cgroup cgroup2 debugfs securityfs devpts mqueue hugetlbfs pstore binfmt_misc configfs fusectl tracefs efivarfs fuse.gvfsd-fuse fusectl autofs rpc_pipefs ramfs bpf nsfs"
REAL_FS="ext2,ext3,ext4,vfat,fat,ntfs,fuseblk,btrfs,xfs,zfs,f2fs,jfs,reiserfs"

SHOW_ALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all|-a) SHOW_ALL=true; shift ;;
        --help|-h)
            echo ""
            echo "  disk-space.sh — Mostra espaco disponivel nos discos (SSD/NVMe/HDD)"
            echo ""
            echo "  Uso: ./disk-space.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all|-a       Inclui pseudo-filesystems e loop devices"
            echo "    --help|-h      Mostra esta ajuda"
            echo "    --version|-V   Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./disk-space.sh"
            echo "    ./disk-space.sh --all"
            echo ""
            exit 0
            ;;
        --version|-V) echo "disk-space.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
    esac
done

is_excluded_fstype() {
    local fs="$1"
    local ex
    for ex in $EXCLUDE_FS; do
        [[ "$fs" == "$ex" ]] && return 0
    done
    return 1
}

declare -A DISK_TYPE_CACHE

get_disk_type() {
    local part_name="$1"
    part_name="${part_name#/dev/}"

    if [[ -n "${DISK_TYPE_CACHE[$part_name]+_}" ]]; then
        echo "${DISK_TYPE_CACHE[$part_name]}"
        return
    fi

    local parent
    parent=$(lsblk -n -o PKNAME "/dev/$part_name" 2>/dev/null | head -1 | tr -d '[:space:]')

    if [[ -z "$parent" ]]; then
        local blk_type
        blk_type=$(lsblk -d -n -o TYPE "/dev/$part_name" 2>/dev/null | head -1 | tr -d '[:space:]')
        if [[ "$blk_type" == "loop" ]]; then
            DISK_TYPE_CACHE["$part_name"]="Loop"
            echo "Loop"
            return
        fi
        DISK_TYPE_CACHE["$part_name"]="Desconhecido"
        echo "Desconhecido"
        return
    fi

    local tran rota
    tran=$(lsblk -d -n -o TRAN "/dev/$parent" 2>/dev/null | head -1 | tr -d '[:space:]')
    rota=$(lsblk -d -n -o ROTA "/dev/$parent" 2>/dev/null | head -1 | tr -d '[:space:]')

    local dtype="Desconhecido"
    if [[ "$parent" == nvme* ]] || [[ "$tran" == "nvme" ]]; then
        dtype="NVMe"
    elif [[ "$tran" == "usb" ]]; then
        dtype="USB"
    elif [[ "$rota" == "0" ]]; then
        dtype="SSD"
    elif [[ "$rota" == "1" ]]; then
        dtype="HDD"
    fi

    DISK_TYPE_CACHE["$part_name"]="$dtype"
    echo "$dtype"
}

human_size() {
    local bytes="$1"
    if ! [[ "$bytes" =~ ^[0-9]+$ ]] || [[ "$bytes" -eq 0 ]]; then
        echo "--"
        return
    fi
    if [[ "$bytes" -ge 1125899906842624 ]]; then
        echo "$(echo "scale=1; $bytes / 1125899906842624" | bc) PB"
    elif [[ "$bytes" -ge 1099511627776 ]]; then
        echo "$(echo "scale=1; $bytes / 1099511627776" | bc) TB"
    elif [[ "$bytes" -ge 1073741824 ]]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [[ "$bytes" -ge 1048576 ]]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [[ "$bytes" -ge 1024 ]]; then
        echo "$(echo "scale=1; $bytes / 1024" | bc) KB"
    else
        echo "${bytes} B"
    fi
}

colorize_pct() {
    local pct="$1"
    pct="${pct%\%}"
    pct="${pct%%.*}"
    if ! [[ "$pct" =~ ^[0-9]+$ ]]; then
        echo -e "${DIM}--${RESET}"
        return
    fi
    if [[ "$pct" -ge 90 ]]; then
        echo -e "${RED}${pct}%${RESET}"
    elif [[ "$pct" -ge 70 ]]; then
        echo -e "${YELLOW}${pct}%${RESET}"
    else
        echo -e "${GREEN}${pct}%${RESET}"
    fi
}

format_bar() {
    local pct="$1"
    pct="${pct%\%}"
    pct="${pct%%.*}"
    if ! [[ "$pct" =~ ^[0-9]+$ ]]; then
        local bar=""
        for ((i=0; i<12; i++)); do bar+="░"; done
        echo -e "${DIM}${bar}${RESET}"
        return
    fi
    local width=12
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    if [[ "$pct" -ge 90 ]]; then
        echo -e "${RED}${bar}${RESET}"
    elif [[ "$pct" -ge 70 ]]; then
        echo -e "${YELLOW}${bar}${RESET}"
    else
        echo -e "${GREEN}${bar}${RESET}"
    fi
}

collect_mount_data_json() {
    local json_data
    if $SHOW_ALL; then
        json_data=$(findmnt -b -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL,USE% -J 2>/dev/null)
    else
        json_data=$(findmnt -b -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL,USE% -J -t "$REAL_FS" 2>/dev/null)
        if [[ -z "$json_data" ]]; then
            json_data=$(findmnt -b -o SOURCE,TARGET,FSTYPE,SIZE,USED,AVAIL,USE% -J 2>/dev/null)
        fi
    fi

    if [[ -n "$json_data" ]]; then
        echo "$json_data" | jq -r '.. | objects | select(.source) | [.source, .target, .fstype, (.size // "-"), (.used // "-"), (.avail // "-"), (."use%" // "-")] | join("|")'
    fi
}

collect_mount_data_df() {
    if $SHOW_ALL; then
        df -h --output=source,target,fstype,size,used,avail,pcent 2>/dev/null | tail -n +2
    else
        df -h --output=source,target,fstype,size,used,avail,pcent \
            -x tmpfs -x devtmpfs -x squashfs -x overlay -x proc -x sysfs \
            -x cgroup -x cgroup2 -x debugfs -x securityfs -x devpts \
            -x mqueue -x hugetlbfs -x pstore -x binfmt_misc -x configfs \
            -x fusectl -x tracefs -x efivarfs -x fuse.gvfsd-fuse -x fusectl \
            -x autofs -x ramfs -x bpf -x nsfs 2>/dev/null
    fi
}

echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD} Espaco nos Discos${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

printf "  ${BOLD}%-4s %-13s %-7s %-10s %-10s %-10s %-5s %-12s  %s${RESET}\n" \
    "TIPO" "DISPOSITIVO" "FS" "TOTAL" "USADO" "LIVRE" "USO%" "BARRA" "MONTAGEM"
echo -e "  ${DIM}──────────────────────────────────────────────────────────────────────────────────${RESET}"

USE_JQ=false
if command -v jq &>/dev/null && command -v findmnt &>/dev/null; then
    USE_JQ=true
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if $USE_JQ; then
    collect_mount_data_json > "$TMPFILE"
else
    collect_mount_data_df > "$TMPFILE"
fi

count=0

if $USE_JQ; then
    while IFS='|' read -r device mount fstype size_bytes used_bytes avail_bytes pct; do
        device=$(echo "$device" | xargs)
        mount=$(echo "$mount" | xargs)
        fstype=$(echo "$fstype" | xargs)
        size_bytes=$(echo "$size_bytes" | xargs)
        used_bytes=$(echo "$used_bytes" | xargs)
        avail_bytes=$(echo "$avail_bytes" | xargs)
        pct=$(echo "$pct" | xargs)

        [[ -z "$device" || "$device" == "none" || "$device" == "-" ]] && continue

        if ! $SHOW_ALL; then
            if is_excluded_fstype "$fstype"; then
                continue
            fi
            if [[ "$device" == /dev/loop* ]]; then
                continue
            fi
        fi

        dev_name="${device#/dev/}"
        disk_type=$(get_disk_type "$dev_name")

        type_icon=""
        case "$disk_type" in
            NVMe) type_icon="${CYAN}⚡${RESET}" ;;
            SSD)  type_icon="${GREEN}∎${RESET}" ;;
            HDD)  type_icon="${YELLOW}◎${RESET}" ;;
            USB)  type_icon="${BLUE}↗${RESET}" ;;
            Loop) type_icon="${DIM}◎${RESET}" ;;
            *)    type_icon="${DIM}?${RESET}" ;;
        esac

        total_h=$(human_size "$size_bytes")
        used_h=$(human_size "$used_bytes")
        avail_h=$(human_size "$avail_bytes")
        if [[ "$pct" =~ ^[0-9]+%$ ]]; then
            pct_plain="$pct"
        else
            pct_plain="--"
        fi
        bar=$(format_bar "$pct")

        display_mount="$mount"
        display_mount="${display_mount//$HOME/~}"

        printf "  %b  %-13s %-7s %-10s %-10s %-10s %-5s %b  %s\n" \
            "$type_icon" "$dev_name" "$fstype" "$total_h" "$used_h" "$avail_h" "$pct_plain" "$bar" "$display_mount"

        count=$((count + 1))
    done < "$TMPFILE"
else
    while IFS= read -r line; do
        device=$(echo "$line" | awk '{print $1}')
        mount=$(echo "$line" | awk '{print $2}')
        fstype=$(echo "$line" | awk '{print $3}')
        total=$(echo "$line" | awk '{print $4}')
        used=$(echo "$line" | awk '{print $5}')
        avail=$(echo "$line" | awk '{print $6}')
        pct=$(echo "$line" | awk '{print $7}')

        [[ -z "$device" || "$device" == "none" || "$device" == "Filesystem" ]] && continue
        [[ "$device" =~ ^[a-z] ]] && continue

        if ! $SHOW_ALL; then
            if is_excluded_fstype "$fstype"; then
                continue
            fi
            if [[ "$device" == /dev/loop* ]]; then
                continue
            fi
        fi

        dev_name="${device#/dev/}"
        disk_type=$(get_disk_type "$dev_name")

        type_icon=""
        case "$disk_type" in
            NVMe) type_icon="${CYAN}⚡${RESET}" ;;
            SSD)  type_icon="${GREEN}∎${RESET}" ;;
            HDD)  type_icon="${YELLOW}◎${RESET}" ;;
            USB)  type_icon="${BLUE}↗${RESET}" ;;
            Loop) type_icon="${DIM}◎${RESET}" ;;
            *)    type_icon="${DIM}?${RESET}" ;;
        esac

        if [[ "$pct" =~ ^[0-9]+%$ ]]; then
            pct_plain="$pct"
        else
            pct_plain="--"
        fi
        bar=$(format_bar "$pct")

        display_mount="$mount"
        display_mount="${display_mount//$HOME/~}"

        printf "  %b  %-13s %-7s %-10s %-10s %-10s %-5s %b  %s\n" \
            "$type_icon" "$dev_name" "$fstype" "$total" "$used" "$avail" "$pct_plain" "$bar" "$display_mount"

        count=$((count + 1))
    done < "$TMPFILE"
fi

if [[ $count -eq 0 ]]; then
    echo -e "  ${DIM}Nenhum disco montado encontrado.${RESET}"
fi

echo ""
