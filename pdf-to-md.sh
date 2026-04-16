#!/bin/bash
# pdf-to-md.sh — Converte arquivos .pdf para Markdown (.md) extraindo o texto (Linux)
# Uso: ./pdf-to-md.sh [opcoes] ARQUIVO.pdf [ARQUIVO2.pdf ...]
# Opcoes:
#   -o, --output DIR       Diretorio de saida (padrao: mesmo diretorio do arquivo)
#   -r, --recursive        Converte todos os .pdf em um diretorio recursivamente
#   -s, --suffix SUFIXO    Sufixo opcional antes de .md
#       --keep-page-breaks Mantem separadores de pagina na extracao do PDF
#       --ocr              Usa OCR quando o PDF nao tiver texto extraivel
#       --ocr-lang IDIOMA  Idioma do OCR (padrao: por)
#       --overwrite        Sobrescreve arquivos .md existentes sem perguntar
#       --dry-run          Exibe o que seria feito sem converter
#   -h, --help             Mostra esta ajuda
#   -v, --version          Mostra versao

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
    echo "  pdf-to-md.sh — Converte arquivos .pdf para Markdown (.md)"
    echo ""
    echo "  Uso: ./pdf-to-md.sh [opcoes] ARQUIVO.pdf [ARQUIVO2.pdf ...]"
    echo "       ./pdf-to-md.sh -r [opcoes] DIRETORIO"
    echo ""
    echo "  Opcoes:"
    echo "    -o, --output DIR        Diretorio de saida (padrao: mesmo diretorio do .pdf)"
    echo "    -r, --recursive         Converte todos os .pdf em um diretorio"
    echo "    -s, --suffix SUFIXO     Sufixo antes de .md (ex: .converted)"
    echo "        --keep-page-breaks  Mantem separadores de pagina extraidos do PDF"
    echo "        --ocr               Usa OCR quando o PDF nao tiver texto extraivel"
    echo "        --ocr-lang IDIOMA   Idioma do OCR (padrao: por)"
    echo "        --overwrite         Sobrescreve .md existentes sem perguntar"
    echo "        --dry-run           Simula conversao sem gravar arquivos"
    echo "    -h, --help              Mostra esta ajuda"
    echo "    -v, --version           Mostra versao"
    echo ""
    echo "  Observacao:"
    echo "    A conversao extrai o texto do PDF e salva em Markdown basico. PDFs"
    echo "    escaneados ou com layout complexo podem exigir ajuste manual."
    echo ""
    echo "  Exemplos:"
    echo "    ./pdf-to-md.sh relatorio.pdf"
    echo "    ./pdf-to-md.sh -o ~/documentos relatorio.pdf manual.pdf"
    echo "    ./pdf-to-md.sh -r ./pasta-pdfs"
    echo "    ./pdf-to-md.sh --dry-run -r ./pasta-pdfs"
    echo "    ./pdf-to-md.sh --keep-page-breaks apostila.pdf"
    echo "    ./pdf-to-md.sh --ocr --ocr-lang por+eng apostila-escaneada.pdf"
    echo ""
}

# --- flags rapidas (antes da checagem de dependencias) ---
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "pdf-to-md.sh $VERSION"; exit 0 ;;
    esac
done

# --- dependencias ---
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "pdftotext" "$INSTALLER poppler-utils || $INSTALLER poppler"
fi

# --- verificacao direta (fallback se dep-helper nao disponivel) ---
if ! command -v pdftotext &>/dev/null; then
    error "pdftotext nao encontrado. Instale com: sudo apt install poppler-utils"
fi

# --- variaveis ---
OUTPUT_DIR=""
RECURSIVE=false
DRY_RUN=false
OVERWRITE=false
KEEP_PAGE_BREAKS=false
USE_OCR=false
OCR_LANG="por"
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
        --keep-page-breaks)
            KEEP_PAGE_BREAKS=true; shift ;;
        --ocr)
            USE_OCR=true; shift ;;
        --ocr-lang)
            [ -z "$2" ] && error "Flag --ocr-lang requer um idioma como argumento."
            OCR_LANG="$2"; shift 2 ;;
        --overwrite)
            OVERWRITE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "pdf-to-md.sh $VERSION"; exit 0 ;;
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
    done < <(find "$SEARCH_DIR" -type f -iname "*.pdf" -print0)
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        warn "Nenhum arquivo .pdf encontrado em: $SEARCH_DIR"
        exit 0
    fi
fi

# --- validacao de entrada ---
if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
    echo -e "${RED}Erro: nenhum arquivo .pdf informado.${RESET}" >&2
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

if [ "$USE_OCR" = true ]; then
    if [ -f "$DEP_HELPER" ]; then
        check_and_install "pdftoppm" "$INSTALLER poppler-utils || $INSTALLER poppler"
        check_and_install "tesseract" "$INSTALLER tesseract-ocr || $INSTALLER tesseract"
    fi

    if ! command -v pdftoppm &>/dev/null; then
        error "pdftoppm nao encontrado. Instale com: sudo apt install poppler-utils"
    fi

    if ! command -v tesseract &>/dev/null; then
        error "tesseract nao encontrado. Instale com: sudo apt install tesseract-ocr"
    fi
fi

# --- contadores ---
CONVERTED=0
SKIPPED=0
ERRORS=0

# --- cabecalho ---
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}  pdf-to-md.sh${RESET}  ${DIM}v$VERSION${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
[ "$DRY_RUN" = true ] && echo -e "  ${YELLOW}[Dry-run ativado — nenhum arquivo sera gravado]${RESET}"
[ "$KEEP_PAGE_BREAKS" = true ] && echo -e "  ${DIM}Separadores de pagina: ${BOLD}ativados${RESET}"
[ "$USE_OCR" = true ] && echo -e "  ${DIM}OCR de fallback: ${BOLD}ativado (${OCR_LANG})${RESET}"
echo -e "  ${DIM}Arquivos encontrados: ${#INPUT_FILES[@]}${RESET}"
echo ""

extract_first_line() {
    local file_path="$1"
    local first_line=""
    if [ -f "$file_path" ]; then
        IFS= read -r first_line < "$file_path" || true
    fi
    printf '%s' "$first_line"
}

run_ocr() {
    local input="$1"
    local output_text="$2"
    local temp_dir="$3"

    local image_prefix="${temp_dir}/page"
    pdftoppm -png -r 300 "$input" "$image_prefix" >/dev/null 2>&1

    local image_found=false
    local page_number=1
    local image_path
    for image_path in "${image_prefix}"-*.png; do
        [ -e "$image_path" ] || continue
        image_found=true
        [ "$page_number" -gt 1 ] && echo "" >> "$output_text"
        [ "$page_number" -gt 1 ] && [ "$KEEP_PAGE_BREAKS" = true ] && echo "---" >> "$output_text"
        [ "$page_number" -gt 1 ] && [ "$KEEP_PAGE_BREAKS" = true ] && echo "" >> "$output_text"
        tesseract "$image_path" stdout -l "$OCR_LANG" >> "$output_text" 2>/dev/null
        page_number=$((page_number + 1))
    done

    [ "$image_found" = true ]
}

convert_file() {
    local input="$1"

    if [ ! -f "$input" ]; then
        warn "Arquivo nao encontrado, ignorando: $input"
        (( ERRORS++ )) || true
        return
    fi

    local ext="${input##*.}"
    if [[ "${ext,,}" != "pdf" ]]; then
        warn "Arquivo ignorado (nao e .pdf): $input"
        (( SKIPPED++ )) || true
        return
    fi

    local base_name
    base_name=$(basename "$input")
    base_name="${base_name%.[pP][dD][fF]}"

    local dest_dir
    if [ -n "$OUTPUT_DIR" ]; then
        dest_dir="$OUTPUT_DIR"
    else
        dest_dir=$(dirname "$input")
    fi

    local output="${dest_dir}/${base_name}${SUFFIX}.md"

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

    local tmp_text
    local tmp_err
    local tmp_dir
    tmp_text=$(mktemp)
    tmp_err=$(mktemp)
    tmp_dir=$(mktemp -d)
    trap 'rm -f "$tmp_text" "$tmp_err"; rm -rf "$tmp_dir"' RETURN

    local page_break_flag="-nopgbrk"
    if [ "$KEEP_PAGE_BREAKS" = true ]; then
        page_break_flag=""
    fi

    if ! pdftotext -layout $page_break_flag "$input" "$tmp_text" 2>"$tmp_err"; then
        if [ "$USE_OCR" = false ]; then
            local err_msg
            err_msg=$(extract_first_line "$tmp_err")
            echo -e "  ${RED}✗${RESET} Falha ao extrair texto de: $(basename "$input")"
            [ -n "$err_msg" ] && echo -e "    ${DIM}$err_msg${RESET}"
            (( ERRORS++ )) || true
            rm -f "$tmp_text" "$tmp_err"
            rm -rf "$tmp_dir"
            trap - RETURN
            return
        fi
    fi

    if [ ! -s "$tmp_text" ]; then
        if [ "$USE_OCR" = true ]; then
            : > "$tmp_text"
            if run_ocr "$input" "$tmp_text" "$tmp_dir" && [ -s "$tmp_text" ]; then
                warn "Texto extraivel ausente; OCR aplicado em: $(basename "$input")"
            else
                echo -e "  ${RED}✗${RESET} PDF sem texto extraivel: $(basename "$input")"
                echo -e "    ${DIM}Falha ao aplicar OCR ou PDF sem conteudo legivel.${RESET}"
                (( ERRORS++ )) || true
                rm -f "$tmp_text" "$tmp_err"
                rm -rf "$tmp_dir"
                trap - RETURN
                return
            fi
        else
            echo -e "  ${RED}✗${RESET} PDF sem texto extraivel: $(basename "$input")"
            echo -e "    ${DIM}O arquivo pode ser escaneado ou protegido. Use --ocr se necessario.${RESET}"
            (( ERRORS++ )) || true
            rm -f "$tmp_text" "$tmp_err"
            rm -rf "$tmp_dir"
            trap - RETURN
            return
        fi
    fi

    if mv "$tmp_text" "$output"; then
        echo -e "  ${GREEN}✓${RESET} ${DIM}$(basename "$input")${RESET} ${DIM}→${RESET} ${BOLD}$(basename "$output")${RESET}"
        (( CONVERTED++ )) || true
    else
        local err_msg
        err_msg=$(extract_first_line "$tmp_err")
        echo -e "  ${RED}✗${RESET} Falha ao converter: $(basename "$input")"
        [ -n "$err_msg" ] && echo -e "    ${DIM}$err_msg${RESET}"
        (( ERRORS++ )) || true
    fi

    rm -f "$tmp_err"
    rm -rf "$tmp_dir"
    trap - RETURN
}

for file in "${INPUT_FILES[@]}"; do
    convert_file "$file"
done

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
