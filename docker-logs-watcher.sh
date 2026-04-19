#!/bin/bash
# docker-logs-watcher.sh — Monitora logs de containers com filtros (Linux)
# Uso: ./docker-logs-watcher.sh [opcoes]
# Opcoes:
#   --container NOME Container para monitorar (padrao: todos rodando)
#   --filter TEXTO   Filtra linhas contendo TEXTO (case-insensitive)
#   --error          Filtra apenas erros (ERROR, FATAL, CRITICAL, Exception)
#   --since TEMPO    Logs a partir de (ex: 5m, 1h, 1d)
#   --notify         Envia notificacao desktop ao detectar erro
#   --help           Mostra esta ajuda
#   --version        Mostra versao

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi




TARGET_CONTAINERS=()
FILTER_TEXT=""
ERROR_ONLY=false
SINCE=""
USE_NOTIFY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --container|-c)
            [[ -z "${2-}" ]] && { echo "Flag --container requer um valor" >&2; exit 1; }
            TARGET_CONTAINERS+=("$2"); shift 2 ;;
        --filter|-f)
            [[ -z "${2-}" ]] && { echo "Flag --filter requer um valor" >&2; exit 1; }
            FILTER_TEXT="$2"; shift 2 ;;
        --error|-e) ERROR_ONLY=true; shift ;;
        --since|-s)
            [[ -z "${2-}" ]] && { echo "Flag --since requer um valor" >&2; exit 1; }
            SINCE="$2"; shift 2 ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-logs-watcher.sh — Monitora logs de containers com filtros"
            echo ""
            echo "  Uso: ./docker-logs-watcher.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --container NOME  Container para monitorar (multiplas vezes)"
            echo "    --filter TEXTO    Filtra linhas contendo TEXTO"
            echo "    --error           Filtra apenas erros (ERROR, FATAL, etc)"
            echo "    --since TEMPO     Logs a partir de (ex: 5m, 1h, 1d)"
            echo "    --notify          Notificacao desktop ao detectar erro"
            echo "    --help            Mostra esta ajuda"
            echo "    --version         Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-logs-watcher.sh --error --notify"
            echo "    ./docker-logs-watcher.sh --container myapp --filter 'timeout'"
            echo "    ./docker-logs-watcher.sh --since 5m --error"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-logs-watcher.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

if [ ${#TARGET_CONTAINERS[@]} -eq 0 ]; then
    while IFS= read -r cid; do
        [ -z "$cid" ] && continue
        cname=$(docker inspect --format '{{.Name}}' "$cid" 2>/dev/null | sed 's|/||')
        TARGET_CONTAINERS+=("$cname")
    done < <(docker ps -q 2>/dev/null)
fi

if [ ${#TARGET_CONTAINERS[@]} -eq 0 ]; then
    echo -e "  ${DIM}Nenhum container rodando.${RESET}"
    exit 0
fi

ERROR_PATTERN="ERROR|FATAL|CRITICAL|CRASH|Exception|Traceback|panic|SEVERE"

send_notify() {
    local title="$1"
    local body="$2"
    if $USE_NOTIFY && command -v notify-send &>/dev/null; then
        notify-send -u critical "$title" "$body" 2>/dev/null || true
    fi
}

colorize_line() {
    local line="$1"
    local line_upper
    line_upper=$(echo "$line" | tr '[:lower:]' '[:upper:]')

    if echo "$line_upper" | grep -qE 'ERROR|FATAL|CRITICAL|CRASH|panic'; then
        echo -e "${RED}${line}${RESET}"
    elif echo "$line_upper" | grep -qE 'WARN|WARNING|CAUTION'; then
        echo -e "${YELLOW}${line}${RESET}"
    elif echo "$line_upper" | grep -qE 'TRACE|DEBUG|VERBOSE'; then
        echo -e "${DIM}${line}${RESET}"
    else
        echo "$line"
    fi
}

echo ""
echo -e "  ${BOLD}Docker Logs Watcher${RESET}"
echo -e "  ${DIM}Monitorando ${#TARGET_CONTAINERS[@]} container(s)${RESET}"

if [ -n "$FILTER_TEXT" ]; then
    echo -e "  ${DIM}Filtro: '$FILTER_TEXT'${RESET}"
fi

if $ERROR_ONLY; then
    echo -e "  ${DIM}Modo: apenas erros${RESET}"
fi

if [ -n "$SINCE" ]; then
    echo -e "  ${DIM}Desde: $SINCE${RESET}"
fi

echo -e "  ${DIM}Ctrl+C para sair${RESET}"
echo ""

error_count=0
last_notify_time=0

for container in "${TARGET_CONTAINERS[@]}"; do
    (
        LOG_ARGS=(--follow --timestamps)
        if [ -n "$SINCE" ]; then
            LOG_ARGS+=(--since "$SINCE")
        fi

        docker logs "${LOG_ARGS[@]}" "$container" 2>&1 | while IFS= read -r line; do
            if $ERROR_ONLY; then
                if ! echo "$line" | grep -qiE "$ERROR_PATTERN"; then
                    continue
                fi
            fi

            if [ -n "$FILTER_TEXT" ]; then
                if ! echo "$line" | grep -qiF "$FILTER_TEXT"; then
                    continue
                fi
            fi

            colored=$(colorize_line "$line")
            echo -e "  ${CYAN}[$container]${RESET} $colored"

            if echo "$line" | grep -qiE "$ERROR_PATTERN"; then
                error_count=$((error_count + 1))
                now=$(date +%s)
                if $USE_NOTIFY && [ $((now - last_notify_time)) -gt 30 ]; then
                    msg=$(echo "$line" | cut -c1-80)
                    send_notify "Docker Error: $container" "$msg"
                    last_notify_time=$now
                fi
            fi
        done
    ) &
done

wait