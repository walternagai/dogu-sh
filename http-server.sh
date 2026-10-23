#!/bin/bash
# http-server.sh — Servidor HTTP local para um diretorio
# Uso: ./http-server.sh [opcoes]
# Opcoes:
#   -d, --directory DIR  Diretorio a servir (padrao: .)
#   -p, --port PORT      Porta (padrao: 8000)
#   -b, --bind ADDR      Endereco de escuta (padrao: 127.0.0.1)
#       --dry-run        Mostra o comando sem iniciar o servidor
#   -h, --help           Mostra esta ajuda
#   -V, --version        Mostra versao
#
# Seguranca: o padrao escuta apenas em localhost. Use --bind 0.0.0.0
# conscientemente para expor o diretorio na rede.

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

DIRECTORY="."
PORT=8000
BIND="127.0.0.1"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--directory)
            [[ -z "${2-}" ]] && { echo "Flag --directory requer um valor" >&2; exit 2; }
            DIRECTORY="$2"; shift 2 ;;
        -p|--port)
            [[ -z "${2-}" ]] && { echo "Flag --port requer um valor" >&2; exit 2; }
            PORT="$2"; shift 2 ;;
        -b|--bind)
            [[ -z "${2-}" ]] && { echo "Flag --bind requer um valor" >&2; exit 2; }
            BIND="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help)
            echo ""
            echo "  http-server.sh — Servidor HTTP local para um diretorio"
            echo ""
            echo "  Uso: ./http-server.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -d, --directory DIR  Diretorio a servir (padrao: .)"
            echo "    -p, --port PORT      Porta (padrao: 8000)"
            echo "    -b, --bind ADDR      Endereco de escuta (padrao: 127.0.0.1)"
            echo "        --dry-run        Mostra o comando sem iniciar"
            echo "    -h, --help           Mostra esta ajuda"
            echo "    -V, --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./http-server.sh"
            echo "    ./http-server.sh -d ./public -p 8080"
            echo "    ./http-server.sh -b 0.0.0.0 -p 9000   # expoe na rede"
            echo ""
            exit 0
            ;;
        -V|--version) echo "http-server.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

command -v python3 &>/dev/null || error "python3 nao encontrado. Instale python3 para usar o servidor HTTP."
[[ -d "$DIRECTORY" ]] || error "Diretorio nao encontrado: $DIRECTORY"
[[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ] || error "Porta invalida: $PORT"

DIRECTORY=$(cd "$DIRECTORY" && pwd)
URL="http://${BIND}:${PORT}/"

log "Servindo ${DIRECTORY}"
log "URL: ${URL}"
log "Ctrl+C para parar"

if $DRY_RUN; then
    echo "python3 -m http.server ${PORT} --bind ${BIND} --directory ${DIRECTORY}"
    exit 0
fi

exec python3 -m http.server "$PORT" --bind "$BIND" --directory "$DIRECTORY"
