#!/bin/bash
# video-catalog-organizer.sh — Organiza catalogo de videos por estrategia (Linux)
# Uso: ./video-catalog-organizer.sh --by <modo> [opcoes] <pasta>
# Opcoes:
#   --by MODE        Estrategia: content | year | quality (obrigatorio)
#   --apply          Efetiva os mv (sem esta flag = dry-run, so lista)
#   --probe-quality  Em --by quality, usa ffprobe para resolucao real (opt-in)
#   --recursive|-r   Processa subpastas tambem
#   --help|-h        Mostra esta ajuda
#   --version|-V     Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"

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

# Variaveis de modo
BY_MODE=""
APPLY=false
PROBE_QUALITY=false
RECURSIVE=false
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --by)
            [[ -z "${2-}" ]] && error "Flag --by requer um valor (content | year | quality)"
            BY_MODE="$2"; shift 2 ;;
        --apply)
            APPLY=true; shift ;;
        --probe-quality)
            PROBE_QUALITY=true; shift ;;
        --recursive|-r)
            RECURSIVE=true; shift ;;
        --help|-h)
            echo ""
            echo "  video-catalog-organizer.sh — Organiza catalogo de videos"
            echo ""
            echo "  Uso: ./video-catalog-organizer.sh --by <modo> [opcoes] <pasta>"
            echo ""
            echo "  Estrategias (uma por execucao):"
            echo "    content   Classifica em filmes/, series/, cursos/, clipes/, outros/"
            echo "    year      Cria pastas YYYY/ (ano do nome ou mtime como fallback)"
            echo "    quality   Cria pastas 2160p|4k 1080p|fhd 720p|hd 480p|sd unknown/"
            echo ""
            echo "  Argumentos:"
            echo "    pasta           Diretorio a organizar (padrao: .)"
            echo ""
            echo "  Opcoes:"
            echo "    --apply         Efetiva os mv (sem esta flag = dry-run, so lista)"
            echo "    --probe-quality Em --by quality, usa ffprobe para resolucao real"
            echo "    --recursive|-r  Processa subpastas tambem"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./video-catalog-organizer.sh --by content ~/Videos"
            echo "    ./video-catalog-organizer.sh --by quality --probe-quality ~/Videos"
            echo "    ./video-catalog-organizer.sh --by year --apply --recursive ~/Videos"
            echo ""
            exit 0
            ;;
        --version|-V) echo "video-catalog-organizer.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

[[ -z "$BY_MODE" ]] && error "Flag --by e obrigatoria (content | year | quality)"

case "$BY_MODE" in
    content|year|quality) ;;
    *) error "--by invalido: '$BY_MODE'. Use: content | year | quality" ;;
esac

# ffprobe so e necessario se --probe-quality + --by quality
if [[ "$BY_MODE" == "quality" ]] && $PROBE_QUALITY; then
    if [ -f "$DEP_HELPER" ]; then
        source "$DEP_HELPER"
        INSTALLER=$(detect_installer)
        check_and_install "ffprobe" "$INSTALLER" "ffmpeg"
    elif ! command -v ffprobe &>/dev/null; then
        error "--probe-quality exige ffprobe (instale ffmpeg) ou dependency-helper.sh"
    fi
fi

TARGET="${POSITIONAL_ARGS[0]:-.}"
TARGET="${TARGET%/}"

[[ -d "$TARGET" ]] || error "'$TARGET' nao e um diretorio valido."

# Lista canonica de extensoes de video (copiada de organize-downloads.sh)
is_video_file() {
    local filename="$1"
    local ext="${filename##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        mp4|mov|avi|mkv|wmv|flv|webm|m4v|mpg|mpeg|ts|3gp|3g2|vob|ogv|m2ts|mts|rm|rmvb|asf|divx|f4v)
            return 0 ;;
        *) return 1 ;;
    esac
}

# --- Detectores de --by ---

# --by content: regex no nome (e duracao via ffprobe para clipes se disponivel)
detect_content() {
    local stem="$1"
    local file="$2"
    # Padroes de serie: S01E01, S1E1, 1x01, - s01e01 -
    if echo "$stem" | grep -qiE '(^|[._ -])s[0-9]{1,2}e[0-9]{1,2}([._ -]|$)|[._ -][0-9]{1,2}x[0-9]{1,2}([._ -]|$)'; then
        echo "series"
        return
    fi
    # Padroes de curso: aula, lesson, modulo, curso, class, module, ep (episodio isolado)
    if echo "$stem" | grep -qiE 'aula|lesson|modulo|module|curso|class|tutorial'; then
        echo "cursos"
        return
    fi
    # Padrao de clipe: duracao < 60s via ffprobe se disponivel
    if command -v ffprobe &>/dev/null; then
        local dur
        dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        if [[ -n "$dur" ]] && awk -v d="$dur" 'BEGIN{exit !(d>0 && d<60)}'; then
            echo "clipes"
            return
        fi
    fi
    # Padrao de filme: nome com ano no formato YYYY (de 1900 ate ano atual+1)
    local current_year
    current_year=$(date +%Y)
    if echo "$stem" | grep -qE "(19[0-9]{2}|20[0-9]{2}|${current_year})"; then
        echo "filmes"
        return
    fi
    echo "outros"
}

# --by year: regex no nome primeiro; mtime como fallback
detect_year() {
    local stem="$1"
    local file="$2"
    local year
    # Ano de 4 digitos entre 1900 e ano atual+1
    year=$(echo "$stem" | grep -oE '(19[0-9]{2}|20[0-9]{2})' | head -1 || true)
    if [[ -n "$year" ]]; then
        echo "$year"
        return
    fi
    # Fallback: mtime
    if [[ -f "$file" ]]; then
        stat -c '%y' "$file" 2>/dev/null | cut -c1-4 || date -r "$file" +%Y 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# --by quality: tokens no nome; ffprobe opt-in se --probe-quality
detect_quality() {
    local stem="$1"
    local file="$2"
    local lower
    lower=$(echo "$stem" | tr '[:upper:]' '[:lower:]')

    # Tokens mais especificos primeiro
    case "$lower" in
        *2160p*|*4k*|*uhd*) echo "2160p"; return ;;
        *1080p*|*fullhd*|*fhd*) echo "1080p"; return ;;
        *720p*|*hd*) echo "720p"; return ;;
        *480p*|*sd*) echo "480p"; return ;;
    esac

    # Sem token no nome: tenta ffprobe se --probe-quality
    if $PROBE_QUALITY && command -v ffprobe &>/dev/null && [[ -f "$file" ]]; then
        local height
        height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null || echo "")
        case "$height" in
            21[6-9][0-9]|2[2-9][0-9][0-9]|[3-9][0-9][0-9][0-9]) echo "2160p"; return ;;
            1080|108[1-9]|10[8-9][0-9]) echo "1080p"; return ;;
            72[0-9]|7[0-9][0-9]) echo "720p"; return ;;
            48[0-9]|4[0-7][0-9]) echo "480p"; return ;;
            *) echo "unknown"; return ;;
        esac
    fi

    echo "unknown"
}

# Resolve a pasta-destino segundo o modo
resolve_destination() {
    local file="$1"
    local filename
    filename=$(basename "$file")
    local stem="${filename%.*}"

    case "$BY_MODE" in
        content) detect_content "$stem" "$file" ;;
        year)    detect_year    "$stem" "$file" ;;
        quality) detect_quality "$stem" "$file" ;;
    esac
}

# --- Loop principal ---

COUNT_FILE=$(mktemp)
trap 'rm -f "$COUNT_FILE"' EXIT

echo ""
if ! $APPLY; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Nada sera movido. Use --apply para efetivar."
fi
echo -e "  Estrategia: ${BOLD}--by $BY_MODE${RESET}"
echo -e "  Diretorio:  ${BOLD}$TARGET${RESET}"
if $RECURSIVE; then
    echo -e "  Modo:       recursivo"
else
    echo -e "  Modo:       apenas raiz"
fi
echo ""

printf "  Continuar? [s/N]: "
# Em execucao nao-interativa (pipe, CI, cron), aborta com erro claro em vez
# de cair no fallback silencioso "n" (que mascara --apply).
if [ -t 0 ]; then
    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
else
    error "Execucao nao interativa detectada. Rode em um terminal interativo (TTY) para confirmar."
fi
case "$confirm" in
    [sS]) ;;
    *) echo -e "  ${DIM}Operacao cancelada.${RESET}"; exit 0 ;;
esac

PROCESSED=0

process_file() {
    local file="$1"
    local target_dir="$2"

    [[ -f "$file" ]] || return

    local filename
    filename=$(basename "$file")

    # Ignora dotfiles
    case "$filename" in
        .*) return ;;
    esac

    # Filtra por extensao de video
    is_video_file "$filename" || return

    local dest_folder
    dest_folder=$(resolve_destination "$file")

    local dest="$target_dir/$dest_folder"
    local dest_file="$dest/$filename"

    # Colisao de nomes
    if [[ -e "$dest_file" ]]; then
        local base="${filename%.*}"
        local suffix="${filename##*.}"
        local n=1
        if [[ "$filename" = "$suffix" ]]; then
            while [[ -e "$dest/$filename ($n)" ]]; do
                n=$((n + 1))
            done
            dest_file="$dest/$filename ($n)"
        else
            while [[ -e "$dest/$base ($n).$suffix" ]]; do
                n=$((n + 1))
            done
            dest_file="$dest/$base ($n).$suffix"
        fi
    fi

    if $APPLY; then
        mkdir -p "$dest"
        mv "$file" "$dest_file"
        echo -e "  ${DIM}→${RESET} $filename ${DIM}→${RESET} ${CYAN}$dest_folder/${RESET}"
    else
        echo -e "  ${DIM}[dry-run]${RESET} $filename ${DIM}→${RESET} ${CYAN}$dest_folder/${RESET}"
    fi

    echo "$dest_folder" >> "$COUNT_FILE"
    PROCESSED=$((PROCESSED + 1))
}

# Diretorios de destino que ja existem: nao re-processar
is_already_organized() {
    local dir="$1"
    case "$(basename "$dir")" in
        filmes|series|cursos|clipes|outros|unknown|2160p|1080p|720p|480p) return 0 ;;
        19[0-9][0-9]|20[0-9][0-9]) return 0 ;;
    esac
    return 1
}

if $RECURSIVE; then
    while IFS= read -r -d '' file; do
        local_dir=$(dirname "$file")
        is_already_organized "$local_dir" && continue
        process_file "$file" "$local_dir"
    done < <(find "$TARGET" -mindepth 1 -type f -not -path '*/\.*' -print0 2>/dev/null)
else
    for file in "$TARGET"/*; do
        process_file "$file" "$TARGET"
    done
fi

echo ""

if [[ $PROCESSED -eq 0 ]]; then
    echo -e "  ${DIM}Nenhum arquivo de video encontrado.${RESET}"
else
    if $APPLY; then
        echo -e "  ${GREEN}✓ $PROCESSED arquivos organizados:${RESET}"
    else
        echo -e "  ${YELLOW}$PROCESSED arquivos seriam organizados:${RESET}"
    fi
    echo ""
    sort "$COUNT_FILE" | uniq -c | sort -rn | while read -r count cat; do
        printf "  %-16s ${BOLD}%d${RESET} arquivos\n" "$cat:" "$count"
    done
fi
echo ""
