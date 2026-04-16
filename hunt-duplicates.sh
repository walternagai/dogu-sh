#!/bin/bash
# hunt-duplicates.sh — Find duplicate files by SHA-256 hash (Linux)
# Uso: ./hunt-duplicates.sh [opcoes] [pasta] [tamanho-minimo-bytes]
# Padrao: diretorio atual com minimo de 1 KB
# Opcoes:
#   --dry-run             Apenas lista, sem interacao (padrao)
#   --trash               Move duplicatas para lixeira
#   --delete              Deleta duplicatas permanentemente (requer --force ou confirmacao)
#   --soft-link           Substitui duplicatas por symlink apontando para o arquivo mantido
#   --mode=MODE           Estrategia de selecao: oldest, newest, smallest-path, first (padrao: first)
#   --interactive         Modo interativo: escolhe qual arquivo manter por grupo
#   --output=FILE         Exporta resultados em JSON ou CSV
#   --ext=LISTA           Filtrar por extensoes (ex: .png,.jpg,.pdf)
#   --type=LISTA          Filtrar por tipo MIME (ex: image,video,document)
#   --max-depth=N         Limitar profundidade da busca
#   --exclude-dir=LISTA   Diretorios extras para ignorar (alem dos padrao)
#   --include-hidden      Incluir arquivos e diretorios ocultos
#   --symlinks            Seguir symlinks
#   --threshold=N         Exibir apenas grupos com N ou mais duplicatas
#   --quiet               Modo silencioso, so exibe resumo final
#   --force               Nao pedir confirmacao (usado com --delete)
#   --use-cache           Usar cache de hashes em ~/.cache/hunt-duplicates/
#   --watch               Monitorar diretorio continuamente com inotifywait
#   --partial-compare     Usar comparacao parcial de conteudo como pre-filtro
#   --help                Mostra esta ajuda
#   --version             Mostra versao
# Nenhum arquivo e deletado sem --trash, --delete ou --soft-link.

set -eo pipefail

VERSION="2.0.0"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=dependency-helper.sh
source "$SCRIPT_DIR/dependency-helper.sh" 2>/dev/null || true

YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

USE_TRASH=false
USE_DELETE=false
USE_SOFT_LINK=false
KEEP_MODE="first"
INTERACTIVE=false
OUTPUT_FILE=""
EXT_FILTER=""
TYPE_FILTER=""
MAX_DEPTH=""
EXCLUDE_DIRS=""
INCLUDE_HIDDEN=false
FOLLOW_SYMLINKS=false
THRESHOLD=0
QUIET=false
FORCE=false
USE_CACHE=false
WATCH_MODE=false
PARTIAL_COMPARE=false
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --trash)
            USE_TRASH=true
            shift
            ;;
        --delete)
            USE_DELETE=true
            shift
            ;;
        --soft-link)
            USE_SOFT_LINK=true
            shift
            ;;
        --mode=*)
            KEEP_MODE="${1#--mode=}"
            case "$KEEP_MODE" in
                oldest|newest|smallest-path|first) ;;
                *) echo "Erro: --mode invalido '$KEEP_MODE'. Use: oldest, newest, smallest-path, first" >&2; exit 1 ;;
            esac
            shift
            ;;
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --output=*)
            OUTPUT_FILE="${1#--output=}"
            shift
            ;;
        --ext=*)
            EXT_FILTER="${1#--ext=}"
            shift
            ;;
        --type=*)
            TYPE_FILTER="${1#--type=}"
            shift
            ;;
        --max-depth=*)
            MAX_DEPTH="${1#--max-depth=}"
            shift
            ;;
        --exclude-dir=*)
            EXCLUDE_DIRS="${1#--exclude-dir=}"
            shift
            ;;
        --include-hidden)
            INCLUDE_HIDDEN=true
            shift
            ;;
        --symlinks)
            FOLLOW_SYMLINKS=true
            shift
            ;;
        --threshold=*)
            THRESHOLD="${1#--threshold=}"
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
        --use-cache)
            USE_CACHE=true
            shift
            ;;
        --watch)
            WATCH_MODE=true
            shift
            ;;
        --partial-compare)
            PARTIAL_COMPARE=true
            shift
            ;;
        --dry-run)
            shift
            ;;
        --help|-h)
            echo ""
            echo "  hunt-duplicates.sh — Encontra arquivos duplicados por hash SHA-256"
            echo ""
            echo "  Uso: ./hunt-duplicates.sh [opcoes] [pasta] [tamanho-minimo-bytes]"
            echo ""
            echo "  Argumentos:"
            echo "    pasta                Diretorio a escanear (padrao: .)"
            echo "    tamanho-minimo-bytes Tamanho minimo em bytes (padrao: 1024)"
            echo ""
            echo "  Opcoes:"
            echo "    --trash              Move duplicatas para lixeira"
            echo "    --delete             Deleta duplicatas permanentemente (requer --force)"
            echo "    --soft-link          Substitui duplicatas por symlink"
            echo "    --mode=MODE          Estrategia: oldest|newest|smallest-path|first (padrao)"
            echo "    --interactive        Escolhe qual arquivo manter por grupo"
            echo "    --output=FILE        Exporta resultados (JSON ou CSV, pela extensao)"
            echo "    --ext=LISTA          Filtrar por extensoes (ex: .png,.jpg)"
            echo "    --type=LISTA         Filtrar por tipo MIME (ex: image,video,document)"
            echo "    --max-depth=N        Limitar profundidade da busca"
            echo "    --exclude-dir=LISTA  Diretorios extras para ignorar (ex: build,dist)"
            echo "    --include-hidden     Incluir arquivos e diretorios ocultos"
            echo "    --symlinks           Seguir symlinks"
            echo "    --threshold=N        Minimo de copias para exibir grupo (padrao: 0)"
            echo "    --quiet              Modo silencioso, so exibe resumo"
            echo "    --force              Nao pedir confirmacao (com --delete)"
            echo "    --use-cache          Usar cache de hashes para acelerar buscas"
            echo "    --watch              Monitorar diretorio continuamente"
            echo "    --partial-compare    Pre-filtro por comparacao parcial de conteudo"
            echo "    --dry-run            Apenas lista (padrao)"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./hunt-duplicates.sh ~/Downloads"
            echo "    ./hunt-duplicates.sh --trash ~/Documents 2048"
            echo "    ./hunt-duplicates.sh --interactive --mode=oldest ~/Photos"
            echo "    ./hunt-duplicates.sh --output=report.json ~/Music"
            echo "    ./hunt-duplicates.sh --ext=.png,.jpg --threshold=3 ~/Pictures"
            echo "    ./hunt-duplicates.sh --use-cache --partial-compare ~/"
            echo "    ./hunt-duplicates.sh --watch ~/Downloads"
            echo ""
            exit 0
            ;;
        --version|-v)
            echo "hunt-duplicates.sh $VERSION"
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
MIN_SIZE="${POSITIONAL_ARGS[1]:-1024}"

if [ ! -d "$TARGET" ]; then
    echo "Erro: '$TARGET' nao e um diretorio valido." >&2
    exit 1
fi

if $USE_DELETE && ! $FORCE; then
    echo -e "${RED}ATENCAO: --delete ira deletar permanentemente os arquivos!${RESET}" >&2
    read -p "Confirmar exclusao permanente de duplicatas? [s/N]: " confirm
    if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
        echo "Operacao cancelada." >&2
        exit 0
    fi
fi

if $WATCH_MODE; then
    check_and_install inotifywait "$(detect_installer) inotify-tools" 2>/dev/null || {
        echo "Erro: inotifywait nao encontrado. Instale inotify-tools." >&2
        exit 1
    }
fi

build_ext_find_args() {
    local exts="$1"
    local first=true
    IFS=',' read -ra parts <<< "$exts"
    for part in "${parts[@]}"; do
        part="${part## }"
        part="${part%% }"
        [[ "$part" != .* ]] && part=".$part"
        if $first; then
            printf ' -iname *%s' "$part"
            first=false
        else
            printf ' -o -iname *%s' "$part"
        fi
    done
}

get_mime_category() {
    local filepath="$1"
    local mime
    mime=$(file --mime-type -b "$filepath" 2>/dev/null || echo "unknown")
    echo "${mime%%/*}"
}

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

SIZE_FILE="$TMPDIR_WORK/sizes"
HASH_FILE="$TMPDIR_WORK/hashes"
CACHE_DIR="${HOME}/.cache/hunt-duplicates"

human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} B"
    fi
}

ensure_trash_dir() {
    local trash_dir="${HOME}/.local/share/Trash"
    mkdir -p "$trash_dir/files" "$trash_dir/info"
    echo "$trash_dir"
}

trash_file() {
    local filepath="$1"
    local trash_dir
    trash_dir=$(ensure_trash_dir)

    local bname
    bname=$(basename "$filepath")
    local dest="$trash_dir/files/$bname"
    local n=1
    while [ -e "$dest" ]; do
        dest="$trash_dir/files/${bname} ($n)"
        n=$((n + 1))
    done

    mv "$filepath" "$dest"

    local info_file="$trash_dir/info/$(basename "$dest").trashinfo"
    cat > "$info_file" <<TRASHINFO
[Trash Info]
Path=$(realpath "$dest" 2>/dev/null || echo "$filepath")
DeletionDate=$(date '+%Y-%m-%dT%H:%M:%S')
TRASHINFO
}

get_cached_hash() {
    local filepath="$1"
    local mtime size cache_key cache_file

    mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 0)
    size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
    cache_key=$(echo -n "${filepath}|${mtime}|${size}" | sha256sum | awk '{print $1}')
    cache_file="$CACHE_DIR/${cache_key:0:2}/${cache_key:2}"

    if [ -f "$cache_file" ]; then
        local cached_hash
        cached_hash=$(head -1 "$cache_file" 2>/dev/null)
        if [ -n "$cached_hash" ]; then
            echo "${cached_hash}|${size}|${filepath}"
            return 0
        fi
    fi
    return 1
}

save_cached_hash() {
    local filepath="$1"
    local hash="$2"
    local mtime size cache_key cache_file

    mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 0)
    size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
    cache_key=$(echo -n "${filepath}|${mtime}|${size}" | sha256sum | awk '{print $1}')
    cache_file="$CACHE_DIR/${cache_key:0:2}/${cache_key:2}"

    mkdir -p "$(dirname "$cache_file")"
    echo "$hash" > "$cache_file"
}

partial_key() {
    local filepath="$1"
    local size head_bytes head_hash tail_hash

    size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
    head_bytes=4096
    if [ "$size" -lt "$head_bytes" ]; then
        head_bytes="$size"
    fi
    head_hash=$(head -c "$head_bytes" "$filepath" 2>/dev/null | sha256sum | awk '{print $1}')
    if [ "$size" -gt "$head_bytes" ]; then
        tail_hash=$(tail -c "$head_bytes" "$filepath" 2>/dev/null | sha256sum | awk '{print $1}')
    else
        tail_hash="$head_hash"
    fi
    echo "${size}|${head_hash}|${tail_hash}"
}

pick_keeper() {
    local group_lines="$1"
    local mode="$2"
    local result_file="$TMPDIR_WORK/pick_keeper_result"
    > "$result_file"

    case "$mode" in
        first)
            echo "$group_lines" | head -1 > "$result_file"
            ;;
        oldest)
            echo "$group_lines" | while IFS='|' read -r hash size filepath; do
                local mtime
                mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 9999999999)
                echo "${mtime}|${hash}|${size}|${filepath}"
            done | sort -t'|' -k1,1n | head -1 | while IFS='|' read -r _ hash size filepath; do
                echo "${hash}|${size}|${filepath}"
            done > "$result_file"
            ;;
        newest)
            echo "$group_lines" | while IFS='|' read -r hash size filepath; do
                local mtime
                mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 0)
                echo "${mtime}|${hash}|${size}|${filepath}"
            done | sort -t'|' -k1,1rn | head -1 | while IFS='|' read -r _ hash size filepath; do
                echo "${hash}|${size}|${filepath}"
            done > "$result_file"
            ;;
        smallest-path)
            echo "$group_lines" | awk -F'|' '{print length($3)"|"$0}' | sort -t'|' -k1,1n | head -1 | cut -d'|' -f2- > "$result_file"
            ;;
    esac
    cat "$result_file"
}

interactive_pick() {
    local group_lines="$1"
    local group_num="$2"
    local result_file="$TMPDIR_WORK/interactive_result"
    > "$result_file"

    echo -e "\n  ${YELLOW}Grupo $group_num${RESET} — Escolha o arquivo para MANTER:"
    local i=1
    while IFS='|' read -r _ _ filepath; do
        local display="${filepath/$HOME/\~}"
        echo -e "    ${CYAN}[$i]${RESET} $display"
        i=$((i + 1))
    done <<< "$group_lines"

    read -p "  Digite o numero do arquivo a manter: " choice
    local count
    count=$(echo "$group_lines" | wc -l | tr -d ' ')
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        echo "$group_lines" | sed -n "${choice}p" > "$result_file"
    else
        echo "$group_lines" | head -1 > "$result_file"
    fi
    cat "$result_file"
}

is_hardlink() {
    local file1="$1"
    local file2="$2"
    local inode1 inode2
    inode1=$(stat -c '%i' "$file1" 2>/dev/null || echo 0)
    inode2=$(stat -c '%i' "$file2" 2>/dev/null || echo 0)
    [ "$inode1" != "0" ] && [ "$inode1" = "$inode2" ]
}

resolve_action() {
    local filepath="$1"
    local action="$2"
    local keeper="$3"
    local display="${filepath/$HOME/\~}"

    case "$action" in
        trash)
            if trash_file "$filepath" 2>/dev/null; then
                echo -e "    ${RED}${display}${RESET} ${DIM}-> lixeira${RESET}"
            else
                echo -e "    ${DIM}(falha ao mover: ${display})${RESET}"
            fi
            ;;
        delete)
            if rm -f "$filepath" 2>/dev/null; then
                echo -e "    ${RED}${display}${RESET} ${DIM}-> deletado${RESET}"
            else
                echo -e "    ${DIM}(falha ao deletar: ${display})${RESET}"
            fi
            ;;
        softlink)
            local rel_target
            rel_target=$(realpath "$keeper" 2>/dev/null || echo "$keeper")
            if ln -sf "$rel_target" "$filepath" 2>/dev/null; then
                echo -e "    ${CYAN}${display}${RESET} ${DIM}-> symlink${RESET}"
            else
                echo -e "    ${DIM}(falha ao criar symlink: ${display})${RESET}"
            fi
            ;;
        list)
            echo "    $display"
            ;;
    esac
}

show_progress() {
    local current="$1"
    local total="$2"
    local label="$3"
    local width=30
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local bar=""
    local i

    for ((i = 0; i < filled; i++)); do bar="${bar}#"; done
    for ((i = 0; i < empty; i++)); do bar="${bar}-"; done

    echo -ne "\r  ${label} [${bar}] ${percent}% (${current}/${total})  "
}

write_hash_script() {
    local target_file="$1"
    cat > "$target_file" <<'HASHEOF'
#!/bin/bash
filepath="$1"
size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 0)
if [ "${HDC_CACHE_ENABLED}" = "1" ] && [ -n "${HDC_CACHE_DIR}" ]; then
    cache_key=$(echo -n "${filepath}|${mtime}|${size}" | sha256sum | awk '{print $1}')
    cache_file="${HDC_CACHE_DIR}/${cache_key:0:2}/${cache_key:2}"
    if [ -f "$cache_file" ]; then
        cached_hash=$(head -1 "$cache_file" 2>/dev/null)
        if [ -n "$cached_hash" ]; then
            echo "${cached_hash}|${size}|${filepath}"
            exit 0
        fi
    fi
fi
hash=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')
if [ -n "$hash" ]; then
    if [ "${HDC_CACHE_ENABLED}" = "1" ] && [ -n "${HDC_CACHE_DIR}" ]; then
        cache_key=$(echo -n "${filepath}|${mtime}|${size}" | sha256sum | awk '{print $1}')
        cache_file="${HDC_CACHE_DIR}/${cache_key:0:2}/${cache_key:2}"
        mkdir -p "$(dirname "$cache_file")"
        echo "$hash" > "$cache_file"
    fi
    echo "${hash}|${size}|${filepath}"
fi
HASHEOF
    chmod +x "$target_file"
}

run_scan() {
    if ! $QUIET; then
        echo ""
        echo -e "  Escaneando ${BOLD}$TARGET${RESET}..."
        echo -e "  ${DIM}(ignorando arquivos < $(human_size "$MIN_SIZE"))${RESET}"
        echo ""
    fi

    local find_cmd=(find "$TARGET" -type f)
    if ! $INCLUDE_HIDDEN; then
        find_cmd+=(-not -path '*/\.*')
    fi
    find_cmd+=(
        -not -path '*/node_modules/*'
        -not -path '*/.venv/*'
        -not -path '*/venv/*'
        -not -path '*/__pycache__/*'
        -not -path '*/.git/*'
    )

    if [ -n "$EXCLUDE_DIRS" ]; then
        IFS=',' read -ra edirs <<< "$EXCLUDE_DIRS"
        for edir in "${edirs[@]}"; do
            edir="${edir## }"; edir="${edir%% }"
            find_cmd+=(-not -path "*/${edir}/*")
        done
    fi

    if [ -n "$MAX_DEPTH" ]; then
        find_cmd+=(-maxdepth "$MAX_DEPTH")
    fi

    if $FOLLOW_SYMLINKS; then
        find_cmd+=(-follow)
    fi

    find_cmd+=(-size +"${MIN_SIZE}c")

    if [ -n "$EXT_FILTER" ]; then
        local ext_args
        ext_args=$(build_ext_find_args "$EXT_FILTER")
        if [ -n "$ext_args" ]; then
            eval "find_cmd+=( \( ${ext_args} \) )"
        fi
    fi

    find_cmd+=(-printf '%s|%p\n')

    if ! $QUIET; then
        echo -ne "  Listando arquivos...\r"
    fi

    "${find_cmd[@]}" 2>/dev/null > "$SIZE_FILE"

    if [ -n "$TYPE_FILTER" ]; then
        local filtered_file="$TMPDIR_WORK/filtered_sizes"
        > "$filtered_file"
        IFS=',' read -ra tcats <<< "$TYPE_FILTER"
        while IFS='|' read -r size filepath; do
            local cat
            cat=$(get_mime_category "$filepath")
            for tcat in "${tcats[@]}"; do
                tcat="${tcat## }"; tcat="${tcat%% }"
                if [ "$cat" = "$tcat" ]; then
                    echo "${size}|${filepath}" >> "$filtered_file"
                    break
                fi
            done
        done < "$SIZE_FILE"
        mv "$filtered_file" "$SIZE_FILE"
    fi

    local total_files
    total_files=$(wc -l < "$SIZE_FILE" | tr -d ' ')

    if ! $QUIET; then
        echo -e "  ${BOLD}$total_files${RESET} arquivos encontrados"
        echo ""
    fi

    if [ "$total_files" -eq 0 ]; then
        if ! $QUIET; then
            echo -e "  ${GREEN}Nenhum arquivo para analisar.${RESET}"
            echo ""
        fi
        return 1
    fi

    if ! $QUIET; then
        echo -ne "  Agrupando por tamanho...\r"
    fi
    awk -F'|' '{print $1}' "$SIZE_FILE" | sort | uniq -d > "$TMPDIR_WORK/dup_sizes"

    if [ ! -s "$TMPDIR_WORK/dup_sizes" ]; then
        if ! $QUIET; then
            echo -e "  ${GREEN}Nenhuma duplicata encontrada.${RESET}"
            echo ""
        fi
        return 1
    fi

    > "$TMPDIR_WORK/candidates"
    while read -r dup_size; do
        awk -F'|' -v s="$dup_size" '$1 == s' "$SIZE_FILE" >> "$TMPDIR_WORK/candidates"
    done < "$TMPDIR_WORK/dup_sizes"

    local candidates
    candidates=$(wc -l < "$TMPDIR_WORK/candidates" | tr -d ' ')

    if ! $QUIET; then
        echo -e "  ${BOLD}$candidates${RESET} candidatos a duplicata (mesmo tamanho)"
    fi

    if $PARTIAL_COMPARE && [ "$candidates" -gt 0 ]; then
        if ! $QUIET; then
            echo -ne "  Pre-filtro por comparacao parcial...\r"
        fi
        local partial_file="$TMPDIR_WORK/partial_keys"
        > "$partial_file"
        while IFS='|' read -r size filepath; do
            local pkey
            pkey=$(partial_key "$filepath")
            echo "${pkey}|${filepath}" >> "$partial_file"
        done < "$TMPDIR_WORK/candidates"

        awk -F'|' '{print $1"|"$2"|"$3}' "$partial_file" | sort | uniq -d > "$TMPDIR_WORK/dup_partials"

        > "$TMPDIR_WORK/filtered_candidates"
        while read -r dp; do
            while IFS='|' read -r _ _ _ pfilepath; do
                local psize
                psize=$(stat -c '%s' "$pfilepath" 2>/dev/null || echo 0)
                echo "${psize}|${pfilepath}"
            done < <(grep -F "$dp" "$partial_file") >> "$TMPDIR_WORK/filtered_candidates"
        done < "$TMPDIR_WORK/dup_partials"

        if [ -s "$TMPDIR_WORK/filtered_candidates" ]; then
            mv "$TMPDIR_WORK/filtered_candidates" "$TMPDIR_WORK/candidates"
            candidates=$(wc -l < "$TMPDIR_WORK/candidates" | tr -d ' ')
        fi
        if ! $QUIET; then
            echo -e "  Apos pre-filtro: ${BOLD}$candidates${RESET} candidatos"
        fi
    fi

    local hashed=0
    > "$HASH_FILE"

    PARALLEL_JOBS=$(nproc 2>/dev/null || echo 4)

    local HASH_SCRIPT="$TMPDIR_WORK/hash_one.sh"
    write_hash_script "$HASH_SCRIPT"

    if $USE_CACHE; then
        export HDC_CACHE_ENABLED=1
        export HDC_CACHE_DIR="$CACHE_DIR"
        mkdir -p "$CACHE_DIR"
    else
        export HDC_CACHE_ENABLED=0
        export HDC_CACHE_DIR=""
    fi

    if [ "$candidates" -gt 50 ] && command -v xargs &>/dev/null; then
        awk -F'|' '{print $2}' "$TMPDIR_WORK/candidates" | \
            xargs -P "$PARALLEL_JOBS" -I{} "$HASH_SCRIPT" "{}" > "$HASH_FILE" 2>/dev/null
    else
        while IFS='|' read -r size filepath; do
            local hash=""
            if $USE_CACHE; then
                if get_cached_hash "$filepath" >> "$HASH_FILE"; then
                    hashed=$((hashed + 1))
                    if ! $QUIET && [ $((hashed % 50)) -eq 0 ]; then
                        show_progress "$hashed" "$candidates" "Calculando hashes"
                    fi
                    continue
                fi
            fi

            hash=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')
            if [ -n "$hash" ]; then
                if $USE_CACHE; then
                    save_cached_hash "$filepath" "$hash"
                fi
                echo "${hash}|${size}|${filepath}" >> "$HASH_FILE"
            fi
            hashed=$((hashed + 1))
            if ! $QUIET && [ $((hashed % 50)) -eq 0 ]; then
                show_progress "$hashed" "$candidates" "Calculando hashes"
            fi
        done < "$TMPDIR_WORK/candidates"
    fi

    unset HDC_CACHE_ENABLED HDC_CACHE_DIR

    if ! $QUIET; then
        echo -e "\r  Calculando hashes... ${GREEN}feito${RESET}                                       "
        echo ""
    fi

    awk -F'|' '{print $1}' "$HASH_FILE" | sort | uniq -d > "$TMPDIR_WORK/dup_hashes"

    if [ ! -s "$TMPDIR_WORK/dup_hashes" ]; then
        if ! $QUIET; then
            echo -e "  ${GREEN}Nenhuma duplicata encontrada.${RESET}"
            echo ""
        fi
        return 1
    fi

    if ! $QUIET; then
        echo -e "  ${BOLD}Duplicatas encontradas:${RESET}"
        echo ""
    fi

    local group_num=0
    local total_dup_files=0
    local total_recoverable=0
    local trashed_count=0
    local deleted_count=0
    local linked_count=0
    local hardlink_count=0
    local json_groups=""
    > "$TMPDIR_WORK/csv_data"

    while read -r dup_hash; do
        local group_lines
        group_lines=$(awk -F'|' -v h="$dup_hash" '$1 == h' "$HASH_FILE")

        local copies
        copies=$(echo "$group_lines" | wc -l | tr -d ' ')

        if [ "$THRESHOLD" -gt 0 ] && [ "$copies" -lt "$THRESHOLD" ]; then
            continue
        fi

        local first_filepath=""
        local is_all_hardlinks=true
        while IFS='|' read -r _ _ filepath; do
            if [ -z "$first_filepath" ]; then
                first_filepath="$filepath"
            else
                if ! is_hardlink "$first_filepath" "$filepath"; then
                    is_all_hardlinks=false
                    break
                fi
            fi
        done <<< "$group_lines"

        if $is_all_hardlinks && [ "$copies" -gt 1 ]; then
            hardlink_count=$((hardlink_count + copies))
            if ! $QUIET; then
                echo -e "  ${DIM}Grupo hardlink (mesmo inode) — $copies links — SHA-256: ${dup_hash:0:16}...${RESET}"
                while IFS='|' read -r _ _ filepath; do
                    echo -e "    ${CYAN}${filepath/$HOME/\~}${RESET} ${DIM}(hardlink)${RESET}"
                done <<< "$group_lines"
                echo ""
            fi
            continue
        fi

        group_num=$((group_num + 1))

        local keeper_line
        if $INTERACTIVE; then
            keeper_line=$(interactive_pick "$group_lines" "$group_num")
        else
            keeper_line=$(pick_keeper "$group_lines" "$KEEP_MODE")
        fi

        local keeper_filepath
        keeper_filepath=$(echo "$keeper_line" | awk -F'|' '{print $3}')
        local first_size
        first_size=$(echo "$group_lines" | head -1 | awk -F'|' '{print $2}')
        local recoverable=$((first_size * (copies - 1)))
        total_recoverable=$((total_recoverable + recoverable))
        total_dup_files=$((total_dup_files + copies))

        if ! $QUIET; then
            echo -e "  ${YELLOW}Grupo $group_num${RESET} — $copies copias — ${RED}$(human_size "$recoverable")${RESET} recuperaveis"
            echo -e "  ${DIM}SHA-256: ${dup_hash:0:16}...${RESET}"
        fi

        local action="list"
        if $USE_TRASH; then action="trash"
        elif $USE_DELETE; then action="delete"
        elif $USE_SOFT_LINK; then action="softlink"
        fi

        while IFS='|' read -r hash size filepath; do
            if ! $QUIET; then
                if [ "$filepath" = "$keeper_filepath" ]; then
                    echo -e "    ${GREEN}${filepath/$HOME/\~}${RESET} ${DIM}(mantido)${RESET}"
                else
                    resolve_action "$filepath" "$action" "$keeper_filepath"
                    case "$action" in
                        trash) trashed_count=$((trashed_count + 1)) ;;
                        delete) deleted_count=$((deleted_count + 1)) ;;
                        softlink) linked_count=$((linked_count + 1)) ;;
                    esac
                fi
            else
                if [ "$filepath" != "$keeper_filepath" ]; then
                    resolve_action "$filepath" "$action" "$keeper_filepath" >/dev/null 2>&1
                    case "$action" in
                        trash) trashed_count=$((trashed_count + 1)) ;;
                        delete) deleted_count=$((deleted_count + 1)) ;;
                        softlink) linked_count=$((linked_count + 1)) ;;
                    esac
                fi
            fi

            if [ -n "$OUTPUT_FILE" ]; then
                local is_kept="false"
                [ "$filepath" = "$keeper_filepath" ] && is_kept="true"
                echo "${dup_hash}|${group_num}|${filepath}|${size}|${is_kept}" >> "$TMPDIR_WORK/csv_data"
            fi
        done <<< "$group_lines"

        if ! $QUIET; then
            echo ""
        fi
    done < "$TMPDIR_WORK/dup_hashes"

    if [ -n "$OUTPUT_FILE" ]; then
        local ext="${OUTPUT_FILE##*.}"
        case "$ext" in
            json)
                {
                    echo "{"
                    echo "  \"version\": \"$VERSION\","
                    echo "  \"target\": \"$TARGET\","
                    echo "  \"total_files_scanned\": $total_files,"
                    echo "  \"groups\": ["
                    local first_group=true
                    while IFS='|' read -r dhash gnum dpath dsize diskept; do
                        if [ -n "$dpath" ]; then
                            echo "    {\"hash\": \"$dhash\", \"group\": $gnum, \"path\": \"$dpath\", \"size\": $dsize, \"kept\": $diskept},"
                        fi
                    done < "$TMPDIR_WORK/csv_data" | sed '$ s/,$//'
                    echo "  ],"
                    echo "  \"summary\": {"
                    echo "    \"duplicate_groups\": $group_num,"
                    echo "    \"duplicate_files\": $total_dup_files,"
                    echo "    \"recoverable_bytes\": $total_recoverable,"
                    echo "    \"hardlink_groups\": $hardlink_count"
                    echo "  }"
                    echo "}"
                } > "$OUTPUT_FILE"
                ;;
            *)
                {
                    echo "hash,group,filepath,size,kept"
                    while IFS='|' read -r dhash gnum dpath dsize diskept; do
                        [ -n "$dpath" ] && echo "$dhash,$gnum,\"$dpath\",$dsize,$diskept"
                    done < "$TMPDIR_WORK/csv_data"
                } > "$OUTPUT_FILE"
                ;;
        esac
        if ! $QUIET; then
            echo -e "  ${GREEN}Resultados exportados para: $OUTPUT_FILE${RESET}"
        fi
    fi

    if ! $QUIET || [ "$group_num" -gt 0 ]; then
        echo "  ─────────────────────────────────"
        echo -e "  ${BOLD}Resumo:${RESET}"
        echo -e "  Arquivos escaneados:  ${BOLD}$total_files${RESET}"
        echo -e "  Grupos de duplicatas: ${BOLD}$group_num${RESET}"
        echo -e "  Arquivos duplicados:  ${BOLD}$total_dup_files${RESET}"
        echo -e "  Hardlinks detectados: ${BOLD}$hardlink_count${RESET}"
        echo -e "  Espaco recuperavel:   ${RED}${BOLD}$(human_size "$total_recoverable")${RESET}"

        if $USE_TRASH; then
            echo -e "  Movidos para lixeira: ${YELLOW}${BOLD}${trashed_count}${RESET}"
            echo -e "  ${DIM}Restaure com: gio trash --restore ou via gerenciador de arquivos${RESET}"
        elif $USE_DELETE; then
            echo -e "  Deletados permanentemente: ${RED}${BOLD}${deleted_count}${RESET}"
        elif $USE_SOFT_LINK; then
            echo -e "  Substituidos por symlink: ${CYAN}${BOLD}${linked_count}${RESET}"
        else
            echo -e "  ${DIM}Nenhum arquivo foi deletado. Use --trash, --delete ou --soft-link.${RESET}"
            echo -e "  ${DIM}Revise a lista acima e delete manualmente se necessario.${RESET}"
        fi

        echo "  ─────────────────────────────────"
        echo ""
    fi
}

if $WATCH_MODE; then
    if ! $QUIET; then
        echo -e "  ${CYAN}Modo watch ativo${RESET} — monitorando $TARGET..."
        echo -e "  ${DIM}Pressione Ctrl+C para sair${RESET}"
        echo ""
    fi
    while true; do
        run_scan
        if ! $QUIET; then
            echo -e "  ${DIM}Aguardando alteracoes...${RESET}"
            echo ""
        fi
        inotifywait -q -r -e modify,create,move \
            --exclude "\.git|node_modules|\.venv|venv|__pycache__" \
            "$TARGET" 2>/dev/null || sleep 5
    done
else
    run_scan
fi