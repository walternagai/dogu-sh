#!/bin/bash
# dedup-files.sh — Compara varios arquivos e remove duplicados (Linux)
# Uso: ./dedup-files.sh [opcoes] [DIRETORIO]
# Padrao: diretorio atual (recursivo), apenas lista duplicados
# Opcoes:
#   --delete             Remove duplicados (sem esta flag, apenas reporta)
#   --keep=STRAT         Estrategia de selecao: first | oldest | newest | largestpath [padrao: first]
#   --min-size=N         Tamanho minimo em bytes [padrao: 1]
#   --exclude-dir=LISTA  Diretorios extras a ignorar, separados por virgula
#   --include-hidden     Incluir arquivos e diretorios ocultos
#   --help               Mostra esta ajuda
#   --version            Mostra versao
#
# Algoritmo em estagios (barato -> caro), sem comparacoes exponenciais ou O(N^2):
#   Fase 1: inode       — hardlinks (mesmo inode) nunca sao re-avaliados. O(N)
#   Fase 2: tamanho     — tamanhos unicos saem da analise na hora. O(N)
#   Fase 3: 1o chunk    — hash parcial (4096 B) descarta a maioria. O(C3)
#   Fase 4: SHA-256     — hash completo so nos candidatos restantes. O(C4)
#   Fase 5: cmp         — byte-a-byte dentro do grupo do mesmo hash. O(C5)
# Cada fase so roda sobre os candidatos da fase anterior; o custo total se
# aproxima de O(N). Uma colisao de hash (fase 4) e detectada na fase 5 e NAO
# e removida — apenas reportada.

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "find" "$INSTALLER" "findutils"
    check_and_install "sha256sum" "$INSTALLER" "coreutils"
    check_and_install "cmp" "$INSTALLER" "diffutils"
fi

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

readonly HASH_PROBE_BYTES=4096
readonly PROGRESS_EVERY=2000

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

# ── Parsing de argumentos ─────────────────────────────────────────────────────
TARGET_DIR=""
DRY_RUN=true
KEEP_STRATEGY="first"
MIN_SIZE=1
EXTRA_EXCLUDES=""
INCLUDE_HIDDEN=false

show_help() {
    sed -n '2,/^set -euo/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --delete|-d)
            DRY_RUN=false; shift ;;
        --keep)
            [[ -z "${2-}" ]] && error "Flag --keep requer um valor"
            case "$2" in
                first|oldest|newest|largestpath) KEEP_STRATEGY="$2" ;;
                *) error "Estrategia invalida: $2 (use first, oldest, newest ou largestpath)" ;;
            esac
            shift 2 ;;
        --keep=*)
            case "${1#*=}" in
                first|oldest|newest|largestpath) KEEP_STRATEGY="${1#*=}" ;;
                *) error "Estrategia invalida: ${1#*=} (use first, oldest, newest ou largestpath)" ;;
            esac
            shift ;;
        --min-size)
            [[ -z "${2-}" ]] && error "Flag --min-size requer um valor"
            [[ "$2" =~ ^[0-9]+$ ]] || error "--min-size exige inteiro nao negativo"
            MIN_SIZE="$2"; shift 2 ;;
        --min-size=*)
            [[ "${1#*=}" =~ ^[0-9]+$ ]] || error "--min-size exige inteiro nao negativo"
            MIN_SIZE="${1#*=}"; shift ;;
        --exclude-dir)
            [[ -z "${2-}" ]] && error "Flag --exclude-dir requer um valor"
            EXTRA_EXCLUDES="$2"; shift 2 ;;
        --exclude-dir=*) EXTRA_EXCLUDES="${1#*=}"; shift ;;
        --include-hidden) INCLUDE_HIDDEN=true; shift ;;
        --help|-h)
            show_help
            exit 0 ;;
        --version|-V) echo "dedup-files.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
        *)
            [[ -n "$TARGET_DIR" ]] && { echo -e "${RED}Argumento inesperado: $1${RESET}" >&2; exit 2; }
            TARGET_DIR="$1"; shift ;;
    esac
done
# Argumentos apos '--' (posicionais)
while [[ $# -gt 0 ]]; do
    [[ -n "$TARGET_DIR" ]] && { echo -e "${RED}Argumento inesperado: $1${RESET}" >&2; exit 2; }
    TARGET_DIR="$1"; shift
done
TARGET_DIR="${TARGET_DIR:-.}"

[[ -d "$TARGET_DIR" ]] || error "Diretorio nao encontrado: $TARGET_DIR"
[[ -r "$TARGET_DIR" ]] || error "Diretorio sem permissao de leitura: $TARGET_DIR"

# Paths vindos de find podem conter glob chars; desativa globbing para
# permitir expansao NAO-quotation com delimitador 0x1f nos grupos.
set -f

# ── Excludes ──────────────────────────────────────────────────────────────────
readonly -a BASE_EXCLUDES=(proc sys dev run tmp .git node_modules .venv venv __pycache__ .cache)
EXCLUDES=("${BASE_EXCLUDES[@]}")
if [[ -n "$EXTRA_EXCLUDES" ]]; then
    IFS=',' read -r -a _extra_arr <<< "$EXTRA_EXCLUDES"
    for _e in "${_extra_arr[@]}"; do
        _e="${_e#"${_e%%[![:space:]]*}"}"; _e="${_e%"${_e##*[![:space:]]}"}"
        [[ -n "$_e" ]] && EXCLUDES+=("$_e")
    done
fi

# ── Temporarios ───────────────────────────────────────────────────────────────
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT
trap 'exit 130' INT

HARDLINK_DUPS="$TMPDIR_WORK/hardlinks.tsv"
DUP_REPORT="$TMPDIR_WORK/duplicates.tsv"
: > "$HARDLINK_DUPS"
: > "$DUP_REPORT"

# ── Util ──────────────────────────────────────────────────────────────────────
human_size() {
    local b=$1
    if   (( b >= 1073741824 )); then awk -v n="$b" 'BEGIN{printf "%.1f GB", n/1073741824}'
    elif (( b >= 1048576    )); then awk -v n="$b" 'BEGIN{printf "%.1f MB", n/1048576}'
    elif (( b >= 1024       )); then awk -v n="$b" 'BEGIN{printf "%.1f KB", n/1024}'
    else printf '%d B' "$b"; fi
}

# Hash parcial: primeiros HASH_PROBE_BYTES bytes do arquivo
partial_hash() {
    sha256sum < <(head -c "$HASH_PROBE_BYTES" -- "$1" 2>/dev/null) | awk '{print $1}'
}

# Recebe paths via stdin (um por linha) e os ordena conforme KEEP_STRATEGY.
# A primeira linha do resultado e o arquivo a ser mantido.
order_group() {
    case "$KEEP_STRATEGY" in
        first) cat ;;
        oldest)  while IFS= read -r f; do
                     [[ -n "$f" ]] || continue
                     printf '%s\t%s\n' "$(stat -c %Y -- "$f" 2>/dev/null || echo 0)" "$f"
                 done | sort -n -k1,1 | cut -f2- ;;
        newest)  while IFS= read -r f; do
                     [[ -n "$f" ]] || continue
                     printf '%s\t%s\n' "$(stat -c %Y -- "$f" 2>/dev/null || echo 0)" "$f"
                 done | sort -rn -k1,1 | cut -f2- ;;
        largestpath) awk '{ print length($0) "\t" $0 }' | sort -rn -k1,1 | cut -f2- ;;
    esac
}

# Processa um grupo final confirmado (fase 5).
# $1 = tamanho; stdin = paths (um por linha), todos com mesmo SHA-256.
process_group() {
    local size=$1
    local -a files=()
    mapfile -t files
    (( ${#files[@]} >= 2 )) || return 0

    local -a ordered=()
    mapfile -t ordered < <(printf '%s\n' "${files[@]}" | order_group)
    local keep="${ordered[0]}"
    local i f
    for (( i=1; i<${#ordered[@]}; i++ )); do
        f="${ordered[$i]}"
        # Verificacao byte-a-byte final contra o mantido (pega colisao de hash)
        if ! cmp -s -- "$keep" "$f"; then
            warn "Colisao de hash detectada (nao removido): $f"
            continue
        fi
        printf '%s\t%s\t%s\n' "$f" "$size" "$keep" >> "$DUP_REPORT"
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "  ${DIM}[Dry-run] rm $f${RESET}"
        else
            rm -f -- "$f"
            log "  ✓ Removido: $f"
        fi
    done
}

# ── Fases 1+2: coleta (inode) e agrupamento por tamanho ──────────────────────
declare -A INODE_SEEN=()
declare -A SIZE_MAP=()   # size -> paths delimitados por 0x1f

scan_files() {
    local total=0 hardlinks=0
    # NOTA: -printf e uma action do find e executa na ordem da expressao;
    # ela deve vir DEPOIS de todos os filtros, senao o filtro e ignorado.
    local -a find_args=(-type f -xdev)
    (( MIN_SIZE > 1 )) && find_args+=(-size +"$((MIN_SIZE - 1))c")
    [[ "$INCLUDE_HIDDEN" == false ]] && find_args+=(-not -path '*/.*')
    local d
    for d in "${EXCLUDES[@]}"; do
        find_args+=(-not -path "*/$d" -not -path "*/$d/*" -not -name "$d")
    done
    find_args+=(-printf '%s\t%T@\t%i\t%p\0')

    local rec size mtime inode path rest
    while IFS=$'\t' read -r -d '' size mtime inode path; do
        total=$((total + 1))
        if (( total % PROGRESS_EVERY == 0 )); then
            log "  ... $total arquivos analisados"
        fi

        # Fase 1: hardlink — mesmo inode implica mesmo conteudo. Mantem o 1o path.
        if [[ -n "${INODE_SEEN[$inode]:-}" ]]; then
            hardlinks=$((hardlinks + 1))
            printf '%s\t%s\t%s\n' "$path" "$size" "${INODE_SEEN[$inode]}" >> "$HARDLINK_DUPS"
            continue
        fi
        INODE_SEEN["$inode"]="$path"

        # Fase 2: agrupa por tamanho exato
        if [[ -n "${SIZE_MAP[$size]:-}" ]]; then
            SIZE_MAP["$size"]+=$'\x1f'"$path"
        else
            SIZE_MAP["$size"]="$path"
        fi
    done < <(find "$TARGET_DIR" "${find_args[@]}" 2>/dev/null)

    SCANNED_TOTAL=$total
    HARDLINK_TOTAL=$hardlinks
}

# ── Fluxo principal ───────────────────────────────────────────────────────────
main() {
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}dedup-files.sh — remoção segura de duplicados${RESET}"
    echo -e "  ${DIM}Alvo: $TARGET_DIR  |  --keep=$KEEP_STRATEGY  |  Modo: $([[ "$DRY_RUN" == true ]] && echo 'dry-run (apenas listar)' || echo 'DELETE')${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

    # Confirmacao para operacao destrutiva (§5 do guia: guard [ -t 0 ])
    if [[ "$DRY_RUN" == false ]]; then
        if [ -t 0 ]; then
            read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        else
            error "Execucao nao interativa detectada. Rode em terminal interativo (TTY) para confirmar --delete."
        fi
        if [[ ! "$confirm" =~ ^[Ss]$ ]]; then
            echo -e "${DIM}Operação cancelada.${RESET}"
            exit 0
        fi
    fi

    SCANNED_TOTAL=0
    HARDLINK_TOTAL=0

    log "Fases 1-2: varredura, filtro de hardlinks e agrupamento por tamanho..."
    scan_files
    log "  ${SCANNED_TOTAL} arquivo(s) varrido(s), ${HARDLINK_TOTAL} hardlink(s) já idêntico(s) (mesmo inode)"

    log "Fases 3-5: refinamento com hash parcial → SHA-256 → comparação byte-a-byte..."
    local size f h key paths
    local -a candidates=()
    local -A PHASH_MAP=()
    local -A FULL_MAP=()
    local n_groups=0

    for size in "${!SIZE_MAP[@]}"; do
        paths="${SIZE_MAP[$size]}"
        # Tamanho único ⇒ impossível haver duplicata
        [[ "$paths" == *$'\x1f'* ]] || continue

        # ── Fase 3: hash parcial do primeiro chunk
        PHASH_MAP=()
        local IFS=$'\x1f'
        for f in $paths; do
            [[ -f "$f" && -r "$f" ]] || { warn "Ignorando (ilegível/desaparecido): $f"; continue; }
            h=$(partial_hash "$f")
            if [[ -n "${PHASH_MAP[$h]:-}" ]]; then
                PHASH_MAP["$h"]+=$'\x1f'"$f"
            else
                PHASH_MAP["$h"]="$f"
            fi
        done

        # ── Fase 4: SHA-256 completo apenas nos subgrupos restantes
        for h in "${!PHASH_MAP[@]}"; do
            paths="${PHASH_MAP[$h]}"
            [[ "$paths" == *$'\x1f'* ]] || continue
            FULL_MAP=()
            for f in $paths; do
                [[ -f "$f" && -r "$f" ]] || { warn "Ignorando (ilegível/desaparecido): $f"; continue; }
                key=$(sha256sum -- "$f" 2>/dev/null | awk '{print $1}') || { warn "Falha ao hashear: $f"; continue; }
                if [[ -n "${FULL_MAP[$key]:-}" ]]; then
                    FULL_MAP["$key"]+=$'\x1f'"$f"
                else
                    FULL_MAP["$key"]="$f"
                fi
            done

            # ── Fase 5: cmp byte-a-byte e remoção/registro
            for key in "${!FULL_MAP[@]}"; do
                paths="${FULL_MAP[$key]}"
                [[ "$paths" == *$'\x1f'* ]] || continue
                local IFS=$'\x1f'
                # shellcheck disable=SC2206  # split intencional no delimitador 0x1f
                candidates=($paths)
                printf '%s\n' "${candidates[@]}" | process_group "$size"
                n_groups=$((n_groups + 1))
            done
        done
    done

    # ── Resumo ────────────────────────────────────────────────────────────────
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    local dup_count=0 freed_bytes=0
    local dup_count_tmp=0 freed_tmp=0
    while IFS=$'\t' read -r _ sz _; do
        dup_count_tmp=$((dup_count_tmp + 1))
        freed_tmp=$((freed_tmp + sz))
    done < "$DUP_REPORT"
    dup_count=$dup_count_tmp
    freed_bytes=$freed_tmp

    if (( dup_count == 0 )); then
        success "Nenhum arquivo duplicado encontrado (${n_groups} grupo(s) verificado(s))."
    else
        if [[ "$DRY_RUN" == true ]]; then
            success "$dup_count duplicado(s) encontrado(s) em ${n_groups} grupo(s) — espaço recuperável: $(human_size "$freed_bytes")"
            echo -e "  ${DIM}Rode com --delete para removê-los.${RESET}"
        else
            success "$dup_count duplicado(s) removido(s) em ${n_groups} grupo(s) — espaço liberado: $(human_size "$freed_bytes")"
        fi
    fi
    if (( HARDLINK_TOTAL > 0 )); then
        warn "$HARDLINK_TOTAL hardlink(s) adicional(is) apontando para o mesmo conteúdo (nada a fazer)."
    fi
}

main "$@"