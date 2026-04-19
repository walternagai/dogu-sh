#!/bin/bash
# media-control.sh — Controla players MPRIS e mostra now playing
# Uso: ./media-control.sh [opcoes]
# Opcoes:
#   --play              Retoma reproducao
#   --pause             Pausa reproducao
#   --toggle            Alterna play/pause (padrao sem arg)
#   --next              Proxima faixa
#   --prev              Faixa anterior
#   --stop              Para reproducao
#   --status            Mostra status atual
#   --volume N          Define volume do player (0-100)
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
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi




ACTION="status"
VOLUME_VAL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --play) ACTION="play"; shift ;;
        --pause) ACTION="pause"; shift ;;
        --toggle|-t) ACTION="toggle"; shift ;;
        --next|-n) ACTION="next"; shift ;;
        --prev|-p) ACTION="prev"; shift ;;
        --stop) ACTION="stop"; shift ;;
        --status|-s) ACTION="status"; shift ;;
        --volume|-v)
            [[ -z "${2-}" ]] && { echo "Flag --volume requer um valor" >&2; exit 1; }
            ACTION="volume"; VOLUME_VAL="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  media-control.sh — Controla players MPRIS"
            echo ""
            echo "  Uso: ./media-control.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --play       Retoma reproducao"
            echo "    --pause      Pausa reproducao"
            echo "    --toggle     Alterna play/pause"
            echo "    --next       Proxima faixa"
            echo "    --prev       Faixa anterior"
            echo "    --stop       Para reproducao"
            echo "    --status     Mostra status atual"
            echo "    --volume N   Define volume (0-100)"
            echo "    --help       Mostra esta ajuda"
            echo "    --version    Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./media-control.sh --toggle"
            echo "    ./media-control.sh --next"
            echo "    ./media-control.sh --status"
            echo ""
            exit 0
            ;;
        --version|-V) echo "media-control.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v playerctl &>/dev/null; then
    check_and_install playerctl "$(detect_installer)" "playerctl" 2>/dev/null || { echo -e "${RED}[ERROR] playerctl necessario.${RESET}" >&2; exit 1; }
fi

get_players() {
    playerctl --list-all 2>/dev/null | grep -v 'No players' || echo ""
}

player=$(get_players | head -1)

if [ -z "$player" ]; then
    echo ""
    echo -e "  ${DIM}Nenhum player MPRIS ativo.${RESET}"
    echo -e "  ${DIM}Abra um player de musica/video e tente novamente.${RESET}"
    echo ""
    exit 0
fi

case "$ACTION" in
    play)
        playerctl --player="$player" play 2>/dev/null
        echo -e "  ${GREEN}▶${RESET} Reproduzindo"
        ;;

    pause)
        playerctl --player="$player" pause 2>/dev/null
        echo -e "  ${YELLOW}⏸${RESET} Pausado"
        ;;

    toggle)
        playerctl --player="$player" play-pause 2>/dev/null
        status=$(playerctl --player="$player" status 2>/dev/null)
        if [ "$status" = "Playing" ]; then
            echo -e "  ${GREEN}▶${RESET} Reproduzindo"
        else
            echo -e "  ${YELLOW}⏸${RESET} Pausado"
        fi
        ;;

    next)
        playerctl --player="$player" next 2>/dev/null
        echo -e "  ${GREEN}⏭${RESET} Proxima faixa"
        sleep 0.5
        ;;

    prev)
        playerctl --player="$player" previous 2>/dev/null
        echo -e "  ${GREEN}⏮${RESET} Faixa anterior"
        sleep 0.5
        ;;

    stop)
        playerctl --player="$player" stop 2>/dev/null
        echo -e "  ${DIM}⏹${RESET} Parado"
        ;;

    volume)
        if [ -z "$VOLUME_VAL" ] || ! [[ "$VOLUME_VAL" =~ ^[0-9]+$ ]]; then
            echo -e "  ${RED}Valor de volume invalido. Use 0-100.${RESET}"
            exit 1
        fi
        vol_frac=$(echo "scale=2; $VOLUME_VAL / 100" | bc)
        playerctl --player="$player" volume "$vol_frac" 2>/dev/null
        echo -e "  ${GREEN}🔊${RESET} Volume: ${VOLUME_VAL}%"
        ;;

    status)
        echo ""
        echo -e "  ${BOLD}── Media Player ──${RESET}"
        echo ""

        players_list=$(get_players)
        player_count=$(echo "$players_list" | wc -l | tr -d ' ')

        if [ "$player_count" -gt 1 ]; then
            echo -e "  ${DIM}Players ativos:${RESET}"
            echo "$players_list" | while read -r p; do
                p_status=$(playerctl --player="$p" status 2>/dev/null || echo "Desconhecido")
                p_track=$(playerctl --player="$p" metadata title 2>/dev/null || echo "?")
                printf "    %-20s %-10s %s\n" "$p" "[$p_status]" "${p_track:0:30}"
            done
            echo ""
        fi

        status=$(playerctl --player="$player" status 2>/dev/null || echo "Desconhecido")
        title=$(playerctl --player="$player" metadata title 2>/dev/null || echo "Desconhecido")
        artist=$(playerctl --player="$player" metadata artist 2>/dev/null || echo "")
        album=$(playerctl --player="$player" metadata album 2>/dev/null || echo "")
        length=$(playerctl --player="$player" metadata mpris:length 2>/dev/null || echo "")

        case "$status" in
            Playing) status_icon="${GREEN}▶${RESET}" ;;
            Paused) status_icon="${YELLOW}⏸${RESET}" ;;
            Stopped) status_icon="${DIM}⏹${RESET}" ;;
        --) shift; break ;;
            *) status_icon="${DIM}?${RESET}" ;;
        esac

        echo -e "  ${status_icon} ${BOLD}${status}${RESET}"
        echo -e "  ${CYAN}${title}${RESET}"
        [ -n "$artist" ] && echo -e "  ${DIM}${artist}${RESET}"
        [ -n "$album" ] && echo -e "  ${DIM}${album}${RESET}"

        if [ -n "$length" ]; then
            length_sec=$((length / 1000000))
            length_min=$((length_sec / 60))
            length_rem=$((length_sec % 60))
            echo -e "  ${DIM}Duracao: ${length_min}:${length_rem}%02d${RESET}"
        fi

        echo ""
        ;;
esac