#!/bin/bash
# world-clock.sh — Relogio com multiplos fusos horarios configuraveis
# Uso: ./world-clock.sh [opcoes]
# Opcoes:
#   -z, --zones ZONES    Lista de fusos separados por virgula
#   --add ZONE           Adiciona fuso horario a configuracao
#   --remove ZONE        Remove fuso horario da configuracao
#   --list               Lista fusos horarios disponiveis
#   --live               Modo continuo (atualiza a cada segundo)
#   --help               Mostra esta ajuda
#   --version            Mostra versao

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


DATA_DIR="$HOME/.config/world-clock"
mkdir -p "$DATA_DIR"
CONFIG_FILE="$DATA_DIR/zones.conf"

DEFAULT_ZONES="America/Sao_Paulo,America/New_York,Europe/London,Europe/Paris,Asia/Tokyo,Australia/Sydney"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "$DEFAULT_ZONES" > "$CONFIG_FILE"
fi

ZONES=""
ADD_ZONE=""
REMOVE_ZONE=""
LIST_ZONES=false
LIVE_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -z|--zones)
            [[ -z "${2-}" ]] && { echo "Flag --zones requer um valor" >&2; exit 1; }
            ZONES="$2"; shift 2 ;;
        --add)
            [[ -z "${2-}" ]] && { echo "Flag --add requer um valor" >&2; exit 1; }
            ADD_ZONE="$2"; shift 2 ;;
        --remove)
            [[ -z "${2-}" ]] && { echo "Flag --remove requer um valor" >&2; exit 1; }
            REMOVE_ZONE="$2"; shift 2 ;;
        --list|-l) LIST_ZONES=true; shift ;;
        --live) LIVE_MODE=true; shift ;;
        --help|-h)
            echo ""
            echo "  world-clock.sh — Relogio com multiplos fusos horarios"
            echo ""
            echo "  Uso: ./world-clock.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -z, --zones ZONES   Fusos separados por virgula"
            echo "    --add ZONE          Adiciona fuso a configuracao"
            echo "    --remove ZONE       Remove fuso da configuracao"
            echo "    --list              Lista fusos populares"
            echo "    --live              Modo continuo (atualiza a cada segundo)"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./world-clock.sh"
            echo "    ./world-clock.sh -z America/Sao_Paulo,Asia/Tokyo"
            echo "    ./world-clock.sh --add Europe/Berlin"
            echo "    ./world-clock.sh --live"
            echo ""
            exit 0
            ;;
        --version|-V) echo "world-clock.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if [ -n "$ADD_ZONE" ]; then
    current=$(cat "$CONFIG_FILE")
    if echo "$current" | grep -q "$ADD_ZONE"; then
        echo -e "  ${YELLOW}$ADD_ZONE ja esta na lista.${RESET}"
    else
        echo "${current},${ADD_ZONE}" >> "$CONFIG_FILE"
        echo -e "  ${GREEN}✓${RESET} $ADD_ZONE adicionado"
    fi
    exit 0
fi

if [ -n "$REMOVE_ZONE" ]; then
    current=$(cat "$CONFIG_FILE")
    new_zones=$(echo "$current" | tr ',' '\n' | grep -v "$REMOVE_ZONE" | tr '\n' ',' | sed 's/,$//')
    echo "$new_zones" > "$CONFIG_FILE"
    echo -e "  ${GREEN}✓${RESET} $REMOVE_ZONE removido"
    exit 0
fi

if $LIST_ZONES; then
    echo ""
    echo -e "  ${BOLD}── Fusos Horarios Populares ──${RESET}"
    echo ""
    echo -e "  ${CYAN}America${RESET}"
    echo "    America/Sao_Paulo    America/New_York    America/Los_Angeles"
    echo "    America/Chicago      America/Denver      America/Toronto"
    echo "    America/Mexico_City  America/Argentina/Buenos_Aires"
    echo ""
    echo -e "  ${CYAN}Europa${RESET}"
    echo "    Europe/London        Europe/Paris         Europe/Berlin"
    echo "    Europe/Moscow        Europe/Rome          Europe/Madrid"
    echo ""
    echo -e "  ${CYAN}Asia${RESET}"
    echo "    Asia/Tokyo           Asia/Shanghai        Asia/Dubai"
    echo "    Asia/Kolkata         Asia/Singapore       Asia/Seoul"
    echo ""
    echo -e "  ${CYAN}Oceania${RESET}"
    echo "    Australia/Sydney     Australia/Melbourne  Pacific/Auckland"
    echo ""
    exit 0
fi

if [ -z "$ZONES" ]; then
    ZONES=$(cat "$CONFIG_FILE")
fi

show_clock() {
    local now=$(date '+%Y-%m-%d %H:%M:%S')
    echo -en "\033[2J\033[H"
    echo ""
    echo -e "  ${BOLD}── World Clock ──${RESET}  ${DIM}${now}${RESET}"
    echo ""

    local local_tz=$(timedatectl show 2>/dev/null | grep '^Timezone=' | cut -d'=' -f2 || cat /etc/timezone 2>/dev/null || echo "UTC")
    local local_time=$(date '+%H:%M:%S')
    local local_date=$(date '+%a %d/%m')
    echo -e "  ${GREEN}${BOLD}⏰ Local${RESET}  ${local_time}  ${DIM}${local_date}  (${local_tz})${RESET}"
    echo ""

    IFS=',' read -ra ZONE_ARRAY <<< "$ZONES"
    for zone in "${ZONE_ARRAY[@]}"; do
        zone=$(echo "$zone" | xargs)
        [ -z "$zone" ] && continue

        if ! TZ="$zone" date &>/dev/null; then
            echo -e "  ${RED}✗ ${zone}${RESET} ${DIM}(fuso invalido)${RESET}"
            continue
        fi

        zone_time=$(TZ="$zone" date '+%H:%M:%S')
        zone_date=$(TZ="$zone" date '+%a %d/%m')
        zone_offset=$(TZ="$zone" date '+%z' | sed 's/.\{2\}$/&:/; s/::$//')
        short_name=$(echo "$zone" | awk -F'/' '{print $NF}' | tr '_' ' ')

        local_h=$(date '+%H' | sed 's/^0//')
        zone_h=$(TZ="$zone" date '+%H' | sed 's/^0//')
        diff=$((zone_h - local_h))
        if [ $diff -gt 12 ]; then diff=$((diff - 24)); elif [ $diff -lt -12 ]; then diff=$((diff + 24)); fi

        if [ "$diff" -gt 0 ]; then
            diff_str="+${diff}h"
        elif [ "$diff" -lt 0 ]; then
            diff_str="${diff}h"
        else
            diff_str="=0"
        fi

        printf "  %-20s %s  " "$short_name" "$zone_time"
        echo -e "${DIM}${zone_date}${RESET}  ${DIM}${diff_str}${RESET}"
    done

    echo ""
    echo -e "  ${DIM}Pressione Ctrl+C para sair${RESET}"
}

if $LIVE_MODE; then
    trap 'echo -e "\n\n  ${DIM}Ate logo!${RESET}\n"; exit 0' INT
    while true; do
        show_clock
        sleep 1
    done
else
    show_clock
fi