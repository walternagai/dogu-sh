#!/bin/bash
# disk-health.sh — Verifica saude SMART do disco e alerta problemas (Linux)
# Usage: ./disk-health.sh [options]
# Options:
#   --all           Show all SMART attributes (verbose)
#   --json          Output in JSON format
#   --watch N       Recheck every N seconds
#   --notify        Desktop notification on critical issues
#   --help          Show this help
#   --version       Show version

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "smartctl" "$INSTALLER" "smartmontools"; fi




VERBOSE=false
JSON_OUTPUT=false
WATCH_INTERVAL=0
USE_NOTIFY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all|-a) VERBOSE=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --watch|-w)
            [[ -z "${2-}" ]] && { echo "Flag --watch requer um valor" >&2; exit 1; }
            WATCH_INTERVAL="${2:-300}"; shift 2 ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --help|-h)
            echo ""
            echo "  disk-health.sh — Check disk SMART health and alert on issues"
            echo ""
            echo "  Usage: ./disk-health.sh [options]"
            echo ""
            echo "  Options:"
            echo "    --all           Show all SMART attributes (verbose)"
            echo "    --json          Output in JSON format"
            echo "    --watch N       Recheck every N seconds"
            echo "    --notify        Desktop notification on critical issues"
            echo "    --help          Show this help"
            echo "    --version       Show version"
            echo ""
            echo "  Requires: smartmontools (smartctl)"
            echo "    sudo apt install smartmontools"
            echo "    sudo dnf install smartmontools"
            echo "    sudo pacman -S smartmontools"
            echo ""
            echo "  Examples:"
            echo "    ./disk-health.sh"
            echo "    ./disk-health.sh --all"
            echo "    ./disk-health.sh --watch 300 --notify"
            echo ""
            exit 0
            ;;
        --version|-V) echo "disk-health.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

send_notify() {
    local title="$1"
    local body="$2"
    local urgency="${3:-critical}"
    if $USE_NOTIFY && command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" "$title" "$body" 2>/dev/null || true
    fi
}

check_smartctl_access() {
    if ! command -v smartctl &>/dev/null; then
        echo -e "  ${RED}Error: smartctl not found.${RESET}" >&2
        echo -e "  ${DIM}Install: sudo apt install smartmontools${RESET}" >&2
        exit 1
    fi
    local test_disk
    test_disk=$(smartctl --scan 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$test_disk" ] && ! smartctl -i "$test_disk" &>/dev/null; then
        echo -e "  ${RED}Error: smartctl requires root privileges to read disk data.${RESET}" >&2
        echo -e "  ${DIM}Try: sudo ./disk-health.sh${RESET}" >&2
        exit 1
    fi
}

human_size() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "?"; return; fi
    if [ "$bytes" -ge 1000000000000 ]; then echo "$(echo "scale=1; $bytes / 1000000000000" | bc) TB"
    elif [ "$bytes" -ge 1000000000 ]; then echo "$(echo "scale=1; $bytes / 1000000000" | bc) GB"
    elif [ "$bytes" -ge 1000000 ]; then echo "$(echo "scale=1; $bytes / 1000000" | bc) MB"
    else echo "$((bytes / 1000)) KB"
    fi
}

CRITICAL_ATTRS="5,10,11,196,197,198,201"
WARNING_ATTRS="1,3,4,7,9,12,192,193,194,196,197,198,199,200,201,220"

CRITICAL_MAP[5]="Reallocated Sectors"
CRITICAL_MAP[10]="Spin Retry Count"
CRITICAL_MAP[11]="Calibration Retry Count"
CRITICAL_MAP[196]="Reallocation Event Count"
CRITICAL_MAP[197]="Current Pending Sector"
CRITICAL_MAP[198]="Offline Uncorrectable"
CRITICAL_MAP[201]="Soft Read Error Rate"

WARN_MAP[1]="Read Error Rate"
WARN_MAP[3]="Spin-Up Time"
WARN_MAP[4]="Start/Stop Count"
WARN_MAP[7]="Seek Error Rate"
WARN_MAP[9]="Power-On Hours"
WARN_MAP[12]="Power Cycle Count"
WARN_MAP[192]="Emergency Retract"
WARN_MAP[193]="Load/Unload Count"
WARN_MAP[194]="Temperature"
WARN_MAP[199]="UDMA CRC Error Count"
WARN_MAP[200]="Multi-Zone Error Rate"
WARN_MAP[220]="Disk Shift"

total_disks=0
healthy_disks=0
warning_disks=0
critical_disks=0
unknown_disks=0

scan_disks() {
    local disks=""
    if [ -d /dev/disk/by-id/ ]; then
        for link in /dev/disk/by-id/*; do
            local target
            target=$(readlink -f "$link" 2>/dev/null)
            case "$target" in
                /dev/nvme[0-9]*n[0-9]*)
                    [[ "$target" =~ /nvme[0-9]+n[0-9]+$ ]] && basename "$target"
                    ;;
                /dev/sd[a-z])
                    basename "$target"
                    ;;
                /dev/hd[a-z])
                    basename "$target"
                    ;;
            esac
        done | sort -u
    else
        ls /dev/sd? /dev/nvme?n? 2>/dev/null | while read -r d; do basename "$d"; done | sort -u
    fi
}

check_disk() {
    local disk="$1"
    local device="/dev/$disk"

    if [ ! -e "$device" ]; then
        return
    fi

    total_disks=$((total_disks + 1))

    local info
    info=$(smartctl -i "$device" 2>/dev/null) || true

    local model family serial capacity rotation temp
    model=$(echo "$info" | grep -i "Device Model:" | sed 's/.*: *//' | head -1)
    if [ -z "$model" ]; then
        model=$(echo "$info" | grep -i "Model Number:" | sed 's/.*: *//' | head -1)
    fi
    family=$(echo "$info" | grep -i "Model Family:" | sed 's/.*: *//' | head -1)
    serial=$(echo "$info" | grep -i "Serial Number:" | sed 's/.*: *//' | head -1)
    capacity=$(echo "$info" | grep -i "User Capacity:" | sed 's/.*: *//' | head -1 | cut -d'[' -f1 | tr -d ' ')
    rotation=$(echo "$info" | grep -i "Rotation Rate:" | sed 's/.*: *//' | head -1)

    if [ -z "$model" ]; then
        model="$disk"
    fi

    local smart_supported smart_enabled
    smart_supported=$(echo "$info" | grep -i "SMART support is:" | head -1 | grep -qi "available\|yes" && echo "yes" || echo "no")
    smart_enabled=$(echo "$info" | grep -i "SMART support is:" | tail -1 | grep -qi "enabled" && echo "yes" || echo "no")

    local overall_status
    overall_status=$(smartctl -H "$device" 2>/dev/null | grep -i "SMART overall-health" | grep -qi "PASSED\|OK" && echo "PASSED" || echo "")

    if [ -z "$overall_status" ]; then
        overall_status=$(smartctl -H "$device" 2>/dev/null | grep -i "SMART Health Status:" | sed 's/.*: *//') || true
    fi

    local disk_status="unknown"
    local status_icon="${DIM}?${RESET}"
    local disk_issues=""

    if [ "$smart_supported" = "no" ]; then
        disk_status="unsupported"
        status_icon="${DIM}○${RESET}"
        unknown_disks=$((unknown_disks + 1))
    elif [ "$smart_enabled" = "no" ]; then
        disk_status="disabled"
        status_icon="${YELLOW}⚠${RESET}"
        warning_disks=$((warning_disks + 1))
        disk_issues="SMART not enabled"
    elif [ "$overall_status" = "PASSED" ]; then
        disk_status="healthy"
        status_icon="${GREEN}✓${RESET}"
        healthy_disks=$((healthy_disks + 1))
    else
        case "$overall_status" in
            *FAIL*|*DEGRADED*|*CRITICAL*)
                disk_status="critical"
                status_icon="${RED}✗${RESET}"
                critical_disks=$((critical_disks + 1))
                disk_issues="$overall_status"
                send_notify "Disk Health CRITICAL: $model" "$overall_status on /dev/$disk" "critical"
                ;;
        --) shift; break ;;
            *)
                disk_status="unknown"
                status_icon="${YELLOW}?${RESET}"
                warning_disks=$((warning_disks + 1))
                disk_issues="${overall_status:-status unknown}"
                ;;
        esac
    fi

    local attrs
    attrs=$(smartctl -A "$device" 2>/dev/null) || true

    local attr_issues=""

    while IFS= read -r line; do
        local attr_id attr_name attr_value attr_worst attr_thresh attr_raw
        attr_id=$(echo "$line" | awk '{print $1}')
        attr_name=$(echo "$line" | awk '{print $2}')
        attr_value=$(echo "$line" | awk '{print $4}')
        attr_thresh=$(echo "$line" | awk '{print $6}')
        attr_raw=$(echo "$line" | awk '{print $10}')

        [[ "$attr_id" =~ ^[0-9]+$ ]] || continue

        if echo "$CRITICAL_ATTRS" | grep -qw "$attr_id"; then
            if [ "$attr_raw" -gt 0 ] 2>/dev/null; then
                local label="${CRITICAL_MAP[$attr_id]:-$attr_name}"
                attr_issues="${attr_issues}    ${RED}CRIT${RESET} ID $attr_id ($label): raw=$attr_raw\n"
                if [ "$disk_status" != "critical" ]; then
                    disk_status="critical"
                    critical_disks=$((critical_disks + 1))
                    healthy_disks=$((healthy_disks - 1))
                fi
                disk_issues="${label}=${attr_raw}"
                send_notify "Disk CRITICAL: $model" "Attribute $attr_id ($label) = $attr_raw" "critical"
            fi
        elif echo "$WARNING_ATTRS" | grep -qw "$attr_id"; then
            if [ -n "$attr_thresh" ] && [[ "$attr_thresh" =~ ^[0-9]+$ ]] && [ "$attr_thresh" -gt 0 ]; then
                if [ "$attr_value" -le "$attr_thresh" ] 2>/dev/null && [ "$attr_value" -lt 255 ]; then
                    local label="${WARN_MAP[$attr_id]:-$attr_name}"
                    attr_issues="${attr_issues}    ${YELLOW}WARN${RESET} ID $attr_id ($label): value=$attr_value thresh=$attr_thresh\n"
                    if [ "$disk_status" = "healthy" ]; then
                        disk_status="warning"
                        healthy_disks=$((healthy_disks - 1))
                        warning_disks=$((warning_disks + 1))
                    fi
                fi
            fi
        fi
    done <<< "$attrs"

    if $JSON_OUTPUT; then
        local json_status
        case "$disk_status" in
            healthy) json_status="healthy" ;;
            critical) json_status="critical" ;;
            warning) json_status="warning" ;;
            disabled) json_status="disabled" ;;
        --) shift; break ;;
            *) json_status="unknown" ;;
        esac
        echo "  {\"disk\":\"$disk\",\"model\":\"$model\",\"serial\":\"$serial\",\"capacity\":\"$capacity\",\"status\":\"$json_status\",\"issues\":\"$disk_issues\"},"
        return
    fi

    echo -e "  $status_icon ${BOLD}$model${RESET}  ${DIM}($device)${RESET}"
    echo -e "    Capacity:  ${CYAN}$capacity${RESET}"
    if [ -n "$family" ]; then
        echo -e "    Family:    ${DIM}$family${RESET}"
    fi
    if [ -n "$serial" ]; then
        echo -e "    Serial:    ${DIM}$serial${RESET}"
    fi
    if [ -n "$rotation" ]; then
        echo -e "    Rotation:  ${DIM}$rotation${RESET}"
    fi
    echo -e "    SMART:     ${DIM}supported=$smart_supported enabled=$smart_enabled${RESET}"
    echo -e "    Health:    $(case "$disk_status" in
        healthy) echo "${GREEN}PASSED${RESET}" ;;
        critical) echo "${RED}$overall_status${RESET}" ;;
        warning) echo "${YELLOW}$disk_issues${RESET}" ;;
        disabled) echo "${YELLOW}DISABLED${RESET}" ;;
        --) shift; break ;;
        *) echo "${DIM}$disk_issues${RESET}" ;;
    esac)"

    if [ -n "$attr_issues" ]; then
        echo ""
        echo -e "    ${BOLD}Problematic attributes:${RESET}"
        echo -e "$attr_issues"
    fi

    if $VERBOSE; then
        local temp_attr
        temp_attr=$(echo "$attrs" | awk '/^194/ {print $10}')
        if [ -n "$temp_attr" ]; then
            echo -e "    Temp:      ${CYAN}${temp_attr}°C${RESET}"
        fi

        local power_hours
        power_hours=$(echo "$attrs" | awk '/^9/ {print $10}')
        if [ -n "$power_hours" ]; then
            local power_years
            power_years=$(echo "scale=1; $power_hours / 8766" | bc 2>/dev/null || echo "?")
            echo -e "    Power-On:  ${CYAN}${power_hours}h${RESET} ${DIM}(~${power_years} years)${RESET}"
        fi

        local reallocated
        reallocated=$(echo "$attrs" | awk '/^5/ {print $10}')
        if [ -n "$reallocated" ]; then
            local color="$DIM"
            if [ "$reallocated" -gt 0 ] 2>/dev/null; then color="$RED"; fi
            echo -e "    Realloc:   ${color}${reallocated} sectors${RESET}"
        fi

        local pending
        pending=$(echo "$attrs" | awk '/^197/ {print $10}')
        if [ -n "$pending" ]; then
            local color="$DIM"
            if [ "$pending" -gt 0 ] 2>/dev/null; then color="$YELLOW"; fi
            echo -e "    Pending:   ${color}${pending} sectors${RESET}"
        fi

        local uncorrectable
        uncorrectable=$(echo "$attrs" | awk '/^198/ {print $10}')
        if [ -n "$uncorrectable" ]; then
            local color="$DIM"
            if [ "$uncorrectable" -gt 0 ] 2>/dev/null; then color="$RED"; fi
            echo -e "    Uncorrect: ${color}${uncorrectable} sectors${RESET}"
        fi
    fi

    echo ""
}

run_check() {
    local disks
    disks=$(scan_disks)

    if [ -z "$disks" ]; then
        echo -e "  ${DIM}No disks found.${RESET}"
        exit 0
    fi

    total_disks=0
    healthy_disks=0
    warning_disks=0
    critical_disks=0
    unknown_disks=0

    echo ""
    echo -e "  ${BOLD}Disk Health Check${RESET}  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo ""

    if $JSON_OUTPUT; then
        echo "  ["
    fi

    while IFS= read -r disk; do
        [ -z "$disk" ] && continue
        check_disk "$disk"
    done <<< "$disks"

    if $JSON_OUTPUT; then
        echo "  ]"
        return
    fi

    echo "  ─────────────────────────────────"
    echo -e "  ${BOLD}Summary:${RESET}"
    echo -e "  ${GREEN}✓${RESET} Healthy:    ${GREEN}${BOLD}$healthy_disks${RESET}"
    echo -e "  ${YELLOW}⚠${RESET} Warning:    ${YELLOW}${BOLD}$warning_disks${RESET}"
    echo -e "  ${RED}✗${RESET} Critical:   ${RED}${BOLD}$critical_disks${RESET}"
    echo -e "  ${DIM}○${RESET} Unknown:    ${DIM}${BOLD}$unknown_disks${RESET}"
    echo "  ─────────────────────────────────"

    if [ "$critical_disks" -gt 0 ]; then
        echo ""
        echo -e "  ${RED}${BOLD}ACTION REQUIRED:${RESET} ${RED}Replace failing disks immediately!${RESET}"
        echo -e "  ${RED}Back up all data from critical disks.${RESET}"
    elif [ "$warning_disks" -gt 0 ]; then
        echo ""
        echo -e "  ${YELLOW}Monitor warning disks closely. Consider replacing soon.${RESET}"
    fi

    echo ""
}

check_smartctl_access

if [ "$WATCH_INTERVAL" -gt 0 ]; then
    while true; do
        clear 2>/dev/null || true
        run_check
        echo -e "  ${DIM}Next check in ${WATCH_INTERVAL}s — Ctrl+C to exit${RESET}"
        sleep "$WATCH_INTERVAL"
    done
else
    run_check
fi