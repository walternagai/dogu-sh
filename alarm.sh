#!/bin/bash
# alarm.sh — Alarme e cronometro com notificacoes
# Uso: ./alarm.sh [opcoes]
# Opcoes:
#   -t, --time TIME      Hora do alarme (HH:MM) ou duracao (Nm, Nh, Ns)
#   -m, --message MSG    Mensagem do alarme (padrao: Alarme!)
#   --list               Lista alarmes ativos
#   --cancel N           Cancela alarme N
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


DATA_DIR="$HOME/.config/alarm"
mkdir -p "$DATA_DIR"
ALARMS_DIR="$DATA_DIR/alarms"
mkdir -p "$ALARMS_DIR"

ALARM_TIME=""
ALARM_MSG="Alarme!"
LIST_ALARMS=false
CANCEL_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--time)
            [[ -z "${2-}" ]] && { echo "Flag --time requer um valor" >&2; exit 1; }
            ALARM_TIME="$2"; shift 2 ;;
        -m|--message)
            [[ -z "${2-}" ]] && { echo "Flag --message requer um valor" >&2; exit 1; }
            ALARM_MSG="$2"; shift 2 ;;
        --list|-l) LIST_ALARMS=true; shift ;;
        --cancel|-c)
            [[ -z "${2-}" ]] && { echo "Flag --cancel requer um valor" >&2; exit 1; }
            CANCEL_ID="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  alarm.sh — Alarme e cronometro com notificacoes"
            echo ""
            echo "  Uso: ./alarm.sh -t TEMPO [-m MENSAGEM]"
            echo ""
            echo "  Opcoes:"
            echo "    -t, --time TIME    Hora (HH:MM) ou duracao (10m, 2h, 30s)"
            echo "    -m, --message MSG  Mensagem do alarme (padrao: Alarme!)"
            echo "    --list             Lista alarmes ativos"
            echo "    --cancel N         Cancela alarme N"
            echo "    --help             Mostra esta ajuda"
            echo "    --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./alarm.sh -t 07:30"
            echo "    ./alarm.sh -t 25m -m 'Pausa do cafe'"
            echo "    ./alarm.sh -t 2h -m 'Reuniao'"
            echo "    ./alarm.sh --list"
            echo ""
            exit 0
            ;;
        --version|-V) echo "alarm.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

play_alarm_sound() {
    if command -v paplay &>/dev/null; then
        for i in 1 2 3 4 5; do
            paplay /usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga 2>/dev/null || true
            sleep 0.5
        done
    elif command -v aplay &>/dev/null; then
        for i in 1 2 3 4 5; do
            aplay -q /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null || true
            sleep 0.3
        done
    elif command -v beep &>/dev/null; then
        beep -l 300 -r 5 -d 200 2>/dev/null || true
    else
        for i in 1 2 3 4 5; do
            printf '\a'
            sleep 0.5
        done
    fi
}

send_notify() {
    local title="$1"
    local body="$2"
    if command -v notify-send &>/dev/null; then
        notify-send -u critical "$title" "$body" 2>/dev/null || true
    fi
}

if [ -n "$CANCEL_ID" ]; then
    pid_file="$ALARMS_DIR/${CANCEL_ID}.pid"
    if [ -f "$pid_file" ]; then
        pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null || true
        rm -f "$pid_file" "$ALARMS_DIR/${CANCEL_ID}.info"
        echo -e "  ${GREEN}✓${RESET} Alarme #${CANCEL_ID} cancelado"
    else
        echo -e "  ${RED}Alarme #${CANCEL_ID} nao encontrado${RESET}"
    fi
    exit 0
fi

if $LIST_ALARMS; then
    echo ""
    echo -e "  ${BOLD}── Alarmes Ativos ──${RESET}"
    echo ""
    found=false
    for info_file in "$ALARMS_DIR"/*.info; do
        [ ! -f "$info_file" ] && continue
        found=true
        alarm_id=$(basename "$info_file" .info)
        pid_file="$ALARMS_DIR/${alarm_id}.pid"
        source "$info_file"
        pid=$(cat "$pid_file" 2>/dev/null || echo "?")
        running=""
        if kill -0 "$pid" 2>/dev/null; then
            running="${GREEN}ativo${RESET}"
        else
            running="${DIM}inativo${RESET}"
        fi
        printf "  #%s  %-8s  %-25s  %s\n" "$alarm_id" "$running" "$ALARM_TARGET_TIME" "$ALARM_MSG_PART"
    done
    if ! $found; then
        echo -e "  ${DIM}Nenhum alarme ativo.${RESET}"
    fi
    echo ""
    exit 0
fi

if [ -z "$ALARM_TIME" ]; then
    echo ""
    echo -e "  ${BOLD}Alarm${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Hora ou duracao (ex: 07:30, 25m, 2h): "
    read -r ALARM_TIME < /dev/tty
    printf "  Mensagem (Enter para 'Alarme!'): "
    read -r ALARM_MSG < /dev/tty
    ALARM_MSG="${ALARM_MSG:-Alarme!}"
fi

target_secs=0

if [[ "$ALARM_TIME" =~ ^([0-9]+):([0-9]+)$ ]]; then
    alarm_h=${BASH_REMATCH[1]}
    alarm_m=${BASH_REMATCH[2]}
    now_h=$(date '+%H')
    now_m=$(date '+%M')
    now_s=$(date '+%S')
    now_total=$((10#$now_h * 3600 + 10#$now_m * 60 + 10#$now_s))
    alarm_total=$((10#$alarm_h * 3600 + 10#$alarm_m * 60))
    target_secs=$((alarm_total - now_total))
    if [ "$target_secs" -le 0 ]; then
        target_secs=$((target_secs + 86400))
    fi
    target_display="$ALARM_TIME"
elif [[ "$ALARM_TIME" =~ ^([0-9]+)h$ ]]; then
    target_secs=$(( ${BASH_REMATCH[1]} * 3600 ))
    target_display="em ${BASH_REMATCH[1]}h"
elif [[ "$ALARM_TIME" =~ ^([0-9]+)m$ ]]; then
    target_secs=$(( ${BASH_REMATCH[1]} * 60 ))
    target_display="em ${BASH_REMATCH[1]}min"
elif [[ "$ALARM_TIME" =~ ^([0-9]+)s$ ]]; then
    target_secs=${BASH_REMATCH[1]}
    target_display="em ${BASH_REMATCH[1]}s"
else
    echo -e "  ${RED}Formato invalido: $ALARM_TIME${RESET}"
    echo -e "  ${DIM}Use HH:MM, Nm, Nh ou Ns${RESET}"
    exit 1
fi

alarm_id=$(date '+%s')
(
    sleep "$target_secs"
    play_alarm_sound
    send_notify "⏰ Alarme" "$ALARM_MSG"
    echo ""
    echo -e "  ${YELLOW}${BOLD}⏰ ${ALARM_MSG}${RESET}"
    echo -e "  ${DIM}$(date '+%H:%M:%S')${RESET}"
    echo ""
) &

echo "ALARM_TARGET_TIME=\"$target_display\"" > "$ALARMS_DIR/${alarm_id}.info"
echo "ALARM_MSG_PART=\"${ALARM_MSG:0:30}\"" >> "$ALARMS_DIR/${alarm_id}.info"
echo $! > "$ALARMS_DIR/${alarm_id}.pid"

echo ""
echo -e "  ${GREEN}✓${RESET} Alarme configurado: ${CYAN}${target_display}${RESET}"
echo -e "  ${DIM}Mensagem: ${ALARM_MSG}${RESET}"
echo -e "  ${DIM}ID: #${alarm_id} (use --cancel ${alarm_id} para cancelar)${RESET}"
echo ""