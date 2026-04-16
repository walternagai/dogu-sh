#!/bin/bash
# ip-info.sh — Info do IP publico, ISP e localizacao geografica
# Uso: ./ip-info.sh [opcoes]
# Opcoes:
#   --local             Mostra IP local (padrao: mostra ambos)
#   --public            Mostra apenas IP publico
#   --json              Saida em JSON (se jq disponivel)
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

SHOW_LOCAL=false
SHOW_PUBLIC_ONLY=false
JSON_OUTPUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --local|-l) SHOW_LOCAL=true; shift ;;
        --public|-p) SHOW_PUBLIC_ONLY=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  ip-info.sh — Info do IP publico, ISP e localizacao"
            echo ""
            echo "  Uso: ./ip-info.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --local    Mostra IP local"
            echo "    --public   Mostra apenas IP publico"
            echo "    --json     Saida em JSON"
            echo "    --help     Mostra esta ajuda"
            echo "    --version  Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./ip-info.sh"
            echo "    ./ip-info.sh --local"
            echo "    ./ip-info.sh --json"
            echo ""
            exit 0
            ;;
        --version|-v) echo "ip-info.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if ! command -v curl &>/dev/null; then
    check_and_install curl "$(detect_installer) curl" 2>/dev/null || { echo -e "${RED}[ERROR] curl necessario.${RESET}" >&2; exit 1; }
fi

get_local_ip() {
    local ip=""
    if command -v ip &>/dev/null; then
        ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+')
    fi
    if [ -z "$ip" ] && command -v hostname &>/dev/null; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "$ip" ]; then
        ip=$(ifconfig 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}')
    fi
    echo "${ip:-N/A}"
}

get_local_ipv6() {
    local ip=""
    if command -v ip &>/dev/null; then
        ip=$(ip -6 route get 2001:4860:4860::8888 2>/dev/null | grep -oP 'src \K[0-9a-f:]+' | head -1)
    fi
    echo "${ip:-N/A}"
}

if $SHOW_LOCAL; then
    echo ""
    echo -e "  ${BOLD}── IP Local ──${RESET}"
    echo ""
    echo -e "  IPv4:     ${GREEN}$(get_local_ip)${RESET}"
    echo -e "  IPv6:     ${GREEN}$(get_local_ipv6)${RESET}"
    echo ""
    echo -e "  ${DIM}Interfaces:${RESET}"
    ip -br addr 2>/dev/null | while read -r iface status ips; do
        [ "$iface" = "lo" ] && continue
        printf "  %-12s %-10s %s\n" "$iface" "[$status]" "$ips"
    done 2>/dev/null || ifconfig 2>/dev/null | grep -E '^[a-z]' | while read -r line; do
        echo "  $line"
    done
    echo ""
    exit 0
fi

public_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null || curl -s --max-time 5 ipinfo.io/ip 2>/dev/null)

if [ -z "$public_ip" ]; then
    echo ""
    echo -e "  ${RED}Nao foi possivel obter o IP publico.${RESET}"
    echo -e "  ${DIM}Verifique sua conexao com a internet.${RESET}"
    echo ""
    exit 1
fi

if $SHOW_PUBLIC_ONLY; then
    echo "$public_ip"
    exit 0
fi

geo_data=$(curl -s --max-time 5 "http://ip-api.com/json/${public_ip}?fields=status,message,country,countryCode,region,regionName,city,zip,lat,lon,timezone,isp,org,as,query" 2>/dev/null)

if [ -z "$geo_data" ]; then
    echo ""
    echo -e "  ${BOLD}── IP Info ──${RESET}"
    echo ""
    echo -e "  IP Publico: ${GREEN}${public_ip}${RESET}"
    echo -e "  ${DIM}Nao foi possivel obter dados de geolocalizacao.${RESET}"
    echo ""
    exit 0
fi

if $JSON_OUTPUT; then
    if command -v jq &>/dev/null; then
        echo "$geo_data" | jq .
    else
        echo "$geo_data"
    fi
    exit 0
fi

status=$(echo "$geo_data" | grep -oP '"status"\s*:\s*"\K[^"]+' || echo "fail")

if [ "$status" = "fail" ]; then
    echo ""
    echo -e "  ${RED}Erro na API de geolocalizacao.${RESET}"
    echo -e "  IP Publico: ${GREEN}${public_ip}${RESET}"
    echo ""
    exit 1
fi

extract_field() {
    echo "$geo_data" | grep -oP "\"$1\"\\s*:\\s*\"?\\K[^\",}]+" || echo ""
}

country=$(extract_field "country")
country_code=$(extract_field "countryCode")
region=$(extract_field "regionName")
city=$(extract_field "city")
zip_code=$(extract_field "zip")
lat=$(extract_field "lat")
lon=$(extract_field "lon")
timezone=$(extract_field "timezone")
isp=$(extract_field "isp")
org=$(extract_field "org")
asn=$(extract_field "as")

echo ""
echo -e "  ${BOLD}── IP Info ──${RESET}"
echo ""
echo -e "  IP Publico:  ${GREEN}${BOLD}${public_ip}${RESET}"
echo -e "  IP Local:    ${GREEN}$(get_local_ip)${RESET}"
echo ""
echo -e "  ${BOLD}Localizacao:${RESET}"
echo -e "  Pais:        ${CYAN}${country}${RESET} ${DIM}(${country_code})${RESET}"
echo -e "  Regiao:      ${CYAN}${region}${RESET}"
echo -e "  Cidade:      ${CYAN}${city}${RESET}"
[ -n "$zip_code" ] && echo -e "  CEP:         ${CYAN}${zip_code}${RESET}"
echo -e "  Coords:      ${CYAN}${lat}, ${lon}${RESET}"
echo -e "  Fuso:        ${CYAN}${timezone}${RESET}"
echo ""
echo -e "  ${BOLD}Rede:${RESET}"
echo -e "  ISP:         ${CYAN}${isp}${RESET}"
echo -e "  Organizacao: ${CYAN}${org}${RESET}"
echo -e "  ASN:         ${DIM}${asn}${RESET}"
echo ""