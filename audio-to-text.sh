#!/bin/bash
# audio-to-text.sh — Transcreve arquivos de audio locais via Whisper (Linux)
# Uso: ./audio-to-text.sh [opcoes] ARQUIVO.mp3
# Opcoes:
#   -m, --model MODEL       Modelo Whisper: tiny, base, small, medium, large (padrao: base)
#   -l, --language LANG     Idioma: auto, en, pt (padrao: auto)
#   -o, --output ARQ        Arquivo de saida (padrao: nome base + extensao do formato)
#   -f, --format FMT        Formato: txt, srt, vtt (padrao: txt)
#       --backend BACKEND   Backend: auto, faster-whisper, openai-whisper (padrao: auto)
#       --verbose           Mostra segmentos e progresso da transcricao
#       --dry-run           Simula a transcricao sem executar
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

MODEL="base"
LANG="auto"
OUTPUT_FILE=""
FORMAT="txt"
BACKEND="auto"
VERBOSE=false
DRY_RUN=false
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--model)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --model requer um valor${RESET}" >&2; exit 2; }
            MODEL="$2"; shift 2 ;;
        -l|--language)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --language requer um valor${RESET}" >&2; exit 2; }
            LANG="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --output requer um valor${RESET}" >&2; exit 2; }
            OUTPUT_FILE="$2"; shift 2 ;;
        -f|--format)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --format requer um valor${RESET}" >&2; exit 2; }
            FORMAT="$2"; shift 2 ;;
        --backend)
            [[ -z "${2-}" ]] && { echo -e "${RED}Flag --backend requer um valor${RESET}" >&2; exit 2; }
            BACKEND="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  audio-to-text.sh — Transcreve arquivos de audio locais via Whisper"
            echo ""
            echo "  Uso: ./audio-to-text.sh [opcoes] ARQUIVO.mp3"
            echo ""
            echo "  Opcoes:"
            echo "    -m, --model MODEL     Modelo Whisper: tiny, base, small, medium, large (padrao: base)"
            echo "    -l, --language LANG   Idioma: auto, en, pt (padrao: auto)"
            echo "    -o, --output ARQ      Arquivo de saida (padrao: nome base + extensao do formato)"
            echo "    -f, --format FMT      Formato: txt, srt, vtt (padrao: txt)"
            echo "        --backend BACKEND Backend: auto, faster-whisper, openai-whisper (padrao: auto)"
            echo "        --verbose         Mostra segmentos e progresso da transcricao"
            echo "        --dry-run         Simula a transcricao sem executar"
            echo "    -h, --help            Mostra esta ajuda"
            echo "    -V, --version         Mostra versao"
            echo ""
            echo "  Backend (auto):"
            echo "    GPU NVIDIA detectada -> faster-whisper em CUDA (CTranslate2, mais rapido)"
            echo "    Sem GPU NVIDIA       -> faster-whisper em CPU (int8)"
            echo "    Use --backend openai-whisper para o CLI oficial (pip install openai-whisper)"
            echo ""
            echo "  Exemplos:"
            echo "    ./audio-to-text.sh gravacao.mp3"
            echo "    ./audio-to-text.sh -l pt -m small entrevista.wav"
            echo "    ./audio-to-text.sh -f srt -o legendas.srt podcast.m4a"
            echo "    ./audio-to-text.sh --backend openai-whisper -l en audio.flac"
            echo ""
            exit 0
            ;;
        --version|-V) echo "audio-to-text.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            else
                error "Argumentos demais. Informe apenas um arquivo de audio."
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT_FILE" ]]; then
    error "Arquivo de audio nao informado. Uso: ./audio-to-text.sh ARQUIVO.mp3"
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    error "Arquivo nao encontrado: $INPUT_FILE"
fi

case "$MODEL" in
    tiny|base|small|medium|large) ;;
    *) error "Modelo invalido: $MODEL. Use tiny, base, small, medium ou large." ;;
esac

case "$LANG" in
    auto|en|pt) ;;
    *) error "Idioma invalido: $LANG. Use auto, en ou pt." ;;
esac

case "$FORMAT" in
    txt|srt|vtt) ;;
    *) error "Formato invalido: $FORMAT. Use txt, srt ou vtt." ;;
esac

# Deteccao de hardware: GPU NVIDIA (CUDA) ou CPU
detect_device() {
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        echo "cuda"
    else
        echo "cpu"
    fi
}

if [[ "$BACKEND" == "auto" ]]; then
    BACKEND="faster-whisper"
fi
case "$BACKEND" in
    faster-whisper|openai-whisper) ;;
    *) error "Backend invalido: $BACKEND. Use auto, faster-whisper ou openai-whisper." ;;
esac

DEVICE=$(detect_device)

if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${INPUT_FILE%.*}.${FORMAT}"
else
    output_ext="${OUTPUT_FILE##*.}"
    if [[ "$output_ext" != "$FORMAT" && "$output_ext" != */* ]]; then
        warn "Extensao do arquivo de saida (${output_ext}) difere do formato (${FORMAT}); o conteudo usara o formato ${FORMAT}."
    fi
fi

# Instala/valida dependencia Python do backend (pip)
require_python_pkg() {
    local import_name="$1"
    local pkg="$2"
    if ! python3 -c "import $import_name" >/dev/null 2>&1; then
        warn "Dependencia Python '$pkg' nao encontrada."
        read -r -p "Deseja instalar '$pkg' com pip agora? [s/N] " choice
        if [[ "$choice" =~ ^[Ss]$ ]]; then
            log "Instalando $pkg..."
            if ! python3 -m pip install "$pkg"; then
                error "Falha ao instalar $pkg. Instale manualmente com: python3 -m pip install $pkg"
            fi
        else
            echo -e "${RED}[ERROR] O backend requer '$pkg'. Instale com: python3 -m pip install $pkg${RESET}" >&2
            exit 127
        fi
    fi
}

echo ""
echo -e "  ${BOLD}AUDIO → TEXTO${RESET}  ${DIM}v${VERSION}${RESET}"
echo ""
echo -e "  ${DIM}Arquivo:  ${RESET}${INPUT_FILE}"
echo -e "  ${DIM}Modelo:   ${RESET}${MODEL}"
echo -e "  ${DIM}Idioma:   ${RESET}${LANG}"
echo -e "  ${DIM}Formato:  ${RESET}${FORMAT}"
echo -e "  ${DIM}Backend:  ${RESET}${BACKEND} (${DEVICE})"
echo -e "  ${DIM}Saida:    ${RESET}${OUTPUT_FILE}"
echo ""

if $DRY_RUN; then
    echo -e "  ${DIM}[Dry-run] Backend ${BACKEND} (${DEVICE}), modelo ${MODEL}, idioma ${LANG}${RESET}"
    echo -e "  ${DIM}[Dry-run] Na primeira execucao, o modelo ${MODEL} sera baixado (requer rede)${RESET}"
    echo -e "  ${DIM}[Dry-run] Transcricao seria salva em: ${OUTPUT_FILE}${RESET}"
    echo ""
    exit 0
fi

if [[ "$BACKEND" == "faster-whisper" ]]; then
    require_python_pkg "faster_whisper" "faster-whisper"

    log "Transcrevendo com faster-whisper (${DEVICE})..."
    if [[ "$DEVICE" == "cuda" ]]; then
        COMPUTE_TYPE="float16"
    else
        COMPUTE_TYPE="int8"
    fi

    if ! python3 - "$INPUT_FILE" "$MODEL" "$LANG" "$OUTPUT_FILE" "$FORMAT" "$DEVICE" "$COMPUTE_TYPE" "$VERBOSE" <<'PY'
import sys

from faster_whisper import WhisperModel

audio_path, model_name, lang, output_path, output_format, device, compute_type, verbose = sys.argv[1:9]

model = WhisperModel(model_name, device=device, compute_type=compute_type)
segments_iter, info = model.transcribe(
    audio_path,
    language=None if lang == "auto" else lang,
    vad_filter=True,
)
segments = list(segments_iter)

if verbose == "true":
    print(f"[INFO] Idioma detectado: {info.language} (prob {info.language_probability:.2f})")


def fmt_ts(ts):
    ms = int(ts * 1000)
    h, ms = divmod(ms, 3600000)
    m, ms = divmod(ms, 60000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


if output_format == "txt":
    text = "\n".join(seg.text.strip() for seg in segments)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(text + "\n")
elif output_format == "srt":
    with open(output_path, "w", encoding="utf-8") as f:
        for i, seg in enumerate(segments, 1):
            f.write(f"{i}\n")
            f.write(f"{fmt_ts(seg.start)} --> {fmt_ts(seg.end)}\n")
            f.write(seg.text.strip() + "\n\n")
elif output_format == "vtt":
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("WEBVTT\n\n")
        for seg in segments:
            f.write(f"{fmt_ts(seg.start).replace(',', '.')} --> {fmt_ts(seg.end).replace(',', '.')}\n")
            f.write(seg.text.strip() + "\n\n")

if verbose == "true":
    for seg in segments:
        print(f"[{fmt_ts(seg.start)}] {seg.text.strip()}")
PY
    then
        error "Falha ao transcrever. Verifique se o arquivo e um audio valido."
    fi
else
    require_python_pkg "whisper" "openai-whisper"

    TMPDIR_WORK=$(mktemp -d)
    trap 'rm -rf "$TMPDIR_WORK"' EXIT

    log "Transcrevendo com openai-whisper..."
    WHISPER_ARGS=(--model "$MODEL" --output_format "$FORMAT" --output_dir "$TMPDIR_WORK")
    if [[ "$LANG" != "auto" ]]; then
        WHISPER_ARGS+=(--language "$LANG")
    fi
    if $VERBOSE; then
        WHISPER_ARGS+=(--verbose True)
    else
        WHISPER_ARGS+=(--verbose False)
    fi

    if ! whisper "$INPUT_FILE" "${WHISPER_ARGS[@]}"; then
        error "Falha ao transcrever. Verifique se o arquivo e um audio valido."
    fi

    GENERATED="$TMPDIR_WORK/$(basename "${INPUT_FILE%.*}").${FORMAT}"
    if [[ ! -f "$GENERATED" ]]; then
        error "Backend openai-whisper nao gerou o arquivo esperado: $GENERATED"
    fi
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    mv "$GENERATED" "$OUTPUT_FILE"
fi

if [[ ! -f "$OUTPUT_FILE" ]]; then
    error "Nenhum arquivo de transcricao foi gerado."
fi

char_count=$(wc -c < "$OUTPUT_FILE")
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
echo -e "  ${GREEN}✓${RESET} Transcricao concluida"
echo -e "  ${DIM}Tamanho: ${RESET}${char_count} bytes"
echo -e "  ${DIM}Arquivo: ${RESET}${OUTPUT_FILE}"
echo ""
echo -e "  ${DIM}--- Preview (primeiras 5 linhas) ---${RESET}"
head -5 "$OUTPUT_FILE" | while IFS= read -r line; do
    echo -e "  ${line}"
done
echo ""
success "Transcricao salva em: ${OUTPUT_FILE}"
echo ""
