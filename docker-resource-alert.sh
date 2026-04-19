#!/bin/bash
# docker-resource-alert.sh — Alerta quando container ultrapassa limites (Linux)
# Uso: ./docker-resource-alert.sh [opcoes]
# Opcoes:
#   --cpu PCT       Limite de CPU em % (padrao: 80)
#   --mem PCT       Limite de RAM em % (padrao: 80)
#   --disk BYTES    Limite de disco em bytes (padrao: 0 = desativado)
#   --watch N       Verifica a cada N segundos (padrao: 10)
#   --notify        Notificacoes desktop
#   --kill          Mata container que ultrapassar CPU por 3 vezes seguidas
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi

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


CPU_LIMIT=80
MEM_LIMIT=80
DISK_LIMIT=0
WATCH_INTERVAL=10
USE_NOTIFY=false
AUTO_KILL=false

declare -A CPU_VIOLATIONS

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu)
            [[ -z "${2-}" ]] && { echo "Flag --cpu requer um valor" >&2; exit 1; }
            CPU_LIMIT="${2:-80}"; shift 2 ;;
        --mem)
            [[ -z "${2-}" ]] && { echo "Flag --mem requer um valor" >&2; exit 1; }
            MEM_LIMIT="${2:-80}"; shift 2 ;;
        --disk)
            [[ -z "${2-}" ]] && { echo "Flag --disk requer um valor" >&2; exit 1; }
            DISK_LIMIT="${2:-0}"; shift 2 ;;
        --watch|-w)
            [[ -z "${2-}" ]] && { echo "Flag --watch requer um valor" >&2; exit 1; }
            WATCH_INTERVAL="${2:-10}"; shift 2 ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --kill|-k) AUTO_KILL=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-resource-alert.sh — Alerta de recursos Docker"
            echo ""
            echo "  Uso: ./docker-resource-alert.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --cpu PCT       Limite de CPU em % (padrao: 80)"
            echo "    --mem PCT       Limite de RAM em % (padrao: 80)"
            echo "    --disk BYTES    Limite de disco em bytes (0 = desativado)"
            echo "    --watch N       Intervalo em segundos (padrao: 10)"
            echo "    --notify        Notificacoes desktop"
            echo "    --kill          Mata container com CPU alta por 3 vezes"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-resource-alert.sh --cpu 90 --mem 90 --watch 15"
            echo "    ./docker-resource-alert.sh --cpu 70 --notify --kill"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-resource-alert.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
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

get_total_memory_kb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {print $2}' /proc/meminfo
    else
        echo "0"
    fi
}

TOTAL_MEM_KB=$(get_total_memory_kb)

echo ""
echo -e "  ${BOLD}Docker Resource Alert${RESET}"
echo ""
echo -e "  Limites: CPU ${RED}${CPU_LIMIT}%${RESET}  |  RAM ${RED}${MEM_LIMIT}%${RESET}  |  Disco ${RED}$( [ "$DISK_LIMIT" -gt 0 ] && echo "${DISK_LIMIT} bytes" || echo "desativado" )${RESET}"
echo -e "  Intervalo: ${CYAN}${WATCH_INTERVAL}s${RESET}"

if $AUTO_KILL; then
    echo -e "  ${RED}Auto-kill: ativado${RESET} (3 violacoes de CPU seguidas)"
fi

echo -e "  ${DIM}Ctrl+C para sair${RESET}"
echo ""

while true; do
    containers=$(docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null)

    [ -z "$containers" ] && sleep "$WATCH_INTERVAL" && continue

    while IFS='|' read -r cid cname; do
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" "$cid" 2>/dev/null | head -1)
        [ -z "$stats" ] && continue

        IFS='|' read -r cpu_pct mem_usage mem_pct <<< "$stats"

        cpu_num=$(echo "$cpu_pct" | tr -d '%' | tr -d '[:space:]')
        mem_num=$(echo "$mem_pct" | tr -d '%' | tr -d '[:space:]')

        if ! [[ "$cpu_num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then cpu_num=0; fi
        if ! [[ "$mem_num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then mem_num=0; fi

        cpu_int=${cpu_num%.*}
        mem_int=${mem_num%.*}
        [[ "$cpu_int" =~ ^[0-9]+$ ]] || cpu_int=0
        [[ "$mem_int" =~ ^[0-9]+$ ]] || mem_int=0

        alerts=""

        if [ "$cpu_int" -gt "$CPU_LIMIT" ]; then
            alerts="${alerts}CPU ${RED}${cpu_pct}${RESET} "
            CPU_VIOLATIONS[$cname]=$((${CPU_VIOLATIONS[$cname]:-0} + 1))

            if $AUTO_KILL && [ "${CPU_VIOLATIONS[$cname]}" -ge 3 ]; then
                echo -e "  ${RED}✗${RESET} $cname — CPU alta por 3 ciclos — ${RED}MATANDO${RESET}"
                docker stop "$cid" &>/dev/null || true
                send_notify "Docker: $cname eliminado" "CPU acima de $CPU_LIMIT% por 3 ciclos"
                unset CPU_VIOLATIONS[$cname]
                continue
            fi
        else
            CPU_VIOLATIONS[$cname]=0
        fi

        if [ "$mem_int" -gt "$MEM_LIMIT" ]; then
            alerts="${alerts}RAM ${RED}${mem_pct}${RESET} "
        fi

        if [ "$DISK_LIMIT" -gt 0 ]; then
            disk_size=$(du -sb "/var/lib/docker/containers/$cid" 2>/dev/null | awk '{print $1}' || echo 0)
            disk_size=$(echo "$disk_size" | tr -d '[:space:]')
            [[ "$disk_size" =~ ^[0-9]+$ ]] || disk_size=0
            if [ "$disk_size" -gt "$DISK_LIMIT" ]; then
                alerts="${alerts}DISCO ${RED}$( [ "$disk_size" -ge 1048576 ] && echo "$((disk_size / 1048576))MB" || echo "$((disk_size / 1024))KB" )${RESET} "
            fi
        fi

        if [ -n "$alerts" ]; then
            timestamp=$(date '+%H:%M:%S')
            echo -e "  ${YELLOW}⚠${RESET} [${DIM}$timestamp${RESET}] ${CYAN}$cname${RESET} — $alerts"

            if $USE_NOTIFY; then
                send_notify "Docker Alert: $cname" "$alerts" "critical"
            fi
        fi
    done <<< "$containers"

    sleep "$WATCH_INTERVAL"
done