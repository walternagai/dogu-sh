#!/bin/bash
# screenshot.sh — Captura de tela com salvamento automatico
# Uso: ./screenshot.sh [opcoes]
# Opcoes:
#   -m, --mode MODE     Modo: full, area, window (padrao: full)
#   -o, --output DIR     Diretorio de saida (padrao: ~/Pictures/screenshots)
#   -d, --delay N        Atraso em segundos (padrao: 0)
#   --clipboard          Copia para clipboard ao inves de salvar
#   --help               Mostra esta ajuda
#   --version            Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

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


MODE="full"
OUTPUT_DIR="$HOME/Pictures/screenshots"
DELAY=0
CLIPBOARD=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--mode)
            [[ -z "${2-}" ]] && { echo "Flag --mode requer um valor" >&2; exit 1; }
            MODE="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 1; }
            OUTPUT_DIR="$2"; shift 2 ;;
        -d|--delay)
            [[ -z "${2-}" ]] && { echo "Flag --delay requer um valor" >&2; exit 1; }
            DELAY="$2"; shift 2 ;;
        --clipboard|-c) CLIPBOARD=true; shift ;;
        --help|-h)
            echo ""
            echo "  screenshot.sh — Captura de tela com salvamento automatico"
            echo ""
            echo "  Uso: ./screenshot.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -m, --mode MODE   full, area, window (padrao: full)"
            echo "    -o, --output DIR  Diretorio de saida"
            echo "    -d, --delay N     Atraso em segundos (padrao: 0)"
            echo "    --clipboard       Copia para clipboard"
            echo "    --help            Mostra esta ajuda"
            echo "    --version         Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./screenshot.sh"
            echo "    ./screenshot.sh -m area"
            echo "    ./screenshot.sh -m window -d 3"
            echo "    ./screenshot.sh --clipboard"
            echo ""
            exit 0
            ;;
        --version|-V) echo "screenshot.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

detect_screenshot_tool() {
    if command -v maim &>/dev/null && command -v slop &>/dev/null; then
        echo "maim"
    elif command -v scrot &>/dev/null; then
        echo "scrot"
    elif command -v gnome-screenshot &>/dev/null; then
        echo "gnome"
    elif command -v spectacle &>/dev/null; then
        echo "spectacle"
    else
        echo "none"
    fi
}

detect_clipboard_tool() {
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
        echo "wl-copy"
    elif command -v xclip &>/dev/null; then
        echo "xclip"
    elif command -v xsel &>/dev/null; then
        echo "xsel"
    else
        echo "none"
    fi
}

tool=$(detect_screenshot_tool)

if [ "$tool" = "none" ]; then
    if command -v maim &>/dev/null; then
        check_and_install slop "$(detect_installer)" "slop" 2>/dev/null
    else
        check_and_install scrot "$(detect_installer)" "scrot" 2>/dev/null || \
        check_and_install maim "$(detect_installer)" "maim" 2>/dev/null || {
            echo -e "${RED}[ERROR] scrot ou maim necessarios.${RESET}" >&2
            exit 1
        }
    fi
    tool=$(detect_screenshot_tool)
fi

mkdir -p "$OUTPUT_DIR"

FILENAME="screenshot_$(date '+%Y%m%d_%H%M%S').png"
FILEPATH="${OUTPUT_DIR}/${FILENAME}"

if [ "$DELAY" -gt 0 ]; then
    echo -e "  ${DIM}Capturando em ${DELAY} segundo(s)...${RESET}"
    sleep "$DELAY"
fi

case "$tool" in
    maim)
        case "$MODE" in
            full) maim "$FILEPATH" 2>/dev/null ;;
            area) maim -s "$FILEPATH" 2>/dev/null ;;
            window) maim -i "$(xdotool getactivewindow)" "$FILEPATH" 2>/dev/null || maim "$FILEPATH" 2>/dev/null ;;
        esac
        ;;
    scrot)
        case "$MODE" in
            full) scrot -z "$FILEPATH" 2>/dev/null ;;
            area) scrot -s -z "$FILEPATH" 2>/dev/null ;;
            window) scrot -u -z "$FILEPATH" 2>/dev/null ;;
        esac
        ;;
    gnome)
        case "$MODE" in
            full) gnome-screenshot -f "$FILEPATH" 2>/dev/null ;;
            area) gnome-screenshot -a -f "$FILEPATH" 2>/dev/null ;;
            window) gnome-screenshot -w -f "$FILEPATH" 2>/dev/null ;;
        esac
        ;;
    spectacle)
        case "$MODE" in
            full) spectacle -b -n -f -o "$FILEPATH" 2>/dev/null ;;
            area) spectacle -b -n -r -o "$FILEPATH" 2>/dev/null ;;
            window) spectacle -b -n -a -o "$FILEPATH" 2>/dev/null ;;
        esac
        ;;
esac

if [ $? -ne 0 ] || [ ! -f "$FILEPATH" ]; then
    echo -e "  ${RED}Erro ao capturar tela.${RESET}"
    exit 1
fi

if $CLIPBOARD; then
    clip_tool=$(detect_clipboard_tool)
    case "$clip_tool" in
        wl-copy) cat "$FILEPATH" | wl-copy 2>/dev/null ;;
        xclip) cat "$FILEPATH" | xclip -selection clipboard -t image/png 2>/dev/null ;;
        xsel) cat "$FILEPATH" | xsel --clipboard --input -t image/png 2>/dev/null ;;
    esac
    echo -e "  ${GREEN}✓${RESET} Captura copiada para clipboard"
    rm -f "$FILEPATH"
else
    file_size=$(du -h "$FILEPATH" | cut -f1)
    echo ""
    echo -e "  ${GREEN}✓${RESET} Captura salva: ${CYAN}${FILEPATH}${RESET}  ${DIM}(${file_size})${RESET}"
    echo -e "  ${DIM}Modo: ${MODE} | Ferramenta: ${tool}${RESET}"
    echo ""
fi