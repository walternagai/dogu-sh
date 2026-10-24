#!/bin/bash
# video-to-text.sh — Extrai audio de um video e transcreve com Whisper
# Uso: ./video-to-text.sh [opcoes] VIDEO.mp4
# Opcoes:
#   -o, --output FILE     Arquivo de saida (padrao: nome do video + .txt)
#   -f, --format FMT      txt, srt ou vtt (padrao: txt)
#   -l, --language LANG   auto, en ou pt (padrao: auto)
#       --keep-audio      Mantem o audio extraido
#       --dry-run         Mostra os comandos sem executar
#       --json            Saida em formato JSON
#   -h, --help            Mostra esta ajuda
#   -V, --version         Mostra versao
#
# Pipeline: video-to-audio.sh (wav temporario) -> audio-to-text.sh.

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
OUTPUT=""
FORMAT="txt"
LANGUAGE="auto"
MODEL="base"
KEEP_AUDIO=false
DRY_RUN=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 2; }
            OUTPUT="$2"; shift 2 ;;
        -f|--format)
            [[ -z "${2-}" ]] && { echo "Flag --format requer um valor" >&2; exit 2; }
            FORMAT="$2"; shift 2 ;;
        -l|--language)
            [[ -z "${2-}" ]] && { echo "Flag --language requer um valor" >&2; exit 2; }
            LANGUAGE="$2"; shift 2 ;;
        -m|--model)
            [[ -z "${2-}" ]] && { echo "Flag --model requer um valor" >&2; exit 2; }
            MODEL="$2"; shift 2 ;;
        --keep-audio) KEEP_AUDIO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  video-to-text.sh — Extrai audio e transcreve com Whisper"
            echo ""
            echo "  Uso: ./video-to-text.sh [opcoes] VIDEO.mp4"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output FILE     Arquivo de saida (padrao: video + .txt)"
            echo "    -f, --format FMT      txt, srt ou vtt (padrao: txt)"
            echo "    -l, --language LANG   auto, en ou pt (padrao: auto)"
            echo "    -m, --model MODEL     tiny, base, small, medium, large (padrao: base)"
            echo "        --keep-audio      Mantem o audio extraido"
            echo "        --dry-run         Mostra os comandos sem executar"
            echo "        --json            Saida em formato JSON"
            echo "    -h, --help            Mostra esta ajuda"
            echo "    -V, --version         Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./video-to-text.sh aula.mp4"
            echo "    ./video-to-text.sh -f srt -l pt entrevista.mkv"
            echo "    ./video-to-text.sh --keep-audio --json palestra.webm"
            echo ""
            exit 0
            ;;
        -V|--version) echo "video-to-text.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            [[ -z "$INPUT" ]] && INPUT="$1" || error "Argumento inesperado: $1"
            shift ;;
    esac
done

[[ -n "$INPUT" ]] || error "Informe um arquivo de video."
[[ -f "$INPUT" ]] || error "Arquivo nao encontrado: $INPUT"
case "$FORMAT" in txt|srt|vtt) ;; *) error "Formato invalido: $FORMAT (use txt, srt ou vtt)" ;; esac
case "$LANGUAGE" in auto|en|pt) ;; *) error "Idioma invalido: $LANGUAGE (use auto, en ou pt)" ;; esac
case "$MODEL" in tiny|base|small|medium|large) ;; *) error "Modelo invalido: $MODEL (use tiny, base, small, medium ou large)" ;; esac

VIDEO_TO_AUDIO="$SCRIPT_DIR/video-to-audio.sh"
AUDIO_TO_TEXT="$SCRIPT_DIR/audio-to-text.sh"
[ -x "$VIDEO_TO_AUDIO" ] || VIDEO_TO_AUDIO="$HOME/.local/bin/video-to-audio.sh"
[ -x "$AUDIO_TO_TEXT" ] || AUDIO_TO_TEXT="$HOME/.local/bin/audio-to-text.sh"
[ -x "$VIDEO_TO_AUDIO" ] || error "video-to-audio.sh nao encontrado."
[ -x "$AUDIO_TO_TEXT" ] || error "audio-to-text.sh nao encontrado."

BASE=$(basename "$INPUT")
BASE="${BASE%.*}"
INPUT_DIR=$(cd "$(dirname "$INPUT")" && pwd)
OUTPUT="${OUTPUT:-${INPUT_DIR}/${BASE}.${FORMAT}}"

TMPDIR_WORK=$(mktemp -d)
AUDIO="${TMPDIR_WORK}/${BASE}.wav"
if ! $KEEP_AUDIO; then
    trap 'rm -rf "$TMPDIR_WORK"' EXIT
fi

if $DRY_RUN; then
    echo "$VIDEO_TO_AUDIO -f wav -o \"$AUDIO\" \"$INPUT\""
    echo "$AUDIO_TO_TEXT -f $FORMAT -l $LANGUAGE -m $MODEL -o \"$OUTPUT\" \"$AUDIO\""
    exit 0
fi

$JSON_MODE || log "Extraindo audio de $INPUT"
"$VIDEO_TO_AUDIO" -f wav -o "$AUDIO" "$INPUT" >/dev/null

$JSON_MODE || log "Transcrevendo audio (formato $FORMAT, idioma $LANGUAGE)"
"$AUDIO_TO_TEXT" -f "$FORMAT" -l "$LANGUAGE" -m "$MODEL" -o "$OUTPUT" "$AUDIO" >/dev/null

if $KEEP_AUDIO; then
    $JSON_MODE || log "Audio mantido em: $AUDIO"
else
    rm -rf "$TMPDIR_WORK"
fi

if $JSON_MODE; then
    if $KEEP_AUDIO; then
        audio_json=$(printf '"%s"' "$(json_escape "$AUDIO")")
    else
        audio_json=null
    fi
    printf '{"input":"%s","audio":%s,"output":"%s","format":"%s","language":"%s","model":"%s","keep_audio":%s}\n' \
        "$(json_escape "$INPUT")" "$audio_json" "$(json_escape "$OUTPUT")" \
        "$FORMAT" "$LANGUAGE" "$MODEL" "$KEEP_AUDIO"
else
    success "Transcricao salva em: $OUTPUT"
fi
