#!/bin/bash
# url-shortener.sh — Encurta URLs usando is.gd (Linux)
# Uso: ./url-shortener.sh [opcoes] [URL]
# Opcoes:
#   -u, --url URL       URL para encurtar
#   -c, --custom ALIAS  Alias personalizado
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
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
fi

URL=""
CUSTOM=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            [[ -z "${2-}" ]] && error "Flag --url requer um valor"
            URL="$2"; shift 2 ;;
        -c|--custom)
            [[ -z "${2-}" ]] && error "Flag --custom requer um valor"
            CUSTOM="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  url-shortener.sh — Encurta URLs usando is.gd"
            echo ""
            echo "  Uso: ./url-shortener.sh [opcoes] [URL]"
            echo ""
            echo "  Opcoes:"
            echo "    -u, --url URL       URL para encurtar"
            echo "    -c, --custom ALIAS  Alias personalizado"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./url-shortener.sh https://exemplo.com/artigo-muito-longo"
            echo "    ./url-shortener.sh -u https://exemplo.com -c meu-link"
            echo ""
            exit 0
            ;;
        --version|-V) echo "url-shortener.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *) URL="$1"; shift ;;
    esac
done

if [ -z "$URL" ]; then
    echo ""
    echo -e "  ${BOLD}── URL Shortener ──${RESET}"
    echo ""
    printf "  URL: "
    read -r URL < /dev/tty
    echo ""
fi

[ -z "$URL" ] && error "URL nao fornecida."

if ! command -v curl &>/dev/null; then
    if type check_and_install &>/dev/null 2>&1; then
        check_and_install curl "$INSTALLER" "curl" 2>/dev/null || error "curl e necessario."
    else
        error "curl e necessario."
    fi
fi

urlencode() {
    local string="$1"
    local encoded=""
    local pos c o
    for ((pos=0; pos<${#string}; pos++)); do
        c="${string:$pos:1}"
        case "$c" in
            [-_.~a-zA-Z0-9]) o="$c" ;;
            *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="$o"
    done
    echo "$encoded"
}

ENCODED_URL=$(urlencode "$URL")
API_URL="https://is.gd/create.php?format=simple&url=${ENCODED_URL}"

if [ -n "$CUSTOM" ]; then
    API_URL="${API_URL}&shorturl=${CUSTOM}"
fi

echo ""
echo -e "  ${BOLD}── Encurtando URL ──${RESET}"
echo ""
echo -e "  ${DIM}Original: ${URL}${RESET}"
echo ""

RESULT=$(curl -sS "$API_URL" 2>/dev/null) || error "Falha ao conectar com is.gd."

if echo "$RESULT" | grep -qi "^error:"; then
    error "$RESULT"
fi

echo -e "  ${GREEN}${BOLD}${RESULT}${RESET}"
echo ""
