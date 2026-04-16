#!/bin/bash
# docx-to-md.sh — Converte arquivos .docx para Markdown (.md) via pandoc (Linux)
# Uso: ./docx-to-md.sh [opcoes] ARQUIVO.docx [ARQUIVO2.docx ...]
# Opcoes:
#   -o, --output DIR    Diretorio de saida (padrao: mesmo diretorio do arquivo)
#   -r, --recursive     Converte todos os .docx em um diretorio recursivamente
#   -s, --suffix SUFIXO Sufixo opcional antes de .md  (ex: .converted → arquivo.converted.md)
#       --overwrite     Sobrescreve arquivos .md existentes sem perguntar
#       --dry-run       Exibe o que seria feito sem converter
#   -h, --help          Mostra esta ajuda
#   -v, --version       Mostra versao

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

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

show_help() {
    echo ""
    echo "  docx-to-md.sh — Converte arquivos .docx para Markdown (.md)"
    echo ""
    echo "  Uso: ./docx-to-md.sh [opcoes] ARQUIVO.docx [ARQUIVO2.docx ...]"
    echo "       ./docx-to-md.sh -r [opcoes] DIRETORIO"
    echo ""
    echo "  Opcoes:"
    echo "    -o, --output DIR     Diretorio de saida (padrao: mesmo diretorio do .docx)"
    echo "    -r, --recursive      Converte todos os .docx em um diretorio"
    echo "    -s, --suffix SUFIXO  Sufixo antes de .md (ex: .converted)"
    echo "        --overwrite      Sobrescreve .md existentes sem perguntar"
    echo "        --dry-run        Simula conversao sem gravar arquivos"
    echo "    -h, --help           Mostra esta ajuda"
    echo "    -v, --version        Mostra versao"
    echo ""
    echo "  Exemplos:"
    echo "    ./docx-to-md.sh relatorio.docx"
    echo "    ./docx-to-md.sh -o ~/documentos relatorio.docx ata.docx"
    echo "    ./docx-to-md.sh -r ./pasta-docs"
    echo "    ./docx-to-md.sh --dry-run -r ./pasta-docs"
    echo "    ./docx-to-md.sh -s .converted relatorio.docx"
    echo ""
}

# --- flags rapidas (antes da checagem de dependencias) ---
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "docx-to-md.sh $VERSION"; exit 0 ;;
    esac
done

# --- dependencias ---
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "pandoc" "$INSTALLER pandoc"
fi

# --- verificacao direta (fallback se dep-helper nao disponivel) ---
if ! command -v pandoc &>/dev/null; then
    error "pandoc nao encontrado. Instale com: sudo apt install pandoc"
fi

# --- variaveis ---
OUTPUT_DIR=""
RECURSIVE=false
DRY_RUN=false
OVERWRITE=false
SUFFIX=""
INPUT_FILES=()

# --- parsing de argumentos ---
while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            [ -z "$2" ] && error "Flag --output requer um diretorio como argumento."
            OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive)
            RECURSIVE=true; shift ;;
        -s|--suffix)
            [ -z "$2" ] && error "Flag --suffix requer um valor."
            SUFFIX="$2"; shift 2 ;;
        --overwrite)
            OVERWRITE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "docx-to-md.sh $VERSION"; exit 0 ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 1
            ;;
        *)
            INPUT_FILES+=("$1"); shift ;;
    esac
done

# --- coleta arquivos em modo recursivo ---
if [ "$RECURSIVE" = true ]; then
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        SEARCH_DIR="."
    else
        SEARCH_DIR="${INPUT_FILES[0]}"
        INPUT_FILES=()
    fi
    [ ! -d "$SEARCH_DIR" ] && error "Diretorio nao encontrado: $SEARCH_DIR"
    while IFS= read -r -d '' f; do
        INPUT_FILES+=("$f")
    done < <(find "$SEARCH_DIR" -type f -iname "*.docx" -print0)
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        warn "Nenhum arquivo .docx encontrado em: $SEARCH_DIR"
        exit 0
    fi
fi

# --- validacao de entrada ---
if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
    echo -e "${RED}Erro: nenhum arquivo .docx informado.${RESET}" >&2
    echo -e "  ${DIM}Use --help para ver o uso.${RESET}" >&2
    exit 1
fi

# --- validacao do diretorio de saida ---
if [ -n "$OUTPUT_DIR" ]; then
    if [ ! -d "$OUTPUT_DIR" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$OUTPUT_DIR"
            log "Diretorio de saida criado: $OUTPUT_DIR"
        else
            log "[Dry-run] Criaria diretorio: $OUTPUT_DIR"
        fi
    fi
fi

# --- contadores ---
CONVERTED=0
SKIPPED=0
ERRORS=0

# --- cabecalho ---
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}  docx-to-md.sh${RESET}  ${DIM}v$VERSION${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}[Dry-run ativado — nenhum arquivo sera gravado]${RESET}"
echo -e "  ${DIM}Arquivos encontrados: ${#INPUT_FILES[@]}${RESET}"
echo ""

# --- funcao de conversao ---
convert_file() {
    local input="$1"

    if [ ! -f "$input" ]; then
        warn "Arquivo nao encontrado, ignorando: $input"
        (( ERRORS++ )) || true
        return
    fi

    # valida extensao
    local ext="${input##*.}"
    if [[ "${ext,,}" != "docx" ]]; then
        warn "Arquivo ignorado (nao e .docx): $input"
        (( SKIPPED++ )) || true
        return
    fi

    # define nome base e diretorio de saida
    local base_name
    base_name=$(basename "$input")
    base_name="${base_name%.[dD][oO][cC][xX]}"

    local dest_dir
    if [ -n "$OUTPUT_DIR" ]; then
        dest_dir="$OUTPUT_DIR"
    else
        dest_dir=$(dirname "$input")
    fi

    local output="${dest_dir}/${base_name}${SUFFIX}.md"

    # verifica sobrescrita
    if [ -f "$output" ] && [ "$OVERWRITE" = false ] && [ "$DRY_RUN" = false ]; then
        warn "Arquivo ja existe, pulando (use --overwrite para forcar): $(basename "$output")"
        (( SKIPPED++ )) || true
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${BLUE}▶${RESET} [Dry-run] ${DIM}$(basename "$input")${RESET} ${DIM}→${RESET} ${BOLD}$(basename "$output")${RESET}"
        (( CONVERTED++ )) || true
        return
    fi

    # converte com pandoc
    local media_dir="${dest_dir}/${base_name}-media"
    if pandoc \
        --from=docx \
        --to=markdown \
        --wrap=none \
        --extract-media="$media_dir" \
        -o "$output" \
        "$input" 2>/tmp/docx-to-md-err; then
        echo -e "  ${GREEN}✓${RESET} ${DIM}$(basename "$input")${RESET} ${DIM}→${RESET} ${BOLD}$(basename "$output")${RESET}"
        (( CONVERTED++ )) || true
    else
        local err_msg
        err_msg=$(head -1 /tmp/docx-to-md-err 2>/dev/null)
        echo -e "  ${RED}✗${RESET} Falha ao converter: $(basename "$input")"
        [ -n "$err_msg" ] && echo -e "    ${DIM}$err_msg${RESET}"
        (( ERRORS++ )) || true
    fi

    # remove pasta de midia vazia (pandoc cria mesmo sem imagens)
    if [ -d "$media_dir" ] && [ -z "$(ls -A "$media_dir" 2>/dev/null)" ]; then
        rmdir "$media_dir"
    fi
}

# --- loop principal ---
for file in "${INPUT_FILES[@]}"; do
    convert_file "$file"
done

# --- resumo ---
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}[Dry-run]${RESET} Seriam convertidos: ${BOLD}$CONVERTED${RESET} arquivo(s)"
else
    echo -e "  ${GREEN}✓ Convertidos:${RESET}  ${BOLD}$CONVERTED${RESET}"
fi
[ "$SKIPPED" -gt 0 ] && echo -e "  ${YELLOW}▶ Ignorados:${RESET}   ${BOLD}$SKIPPED${RESET}"
[ "$ERRORS"  -gt 0 ] && echo -e "  ${RED}✗ Erros:${RESET}      ${BOLD}$ERRORS${RESET}"
echo ""

[ "$ERRORS" -gt 0 ] && exit 1
exit 0
