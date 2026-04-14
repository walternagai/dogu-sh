#!/bin/bash
# nvidia-gpu-monitor.sh — Monitor NVIDIA GPU activity in background (Linux)
# Usage: ./nvidia-gpu-monitor.sh [options]
# Options:
#   --interval N    Sampling interval in seconds (default: 5)
#   --output FILE   Log file path (default: /tmp/nvidia-gpu-monitor.log)
#   --temp N        Temperature alert threshold in °C (default: 80)
#   --retention N   Log retention in days (default: 7)
#   --once          Collect once and exit
#   --notify        Desktop notification on alerts
#   --help          Show this help
#   --version       Show version

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

INTERVAL=5
LOG_FILE="/tmp/nvidia-gpu-monitor.log"
ALERT_LOG="/tmp/nvidia-gpu-monitor-alerts.log"
TEMP_THRESHOLD=80
RETENTION_DAYS=7
ONCE=false
USE_NOTIFY=false
PID_FILE="/tmp/nvidia-gpu-monitor.pid"

while [ $# -gt 0 ]; do
    case "$1" in
        --interval|-i) INTERVAL="${2:-5}"; shift 2 ;;
        --output|-o) LOG_FILE="${2:-/tmp/nvidia-gpu-monitor.log}"; ALERT_LOG="${LOG_FILE%.log}-alerts.log"; shift 2 ;;
        --temp|-t) TEMP_THRESHOLD="${2:-80}"; shift 2 ;;
        --retention|-r) RETENTION_DAYS="${2:-7}"; shift 2 ;;
        --once|-1) ONCE=true; shift ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --help|-h)
            echo ""
            echo "  nvidia-gpu-monitor.sh — Monitor NVIDIA GPU activity in background"
            echo ""
            echo "  Usage: ./nvidia-gpu-monitor.sh [options]"
            echo ""
            echo "  Options:"
            echo "    --interval N    Sampling interval in seconds (default: 5)"
            echo "    --output FILE   Log file path (default: /tmp/nvidia-gpu-monitor.log)"
            echo "    --temp N        Temperature alert threshold °C (default: 80)"
            echo "    --retention N   Log retention in days (default: 7)"
            echo "    --once          Collect once and exit"
            echo "    --notify        Desktop notification on alerts"
            echo "    --stop          Stop background monitor"
            echo "    --help          Show this help"
            echo "    --version       Show version"
            echo ""
            echo "  Background usage:"
            echo "    nohup ./nvidia-gpu-monitor.sh &"
            echo "    nohup ./nvidia-gpu-monitor.sh --interval 10 --temp 75 &"
            echo ""
            echo "  Stop background monitor:"
            echo "    ./nvidia-gpu-monitor.sh --stop"
            echo "    kill \$(cat /tmp/nvidia-gpu-monitor.pid)"
            echo ""
            echo "  Requires: NVIDIA drivers + nvidia-smi"
            echo ""
            exit 0
            ;;
        --version|-v) echo "nvidia-gpu-monitor.sh $VERSION"; exit 0 ;;
        --stop|-s)
            if [ -f "$PID_FILE" ]; then
                PID=$(cat "$PID_FILE")
                if kill -0 "$PID" 2>/dev/null; then
                    kill "$PID"
                    rm -f "$PID_FILE"
                    echo -e "  ${GREEN}Stopped nvidia-gpu-monitor (PID $PID)${RESET}"
                else
                    rm -f "$PID_FILE"
                    echo -e "  ${YELLOW}Process $PID not running (stale PID file removed)${RESET}"
                fi
            else
                echo -e "  ${YELLOW}No PID file found. Monitor may not be running.${RESET}"
            fi
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if ! command -v nvidia-smi &>/dev/null; then
    echo -e "  ${RED}Error: nvidia-smi not found.${RESET}" >&2
    echo -e "  Install NVIDIA drivers:" >&2
    echo -e "    sudo apt install nvidia-driver-535   # Debian/Ubuntu" >&2
    echo -e "    sudo dnf install xorg-x11-drv-nvidia # Fedora" >&2
    echo -e "    sudo pacman -S nvidia                  # Arch" >&2
    exit 1
fi

if ! nvidia-smi &>/dev/null; then
    echo -e "  ${RED}Error: nvidia-smi failed. No NVIDIA GPU detected or driver issue.${RESET}" >&2
    exit 1
fi

send_notify() {
    local title="$1"
    local body="$2"
    local urgency="${3:-critical}"
    if $USE_NOTIFY && command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" "$title" "$body" 2>/dev/null || true
    fi
}

rotate_logs() {
    local log="$1"
    local days="$2"
    if [ -f "$log" ]; then
        find "$(dirname "$log")" -name "$(basename "$log")" -mtime +"$days" -delete 2>/dev/null || true
    fi
}

format_bar() {
    local value="$1"
    local width=20
    local filled=$(( value * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    local color=""
    if [ "$value" -ge 90 ]; then
        color="$RED"
    elif [ "$value" -ge 70 ]; then
        color="$YELLOW"
    else
        color="$GREEN"
    fi
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done
    echo -e "${color}${bar}${RESET} ${value}%"
}

collect_gpu_data() {
    local query_output
    query_output=$(nvidia-smi \
        --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,memory.free,temperature.gpu,fan.speed,power.draw,power.limit,clocks.current.sm,clocks.current.mem,clocks.max.sm,clocks.max.mem,pstate,uuid,driver_version,vbios_version \
        --format=csv,noheader,nounits 2>/dev/null) || return 1

    echo "$query_output"
}

collect_process_data() {
    nvidia-smi --query-compute-apps=pid,gpu_uuid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null || echo ""
}

log_alert() {
    local timestamp="$1"
    local gpu_idx="$2"
    local gpu_name="$3"
    local temp="$4"
    local gpu_util="$5"
    local mem_util="$6"
    local mem_used="$7"
    local mem_total="$8"
    local power_draw="$9"
    local power_limit="${10}"
    local fan_speed="${11}"
    local sm_clock="${12}"
    local mem_clock="${13}"
    local pstate="${14}"
    local processes="${15}"

    {
        echo "================================================================"
        echo "  TEMPERATURE ALERT — ${timestamp}"
        echo "================================================================"
        echo "  GPU ${gpu_idx}: ${gpu_name}"
        echo "  Temperature:  ${temp}°C (threshold: ${TEMP_THRESHOLD}°C)"
        echo "  GPU Util:     ${gpu_util}%"
        echo "  Mem Util:     ${mem_util}%"
        echo "  VRAM Used:    ${mem_used} / ${mem_total} MiB"
        echo "  Power Draw:   ${power_draw}W / ${power_limit}W"
        echo "  Fan Speed:    ${fan_speed}%"
        echo "  SM Clock:     ${sm_clock} MHz"
        echo "  Mem Clock:    ${mem_clock} MHz"
        echo "  P-State:      ${pstate}"
        if [ -n "$processes" ]; then
            echo "  Active Processes:"
            echo "$processes" | while IFS=, read -r pid uuid pname pmem; do
                printf "    PID %-8s  %-30s  %s MiB\n" "$pid" "$pname" "$pmem"
            done
        else
            echo "  No active compute processes"
        fi
        echo "================================================================"
        echo ""
    } >> "$ALERT_LOG"
}

display_line() {
    local label="$1"
    local value="$2"
    printf "  ${CYAN}%-16s${RESET} %s\n" "$label" "$value"
}

print_summary() {
    local timestamp="$1"
    local idx="$2"
    local name="$3"
    local gpu_util="$4"
    local mem_util="$5"
    local mem_used="$6"
    local mem_total="$7"
    local mem_free="$8"
    local temp="$9"
    local fan_speed="${10}"
    local power_draw="${11}"
    local power_limit="${12}"
    local sm_clock="${13}"
    local mem_clock="${14}"
    local max_sm="${15}"
    local max_mem="${16}"
    local pstate="${17}"
    local uuid="${18}"
    local driver="${19}"
    local vbios="${20}"

    local temp_color="$GREEN"
    if [ "${temp:-0}" -ge "$TEMP_THRESHOLD" ]; then
        temp_color="$RED"
    elif [ "${temp:-0}" -ge $((TEMP_THRESHOLD - 10)) ]; then
        temp_color="$YELLOW"
    fi

    local log_line="[$timestamp] GPU${idx} util=${gpu_util}% mem=${mem_util}% temp=${temp}°C fan=${fan_speed}% pwr=${power_draw}W vram=${mem_used}/${mem_total}MiB sm=${sm_clock}MHz memclk=${mem_clock}MHz pstate=${pstate}"

    echo ""
    echo -e "  ${BOLD}────────────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}  GPU ${idx}: ${name}${RESET}"
    echo -e "  ${BOLD}────────────────────────────────────────────────────────${RESET}"
    display_line "GPU Usage" "$(format_bar "${gpu_util}")"
    display_line "Memory Usage" "$(format_bar "${mem_util}")"
    display_line "VRAM" "${mem_used} / ${mem_total} MiB (${mem_free} MiB free)"
    display_line "Temperature" "${temp_color}${temp}°C${RESET} (alert: ${TEMP_THRESHOLD}°C)"
    display_line "Fan Speed" "${fan_speed}%"
    display_line "Power" "${power_draw}W / ${power_limit}W"
    display_line "SM Clock" "${sm_clock} / ${max_sm} MHz"
    display_line "Mem Clock" "${mem_clock} / ${max_mem} MHz"
    display_line "P-State" "${pstate}"
    display_line "Driver" "${driver}"
    display_line "vBIOS" "${vbios}"
    echo ""

    echo "$log_line" >> "$LOG_FILE"
}

cleanup() {
    rm -f "$PID_FILE"
    exit 0
}

trap cleanup SIGINT SIGTERM SIGHUP

if ! $ONCE; then
    if [ -f "$PID_FILE" ]; then
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo -e "  ${YELLOW}nvidia-gpu-monitor already running (PID $OLD_PID)${RESET}" >&2
            echo -e "  Use --stop to stop it first." >&2
            exit 1
        fi
        rm -f "$PID_FILE"
    fi
    echo $$ > "$PID_FILE"
fi

rotate_logs "$LOG_FILE" "$RETENTION_DAYS"
rotate_logs "$ALERT_LOG" "$RETENTION_DAYS"

echo -e "  ${BOLD}nvidia-gpu-monitor.sh v${VERSION}${RESET}" | tee -a "$LOG_FILE"
echo -e "  ${DIM}Interval: ${INTERVAL}s | Temp alert: ${TEMP_THRESHOLD}°C | Retention: ${RETENTION_DAYS} days${RESET}" | tee -a "$LOG_FILE"
echo -e "  ${DIM}Log: ${LOG_FILE}${RESET}" | tee -a "$LOG_FILE"
echo -e "  ${DIM}Alert log: ${ALERT_LOG}${RESET}" | tee -a "$LOG_FILE"

if ! $ONCE; then
    echo -e "  ${DIM}PID: $$ (PID file: ${PID_FILE})${RESET}" | tee -a "$LOG_FILE"
    echo -e "  ${DIM}Stop with: kill \$\$ or ./nvidia-gpu-monitor.sh --stop${RESET}" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

monitor_loop() {
    while true; do
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        local gpu_data
        gpu_data=$(collect_gpu_data) || {
            echo "[$timestamp] ERROR: nvidia-smi query failed" >> "$LOG_FILE"
            sleep "$INTERVAL"
            continue
        }

        local process_data
        process_data=$(collect_process_data)

        while IFS=, read -r idx name gpu_util mem_util mem_used mem_total mem_free temp fan_speed power_draw power_limit sm_clock mem_clock max_sm max_mem pstate uuid driver vbios; do
            idx=$(echo "$idx" | xargs)
            name=$(echo "$name" | xargs)
            gpu_util=$(echo "$gpu_util" | xargs)
            mem_util=$(echo "$mem_util" | xargs)
            mem_used=$(echo "$mem_used" | xargs)
            mem_total=$(echo "$mem_total" | xargs)
            mem_free=$(echo "$mem_free" | xargs)
            temp=$(echo "$temp" | xargs)
            fan_speed=$(echo "$fan_speed" | xargs)
            power_draw=$(echo "$power_draw" | xargs)
            power_limit=$(echo "$power_limit" | xargs)
            sm_clock=$(echo "$sm_clock" | xargs)
            mem_clock=$(echo "$mem_clock" | xargs)
            max_sm=$(echo "$max_sm" | xargs)
            max_mem=$(echo "$max_mem" | xargs)
            pstate=$(echo "$pstate" | xargs)

            print_summary "$timestamp" "$idx" "$name" \
                "$gpu_util" "$mem_util" "$mem_used" "$mem_total" "$mem_free" \
                "$temp" "$fan_speed" "$power_draw" "$power_limit" \
                "$sm_clock" "$mem_clock" "$max_sm" "$max_mem" \
                "$pstate" "$uuid" "$driver" "$vbios"

            if [ "${temp:-0}" -ge "$TEMP_THRESHOLD" ]; then
                log_alert "$timestamp" "$idx" "$name" "$temp" \
                    "$gpu_util" "$mem_util" "$mem_used" "$mem_total" \
                    "$power_draw" "$power_limit" "$fan_speed" \
                    "$sm_clock" "$mem_clock" "$pstate" "$process_data"

                echo -e "  ${RED}${BOLD}⚠  TEMPERATURE ALERT: GPU ${idx} at ${temp}°C (threshold: ${TEMP_THRESHOLD}°C)${RESET}"
                send_notify "GPU Temperature Alert" "GPU ${idx} (${name}) at ${temp}°C — exceeds ${TEMP_THRESHOLD}°C" "critical"
            fi
        done <<< "$gpu_data"

        $ONCE && break

        sleep "$INTERVAL"
    done
}

monitor_loop