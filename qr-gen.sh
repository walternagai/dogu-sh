#!/bin/bash
# qr-gen.sh — Gera QR Code no terminal ou salva como PNG
# Uso: ./qr-gen.sh [opcoes]
# Opcoes:
#   -t, --text TEXT     Texto/URL para gerar QR Code
#   -o, --output FILE   Salva como PNG (requer qrencode)
#   -s, --size N        Tamanho do modulo (padrao: 2 para terminal, 4 para PNG)
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

QR_TEXT=""
OUTPUT_FILE=""
SIZE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -t|--text) QR_TEXT="$2"; shift 2 ;;
        -o|--output) OUTPUT_FILE="$2"; shift 2 ;;
        -s|--size) SIZE="$2"; shift 2 ;;
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
        --version|-v) echo "qr-gen.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
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
    check_and_install qrencode "$(detect_installer) qrencode" 2>/dev/null || { echo -e "${RED}[ERROR] qrencode necessario.${RESET}" >&2; exit 1; }
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