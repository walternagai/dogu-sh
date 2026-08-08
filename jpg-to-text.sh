#!/bin/bash
# jpg-to-text.sh — Extrai texto de imagens JPG via OCR (Linux)
# Uso: ./jpg-to-text.sh [opcoes] ARQUIVO.jpg
# Opcoes:
#   -l, --lang LANG     Idioma do OCR (padrao: por+eng)
#   -o, --output ARQ    Salva saida em arquivo .txt (padrao: stdout)
#   -p, --preprocess    Aplica pre-processamento para melhorar OCR
#       --dry-run       Simula a extracao sem gerar arquivos
#   -h, --help          Mostra esta ajuda
#   -V, --version       Mostra versao

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
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "tesseract" "$INSTALLER" "tesseract-ocr"
fi

if ! command -v tesseract &>/dev/null; then
    if [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
        error "tesseract nao encontrado. Instale com: sudo apt install tesseract-ocr"
    fi
fi

INPUT_FILE=""
OUTPUT_FILE=""
LANG="por+eng"
PREPROCESS=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--lang)
            [[ -z "${2-}" ]] && error "Flag --lang requer um valor (ex: por, eng, por+eng)"
            LANG="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && error "Flag --output requer um caminho de arquivo"
            OUTPUT_FILE="$2"; shift 2 ;;
        -p|--preprocess) PREPROCESS=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  jpg-to-text.sh — Extrai texto de imagens JPG via OCR"
            echo ""
            echo "  Uso: ./jpg-to-text.sh [opcoes] ARQUIVO.jpg"
            echo ""
            echo "  Opcoes:"
            echo "    -l, --lang LANG     Idioma do OCR (padrao: por+eng)"
            echo "    -o, --output ARQ    Salva saida em arquivo .txt (padrao: stdout)"
            echo "    -p, --preprocess    Aplica pre-processamento para melhorar OCR"
            echo "        --dry-run       Simula a extracao sem gerar arquivos"
            echo "    -h, --help          Mostra esta ajuda"
            echo "    -V, --version       Mostra versao"
            echo ""
            echo "  Idiomas suportados:"
            echo "    por     Portugues"
            echo "    eng     Ingles"
            echo "    spa     Espanhol"
            echo "    deu     Alemao"
            echo "    fra     Frances"
            echo "    por+eng Portugues + Ingles (padrao)"
            echo ""
            echo "  Exemplos:"
            echo "    ./jpg-to-text.sh foto.jpg"
            echo "    ./jpg-to-text.sh -l eng documento.jpg"
            echo "    ./jpg-to-text.sh -o saida.txt foto.jpg"
            echo "    ./jpg-to-text.sh -p -l por+eng foto.jpg"
            echo ""
            exit 0
            ;;
        --version|-V) echo "jpg-to-text.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            else
                error "Argumentos demais. Informe apenas um arquivo JPG."
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    error "Arquivo JPG nao informado. Uso: ./jpg-to-text.sh ARQUIVO.jpg"
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    error "Arquivo nao encontrado: $INPUT_FILE"
fi

if [[ ! "$INPUT_FILE" =~ \.[Jj][Pp][Gg]$ && ! "$INPUT_FILE" =~ \.[Jj][Pp][Ee][Gg]$ ]]; then
    warn "O arquivo nao possui extensao .jpg/.jpeg: $INPUT_FILE"
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${INPUT_FILE%.*}.txt"
fi

if [[ -d "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${OUTPUT_FILE}/$(basename "${INPUT_FILE%.*}").txt"
fi

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

echo ""
echo -e "  ${BOLD}JPG → Texto (OCR)${RESET}  ${DIM}v${VERSION}${RESET}"
echo ""
echo -e "  ${DIM}Arquivo:    ${RESET}${INPUT_FILE}"
echo -e "  ${DIM}Idioma:     ${RESET}${LANG}"
echo -e "  ${DIM}Saida:      ${RESET}${OUTPUT_FILE}"
echo -e "  ${DIM}Preprocess: ${RESET}$([ "$PREPROCESS" = true ] && echo "sim" || echo "nao")"
echo ""

if $DRY_RUN; then
    echo -e "  ${DIM}[Dry-run] Seria executado:${RESET}"
    echo -e "  ${DIM}  tesseract \"$INPUT_FILE\" stdout -l ${LANG}${RESET}"
    echo -e "  ${DIM}  Resultado salvo em: ${OUTPUT_FILE}${RESET}"
    echo ""
    exit 0
fi

log "Processando OCR..."

OCR_INPUT="$INPUT_FILE"

if [[ "$PREPROCESS" == true ]]; then
    if command -v convert &>/dev/null; then
        log "Aplicando pre-processamento com ImageMagick..."
        PREPROCESS_FILE=$(mktemp --suffix=.png)
        trap 'rm -f "$TMPFILE" "$PREPROCESS_FILE"' EXIT
        convert "$INPUT_FILE" -colorspace Gray -threshold 50% -sharpen 0x1 "$PREPROCESS_FILE" 2>/dev/null
        OCR_INPUT="$PREPROCESS_FILE"
    else
        warn "ImageMagick (convert) nao encontrado. Pre-processamento ignorado."
    fi
fi

if tesseract "$OCR_INPUT" "stdout" -l "$LANG" > "$TMPFILE" 2>/dev/null; then
    extracted_text=$(cat "$TMPFILE")
    char_count=${#extracted_text}

    if [[ "$char_count" -eq 0 ]]; then
        warn "Nenhum texto detectado na imagem. A imagem pode nao conter texto legivel."
    fi

    mkdir -p "$(dirname "$OUTPUT_FILE")"
    cp "$TMPFILE" "$OUTPUT_FILE"

    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    echo ""
    echo -e "  ${GREEN}✓${RESET} Texto extraido com sucesso"
    echo -e "  ${DIM}Caracteres: ${RESET}${char_count}"
    echo -e "  ${DIM}Arquivo:    ${RESET}${OUTPUT_FILE}"
    echo ""
    echo -e "  ${DIM}--- Preview (primeiras 5 linhas) ---${RESET}"
    head -5 "$OUTPUT_FILE" | while IFS= read -r line; do
        echo -e "  ${line}"
    done
    echo ""
    success "Texto salvo em: ${OUTPUT_FILE}"
else
    error "Falha ao executar tesseract. Verifique se o arquivo e uma imagem valida."
fi
