#!/bin/bash
# port-check.sh — Verifica se portas estao abertas em um host
# Uso: ./port-check.sh [opcoes]
# Opcoes:
#   -h, --host HOST     Host para verificar (padrao: localhost)
#   -p, --port PORT     Porta ou range (ex: 80, 1-1024, 80,443,8080)
#   --common            Verifica portas comuns
#   --timeout MS        Timeout em milissegundos (padrao: 2000)
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

HOST="localhost"
PORT_SPEC=""
CHECK_COMMON=false
TIMEOUT=2000

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--host) HOST="$2"; shift 2 ;;
        -p|--port) PORT_SPEC="$2"; shift 2 ;;
        --common|-c) CHECK_COMMON=true; shift ;;
        --timeout|-t) TIMEOUT="$2"; shift 2 ;;
        --help|-H)
            echo ""
            echo "  port-check.sh — Verifica se portas estao abertas"
            echo ""
            echo "  Uso: ./port-check.sh -h HOST -p PORTA"
            echo ""
            echo "  Opcoes:"
            echo "    -h, --host HOST    Host (padrao: localhost)"
            echo "    -p, --port PORT    Porta, range ou lista (80, 1-1024, 80,443,8080)"
            echo "    --common           Verifica portas comuns"
            echo "    --timeout MS       Timeout em ms (padrao: 2000)"
            echo "    --help             Mostra esta ajuda"
            echo "    --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./port-check.sh -h google.com -p 443"
            echo "    ./port-check.sh -h 192.168.1.1 -p 80,443,8080"
            echo "    ./port-check.sh -h localhost -p 1-1024"
            echo "    ./port-check.sh --common"
            echo ""
            exit 0
            ;;
        --version|-v) echo "port-check.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

check_port() {
    local host="$1"
    local port="$2"
    local timeout_secs=$(echo "scale=2; $TIMEOUT / 1000" | bc)

    if command -v nc &>/dev/null; then
        nc -z -w "$TIMEOUT" "$host" "$port" 2>/dev/null && return 0 || return 1
    elif command -v timeout &>/dev/null && command -v bash &>/dev/null; then
        (echo > /dev/tcp/"$host"/"$port") &>/dev/null && return 0 || return 1
    else
        return 2
    fi
}

get_service_name() {
    case "$1" in
        20) echo "ftp-data" ;; 21) echo "ftp" ;; 22) echo "ssh" ;;
        23) echo "telnet" ;; 25) echo "smtp" ;; 53) echo "dns" ;;
        80) echo "http" ;; 110) echo "pop3" ;; 143) echo "imap" ;;
        443) echo "https" ;; 465) echo "smtps" ;; 587) echo "submission" ;;
        993) echo "imaps" ;; 995) echo "pop3s" ;; 3306) echo "mysql" ;;
        5432) echo "postgresql" ;; 6379) echo "redis" ;; 8080) echo "http-alt" ;;
        8443) echo "https-alt" ;; 27017) echo "mongodb" ;;
        *) echo "" ;;
    esac
}

COMMON_PORTS="20 21 22 23 25 53 80 110 143 443 465 587 993 995 3306 5432 6379 8080 8443 27017"

if $CHECK_COMMON; then
    PORT_SPEC=$(echo $COMMON_PORTS | tr ' ' ',')
fi

if [ -z "$PORT_SPEC" ]; then
    echo ""
    echo -e "  ${BOLD}Port Check${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Host (padrao: localhost): "
    read -r input_host < /dev/tty
    [ -n "$input_host" ] && HOST="$input_host"
    printf "  Porta(s): "
    read -r PORT_SPEC < /dev/tty
fi

if [ -z "$PORT_SPEC" ]; then
    echo -e "  ${RED}Erro: especifique porta(s).${RESET}"
    exit 1
fi

echo ""
echo -e "  ${BOLD}── Port Check: ${HOST} ──${RESET}"
echo ""

ports=()

if [[ "$PORT_SPEC" =~ ^[0-9]+-[0-9]+$ ]]; then
    start=${PORT_SPEC%-*}
    end=${PORT_SPEC#*-}
    for ((p=start; p<=end; p++)); do
        ports+=($p)
    done
elif [[ "$PORT_SPEC" =~ , ]]; then
    IFS=',' read -ra ports <<< "$PORT_SPEC"
else
    ports=("$PORT_SPEC")
fi

open_count=0
closed_count=0
printf "  %-8s %-10s %-15s %s\n" "PORTA" "STATUS" "SERVICO" "DETALHE"
printf "  %-8s %-10s %-15s %s\n" "─────" "──────────" "───────────────" "───────"

for port in "${ports[@]}"; do
    port=$(echo "$port" | xargs)
    [ -z "$port" ] && continue

    result=$(check_port "$HOST" "$port" 2>/dev/null)
    exit_code=$?

    service=$(get_service_name "$port")

    if [ $exit_code -eq 0 ]; then
        printf "  ${GREEN}%-8s%-10s${RESET} %-15s %s\n" "$port" "ABERTA" "$service" "✓"
        open_count=$((open_count + 1))
    elif [ $exit_code -eq 2 ]; then
        printf "  ${YELLOW}%-8s%-10s${RESET} %-15s %s\n" "$port" "ERRO" "$service" "sem ferramenta"
    else
        printf "  ${RED}%-8s%-10s${RESET} %-15s %s\n" "$port" "FECHADA" "$service" "✗"
        closed_count=$((closed_count + 1))
    fi
done

echo ""
echo -e "  ${DIM}Abertas: ${open_count} | Fechadas: ${closed_count} | Timeout: ${TIMEOUT}ms${RESET}"
echo ""