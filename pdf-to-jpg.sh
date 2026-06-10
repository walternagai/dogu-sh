#!/bin/bash
# pdf-to-jpg.sh — Converte arquivos .pdf em imagens JPG (Linux)
# Uso: ./pdf-to-jpg.sh [opcoes] ARQUIVO.pdf
# Opcoes:
#   -o, --output DIR       Diretorio de saida (padrao: diretorio atual)
#   -q, --quality N        Qualidade JPEG 1-100 (padrao: 85)
#   -r, --resolution N     Resolucao em DPI (padrao: 150)
#   -p, --prefix STR       Prefixo para arquivos de saida (padrao: nome do PDF)
#   -s, --single-page N    Extrai apenas uma pagina especifica
#   -f, --first-page N     Primeira pagina (padrao: 1)
#   -l, --last-page N      Ultima pagina (padrao: ultima do PDF)
#       --dry-run          Simula a conversao sem gerar arquivos
#   -h, --help             Mostra esta ajuda
#   -V, --version          Mostra versao

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
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "pdftoppm" "$INSTALLER" "poppler-utils"
    check_and_install "pdfinfo" "$INSTALLER" "poppler-utils"
fi

INPUT_PDF=""
OUTPUT_DIR=""
QUALITY=85
RESOLUTION=150
PREFIX=""
SINGLE_PAGE=""
FIRST_PAGE=1
LAST_PAGE=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --output requer um valor${RESET}" >&2; exit 2; }
            OUTPUT_DIR="$2"; shift 2 ;;
        -q|--quality)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --quality requer um valor${RESET}" >&2; exit 2; }
            QUALITY="$2"; shift 2 ;;
        -r|--resolution)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --resolution requer um valor${RESET}" >&2; exit 2; }
            RESOLUTION="$2"; shift 2 ;;
        -p|--prefix)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --prefix requer um valor${RESET}" >&2; exit 2; }
            PREFIX="$2"; shift 2 ;;
        -s|--single-page)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --single-page requer um valor${RESET}" >&2; exit 2; }
            SINGLE_PAGE="$2"; shift 2 ;;
        -f|--first-page)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --first-page requer um valor${RESET}" >&2; exit 2; }
            FIRST_PAGE="$2"; shift 2 ;;
        -l|--last-page)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --last-page requer um valor${RESET}" >&2; exit 2; }
            LAST_PAGE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  pdf-to-jpg.sh — Converte arquivos .pdf em imagens JPG"
            echo ""
            echo "  Uso: ./pdf-to-jpg.sh [opcoes] ARQUIVO.pdf"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output DIR       Diretorio de saida (padrao: diretorio atual)"
            echo "    -q, --quality N        Qualidade JPEG 1-100 (padrao: 85)"
            echo "    -r, --resolution N     Resolucao em DPI (padrao: 150)"
            echo "    -p, --prefix STR       Prefixo para arquivos de saida (padrao: nome do PDF)"
            echo "    -s, --single-page N    Extrai apenas uma pagina especifica"
            echo "    -f, --first-page N     Primeira pagina (padrao: 1)"
            echo "    -l, --last-page N      Ultima pagina (padrao: ultima do PDF)"
            echo "        --dry-run          Simula a conversao sem gerar arquivos"
            echo "    -h, --help             Mostra esta ajuda"
            echo "    -V, --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./pdf-to-jpg.sh documento.pdf"
            echo "    ./pdf-to-jpg.sh -o ./imagens documento.pdf"
            echo "    ./pdf-to-jpg.sh -q 95 -r 300 documento.pdf"
            echo "    ./pdf-to-jpg.sh -s 3 -p capa documento.pdf"
            echo "    ./pdf-to-jpg.sh -f 2 -l 5 documento.pdf"
            echo ""
            exit 0
            ;;
        --version|-V) echo "pdf-to-jpg.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            if [[ -z "$INPUT_PDF" ]]; then
                INPUT_PDF="$1"
            else
                error "Argumentos demais. Informe apenas um arquivo PDF."
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT_PDF" ]]; then
    error "Arquivo PDF nao informado. Uso: ./pdf-to-jpg.sh ARQUIVO.pdf"
fi

if [[ ! -f "$INPUT_PDF" ]]; then
    error "Arquivo nao encontrado: $INPUT_PDF"
fi

if [[ ! "$INPUT_PDF" =~ \.[Pp][Dd][Ff]$ ]]; then
    warn "O arquivo nao possui extensao .pdf: $INPUT_PDF"
fi

if [[ "$QUALITY" -lt 1 || "$QUALITY" -gt 100 ]]; then
    error "Qualidade deve ser um valor entre 1 e 100."
fi

if [[ "$RESOLUTION" -lt 1 ]]; then
    error "Resolucao deve ser um valor positivo."
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="."
fi

if [[ ! -d "$OUTPUT_DIR" ]]; then
    if $DRY_RUN; then
        echo -e "  ${DIM}[Dry-run] mkdir -p $OUTPUT_DIR${RESET}"
    else
        mkdir -p "$OUTPUT_DIR"
    fi
fi

if [[ -z "$PREFIX" ]]; then
    PREFIX=$(basename "$INPUT_PDF" .pdf)
    PREFIX=$(basename "$PREFIX" .PDF)
fi

total_pages=$(pdfinfo "$INPUT_PDF" 2>/dev/null | awk '/^Pages:/ {print $2}')
if [[ -z "$total_pages" || "$total_pages" -lt 1 ]]; then
    error "Nao foi possivel determinar o numero de paginas do PDF: $INPUT_PDF"
fi

if [[ -n "$SINGLE_PAGE" ]]; then
    if [[ "$SINGLE_PAGE" -lt 1 || "$SINGLE_PAGE" -gt "$total_pages" ]]; then
        error "Pagina ${SINGLE_PAGE} fora do intervalo (1-${total_pages})."
    fi
    FIRST_PAGE="$SINGLE_PAGE"
    LAST_PAGE="$SINGLE_PAGE"
fi

if [[ "$FIRST_PAGE" -lt 1 || "$FIRST_PAGE" -gt "$total_pages" ]]; then
    error "Primeira pagina ${FIRST_PAGE} fora do intervalo (1-${total_pages})."
fi

if [[ -z "$LAST_PAGE" ]]; then
    LAST_PAGE="$total_pages"
fi

if [[ "$LAST_PAGE" -lt "$FIRST_PAGE" || "$LAST_PAGE" -gt "$total_pages" ]]; then
    error "Ultima pagina ${LAST_PAGE} invalida. Deve estar entre ${FIRST_PAGE} e ${total_pages}."
fi

echo ""
echo -e "  ${BOLD}PDF → JPG${RESET}  ${DIM}v${VERSION}${RESET}"
echo ""
echo -e "  ${DIM}Arquivo:    ${RESET}${INPUT_PDF}"
echo -e "  ${DIM}Paginas:    ${RESET}${FIRST_PAGE}–${LAST_PAGE} de ${total_pages}"
echo -e "  ${DIM}Resolucao:  ${RESET}${RESOLUTION} DPI"
echo -e "  ${DIM}Qualidade:  ${RESET}${QUALITY}%"
echo -e "  ${DIM}Saida:      ${RESET}${OUTPUT_DIR}/${PREFIX}-*.jpg"
echo ""

if $DRY_RUN; then
    num_pages=$((LAST_PAGE - FIRST_PAGE + 1))
    echo -e "  ${DIM}[Dry-run] Seriam gerados ${num_pages} arquivo(s) com:${RESET}"
    echo -e "  ${DIM}             pdftoppm -jpeg -r ${RESOLUTION} -jpegopt quality=${QUALITY}${RESET}"
    echo -e "  ${DIM}                     -f ${FIRST_PAGE} -l ${LAST_PAGE}${RESET}"
    echo -e "  ${DIM}                     \"${INPUT_PDF}\" \"${OUTPUT_DIR}/${PREFIX}\"${RESET}"
    echo ""
    exit 0
fi

log "Convertendo..."
output_path="${OUTPUT_DIR}/${PREFIX}"

if pdftoppm -jpeg -r "$RESOLUTION" -jpegopt quality="$QUALITY" \
    -f "$FIRST_PAGE" -l "$LAST_PAGE" \
    "$INPUT_PDF" "$output_path" 2>&1 | while IFS= read -r line; do
    echo -e "  ${DIM}${line}${RESET}" >&2
done; then
    :
else
    warn "Tentando sem -jpegopt (versao antiga do pdftoppm)..."
    if pdftoppm -jpeg -r "$RESOLUTION" \
        -f "$FIRST_PAGE" -l "$LAST_PAGE" \
        "$INPUT_PDF" "$output_path" 2>/dev/null; then
        :
    else
        error "Falha ao converter PDF. Verifique se o arquivo e valido."
    fi
fi

echo ""
generated=0
for jpg in "${OUTPUT_DIR}/${PREFIX}"-*.jpg; do
    [[ -f "$jpg" ]] || continue
    size=$(du -h "$jpg" 2>/dev/null | cut -f1)
    echo -e "  ${GREEN}✓${RESET} ${CYAN}${jpg}${RESET}  ${DIM}(${size})${RESET}"
    generated=$((generated + 1))
done

echo ""
if [[ "$generated" -eq 0 ]]; then
    error "Nenhuma imagem JPG foi gerada. Verifique o arquivo PDF."
fi

success "${generated} imagem(ns) gerada(s) em: ${OUTPUT_DIR}"
echo ""

