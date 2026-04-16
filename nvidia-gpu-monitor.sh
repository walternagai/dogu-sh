#!/bin/bash
# nvidia-gpu-monitor.sh — Monitora atividade da GPU NVIDIA em segundo plano (Linux)
# Uso: ./nvidia-gpu-monitor.sh [opcoes]
# Opcoes:
#   --interval N    Intervalo de amostragem em segundos (padrao: 5)
#   --output FILE   Caminho do arquivo de log (padrao: /tmp/nvidia-gpu-monitor.log)
#   --temp N        Limiar de alerta de temperatura em °C (padrao: 80)
#   --retention N   Retencao do log em dias (padrao: 7)
#   --once          Coleta uma vez e sai
#   --notify        Notificacao de desktop em alertas
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

NVIDIA_PATHS="/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/snap/bin:/opt/nvidia/bin:/usr/lib/wsl/lib"
for p in ${NVIDIA_PATHS//:/ }; do
    case ":$PATH:" in
        *":$p:"*) ;;
        *) PATH="$PATH:$p" ;;
    esac
done
export PATH

ERR_FILE="/tmp/nvidia-gpu-monitor-err.log"

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
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
DAEMON=false
PID_FILE="/tmp/nvidia-gpu-monitor.pid"

while [ $# -gt 0 ]; do
    case "$1" in
        --interval|-i) INTERVAL="${2:-5}"; shift 2 ;;
        --output|-o) LOG_FILE="${2:-/tmp/nvidia-gpu-monitor.log}"; ALERT_LOG="${LOG_FILE%.log}-alerts.log"; shift 2 ;;
        --temp|-t) TEMP_THRESHOLD="${2:-80}"; shift 2 ;;
        --retention|-r) RETENTION_DAYS="${2:-7}"; shift 2 ;;
        --once|-1) ONCE=true; shift ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --daemon|-d) DAEMON=true; shift ;;
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
            echo "    --daemon        Run as daemon (redirect output to log file)"
            echo "    --stop          Stop background monitor"
            echo "    --help          Show this help"
            echo "    --version       Show version"
            echo ""
            echo "  Background usage:"
            echo "    nohup ./nvidia-gpu-monitor.sh &"
            echo "    ./nvidia-gpu-monitor.sh --daemon            (recommended)"
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
                    kill -TERM "$PID" 2>/dev/null
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
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

NVIDIA_SMI=""
for candidate in /usr/bin/nvidia-smi /usr/sbin/nvidia-smi /usr/local/bin/nvidia-smi /snap/bin/nvidia-smi /usr/lib/wsl/lib/nvidia-smi nvidia-smi; do
    if [ -x "$candidate" ] 2>/dev/null; then
        NVIDIA_SMI="$candidate"
        break
    fi
done

if [ -z "$NVIDIA_SMI" ]; then
    echo -e "  ${RED}Error: nvidia-smi not found.${RESET}" >&2
    echo -e "  PATH searched: $PATH" >&2
    echo -e "  Install NVIDIA drivers:" >&2
    echo -e "    sudo apt install nvidia-driver-535   # Debian/Ubuntu" >&2
    echo -e "    sudo dnf install xorg-x11-drv-nvidia # Fedora" >&2
    echo -e "    sudo pacman -S nvidia                  # Arch" >&2
    exit 1
fi

if ! "$NVIDIA_SMI" &>/dev/null; then
    echo -e "  ${RED}Error: nvidia-smi failed. No NVIDIA GPU detected or driver issue.${RESET}" >&2
    "$NVIDIA_SMI" &>"$ERR_FILE" || true
    echo -e "  Details logged to: $ERR_FILE" >&2
    cat "$ERR_FILE" >&2
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
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "N/A"
        return
    fi
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
    local core_output extended_output rc
    core_output=$("$NVIDIA_SMI" \
        --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total,memory.free,temperature.gpu,pstate,uuid,driver_version,vbios_version \
        --format=csv,noheader 2>"$ERR_FILE")
    rc=$?
    if [ $rc -ne 0 ] || [ -z "$core_output" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: nvidia-smi core query failed (rc=$rc)" >> "$LOG_FILE"
        [ -s "$ERR_FILE" ] && cat "$ERR_FILE" >> "$LOG_FILE"
        : > "$ERR_FILE"
        return 1
    fi
    : > "$ERR_FILE"

    extended_output=$("$NVIDIA_SMI" \
        --query-gpu=index,fan.speed,power.draw,power.limit,clocks.current.sm,clocks.current.mem,clocks.max.sm,clocks.max.mem \
        --format=csv,noheader 2>>"$ERR_FILE") || true

    echo "CORE<<${core_output}>>EXT<<${extended_output}>>"
}

collect_process_data() {
    "$NVIDIA_SMI" --query-compute-apps=pid,gpu_uuid,process_name,used_memory --format=csv,noheader 2>/dev/null || echo ""
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
                pmem=$(echo "$pmem" | sed 's/ MiB//' | xargs)
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
    if [[ "$temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge "$TEMP_THRESHOLD" ]; then
        temp_color="$RED"
    elif [[ "$temp" =~ ^[0-9]+$ ]] && [ "$temp" -ge $((TEMP_THRESHOLD - 10)) ]; then
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

if ! $ONCE && ! $DAEMON; then
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

if $DAEMON; then
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
    echo -e "  ${GREEN}Starting nvidia-gpu-monitor in daemon mode (PID $$)${RESET}"
    echo -e "  ${DIM}Log: ${LOG_FILE}${RESET}"
    echo -e "  ${DIM}Stop with: ./nvidia-gpu-monitor.sh --stop${RESET}"
    exec >> "$LOG_FILE" 2>&1
    disown 2>/dev/null || true
fi

rotate_logs "$LOG_FILE" "$RETENTION_DAYS"
rotate_logs "$ALERT_LOG" "$RETENTION_DAYS"

log_both() {
    local msg="$1"
    echo -e "$msg"
    echo -e "$msg" >> "$LOG_FILE"
}

log_both "  ${BOLD}nvidia-gpu-monitor.sh v${VERSION}${RESET}"
log_both "  ${DIM}Interval: ${INTERVAL}s | Temp alert: ${TEMP_THRESHOLD}°C | Retention: ${RETENTION_DAYS} days${RESET}"
log_both "  ${DIM}Log: ${LOG_FILE}${RESET}"
log_both "  ${DIM}Alert log: ${ALERT_LOG}${RESET}"

if ! $ONCE; then
    log_both "  ${DIM}PID: $$ (PID file: ${PID_FILE})${RESET}"
    log_both "  ${DIM}Stop with: kill \$\$ or ./nvidia-gpu-monitor.sh --stop${RESET}"
fi

log_both ""

monitor_loop() {
    while true; do
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')

        local raw_data
        raw_data=$(collect_gpu_data) || {
            sleep "$INTERVAL"
            continue
        }

        local core_data ext_data
        core_data=$(echo "$raw_data" | sed -n 's/.*CORE<<\(.*\)>>EXT.*/\1/p')
        ext_data=$(echo "$raw_data" | sed -n 's/.*>>EXT<<\(.*\)>>/\1/p')

        local process_data
        process_data=$(collect_process_data)

        local idx name gpu_util_pct mem_util_pct mem_used_mb mem_total_mb mem_free_mb temp_c pstate uuid driver vbios
        local fan_speed="N/A" power_draw="N/A" power_limit="N/A"
        local sm_clock="N/A" mem_clock="N/A" max_sm="N/A" max_mem="N/A"

        while IFS=',' read -r idx name gpu_util_pct mem_util_pct mem_used_mb mem_total_mb mem_free_mb temp_c pstate uuid driver vbios; do
            idx=$(echo "$idx" | xargs)
            name=$(echo "$name" | xargs)
            gpu_util_pct=$(echo "$gpu_util_pct" | sed 's/ %//' | xargs); gpu_util_pct=${gpu_util_pct:-0}
            mem_util_pct=$(echo "$mem_util_pct" | sed 's/ %//' | xargs); mem_util_pct=${mem_util_pct:-0}
            mem_used_mb=$(echo "$mem_used_mb" | sed 's/ MiB//' | xargs); mem_used_mb=${mem_used_mb:-0}
            mem_total_mb=$(echo "$mem_total_mb" | sed 's/ MiB//' | xargs); mem_total_mb=${mem_total_mb:-0}
            mem_free_mb=$(echo "$mem_free_mb" | sed 's/ MiB//' | xargs); mem_free_mb=${mem_free_mb:-0}
            temp_c=$(echo "$temp_c" | xargs); temp_c=${temp_c:-0}
            pstate=$(echo "$pstate" | xargs); pstate=${pstate:-N/A}
            uuid=$(echo "$uuid" | xargs)
            driver=$(echo "$driver" | xargs)
            vbios=$(echo "$vbios" | xargs)

            if [ -n "$ext_data" ]; then
                local ext_idx ext_fan ext_pwr_draw ext_pwr_limit ext_sm ext_mem ext_maxsm ext_maxmem
                while IFS=',' read -r ext_idx ext_fan ext_pwr_draw ext_pwr_limit ext_sm ext_mem ext_maxsm ext_maxmem; do
                    ext_idx=$(echo "$ext_idx" | xargs)
                    if [ "$ext_idx" = "$idx" ]; then
                        fan_speed=$(echo "$ext_fan" | sed 's/ %//' | xargs); fan_speed=${fan_speed:-N/A}
                        power_draw=$(echo "$ext_pwr_draw" | sed 's/ W//' | xargs); power_draw=${power_draw:-N/A}
                        power_limit=$(echo "$ext_pwr_limit" | sed 's/ W//' | xargs); power_limit=${power_limit:-N/A}
                        sm_clock=$(echo "$ext_sm" | sed 's/ MHz//' | xargs); sm_clock=${sm_clock:-N/A}
                        mem_clock=$(echo "$ext_mem" | sed 's/ MHz//' | xargs); mem_clock=${mem_clock:-N/A}
                        max_sm=$(echo "$ext_maxsm" | sed 's/ MHz//' | xargs); max_sm=${max_sm:-N/A}
                        max_mem=$(echo "$ext_maxmem" | sed 's/ MHz//' | xargs); max_mem=${max_mem:-N/A}
                    fi
                done <<< "$ext_data"
            fi

            print_summary "$timestamp" "$idx" "$name" \
                "$gpu_util_pct" "$mem_util_pct" "$mem_used_mb" "$mem_total_mb" "$mem_free_mb" \
                "$temp_c" "$fan_speed" "$power_draw" "$power_limit" \
                "$sm_clock" "$mem_clock" "$max_sm" "$max_mem" \
                "$pstate" "$uuid" "$driver" "$vbios"

            if [[ "$temp_c" =~ ^[0-9]+$ ]] && [ "$temp_c" -ge "$TEMP_THRESHOLD" ]; then
                log_alert "$timestamp" "$idx" "$name" "$temp_c" \
                    "$gpu_util_pct" "$mem_util_pct" "$mem_used_mb" "$mem_total_mb" \
                    "$power_draw" "$power_limit" "$fan_speed" \
                    "$sm_clock" "$mem_clock" "$pstate" "$process_data"

                echo -e "  ${RED}${BOLD}⚠  TEMPERATURE ALERT: GPU ${idx} at ${temp_c}°C (threshold: ${TEMP_THRESHOLD}°C)${RESET}"
                send_notify "GPU Temperature Alert" "GPU ${idx} (${name}) at ${temp_c}°C — exceeds ${TEMP_THRESHOLD}°C" "critical"
            fi

            fan_speed="N/A"; power_draw="N/A"; power_limit="N/A"
            sm_clock="N/A"; mem_clock="N/A"; max_sm="N/A"; max_mem="N/A"
        done <<< "$core_data"

        $ONCE && break

        sleep "$INTERVAL"
    done
}

monitor_loop