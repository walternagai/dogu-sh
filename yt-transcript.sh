#!/bin/bash
# yt-transcript.sh — Baixa transcricoes de videos do YouTube (EN e PT-BR)
# Uso: ./yt-transcript.sh [opcoes] URL
# Opcoes:
#   -l, --lang LANG       Idioma: en, pt, both (padrao: both)
#   -o, --output DIR      Diretorio de saida (padrao: diretorio atual)
#   -f, --format FMT      Formato: txt, srt, vtt (padrao: txt)
#   --no-auto             Nao incluir legendas automaticas (padrao: incluir)
#   --dry-run             Mostra o que seria feito sem executar
#   --help|-h             Mostra esta ajuda
#   --version|-V          Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
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

LANG_CHOICE="both"
OUTPUT_DIR="."
SUB_FORMAT="txt"
USE_AUTO=true
DRY_RUN=false
VIDEO_URL=""

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

strip_vtt() {
    local input_file="$1"
    local output_file="$2"
    local prev_line=""
    while IFS= read -r line; do
        [[ "$line" =~ ^WEBVTT ]] && continue
        [[ "$line" =~ ^Kind: ]] && continue
        [[ "$line" =~ ^Language: ]] && continue
        [[ "$line" =~ ^[0-9]{2}:[0-9]{2} ]] && continue
        [[ "$line" =~ ^[0-9]+:[0-9]{2} ]] && continue
        [[ "$line" =~ ^NOTE ]] && continue
        [[ "$line" =~ ^Style: ]] && continue
        [[ "$line" =~ ^::cue ]] && continue
        [[ "$line" =~ ^\} ]] && continue
        [[ -z "$line" ]] && { [[ -n "$prev_line" ]] && echo "" >> "$output_file"; prev_line=""; continue; }
        local clean_line
        clean_line=$(echo "$line" | sed 's/<[^>]*>//g')
        if [[ "$clean_line" != "$prev_line" ]]; then
            echo "$clean_line" >> "$output_file"
            prev_line="$clean_line"
        fi
    done < "$input_file"
}

strip_srt() {
    local input_file="$1"
    local output_file="$2"
    local prev_line=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[0-9]+$ ]] && continue
        [[ "$line" =~ ^[0-9]{2}:[0-9]{2} ]] && continue
        [[ -z "$line" ]] && { [[ -n "$prev_line" ]] && echo "" >> "$output_file"; prev_line=""; continue; }
        local clean_line
        clean_line=$(echo "$line" | sed 's/<[^>]*>//g')
        if [[ "$clean_line" != "$prev_line" ]]; then
            echo "$clean_line" >> "$output_file"
            prev_line="$clean_line"
        fi
    done < "$input_file"
}

download_transcript() {
    local url="$1"
    local lang_code="$2"
    local lang_label="$3"

    local video_title
    video_title=$(yt-dlp --print title "$url" 2>/dev/null) || {
        error "Nao foi possivel obter o titulo do video"
    }

    local safe_title
    safe_title=$(echo "$video_title" | sed 's/[^a-zA-Z0-9._-]/_/g' | head -c 80)
    local output_file="${OUTPUT_DIR}/${safe_title}.${lang_code}"

    log "  ▶ Baixando transcricao: ${BOLD}${lang_label}${RESET} (${lang_code})"

    local ytdlp_args=()
    ytdlp_args+=(--skip-download)
    ytdlp_args+=(--sub-lang "$lang_code")
    ytdlp_args+=(--sub-format "srt/vtt/best")
    ytdlp_args+=(--output "${TMPDIR_WORK}/${safe_title}.%(ext)s")

    if [[ "$USE_AUTO" == true ]]; then
        ytdlp_args+=(--write-sub --write-auto-sub)
    else
        ytdlp_args+=(--write-sub)
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "  [Dry-run] yt-dlp ${ytdlp_args[*]} $url"
        return 0
    fi

    local ytdlp_output
    ytdlp_output=$(yt-dlp "${ytdlp_args[@]}" "$url" 2>&1) || true

    local sub_file=""
    for ext in srt vtt; do
        if [[ -f "${TMPDIR_WORK}/${safe_title}.${lang_code}.${ext}" ]]; then
            sub_file="${TMPDIR_WORK}/${safe_title}.${lang_code}.${ext}"
            break
        fi
    done

    if [[ -z "$sub_file" ]]; then
        warn "  ✗ Transcricao nao disponivel em ${lang_label} (${lang_code})"
        return 1
    fi

    case "$SUB_FORMAT" in
        txt)
            output_file="${output_file}.txt"
            if [[ "$sub_file" == *.vtt ]]; then
                strip_vtt "$sub_file" "$output_file"
            else
                strip_srt "$sub_file" "$output_file"
            fi
            ;;
        srt)
            output_file="${output_file}.srt"
            cp "$sub_file" "$output_file"
            ;;
        vtt)
            output_file="${output_file}.vtt"
            cp "$sub_file" "$output_file"
            ;;
    esac

    success "  ✓ Salvo: ${CYAN}${output_file}${RESET}"
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -l|--lang)
            [[ -z "${2-}" ]] && error "Flag --lang requer um valor (en, pt, both)"
            LANG_CHOICE="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && error "Flag --output requer um valor"
            OUTPUT_DIR="$2"; shift 2 ;;
        -f|--format)
            [[ -z "${2-}" ]] && error "Flag --format requer um valor (txt, srt, vtt)"
            SUB_FORMAT="$2"; shift 2 ;;
        --auto) USE_AUTO=true; shift ;;
        --no-auto) USE_AUTO=false; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  yt-transcript.sh — Baixa transcricoes de videos do YouTube"
            echo ""
            echo "  Uso: ./yt-transcript.sh [opcoes] URL"
            echo ""
            echo "  Opcoes:"
            echo "    -l, --lang LANG     Idioma: en, pt, both (padrao: both)"
            echo "    -o, --output DIR    Diretorio de saida (padrao: .)"
            echo "    -f, --format FMT    Formato: txt, srt, vtt (padrao: txt)"
            echo "    --no-auto           Nao incluir legendas automaticas"
            echo "    --dry-run           Mostra o que seria feito sem executar"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./yt-transcript.sh https://youtube.com/watch?v=xxxxx"
            echo "    ./yt-transcript.sh --lang en --auto https://youtube.com/watch?v=xxxxx"
            echo "    ./yt-transcript.sh --lang pt -o ~/transcricoes URL"
            echo "    ./yt-transcript.sh --format srt --auto URL"
            echo ""
            exit 0
            ;;
        --version|-V) echo "yt-transcript.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            VIDEO_URL="$1"; shift ;;
    esac
done

if [[ -z "$VIDEO_URL" ]]; then
    echo ""
    echo -e "  ${BOLD}YouTube Transcript${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
    echo ""
    printf "  URL do video: "
    read -r VIDEO_URL < /dev/tty
fi

if [[ -z "$VIDEO_URL" ]]; then
    error "URL do video nao fornecida"
fi

if [[ ! "$LANG_CHOICE" =~ ^(en|pt|both)$ ]]; then
    error "Idioma invalido: $LANG_CHOICE (use en, pt ou both)"
fi

if [[ ! "$SUB_FORMAT" =~ ^(txt|srt|vtt)$ ]]; then
    error "Formato invalido: $SUB_FORMAT (use txt, srt ou vtt)"
fi

ensure_yt_dlp() {
    if command -v yt-dlp &>/dev/null; then
        return 0
    fi

    warn "yt-dlp nao encontrado."
    echo ""
    echo -e "  ${BOLD}yt-dlp${RESET} nao esta instalado. Escolha o metodo de instalacao:"
    echo ""
    echo -e "  ${CYAN}1${RESET}) pip install yt-dlp ${DIM}(recomendado)${RESET}"
    echo -e "  ${CYAN}2${RESET}) pipx install yt-dlp"
    echo -e "  ${CYAN}3${RESET}) Baixar binario do GitHub"
    echo -e "  ${CYAN}0${RESET}) Cancelar"
    echo ""
    if [ -t 0 ]; then
        read -r -p "  Escolha [0-3]: " method < /dev/tty
    else
        error "Execucao nao interativa detectada. Rode em terminal interativo (TTY) para confirmar."
    fi

    case "$method" in
        1)
            log "Instalando via pip..."
            if command -v pip3 &>/dev/null; then
                pip3 install --user yt-dlp || error "Falha ao instalar yt-dlp via pip"
            elif command -v pip &>/dev/null; then
                pip install --user yt-dlp || error "Falha ao instalar yt-dlp via pip"
            else
                error "pip nao encontrado. Instale python3-pip primeiro."
            fi
            export PATH="$HOME/.local/bin:$PATH"
            ;;
        2)
            if ! command -v pipx &>/dev/null; then
                error "pipx nao encontrado. Instale com: sudo apt install pipx"
            fi
            log "Instalando via pipx..."
            pipx install yt-dlp || error "Falha ao instalar yt-dlp via pipx"
            ;;
        3)
            log "Baixando binario do GitHub..."
            local bin_dir="$HOME/.local/bin"
            mkdir -p "$bin_dir"
            if command -v curl &>/dev/null; then
                curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o "$bin_dir/yt-dlp" \
                    || error "Falha ao baixar yt-dlp"
            elif command -v wget &>/dev/null; then
                wget -O "$bin_dir/yt-dlp" https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
                    || error "Falha ao baixar yt-dlp"
            else
                error "curl ou wget necessario para download"
            fi
            chmod +x "$bin_dir/yt-dlp"
            export PATH="$bin_dir:$PATH"
            ;;
        *)
            error "Instalacao cancelada"
            ;;
    esac

    if ! command -v yt-dlp &>/dev/null; then
        error "yt-dlp nao foi instalado corretamente"
    fi
    success "yt-dlp instalado com sucesso"
}

ensure_yt_dlp

if [[ "$OUTPUT_DIR" != "." ]] && [[ ! -d "$OUTPUT_DIR" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "  [Dry-run] mkdir -p $OUTPUT_DIR"
    else
        mkdir -p "$OUTPUT_DIR"
    fi
fi

echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}YouTube Transcript${RESET}"
echo -e "  ${DIM}URL: ${VIDEO_URL}${RESET}"
echo -e "  ${DIM}Idioma: ${LANG_CHOICE} | Formato: ${SUB_FORMAT} | Auto: ${USE_AUTO}${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

DOWNLOADED=0
FAILED=0

case "$LANG_CHOICE" in
    en)
        download_transcript "$VIDEO_URL" "en" "Ingles" && DOWNLOADED=$((DOWNLOADED + 1)) || FAILED=$((FAILED + 1))
        ;;
    pt)
        download_transcript "$VIDEO_URL" "pt" "Portugues" && DOWNLOADED=$((DOWNLOADED + 1)) || FAILED=$((FAILED + 1))
        ;;
    both)
        download_transcript "$VIDEO_URL" "en" "Ingles" && DOWNLOADED=$((DOWNLOADED + 1)) || FAILED=$((FAILED + 1))
        download_transcript "$VIDEO_URL" "pt" "Portugues" && DOWNLOADED=$((DOWNLOADED + 1)) || FAILED=$((FAILED + 1))
        ;;
esac

echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
if [[ $FAILED -eq 0 ]]; then
    success "✓ $DOWNLOADED transcricao(oes) baixada(s) com sucesso"
else
    warn "✗ $DOWNLOADED baixada(s), $FAILED falha(s)"
    exit 1
fi
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
