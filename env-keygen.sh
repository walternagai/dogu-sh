#!/bin/bash
# env-keygen.sh — Gera chaves secretas seguras para uso em arquivos .env
# Uso: ./env-keygen.sh [opcoes]
# Opcoes:
#   -n, --name VAR      Nome da variavel (ex: SECRET_KEY)
#   -l, --length N      Tamanho em bytes ou caracteres (padrao: 32)
#   -f, --format FMT    Formato (padrao: hex)
#   -c, --count N       Gerar N chaves de uma vez (padrao: 1)
#   --upper             Gerar em maiusculas (aplica a hex, alnum, uuid, rails)
#   --no-hyphen         Remover hifens (aplica a uuid)
#   --copy              Copia a chave gerada para a area de transferencia
#   --append FILE       Acrescenta a chave ao arquivo .env especificado
#   --dry-run           Exibe o que seria gerado sem salvar
#   --help              Mostra esta ajuda
#   --version           Mostra versao
#
# Formatos disponiveis:
#   hex        Bytes hexadecimais (2x tamanho em chars)
#   base64     Base64 padrao
#   base64url  Base64 URL-safe (sem +/=)
#   uuid       UUID v4 (tamanho fixo, ignora --length)
#   alnum      Apenas letras e numeros
#   django     Django SECRET_KEY, 50 chars (tamanho fixo, ignora --length)
#   fernet     Chave Fernet, 44 chars base64url (tamanho fixo, ignora --length)
#   rails      Rails secret_key_base, 64 hex (tamanho fixo, ignora --length)
#   ascii      ASCII imprimivel (33-126)
#   numeric    Apenas digitos
#   password   Senha legivel com pontuacao segura

set -eo pipefail

VERSION="1.1.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
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
UPPER=false
NO_HYPHEN=false
LENGTH_SET=false

VALID_FORMATS="hex base64 base64url uuid alnum django fernet rails ascii numeric password"
FIXED_FORMATS="uuid django fernet rails"

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--name)      VAR_NAME="$2"; shift 2 ;;
        -l|--length)    BYTE_LENGTH="$2"; LENGTH_SET=true; shift 2 ;;
        -f|--format)    FORMAT="$2"; shift 2 ;;
        -c|--count)     COUNT="$2"; shift 2 ;;
        --upper|-u)     UPPER=true; shift ;;
        --no-hyphen)    NO_HYPHEN=true; shift ;;
        --copy)         COPY=true; shift ;;
        --append)       APPEND_FILE="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  env-keygen.sh — Gera chaves secretas seguras para arquivos .env"
            echo ""
            echo "  Uso: ./env-keygen.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -n, --name VAR       Nome da variavel (ex: SECRET_KEY)"
            echo "    -l, --length N       Tamanho em bytes/chars (padrao: 32)"
            echo "    -f, --format FMT     Formato (padrao: hex)"
            echo "    -c, --count N        Gerar N chaves de uma vez (padrao: 1)"
            echo "    --upper|-u           Maiusculas (hex, alnum, uuid, rails)"
            echo "    --no-hyphen          Sem hifens (uuid)"
            echo "    --copy               Copia a chave para a area de transferencia"
            echo "    --append FILE        Acrescenta ao arquivo .env especificado"
            echo "    --dry-run            Exibe sem salvar"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Formatos:"
            echo "    hex        Bytes hexadecimais"
            echo "    base64     Base64 padrao"
            echo "    base64url  Base64 URL-safe (sem +/=)"
            echo "    uuid       UUID v4 (tamanho fixo)"
            echo "    alnum      Apenas letras e numeros"
            echo "    django     Django SECRET_KEY, 50 chars (tamanho fixo)"
            echo "    fernet     Chave Fernet, 44 chars (tamanho fixo)"
            echo "    rails      Rails secret_key_base, 64 hex (tamanho fixo)"
            echo "    ascii      ASCII imprimivel (33-126)"
            echo "    numeric    Apenas digitos"
            echo "    password   Senha com pontuacao segura"
            echo ""
            echo "  Exemplos:"
            echo "    ./env-keygen.sh"
            echo "    ./env-keygen.sh -n JWT_SECRET -l 64 -f base64"
            echo "    ./env-keygen.sh -n APP_KEY --append .env"
            echo "    ./env-keygen.sh -n DB_PASS -f base64url --copy"
            echo "    ./env-keygen.sh -c 5 -l 16 -f hex"
            echo "    ./env-keygen.sh -f uuid -n API_CLIENT_ID"
            echo "    ./env-keygen.sh -f django -n DJANGO_SECRET_KEY"
            echo "    ./env-keygen.sh -f fernet -n FERNET_KEY"
            echo "    ./env-keygen.sh -f rails -n SECRET_KEY_BASE"
            echo "    ./env-keygen.sh -f alnum -l 48 -n STRIPE_WEBHOOK_SECRET"
            echo "    ./env-keygen.sh -f password -l 20 --copy"
            echo "    ./env-keygen.sh -f numeric -l 6 -n SMS_OTP_SEED"
            echo "    ./env-keygen.sh -f ascii -l 64 -n ENCRYPTION_KEY"
            echo "    ./env-keygen.sh -f uuid --upper --no-hyphen -n DEVICE_ID"
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

if ! echo "$VALID_FORMATS" | grep -qw "$FORMAT"; then
    error "Formato invalido: '$FORMAT'. Use: $VALID_FORMATS"
fi

if [ "$LENGTH_SET" = true ]; then
    for fmt in $FIXED_FORMATS; do
        if [ "$FORMAT" = "$fmt" ]; then
            warn "Formato '$FORMAT' tem tamanho fixo — --length sera ignorado."
            break
        fi
    done
fi

if [ "$NO_HYPHEN" = true ] && [ "$FORMAT" != "uuid" ]; then
    warn "--no-hyphen so se aplica ao formato 'uuid' — sera ignorado."
fi

if ! command -v openssl &>/dev/null; then
    error "openssl nao encontrado. Instale com: sudo apt install openssl"
fi

generate_uuid_raw() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    elif [ -r /dev/urandom ]; then
        local hex
        hex=$(od -N16 -tx1 -An /dev/urandom | tr -d ' \n')
        local time_lo="${hex:0:8}"
        local time_mid="${hex:8:4}"
        local time_hi="${hex:12:4}"
        local clk_hi="${hex:16:2}"
        local clk_lo="${hex:18:2}"
        local node="${hex:20:12}"
        time_hi="4${time_hi:1:3}"
        local csh_dec=$((16#$clk_hi))
        csh_dec=$((csh_dec & 0x3 | 0x8))
        clk_hi=$(printf '%02x' "$csh_dec")
        echo "${time_lo}-${time_mid}-${time_hi}-${clk_hi}${clk_lo}-${node}"
    elif command -v python3 &>/dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    else
        error "uuidgen, python3 ou /dev/urandom necessarios para gerar UUID."
    fi
}

generate_key() {
    case "$FORMAT" in
        hex)
            openssl rand -hex "$BYTE_LENGTH"
            ;;
        base64)
            openssl rand -base64 "$BYTE_LENGTH" | tr -d '\n'
            ;;
        base64url)
            openssl rand -base64 "$BYTE_LENGTH" | tr -d '\n=' | tr '+/' '-_'
            ;;
        uuid)
            generate_uuid_raw
            ;;
        alnum)
            local len=$((BYTE_LENGTH))
            local chars=""
            while [ ${#chars} -lt "$len" ]; do
                local chunk
                chunk=$(openssl rand -base64 48 | tr -d '\n' | tr -cd 'A-Za-z0-9')
                chars="${chars}${chunk}"
            done
            echo "${chars:0:$len}"
            ;;
        django)
            local charset='A-Za-z0-9!@#$%^&*()_+-=[]{}|;:,.<>?'
            local key=""
            while [ ${#key} -lt 50 ]; do
                local chunk
                chunk=$(openssl rand -base64 96 | tr -d '\n' | tr -cd "$charset")
                key="${key}${chunk}"
            done
            echo "${key:0:50}"
            ;;
        fernet)
            openssl rand -base64 32 | tr -d '\n'
            ;;
        rails)
            openssl rand -hex 64
            ;;
        ascii)
            local len=$((BYTE_LENGTH))
            local key=""
            while [ ${#key} -lt "$len" ]; do
                local chunk
                chunk=$(openssl rand -base64 96 | tr -d '\n' | tr -cd '!-~')
                key="${key}${chunk}"
            done
            echo "${key:0:$len}"
            ;;
        numeric)
            local len=$((BYTE_LENGTH))
            local key=""
            while [ ${#key} -lt "$len" ]; do
                local chunk
                chunk=$(openssl rand -base64 48 | tr -d '\n' | tr -cd '0-9')
                key="${key}${chunk}"
            done
            echo "${key:0:$len}"
            ;;
        password)
            local len=$((BYTE_LENGTH))
            local charset='A-Za-z0-9!@#$%^&*()_+-='
            local key=""
            while [ ${#key} -lt "$len" ]; do
                local chunk
                chunk=$(openssl rand -base64 96 | tr -d '\n' | tr -cd "$charset")
                key="${key}${chunk}"
            done
            echo "${key:0:$len}"
            ;;
        *)
            error "Formato invalido: '$FORMAT'. Use: $VALID_FORMATS"
            ;;
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

    if [ "$FORMAT" = "uuid" ] && [ "$NO_HYPHEN" = true ]; then
        KEY=$(echo "$KEY" | tr -d '-')
    fi

    if [ "$UPPER" = true ]; then
        case "$FORMAT" in
            hex|alnum|uuid|rails|password|ascii|django)
                KEY=$(echo "$KEY" | tr '[:lower:]' '[:upper:]')
                ;;
        esac
    fi

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

INFO_FMT="$FORMAT"
INFO_LEN="len: ${BYTE_LENGTH}"
case "$FORMAT" in
    uuid)    INFO_LEN="len: 36 (fixo)" ;;
    django)  INFO_LEN="len: 50 (fixo)" ;;
    fernet)  INFO_LEN="len: 44 (fixo)" ;;
    rails)   INFO_LEN="len: 128 (64 bytes)" ;;
esac

echo -e "  ${DIM}Formato: ${INFO_FMT}  |  ${INFO_LEN}  |  Quantidade: ${COUNT}${RESET}"
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