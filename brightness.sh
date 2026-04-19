#!/bin/bash
# brightness.sh — Controle de brilho do monitor
# Uso: ./brightness.sh [opcoes]
# Opcoes:
#   -u, --up N           Aumenta brilho em N% (padrao: 5)
#   -d, --down N         Diminui brilho em N% (padrao: 5)
#   -s, --set N          Define brilho para N%
#   --get                Mostra brilho atual
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
        --get|-g) ACTION="get"; shift ;;
        --help|-h)
            echo ""
            echo "  brightness.sh — Controle de brilho do monitor"
            echo ""
            echo "  Uso: ./brightness.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -u, --up N      Aumenta brilho em N% (padrao: 5)"
            echo "    -d, --down N    Diminui brilho em N% (padrao: 5)"
            echo "    -s, --set N     Define brilho para N% (0-100)"
            echo "    --get           Mostra brilho atual"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./brightness.sh --get"
            echo "    ./brightness.sh -u 10"
            echo "    ./brightness.sh -d 5"
            echo "    ./brightness.sh -s 80"
            echo ""
            exit 0
            ;;
        --version|-V) echo "brightness.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

detect_backend() {
    if command -v light &>/dev/null; then
        echo "light"
    elif command -v brightnessctl &>/dev/null; then
        echo "brightnessctl"
    elif command -v xrandr &>/dev/null && [ -n "$DISPLAY" ]; then
        echo "xrandr"
    elif [ -d "/sys/class/backlight" ] && [ -n "$(ls /sys/class/backlight/ 2>/dev/null)" ]; then
        echo "sysfs"
    else
        echo "none"
    fi
}

get_current() {
    local backend="$1"
    case "$backend" in
        light) light -G 2>/dev/null | cut -d'.' -f1 ;;
        brightnessctl) brightnessctl info 2>/dev/null | grep -oP '\(\K[0-9]+' | head -1 ;;
        xrandr)
            local monitor=$(xrandr 2>/dev/null | grep ' connected' | head -1 | awk '{print $1}')
            xrandr --verbose 2>/dev/null | grep -A10 "$monitor" | grep -i brightness | awk '{printf "%.0f", $2 * 100}'
            ;;
        sysfs)
            local bl=$(ls /sys/class/backlight/ | head -1)
            local cur=$(cat "/sys/class/backlight/$bl/brightness" 2>/dev/null || echo 0)
            local max=$(cat "/sys/class/backlight/$bl/max_brightness" 2>/dev/null || echo 100)
            echo $((cur * 100 / max))
            ;;
        --) shift; break ;;
        *) echo "0" ;;
    esac
}

set_brightness() {
    local backend="$1"
    local pct="$2"

    [ "$pct" -lt 1 ] && pct=1
    [ "$pct" -gt 100 ] && pct=100

    case "$backend" in
        light) light -S "$pct" 2>/dev/null ;;
        brightnessctl) brightnessctl set "${pct}%" 2>/dev/null ;;
        xrandr)
            local monitor=$(xrandr 2>/dev/null | grep ' connected' | head -1 | awk '{print $1}')
            local frac=$(echo "scale=2; $pct / 100" | bc)
            xrandr --output "$monitor" --brightness "$frac" 2>/dev/null
            ;;
        sysfs)
            local bl=$(ls /sys/class/backlight/ | head -1)
            local max=$(cat "/sys/class/backlight/$bl/max_brightness" 2>/dev/null || echo 100)
            local new_val=$((pct * max / 100))
            echo "$new_val" | sudo tee "/sys/class/backlight/$bl/brightness" &>/dev/null
            ;;
    esac
}

backend=$(detect_backend)

if [ "$backend" = "none" ]; then
    echo ""
    echo -e "  ${RED}Nenhum metodo de controle de brilho encontrado.${RESET}"
    echo -e "  ${DIM}Instale: light, brightnessctl ou xrandr${RESET}"
    echo ""
    exit 1
fi

current=$(get_current "$backend")

case "$ACTION" in
    get)
        echo ""
        echo -e "  ${BOLD}── Brightness ──${RESET}"
        echo ""
        bar_filled=$((current / 5))
        bar_empty=$((20 - bar_filled))
        bar=""
        for ((i=0; i<20; i++)); do
            if [ $i -lt $bar_filled ]; then bar="${bar}█"; else bar="${bar}░"; fi
        done
        echo -e "  ${CYAN}${bar}${RESET}  ${BOLD}${current}%${RESET}"
        echo -e "  ${DIM}Backend: ${backend}${RESET}"
        echo ""
        ;;

    up)
        new=$((current + VALUE))
        [ "$new" -gt 100 ] && new=100
        set_brightness "$backend" "$new"
        echo -e "  ${GREEN}✓${RESET} Brilho: ${current}% → ${new}%"
        ;;

    down)
        new=$((current - VALUE))
        [ "$new" -lt 1 ] && new=1
        set_brightness "$backend" "$new"
        echo -e "  ${GREEN}✓${RESET} Brilho: ${current}% → ${new}%"
        ;;

    set)
        if ! [[ "$VALUE" =~ ^[0-9]+$ ]] || [ "$VALUE" -lt 0 ] || [ "$VALUE" -gt 100 ]; then
            echo -e "  ${RED}Valor invalido. Use 0-100.${RESET}"
            exit 1
        fi
        set_brightness "$backend" "$VALUE"
        echo -e "  ${GREEN}✓${RESET} Brilho definido: ${VALUE}%"
        ;;
esac