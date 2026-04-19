#!/bin/bash
# volume.sh — Controle de volume e mute via PulseAudio/PipeWire
# Uso: ./volume.sh [opcoes]
# Opcoes:
#   -u, --up N           Aumenta volume em N% (padrao: 5)
#   -d, --down N         Diminui volume em N% (padrao: 5)
#   -s, --set N          Define volume para N%
#   --mute               Alterna mute
#   --get                Mostra volume atual (padrao)
#   --source             Opera no microfone (padrao: speaker)
#   --list               Lista dispositivos de audio
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


ACTION="get"
VALUE="5"
DEVICE="sink"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--up)
            [[ -z "${2-}" ]] && { echo "Flag --up requer um valor" >&2; exit 1; }
            ACTION="up"; VALUE="${2:-5}"; shift 2 ;;
        -d|--down)
            [[ -z "${2-}" ]] && { echo "Flag --down requer um valor" >&2; exit 1; }
            ACTION="down"; VALUE="${2:-5}"; shift 2 ;;
        -s|--set)
            [[ -z "${2-}" ]] && { echo "Flag --set requer um valor" >&2; exit 1; }
            ACTION="set"; VALUE="$2"; shift 2 ;;
        --mute|-m) ACTION="mute"; shift ;;
        --get|-g) ACTION="get"; shift ;;
        --source) DEVICE="source"; shift ;;
        --list|-l) ACTION="list"; shift ;;
        --help|-h)
            echo ""
            echo "  volume.sh — Controle de volume via PulseAudio/PipeWire"
            echo ""
            echo "  Uso: ./volume.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -u, --up N      Aumenta volume em N% (padrao: 5)"
            echo "    -d, --down N    Diminui volume em N% (padrao: 5)"
            echo "    -s, --set N     Define volume para N%"
            echo "    --mute          Alterna mute"
            echo "    --get           Mostra volume atual"
            echo "    --source        Opera no microfone"
            echo "    --list          Lista dispositivos de audio"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./volume.sh --get"
            echo "    ./volume.sh -u 10"
            echo "    ./volume.sh --mute"
            echo "    ./volume.sh -s 75"
            echo ""
            exit 0
            ;;
        --version|-V) echo "volume.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

detect_backend() {
    if command -v wpctl &>/dev/null; then
        echo "wireplumber"
    elif command -v pactl &>/dev/null; then
        echo "pulseaudio"
    elif command -v amixer &>/dev/null; then
        echo "alsa"
    else
        echo "none"
    fi
}

backend=$(detect_backend)

if [ "$backend" = "none" ]; then
    echo ""
    echo -e "  ${RED}Nenhum controlador de audio encontrado.${RESET}"
    echo -e "  ${DIM}Instale: pipewire-pulse, pulseaudio ou alsa-utils${RESET}"
    echo ""
    exit 1
fi

get_default_sink() {
    case "$backend" in
        wireplumber) wpctl status 2>/dev/null | grep -A1 'Audio' | grep -oP '\d+\.' | head -1 | tr -d '.' ;;
        pulseaudio) pactl get-default-sink 2>/dev/null ;;
        alsa) echo "default" ;;
    esac
}

get_volume() {
    local dev_type="$1"
    case "$backend" in
        wireplumber)
            if [ "$dev_type" = "source" ]; then
                wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | awk '{print $2}' | xargs -I{} echo "{} * 100" | bc | cut -d'.' -f1
            else
                wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}' | xargs -I{} echo "{} * 100" | bc | cut -d'.' -f1
            fi
            ;;
        pulseaudio)
            if [ "$dev_type" = "source" ]; then
                local src=$(pactl get-default-source 2>/dev/null || pactl list short sources 2>/dev/null | head -1 | awk '{print $2}')
                pactl get-source-volume "$src" 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
            else
                local sink=$(pactl get-default-sink 2>/dev/null)
                pactl get-sink-volume "$sink" 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
            fi
            ;;
        alsa)
            if [ "$dev_type" = "source" ]; then
                amixer get Capture 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
            else
                amixer get Master 2>/dev/null | grep -oP '\d+%' | head -1 | tr -d '%'
            fi
            ;;
    esac
}

get_mute_status() {
    local dev_type="$1"
    case "$backend" in
        wireplumber)
            if [ "$dev_type" = "source" ]; then
                wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED && echo "yes" || echo "no"
            else
                wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -q MUTED && echo "yes" || echo "no"
            fi
            ;;
        pulseaudio)
            if [ "$dev_type" = "source" ]; then
                local src=$(pactl get-default-source 2>/dev/null || pactl list short sources 2>/dev/null | head -1 | awk '{print $2}')
                pactl get-source-mute "$src" 2>/dev/null | grep -q yes && echo "yes" || echo "no"
            else
                local sink=$(pactl get-default-sink 2>/dev/null)
                pactl get-sink-mute "$sink" 2>/dev/null | grep -q yes && echo "yes" || echo "no"
            fi
            ;;
        alsa)
            if [ "$dev_type" = "source" ]; then
                amixer get Capture 2>/dev/null | grep -q '\[off\]' && echo "yes" || echo "no"
            else
                amixer get Master 2>/dev/null | grep -q '\[off\]' && echo "yes" || echo "no"
            fi
            ;;
    esac
}

set_volume_pct() {
    local pct="$1"
    local dev_type="$2"
    case "$backend" in
        wireplumber)
            if [ "$dev_type" = "source" ]; then
                wpctl set-volume @DEFAULT_AUDIO_SOURCE@ "${pct}%" 2>/dev/null
            else
                wpctl set-volume @DEFAULT_AUDIO_SINK@ "${pct}%" 2>/dev/null
            fi
            ;;
        pulseaudio)
            if [ "$dev_type" = "source" ]; then
                local src=$(pactl get-default-source 2>/dev/null || pactl list short sources 2>/dev/null | head -1 | awk '{print $2}')
                pactl set-source-volume "$src" "${pct}%" 2>/dev/null
            else
                local sink=$(pactl get-default-sink 2>/dev/null)
                pactl set-sink-volume "$sink" "${pct}%" 2>/dev/null
            fi
            ;;
        alsa)
            if [ "$dev_type" = "source" ]; then
                amixer set Capture "${pct}%" 2>/dev/null
            else
                amixer set Master "${pct}%" 2>/dev/null
            fi
            ;;
    esac
}

toggle_mute() {
    local dev_type="$1"
    case "$backend" in
        wireplumber)
            if [ "$dev_type" = "source" ]; then
                wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle 2>/dev/null
            else
                wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
            fi
            ;;
        pulseaudio)
            if [ "$dev_type" = "source" ]; then
                local src=$(pactl get-default-source 2>/dev/null || pactl list short sources 2>/dev/null | head -1 | awk '{print $2}')
                pactl set-source-mute "$src" toggle 2>/dev/null
            else
                local sink=$(pactl get-default-sink 2>/dev/null)
                pactl set-sink-mute "$sink" toggle 2>/dev/null
            fi
            ;;
        alsa)
            if [ "$dev_type" = "source" ]; then
                amixer set Capture toggle 2>/dev/null
            else
                amixer set Master toggle 2>/dev/null
            fi
            ;;
    esac
}

show_volume_bar() {
    local vol="$1"
    local muted="$2"
    local label="$3"

    local bar_filled=$((vol / 5))
    local bar_empty=$((20 - bar_filled))
    bar=""
    for ((i=0; i<20; i++)); do
        if [ $i -lt $bar_filled ]; then bar="${bar}█"; else bar="${bar}░"; fi
    done

    if [ "$muted" = "yes" ]; then
        echo -e "  ${DIM}${bar}${RESET}  ${DIM}${BOLD}MUTED${RESET}  ${DIM}(${label})${RESET}"
    else
        local color="$GREEN"
        [ "$vol" -gt 100 ] && color="$RED"
        [ "$vol" -gt 80 ] && color="$YELLOW"
        echo -e "  ${color}${bar}${RESET}  ${BOLD}${vol}%${RESET}  ${DIM}(${label})${RESET}"
    fi
}

case "$ACTION" in
    get)
        vol=$(get_volume "$DEVICE")
        muted=$(get_mute_status "$DEVICE")
        [ -z "$vol" ] && vol=0
        label=$([ "$DEVICE" = "source" ] && echo "microfone" || echo "speaker")
        echo ""
        echo -e "  ${BOLD}── Volume ──${RESET}"
        echo ""
        show_volume_bar "$vol" "$muted" "$label"
        echo -e "  ${DIM}Backend: ${backend}${RESET}"
        echo ""
        ;;

    up)
        current=$(get_volume "$DEVICE")
        new=$((current + VALUE))
        [ "$new" -gt 150 ] && new=150
        set_volume_pct "$new" "$DEVICE"
        muted=$(get_mute_status "$DEVICE")
        label=$([ "$DEVICE" = "source" ] && echo "microfone" || echo "speaker")
        show_volume_bar "$new" "$muted" "$label"
        ;;

    down)
        current=$(get_volume "$DEVICE")
        new=$((current - VALUE))
        [ "$new" -lt 0 ] && new=0
        set_volume_pct "$new" "$DEVICE"
        muted=$(get_mute_status "$DEVICE")
        label=$([ "$DEVICE" = "source" ] && echo "microfone" || echo "speaker")
        show_volume_bar "$new" "$muted" "$label"
        ;;

    set)
        if ! [[ "$VALUE" =~ ^[0-9]+$ ]]; then
            echo -e "  ${RED}Valor invalido.${RESET}"
            exit 1
        fi
        [ "$VALUE" -gt 150 ] && VALUE=150
        set_volume_pct "$VALUE" "$DEVICE"
        muted=$(get_mute_status "$DEVICE")
        label=$([ "$DEVICE" = "source" ] && echo "microfone" || echo "speaker")
        show_volume_bar "$VALUE" "$muted" "$label"
        ;;

    mute)
        toggle_mute "$DEVICE"
        muted=$(get_mute_status "$DEVICE")
        vol=$(get_volume "$DEVICE")
        label=$([ "$DEVICE" = "source" ] && echo "microfone" || echo "speaker")
        if [ "$muted" = "yes" ]; then
            echo -e "  ${DIM}🔇 ${label} mutado${RESET}"
        else
            echo -e "  ${GREEN}🔊 ${label} ativo (${vol}%)${RESET}"
        fi
        ;;

    list)
        echo ""
        echo -e "  ${BOLD}── Dispositivos de Audio ──${RESET}"
        echo ""
        case "$backend" in
            wireplumber) wpctl status 2>/dev/null ;;
            pulseaudio)
                echo -e "  ${CYAN}Sinks (saida):${RESET}"
                pactl list short sinks 2>/dev/null | while read -r id name rest; do
                    printf "    %-4s %s\n" "$id" "$name"
                done
                echo ""
                echo -e "  ${CYAN}Sources (entrada):${RESET}"
                pactl list short sources 2>/dev/null | while read -r id name rest; do
                    printf "    %-4s %s\n" "$id" "$name"
                done
                ;;
            alsa)
                amixer devices 2>/dev/null || echo "  Nao foi possivel listar dispositivos"
                ;;
        esac
        echo ""
        ;;
esac