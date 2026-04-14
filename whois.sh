#!/bin/bash
# whois.sh — Consulta WHOIS de dominios
# Uso: ./whois.sh [opcoes]
# Opcoes:
#   -d, --domain DOM     Dominio para consultar
#   --raw               Saida bruta do whois
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

DOMAIN=""
RAW_OUTPUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--domain) DOMAIN="$2"; shift 2 ;;
        --raw|-r) RAW_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  whois.sh — Consulta WHOIS de dominios"
            echo ""
            echo "  Uso: ./whois.sh -d DOMINIO [--raw]"
            echo ""
            echo "  Opcoes:"
            echo "    -d, --domain DOM  Dominio para consultar"
            echo "    --raw             Saida bruta do whois"
            echo "    --help            Mostra esta ajuda"
            echo "    --version         Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./whois.sh -d google.com"
            echo "    ./whois.sh -d github.com --raw"
            echo ""
            exit 0
            ;;
        --version|-v) echo "whois.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo ""
    echo -e "  ${BOLD}WHOIS Lookup${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Dominio: "
    read -r DOMAIN < /dev/tty
fi

if [ -z "$DOMAIN" ]; then
    echo -e "  ${RED}Erro: dominio vazio.${RESET}"
    exit 1
fi

if ! command -v whois &>/dev/null; then
    check_and_install whois "$(detect_installer) whois" 2>/dev/null || { echo -e "${RED}[ERROR] whois necessario.${RESET}" >&2; exit 1; }
fi

DOMAIN=$(echo "$DOMAIN" | sed 's|https\?://||; s|/.*||')

result=$(whois "$DOMAIN" 2>/dev/null)

if [ -z "$result" ]; then
    echo ""
    echo -e "  ${RED}Nenhum resultado WHOIS para: ${DOMAIN}${RESET}"
    echo ""
    exit 1
fi

if $RAW_OUTPUT; then
    echo "$result"
    exit 0
fi

echo ""
echo -e "  ${BOLD}── WHOIS: ${DOMAIN} ──${RESET}"
echo ""

declare -A fields
fields[("Domain Name")]=""
fields[("Registrar")]=""
fields[("Registrar URL")]=""
fields[("Creation Date")]=""
fields[("Registry Expiry Date")]=""
fields[("Updated Date")]=""
fields[("Registrar Abuse Contact Email")]=""
fields[("Domain Status")]=""
fields[("Name Server")]=""
fields[("DNSSEC")]=""

display_fields=("Domain Name" "Registrar" "Registrar URL" "Creation Date" "Registry Expiry Date" "Updated Date" "Registrar Abuse Contact Email" "Domain Status" "Name Server" "DNSSEC")

printed_fields=0

for label in "${display_fields[@]}"; do
    values=$(echo "$result" | grep -i "^${label}:" | sed "s/^${label}:*//i" | xargs | sort -u)
    if [ -n "$values" ]; then
        printed_fields=$((printed_fields + 1))

        case "$label" in
            "Creation Date"|"Registry Expiry Date"|"Updated Date")
                color="$CYAN"
                ;;
            "Domain Status")
                color="$YELLOW"
                ;;
            "Name Server")
                color="$GREEN"
                ;;
            *)
                color="$GREEN"
                ;;
        esac

        echo "$values" | while read -r val; do
            printf "  %-28s ${color}%s${RESET}\n" "$label:" "$val"
            label=""
        done
    fi
done

if [ "$printed_fields" -eq 0 ]; then
    echo -e "  ${DIM}Nao foi possivel extrair campos formatados.${RESET}"
    echo -e "  ${DIM}Tente --raw para saida completa.${RESET}"
fi

echo ""

if echo "$result" | grep -qi "No match\|NOT FOUND\|No Data Found\|Available\|No entries found"; then
    echo -e "  ${YELLOW}⚠ Dominio pode estar disponivel para registro.${RESET}"
    echo ""
fi