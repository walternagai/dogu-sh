#!/bin/bash
# dns-lookup.sh — Lookup DNS (A, AAAA, MX, NS, TXT, CNAME)
# Uso: ./dns-lookup.sh [opcoes]
# Opcoes:
#   -d, --domain DOM    Dominio para consultar
#   -t, --type TYPE     Tipo de registro (padrao: A)
#   --all               Consulta todos os tipos comuns
#   --server DNS        Servidor DNS especifico
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DOMAIN=""
RECORD_TYPE="A"
ALL_TYPES=false
DNS_SERVER=""

while [ $# -gt 0 ]; do
    case "$1" in
        -d|--domain) DOMAIN="$2"; shift 2 ;;
        -t|--type) RECORD_TYPE="$2"; shift 2 ;;
        --all|-a) ALL_TYPES=true; shift ;;
        --server|-s) DNS_SERVER="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  dns-lookup.sh — Lookup DNS"
            echo ""
            echo "  Uso: ./dns-lookup.sh -d DOMINIO [-t TIPO] [--all]"
            echo ""
            echo "  Opcoes:"
            echo "    -d, --domain DOM  Dominio para consultar"
            echo "    -t, --type TYPE  Tipo de registro (A, AAAA, MX, NS, TXT, CNAME, SOA)"
            echo "    --all            Consulta todos os tipos comuns"
            echo "    --server DNS     Servidor DNS (ex: 8.8.8.8)"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./dns-lookup.sh -d google.com"
            echo "    ./dns-lookup.sh -d google.com -t MX"
            echo "    ./dns-lookup.sh -d google.com --all"
            echo ""
            exit 0
            ;;
        --version|-v) echo "dns-lookup.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if [ -z "$DOMAIN" ]; then
    echo ""
    echo -e "  ${BOLD}DNS Lookup${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Dominio: "
    read -r DOMAIN < /dev/tty
fi

if [ -z "$DOMAIN" ]; then
    echo -e "  ${RED}Erro: dominio vazio.${RESET}"
    exit 1
fi

if ! command -v dig &>/dev/null; then
    if command -v nslookup &>/dev/null; then
        USE_NSLOOKUP=true
    else
        echo -e "  ${RED}Erro: dig ou nslookup necessarios.${RESET}"
        echo -e "  ${DIM}Instale: dnsutils (Debian) ou bind-utils (Fedora)${RESET}"
        exit 1
    fi
else
    USE_NSLOOKUP=false
fi

do_lookup() {
    local domain="$1"
    local rtype="$2"

    if [ "$USE_NSLOOKUP" = true ]; then
        result=$(nslookup -type="$rtype" "$domain" ${DNS_SERVER:-} 2>/dev/null | tail -n +3)
    else
        local dig_args="+short"
        if [ -n "$DNS_SERVER" ]; then
            dig_args="@${DNS_SERVER} $dig_args"
        fi
        result=$(dig $dig_args "$domain" "$rtype" 2>/dev/null)
    fi

    echo "$result"
}

echo ""
echo -e "  ${BOLD}── DNS Lookup: ${DOMAIN} ──${RESET}"
echo ""

if $ALL_TYPES; then
    for rtype in A AAAA MX NS TXT CNAME SOA; do
        echo -e "  ${CYAN}${BOLD}${rtype}:${RESET}"
        result=$(do_lookup "$DOMAIN" "$rtype")
        if [ -z "$result" ]; then
            echo -e "    ${DIM}(nenhum registro)${RESET}"
        else
            echo "$result" | while read -r line; do
                echo -e "    ${GREEN}${line}${RESET}"
            done
        fi
        echo ""
    done
else
    echo -e "  ${CYAN}${BOLD}${RECORD_TYPE}:${RESET}"
    result=$(do_lookup "$DOMAIN" "$RECORD_TYPE")
    if [ -z "$result" ]; then
        echo -e "    ${DIM}(nenhum registro encontrado)${RESET}"
    else
        echo "$result" | while read -r line; do
            echo -e "    ${GREEN}${line}${RESET}"
        done
    fi
    echo ""

    if [ -n "$DNS_SERVER" ]; then
        echo -e "  ${DIM}Servidor DNS: ${DNS_SERVER}${RESET}"
    fi
fi