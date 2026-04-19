#!/bin/bash
# stopwatch.sh — Cronometro com voltas (laps)
# Uso: ./stopwatch.sh [opcoes]
# Opcoes:
#   --laps              Mostra voltas da ultima sessao
#   --help              Mostra esta ajuda
#   --version           Mostra versao

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


DATA_DIR="$HOME/.config/stopwatch"
mkdir -p "$DATA_DIR"
LAPS_FILE="$DATA_DIR/laps.csv"

ACTION="run"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --laps|-l) ACTION="laps"; shift ;;
        --help|-h)
            echo ""
            echo "  stopwatch.sh — Cronometro com voltas (laps)"
            echo ""
            echo "  Uso: ./stopwatch.sh [opcoes]"
            echo ""
            echo "  Comandos durante execucao:"
            echo "    l - Marcar volta (lap)"
            echo "    p - Pausar/Retomar"
            echo "    q - Sair"
            echo ""
            echo "  Opcoes:"
            echo "    --laps    Mostra voltas da ultima sessao"
            echo "    --help    Mostra esta ajuda"
            echo "    --version Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "stopwatch.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

format_elapsed() {
    local total=$1
    local hrs=$((total / 360000))
    local mins=$(( (total % 360000) / 6000 ))
    local secs=$(( (total % 6000) / 100 ))
    local cs=$((total % 100))
    printf "%02d:%02d:%02d.%02d" "$hrs" "$mins" "$secs" "$cs"
}

if [ "$ACTION" = "laps" ]; then
    if [ ! -f "$LAPS_FILE" ] || [ ! -s "$LAPS_FILE" ]; then
        echo ""
        echo -e "  ${DIM}Nenhuma volta registrada.${RESET}"
        echo ""
        exit 0
    fi
    echo ""
    echo -e "  ${BOLD}── Voltas (Laps) ──${RESET}"
    echo ""
    printf "  %-6s %-16s %-16s\n" "VOLTA" "TEMPO VOLTA" "TEMPO TOTAL"
    printf "  %-6s %-16s %-16s\n" "──────" "────────────────" "────────────────"
    tail -n +2 "$LAPS_FILE" | while IFS=',' read -r lap_num lap_time total_time; do
        printf "  ${CYAN}#%-5s${RESET} %-16s %-16s\n" "$lap_num" "$lap_time" "$total_time"
    done
    echo ""
    exit 0
fi

echo ""
echo -e "  ${BOLD}Stopwatch${RESET}  ${DIM}v$VERSION${RESET}"
echo ""
echo -e "  ${CYAN}l${RESET} = volta | ${CYAN}p${RESET} = pausar/retomar | ${CYAN}q${RESET} = sair"
echo ""

echo "volta,tempo_volta,tempo_total" > "$LAPS_FILE"

START=$(date '+%s%2N')
PAUSED=false
PAUSE_START=0
TOTAL_PAUSED=0
LAP_START=$START
LAP_COUNT=0

cleanup() {
    echo ""
    echo -e "  ${DIM}Cronometro finalizado.${RESET}"
    if [ "$LAP_COUNT" -gt 0 ]; then
        echo -e "  ${DIM}Use --laps para ver as voltas registradas.${RESET}"
    fi
    echo ""
    exit 0
}
trap cleanup INT

while true; do
    if ! $PAUSED; then
        NOW=$(date '+%s%2N')
        ELAPSED=$((NOW - START - TOTAL_PAUSED))

        DISPLAY=$(format_elapsed "$ELAPSED")

        LAP_ELAPSED=$((NOW - LAP_START - TOTAL_PAUSED))
        LAP_DISPLAY=$(format_elapsed "$LAP_ELAPSED")

        echo -en "\r  ⏱  ${BOLD}${DISPLAY}${RESET}  ${DIM}| Volta: ${LAP_DISPLAY}${RESET}    "
    fi

    read -t 0.1 -n 1 key 2>/dev/null || true

    case "$key" in
        l|L)
            NOW=$(date '+%s%2N')
            LAP_ELAPSED=$((NOW - LAP_START - TOTAL_PAUSED))
            TOTAL_AT_LAP=$((NOW - START - TOTAL_PAUSED))
            LAP_COUNT=$((LAP_COUNT + 1))

            LAP_STR=$(format_elapsed "$LAP_ELAPSED")
            TOTAL_STR=$(format_elapsed "$TOTAL_AT_LAP")

            echo ""
            echo -e "  ${GREEN}Volta #${LAP_COUNT}${RESET}  ${CYAN}${LAP_STR}${RESET}  ${DIM}(total: ${TOTAL_STR})${RESET}"

            echo "${LAP_COUNT},${LAP_STR},${TOTAL_STR}" >> "$LAPS_FILE"

            LAP_START=$NOW
            ;;
        p|P)
            if $PAUSED; then
                PAUSE_DURATION=$(( $(date '+%s%2N') - PAUSE_START ))
                TOTAL_PAUSED=$((TOTAL_PAUSED + PAUSE_DURATION))
                PAUSED=false
                echo ""
                echo -e "  ${GREEN}▶ Retomado${RESET}"
            else
                PAUSE_START=$(date '+%s%2N')
                PAUSED=true
                echo ""
                echo -e "  ${YELLOW}⏸ Pausado${RESET}"
            fi
            ;;
        q|Q)
            cleanup
            ;;
    esac
done