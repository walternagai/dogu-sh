#!/bin/bash
# batch-rename.sh — Renomeia arquivos em lote por padrão de busca/substituição (Linux)
# Uso: ./batch-rename.sh [opcoes] <arquivo> [<arquivo2> ...]
# Opcoes:
#   --find=PADRAO       Texto a procurar no nome (usado com --replace)
#   --replace=TEXTO     Substituicao do padrao (padrao: remove o trecho)
#   --prefix=TEXTO      Adiciona texto no inicio do nome
#   --suffix=TEXTO      Adiciona texto antes da extensao
#   --ext=NOVA_EXT      Troca a extensao (ex: --ext=md); sem valor remove a extensao
#   --lower             Converte nome para minusculas
#   --upper             Converte nome para maiusculas
#   --seq               Adiciona numeracao sequencial antes da extensao
#   --seq-start=N       Numero inicial da sequencia (padrao: 1)
#   --regex             Trata --find como expressao regular (BRE do sed)
#   --include-dir       Inclui diretorios, nao apenas arquivos
#   --dry-run           Apenas mostra as mudancas, nao renomeia nada
#   --force             Nao pedir confirmacao antes de renomear
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -euo pipefail

readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

# Sem dependencias externas alem do coreutils (sed, mv) — nao usa dependency-helper

# =============================================
# Defaults
# =============================================

FIND_PATTERN=""
REPLACE_TEXT=""
PREFIX_TEXT=""
SUFFIX_TEXT=""
NEW_EXT=""
EXT_SET=false
CASE_MODE=""       # "lower" | "upper" | ""
USE_SEQ=false
SEQ_START=1
USE_REGEX=false
INCLUDE_DIR=false
DRY_RUN=false
FORCE=false
POSITIONAL=()

# =============================================
# Parsing de argumentos
# =============================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --find=*) FIND_PATTERN="${1#--find=}"; shift ;;
        --replace=*) REPLACE_TEXT="${1#--replace=}"; shift ;;
        --prefix=*) PREFIX_TEXT="${1#--prefix=}"; shift ;;
        --suffix=*) SUFFIX_TEXT="${1#--suffix=}"; shift ;;
        --ext=*) NEW_EXT="${1#--ext=}"; EXT_SET=true; shift ;;
        --lower) CASE_MODE="lower"; shift ;;
        --upper) CASE_MODE="upper"; shift ;;
        --seq) USE_SEQ=true; shift ;;
        --seq-start=*)
            [[ "${1#--seq-start=}" =~ ^[0-9]+$ ]] || error "Valor invalido para --seq-start: '${1#--seq-start=}'"
            SEQ_START="${1#--seq-start=}"
            shift
            ;;
        --regex) USE_REGEX=true; shift ;;
        --include-dir) INCLUDE_DIR=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --help|-h)
            echo ""
            echo "  batch-rename.sh — Renomeia arquivos em lote por padrão de busca/substituição"
            echo ""
            echo "  Uso: ./batch-rename.sh [opcoes] <arquivo> [<arquivo2> ...]"
            echo ""
            echo "  Opcoes:"
            echo "    --find=PADRAO     Texto a procurar no nome (obrigatorio a menos que use"
            echo "                      --prefix/--suffix/--ext/--lower/--upper/--seq)"
            echo "    --replace=TEXTO   Substituicao do padrao (padrao: remove o trecho)"
            echo "    --prefix=TEXTO    Adiciona texto no inicio do nome"
            echo "    --suffix=TEXTO    Adiciona texto antes da extensao"
            echo "    --ext=NOVA_EXT    Troca a extensao (ex: --ext=md); sem valor remove"
            echo "    --lower           Converte nome para minusculas"
            echo "    --upper           Converte nome para maiusculas"
            echo "    --seq             Numeracao sequencial antes da extensao"
            echo "    --seq-start=N     Numero inicial da sequencia (padrao: 1)"
            echo "    --regex           Trata --find como expressao regular (BRE do sed)"
            echo "    --include-dir     Inclui diretorios, nao apenas arquivos"
            echo "    --dry-run         Apenas mostra as mudancas (recomendado antes de aplicar)"
            echo "    --force           Nao pedir confirmacao"
            echo "    --help|-h         Mostra esta ajuda"
            echo "    --version|-V      Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./batch-rename.sh --find=' ' --replace=_ --dry-run *.txt"
            echo "    ./batch-rename.sh --find=IMG --replace=FOTO *.jpg"
            echo "    ./batch-rename.sh --prefix=2024- *.md"
            echo "    ./batch-rename.sh --suffix=_v2 *.sh"
            echo "    ./batch-rename.sh --ext=txt *.log"
            echo "    ./batch-rename.sh --lower *.JPG"
            echo "    ./batch-rename.sh --seq *.png        # foto.png -> foto-1.png, ..."
            echo "    ./batch-rename.sh --regex --find='^cap_' --replace='capitulo-' *.mp3"
            echo ""
            exit 0
            ;;
        --version|-V)
            echo "batch-rename.sh $VERSION"
            exit 0
            ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

while [[ $# -gt 0 ]]; do
    POSITIONAL+=("$1")
    shift
done

# =============================================
# Validações
# =============================================

if [[ ${#POSITIONAL[@]} -eq 0 ]]; then
    error "Nenhum arquivo informado. Uso: ./batch-rename.sh [opcoes] <arquivo> [<arquivo2> ...]"
fi

HAS_TEXT_OP=false
[[ -n "$PREFIX_TEXT" || -n "$SUFFIX_TEXT" || "$EXT_SET" == true || -n "$CASE_MODE" || "$USE_SEQ" == true ]] && HAS_TEXT_OP=true

if [[ -z "$FIND_PATTERN" && "$HAS_TEXT_OP" == false ]]; then
    error "Informe --find (com --replace) ou alguma operacao: --prefix/--suffix/--ext/--lower/--upper/--seq"
fi

# =============================================
# Geracao do novo nome
# =============================================

compute_new_name() {
    local old_name="$1"
    local base ext new_base new_name

    base="${old_name%.*}"
    ext=""
    # Só considera extensao se houver ponto e o nome não seja dotfile puro (ex: .bashrc)
    if [[ "$old_name" == *.* && "$base" != "" ]]; then
        ext="${old_name##*.}"
    else
        base="$old_name"
        ext=""
    fi

    if [[ "$USE_REGEX" == true && -n "$FIND_PATTERN" ]]; then
        new_base=$(printf '%s' "$base" | sed -e "s/$FIND_PATTERN/$REPLACE_TEXT/g")
    elif [[ -n "$FIND_PATTERN" ]]; then
        # Escape de caracteres especiais de regex (BRE) para busca literal
        local escaped_find escaped_replace
        escaped_find=$(printf '%s' "$FIND_PATTERN" | sed -e 's/[][^\/.*^$]/\\&/g')
        escaped_replace=$(printf '%s' "$REPLACE_TEXT" | sed -e 's/[\/&]/\\&/g')
        new_base=$(printf '%s' "$base" | sed -e "s/$escaped_find/$escaped_replace/g")
    else
        new_base="$base"
    fi

    [[ -n "$PREFIX_TEXT" ]] && new_base="${PREFIX_TEXT}${new_base}"
    [[ -n "$SUFFIX_TEXT" ]] && new_base="${new_base}${SUFFIX_TEXT}"

    if [[ "$USE_SEQ" == true ]]; then
        new_base="${new_base}-${SEQ_COUNTER}"
        SEQ_COUNTER=$((SEQ_COUNTER + 1))
    fi

    if [[ "$EXT_SET" == true ]]; then
        if [[ -n "$NEW_EXT" ]]; then
            ext="${NEW_EXT#.}"
        else
            ext=""
        fi
    fi

    case "$CASE_MODE" in
        lower) new_base="${new_base,,}" ;;
        upper) new_base="${new_base^^}" ;;
    esac

    new_name="$new_base"
    [[ -n "$ext" ]] && new_name="${new_name}.${ext}"

    if [[ -n "$new_name" && "$old_name" != "$new_name" ]]; then
        printf '%s' "$new_name"
    fi
}

# Coleta candidatos
SEQ_COUNTER=$SEQ_START
renamed_count=0
target_count=0
declare -a PLAN_OLD=()
declare -a PLAN_NEW=()

for path in "${POSITIONAL[@]}"; do
    if [[ ! -e "$path" ]]; then
        warn "Nao encontrado: $path"
        continue
    fi
    if [[ -d "$path" && "$INCLUDE_DIR" == false ]]; then
        warn "Ignorando diretorio (use --include-dir): $path"
        continue
    fi

    dir_path=$(dirname -- "$path")
    old_name=$(basename -- "$path")
    new_name=$(compute_new_name "$old_name" || true)

    if [[ -z "$new_name" ]]; then
        continue
    fi

    if [[ -e "$dir_path/$new_name" ]]; then
        warn "Destino ja existe, pulando: $dir_path/$new_name"
        continue
    fi

    PLAN_OLD+=("$path")
    PLAN_NEW+=("$dir_path/$new_name")
    target_count=$((target_count + 1))
done

if [[ "$target_count" -eq 0 ]]; then
    echo ""
    warn "Nada a renomear. Dica: use --dry-run para inspecionar, ou verifique se o padrao altera algum nome."
    exit 0
fi

# =============================================
# Preview
# =============================================

echo ""
echo -e "  ${BOLD}Renomeacao em lote${RESET}"
if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Nada sera modificado"
fi
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"

for i in "${!PLAN_OLD[@]}"; do
    printf "  ${DIM}▸${RESET} %s\n" "$(basename -- "${PLAN_OLD[$i]}")"
    printf "    ${DIM}↓${RESET}\n"
    printf "  ${GREEN}▸${RESET} %s\n" "$(basename -- "${PLAN_NEW[$i]}")"
done

echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
echo -e "  Total: ${BOLD}$target_count${RESET} item(ns)"

if $DRY_RUN; then
    echo ""
    echo -e "  ${DIM}Execute sem --dry-run para aplicar.${RESET}"
    echo ""
    exit 0
fi

# =============================================
# Confirmação (guard TTY conforme SCRIPTING_GUIDE §5)
# =============================================

if ! $FORCE; then
    printf "  Confirmar renomeacao? [s/N] "
    if [ -t 0 ]; then
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    else
        error "Execucao nao interativa detectada. Rode em terminal interativo (TTY), ou use --force."
    fi
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        echo -e "  ${DIM}Operacao cancelada.${RESET}"
        exit 0
    fi
fi

# =============================================
# Execução
# =============================================

echo ""
for i in "${!PLAN_OLD[@]}"; do
    if mv -- "${PLAN_OLD[$i]}" "${PLAN_NEW[$i]}"; then
        renamed_count=$((renamed_count + 1))
        success "✓ $(basename -- "${PLAN_OLD[$i]}") -> $(basename -- "${PLAN_NEW[$i]}")"
    else
        warn "✗ Falha ao renomear: ${PLAN_OLD[$i]}"
    fi
done

echo ""
if [[ "$renamed_count" -eq "$target_count" ]]; then
    success "✓ $renamed_count item(ns) renomeado(s) com sucesso."
else
    warn "Concluido parcialmente: $renamed_count de $target_count renomeado(s)."
    exit 1
fi
echo ""