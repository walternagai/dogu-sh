#!/bin/bash
# subnet-calc.sh — Calculadora de sub-redes IPv4/CIDR
# Uso: ./subnet-calc.sh [opcoes]
# Opcoes:
#   -i, --ip IP/CIDR     Calcula sub-rede a partir do IP/CIDR
#   --help               Mostra esta ajuda
#   --version            Mostra versao

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "bc" "$INSTALLER" "bc"; fi




INPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--ip)
            [[ -z "${2-}" ]] && { echo "Flag --ip requer um valor" >&2; exit 1; }
            INPUT="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  subnet-calc.sh — Calculadora de sub-redes IPv4/CIDR"
            echo ""
            echo "  Uso: ./subnet-calc.sh -i IP/CIDR"
            echo ""
            echo "  Opcoes:"
            echo "    -i, --ip IP/CIDR    Calcula sub-rede (ex: 192.168.1.0/24)"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./subnet-calc.sh -i 192.168.1.0/24"
            echo "    ./subnet-calc.sh -i 10.0.0.100/22"
            echo ""
            exit 0
            ;;
        --version|-V) echo "subnet-calc.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

ip_to_int() {
    local ip="$1"
    local IFS='.'
    read -r a b c d <<< "$ip"
    echo "$((a * 256 * 256 * 256 + b * 256 * 256 + c * 256 + d))"
}

int_to_ip() {
    local n="$1"
    echo "$((n >> 24 & 255)).$((n >> 16 & 255)).$((n >> 8 & 255)).$((n & 255))"
}

if [ -z "$INPUT" ]; then
    echo ""
    echo -e "  ${BOLD}Subnet Calculator${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  IP/CIDR (ex: 192.168.1.0/24): "
    read -r INPUT < /dev/tty
fi

if [[ ! "$INPUT" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
    echo ""
    echo -e "  ${RED}Formato invalido. Use: IP/CIDR (ex: 192.168.1.0/24)${RESET}"
    echo ""
    exit 1
fi

IP_PART="${INPUT%%/*}"
CIDR="${INPUT##*/}"

if [ "$CIDR" -lt 0 ] || [ "$CIDR" -gt 32 ]; then
    echo ""
    echo -e "  ${RED}CIDR invalido. Deve estar entre 0 e 32.${RESET}"
    echo ""
    exit 1
fi

for octet in ${IP_PART//./ }; do
    if [ "$octet" -gt 255 ]; then
        echo ""
        echo -e "  ${RED}IP invalido. Octeto $octet > 255.${RESET}"
        echo ""
        exit 1
    fi
done

IP_INT=$(ip_to_int "$IP_PART")
MASK_INT=$((0xFFFFFFFF << (32 - CIDR) & 0xFFFFFFFF))
NETWORK_INT=$((IP_INT & MASK_INT))
BROADCAST_INT=$((NETWORK_INT | (MASK_INT ^ 0xFFFFFFFF)))
WILDCARD_INT=$((MASK_INT ^ 0xFFFFFFFF))
FIRST_HOST_INT=$((NETWORK_INT + 1))
LAST_HOST_INT=$((BROADCAST_INT - 1))

if [ "$CIDR" -eq 32 ]; then
    TOTAL_HOSTS=1
    USABLE_HOSTS=1
    FIRST_HOST_INT=$NETWORK_INT
    LAST_HOST_INT=$NETWORK_INT
elif [ "$CIDR" -eq 31 ]; then
    TOTAL_HOSTS=2
    USABLE_HOSTS=2
    FIRST_HOST_INT=$NETWORK_INT
    LAST_HOST_INT=$BROADCAST_INT
else
    TOTAL_HOSTS=$((WILDCARD_INT + 1))
    USABLE_HOSTS=$((TOTAL_HOSTS - 2))
fi

NETMASK=$(int_to_ip "$MASK_INT")
WILDCARD=$(int_to_ip "$WILDCARD_INT")
NETWORK=$(int_to_ip "$NETWORK_INT")
BROADCAST=$(int_to_ip "$BROADCAST_INT")
FIRST_HOST=$(int_to_ip "$FIRST_HOST_INT")
LAST_HOST=$(int_to_ip "$LAST_HOST_INT")

CIDR_CLASS=""
case "$CIDR" in
    8) CIDR_CLASS="Classe A (/8)" ;;
    16) CIDR_CLASS="Classe B (/16)" ;;
    24) CIDR_CLASS="Classe C (/24)" ;;
esac

echo ""
echo -e "  ${BOLD}── Subnet Calculator ──${RESET}"
echo ""
echo -e "  ${CYAN}Endereco:${RESET}         ${BOLD}${INPUT}${RESET} ${DIM}${CIDR_CLASS}${RESET}"
echo ""
echo -e "  Netmask:           ${GREEN}${NETMASK}${RESET}  ${DIM}(/${CIDR})${RESET}"
echo -e "  Wildcard:          ${GREEN}${WILDCARD}${RESET}"
echo -e "  Rede:              ${GREEN}${NETWORK}${RESET}"
echo -e "  Broadcast:         ${GREEN}${BROADCAST}${RESET}"
echo -e "  Primeiro host:      ${GREEN}${FIRST_HOST}${RESET}"
echo -e "  Ultimo host:        ${GREEN}${LAST_HOST}${RESET}"
echo -e "  Total de IPs:      ${GREEN}${TOTAL_HOSTS}${RESET}"
echo -e "  Hosts utilizaveis: ${GREEN}${USABLE_HOSTS}${RESET}"
echo ""

BINARY_NETMASK=""
for i in 1 2 3 4; do
    octet=$(echo "$NETMASK" | cut -d'.' -f$i)
    binary=$(echo "obase=2; $octet" | bc | awk '{printf "%08d", $1}')
    BINARY_NETMASK="${BINARY_NETMASK}${binary}"
    [ "$i" -lt 4 ] && BINARY_NETMASK="${BINARY_NETMASK}."
done

echo -e "  ${DIM}Binario: ${BINARY_NETMASK}${RESET}"
echo ""