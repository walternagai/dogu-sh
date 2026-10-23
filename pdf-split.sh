#!/bin/bash
# pdf-split.sh — Divide um PDF em paginas ou intervalos
# Uso: ./pdf-split.sh [opcoes] ARQUIVO.pdf
# Opcoes:
#   -p, --pages RANGE    Intervalos: 1-3,5,7- (padrao: uma pagina por arquivo)
#   -o, --output DIR     Diretorio de saida (padrao: ./<nome>-paginas)
#       --prefix NAME    Prefixo dos arquivos (padrao: nome do PDF)
#       --force          Sobrescreve arquivos existentes
#       --dry-run        Mostra o que seria feito
#       --json           Saida em formato JSON
#   -h, --help           Mostra esta ajuda
#   -V, --version        Mostra versao

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

INPUT=""
PAGES=""
OUTPUT_DIR=""
PREFIX=""
FORCE=false
DRY_RUN=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--pages)
            [[ -z "${2-}" ]] && { echo "Flag --pages requer um valor" >&2; exit 2; }
            PAGES="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 2; }
            OUTPUT_DIR="$2"; shift 2 ;;
        --prefix)
            [[ -z "${2-}" ]] && { echo "Flag --prefix requer um valor" >&2; exit 2; }
            PREFIX="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  pdf-split.sh — Divide um PDF em paginas ou intervalos"
            echo ""
            echo "  Uso: ./pdf-split.sh [opcoes] ARQUIVO.pdf"
            echo ""
            echo "  Opcoes:"
            echo "    -p, --pages RANGE    Intervalos: 1-3,5,7- (padrao: uma pagina por arquivo)"
            echo "    -o, --output DIR     Diretorio de saida"
            echo "        --prefix NAME    Prefixo dos arquivos"
            echo "        --force          Sobrescreve arquivos existentes"
            echo "        --dry-run        Mostra o que seria feito"
            echo "        --json           Saida em formato JSON"
            echo "    -h, --help           Mostra esta ajuda"
            echo "    -V, --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./pdf-split.sh documento.pdf"
            echo "    ./pdf-split.sh --pages 1-5 documento.pdf"
            echo "    ./pdf-split.sh --pages 1-3,7,10- -o ./partes documento.pdf"
            echo ""
            exit 0
            ;;
        -V|--version) echo "pdf-split.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            [[ -z "$INPUT" ]] && INPUT="$1" || error "Argumento inesperado: $1"
            shift ;;
    esac
done

[[ -n "$INPUT" ]] || error "Informe um arquivo PDF."
[[ -f "$INPUT" ]] || error "Arquivo nao encontrado: $INPUT"
command -v pdfseparate &>/dev/null || error "pdfseparate nao encontrado (poppler-utils)."
command -v pdfunite &>/dev/null || error "pdfunite nao encontrado (poppler-utils)."
command -v pdfinfo &>/dev/null || error "pdfinfo nao encontrado (poppler-utils)."

TOTAL=$(pdfinfo "$INPUT" 2>/dev/null | awk '/^Pages:/{print $2}')
[[ "$TOTAL" =~ ^[0-9]+$ ]] && [ "$TOTAL" -gt 0 ] || error "Nao foi possivel ler o numero de paginas de $INPUT."

BASE=$(basename "$INPUT" .pdf)
PREFIX="${PREFIX:-$BASE}"
INPUT_DIR=$(cd "$(dirname "$INPUT")" && pwd)
OUTPUT_DIR="${OUTPUT_DIR:-${INPUT_DIR}/${BASE}-paginas}"

mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

json_outputs=""
json_first=true
add_output() {
    local path="$1"
    if $JSON_MODE; then
        $json_first || json_outputs+=","
        json_first=false
        json_outputs+=$(printf '"%s"' "$(json_escape "$path")")
    fi
}

if [ -z "$PAGES" ]; then
    target="$OUTPUT_DIR/${PREFIX}-%d.pdf"
    if $DRY_RUN; then
        echo "pdfseparate \"$INPUT\" \"$target\""
    else
        pdfseparate "$INPUT" "$target"
        for ((p=1; p<=TOTAL; p++)); do
            add_output "$OUTPUT_DIR/${PREFIX}-${p}.pdf"
        done
        $JSON_MODE || success "$TOTAL pagina(s) extraida(s) em $OUTPUT_DIR"
    fi
else
    IFS=',' read -ra RANGES <<< "$PAGES"
    for range in "${RANGES[@]}"; do
        range=$(echo "$range" | tr -d '[:space:]')
        [ -z "$range" ] && continue
        if [[ "$range" =~ ^([0-9]+)-([0-9]*)$ ]]; then
            first="${BASH_REMATCH[1]}"
            last="${BASH_REMATCH[2]:-$TOTAL}"
            label="${first}-${last}"
        elif [[ "$range" =~ ^[0-9]+$ ]]; then
            first="$range"; last="$range"; label="$range"
        else
            error "Intervalo invalido: $range (use 3, 1-5 ou 7-)"
        fi
        [[ "$first" -ge 1 && "$last" -le "$TOTAL" && "$first" -le "$last" ]] \
            || error "Intervalo fora do PDF (1-$TOTAL): $range"

        out="$OUTPUT_DIR/${PREFIX}-${label}.pdf"
        if [ -f "$out" ] && ! $FORCE; then
            warn "Ja existe (use --force): $out"
            continue
        fi
        if $DRY_RUN; then
            echo "pdfseparate -f $first -l $last \"$INPUT\" <tmp> && pdfunite <tmp> \"$out\""
            continue
        fi

        tmp=$(mktemp -d)
        pdfseparate -f "$first" -l "$last" "$INPUT" "$tmp/page-%d.pdf"
        if [ "$first" -eq "$last" ]; then
            cp "$tmp/page-${first}.pdf" "$out"
        else
            pdfunite "$tmp"/page-*.pdf "$out"
        fi
        rm -rf "$tmp"
        add_output "$out"
        $JSON_MODE || success "Gerado: $out"
    done
fi

if $JSON_MODE; then
    printf '{"input":"%s","pages":%s,"outputs":[%s]}\n' \
        "$(json_escape "$INPUT")" "$TOTAL" "$json_outputs"
fi
