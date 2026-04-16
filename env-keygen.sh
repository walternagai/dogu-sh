#!/bin/bash
# env-keygen.sh — Gera chaves secretas seguras para uso em arquivos .env
# Uso: ./env-keygen.sh [opcoes]
# Opcoes:
#   -n, --name VAR      Nome da variavel (ex: SECRET_KEY)
#   -l, --length BYTES  Tamanho em bytes (padrao: 32)
#   -f, --format FMT    Formato: hex, base64, base64url (padrao: hex)
#   -c, --count N       Gerar N chaves de uma vez (padrao: 1)
#   --copy              Copia a chave gerada para a area de transferencia
#   --append FILE       Acrescenta a chave ao arquivo .env especificado
#   --dry-run           Exibe o que seria gerado sem salvar
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "openssl" "$INSTALLER openssl"
fi

VAR_NAME=""
BYTE_LENGTH=32
FORMAT="hex"
COUNT=1
COPY=false
APPEND_FILE=""
DRY_RUN=false

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--name)    VAR_NAME="$2"; shift 2 ;;
        -l|--length)  BYTE_LENGTH="$2"; shift 2 ;;
        -f|--format)  FORMAT="$2"; shift 2 ;;
        -c|--count)   COUNT="$2"; shift 2 ;;
        --copy)       COPY=true; shift ;;
        --append)     APPEND_FILE="$2"; shift 2 ;;
        --dry-run)    DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  env-keygen.sh — Gera chaves secretas seguras para arquivos .env"
            echo ""
            echo "  Uso: ./env-keygen.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -n, --name VAR       Nome da variavel (ex: SECRET_KEY)"
            echo "    -l, --length BYTES   Tamanho em bytes (padrao: 32)"
            echo "    -f, --format FMT     Formato: hex | base64 | base64url (padrao: hex)"
            echo "    -c, --count N        Gerar N chaves de uma vez (padrao: 1)"
            echo "    --copy               Copia a chave para a area de transferencia"
            echo "    --append FILE        Acrescenta ao arquivo .env especificado"
            echo "    --dry-run            Exibe sem salvar"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./env-keygen.sh"
            echo "    ./env-keygen.sh -n JWT_SECRET -l 64 -f base64"
            echo "    ./env-keygen.sh -n APP_KEY --append .env"
            echo "    ./env-keygen.sh -n DB_PASS -f base64url --copy"
            echo "    ./env-keygen.sh -c 5 -l 16 -f hex"
            echo ""
            exit 0
            ;;
        --version|-v) echo "env-keygen.sh $VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 1
            ;;
    esac
done

if ! command -v openssl &>/dev/null; then
    error "openssl nao encontrado. Instale com: sudo apt install openssl"
fi

generate_key() {
    case "$FORMAT" in
        hex)       openssl rand -hex "$BYTE_LENGTH" ;;
        base64)    openssl rand -base64 "$BYTE_LENGTH" | tr -d '\n' ;;
        base64url) openssl rand -base64 "$BYTE_LENGTH" | tr -d '\n=' | tr '+/' '-_' ;;
        *) error "Formato invalido: '$FORMAT'. Use: hex, base64, base64url" ;;
    esac
}

copy_to_clipboard() {
    local value="$1"
    if command -v xclip &>/dev/null; then
        echo -n "$value" | xclip -selection clipboard
        success "Chave copiada para a area de transferencia (xclip)"
    elif command -v xsel &>/dev/null; then
        echo -n "$value" | xsel --clipboard --input
        success "Chave copiada para a area de transferencia (xsel)"
    elif command -v wl-copy &>/dev/null; then
        echo -n "$value" | wl-copy
        success "Chave copiada para a area de transferencia (wl-copy)"
    else
        warn "Nenhuma ferramenta de clipboard disponivel (xclip, xsel, wl-copy)"
    fi
}

append_to_env() {
    local line="$1"
    local file="$2"
    if [ ! -f "$file" ]; then
        warn "Arquivo '$file' nao existe — sera criado."
    fi
    if grep -q "^${VAR_NAME}=" "$file" 2>/dev/null; then
        warn "Variavel '${VAR_NAME}' ja existe em '$file'. Use outro nome ou edite manualmente."
        return 1
    fi
    echo "$line" >> "$file"
    success "Adicionado em $file"
}

echo ""
echo -e "  ${BOLD}${CYAN}env-keygen.sh${RESET}  ${DIM}v${VERSION}${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""

LAST_KEY=""
for i in $(seq 1 "$COUNT"); do
    KEY=$(generate_key)

    if [ -n "$VAR_NAME" ]; then
        LINE="${VAR_NAME}=${KEY}"
    else
        LINE="$KEY"
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[Dry-run]${RESET} ${BOLD}${LINE}${RESET}"
    else
        echo -e "  ${GREEN}${BOLD}${LINE}${RESET}"
    fi

    LAST_KEY="$KEY"
done

echo ""
echo -e "  ${DIM}Formato: ${FORMAT}  |  Bytes: ${BYTE_LENGTH}  |  Quantidade: ${COUNT}${RESET}"
echo ""

if [ "$DRY_RUN" = false ]; then
    if [ "$COPY" = true ] && [ "$COUNT" -eq 1 ]; then
        copy_to_clipboard "$LAST_KEY"
    elif [ "$COPY" = true ] && [ "$COUNT" -gt 1 ]; then
        warn "--copy ignorado quando --count > 1"
    fi

    if [ -n "$APPEND_FILE" ]; then
        if [ -z "$VAR_NAME" ]; then
            error "--append requer --name para nomear a variavel no arquivo .env"
        fi
        append_to_env "${VAR_NAME}=${LAST_KEY}" "$APPEND_FILE"
    fi
fi
