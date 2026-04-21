#!/bin/bash
# dir-summary.sh — Resumo de diretorio: conta arquivos, tipos e tamanho (Linux)
# Uso: ./dir-summary.sh [opcoes] [diretorio]
# Opcoes:
#   --all|-a        Inclui arquivos ocultos (.*)
#   --sort|-s TYPE  Ordena por: size (padrao), count, name
#   --top|-t N      Mostra apenas os N maiores tipos (padrao: 10)
#   --deep|-d N     Mostra os N maiores arquivos (padrao: 5, 0=desativa)
#   --depth|-D N    Profundidade de subdiretorios (padrao: 1, 0=desativa)
#   --age|-A        Mostra distribuicao por idade dos arquivos
#   --human|-h      Tamanhos em formato humano (padrao)
#   --bytes|-b      Tamanhos em bytes
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="2.0.0"
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

format_size() {
    local size="$1"
    if [[ "$HUMAN_READABLE" == true ]]; then
        if command -v numfmt &>/dev/null; then
            numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B"
        else
            if [[ $size -ge 1099511627776 ]]; then
                printf "%.2fTB" "$(echo "scale=2; $size/1099511627776" | bc 2>/dev/null || echo "0")"
            elif [[ $size -ge 1073741824 ]]; then
                printf "%.2fGB" "$(echo "scale=2; $size/1073741824" | bc 2>/dev/null || echo "0")"
            elif [[ $size -ge 1048576 ]]; then
                printf "%.2fMB" "$(echo "scale=2; $size/1048576" | bc 2>/dev/null || echo "0")"
            elif [[ $size -ge 1024 ]]; then
                printf "%.2fKB" "$(echo "scale=2; $size/1024" | bc 2>/dev/null || echo "0")"
            else
                echo "${size}B"
            fi
        fi
    else
        echo "$size"
    fi
}

draw_bar() {
    local pct="$1"
    local width="${2:-15}"
    local filled=$(( (pct * width) / 100 ))
    (( filled > width )) && filled=$width
    (( filled < 0 )) && filled=0
    local empty=$((width - filled))
    local bar_filled="" bar_empty="" i
    for ((i=0; i<filled; i++)); do bar_filled="${bar_filled}█"; done
    for ((i=0; i<empty; i++)); do bar_empty="${bar_empty}░"; done
    echo -e "${GREEN}${bar_filled}${DIM}${bar_empty}${RESET}"
}

INCLUDE_HIDDEN=false
SORT_BY="size"
TOP_N=10
DEEP_N=5
DEPTH_N=1
SHOW_AGE=false
HUMAN_READABLE=true
TARGET_DIR="."

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all|-a) INCLUDE_HIDDEN=true; shift ;;
        --sort|-s)
            [[ -z "${2-}" ]] && error "Flag --sort requer um valor (size, count, name)"
            SORT_BY="$2"; shift 2 ;;
        --top|-t)
            [[ -z "${2-}" ]] && error "Flag --top requer um valor numerico"
            TOP_N="$2"; shift 2 ;;
        --deep|-d)
            [[ -z "${2-}" ]] && error "Flag --deep requer um valor numerico"
            DEEP_N="$2"; shift 2 ;;
        --depth|-D)
            [[ -z "${2-}" ]] && error "Flag --depth requer um valor numerico"
            DEPTH_N="$2"; shift 2 ;;
        --age|-A) SHOW_AGE=true; shift ;;
        --human|-h) HUMAN_READABLE=true; shift ;;
        --bytes|-b) HUMAN_READABLE=false; shift ;;
        --help|-h)
            echo ""
            echo "  dir-summary.sh — Resumo de diretorio: conta arquivos, tipos e tamanho"
            echo ""
            echo "  Uso: ./dir-summary.sh [opcoes] [diretorio]"
            echo ""
            echo "  Opcoes:"
            echo "    --all|-a        Inclui arquivos ocultos (.*)"
            echo "    --sort|-s TYPE  Ordena por: size (padrao), count, name"
            echo "    --top|-t N      Mostra apenas os N maiores tipos (padrao: 10)"
            echo "    --deep|-d N     Mostra os N maiores arquivos (padrao: 5, 0=desativa)"
            echo "    --depth|-D N    Profundidade de subdiretorios (padrao: 1, 0=desativa)"
            echo "    --age|-A        Mostra distribuicao por idade dos arquivos"
            echo "    --human|-h      Tamanhos em formato humano (padrao)"
            echo "    --bytes|-b      Tamanhos em bytes"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./dir-summary.sh                    Resumo do diretorio atual"
            echo "    ./dir-summary.sh ~/Downloads         Resumo do diretorio Downloads"
            echo "    ./dir-summary.sh -a /var/log         Inclui arquivos ocultos"
            echo "    ./dir-summary.sh -s count -t 5      Top 5 por quantidade de arquivos"
            echo "    ./dir-summary.sh -d 10 -A           Top 10 maiores arquivos + idade"
            echo "    ./dir-summary.sh -D 0                Sem breakdown de subdiretorios"
            echo ""
            exit 0
            ;;
        --version|-V) echo "dir-summary.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

if [[ ! -d "$TARGET_DIR" ]]; then
    error "Diretorio nao encontrado: $TARGET_DIR"
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo ""
echo -e "  ${CYAN}${BOLD}dir-summary.sh${RESET} — Analise de: ${BOLD}$TARGET_DIR${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

FIND_CMD="find \"$TARGET_DIR\" -type f"
if [[ "$INCLUDE_HIDDEN" == false ]]; then
    FIND_CMD="$FIND_CMD -not -path '*/\.*'"
fi
FIND_CMD="$FIND_CMD 2>/dev/null"

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

log "Coletando dados do diretorio..."

eval "$FIND_CMD" | while read -r file; do
    bname=$(basename "$file")
    if [[ "$bname" =~ ^\. ]]; then
        if [[ "$bname" =~ \. ]] && [[ "$bname" != "${bname#*.}" ]]; then
            ext="${bname#*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            [[ -z "$ext" ]] && ext="[sem_ext]"
        else
            ext="[sem_ext]"
        fi
    elif [[ "$bname" =~ \. ]]; then
        ext="${bname##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    else
        ext="[sem_ext]"
    fi

    read size mtime <<< "$(stat -c"%s %Y" "$file" 2>/dev/null || echo "0 0")"

    if [[ "$DEPTH_N" -gt 0 ]]; then
        rel="${file#$TARGET_DIR/}"
        dir_part=$(dirname "$rel")
        if [[ "$dir_part" == "." ]]; then
            subdir="[raiz]"
        else
            subdir=$(echo "$dir_part" | cut -d/ -f1-"$DEPTH_N")
        fi
    else
        subdir=""
    fi

    printf "%s\t%s\t%s\t%s\t%s\n" "$ext" "$size" "$file" "$mtime" "${subdir:-}" >> "$TMPFILE"
done

TOTAL_FILES=$(wc -l < "$TMPFILE")

if [[ "$TOTAL_FILES" -eq 0 ]]; then
    warn "Nenhum arquivo encontrado no diretorio."
    exit 0
fi

log "Processando estatisticas..."

declare -A ext_count
declare -A ext_size
declare -A subdir_count
declare -A subdir_size

TOTAL_SIZE=0
TOTAL_EMPTY=0
LARGEST_FILE=""
LARGEST_SIZE=0
SMALLEST_FILE=""
SMALLEST_SIZE=0
NOW=$(date +%s)

AGE_24H_COUNT=0; AGE_24H_SIZE=0
AGE_7D_COUNT=0;  AGE_7D_SIZE=0
AGE_30D_COUNT=0; AGE_30D_SIZE=0
AGE_90D_COUNT=0; AGE_90D_SIZE=0
AGE_OLDER_COUNT=0; AGE_OLDER_SIZE=0

while IFS=$'\t' read -r ext size file mtime subdir; do
    ext_count["$ext"]=$((${ext_count["$ext"]:-0} + 1))
    ext_size["$ext"]=$((${ext_size["$ext"]:-0} + size))

    TOTAL_SIZE=$((TOTAL_SIZE + size))

    if [[ "$size" -eq 0 ]]; then
        TOTAL_EMPTY=$((TOTAL_EMPTY + 1))
    fi

    if [[ "$size" -gt "$LARGEST_SIZE" ]]; then
        LARGEST_SIZE=$size
        LARGEST_FILE="$file"
    fi
    if [[ "$size" -gt 0 ]]; then
        if [[ "$SMALLEST_SIZE" -eq 0 ]] || [[ "$size" -lt "$SMALLEST_SIZE" ]]; then
            SMALLEST_SIZE=$size
            SMALLEST_FILE="$file"
        fi
    fi

    if [[ -n "$subdir" ]] && [[ "$DEPTH_N" -gt 0 ]]; then
        subdir_count["$subdir"]=$((${subdir_count["$subdir"]:-0} + 1))
        subdir_size["$subdir"]=$((${subdir_size["$subdir"]:-0} + size))
    fi

    if [[ "$SHOW_AGE" == true ]]; then
        age=$((NOW - mtime))
        if [[ $age -le 86400 ]]; then
            AGE_24H_COUNT=$((AGE_24H_COUNT + 1)); AGE_24H_SIZE=$((AGE_24H_SIZE + size))
        elif [[ $age -le 604800 ]]; then
            AGE_7D_COUNT=$((AGE_7D_COUNT + 1)); AGE_7D_SIZE=$((AGE_7D_SIZE + size))
        elif [[ $age -le 2592000 ]]; then
            AGE_30D_COUNT=$((AGE_30D_COUNT + 1)); AGE_30D_SIZE=$((AGE_30D_SIZE + size))
        elif [[ $age -le 7776000 ]]; then
            AGE_90D_COUNT=$((AGE_90D_COUNT + 1)); AGE_90D_SIZE=$((AGE_90D_SIZE + size))
        else
            AGE_OLDER_COUNT=$((AGE_OLDER_COUNT + 1)); AGE_OLDER_SIZE=$((AGE_OLDER_SIZE + size))
        fi
    fi
done < "$TMPFILE"

TOTAL_SUBDIRS=0
if [[ "$DEPTH_N" -gt 0 ]]; then
    TOTAL_SUBDIRS=$(find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
fi

echo ""
echo -e "  ${CYAN}${BOLD}Resumo Geral${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
printf "  %-25s %b\n" "Total de arquivos:" "${BOLD}${TOTAL_FILES}${RESET}"
printf "  %-25s %b\n" "Tamanho total:" "${BOLD}$(format_size $TOTAL_SIZE)${RESET}"
printf "  %-25s %b\n" "Tipos de arquivo:" "${BOLD}${#ext_count[@]}${RESET}"
if [[ "$TOTAL_SUBDIRS" -gt 0 ]]; then
    printf "  %-25s %b\n" "Subdiretorios:" "${BOLD}${TOTAL_SUBDIRS}${RESET}"
fi
AVG_SIZE=$((TOTAL_SIZE / TOTAL_FILES))
printf "  %-25s %b\n" "Tamanho medio:" "${BOLD}$(format_size $AVG_SIZE)${RESET}"
if [[ -n "$LARGEST_FILE" ]]; then
    largest_name=$(basename "$LARGEST_FILE")
    [[ ${#largest_name} -gt 28 ]] && largest_name="${largest_name:0:25}..."
    printf "  %-25s %b\n" "Maior arquivo:" "${BOLD}${largest_name}${RESET}  ${DIM}($(format_size $LARGEST_SIZE))${RESET}"
fi
if [[ -n "$SMALLEST_FILE" ]]; then
    smallest_name=$(basename "$SMALLEST_FILE")
    [[ ${#smallest_name} -gt 28 ]] && smallest_name="${smallest_name:0:25}..."
    printf "  %-25s %b\n" "Menor arquivo:" "${BOLD}${smallest_name}${RESET}  ${DIM}($(format_size $SMALLEST_SIZE))${RESET}"
fi
if [[ "$TOTAL_EMPTY" -gt 0 ]]; then
    printf "  %-25s %b\n" "Arquivos vazios:" "${YELLOW}${TOTAL_EMPTY}${RESET}"
fi
echo ""

# --- Distribuicao por Tipo ---

TMP_SORT=$(mktemp)
trap 'rm -f "$TMPFILE" "$TMP_SORT"' EXIT

for ext in "${!ext_count[@]}"; do
    count=${ext_count["$ext"]}
    size=${ext_size["$ext"]}
    printf "%s\t%s\t%s\n" "$ext" "$count" "$size" >> "$TMP_SORT"
done

echo -e "  ${CYAN}${BOLD}Distribuicao por Tipo${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""

printf "  %-4s %-12s %8s %10s  %-15s %5s\n" "RANK" "EXTENSAO" "ARQS" "TAMANHO" "DISTRIBUICAO" "%"
echo -e "  ${DIM}──── ──────────── ──────── ────────── ─────────────── ─────${RESET}"

case "$SORT_BY" in
    count) sort_cmd="sort -t\$'\\t' -k2 -nr" ;;
    name)  sort_cmd="sort -t\$'\\t' -k1" ;;
    *)     sort_cmd="sort -t\$'\\t' -k3 -nr" ;;
esac

RANK=1
while IFS=$'\t' read -r ext count size && [[ $RANK -le $TOP_N ]]; do
    ext_display="$ext"
    [[ ${#ext} -gt 12 ]] && ext_display="${ext:0:9}..."

    pct=0
    if [[ "$TOTAL_SIZE" -gt 0 ]]; then
        pct=$(( (size * 100) / TOTAL_SIZE ))
    fi

    bar=$(draw_bar "$pct" 15)

    printf "  %-4s %-12s %8s %10s  %b %3d%%\n" \
        "#$RANK" \
        "$ext_display" \
        "$count" \
        "$(format_size $size)" \
        "$bar" \
        "$pct"

    RANK=$((RANK + 1))
done < <(eval "$sort_cmd" < "$TMP_SORT")

TOTAL_TYPES=${#ext_count[@]}
if [[ $TOP_N -lt $TOTAL_TYPES ]]; then
    echo ""
    echo -e "  ${DIM}... e mais $((TOTAL_TYPES - TOP_N)) tipos (use -t N para ver mais)${RESET}"
fi

# --- Maiores Arquivos ---

if [[ "$DEEP_N" -gt 0 ]]; then
    echo ""
    echo -e "  ${CYAN}${BOLD}Maiores Arquivos${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    echo ""

    DEEP_RANK=1
    while IFS=$'\t' read -r ext size file mtime subdir && [[ $DEEP_RANK -le $DEEP_N ]]; do
        fname=$(basename "$file")
        if [[ ${#fname} -gt 38 ]]; then
            fname="${fname:0:35}..."
        fi
        printf "  %-4s %-38s %12s\n" \
            "#$DEEP_RANK" \
            "$fname" \
            "$(format_size $size)"
        DEEP_RANK=$((DEEP_RANK + 1))
    done < <(sort -t$'\t' -k2 -nr < "$TMPFILE" | head -n "$DEEP_N")
fi

# --- Subdiretorios ---

if [[ "$DEPTH_N" -gt 0 ]] && [[ ${#subdir_count[@]} -gt 0 ]]; then
    TMP_SUBS=$(mktemp)
    trap 'rm -f "$TMPFILE" "$TMP_SORT" "$TMP_SUBS"' EXIT

    for sd in "${!subdir_count[@]}"; do
        printf "%s\t%s\t%s\n" "$sd" "${subdir_count["$sd"]}" "${subdir_size["$sd"]}" >> "$TMP_SUBS"
    done

    echo ""
    echo -e "  ${CYAN}${BOLD}Subdiretorios${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    echo ""

    printf "  %-34s %6s %10s  %5s\n" "DIRETORIO" "ARQS" "TAMANHO" "%"
    echo -e "  ${DIM}────────────────────────────────── ────── ────────── ─────${RESET}"

    while IFS=$'\t' read -r sd sc ss && [[ -n "$sd" ]]; do
        sd_display="$sd"
        [[ ${#sd_display} -gt 34 ]] && sd_display="${sd_display:0:31}..."

        sd_pct=0
        if [[ "$TOTAL_SIZE" -gt 0 ]]; then
            sd_pct=$(( (ss * 100) / TOTAL_SIZE ))
        fi

        if [[ "$sd_pct" -ge 50 ]]; then
            sd_color="$RED"
        elif [[ "$sd_pct" -ge 25 ]]; then
            sd_color="$YELLOW"
        else
            sd_color="$GREEN"
        fi

        printf "  %-34s %6s %10s  %b%3d%%%b\n" \
            "$sd_display" \
            "$sc" \
            "$(format_size $ss)" \
            "$sd_color" "$sd_pct" "$RESET"
    done < <(sort -t$'\t' -k3 -nr < "$TMP_SUBS")
fi

# --- Idade dos Arquivos ---

if [[ "$SHOW_AGE" == true ]]; then
    echo ""
    echo -e "  ${CYAN}${BOLD}Idade dos Arquivos${RESET}"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    echo ""

    printf "  %-20s %10s %12s  %-15s %5s\n" "PERIODO" "ARQUIVOS" "TAMANHO" "DISTRIBUICAO" "%"
    echo -e "  ${DIM}──────────────────── ────────── ──────────── ─────────────── ─────${RESET}"

    print_age_row() {
        local label="$1" count="$2" asize="$3"
        local pct=0
        if [[ "$TOTAL_SIZE" -gt 0 ]]; then
            pct=$(( (asize * 100) / TOTAL_SIZE ))
        fi
        local bar
        bar=$(draw_bar "$pct" 15)
        printf "  %-20s %10s %12s  %b %3d%%\n" \
            "$label" "$count" "$(format_size $asize)" "$bar" "$pct"
    }

    print_age_row "Ultimas 24h"   "$AGE_24H_COUNT"    "$AGE_24H_SIZE"
    print_age_row "Ultima semana"  "$AGE_7D_COUNT"     "$AGE_7D_SIZE"
    print_age_row "Ultimo mes"     "$AGE_30D_COUNT"    "$AGE_30D_SIZE"
    print_age_row "Ultimos 3 meses" "$AGE_90D_COUNT"  "$AGE_90D_SIZE"
    print_age_row "Mais antigos"    "$AGE_OLDER_COUNT" "$AGE_OLDER_SIZE"
fi

echo ""