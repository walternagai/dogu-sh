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


DOMAIN=""
RECORD_TYPE="A"
ALL_TYPES=false
DNS_SERVER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--domain)
            [[ -z "${2-}" ]] && { echo "Flag --domain requer um valor" >&2; exit 1; }
            DOMAIN="$2"; shift 2 ;;
        -t|--type)
            [[ -z "${2-}" ]] && { echo "Flag --type requer um valor" >&2; exit 1; }
            RECORD_TYPE="$2"; shift 2 ;;
        --all|-a) ALL_TYPES=true; shift ;;
        --server|-s)
            [[ -z "${2-}" ]] && { echo "Flag --server requer um valor" >&2; exit 1; }
            DNS_SERVER="$2"; shift 2 ;;
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
        --version|-V) echo "dns-lookup.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
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