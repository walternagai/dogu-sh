#!/bin/bash
# dir-summary.sh — Resumo de diretorio: conta arquivos, tipos e tamanho (Linux)
# Uso: ./dir-summary.sh [opcoes] [diretorio]
# Opcoes:
#   --all|-a        Inclui arquivos ocultos (.*)
#   --sort|-s TYPE  Ordena por: size (padrao), count, name
#   --top|-t N      Mostra apenas os N maiores tipos (padrao: 10)
#   --human|-h      Tamanhos em formato humano (padrao)
#   --bytes|-b      Tamanhos em bytes
#   --help          Mostra esta ajuda
#   --version       Mostra versao

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

format_size() {
    local size="$1"
    if [[ "$HUMAN_READABLE" == true ]]; then
        if command -v numfmt &>/dev/null; then
            numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B"
        else
            # Fallback manual
            if [[ $size -ge 1099511627776 ]]; then
                printf "%.2fTB" $(echo "scale=2; $size/1099511627776" | bc 2>/dev/null || echo "0")
            elif [[ $size -ge 1073741824 ]]; then
                printf "%.2fGB" $(echo "scale=2; $size/1073741824" | bc 2>/dev/null || echo "0")
            elif [[ $size -ge 1048576 ]]; then
                printf "%.2fMB" $(echo "scale=2; $size/1048576" | bc 2>/dev/null || echo "0")
            elif [[ $size -ge 1024 ]]; then
                printf "%.2fKB" $(echo "scale=2; $size/1024" | bc 2>/dev/null || echo "0")
            else
                echo "${size}B"
            fi
        fi
    else
        echo "$size"
    fi
}

# Valores padrao
INCLUDE_HIDDEN=false
SORT_BY="size"
TOP_N=10
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
            echo "    --human|-h      Tamanhos em formato humano (padrao)"
            echo "    --bytes|-b      Tamanhos em bytes"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./dir-summary.sh                  Resumo do diretorio atual"
            echo "    ./dir-summary.sh ~/Downloads      Resumo do diretorio Downloads"
            echo "    ./dir-summary.sh -a /var/log      Inclui arquivos ocultos"
            echo "    ./dir-summary.sh -s count -t 5    Top 5 por quantidade de arquivos"
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

# Verifica se o diretorio existe
if [[ ! -d "$TARGET_DIR" ]]; then
    error "Diretorio nao encontrado: $TARGET_DIR"
fi

# Resolve caminho absoluto
TARGET_DIR=$(cd "$TARGET_DIR" && pwd)

echo ""
echo -e "  ${CYAN}${BOLD}dir-summary.sh${RESET} — Analise de: ${BOLD}$TARGET_DIR${RESET}"
echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Monta o comando find
FIND_CMD="find \"$TARGET_DIR\" -type f"
if [[ "$INCLUDE_HIDDEN" == false ]]; then
    FIND_CMD="$FIND_CMD -not -path '*/\.*'"
fi
FIND_CMD="$FIND_CMD 2>/dev/null"

# Conta arquivos totais
log "Contando arquivos..."
TOTAL_FILES=$(eval "$FIND_CMD" | wc -l)

if [[ "$TOTAL_FILES" -eq 0 ]]; then
    warn "Nenhum arquivo encontrado no diretorio."
    exit 0
fi

# Coleta dados por extensao
log "Analisando tipos de arquivos..."

TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

eval "$FIND_CMD" | while read -r file; do
    # Extrai extensao (parte apos o ultimo ponto), ignora arquivos ocultos
    basename=$(basename "$file")
    if [[ "$basename" =~ ^\. ]]; then
        # Arquivo oculto - pega extensao apos o primeiro ponto
        if [[ "$basename" =~ \. ]] && [[ "$basename" != "${basename#*.}" ]]; then
            ext="${basename#*.}"
            ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
            # Se nao sobrou nada, e um arquivo oculto sem extensao real
            [[ -z "$ext" ]] && ext="[sem_extensao]"
        else
            ext="[sem_extensao]"
        fi
    elif [[ "$file" =~ \. ]]; then
        ext="${file##*.}"
        ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    else
        ext="[sem_extensao]"
    fi
    
    # Pega o tamanho
    size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    
    echo "$ext $size" >> "$TMPFILE"
done

# Verifica se tem bc para calculos
if ! command -v bc &>/dev/null && [[ "$HUMAN_READABLE" == true ]]; then
    warn "bc nao encontrado. Tamanhos podem estar imprecisos."
fi

# Processa os dados coletados
log "Processando estatisticas..."

declare -A ext_count
declare -A ext_size

while read -r line; do
    read -r ext size <<< "$line"
    ext_count["$ext"]=$((${ext_count["$ext"]:-0} + 1))
    ext_size["$ext"]=$((${ext_size["$ext"]:-0} + size))
done < "$TMPFILE"

TOTAL_SIZE=0
for ext in "${!ext_size[@]}"; do
    TOTAL_SIZE=$((TOTAL_SIZE + ext_size["$ext"]))
done

# Exibe resumo geral
echo ""
echo -e "  ${CYAN}${BOLD}Resumo Geral${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
printf "  %-25s %s\n" "Total de arquivos:" "${BOLD}$TOTAL_FILES${RESET}"
printf "  %-25s %s\n" "Tamanho total:" "${BOLD}$(format_size $TOTAL_SIZE)${RESET}"
printf "  %-25s %s\n" "Tipos de arquivo:" "${BOLD}${#ext_count[@]}${RESET}"
echo ""

# Prepara dados para ordenacao
TMP_SORT=$(mktemp)
trap 'rm -f "$TMPFILE" "$TMP_SORT"' EXIT

for ext in "${!ext_count[@]}"; do
    count=${ext_count["$ext"]}
    size=${ext_size["$ext"]}
    printf "%s\t%s\t%s\n" "$ext" "$count" "$size" >> "$TMP_SORT"
done

# Ordena conforme solicitado
echo -e "  ${CYAN}${BOLD}Distribuicao por Tipo${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""

printf "  %-4s %-12s %10s %15s\n" "RANK" "EXTENSAO" "ARQUIVOS" "TAMANHO"
echo -e "  ${DIM}──── ──────────── ────────── ───────────────${RESET}"

case "$SORT_BY" in
    count)
        sort_cmd="sort -t$'\t' -k2 -nr"
        ;;
    name)
        sort_cmd="sort -t$'\t' -k1"
        ;;
    size|*)
        sort_cmd="sort -t$'\t' -k3 -nr"
        ;;
esac

RANK=1
while IFS=$'\t' read -r ext count size && [[ $RANK -le $TOP_N ]]; do
    ext_display="$ext"
    [[ ${#ext} -gt 12 ]] && ext_display="${ext:0:9}..."

    printf "  %-4s %-12s %10s %15s\n" \
        "#$RANK" \
        "$ext_display" \
        "$count" \
        "$(format_size $size)"

    RANK=$((RANK + 1))
done < <(eval "$sort_cmd" < "$TMP_SORT")

# Mostra info se houve limitacao
TOTAL_TYPES=${#ext_count[@]}
if [[ $TOP_N -lt $TOTAL_TYPES ]]; then
    echo ""
    echo -e "  ${DIM}... e mais $((TOTAL_TYPES - TOP_N)) tipos (use -t N para ver mais)${RESET}"
fi

echo ""
