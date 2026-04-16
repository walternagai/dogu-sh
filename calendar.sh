#!/bin/bash
# calendar.sh — Calendario mensal com marcacao de eventos
# Uso: ./calendar.sh [opcoes]
# Opcoes:
#   -m, --month MES      Mes (1-12, padrao: atual)
#   -y, --year ANO       Ano (padrao: atual)
#   -a, --add DATA MSG   Adiciona evento (YYYY-MM-DD MSG)
#   -r, --remove ID      Remove evento por ID
#   --events             Lista eventos do mes
#   --help               Mostra esta ajuda
#   --version            Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DATA_DIR="$HOME/.config/calendar"
mkdir -p "$DATA_DIR"
EVENTS_FILE="$DATA_DIR/events.csv"

TARGET_MONTH=""
TARGET_YEAR=""
ADD_EVENT=""
REMOVE_ID=""
SHOW_EVENTS=false

while [ $# -gt 0 ]; do
    case "$1" in
        -m|--month) TARGET_MONTH="$2"; shift 2 ;;
        -y|--year) TARGET_YEAR="$2"; shift 2 ;;
        -a|--add) ADD_EVENT="$2"; shift 2 ;;
        -r|--remove) REMOVE_ID="$2"; shift 2 ;;
        --events|-e) SHOW_EVENTS=true; shift ;;
        --help|-h)
            echo ""
            echo "  calendar.sh — Calendario mensal com marcacao de eventos"
            echo ""
            echo "  Uso: ./calendar.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -m, --month MES     Mes (1-12, padrao: atual)"
            echo "    -y, --year ANO      Ano (padrao: atual)"
            echo "    -a, --add DATA MSG  Adiciona evento (YYYY-MM-DD MSG)"
            echo "    -r, --remove ID     Remove evento por ID"
            echo "    --events            Lista eventos do mes"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./calendar.sh"
            echo "    ./calendar.sh -m 12 -y 2025"
            echo "    ./calendar.sh -a '2025-12-25 Natal'"
            echo "    ./calendar.sh --events"
            echo ""
            exit 0
            ;;
        --version|-v) echo "calendar.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if [ ! -f "$EVENTS_FILE" ]; then
    echo "id,data,mensagem" > "$EVENTS_FILE"
fi

[ -z "$TARGET_MONTH" ] && TARGET_MONTH=$(date '+%m')
[ -z "$TARGET_YEAR" ] && TARGET_YEAR=$(date '+%Y')

TARGET_MONTH=$(printf '%02d' "$TARGET_MONTH")

if [ -n "$ADD_EVENT" ]; then
    event_date=$(echo "$ADD_EVENT" | awk '{print $1}')
    event_msg=$(echo "$ADD_EVENT" | sed "s/^${event_date} //")
    next_id=$(tail -n +2 "$EVENTS_FILE" | wc -l | tr -d ' ')
    next_id=$((next_id + 1))
    echo "${next_id},${event_date},${event_msg}" >> "$EVENTS_FILE"
    echo -e "  ${GREEN}✓${RESET} Evento adicionado: ${CYAN}${event_date}${RESET} ${event_msg}"
    exit 0
fi

if [ -n "$REMOVE_ID" ]; then
    tmp_file=$(mktemp)
    head -1 "$EVENTS_FILE" > "$tmp_file"
    grep -v "^${REMOVE_ID}," "$EVENTS_FILE" | tail -n +2 >> "$tmp_file"
    mv "$tmp_file" "$EVENTS_FILE"
    echo -e "  ${GREEN}✓${RESET} Evento #${REMOVE_ID} removido"
    exit 0
fi

get_day_name() {
    case "$1" in
        0) echo "Dom" ;; 1) echo "Seg" ;; 2) echo "Ter" ;;
        3) echo "Qua" ;; 4) echo "Qui" ;; 5) echo "Sex" ;; 6) echo "Sab" ;;
    esac
}

get_month_name() {
    case "$1" in
        01) echo "Janeiro" ;; 02) echo "Fevereiro" ;; 03) echo "Marco" ;;
        04) echo "Abril" ;; 05) echo "Maio" ;; 06) echo "Junho" ;;
        07) echo "Julho" ;; 08) echo "Agosto" ;; 09) echo "Setembro" ;;
        10) echo "Outubro" ;; 11) echo "Novembro" ;; 12) echo "Dezembro" ;;
    esac
}

day_of_week() {
    local d="$1" m="$2" y="$3"
    if [ "$m" -le 2 ]; then
        m=$((m + 12))
        y=$((y - 1))
    fi
    local K=$((y % 100))
    local J=$((y / 100))
    local h=$(( (d + (13 * (m + 1)) / 5 + K + K / 4 + J / 4 - 2 * J) % 7 ))
    if [ "$h" -lt 0 ]; then h=$((h + 7)); fi
    local dow=$(( (h + 6) % 7 ))
    echo $dow
}

days_in_month() {
    local m="$1" y="$2"
    case "$m" in
        01|03|05|07|08|10|12) echo 31 ;;
        04|06|09|11) echo 30 ;;
        02)
            if [ $((y % 4)) -eq 0 ] && { [ $((y % 100)) -ne 0 ] || [ $((y % 400)) -eq 0 ]; }; then
                echo 29
            else echo 28
            fi
            ;;
    esac
}

first_dow=$(day_of_week 1 "$TARGET_MONTH" "$TARGET_YEAR")
total_days=$(days_in_month "$TARGET_MONTH" "$TARGET_YEAR")
today_d=$(date '+%d')
today_m=$(date '+%m')
today_y=$(date '+%Y')
month_name=$(get_month_name "$TARGET_MONTH")

declare -A EVENT_DAYS
if [ -f "$EVENTS_FILE" ]; then
    while IFS=',' read -r id date msg; do
        [ "$id" = "id" ] && continue
        event_day=$(echo "$date" | cut -d'-' -f3 | sed 's/^0//')
        event_month=$(echo "$date" | cut -d'-' -f2)
        event_year=$(echo "$date" | cut -d'-' -f1)
        if [ "$event_month" = "$TARGET_MONTH" ] && [ "$event_year" = "$TARGET_YEAR" ]; then
            EVENT_DAYS[$event_day]="$msg"
        fi
    done < "$EVENTS_FILE"
fi

echo ""
echo -e "  ${BOLD}    ${month_name} ${TARGET_YEAR}${RESET}"
echo ""
echo -e "  ${DIM}Dom  Seg  Ter  Qua  Qui  Sex  Sab${RESET}"
echo -e "  ${DIM}─────────────────────────────────${RESET}"

row="  "
for ((i=0; i<first_dow; i++)); do
    row="${row}     "
done

for ((d=1; d<=total_days; d++)); do
    d_str=$(printf '%2d' "$d")

    is_today=false
    has_event=false

    if [ "$d" -eq "$today_d" ] && [ "$TARGET_MONTH" = "$today_m" ] && [ "$TARGET_YEAR" = "$today_y" ]; then
        is_today=true
    fi

    if [ -n "${EVENT_DAYS[$d]}" ]; then
        has_event=true
    fi

    if $is_today && $has_event; then
        cell="${YELLOW}${BOLD}[${d_str}]${RESET}"
    elif $is_today; then
        cell="${GREEN}${BOLD} ${d_str}${RESET} "
    elif $has_event; then
        cell="${CYAN} ${d_str}*${RESET}"
    else
        cell=" ${d_str}  "
    fi

    row="${row}${cell}"

    col=$(( (first_dow + d) % 7 ))
    if [ "$col" -eq 0 ] || [ "$d" -eq "$total_days" ]; then
        echo -e "$row"
        row="  "
    fi
done

echo -e "  ${DIM}─────────────────────────────────${RESET}"

event_count=${#EVENT_DAYS[@]}
if [ "$event_count" -gt 0 ]; then
    echo ""
    echo -e "  ${CYAN}*${RESET} = dia com evento"
fi

echo ""

if $SHOW_EVENTS; then
    echo -e "  ${BOLD}── Eventos de ${month_name} ${TARGET_YEAR} ──${RESET}"
    echo ""
    if [ -f "$EVENTS_FILE" ]; then
        found=false
        while IFS=',' read -r id date msg; do
            [ "$id" = "id" ] && continue
            event_month=$(echo "$date" | cut -d'-' -f2)
            event_year=$(echo "$date" | cut -d'-' -f1)
            if [ "$event_month" = "$TARGET_MONTH" ] && [ "$event_year" = "$TARGET_YEAR" ]; then
                found=true
                echo -e "  ${CYAN}#${id}${RESET}  ${DIM}${date}${RESET}  ${msg}"
            fi
        done < "$EVENTS_FILE"
        if ! $found; then
            echo -e "  ${DIM}Nenhum evento neste mes.${RESET}"
        fi
    else
        echo -e "  ${DIM}Nenhum evento registrado.${RESET}"
    fi
    echo ""
fi