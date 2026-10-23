#!/bin/bash
# image-optimizer.sh — Redimensiona e comprime imagens em lote
# Uso: ./image-optimizer.sh [opcoes] ARQUIVO|DIRETORIO [...]
# Opcoes:
#   -o, --output DIR    Diretorio de saida (padrao: ./optimized)
#   -r, --recursive     Varre subdiretorios
#   -q, --quality N     Qualidade JPEG/WebP (padrao: 82)
#       --max-width N   Largura maxima em pixels (padrao: 1920)
#   -f, --format FMT    keep, jpg, png ou webp (padrao: keep)
#       --force         Sobrescreve arquivos de saida
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

OUTPUT_DIR="./optimized"
RECURSIVE=false
QUALITY=82
MAX_WIDTH=1920
FORMAT="keep"
FORCE=false
DRY_RUN=false
JSON_MODE=false
INPUTS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 2; }
            OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive) RECURSIVE=true; shift ;;
        -q|--quality)
            [[ -z "${2-}" ]] && { echo "Flag --quality requer um valor" >&2; exit 2; }
            QUALITY="$2"; shift 2 ;;
        --max-width)
            [[ -z "${2-}" ]] && { echo "Flag --max-width requer um valor" >&2; exit 2; }
            MAX_WIDTH="$2"; shift 2 ;;
        -f|--format)
            [[ -z "${2-}" ]] && { echo "Flag --format requer um valor" >&2; exit 2; }
            FORMAT="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  image-optimizer.sh — Redimensiona e comprime imagens em lote"
            echo ""
            echo "  Uso: ./image-optimizer.sh [opcoes] ARQUIVO|DIRETORIO [...]"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output DIR    Diretorio de saida (padrao: ./optimized)"
            echo "    -r, --recursive     Varre subdiretorios"
            echo "    -q, --quality N     Qualidade JPEG/WebP (padrao: 82)"
            echo "        --max-width N   Largura maxima (padrao: 1920)"
            echo "    -f, --format FMT    keep, jpg, png ou webp (padrao: keep)"
            echo "        --force         Sobrescreve arquivos de saida"
            echo "        --dry-run       Mostra o que seria feito"
            echo "        --json          Saida em formato JSON"
            echo "    -h, --help          Mostra esta ajuda"
            echo "    -V, --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./image-optimizer.sh foto.jpg"
            echo "    ./image-optimizer.sh -r ./fotos -o ./web -f webp -q 80"
            echo "    ./image-optimizer.sh --max-width 1280 --dry-run ./fotos"
            echo ""
            exit 0
            ;;
        -V|--version) echo "image-optimizer.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; while [[ $# -gt 0 ]]; do INPUTS+=("$1"); shift; done; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            INPUTS+=("$1"); shift ;;
    esac
done

command -v convert &>/dev/null || error "ImageMagick (convert) nao encontrado."
[ ${#INPUTS[@]} -gt 0 ] || error "Informe ao menos um arquivo ou diretorio."
[[ "$QUALITY" =~ ^[0-9]+$ ]] && [ "$QUALITY" -ge 1 ] && [ "$QUALITY" -le 100 ] || error "Qualidade invalida: $QUALITY"
[[ "$MAX_WIDTH" =~ ^[0-9]+$ ]] && [ "$MAX_WIDTH" -gt 0 ] || error "Largura invalida: $MAX_WIDTH"
case "$FORMAT" in keep|jpg|jpeg|png|webp) ;; *) error "Formato invalido: $FORMAT (use keep, jpg, png ou webp)" ;; esac

FILES=()
for item in "${INPUTS[@]}"; do
    if [ -d "$item" ]; then
        if $RECURSIVE; then
            while IFS= read -r -d '' f; do FILES+=("$f"); done < <(find "$item" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
        else
            while IFS= read -r -d '' f; do FILES+=("$f"); done < <(find "$item" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0)
        fi
    elif [ -f "$item" ]; then
        FILES+=("$item")
    else
        warn "Ignorando (nao encontrado): $item"
    fi
done

[ ${#FILES[@]} -gt 0 ] || error "Nenhuma imagem encontrada."

mkdir -p "$OUTPUT_DIR"
json_files=""
json_first=true
processed=0
failed=0

for f in "${FILES[@]}"; do
    base=$(basename "$f")
    ext="${base##*.}"
    name="${base%.*}"
    out_ext="$ext"
    case "$FORMAT" in
        jpg|jpeg) out_ext="jpg" ;;
        png) out_ext="png" ;;
        webp) out_ext="webp" ;;
    esac
    out="$OUTPUT_DIR/${name}.${out_ext}"

    if [ -f "$out" ] && ! $FORCE; then
        warn "Ja existe (use --force): $out"
        continue
    fi

    if $DRY_RUN; then
        echo "convert \"$f\" -auto-orient -resize \"${MAX_WIDTH}x>\" -strip -quality $QUALITY \"$out\""
        continue
    fi

    before=$(stat -c '%s' "$f" 2>/dev/null || stat -f '%z' "$f" 2>/dev/null || echo 0)
    if convert "$f" -auto-orient -resize "${MAX_WIDTH}x>" -strip -quality "$QUALITY" "$out" 2>/dev/null; then
        after=$(stat -c '%s' "$out" 2>/dev/null || stat -f '%z' "$out" 2>/dev/null || echo 0)
        processed=$((processed + 1))
        $JSON_MODE || success "$base -> $out ($before -> $after bytes)"
        $json_first || json_files+=","
        json_first=false
        json_files+=$(printf '{"input":"%s","output":"%s","bytes_before":%s,"bytes_after":%s}' \
            "$(json_escape "$f")" "$(json_escape "$out")" "$before" "$after")
    else
        failed=$((failed + 1))
        warn "Falha ao otimizar: $f"
    fi
done

if $JSON_MODE; then
    printf '{"output_dir":"%s","processed":%s,"failed":%s,"files":[%s]}\n' \
        "$(json_escape "$OUTPUT_DIR")" "$processed" "$failed" "$json_files"
fi
