#!/bin/bash
# api-tester.sh — Teste rapido de APIs REST com formatacao JSON (Linux)
# Uso: ./api-tester.sh [opcoes] [URL]
# Opcoes:
#   -u, --url URL       URL da requisicao
#   -X, --method MET    Metodo HTTP (GET, POST, PUT, DELETE, PATCH, HEAD)
#   -d, --data DATA     Corpo da requisicao
#   -H, --header HEAD   Cabecalho personalizado (pode repetir)
#   -v, --verbose       Mostra cabecalhos e metadados
#   --status-only       Mostra apenas o codigo de status
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
METHOD="GET"
DATA=""
declare -a HEADERS=()
VERBOSE=false
STATUS_ONLY=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)
            [[ -z "${2-}" ]] && error "Flag --url requer um valor"
            URL="$2"; shift 2 ;;
        -X|--method)
            [[ -z "${2-}" ]] && error "Flag --method requer um valor"
            METHOD=$(echo "$2" | tr '[:lower:]' '[:upper]'); shift 2 ;;
        -d|--data)
            [[ -z "${2-}" ]] && error "Flag --data requer um valor"
            DATA="$2"; shift 2 ;;
        -H|--header)
            [[ -z "${2-}" ]] && error "Flag --header requer um valor"
            HEADERS+=("$2"); shift 2 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --status-only) STATUS_ONLY=true; shift ;;
        --help|-h)
            echo ""
            echo "  api-tester.sh — Teste rapido de APIs REST com formatacao JSON"
            echo ""
            echo "  Uso: ./api-tester.sh [opcoes] [URL]"
            echo ""
            echo "  Opcoes:"
            echo "    -u, --url URL       URL da requisicao"
            echo "    -X, --method MET    Metodo HTTP (GET, POST, PUT, DELETE, PATCH, HEAD)"
            echo "    -d, --data DATA     Corpo da requisicao (JSON ou form)"
            echo "    -H, --header HEAD   Cabecalho personalizado (pode repetir)"
            echo "    -v, --verbose       Mostra cabecalhos e metadados"
            echo "    --status-only       Mostra apenas o codigo de status"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./api-tester.sh https://api.github.com/users/octocat"
            echo "    ./api-tester.sh -X POST -d '{\"title\":\"foo\"}' \\"
            echo "      -H \"Content-Type: application/json\" \\"
            echo "      https://jsonplaceholder.typicode.com/posts"
            echo "    ./api-tester.sh -H \"Authorization: Bearer TOKEN\" \\"
            echo "      --status-only https://api.example.com"
            echo ""
            exit 0
            ;;
        --version|-V) echo "api-tester.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *) URL="$1"; shift ;;
    esac
done

if [ -z "$URL" ] && [ $# -gt 0 ]; then
    URL="$1"
fi

if [ -z "$URL" ]; then
    echo ""
    echo -e "  ${BOLD}── API Tester ──${RESET}"
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

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

HEADER_FILE="$TMPDIR/headers"
BODY_FILE="$TMPDIR/body"

CURL_CMD=("curl" "-sS" "-D" "$HEADER_FILE" "-o" "$BODY_FILE"
    "-w" "%{http_code}|%{time_total}|%{size_download}")

for h in "${HEADERS[@]}"; do
    CURL_CMD+=("-H" "$h")
done

if [ "$METHOD" != "GET" ]; then
    CURL_CMD+=("-X" "$METHOD")
fi

if [ -n "$DATA" ]; then
    CURL_CMD+=("-d" "$DATA")
fi

CURL_CMD+=("$URL")

HTTP_META=$("${CURL_CMD[@]}" 2>/dev/null) || error "Falha na requisicao para ${URL}"

HTTP_CODE="${HTTP_META%%|*}"
REST="${HTTP_META#*|}"
TIME_TOTAL="${REST%%|*}"
SIZE_DOWNLOAD="${REST#*|}"

if $STATUS_ONLY; then
    echo ""
    echo -e "  ${BOLD}HTTP ${HTTP_CODE}${RESET}  ${DIM}${TIME_TOTAL}s  ${SIZE_DOWNLOAD}B${RESET}"
    echo ""
    exit 0
fi

echo ""
echo -e "  ${BOLD}── ${METHOD} ${URL}${RESET}"

if $VERBOSE && [ -f "$HEADER_FILE" ]; then
    echo ""
    echo -e "  ${CYAN}── Cabecalhos da Resposta ──${RESET}"
    echo ""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo -e "  ${DIM}${line}${RESET}"
    done < "$HEADER_FILE"
fi

if [ -f "$BODY_FILE" ] && [ -s "$BODY_FILE" ]; then
    echo ""
    echo -e "  ${CYAN}── Corpo da Resposta ──${RESET}"
    echo ""
    if command -v jq &>/dev/null; then
        jq . "$BODY_FILE" 2>/dev/null || cat "$BODY_FILE"
    else
        cat "$BODY_FILE"
    fi
fi

echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
STATUS_COLOR="$GREEN"
if [ "${HTTP_CODE:0:1}" = "4" ] || [ "${HTTP_CODE:0:1}" = "5" ]; then
    STATUS_COLOR="$RED"
elif [ "${HTTP_CODE:0:1}" = "3" ]; then
    STATUS_COLOR="$YELLOW"
fi
echo -e "  ${BOLD}HTTP${RESET} ${STATUS_COLOR}${HTTP_CODE}${RESET}  ${DIM}|${RESET}  ${TIME_TOTAL}s  ${DIM}|${RESET}  ${SIZE_DOWNLOAD}B"
echo ""
