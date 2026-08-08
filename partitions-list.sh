#!/bin/bash
# partitions-list.sh — Lista todas as particoes (montadas ou nao) com tipo de disco (Linux)
# Uso: ./partitions-list.sh [opcoes]
# Opcoes:
#   --all|-a        Inclui loop devices, zram, crypt e swap
#   --json|-j       Saida em formato JSON
#   --uuid|-u       Mostra coluna UUID
#   --label|-l      Mostra coluna LABEL do filesystem
#   --help|-h       Mostra esta ajuda
#   --version|-V    Mostra versao

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
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "lsblk" "$INSTALLER" "util-linux"
fi

EXCLUDE_FS="tmpfs devtmpfs squashfs overlay proc sysfs cgroup cgroup2 debugfs securityfs devpts mqueue hugetlbfs pstore binfmt_misc configfs fusectl tracefs efivarfs fuse.gvsd-fuse fusectl autofs rpc_pipefs ramfs bpf nsfs"

SHOW_ALL=false
SHOW_UUID=false
SHOW_LABEL=false
JSON_OUTPUT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all|-a) SHOW_ALL=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --uuid|-u) SHOW_UUID=true; shift ;;
        --label|-l) SHOW_LABEL=true; shift ;;
        --help|-h)
            echo ""
            echo "  partitions-list.sh — Lista todas as particoes (montadas ou nao)"
            echo ""
            echo "  Uso: ./partitions-list.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all|-a       Inclui loop devices, zram, crypt e swap"
            echo "    --json|-j      Saida em formato JSON"
            echo "    --uuid|-u      Mostra coluna UUID"
            echo "    --label|-l     Mostra coluna LABEL do filesystem"
            echo "    --help|-h      Mostra esta ajuda"
            echo "    --version|-V   Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./partitions-list.sh"
            echo "    ./partitions-list.sh --all"
            echo "    ./partitions-list.sh --uuid --label"
            echo "    ./partitions-list.sh --json"
            echo ""
            exit 0
            ;;
        --version|-V) echo "partitions-list.sh $VERSION"; exit 0 ;;
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

collect_partitions_json() {
    local json_data
    json_data=$(lsblk -b -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,PARTTYPENAME,LABEL,UUID,PKNAME,RO -J 2>/dev/null)
    if [[ -n "$json_data" ]]; then
        echo "$json_data" | jq -r '.. | objects | select(.name) | [.name, (.fstype // "-"), (.size // "-"), (.type // "-"), (.mountpoint // "-"), (.parttypename // "-"), (.label // "-"), (.uuid // "-"), (.pkname // "-"), (.ro // "-")] | join("|")'
    fi
}

collect_partitions_text() {
    lsblk -b -o NAME,FSTYPE,SIZE,TYPE,MOUNTPOINT,PARTTYPENAME,LABEL,UUID,PKNAME,RO -n 2>/dev/null
}

should_include_type() {
    local blk_type="$1"
    local fstype="$2"
    if $SHOW_ALL; then
        case "$blk_type" in
            part|crypt|swap|loop|zram) return 0 ;;
            *) return 1 ;;
        esac
    else
        [[ "$blk_type" == "part" ]] || return 1
        [[ "$fstype" == "swap" ]] && return 1
        return 0
    fi
}

declare -A MOUNT_PERM_CACHE

get_mount_perm() {
    local mountpoint="$1"
    local ro_flag="$2"
    local perm

    if [[ -n "$mountpoint" && "$mountpoint" != "-" ]]; then
        if [[ -n "${MOUNT_PERM_CACHE[$mountpoint]+_}" ]]; then
            echo "${MOUNT_PERM_CACHE[$mountpoint]}"
            return
        fi
        local opts
        opts=$(findmnt -n -o OPTIONS "$mountpoint" 2>/dev/null | head -1)
        if [[ -n "$opts" ]]; then
            if echo "$opts" | grep -q '^ro'; then
                perm="ro"
            elif echo "$opts" | grep -q ',ro'; then
                perm="ro"
            else
                perm="rw"
            fi
        else
            if [[ "$ro_flag" == "1" ]]; then
                perm="ro"
            else
                perm="rw"
            fi
        fi
        MOUNT_PERM_CACHE["$mountpoint"]="$perm"
        echo "$perm"
    else
        if [[ "$ro_flag" == "1" ]]; then
            echo "ro"
        else
            echo "rw"
        fi
    fi
}

emit_json_entry() {
    local dev="$1" fstype="$2" size_bytes="$3" mountpoint="$4" parttype="$5" label="$6" uuid="$7" dtype="$8" perm="$9"
    local size_h mounted
    size_h=$(human_size "$size_bytes")
    if [[ -n "$mountpoint" && "$mountpoint" != "-" ]]; then
        mounted="true"
    else
        mounted="false"
        mountpoint=""
    fi
    fstype="${fstype:-}"
    parttype="${parttype:-}"
    label="${label:-}"
    uuid="${uuid:-}"
    perm="${perm:-rw}"
    printf '    {"device":"%s","fstype":"%s","size":%s,"size_h":"%s","mounted":%s,"mountpoint":"%s","parttype":"%s","disk_type":"%s","label":"%s","uuid":"%s","perm":"%s"}\n' \
        "$dev" "$fstype" "${size_bytes:-0}" "$size_h" "$mounted" "$mountpoint" "$parttype" "$dtype" "$label" "$uuid" "$perm"
}

print_table_row() {
    local dev="$1" fstype="$2" size_h="$3" mountpoint="$4" parttype="$5" label="$6" uuid="$7" dtype="$8" perm="$9"
    local type_icon state_icon display_mount

    case "$dtype" in
        NVMe) type_icon="${CYAN}⚡${RESET}  " ;;
        SSD)  type_icon="${GREEN}∎${RESET}   " ;;
        HDD)  type_icon="${YELLOW}◎${RESET}   " ;;
        USB)  type_icon="${BLUE}↗${RESET}   " ;;
        Loop) type_icon="${DIM}◎${RESET}   " ;;
        *)    type_icon="${DIM}?${RESET}   " ;;
    esac

    if [[ -n "$mountpoint" && "$mountpoint" != "-" ]]; then
        state_icon="${GREEN}●${RESET}"
        display_mount="$mountpoint"
        display_mount="${display_mount//$HOME/~}"
        mount_text="$display_mount"
        mount_prefix=""
        mount_suffix=""
    else
        state_icon="${DIM}○${RESET}"
        mount_text="nao montada"
        mount_prefix="${DIM}"
        mount_suffix="${RESET}"
    fi

    local mount_padded
    mount_padded=$(printf '%-18s' "$mount_text")

    local fstype_color="$DIM"
    local fstype_text="--"
    if [[ -n "$fstype" && "$fstype" != "-" ]]; then
        fstype_color="$CYAN"
        fstype_text="$fstype"
    fi

    local parttype_text="--"
    [[ -n "$parttype" && "$parttype" != "-" ]] && parttype_text="$parttype"

    local uuid_text="--"
    [[ -n "$uuid" && "$uuid" != "-" ]] && uuid_text="$uuid"

    local label_text="--"
    [[ -n "$label" && "$label" != "-" ]] && label_text="$label"

    local perm_color="$GREEN"
    [[ "$perm" == "ro" ]] && perm_color="$RED"

    printf "  %b%-14s %b%-8s %-10s %b  %b%s%b  %b%-4s%b %s" \
        "$type_icon" "$dev" "$fstype_color" "$fstype_text" "$size_h" "$state_icon" \
        "$mount_prefix" "$mount_padded" "$mount_suffix" \
        "$perm_color" "$perm" "$RESET" "$parttype_text"
    if $SHOW_LABEL; then
        printf "  ${CYAN}%-12s${RESET}" "$label_text"
    fi
    if $SHOW_UUID; then
        printf "  ${DIM}%s${RESET}" "$uuid_text"
    fi
    printf "\n"
}

print_header() {
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD} Particoes dos Discos${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    local header="  ${BOLD}%-4s%-14s %-8s %-10s %-3s %-18s %-4s %s${RESET}"
    local args=("TIPO" "DISPOSITIVO" "FS" "TAMANHO" "EST" "MONTAGEM" "PERM" "PARTICAO")
    if $SHOW_LABEL; then
        header="$header  %-12s"
        args+=("LABEL")
    fi
    if $SHOW_UUID; then
        header="$header  %s"
        args+=("UUID")
    fi
    printf "$header\n" "${args[@]}"
    echo -e "  ${DIM}──────────────────────────────────────────────────────────────────────────────────${RESET}"
}

USE_JQ=false
if command -v jq &>/dev/null && command -v lsblk &>/dev/null; then
    USE_JQ=true
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

if $USE_JQ; then
    collect_partitions_json > "$TMPFILE"
else
    collect_partitions_text > "$TMPFILE"
fi

count=0
mounted_count=0
unmounted_count=0
ro_count=0

if $JSON_OUTPUT; then
    echo "["
    local_first=true
else
    print_header
fi

if $USE_JQ; then
    while IFS='|' read -r dev fstype size_bytes blk_type mountpoint parttype label uuid pkname ro_flag; do
        dev=$(echo "$dev" | xargs)
        fstype=$(echo "$fstype" | xargs)
        size_bytes=$(echo "$size_bytes" | xargs)
        blk_type=$(echo "$blk_type" | xargs)
        mountpoint=$(echo "$mountpoint" | xargs)
        parttype=$(echo "$parttype" | xargs)
        label=$(echo "$label" | xargs)
        uuid=$(echo "$uuid" | xargs)
        pkname=$(echo "$pkname" | xargs)
        ro_flag=$(echo "$ro_flag" | xargs)

        [[ -z "$dev" || "$dev" == "-" ]] && continue

        if ! should_include_type "$blk_type" "$fstype"; then
            continue
        fi

        if ! $SHOW_ALL; then
            if is_excluded_fstype "$fstype"; then
                continue
            fi
        fi

        dtype=$(get_disk_type "$dev")
        perm=$(get_mount_perm "$mountpoint" "$ro_flag")

        if $JSON_OUTPUT; then
            if $local_first; then
                emit_json_entry "$dev" "$fstype" "$size_bytes" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm"
                local_first=false
            else
                emit_json_entry "$dev" "$fstype" "$size_bytes" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm" | sed 's/^    /   ,/'
            fi
            count=$((count + 1))
            continue
        fi

        size_h=$(human_size "$size_bytes")

        print_table_row "$dev" "$fstype" "$size_h" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm"

        if [[ -n "$mountpoint" && "$mountpoint" != "-" ]]; then
            mounted_count=$((mounted_count + 1))
        else
            unmounted_count=$((unmounted_count + 1))
        fi
        [[ "$perm" == "ro" ]] && ro_count=$((ro_count + 1))
        count=$((count + 1))
    done < "$TMPFILE"
else
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        dev=$(echo "$line" | awk '{print $1}')
        fstype=$(echo "$line" | awk '{print $2}')
        size_bytes=$(echo "$line" | awk '{print $3}')
        blk_type=$(echo "$line" | awk '{print $4}')
        mountpoint=$(echo "$line" | awk '{print $5}')
        parttype=$(echo "$line" | awk '{print $6}')
        label=$(echo "$line" | awk '{print $7}')
        uuid=$(echo "$line" | awk '{print $8}')
        pkname=$(echo "$line" | awk '{print $9}')
        ro_flag=$(echo "$line" | awk '{print $10}')

        [[ -z "$dev" || "$dev" == "-" ]] && continue

        if ! should_include_type "$blk_type" "$fstype"; then
            continue
        fi

        if ! $SHOW_ALL; then
            if is_excluded_fstype "$fstype"; then
                continue
            fi
        fi

        dtype=$(get_disk_type "$dev")
        perm=$(get_mount_perm "$mountpoint" "$ro_flag")

        if $JSON_OUTPUT; then
            if $local_first; then
                emit_json_entry "$dev" "$fstype" "$size_bytes" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm"
                local_first=false
            else
                emit_json_entry "$dev" "$fstype" "$size_bytes" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm" | sed 's/^    /   ,/'
            fi
            count=$((count + 1))
            continue
        fi

        size_h=$(human_size "$size_bytes")

        print_table_row "$dev" "$fstype" "$size_h" "$mountpoint" "$parttype" "$label" "$uuid" "$dtype" "$perm"

        if [[ -n "$mountpoint" && "$mountpoint" != "-" ]]; then
            mounted_count=$((mounted_count + 1))
        else
            unmounted_count=$((unmounted_count + 1))
        fi
        [[ "$perm" == "ro" ]] && ro_count=$((ro_count + 1))
        count=$((count + 1))
    done < "$TMPFILE"
fi

if $JSON_OUTPUT; then
    echo "]"
    rm -f "$TMPFILE"
    exit 0
fi

if [[ $count -eq 0 ]]; then
    echo -e "  ${DIM}Nenhuma particao encontrada.${RESET}"
fi

echo ""
echo -e "  ${DIM}─────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  ${GREEN}●${RESET} Montadas:      ${GREEN}${BOLD}${mounted_count}${RESET}"
echo -e "  ${DIM}○${RESET} Nao montadas:  ${DIM}${BOLD}${unmounted_count}${RESET}"
echo -e "  ${RED}RO${RESET} Read-only:    ${RED}${BOLD}${ro_count}${RESET}"
echo -e "  ${BOLD}Total:${RESET}          ${BOLD}${count}${RESET} particoes"
echo -e "  ${DIM}─────────────────────────────────────────${RESET}"
echo ""