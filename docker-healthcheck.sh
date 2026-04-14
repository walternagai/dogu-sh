#!/bin/bash
# docker-healthcheck.sh — Verifica saude dos containers e reinicia unhealthy (Linux)
# Uso: ./docker-healthcheck.sh [opcoes]
# Opcoes:
#   --restart       Reinicia containers unhealthy automaticamente
#   --notify        Notificacoes desktop em problemas
#   --watch N       Verifica a cada N segundos (modo continuo)
#   --dry-run       Preview sem reiniciar
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

AUTO_RESTART=false
USE_NOTIFY=false
WATCH_INTERVAL=0
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --restart|-r) AUTO_RESTART=true; shift ;;
        --notify|-n) USE_NOTIFY=true; shift ;;
        --watch|-w) WATCH_INTERVAL="${2:-30}"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-healthcheck.sh — Verifica saude dos containers"
            echo ""
            echo "  Uso: ./docker-healthcheck.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --restart       Reinicia containers unhealthy automaticamente"
            echo "    --notify        Notificacoes desktop em problemas"
            echo "    --watch N       Verifica a cada N segundos (modo continuo)"
            echo "    --dry-run       Preview sem reiniciar"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-healthcheck.sh"
            echo "    ./docker-healthcheck.sh --restart --notify"
            echo "    ./docker-healthcheck.sh --watch 60 --restart"
            echo ""
            exit 0
            ;;
        --version) echo "docker-healthcheck.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
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

run_check() {
    local total_running=0
    local total_healthy=0
    local total_unhealthy=0
    local total_starting=0
    local total_no_health=0
    local restarted=0

    echo ""
    echo -e "  ${BOLD}Docker Healthcheck${RESET}  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo ""

    containers=$(docker ps --format '{{.ID}}|{{.Names}}|{{.Status}}' 2>/dev/null)
    total_running=$(echo "$containers" | grep -c '|' || echo 0)

    if [ "$total_running" -eq 0 ]; then
        echo -e "  ${DIM}Nenhum container rodando.${RESET}"
        echo ""
        return
    fi

    for container_line in $containers; do
        IFS='|' read -r cid cname cstatus <<< "$container_line"

        health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$cid" 2>/dev/null)

        case "$health" in
            healthy)
                total_healthy=$((total_healthy + 1))
                ;;
            unhealthy)
                total_unhealthy=$((total_unhealthy + 1))
                local failing=""
                failing=$(docker inspect --format '{{range .State.Health.Log}}{{if eq .ExitCode 1}}{{.Output}}{{end}}{{end}}' "$cid" 2>/dev/null | head -1)
                failing=$(echo "$failing" | cut -c1-80)

                echo -e "  ${RED}✗${RESET} ${BOLD}$cname${RESET}  ${RED}UNHEALTHY${RESET}"
                if [ -n "$failing" ]; then
                    echo -e "    ${DIM}$failing${RESET}"
                fi

                if $AUTO_RESTART && ! $DRY_RUN; then
                    echo -e "    ${YELLOW}→ Reiniciando $cname...${RESET}"
                    docker restart "$cname" &>/dev/null
                    if [ $? -eq 0 ]; then
                        echo -e "    ${GREEN}  ✓ Reiniciado${RESET}"
                        restarted=$((restarted + 1))
                        send_notify "Docker: $cname reiniciado" "Container unhealthy foi reiniciado" "normal"
                    else
                        echo -e "    ${RED}  ✗ Falha ao reiniciar${RESET}"
                    fi
                elif $AUTO_RESTART && $DRY_RUN; then
                    echo -e "    ${DIM}[dry-run] Seria reiniciado${RESET}"
                fi

                send_notify "Docker: $cname UNHEALTHY" "Container com problema de saude" "critical"
                ;;
            starting)
                total_starting=$((total_starting + 1))
                echo -e "  ${YELLOW}◐${RESET} $cname  ${YELLOW}STARTING${RESET}"
                ;;
            none)
                total_no_health=$((total_no_health + 1))
                ;;
            *)
                total_no_health=$((total_no_health + 1))
                ;;
        esac
    done

    echo ""
    echo "  ─────────────────────────────────"
    echo -e "  ${BOLD}Resumo:${RESET}"
    echo -e "  Rodando:       ${BOLD}$total_running${RESET}"
    echo -e "  Saudaveis:     ${GREEN}${BOLD}$total_healthy${RESET}"
    echo -e "  Iniciando:     ${YELLOW}${BOLD}$total_starting${RESET}"
    echo -e "  Problema:      ${RED}${BOLD}$total_unhealthy${RESET}"
    echo -e "  Sem health:    ${DIM}${BOLD}$total_no_health${RESET}"

    if [ "$restarted" -gt 0 ]; then
        echo -e "  Reiniciados:   ${CYAN}${BOLD}$restarted${RESET}"
    fi

    echo "  ─────────────────────────────────"
}

if [ "$WATCH_INTERVAL" -gt 0 ]; then
    while true; do
        clear 2>/dev/null || true
        run_check
        echo ""
        echo -e "  ${DIM}Proxima verificacao em ${WATCH_INTERVAL}s — Ctrl+C para sair${RESET}"
        sleep "$WATCH_INTERVAL"
    done
else
    run_check
    echo ""
fi