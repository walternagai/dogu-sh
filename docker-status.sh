#!/bin/bash
# docker-status.sh — Painel resumido do Docker (Linux)
# Uso: ./docker-status.sh
# Opcoes:
#   --watch N       Atualiza a cada N segundos (modo live)
#   --containers    Mostra apenas containers
#   --images        Mostra apenas imagens
#   --volumes       Mostra apenas volumes
#   --help          Mostra esta ajuda
#   --version       Mostra versao

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




WATCH_INTERVAL=0
SHOW_CONTAINERS=false
SHOW_IMAGES=false
SHOW_VOLUMES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch|-w)
            [[ -z "${2-}" ]] && { echo "Flag --watch requer um valor" >&2; exit 1; }
            WATCH_INTERVAL="${2:-5}"; shift 2 ;;
        --containers|-c) SHOW_CONTAINERS=true; shift ;;
        --images|-i) SHOW_IMAGES=true; shift ;;
        --volumes|-v) SHOW_VOLUMES=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-status.sh — Painel resumido do Docker"
            echo ""
            echo "  Uso: ./docker-status.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --watch N       Atualiza a cada N segundos (modo live)"
            echo "    --containers    Mostra apenas containers"
            echo "    --images        Mostra apenas imagens"
            echo "    --volumes       Mostra apenas volumes"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-status.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

if ! $SHOW_CONTAINERS && ! $SHOW_IMAGES && ! $SHOW_VOLUMES; then
    SHOW_CONTAINERS=true
    SHOW_IMAGES=true
    SHOW_VOLUMES=true
fi

format_bytes() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "0 B"; return; fi
    if [ "$bytes" -ge 1073741824 ]; then echo "$(echo "scale=1; $bytes / 1073741824" | bc)GB"
    elif [ "$bytes" -ge 1048576 ]; then echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
    elif [ "$bytes" -ge 1024 ]; then echo "$((bytes / 1024))KB"
    else echo "${bytes}B"
    fi
}

show_status() {
    clear 2>/dev/null || true

    echo ""
    echo -e "  ${BOLD}Docker Status${RESET}  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo ""

    # -- Resumo geral --
    total_containers=$(docker ps -aq 2>/dev/null | wc -l | tr -d ' ')
    running_containers=$(docker ps -q 2>/dev/null | wc -l | tr -d ' ')
    stopped_containers=$((total_containers - running_containers))
    total_images=$(docker images -q 2>/dev/null | sort -u | wc -l | tr -d ' ')
    total_volumes=$(docker volume ls -q 2>/dev/null | wc -l | tr -d ' ')
    total_networks=$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')

    echo -e "  Containers:  ${GREEN}${BOLD}$running_containers${RESET} rodando  ${DIM}/  ${total_containers} total${RESET}"
    if [ "$stopped_containers" -gt 0 ]; then
        echo -e "              ${YELLOW}${stopped_containers} parado(s)${RESET}"
    fi
    echo -e "  Imagens:     ${BOLD}$total_images${RESET}"
    echo -e "  Volumes:     ${BOLD}$total_volumes${RESET}"
    echo -e "  Networks:    ${BOLD}$total_networks${RESET}"

    # -- Disco --
    docker system df 2>/dev/null | tail -n +2 | while IFS= read -r line; do
        type_name=$(echo "$line" | awk '{print $1}')
        size_val=$(echo "$line" | awk '{print $2}')
        echo -e "  ${DIM}$type_name: $size_val${RESET}"
    done

    echo ""

    # -- Containers --
    if $SHOW_CONTAINERS && [ "$total_containers" -gt 0 ]; then
        echo -e "  ${BOLD}── Containers ──${RESET}"
        echo ""
        printf "  %-14s %-22s %-18s %-8s %-10s %s\n" "ID" "NOME" "IMAGEM" "STATUS" "PORTAS" "CPU/MEM"
        printf "  %-14s %-22s %-18s %-8s %-10s %s\n" "──────────" "──────────────────" "────────────────" "──────" "─────────" "──────"

        docker ps -a --format '{{.ID}}|{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' 2>/dev/null | while IFS='|' read -r id name image status ports; do
            short_id="${id:0:12}"
            short_name=$(echo "$name" | cut -c1-20)
            short_image=$(echo "$image" | cut -c1-16)

            is_running=false
            case "$status" in
                Up*) is_running=true ;;
            esac

            # CPU/MEM para containers rodando
            cpu_mem=""
            if $is_running; then
                stats=$(docker stats --no-stream --format "{{.CPUPerc}}/{{.MemUsage}}" "$id" 2>/dev/null | head -1)
                if [ -n "$stats" ]; then
                    cpu_mem=$(echo "$stats" | awk -F'/' '{print $1 "/" $2}' | cut -c1-20)
                fi
            fi

            if $is_running; then
                status_color="${GREEN}"
            else
                status_color="${RED}"
                status="Stopped"
            fi

            short_ports=""
            if [ -n "$ports" ]; then
                short_ports=$(echo "$ports" | cut -c1-9)
            fi

            printf "  ${status_color}%-14s${RESET} %-22s %-18s %-8s %-10s %s\n" \
                "$short_id" "$short_name" "$short_image" "$status_color$status${RESET}" "$short_ports" "$cpu_mem"
        done

        echo ""
    fi

    # -- Imagens --
    if $SHOW_IMAGES && [ "$total_images" -gt 0 ]; then
        echo -e "  ${BOLD}── Imagens ──${RESET}"
        echo ""
        printf "  %-20s %-14s %-12s %s\n" "REPOSITORIO" "TAG" "TAMANHO" "ID"
        printf "  %-20s %-14s %-12s %s\n" "──────────────────" "────────────" "──────────" "──────────"

        docker images --format '{{.Repository}}|{{.Tag}}|{{.Size}}|{{.ID}}' 2>/dev/null | while IFS='|' read -r repo tag size id; do
            short_repo=$(echo "$repo" | cut -c1-18)
            short_tag=$(echo "$tag" | cut -c1-12)
            short_id="${id:0:12}"
            printf "  %-20s %-14s %-12s %s\n" "$short_repo" "$short_tag" "$size" "$short_id"
        done

        echo ""
    fi

    # -- Volumes --
    if $SHOW_VOLUMES && [ "$total_volumes" -gt 0 ]; then
        echo -e "  ${BOLD}── Volumes ──${RESET}"
        echo ""
        printf "  %-30s %-12s %s\n" "NOME" "DRIVER" "MOUNTPOINT"
        printf "  %-30s %-12s %s\n" "────────────────────────────" "──────────" "──────────────────"

        docker volume ls --format '{{.Name}}|{{.Driver}}|{{.Mountpoint}}' 2>/dev/null | while IFS='|' read -r name driver mount; do
            short_name=$(echo "$name" | cut -c1-28)
            short_mount=$(echo "$mount" | cut -c1-30)
            printf "  %-30s %-12s %s\n" "$short_name" "$driver" "$short_mount"
        done

        echo ""
    fi
}

if [ "$WATCH_INTERVAL" -gt 0 ]; then
    while true; do
        show_status
        echo -e "  ${DIM}Atualizando a cada ${WATCH_INTERVAL}s — Ctrl+C para sair${RESET}"
        sleep "$WATCH_INTERVAL"
    done
else
    show_status
fi