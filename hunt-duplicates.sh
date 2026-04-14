#!/bin/bash
# hunt-duplicates.sh — Find duplicate files by SHA-256 hash (Linux)
# Uso: ./hunt-duplicates.sh [pasta] [tamanho-minimo-bytes]
# Padrao: ~/  com minimo de 1 KB
# Opcoes:
#   --dry-run       Apenas lista, sem interacao (padrao ja e nao-destrutivo)
#   --trash         Move duplicatas para lixeira em vez de apenas listar
#   --help          Mostra esta ajuda
#   --version       Mostra versao
# Nenhum arquivo e deletado sem --trash.

set -eo pipefail

VERSION="1.1.0"

YELLOW='\033[1;33m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

USE_TRASH=false
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --trash)
            USE_TRASH=true
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
            echo "    --dry-run            Apenas lista (padrao)"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./hunt-duplicates.sh ~/Downloads"
            echo "    ./hunt-duplicates.sh --trash ~/Documents 2048"
            echo ""
            exit 0
            ;;
        --version|-v)
            echo "hunt-duplicates.sh $VERSION"
            exit 0
            ;;
        -*)
            echo "Opcao desconhecida: $1" >&2
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

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

SIZE_FILE="$TMPDIR_WORK/sizes"
HASH_FILE="$TMPDIR_WORK/hashes"

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

    local basename
    basename=$(basename "$filepath")
    local dest="$trash_dir/files/$basename"
    local n=1
    while [ -e "$dest" ]; do
        dest="$trash_dir/files/${basename} ($n)"
        n=$((n + 1))
    done

    mv "$filepath" "$dest"

    local info_file="$trash_dir/info/$(basename "$dest").trashinfo"
    cat > "$info_file" <<EOF
[Trash Info]
Path=$(realpath "$dest" 2>/dev/null || echo "$filepath")
DeletionDate=$(date '+%Y-%m-%dT%H:%M:%S')
EOF
}

echo ""
echo -e "  Escaneando ${BOLD}$TARGET${RESET}..."
echo -e "  ${DIM}(ignorando arquivos < $(human_size "$MIN_SIZE"))${RESET}"
echo ""

# Passo 1: Listar arquivos com tamanho usando find -printf (evita race condition)
echo -ne "  Listando arquivos...\r"
find "$TARGET" -type f -size +"${MIN_SIZE}c" \
    -not -path '*/\.*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.venv/*' \
    -not -path '*/venv/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.git/*' \
    -printf '%s|%p\n' \
    2>/dev/null > "$SIZE_FILE"

total_files=$(wc -l < "$SIZE_FILE" | tr -d ' ')
echo -e "  ${BOLD}$total_files${RESET} arquivos encontrados"
echo ""

# Passo 2: Encontrar tamanhos duplicados (pre-filtro)
echo -ne "  Agrupando por tamanho...\r"
awk -F'|' '{print $1}' "$SIZE_FILE" | sort | uniq -d > "$TMPDIR_WORK/dup_sizes"

if [ ! -s "$TMPDIR_WORK/dup_sizes" ]; then
    echo -e "  ${GREEN}✓ Nenhuma duplicata encontrada.${RESET}"
    echo ""
    exit 0
fi

# Passo 3: Filtrar apenas candidatos (usar awk em vez de grep para evitar problemas com caminhos especiais)
> "$TMPDIR_WORK/candidates"
while read -r dup_size; do
    awk -F'|' -v s="$dup_size" '$1 == s' "$SIZE_FILE" >> "$TMPDIR_WORK/candidates"
done < "$TMPDIR_WORK/dup_sizes"

candidates=$(wc -l < "$TMPDIR_WORK/candidates" | tr -d ' ')
echo -e "  ${BOLD}$candidates${RESET} candidatos a duplicata (mesmo tamanho)"

# Passo 4: Calcular hashes com paralelizacao
hashed=0
> "$HASH_FILE"

# Usar xargs -P para paralelizar calculo de hash
PARALLEL_JOBS=$(nproc 2>/dev/null || echo 4)

# Criar script temporario para calcular hash em paralelo
HASH_SCRIPT="$TMPDIR_WORK/hash_one.sh"
cat > "$HASH_SCRIPT" <<'HASHSCRIPT'
#!/bin/bash
filepath="$1"
hash=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')
size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
if [ -n "$hash" ]; then
    echo "$hash|$size|$filepath"
fi
HASHSCRIPT
chmod +x "$HASH_SCRIPT"

if [ "$candidates" -gt 50 ] && command -v xargs &>/dev/null; then
    awk -F'|' '{print $2}' "$TMPDIR_WORK/candidates" | \
        xargs -P "$PARALLEL_JOBS" -I{} "$HASH_SCRIPT" "{}" > "$HASH_FILE" 2>/dev/null
else
    while IFS='|' read -r size filepath; do
        hash=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')
        if [ -n "$hash" ]; then
            echo "$hash|$size|$filepath" >> "$HASH_FILE"
        fi
        hashed=$((hashed + 1))
        if [ $((hashed % 50)) -eq 0 ]; then
            echo -ne "\r  Calculando hashes... $hashed/$candidates"
        fi
    done < "$TMPDIR_WORK/candidates"
fi

echo -e "\r  Calculando hashes... ${GREEN}feito${RESET}          "
echo ""

# Passo 5: Encontrar hashes duplicados
awk -F'|' '{print $1}' "$HASH_FILE" | sort | uniq -d > "$TMPDIR_WORK/dup_hashes"

if [ ! -s "$TMPDIR_WORK/dup_hashes" ]; then
    echo -e "  ${GREEN}✓ Nenhuma duplicata encontrada.${RESET}"
    echo ""
    exit 0
fi

# Passo 6: Exibir resultados
echo -e "  ${BOLD}Duplicatas encontradas:${RESET}"
echo ""

group_num=0
total_dup_files=0
total_recoverable=0
trashed_count=0

while read -r dup_hash; do
    group_num=$((group_num + 1))

    # Usar awk em vez de grep para evitar problemas com caracteres especiais no hash
    group_lines=$(awk -F'|' -v h="$dup_hash" '$1 == h' "$HASH_FILE")
    copies=$(echo "$group_lines" | wc -l | tr -d ' ')
    first_size=$(echo "$group_lines" | head -1 | awk -F'|' '{print $2}')
    recoverable=$((first_size * (copies - 1)))
    total_recoverable=$((total_recoverable + recoverable))
    total_dup_files=$((total_dup_files + copies))

    echo -e "  ${YELLOW}Grupo $group_num${RESET} — $copies copias — ${RED}$(human_size "$recoverable")${RESET} recuperaveis"
    echo -e "  ${DIM}SHA-256: ${dup_hash:0:16}...${RESET}"

    local_line_num=0
    echo "$group_lines" | while IFS='|' read -r _ _ filepath; do
        local_line_num=$((local_line_num + 1))
        display="${filepath/$HOME/\~}"

        if $USE_TRASH && [ "$local_line_num" -gt 1 ]; then
            if trash_file "$filepath" 2>/dev/null; then
                echo -e "    ${RED}$display${RESET} ${DIM}→ lixeira${RESET}"
                trashed_count=$((trashed_count + 1))
            else
                echo -e "    ${DIM}(falha ao mover: $display)${RESET}"
                echo "    $display"
            fi
        else
            if [ "$local_line_num" -eq 1 ]; then
                echo -e "    ${GREEN}$display${RESET} ${DIM}(mantido)${RESET}"
            else
                echo "    $display"
            fi
        fi
    done
    echo ""
done < "$TMPDIR_WORK/dup_hashes"

# Resumo
echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  Grupos de duplicatas:  ${BOLD}$group_num${RESET}"
echo -e "  Arquivos duplicados:   ${BOLD}$total_dup_files${RESET}"
echo -e "  Espaco recuperavel:    ${RED}${BOLD}$(human_size "$total_recoverable")${RESET}"

if $USE_TRASH; then
    echo -e "  Movidos para lixeira: ${YELLOW}${BOLD}${trashed_count}${RESET}"
    echo -e "  ${DIM}Restaure com: gio trash --restore ou via gerenciador de arquivos${RESET}"
else
    echo -e "  ${DIM}Nenhum arquivo foi deletado. Use --trash para mover duplicatas.${RESET}"
    echo -e "  ${DIM}Revise a lista acima e delete manualmente se necessario.${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""