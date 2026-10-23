#!/bin/bash
# pdf-merge.sh — Junta varios PDFs em um unico arquivo
# Uso: ./pdf-merge.sh [opcoes] ARQUIVO1.pdf ARQUIVO2.pdf [...]
# Opcoes:
#   -o, --output FILE   Arquivo de saida (padrao: merged-<timestamp>.pdf)
#       --force         Sobrescreve o arquivo de saida
#       --dry-run       Mostra o que seria feito
#       --json          Saida em formato JSON
#   -h, --help          Mostra esta ajuda
#   -V, --version       Mostra versao

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

OUTPUT=""
FORCE=false
DRY_RUN=false
JSON_MODE=false
INPUTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 2; }
            OUTPUT="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  pdf-merge.sh — Junta varios PDFs em um unico arquivo"
            echo ""
            echo "  Uso: ./pdf-merge.sh [opcoes] ARQUIVO1.pdf ARQUIVO2.pdf [...]"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output FILE   Arquivo de saida"
            echo "        --force         Sobrescreve o arquivo de saida"
            echo "        --dry-run       Mostra o que seria feito"
            echo "        --json          Saida em formato JSON"
            echo "    -h, --help          Mostra esta ajuda"
            echo "    -V, --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./pdf-merge.sh a.pdf b.pdf c.pdf"
            echo "    ./pdf-merge.sh -o contrato.pdf parte1.pdf parte2.pdf"
            echo ""
            exit 0
            ;;
        -V|--version) echo "pdf-merge.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; while [[ $# -gt 0 ]]; do INPUTS+=("$1"); shift; done; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            INPUTS+=("$1"); shift ;;
    esac
done

command -v pdfunite &>/dev/null || error "pdfunite nao encontrado (poppler-utils)."
command -v pdfinfo &>/dev/null || error "pdfinfo nao encontrado (poppler-utils)."

[ ${#INPUTS[@]} -ge 2 ] || error "Informe ao menos dois PDFs."

for f in "${INPUTS[@]}"; do
    [[ -f "$f" ]] || error "Arquivo nao encontrado: $f"
    [[ "${f,,}" == *.pdf ]] || error "Nao e PDF: $f"
done

if [ -z "$OUTPUT" ]; then
    OUTPUT="merged-$(date '+%Y%m%d_%H%M%S').pdf"
fi
if [ -f "$OUTPUT" ] && ! $FORCE; then
    error "Arquivo ja existe (use --force): $OUTPUT"
fi

TOTAL=0
DETAILS=""
first=true
for f in "${INPUTS[@]}"; do
    pages=$(pdfinfo "$f" 2>/dev/null | awk '/^Pages:/{print $2}')
    [[ "$pages" =~ ^[0-9]+$ ]] || pages=0
    TOTAL=$((TOTAL + pages))
    $first || DETAILS+=","
    first=false
    DETAILS+=$(printf '{"file":"%s","pages":%s}' "$(json_escape "$f")" "$pages")
done

if $DRY_RUN; then
    echo "pdfunite ${INPUTS[*]} \"$OUTPUT\""
    exit 0
fi

pdfunite "${INPUTS[@]}" "$OUTPUT"

if $JSON_MODE; then
    printf '{"output":"%s","inputs":[%s],"pages":%s}\n' \
        "$(json_escape "$OUTPUT")" "$DETAILS" "$TOTAL"
else
    success "PDF gerado: $OUTPUT (${TOTAL} pagina(s))"
fi
