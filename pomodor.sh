#!/bin/bash
# pomodor.sh — Timer Pomodoro com notificacoes (Linux)
# Uso: ./pomodor.sh
# Opcoes:
#   -w, --work MIN       Minutos de trabalho (padrao: 25)
#   -b, --break MIN      Minutos de pausa (padrao: 5)
#   -l, --long-break MIN Minutos de pausa longa (padrao: 15)
#   -c, --cycles N       Sessoes antes de pausa longa (padrao: 4)
#   --status            Mostra sessoes de hoje
#   --reset             Reseta contagem do dia
#   --no-sound          Desativa som
#   --help              Mostra esta ajuda
#   --version           Mostra versao

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

WORK_MINS=25
BREAK_MINS=5
LONG_BREAK_MINS=15
CYCLES_BEFORE_LONG=4
NO_SOUND=false
ACTION="run"
CLEAN_ALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        -w|--work) WORK_MINS="${2:-25}"; shift 2 ;;
        -b|--break) BREAK_MINS="${2:-5}"; shift 2 ;;
        -l|--long-break) LONG_BREAK_MINS="${2:-15}"; shift 2 ;;
        -c|--cycles) CYCLES_BEFORE_LONG="${2:-4}"; shift 2 ;;
        --status|-s) ACTION="status"; shift ;;
        --reset) ACTION="reset"; shift ;;
        --no-sound) NO_SOUND=true; shift ;;
        --help|-h)
            echo ""
            echo "  pomodor.sh — Timer Pomodoro com notificacoes"
            echo ""
            echo "  Uso: ./pomodor.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -w, --work MIN        Minutos de trabalho (padrao: 25)"
            echo "    -b, --break MIN       Minutos de pausa (padrao: 5)"
            echo "    -l, --long-break MIN  Minutos de pausa longa (padrao: 15)"
            echo "    -c, --cycles N        Sessoes antes de pausa longa (padrao: 4)"
            echo "    --status              Mostra sessoes de hoje"
            echo "    --reset               Reseta contagem do dia"
            echo "    --no-sound            Desativa som"
            echo "    --help                Mostra esta ajuda"
            echo "    --version             Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./pomodor.sh"
            echo "    ./pomodor.sh -w 50 -b 10"
            echo "    ./pomodor.sh --status"
            echo ""
            exit 0
            ;;
        --version|-v) echo "pomodor.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

DATA_DIR="$HOME/.config/pomodor"
mkdir -p "$DATA_DIR"

TODAY=$(date '+%Y-%m-%d')
HISTORY_FILE="$DATA_DIR/history.csv"

if [ ! -f "$HISTORY_FILE" ]; then
    echo "data,horario,tipo,minutos" > "$HISTORY_FILE"
fi

play_sound() {
    if $NO_SOUND; then
        return
    fi

    if command -v paplay &>/dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null & disown || true
    elif command -v aplay &>/dev/null; then
        (
            for i in 1 2 3; do
                aplay -q /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null || true
                sleep 0.3
            done
        ) & disown || true
    elif command -v beep &>/dev/null; then
        beep -l 200 -r 3 2>/dev/null & disown || true
    else
        printf '\a' 2>/dev/null || true
    fi
}

send_notify() {
    local title="$1"
    local body="$2"
    local urgency="${3:-normal}"

    if command -v notify-send &>/dev/null; then
        notify-send -u "$urgency" "$title" "$body" 2>/dev/null || true
    fi
}

count_today_sessions() {
    if [ -f "$HISTORY_FILE" ]; then
        awk -F',' -v d="$TODAY" '$1 == d && $3 == "trabalho" {count++} END {print count+0}' "$HISTORY_FILE"
    else
        echo 0
    fi
}

format_time() {
    local total_secs=$1
    local mins=$((total_secs / 60))
    local secs=$((total_secs % 60))
    printf "%02d:%02d" "$mins" "$secs"
}

show_progress() {
    local elapsed=$1
    local total=$2
    local label="$3"

    local remaining=$((total - elapsed))
    local pct=$((elapsed * 100 / total))

    local bar_filled=$((pct / 5))
    local bar_empty=$((20 - bar_filled))
    local bar=""
    local i=0
    while [ $i -lt 20 ]; do
        if [ $i -lt $bar_filled ]; then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
        i=$((i + 1))
    done

    printf "\r  %s [%s] %s restante    " "$label" "$bar" "$(format_time $remaining)"
}

case "$ACTION" in
    status)
        sessions=$(count_today_sessions)
        echo ""
        echo -e "  ${BOLD}Pomodor — Sessoes de hoje${RESET}"
        echo ""
        echo -e "  Sessoes de trabalho:  ${GREEN}${BOLD}$sessions${RESET}"
        echo -e "  Ciclo atual:         ${CYAN}$((sessions % CYCLES_BEFORE_LONG))/${CYCLES_BEFORE_LONG}${RESET}"

        if [ "$((sessions % CYCLES_BEFORE_LONG))" -eq 0 ] && [ "$sessions" -gt 0 ]; then
            echo -e "  Proximo:             ${YELLOW}PAUSA LONGA ($LONG_BREAK_MINS min)${RESET}"
        else
            echo -e "  Proximo:             Trabalho ($WORK_MINS min)"
        fi
        echo ""

        if [ -f "$HISTORY_FILE" ]; then
            echo -e "  ${BOLD}Historico de hoje:${RESET}"
            echo ""
            awk -F',' -v d="$TODAY" '$1 == d {printf "  %s  %-10s  %s min\n", $2, $3, $4}' "$HISTORY_FILE"
            echo ""
        fi
        ;;

    reset)
        if [ -f "$HISTORY_FILE" ]; then
            tmp_file=$(mktemp)
            awk -F',' -v d="$TODAY" '$1 != d' "$HISTORY_FILE" > "$tmp_file"
            echo "data,horario,tipo,minutos" > "$HISTORY_FILE"
            if [ -s "$tmp_file" ]; then
                tail -n +2 "$tmp_file" >> "$HISTORY_FILE"
            fi
            rm -f "$tmp_file"
        fi
        echo -e "  ${GREEN}✓${RESET} Contagem do dia resetada."
        echo ""
        ;;

    run)
        session_num=$(count_today_sessions)
        session_num=$((session_num + 1))

        echo ""
        echo -e "  ${BOLD}Pomodor — Sessao $session_num${RESET}"
        echo -e "  ${DIM}Trabalho: ${WORK_MINS}min | Pausa: ${BREAK_MINS}min | Longa: ${LONG_BREAK_MINS}min | Ciclo: ${CYCLES_BEFORE_LONG}${RESET}"
        echo ""

        while true; do
            session_type="trabalho"
            is_long_break=false

            if [ "$((session_num % CYCLES_BEFORE_LONG))" -eq 0 ] && [ "$session_num" -gt 0 ]; then
                current_mins=$LONG_BREAK_MINS
                session_type="pausa-longa"
                is_long_break=true
            elif [ "$((session_num % 2))" -eq 0 ]; then
                current_mins=$BREAK_MINS
                session_type="pausa"
            else
                current_mins=$WORK_MINS
                session_type="trabalho"
            fi

            total_secs=$((current_mins * 60))

            if $is_long_break; then
                echo -e "  ${YELLOW}${BOLD}PAUSA LONGA${RESET} — ${current_mins} minutos"
            elif [ "$session_type" = "pausa" ]; then
                echo -e "  ${GREEN}${BOLD}PAUSA${RESET} — ${current_mins} minutos"
            else
                echo -e "  ${RED}${BOLD}TRABALHO${RESET} — Sessao $session_num — ${current_mins} minutos"
            fi

            echo ""
            echo -e "  ${DIM}Pressione Ctrl+C para pular${RESET}"
            echo ""

            elapsed=0
            while [ $elapsed -lt $total_secs ]; do
                if [ "$session_type" = "trabalho" ]; then
                    show_progress $elapsed $total_secs "Trabalho"
                elif $is_long_break; then
                    show_progress $elapsed $total_secs "Pausa longa"
                else
                    show_progress $elapsed $total_secs "Pausa   "
                fi
                sleep 1
                elapsed=$((elapsed + 1))
            done

            echo ""

            now=$(date '+%H:%M:%S')
            echo "$TODAY,$now,$session_type,$current_mins" >> "$HISTORY_FILE"

            play_sound

            if [ "$session_type" = "trabalho" ]; then
                send_notify "Pomodor — Trabalho concluido" "Sessao $session_num finalizada. Hora da pausa!" "normal"
                echo -e "  ${GREEN}✓ Sessao $session_num concluida!${RESET} Hora da pausa."
            elif $is_long_break; then
                send_notify "Pomodor — Pausa longa concluida" "Voltando ao trabalho!" "critical"
                echo -e "  ${GREEN}✓ Pausa longa concluida!${RESET} Voltando ao trabalho."
            else
                send_notify "Pomodor — Pausa concluida" "Voltando ao trabalho!" "normal"
                echo -e "  ${GREEN}✓ Pausa concluida!${RESET} Voltando ao trabalho."
            fi

            echo ""

            total_sessions=$(count_today_sessions)
            echo -e "  ${DIM}Total hoje: $total_sessions sessoes | Ciclo: $((total_sessions % CYCLES_BEFORE_LONG))/${CYCLES_BEFORE_LONG}${RESET}"

            session_num=$((session_num + 1))

            if ! $CLEAN_ALL; then
                printf "  Continuar? [s/N]: "
                read -r cont < /dev/tty 2>/dev/null || cont="n"
                case "$cont" in
                    [sS]) ;;
                    *) echo -e "  ${DIM}Ate logo!${RESET}"; echo ""; break ;;
                esac
            fi

            echo ""
        done
        ;;
esac