#!/bin/bash
# currency-converter.sh — Cotacao de moedas em tempo real via API
# Uso: ./currency-converter.sh [opcoes]
# Opcoes:
#   -f, --from CURRENCY  Moeda de origem (padrao: USD)
#   -t, --to CURRENCY    Moeda de destino (padrao: BRL)
#   -a, --amount VAL     Valor a converter (padrao: 1)
#   --list               Lista moedas populares
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

FROM_CUR="USD"
TO_CUR="BRL"
AMOUNT="1"
LIST_CURRENCIES=false

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--from) FROM_CUR="$2"; shift 2 ;;
        -t|--to) TO_CUR="$2"; shift 2 ;;
        -a|--amount) AMOUNT="$2"; shift 2 ;;
        --list|-l) LIST_CURRENCIES=true; shift ;;
        --help|-h)
            echo ""
            echo "  currency-converter.sh — Cotacao de moedas em tempo real"
            echo ""
            echo "  Uso: ./currency-converter.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -f, --from CURRENCY  Moeda de origem (padrao: USD)"
            echo "    -t, --to CURRENCY    Moeda de destino (padrao: BRL)"
            echo "    -a, --amount VAL     Valor a converter (padrao: 1)"
            echo "    --list               Lista moedas populares"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./currency-converter.sh -f USD -t BRL -a 100"
            echo "    ./currency-converter.sh -f EUR -t JPY"
            echo ""
            exit 0
            ;;
        --version|-v) echo "currency-converter.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

FROM_CUR=$(echo "$FROM_CUR" | tr '[:lower:]' '[:upper]')
TO_CUR=$(echo "$TO_CUR" | tr '[:lower:]' '[:upper}')

if ! command -v curl &>/dev/null; then
    check_and_install curl "$(detect_installer) curl" 2>/dev/null || { echo -e "${RED}[ERROR] curl necessario.${RESET}" >&2; exit 1; }
fi

if ! command -v jq &>/dev/null; then
    check_and_install jq "$(detect_installer) jq" 2>/dev/null || { echo -e "${RED}[ERROR] jq necessario.${RESET}" >&2; exit 1; }
fi

POPULAR_CURRENCIES="USD BRL EUR GBP JPY CAD AUD CHF CNY INR MXN ARS KRW NZD SEK NOK DKK ZAR RUB TRY PLN"

if $LIST_CURRENCIES; then
    echo ""
    echo -e "  ${BOLD}── Moedas Populares ──${RESET}"
    echo ""
    for cur in $POPULAR_CURRENCIES; do
        case "$cur" in
            USD) name="Dolar Americano" ;;
            BRL) name="Real Brasileiro" ;;
            EUR) name="Euro" ;;
            GBP) name="Libra Esterlina" ;;
            JPY) name="Iene Japones" ;;
            CAD) name="Dolar Canadense" ;;
            AUD) name="Dolar Australiano" ;;
            CHF) name="Franco Suico" ;;
            CNY) name="Yuan Chines" ;;
            INR) name="Rupia Indiana" ;;
            MXN) name="Peso Mexicano" ;;
            ARS) name="Peso Argentino" ;;
            KRW) name="Won Coreano" ;;
            NZD) name="Dolar Neozelandes" ;;
            SEK) name="Coroa Sueca" ;;
            NOK) name="Coroa Norueguesa" ;;
            DKK) name="Coroa Dinamarquesa" ;;
            ZAR) name="Rand Sul-Africano" ;;
            RUB) name="Rublo Russo" ;;
            TRY) name="Lira Turca" ;;
            PLN) name="Zloty Polones" ;;
            *) name="" ;;
        esac
        printf "  ${CYAN}%-4s${RESET} %s\n" "$cur" "$name"
    done
    echo ""
    exit 0
fi

API_URL="https://open.er-api.com/v6/latest/${FROM_CUR}"

response=$(curl -s "$API_URL" 2>/dev/null)

if [ -z "$response" ]; then
    echo ""
    echo -e "  ${RED}Erro: nao foi possivel conectar a API.${RESET}"
    echo -e "  ${DIM}Verifique sua conexao com a internet.${RESET}"
    echo ""
    exit 1
fi

api_error=$(echo "$response" | jq -r '.error' 2>/dev/null)
if [ "$api_error" != "null" ] && [ -n "$api_error" ]; then
    echo ""
    echo -e "  ${RED}Erro da API: $api_error${RESET}"
    echo ""
    exit 1
fi

rate=$(echo "$response" | jq -r ".rates.$TO_CUR" 2>/dev/null)

if [ -z "$rate" ] || [ "$rate" = "null" ]; then
    echo ""
    echo -e "  ${RED}Erro: moeda '$TO_CUR' nao encontrada.${RESET}"
    echo -e "  ${DIM}Use --list para ver moedas disponiveis.${RESET}"
    echo ""
    exit 1
fi

last_updated=$(echo "$response" | jq -r '.time_last_update_utc' 2>/dev/null)

result=$(echo "scale=4; $AMOUNT * $rate" | bc 2>/dev/null)
result=$(echo "$result" | sed 's/^\./0./; s/^-\./-0./')

echo ""
echo -e "  ${BOLD}── Conversao de Moedas ──${RESET}"
echo ""
echo -e "  ${CYAN}${AMOUNT} ${FROM_CUR}${RESET} = ${GREEN}${BOLD}${result} ${TO_CUR}${RESET}"
echo -e "  ${DIM}Taxa: 1 ${FROM_CUR} = ${rate} ${TO_CUR}${RESET}"
echo -e "  ${DIM}Atualizado: ${last_updated}${RESET}"
echo ""