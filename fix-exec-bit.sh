#!/bin/bash
# fix-exec-bit.sh — Remove bit de execução de arquivos de dados (Linux)
# util apos copiar de NTFS/exFAT, onde arquivos regulares ganham +x indevidamente
# Uso: ./fix-exec-bit.sh [opcoes] [diretorio]   (padrao: diretorio atual)
# Opcoes:
#   --dry-run             Apenas lista arquivos, sem modificar
#   --ext=LISTA           Substitui a lista de extensoes seguras (ex: .txt,.md,.json)
#   --add-ext=LISTA       Adiciona extensoes a lista padrao
#   --list-ext            Imprime a lista padrao de extensoes e sai
#   --include-hidden      Inclui arquivos e diretorios ocultos (ignorados por padrao)
#   --exclude-dir=LISTA   Diretorios extras para ignorar (ex: build,dist)
#   --max-depth=N         Limitar profundidade da busca
#   --quiet               Modo silencioso, so exibe resumo final
#   --force               Nao pedir confirmacao (aplica chmod direto)
#   --report=FILE         Grava lista dos arquivos afetados em FILE
#   --help                Mostra esta ajuda
#   --version             Mostra versao
# Nao toca diretorios (preserva bit x) nem scripts/binarios fora da lista segura.

set -euo pipefail

readonly VERSION="1.0.0"

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

# Lista padrao de extensoes "seguras" (arquivos que nao deveriam ter bit x).
# Conservadora: documentos, web, Office, PDF, fontes, imagens, audio, video,
# compactados, pacotes, patches/locks. ~60 extensoes.
readonly DEFAULT_SAFE_EXTS=(
    txt md rst tex bib json json5 yaml yml toml ini cfg conf properties
    csv tsv log lock map
    html htm css xml svg xul
    pdf epub doc docx odt rtf pages
    xls xlsx ods numbers
    ppt pptx odp key
    ttf otf woff woff2 eot
    bmp jpg jpeg png gif webp ico tiff tif heic heif raw
    mp3 wav flac aac ogg opus m4a aiff alac wma mid midi
    mp4 mov mkv avi webm m4v mpg mpeg flv wmv
    zip tar gz bz2 xz tgz zst lz4 lzma 7z rar jar war cpio iso img
    deb rpm apk dmg msi pkg appimage cab
    patch diff
)

DRY_RUN=false
EXT_OVERRIDE=""
EXT_ADD=""
LIST_EXT=false
INCLUDE_HIDDEN=false
EXCLUDE_DIRS=""
MAX_DEPTH=""
QUIET=false
FORCE=false
REPORT_FILE=""
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --ext=*)
            EXT_OVERRIDE="${1#--ext=}"
            shift
            ;;
        --add-ext=*)
            EXT_ADD="${1#--add-ext=}"
            shift
            ;;
        --list-ext)
            LIST_EXT=true
            shift
            ;;
        --include-hidden)
            INCLUDE_HIDDEN=true
            shift
            ;;
        --exclude-dir=*)
            EXCLUDE_DIRS="${1#--exclude-dir=}"
            shift
            ;;
        --max-depth=*)
            MAX_DEPTH="${1#--max-depth=}"
            shift
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --report=*)
            REPORT_FILE="${1#--report=}"
            shift
            ;;
        --help|-h)
            echo ""
            echo "  fix-exec-bit.sh — Remove bit de execucao de arquivos de dados"
            echo ""
            echo "  Util apos copiar arquivos de NTFS/exFAT, onde arquivos regulares"
            echo "  ganham o bit +x indevidamente. Preserva diretorios e scripts/binarios."
            echo ""
            echo "  Uso: ./fix-exec-bit.sh [opcoes] [diretorio]"
            echo ""
            echo "  Argumentos:"
            echo "    diretorio            Diretorio a processar (padrao: .)"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run            Apenas lista arquivos, sem modificar"
            echo "    --ext=LISTA          Substitui a lista de extensoes seguras (ex: .txt,.md)"
            echo "    --add-ext=LISTA      Adiciona extensoes a lista padrao"
            echo "    --list-ext           Imprime a lista padrao e sai"
            echo "    --include-hidden     Inclui arquivos/dirs ocultos (ignorados por padrao)"
            echo "    --exclude-dir=LISTA  Diretorios extras para ignorar (ex: build,dist)"
            echo "    --max-depth=N        Limitar profundidade da busca"
            echo "    --quiet              Modo silencioso, so exibe resumo"
            echo "    --force              Nao pedir confirmacao (aplica chmod direto)"
            echo "    --report=FILE        Grava lista dos arquivos afetados em FILE"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./fix-exec-bit.sh --dry-run ~/backup_sd"
            echo "    ./fix-exec-bit.sh ~/Documents"
            echo "    ./fix-exec-bit.sh --force --quiet ~/Pictures"
            echo "    ./fix-exec-bit.sh --add-ext=.tex,.bib ~/school"
            echo "    ./fix-exec-bit.sh --max-depth=2 ~/Downloads"
            echo "    ./fix-exec-bit.sh --report=fixados.txt ~/backup_sd"
            echo ""
            exit 0
            ;;
        --version|-V)
            echo "fix-exec-bit.sh $VERSION"
            exit 0
            ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# --list-ext: imprime a lista padrao e sai
if $LIST_EXT; then
    echo "Lista padrao de extensoes seguras (${#DEFAULT_SAFE_EXTS[@]}):"
    for ext in "${DEFAULT_SAFE_EXTS[@]}"; do
        echo "  .$ext"
    done
    exit 0
fi

TARGET="${POSITIONAL_ARGS[0]:-.}"
TARGET="${TARGET%/}"

if [ ! -d "$TARGET" ]; then
    error "'$TARGET' nao e um diretorio valido."
fi

# Constroi a lista final de extensoes seguras
SAFE_EXTS=()
if [ -n "$EXT_OVERRIDE" ]; then
    IFS=',' read -ra parts <<< "$EXT_OVERRIDE"
    for part in "${parts[@]}"; do
        part="${part## }"; part="${part%% }"
        [[ -z "$part" ]] && continue
        [[ "$part" != .* ]] && part=".$part"
        SAFE_EXTS+=("${part#.}")
    done
else
    SAFE_EXTS=("${DEFAULT_SAFE_EXTS[@]}")
    if [ -n "$EXT_ADD" ]; then
        IFS=',' read -ra parts <<< "$EXT_ADD"
        for part in "${parts[@]}"; do
            part="${part## }"; part="${part%% }"
            [[ -z "$part" ]] && continue
            [[ "$part" != .* ]] && part=".$part"
            SAFE_EXTS+=("${part#.}")
        done
    fi
fi

if [ "${#SAFE_EXTS[@]}" -eq 0 ]; then
    error "Lista de extensoes seguras vazia."
fi

# Arquivo temporario para lista de matches
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
trap 'exit 130' INT TERM

# Monta o comando find
find_cmd=(find "$TARGET" -type f -perm /u+x)
if ! $INCLUDE_HIDDEN; then
    find_cmd+=(-not -path '*/\.*')
fi
find_cmd+=(
    -not -path '*/node_modules/*'
    -not -path '*/.venv/*'
    -not -path '*/venv/*'
    -not -path '*/__pycache__/*'
    -not -path '*/.git/*'
    -not -path '*/.hg/*'
    -not -path '*/.svn/*'
)

if [ -n "$EXCLUDE_DIRS" ]; then
    IFS=',' read -ra edirs <<< "$EXCLUDE_DIRS"
    for edir in "${edirs[@]}"; do
        edir="${edir## }"; edir="${edir%% }"
        [[ -z "$edir" ]] && continue
        find_cmd+=(-not -path "*/${edir}/*")
    done
fi

if [ -n "$MAX_DEPTH" ]; then
    find_cmd+=(-maxdepth "$MAX_DEPTH")
fi

# Adiciona o grupo de extensoes seguras: \( -iname "*.txt" -o -iname "*.md" ... \)
# Globs sao quotados para o find expandir (nao o bash no CWD do script).
find_cmd+=(\()
first_ext=true
for ext in "${SAFE_EXTS[@]}"; do
    if $first_ext; then
        find_cmd+=(-iname "*.$ext")
        first_ext=false
    else
        find_cmd+=(-o -iname "*.$ext")
    fi
done
find_cmd+=(\))

find_cmd+=(-printf '%p\n')

if ! $QUIET; then
    echo ""
    echo -e "  ${CYAN}${BOLD}fix-exec-bit.sh${RESET} — Analisando: ${BOLD}$TARGET${RESET}"
    echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${RESET} Nenhum arquivo sera modificado"
    fi
    echo -e "  ${DIM}Buscando arquivos com bit +x e extensoes seguras...${RESET}"
fi

"${find_cmd[@]}" 2>/dev/null > "$TMPFILE" || true

total_matches=0
total_matches=$(wc -l < "$TMPFILE" | tr -d ' ')

if [ "$total_matches" -eq 0 ]; then
    if ! $QUIET; then
        echo -e "  ${GREEN}✓${RESET} Nenhum arquivo com bit +x entre as extensoes seguras."
        echo ""
    fi
    exit 0
fi

# Breakdown por extensao
if ! $QUIET; then
    echo -e "  ${BOLD}$total_matches${RESET} arquivos encontrados com bit +x"
    echo ""
    echo -e "  ${BOLD}Distribuicao por extensao:${RESET}"

    while IFS= read -r fpath; do
        fname=$(basename "$fpath")
        ext="${fname##*.}"
        if [ "$ext" = "$fname" ]; then
            ext="(sem ext)"
        fi
        echo ".$ext"
    done < "$TMPFILE" | sort | uniq -c | sort -rn | while read -r count ext; do
        printf "  %-14s ${BOLD}%d${RESET} arquivos\n" "$ext" "$count"
    done
    echo ""
fi

# Modo dry-run: apenas lista, nao modifica
if $DRY_RUN; then
    if ! $QUIET; then
        echo -e "  ${BOLD}Arquivos que teriam o bit +x removido:${RESET}"
        while IFS= read -r fpath; do
            local_display="${fpath/$HOME/\~}"
            echo -e "    ${DIM}${local_display}${RESET}"
        done < "$TMPFILE"
        echo ""
    fi
    if [ -n "$REPORT_FILE" ]; then
        cp "$TMPFILE" "$REPORT_FILE"
        if ! $QUIET; then
            log "Lista salva em: $REPORT_FILE"
        fi
    fi
    echo "  ─────────────────────────────────"
    echo -e "  ${BOLD}Resumo (dry-run):${RESET}"
    echo -e "  Arquivos que seriam modificados: ${YELLOW}${BOLD}$total_matches${RESET}"
    echo -e "  ${DIM}Execute sem --dry-run para aplicar.${RESET}"
    echo "  ─────────────────────────────────"
    echo ""
    exit 0
fi

# Modo real: pedir confirmacao (a menos que --force)
if ! $FORCE; then
    printf "  Remover bit +x de ${BOLD}%d${RESET} arquivos? [s/N]: " "$total_matches"
    if [ -t 0 ]; then
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    else
        error "Execucao nao interativa detectada. Rode em terminal interativo (TTY) para confirmar."
    fi
    case "$confirm" in
        [sS]) ;;
        *)
            echo -e "  ${DIM}Operacao cancelada.${RESET}"
            exit 0
            ;;
    esac
fi

# Aplica chmod -x em lote via xargs (preserva paths com espacos usando -d '\n').
# -r: nao invoca chmod se a lista estiver vazia
# -n 64: agrupa ate 64 arquivos por invocacao do chmod (eficiente)
if ! $QUIET; then
    echo -e "  ${DIM}Aplicando chmod -x...${RESET}"
fi

ERRFILE="${TMPFILE}.err"
modified=0
chmod_failures=0

if [ -s "$TMPFILE" ]; then
    xargs -r -d '\n' -n 64 chmod -x -- < "$TMPFILE" 2>"$ERRFILE" || true
    if [ -s "$ERRFILE" ]; then
        chmod_failures=$(wc -l < "$ERRFILE" | tr -d ' ')
    fi
    modified=$((total_matches - chmod_failures))
fi
rm -f "$ERRFILE"

if [ -n "$REPORT_FILE" ]; then
    cp "$TMPFILE" "$REPORT_FILE"
    if ! $QUIET; then
        log "Lista de arquivos modificados salva em: $REPORT_FILE"
    fi
fi

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  Arquivos analisados (com +x):  ${BOLD}$total_matches${RESET}"
echo -e "  Bit +x removido:               ${GREEN}${BOLD}$modified${RESET}"
if [ "$chmod_failures" -gt 0 ]; then
    echo -e "  Falhas:                        ${RED}${BOLD}$chmod_failures${RESET}"
fi
echo "  ─────────────────────────────────"
echo ""