#!/bin/bash
# weather.sh — Previsao do tempo via wttr.in com localizacao automatica
# Uso: ./weather.sh [opcoes]
# Opcoes:
#   -l, --location CITY  Cidade ou localizacao (padrao: auto)
#   -f, --format FMT     Formato: full, compact, simple (padrao: compact)
#   --forecast           Previsao de 3 dias
#   --help               Mostra esta ajuda
#   --version            Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

LOCATION=""
FORMAT="compact"
FORECAST=false

while [ $# -gt 0 ]; do
    case "$1" in
        -l|--location) LOCATION="$2"; shift 2 ;;
        -f|--format) FORMAT="$2"; shift 2 ;;
        --forecast) FORECAST=true; shift ;;
        --help|-h)
            echo ""
            echo "  weather.sh — Previsao do tempo via wttr.in"
            echo ""
            echo "  Uso: ./weather.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -l, --location CITY  Cidade ou localizacao (padrao: auto)"
            echo "    -f, --format FMT     Formato: full, compact, simple (padrao: compact)"
            echo "    --forecast           Previsao de 3 dias"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./weather.sh"
            echo "    ./weather.sh -l 'Sao Paulo'"
            echo "    ./weather.sh -l London -f full"
            echo "    ./weather.sh --forecast"
            echo ""
            exit 0
            ;;
        --version|-v) echo "weather.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v curl &>/dev/null; then
    check_and_install curl "$(detect_installer) curl" 2>/dev/null || { echo -e "${RED}[ERROR] curl necessario.${RESET}" >&2; exit 1; }
fi

if [ -z "$LOCATION" ]; then
    LOCATION=""
fi

LOCATION_ENCODED=$(echo "$LOCATION" | sed 's/ /+/g; s/ /%20/g' | sed 's/+/%20/g')

if $FORECAST; then
    FORMAT="full"
fi

echo ""
echo -e "  ${BOLD}── Weather ──${RESET}  ${DIM}v$VERSION${RESET}"
echo ""

case "$FORMAT" in
    full)
        curl -s "wttr.in/${LOCATION_ENCODED}?lang=pt" 2>/dev/null || {
            echo -e "  ${RED}Erro: nao foi possivel obter a previsao.${RESET}"
            exit 1
        }
        ;;
    compact)
        curl -s "wttr.in/${LOCATION_ENCODED}?lang=pt" 2>/dev/null || {
            echo -e "  ${RED}Erro: nao foi possivel obter a previsao.${RESET}"
            exit 1
        }
        ;;
    simple)
        result=$(curl -s "wttr.in/${LOCATION_ENCODED}?format=3&lang=pt" 2>/dev/null)
        if [ -z "$result" ]; then
            echo -e "  ${RED}Erro: nao foi possivel obter a previsao.${RESET}"
            exit 1
        fi
        echo -e "  ${CYAN}${result}${RESET}"
        ;;
    *)
        echo -e "  ${RED}Formato desconhecido: $FORMAT${RESET}"
        echo -e "  ${DIM}Use: full, compact ou simple${RESET}"
        exit 1
        ;;
esac

echo ""