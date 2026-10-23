#!/bin/bash
# ssl-cert-check.sh — Verifica validade, emissor e dias restantes de um certificado TLS
# Uso: ./ssl-cert-check.sh [opcoes] HOST[:PORTA]
# Opcoes:
#   -p, --port PORT       Porta (padrao: 443)
#   -w, --warn-days N     Alerta quando faltarem N dias (padrao: 30)
#       --json            Saida em formato JSON
#   -h, --help            Mostra esta ajuda
#   -V, --version         Mostra versao
#
# Aceita host puro, host:porta ou URL https://host/caminho.

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
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

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

TARGET=""
PORT=""
WARN_DAYS=30
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--port)
            [[ -z "${2-}" ]] && { echo "Flag --port requer um valor" >&2; exit 2; }
            PORT="$2"; shift 2 ;;
        -w|--warn-days)
            [[ -z "${2-}" ]] && { echo "Flag --warn-days requer um valor" >&2; exit 2; }
            WARN_DAYS="$2"; shift 2 ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  ssl-cert-check.sh — Verifica certificado TLS de um host"
            echo ""
            echo "  Uso: ./ssl-cert-check.sh [opcoes] HOST[:PORTA]"
            echo ""
            echo "  Opcoes:"
            echo "    -p, --port PORT     Porta (padrao: 443)"
            echo "    -w, --warn-days N   Alerta quando faltarem N dias (padrao: 30)"
            echo "        --json          Saida em formato JSON"
            echo "    -h, --help          Mostra esta ajuda"
            echo "    -V, --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./ssl-cert-check.sh example.com"
            echo "    ./ssl-cert-check.sh https://example.com"
            echo "    ./ssl-cert-check.sh example.com:8443 --json"
            echo ""
            exit 0
            ;;
        -V|--version) echo "ssl-cert-check.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            [[ -z "$TARGET" ]] && TARGET="$1" || error "Argumento inesperado: $1"
            shift ;;
    esac
done

command -v openssl &>/dev/null || error "openssl nao encontrado."

[[ -n "$TARGET" ]] || error "Informe um host. Ex.: ./ssl-cert-check.sh example.com"

# Normaliza URL/host:porta
TARGET="${TARGET#https://}"
TARGET="${TARGET#http://}"
TARGET="${TARGET%%/*}"
if [[ -n "$PORT" ]]; then
    HOST="$TARGET"
else
    if [[ "$TARGET" == *:* && "$TARGET" != \[* ]]; then
        HOST="${TARGET%:*}"
        PORT="${TARGET##*:}"
    else
        HOST="$TARGET"
        PORT=443
    fi
fi
[[ "$WARN_DAYS" =~ ^[0-9]+$ ]] || error "--warn-days exige um inteiro nao negativo"

run_s_client() {
    if command -v timeout &>/dev/null; then
        timeout 10 openssl s_client -servername "$HOST" -connect "${HOST}:${PORT}" 2>/dev/null < /dev/null
    else
        openssl s_client -servername "$HOST" -connect "${HOST}:${PORT}" 2>/dev/null < /dev/null
    fi
}

CERT_OUTPUT=$(run_s_client) || error "Falha ao conectar em ${HOST}:${PORT}"

INFO=$(printf '%s\n' "$CERT_OUTPUT" | openssl x509 -noout -subject -issuer -dates -ext subjectAltName 2>/dev/null) \
    || error "Nao foi possivel ler o certificado de ${HOST}:${PORT}"

SUBJECT=$(printf '%s\n' "$INFO" | sed -n 's/^subject=//p' | head -1)
ISSUER=$(printf '%s\n' "$INFO" | sed -n 's/^issuer=//p' | head -1)
NOT_BEFORE=$(printf '%s\n' "$INFO" | sed -n 's/^notBefore=//p' | head -1)
NOT_AFTER=$(printf '%s\n' "$INFO" | sed -n 's/^notAfter=//p' | head -1)
SAN_RAW=$(printf '%s\n' "$INFO" | grep -o 'DNS:[^,]*' | sed 's/^DNS://' | tr '\n' ',' | sed 's/,$//')

END_EPOCH=$(date -d "$NOT_AFTER" +%s 2>/dev/null || true)
if [[ -z "$END_EPOCH" ]]; then
    END_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$NOT_AFTER" +%s 2>/dev/null || true)
fi
[[ -n "$END_EPOCH" ]] || error "Nao foi possivel interpretar a data '$NOT_AFTER'"

NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (END_EPOCH - NOW_EPOCH) / 86400 ))

if [ "$DAYS_LEFT" -le 0 ]; then
    STATUS="expired"
elif [ "$DAYS_LEFT" -le "$WARN_DAYS" ]; then
    STATUS="warning"
else
    STATUS="ok"
fi

if $JSON_MODE; then
    printf '{"host":"%s","port":%s,"subject":"%s","issuer":"%s","not_before":"%s","not_after":"%s","days_left":%s,"status":"%s","san":"%s"}\n' \
        "$(json_escape "$HOST")" "$PORT" "$(json_escape "$SUBJECT")" "$(json_escape "$ISSUER")" \
        "$(json_escape "$NOT_BEFORE")" "$(json_escape "$NOT_AFTER")" "$DAYS_LEFT" "$STATUS" \
        "$(json_escape "$SAN_RAW")"
else
    echo ""
    echo -e "  ${BOLD}── Certificado TLS: ${HOST}:${PORT} ──${RESET}"
    echo ""
    echo -e "  Subject:   ${CYAN}${SUBJECT}${RESET}"
    echo -e "  Emissor:   ${DIM}${ISSUER}${RESET}"
    echo -e "  Valido de: ${DIM}${NOT_BEFORE}${RESET}"
    echo -e "  Valido ate:${DIM} ${NOT_AFTER}${RESET}"
    echo -e "  Dias:      ${BOLD}${DAYS_LEFT}${RESET}"
    [ -n "$SAN_RAW" ] && echo -e "  SAN:       ${DIM}${SAN_RAW}${RESET}"
    echo ""
    case "$STATUS" in
        ok)      success "Certificado valido (mais de ${WARN_DAYS} dias)." ;;
        warning) warn "Certificado expira em ${DAYS_LEFT} dia(s)." ;;
        expired) error "Certificado expirado ou sem dias restantes." ;;
    esac
fi

[[ "$STATUS" == "expired" ]] && exit 1
exit 0
