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

set -euo pipefail

readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }


DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "bc" "$INSTALLER" "bc"
    check_and_install "nc" "$INSTALLER" "netcat-openbsd"
fi


HOST="localhost"
PORT_SPEC=""
CHECK_COMMON=false
TIMEOUT=2000
JSON_MODE=false

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--host)
            [[ -z "${2-}" ]] && { echo "Flag --host requer um valor" >&2; exit 2; }
            HOST="$2"; shift 2 ;;
        -p|--port)
            [[ -z "${2-}" ]] && { echo "Flag --port requer um valor" >&2; exit 2; }
            PORT_SPEC="$2"; shift 2 ;;
        --common|-c) CHECK_COMMON=true; shift ;;
        --json|-j) JSON_MODE=true; shift ;;
        --timeout|-t)
            [[ -z "${2-}" ]] && { echo "Flag --timeout requer um valor" >&2; exit 2; }
            TIMEOUT="$2"; shift 2 ;;
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
            echo "    --json|-j          Saida em formato JSON"
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
        --version|-V) echo "port-check.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

check_port() {
    local host="$1"
    local port="$2"
    local timeout_secs=$(echo "scale=2; $TIMEOUT / 1000" | bc)

    if command -v nc &>/dev/null; then
        nc -z -w "$timeout_secs" "$host" "$port" 2>/dev/null && return 0 || return 1
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

if [ -z "$PORT_SPEC" ] && ! $JSON_MODE; then
    if [ ! -t 0 ]; then
        error "Execução não interativa detectada. Informe --port (ex.: --port 443) ou rode em terminal."
    fi
    echo ""
    echo -e "  ${BOLD}Port Check${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Host (padrao: localhost): "
    read -r input_host < /dev/tty 2>/dev/null || input_host=""
    [ -n "$input_host" ] && HOST="$input_host"
    printf "  Porta(s): "
    read -r PORT_SPEC < /dev/tty 2>/dev/null || PORT_SPEC=""
fi

if [ -z "$PORT_SPEC" ]; then
    echo -e "  ${RED}Erro: especifique porta(s).${RESET}" >&2
    exit 1
fi

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
error_count=0
json_items=""
json_first=true

if ! $JSON_MODE; then
    echo ""
    echo -e "  ${BOLD}── Port Check: ${HOST} ──${RESET}"
    echo ""
    printf "  %-8s %-10s %-15s %s\n" "PORTA" "STATUS" "SERVICO" "DETALHE"
    printf "  %-8s %-10s %-15s %s\n" "─────" "──────────" "───────────────" "───────"
fi

for port in "${ports[@]}"; do
    port=$(echo "$port" | xargs)
    [ -z "$port" ] && continue

    if result=$(check_port "$HOST" "$port" 2>/dev/null); then
        exit_code=0
    else
        exit_code=$?
    fi

    service=$(get_service_name "$port")

    if [ $exit_code -eq 0 ]; then
        status="open"; status_label="ABERTA"; detail="✓"
        open_count=$((open_count + 1))
    elif [ $exit_code -eq 2 ]; then
        status="error"; status_label="ERRO"; detail="sem ferramenta"
        error_count=$((error_count + 1))
    else
        status="closed"; status_label="FECHADA"; detail="✗"
        closed_count=$((closed_count + 1))
    fi

    if $JSON_MODE; then
        $json_first || json_items+=","
        json_first=false
        json_items+=$(printf '{"port":%s,"status":"%s","service":"%s"}' \
            "$port" "$status" "$(json_escape "$service")")
    elif [ "$status" = "open" ]; then
        printf "  ${GREEN}%-8s%-10s${RESET} %-15s %s\n" "$port" "$status_label" "$service" "$detail"
    elif [ "$status" = "error" ]; then
        printf "  ${YELLOW}%-8s%-10s${RESET} %-15s %s\n" "$port" "$status_label" "$service" "$detail"
    else
        printf "  ${RED}%-8s%-10s${RESET} %-15s %s\n" "$port" "$status_label" "$service" "$detail"
    fi
done

if $JSON_MODE; then
    printf '{"host":"%s","timeout_ms":%s,"ports":[%s],"summary":{"open":%s,"closed":%s,"error":%s}}\n' \
        "$(json_escape "$HOST")" "$TIMEOUT" "$json_items" \
        "$open_count" "$closed_count" "$error_count"
else
    echo ""
    echo -e "  ${DIM}Abertas: ${open_count} | Fechadas: ${closed_count} | Timeout: ${TIMEOUT}ms${RESET}"
    echo ""
fi