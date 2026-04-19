#!/bin/bash
# qr-gen.sh — Gera QR Code no terminal ou salva como PNG
# Uso: ./qr-gen.sh [opcoes]
# Opcoes:
#   -t, --text TEXT     Texto/URL para gerar QR Code
#   -o, --output FILE   Salva como PNG (requer qrencode)
#   -s, --size N        Tamanho do modulo (padrao: 2 para terminal, 4 para PNG)
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




QR_TEXT=""
OUTPUT_FILE=""
SIZE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--text)
            [[ -z "${2-}" ]] && { echo "Flag --text requer um valor" >&2; exit 1; }
            QR_TEXT="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 1; }
            OUTPUT_FILE="$2"; shift 2 ;;
        -s|--size)
            [[ -z "${2-}" ]] && { echo "Flag --size requer um valor" >&2; exit 1; }
            SIZE="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  qr-gen.sh — Gera QR Code no terminal ou salva como PNG"
            echo ""
            echo "  Uso: ./qr-gen.sh -t 'texto' [-o arquivo.png]"
            echo ""
            echo "  Opcoes:"
            echo "    -t, --text TEXT     Texto/URL para QR Code"
            echo "    -o, --output FILE   Salva como PNG"
            echo "    -s, --size N        Tamanho do modulo"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./qr-gen.sh -t 'https://github.com'"
            echo "    ./qr-gen.sh -t 'Hello World' -o qr.png"
            echo ""
            exit 0
            ;;
        --version|-V) echo "qr-gen.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if [ -z "$QR_TEXT" ]; then
    echo ""
    echo -e "  ${BOLD}QR Generator${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Texto/URL: "
    read -r QR_TEXT < /dev/tty
fi

if [ -z "$QR_TEXT" ]; then
    echo -e "  ${RED}Erro: texto vazio.${RESET}"
    exit 1
fi

if ! command -v qrencode &>/dev/null; then
    check_and_install qrencode "$(detect_installer)" "qrencode" 2>/dev/null || { echo -e "${RED}[ERROR] qrencode necessario.${RESET}" >&2; exit 1; }
fi

if [ -n "$OUTPUT_FILE" ]; then
    module_size="${SIZE:-4}"
    qrencode -o "$OUTPUT_FILE" -s "$module_size" "$QR_TEXT" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} QR Code salvo: ${CYAN}${OUTPUT_FILE}${RESET}"
        echo -e "  ${DIM}Texto: ${QR_TEXT}${RESET}"
    else
        echo -e "  ${RED}Erro ao gerar QR Code.${RESET}"
        exit 1
    fi
else
    module_size="${SIZE:-2}"
    echo ""
    echo -e "  ${BOLD}── QR Code ──${RESET}"
    echo ""
    qrencode -t ANSIUTF8 -s "$module_size" "$QR_TEXT" 2>/dev/null || \
        qrencode -t ASCII -s "$module_size" "$QR_TEXT" 2>/dev/null || \
        qrencode -t UTF8 -s "$module_size" "$QR_TEXT" 2>/dev/null
    echo ""
    echo -e "  ${DIM}Texto: ${QR_TEXT}${RESET}"
    echo ""
fi