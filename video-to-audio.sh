#!/bin/bash
# video-to-audio.sh — Extrai a trilha de audio de arquivos de video (Linux)
# Uso: ./video-to-audio.sh [opcoes] ARQUIVO.mp4
# Opcoes:
#   -o, --output FILE       Arquivo de saida (padrao: nome do video + extensao do formato)
#   -f, --format EXT        Formato de audio: mp3, m4a, ogg, wav, flac, opus (padrao: mp3)
#       --copy              Copia o stream de audio sem re-encodar (mais rapido)
#       --dry-run           Simula a extracao sem gerar arquivos
#   -h, --help              Mostra esta ajuda
#   -V, --version           Mostra versao

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
    check_and_install "ffmpeg" "$INSTALLER" "ffmpeg"
fi

INPUT_FILE=""
OUTPUT_FILE=""
FORMAT="mp3"
COPY_STREAM=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --output requer um valor${RESET}" >&2; exit 2; }
            OUTPUT_FILE="$2"; shift 2 ;;
        -f|--format)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --format requer um valor${RESET}" >&2; exit 2; }
            FORMAT="$2"; shift 2 ;;
        --copy) COPY_STREAM=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  video-to-audio.sh — Extrai a trilha de audio de arquivos de video"
            echo ""
            echo "  Uso: ./video-to-audio.sh [opcoes] ARQUIVO.mp4"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output FILE    Arquivo de saida (padrao: nome do video + extensao do formato)"
            echo "    -f, --format EXT     Formato de audio: mp3, m4a, ogg, wav, flac, opus (padrao: mp3)"
            echo "        --copy           Copia o stream de audio sem re-encodar (mais rapido)"
            echo "        --dry-run        Simula a extracao sem gerar arquivos"
            echo "    -h, --help           Mostra esta ajuda"
            echo "    -V, --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./video-to-audio.sh video.mp4"
            echo "    ./video-to-audio.sh -f m4a video.mp4"
            echo "    ./video-to-audio.sh -o ./musicas/trilha.mp3 video.mp4"
            echo "    ./video-to-audio.sh --copy -o video.m4a video.mkv"
            echo ""
            exit 0
            ;;
        --version|-V) echo "video-to-audio.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            else
                error "Argumentos demais. Informe apenas um arquivo de video."
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    error "Arquivo de video nao informado. Uso: ./video-to-audio.sh ARQUIVO.mp4"
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    error "Arquivo nao encontrado: $INPUT_FILE"
fi

if $COPY_STREAM; then
    AUDIO_OPTS="-c:a copy"
    warn "Modo --copy: o container de saida precisa suportar o codec do video original."
else
    case "$FORMAT" in
        mp3)  AUDIO_OPTS="-c:a libmp3lame -q:a 2" ;;
        m4a)  AUDIO_OPTS="-c:a aac -b:a 192k" ;;
        ogg)  AUDIO_OPTS="-c:a libvorbis -q:a 6" ;;
        wav)  AUDIO_OPTS="-c:a pcm_s16le" ;;
        flac) AUDIO_OPTS="-c:a flac" ;;
        opus) AUDIO_OPTS="-c:a libopus -b:a 128k" ;;
        *)    error "Formato invalido: $FORMAT. Use mp3, m4a, ogg, wav, flac ou opus." ;;
    esac
fi

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${INPUT_FILE%.*}.${FORMAT}"
fi

echo ""
echo -e "  ${BOLD}VIDEO → AUDIO${RESET}  ${DIM}v${VERSION}${RESET}"
echo ""
echo -e "  ${DIM}Arquivo:  ${RESET}${INPUT_FILE}"
echo -e "  ${DIM}Formato:  ${RESET}${FORMAT}"
echo -e "  ${DIM}Saida:    ${RESET}${OUTPUT_FILE}"
echo -e "  ${DIM}Modo:     ${RESET}${AUDIO_OPTS}"
echo ""

if [[ -f "$OUTPUT_FILE" ]]; then
    if $DRY_RUN; then
        echo -e "  ${DIM}[Dry-run] Arquivo de saida ja existe; seria solicitada confirmacao${RESET}"
    else
        read -r -p "Arquivo de saida ja existe. Sobrescrever? [s/N] " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
            echo -e "${DIM}Operacao cancelada.${RESET}"
            exit 0
        fi
    fi
fi

if $DRY_RUN; then
    echo -e "  ${DIM}[Dry-run] ffmpeg -i \"${INPUT_FILE}\" -vn ${AUDIO_OPTS} -y \"${OUTPUT_FILE}\"${RESET}"
    echo ""
    exit 0
fi

log "Extraindo audio..."
if ! ffmpeg -hide_banner -loglevel error -i "$INPUT_FILE" -vn $AUDIO_OPTS -y "$OUTPUT_FILE"; then
    error "Falha ao extrair audio. Verifique se o arquivo e um video valido."
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
    error "Nenhum arquivo de audio foi gerado. Verifique o video."
fi

size=$(du -h "$OUTPUT_FILE" 2>/dev/null | cut -f1)
echo ""
echo -e "  ${GREEN}✓${RESET} ${CYAN}${OUTPUT_FILE}${RESET}  ${DIM}(${size})${RESET}"
echo ""
success "Audio extraido com sucesso."
echo ""
