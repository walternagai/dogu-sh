#!/bin/bash
# unarchive.sh — Descompacta arquivos compactados (zip, rar, 7z, tar, cbz, cbr...) sozinhos ou em lote
# Uso: ./unarchive.sh [opcoes] ARQUIVO|DIRETORIO [ARQUIVO|DIRETORIO ...]
# Opcoes:
#   -o, --output DIR     Diretorio base de saida (padrao: mesmo diretorio de cada arquivo)
#   -r, --recursive      Varre diretorios informados de forma recursiva
#   -f, --force          Sobrescreve arquivos/pastas de destino ja existentes
#   -F, --flat           Extrai direto no destino, sem criar subpasta por arquivo
#       --dry-run        Simula a extracao sem escrever arquivos
#   -h, --help           Mostra esta ajuda
#   -V, --version        Mostra versao
#
# Formatos suportados:
#   zip cbz jar rar cbr 7z tar tar.gz tgz tar.bz2 tbz2 tbz tar.xz txz tar.zst tzst gz bz2 xz zst

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

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
INSTALLER=""
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
fi

OUTPUT_DIR=""
RECURSIVE=false
FORCE=false
FLAT=false
DRY_RUN=false
declare -a INPUT_ITEMS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            if [[ -z "${2-}" ]]; then
                echo -e "${RED}Flag --output requer um valor${RESET}" >&2
                exit 2
            fi
            OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive) RECURSIVE=true; shift ;;
        -f|--force)     FORCE=true; shift ;;
        -F|--flat)      FLAT=true; shift ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  unarchive.sh — Descompacta arquivos compactados sozinhos ou em lote"
            echo ""
            echo "  Uso: ./unarchive.sh [opcoes] ARQUIVO|DIRETORIO [ARQUIVO|DIRETORIO ...]"
            echo ""
            echo "  Opcoes:"
            echo "    -o, --output DIR     Diretorio base de saida (padrao: mesmo diretorio de cada arquivo)"
            echo "    -r, --recursive      Varre diretorios informados de forma recursiva"
            echo "    -f, --force          Sobrescreve arquivos/pastas de destino ja existentes"
            echo "    -F, --flat           Extrai direto no destino, sem criar subpasta por arquivo"
            echo "        --dry-run        Simula a extracao sem escrever arquivos"
            echo "    -h, --help           Mostra esta ajuda"
            echo "    -V, --version        Mostra versao"
            echo ""
            echo "  Formatos: zip cbz jar rar cbr 7z tar tar.gz tgz tar.bz2 tbz2"
            echo "            tbz tar.xz txz tar.zst tzst gz bz2 xz zst"
            echo ""
            echo "  Exemplos:"
            echo "    ./unarchive.sh arquivo.zip"
            echo "    ./unarchive.sh *.zip *.cbz"
            echo "    ./unarchive.sh -o ./saida *.7z"
            echo "    ./unarchive.sh ./Downloads"
            echo "    ./unarchive.sh -r ./Downloads"
            echo "    ./unarchive.sh -F -o ./tudo *.rar"
            echo "    ./unarchive.sh --dry-run arquivo.cbr"
            echo ""
            exit 0
            ;;
        --version|-V) echo "unarchive.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; if [[ $# -gt 0 ]]; then INPUT_ITEMS+=("$@"); fi; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            INPUT_ITEMS+=("$1"); shift ;;
    esac
done

dim_output() {
    while IFS= read -r line; do
        echo -e "        ${DIM}${line}${RESET}"
    done
}

is_archive() {
    local f="${1,,}"
    case "$f" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz|*.tar.xz|*.txz|*.tar.zst|*.tzst|*.tar|*.zip|*.cbz|*.jar|*.rar|*.cbr|*.7z|*.gz|*.bz2|*.xz|*.zst) return 0 ;;
        *) return 1 ;;
    esac
}

archive_type() {
    local f="${1,,}"
    case "$f" in
        *.tar.zst|*.tzst) echo "tar.zst" ;;
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz|*.tar.xz|*.txz|*.tar) echo "tar" ;;
        *.zip|*.cbz|*.jar) echo "zip" ;;
        *.rar|*.cbr) echo "rar" ;;
        *.7z) echo "7z" ;;
        *.gz) echo "gz" ;;
        *.bz2) echo "bz2" ;;
        *.xz) echo "xz" ;;
        *.zst) echo "zst" ;;
        *) echo "unknown" ;;
    esac
}

archive_base() {
    local name lower base
    name=$(basename "$1")
    lower="${name,,}"
    case "$lower" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tbz|*.tar.xz|*.txz|*.tar.zst|*.tzst)
            base="${lower%.*}"
            base="${base%.tar}" ;;
        *) base="${name%.*}" ;;
    esac
    echo "$base"
}

require_tool() {
    local bin="$1"
    local pkg="$2"
    if command -v "$bin" >/dev/null 2>&1; then
        return 0
    fi
    if [[ -n "$INSTALLER" && "$INSTALLER" != echo* ]]; then
        if [[ "$pkg" == "p7zip-full" && "$INSTALLER" != sudo\ apt-get* ]]; then pkg="p7zip"; fi
        if [[ "$pkg" == "xz-utils" && "$INSTALLER" != sudo\ apt-get* ]]; then pkg="xz"; fi
        check_and_install "$bin" "$INSTALLER" "$pkg"
        return 0
    fi
    echo -e "${RED}[ERROR]${RESET} Dependencia '${bin}' nao encontrada. Instale manualmente." >&2
    exit 127
}

extract_zip() {
    local archive="$1" destdir="$2"
    local ovl=(-o)
    if [[ "$FLAT" == true && "$FORCE" == false ]]; then ovl=(-n); fi
    unzip "${ovl[@]}" "$archive" -d "$destdir" 2>&1 | dim_output
}

extract_rar() {
    local archive="$1" destdir="$2"
    local ovflag="-o+"
    if [[ "$FLAT" == true && "$FORCE" == false ]]; then ovflag="-o-"; fi
    unrar x -y "$ovflag" "$archive" "$destdir/" 2>&1 | dim_output
}

extract_7z() {
    local archive="$1" destdir="$2"
    local bin="" mode="-aoa"
    if command -v 7z >/dev/null 2>&1; then
        bin="7z"
    elif command -v 7za >/dev/null 2>&1; then
        bin="7za"
    else
        echo -e "${RED}[ERROR] 7z nao encontrado.${RESET}" >&2
        return 1
    fi
    if [[ "$FLAT" == true && "$FORCE" == false ]]; then mode="-aos"; fi
    "$bin" x -bd -y "$mode" -o"$destdir" "$archive" 2>&1 | dim_output
}

extract_tar() {
    local archive="$1" destdir="$2" atype="$3"
    local opts=(-x -v)
    if [[ "$atype" == "tar.zst" ]]; then opts=(--zstd "${opts[@]}"); fi
    if [[ "$FLAT" == true && "$FORCE" == false ]]; then opts+=(-k); fi
    tar "${opts[@]}" -f "$archive" -C "$destdir" 2>&1 | dim_output
}

extract_single() {
    local archive="$1" target="$2" tool="$3"
    case "$tool" in
        gzip)  gzip -cd "$archive" > "$target" ;;
        bzip2) bzip2 -cd "$archive" > "$target" ;;
        xz)    xz -cd "$archive" > "$target" ;;
        zstd)  zstd -dcq "$archive" > "$target" ;;
    esac
}

run_extract() {
    local atype="$1" archive="$2" destdir="$3" target="$4"
    case "$atype" in
        zip)         extract_zip "$archive" "$destdir" ;;
        rar)         if command -v unrar >/dev/null 2>&1; then extract_rar "$archive" "$destdir"; else extract_7z "$archive" "$destdir"; fi ;;
        7z)          extract_7z "$archive" "$destdir" ;;
        tar|tar.zst) extract_tar "$archive" "$destdir" "$atype" ;;
        gz)          extract_single "$archive" "$target" gzip ;;
        bz2)         extract_single "$archive" "$target" bzip2 ;;
        xz)          extract_single "$archive" "$target" xz ;;
        zst)         extract_single "$archive" "$target" zstd ;;
    esac
}

if [[ ${#INPUT_ITEMS[@]} -eq 0 ]]; then
    error "Informe ao menos um arquivo compactado ou diretorio. Uso: ./unarchive.sh [opcoes] ARQUIVO|DIRETORIO ..."
fi

shopt -s nullglob
declare -a ARCHIVES=()
declare -a PENDING_ERRORS=()
for item in "${INPUT_ITEMS[@]}"; do
    if [[ -d "$item" ]]; then
        if [[ "$RECURSIVE" == true ]]; then
            while IFS= read -r -d '' f; do
                if [[ -f "$f" ]] && is_archive "$f"; then
                    ARCHIVES+=("$f")
                fi
            done < <(find "$item" -type f -print0)
        else
            for f in "$item"/*; do
                if [[ -f "$f" ]] && is_archive "$f"; then
                    ARCHIVES+=("$f")
                fi
            done
        fi
    elif [[ -f "$item" ]]; then
        if is_archive "$item"; then
            ARCHIVES+=("$item")
        else
            warn "Extensao nao suportada, ignorando: $item"
            PENDING_ERRORS+=("$item")
        fi
    else
        warn "Nao encontrado, ignorando: $item"
        PENDING_ERRORS+=("$item")
    fi
done

if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
    error "Nenhum arquivo compactado suportado encontrado."
fi

if [[ -n "$OUTPUT_DIR" && ! -d "$OUTPUT_DIR" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${DIM}[Dry-run] mkdir -p $OUTPUT_DIR${RESET}"
    else
        mkdir -p "$OUTPUT_DIR"
    fi
fi

total=${#ARCHIVES[@]}
if [[ -n "$OUTPUT_DIR" ]]; then DESTSHOW="$OUTPUT_DIR"; else DESTSHOW="mesmo diretorio de cada arquivo"; fi
MODOSHOW="subpastas por arquivo"
if [[ "$FLAT" == true ]]; then MODOSHOW="plano (sem subpastas)"; fi
if [[ "$RECURSIVE" == true ]]; then MODOSHOW="${MODOSHOW} + varredura recursiva"; fi

echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}Unarchive${RESET}  ${DIM}v${SCRIPT_VERSION}${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  ${DIM}Arquivos:  ${RESET}${total}"
echo -e "  ${DIM}Destino:   ${RESET}${DESTSHOW}"
echo -e "  ${DIM}Modo:      ${RESET}${MODOSHOW}"
echo ""

processed=0
ok=0
skipped=0
failed=0

for archive in "${ARCHIVES[@]}"; do
    processed=$((processed + 1))
    atype=$(archive_type "$archive")
    base=$(archive_base "$archive")
    arc_name=$(basename "$archive")
    parent=$(dirname "$archive")

    is_single=false
    destdir=""
    target=""
    dest_show=""
    cmd_desc=""
    case "$atype" in
        tar|tar.zst)
            if [[ "$FLAT" == true ]]; then destdir="${OUTPUT_DIR:-$parent}"; else destdir="${OUTPUT_DIR:-$parent}/$base"; fi
            tmode=""
            kflag=""
            if [[ "$atype" == "tar.zst" ]]; then tmode="--zstd "; fi
            if [[ "$FLAT" == true && "$FORCE" == false ]]; then kflag=" -k"; fi
            cmd_desc="tar ${tmode}-xvf${kflag} \"$archive\" -C \"$destdir\""
            dest_show="$destdir/"
            ;;
        zip)
            if [[ "$FLAT" == true ]]; then destdir="${OUTPUT_DIR:-$parent}"; else destdir="${OUTPUT_DIR:-$parent}/$base"; fi
            ovflag="-o"
            if [[ "$FLAT" == true && "$FORCE" == false ]]; then ovflag="-n"; fi
            cmd_desc="unzip $ovflag \"$archive\" -d \"$destdir\""
            dest_show="$destdir/"
            ;;
        rar)
            if [[ "$FLAT" == true ]]; then destdir="${OUTPUT_DIR:-$parent}"; else destdir="${OUTPUT_DIR:-$parent}/$base"; fi
            ovflag="-o+"
            if [[ "$FLAT" == true && "$FORCE" == false ]]; then ovflag="-o-"; fi
            cmd_desc="unrar x -y $ovflag \"$archive\" \"$destdir/\""
            dest_show="$destdir/"
            ;;
        7z)
            if [[ "$FLAT" == true ]]; then destdir="${OUTPUT_DIR:-$parent}"; else destdir="${OUTPUT_DIR:-$parent}/$base"; fi
            mode="-aoa"
            if [[ "$FLAT" == true && "$FORCE" == false ]]; then mode="-aos"; fi
            cmd_desc="7z x -bd -y $mode -o\"$destdir\" \"$archive\""
            dest_show="$destdir/"
            ;;
        gz|bz2|xz|zst)
            is_single=true
            if [[ -n "$OUTPUT_DIR" ]]; then target="$OUTPUT_DIR/$base"; else target="$parent/$base"; fi
            comp="gzip -cd"
            case "$atype" in
                bz2) comp="bzip2 -cd" ;;
                xz)  comp="xz -cd" ;;
                zst) comp="zstd -d" ;;
            esac
            cmd_desc="$comp \"$archive\" > \"$target\""
            dest_show="$target"
            ;;
        *)
            warn "Formato desconhecido, ignorando: $archive"
            failed=$((failed + 1))
            continue
            ;;
    esac

    echo -e "  ${CYAN}▶${RESET} ${DIM}[${processed}/${total}]${RESET} ${BOLD}${arc_name}${RESET} ${DIM}(${atype})${RESET}"
    echo -e "      ${DIM}→ ${dest_show}${RESET}"

    if [[ "$is_single" == true && -e "$target" && "$FORCE" == false ]]; then
        echo -e "      ${YELLOW}• Pulado: destino existe. Use --force para sobrescrever.${RESET}"
        skipped=$((skipped + 1))
        continue
    fi
    if [[ "$is_single" == false && "$FLAT" == false && -d "$destdir" && -n "$(ls -A "$destdir" 2>/dev/null)" && "$FORCE" == false ]]; then
        echo -e "      ${YELLOW}• Pulado: pasta de destino ja existe e nao esta vazia. Use --force para sobrescrever.${RESET}"
        skipped=$((skipped + 1))
        continue
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "      ${DIM}[Dry-run] ${cmd_desc}${RESET}"
        ok=$((ok + 1))
        continue
    fi

    if [[ -n "$destdir" && ! -d "$destdir" ]]; then
        mkdir -p "$destdir"
    fi

    case "$atype" in
        zip)     require_tool unzip unzip ;;
        rar)     if ! command -v unrar >/dev/null 2>&1 && ! command -v 7z >/dev/null 2>&1 && ! command -v 7za >/dev/null 2>&1; then require_tool unrar unrar; fi ;;
        7z)      if ! command -v 7z >/dev/null 2>&1 && ! command -v 7za >/dev/null 2>&1; then require_tool 7z p7zip-full; fi ;;
        tar)     : ;;
        tar.zst) require_tool zstd zstd ;;
        gz)      require_tool gzip gzip ;;
        bz2)     require_tool bzip2 bzip2 ;;
        xz)      require_tool xz xz-utils ;;
        zst)     require_tool zstd zstd ;;
    esac

    if run_extract "$atype" "$archive" "$destdir" "$target"; then
        echo -e "      ${GREEN}✓ Extraido${RESET}"
        ok=$((ok + 1))
    else
        echo -e "      ${RED}✗ Falhou${RESET}"
        failed=$((failed + 1))
    fi
done

echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
echo -e "  ${GREEN}✓${RESET} Extraidos: ${ok}"
echo -e "  ${YELLOW}•${RESET} Pulados:   ${skipped}"
echo -e "  ${RED}✗${RESET} Falhas:    $((failed + ${#PENDING_ERRORS[@]}))"
echo ""

if [[ "$failed" -gt 0 || ${#PENDING_ERRORS[@]} -gt 0 ]]; then
    echo -e "  ${RED}$((failed + ${#PENDING_ERRORS[@]})) item(s) com problema na extracao.${RESET}" >&2
    exit 1
fi

success "Extracao concluida: ${ok} arquivo(s) processado(s)."
echo ""