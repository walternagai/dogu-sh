#!/bin/bash
# organize-downloads.sh — Organize files by extension type (Linux)
# Uso: ./organize-downloads.sh [pasta]   (padrao: ~/Downloads)
# Opcoes:
#   --dry-run       Preview sem mover arquivos
#   --recursive     Processa subpastas tambem
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

VERSION="1.2.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
DIM='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

DRY_RUN=false
RECURSIVE=false
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --recursive|-r)
            RECURSIVE=true
            shift
            ;;
        --help|-h)
            echo ""
            echo "  organize-downloads.sh — Organiza arquivos por tipo de extensao"
            echo ""
            echo "  Uso: ./organize-downloads.sh [opcoes] [pasta]"
            echo ""
            echo "  Argumentos:"
            echo "    pasta         Diretorio a organizar (padrao: .)"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem mover arquivos"
            echo "    --recursive   Processa subpastas tambem"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./organize-downloads.sh"
            echo "    ./organize-downloads.sh --dry-run ~/Downloads"
            echo "    ./organize-downloads.sh --recursive ~/Downloads"
            echo ""
            exit 0
            ;;
        --version|-v)
            echo "organize-downloads.sh $VERSION"
            exit 0
            ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 1
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

TARGET="${POSITIONAL_ARGS[0]:-.}"
TARGET="${TARGET%/}"

if [ ! -d "$TARGET" ]; then
    echo "Erro: '$TARGET' nao e um diretorio valido." >&2
    exit 1
fi

get_category() {
    local ext="$1"
    case "$ext" in
        jpg|jpeg|png|gif|bmp|svg|webp|ico|tiff|heic|heif|raw|cr2|nef|avif|dng|jxl|eps|psd|xcf|pbm|pgm|ppm|hdr|qoi)
            echo "Imagens" ;;
        pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf|tex|pages|numbers|key|epub|djvu|mobi|azw|azw3|cbr|cbz|xps|oxps|docm|xlsm|pptm|fodt|fods|fodp|log|ps)
            echo "Documentos" ;;
        mp4|mov|avi|mkv|wmv|flv|webm|m4v|mpg|mpeg|ts|3gp|3g2|vob|ogv|m2ts|mts|rm|rmvb|asf|divx|f4v)
            echo "Videos" ;;
        mp3|wav|flac|aac|ogg|wma|m4a|opus|aiff|alac|mid|midi|ape|wv|tta|spx|mpc|mp2|dsf|dff|mod|s3m|xm|it)
            echo "Audio" ;;
        dmg|pkg|exe|msi|deb|rpm|appimage|snap|flatpak|apk|ipa|app|cab)
            echo "Instaladores" ;;
        zip|rar|7z|tar|gz|bz2|xz|tgz|zst|lz4|lzma|lzo|cpio|iso|img|jar|war|ar|z)
            echo "Compactados" ;;
        py|js|html|css|sh|json|xml|yaml|yml|md|csv|sql|rb|go|rs|java|c|cpp|h|swift|kt|lua|r|ts|tsx|jsx|php|pl|vue|svelte|dart|zig|nim|toml|ini|scss|sass|less|proto|cmake|cs|fs|hs|ex|clj|scala|erl|sol)
            echo "Codigo" ;;
        ttf|otf|woff|woff2|eot)
            echo "Fontes" ;;
        *)
            echo "Outros" ;;
    esac
}

get_extension() {
    local filename="$1"

    # Dotfiles sem extensao real (ex: .gitignore → ext="", category=Outros)
    case "$filename" in
        .*)
            local bare="${filename#.}"
            if [ "$bare" = "${bare#*.}" ]; then
                echo ""
                return
            fi
            ;;
    esac

    local ext="${filename##*.}"
    if [ "$ext" = "$filename" ]; then
        echo ""
        return
    fi
    echo "$ext" | tr '[:upper:]' '[:lower:]'
}

MOVED=0
COUNTS_FILE=$(mktemp)
trap 'rm -f "$COUNTS_FILE"' EXIT

echo ""

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem mover arquivos"
fi

echo -e "  Escaneando ${BOLD}$TARGET${RESET}..."

process_file() {
    local file="$1"
    local target_dir="$2"

    [ -f "$file" ] || return

    local filename
    filename=$(basename "$file")

    case "$filename" in
        .*) return ;;
    esac

    local ext
    ext=$(get_extension "$filename")

    local category
    if [ -z "$ext" ]; then
        category="Outros"
    else
        category=$(get_category "$ext")
    fi

    local dest="$target_dir/$category"
    local dest_file="$dest/$filename"

    if [ -e "$dest_file" ]; then
        local base="${filename%.*}"
        local suffix="${filename##*.}"
        if [ "$filename" = "$suffix" ]; then
            local n=1
            while [ -e "$dest/$filename ($n)" ]; do
                n=$((n + 1))
            done
            dest_file="$dest/$filename ($n)"
        else
            local n=1
            while [ -e "$dest/$base ($n).$suffix" ]; do
                n=$((n + 1))
            done
            dest_file="$dest/$base ($n).$suffix"
        fi
    fi

    if $DRY_RUN; then
        echo -e "  ${DIM}→${RESET} $filename ${DIM}→${RESET} ${CYAN}$category/${RESET}"
    else
        mkdir -p "$dest"
        mv "$file" "$dest_file"
        echo -e "  ${DIM}→${RESET} $filename ${DIM}→${RESET} ${CYAN}$category/${RESET}"
    fi

    echo "$category" >> "$COUNTS_FILE"
    MOVED=$((MOVED + 1))
}

if $RECURSIVE; then
    while IFS= read -r -d '' file; do
        local_dir=$(dirname "$file")

        # Nao organizar arquivos que ja estao dentro de subpastas de categoria
        local parent_dir
        parent_dir=$(basename "$local_dir")
        case "$parent_dir" in
            Imagens|Documentos|Videos|Audio|Instaladores|Compactados|Codigo|Fontes|Outros)
                continue
                ;;
        esac

        process_file "$file" "$local_dir"
    done < <(find "$TARGET" -mindepth 1 -type f -not -path '*/\.*' -print0 2>/dev/null)
else
    for file in "$TARGET"/*; do
        process_file "$file" "$TARGET"
    done
fi

echo ""

if [ $MOVED -eq 0 ]; then
    echo -e "  ${DIM}Nenhum arquivo pra organizar.${RESET}"
else
    if $DRY_RUN; then
        echo -e "  ${YELLOW}$MOVED arquivos seriam organizados:${RESET}"
    else
        echo -e "  ${GREEN}✓ $MOVED arquivos organizados:${RESET}"
    fi
    echo ""
    sort "$COUNTS_FILE" | uniq -c | sort -rn | while read -r count cat; do
        printf "  %-16s ${BOLD}%d${RESET} arquivos\n" "$cat:" "$count"
    done
fi
echo ""