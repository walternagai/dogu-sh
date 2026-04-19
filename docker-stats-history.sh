#!/bin/bash
# docker-stats-history.sh — Registra historico de CPU/RAM dos containers em CSV
# Uso: ./docker-stats-history.sh [opcoes]
# Opcoes:
#   --output FILE   Arquivo CSV destino (padrao: docker-stats.csv)
#   --watch N       Intervalo em segundos (padrao: 10)
#   --container N   Filtrar por nome do container
#   --no-header     Nao escrever header CSV
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail


readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='033[1;33m'
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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi




OUTPUT_FILE="docker-stats.csv"
WATCH_INTERVAL=10
CONTAINER_FILTER=""
NO_HEADER=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output|-o)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 1; }
            OUTPUT_FILE="$2"; shift 2 ;;
        --watch|-w)
            [[ -z "${2-}" ]] && { echo "Flag --watch requer um valor" >&2; exit 1; }
            WATCH_INTERVAL="${2:-10}"; shift 2 ;;
        --container|-c)
            [[ -z "${2-}" ]] && { echo "Flag --container requer um valor" >&2; exit 1; }
            CONTAINER_FILTER="$2"; shift 2 ;;
        --no-header) NO_HEADER=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-stats-history.sh — Historico de CPU/RAM em CSV"
            echo ""
            echo "  Uso: ./docker-stats-history.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --output FILE   Arquivo CSV destino (padrao: docker-stats.csv)"
            echo "    --watch N       Intervalo em segundos (padrao: 10)"
            echo "    --container N   Filtrar por nome do container"
            echo "    --no-header     Nao escrever header CSV"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Formato CSV:"
            echo "    timestamp,container,cpu_pct,mem_usage,mem_limit,mem_pct,net_io,block_io"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-stats-history.sh --output /tmp/stats.csv"
            echo "    ./docker-stats-history.sh --watch 30 --container nginx"
            echo "    ./docker-stats-history.sh --output stats.csv &"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-stats-history.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

if ! $NO_HEADER && [ ! -f "$OUTPUT_FILE" ]; then
    echo "timestamp,container,cpu_pct,mem_usage,mem_limit,mem_pct,net_io,block_io" > "$OUTPUT_FILE"
fi

collect_stats() {
    local timestamp
    timestamp=$(date '+%Y-%m-%dT%H:%M:%S')

    local filter_arg=""
    if [ -n "$CONTAINER_FILTER" ]; then
        filter_arg="--filter name=$CONTAINER_FILTER"
    fi

    local containers
    containers=$(docker ps $filter_arg --format '{{.Names}}' 2>/dev/null)

    if [ -z "$containers" ]; then
        return
    fi

    local row_count=0

    while IFS= read -r cname; do
        [ -z "$cname" ] && continue

        local stats
        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}|{{.NetIO}}|{{.BlockIO}}" "$cname" 2>/dev/null | head -1)

        if [ -z "$stats" ]; then
            continue
        fi

        IFS='|' read -r cpu_pct mem_usage mem_pct net_io block_io <<< "$stats"

        local mem_usage_val
        mem_usage_val=$(echo "$mem_usage" | awk -F'/' '{print $1}' | tr -d '[:space:]')
        local mem_limit_val
        mem_limit_val=$(echo "$mem_usage" | awk -F'/' '{print $2}' | tr -d '[:space:]')

        local csv_line="${timestamp},${cname},${cpu_pct},${mem_usage_val},${mem_limit_val},${mem_pct},${net_io},${block_io}"
        if $DRY_RUN; then
            echo "$csv_line"
        else
            echo "$csv_line" >> "$OUTPUT_FILE"
        fi

        row_count=$((row_count + 1))
    done <<< "$containers"

    local total_lines
    total_lines=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
    echo -e "  ${DIM}[$(date '+%H:%M:%S')]${RESET} ${row_count} container(s) registrados  |  Total: ${BOLD}$((total_lines - 1))${RESET} linhas em ${OUTPUT_FILE}"
}

echo ""
echo -e "  ${BOLD}Docker Stats History${RESET}  ${DIM}v$VERSION${RESET}"
echo ""
echo -e "  Arquivo:  ${CYAN}${OUTPUT_FILE}${RESET}"
echo -e "  Intervalo: ${BOLD}${WATCH_INTERVAL}s${RESET}"

if [ -n "$CONTAINER_FILTER" ]; then
    echo -e "  Filtro:   ${CYAN}${CONTAINER_FILTER}${RESET}"
fi

echo -e "  ${DIM}Ctrl+C para parar${RESET}"
echo ""

echo -e "  ${GREEN}✓${RESET} Coletando stats... (a cada ${WATCH_INTERVAL}s)"

while true; do
    collect_stats
    sleep "$WATCH_INTERVAL"
done