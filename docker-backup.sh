#!/bin/bash
# docker-backup.sh — Backup de volumes e configs de containers (Linux)
# Uso: ./docker-backup.sh [opcoes]
# Opcoes:
#   --all           Backup de todos os volumes
#   --volume NOME   Backup de volume especifico
#   --container ID  Backup de config do container
#   --output DIR    Diretorio de saida (padrao: ~/docker-backups)
#   --compress      Comprimir com gzip
#   --keep N        Manter N ultimos backups (padrao: 5)
#   --dry-run       Preview sem criar backup
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

BACKUP_ALL=false
TARGET_VOLUMES=()
TARGET_CONTAINERS=()
OUTPUT_DIR="$HOME/docker-backups"
USE_COMPRESS=false
KEEP_VERSIONS=5
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --all|-a) BACKUP_ALL=true; shift ;;
        --volume|-V) TARGET_VOLUMES+=("$2"); shift 2 ;;
        --container|-c) TARGET_CONTAINERS+=("$2"); shift 2 ;;
        --output|-o) OUTPUT_DIR="$2"; shift 2 ;;
        --compress|-z) USE_COMPRESS=true; shift ;;
        --keep|-k) KEEP_VERSIONS="${2:-5}"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-backup.sh — Backup de volumes e configs de containers"
            echo ""
            echo "  Uso: ./docker-backup.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all           Backup de todos os volumes"
            echo "    --volume NOME   Backup de volume especifico (multiplas vezes)"
            echo "    --container ID  Backup da config do container (docker inspect)"
            echo "    --output DIR    Diretorio de saida (padrao: ~/docker-backups)"
            echo "    --compress      Comprimir com gzip"
            echo "    --keep N        Manter N ultimos backups (padrao: 5)"
            echo "    --dry-run       Preview sem criar backup"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-backup.sh --all"
            echo "    ./docker-backup.sh --volume pgdata --volume redis-data"
            echo "    ./docker-backup.sh --container myapp --compress"
            echo "    ./docker-backup.sh --all --output /mnt/backup --keep 10"
            echo ""
            exit 0
            ;;
        --version) echo "docker-backup.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="$OUTPUT_DIR/$TIMESTAMP"
BACKUP_COUNT=0
BACKUP_SIZE=0

human_size() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "0 B"; return; fi
    if [ "$bytes" -ge 1073741824 ]; then echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then echo "$((bytes / 1024)) KB"
    else echo "${bytes} B"
    fi
}

backup_volume() {
    local vol_name="$1"
    local dest="$BACKUP_DIR/volumes"

    if ! docker volume inspect "$vol_name" &>/dev/null; then
        echo -e "  ${RED}✗${RESET} Volume '$vol_name' nao encontrado"
        return 1
    fi

    mkdir -p "$dest"

    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} Volume: ${CYAN}$vol_name${RESET}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
        return 0
    fi

    local archive="$dest/${vol_name}.tar"
    if $USE_COMPRESS; then
        archive="$dest/${vol_name}.tar.gz"
        docker run --rm -v "$vol_name:/source:ro" -v "$dest:/backup" alpine tar czf "/backup/${vol_name}.tar.gz" -C /source . 2>/dev/null
    else
        docker run --rm -v "$vol_name:/source:ro" -v "$dest:/backup" alpine tar cf "/backup/${vol_name}.tar" -C /source . 2>/dev/null
    fi

    if [ -f "$archive" ]; then
        local size
        size=$(stat -c '%s' "$archive" 2>/dev/null || echo 0)
        local size_str
        size_str=$(human_size "$size")
        BACKUP_SIZE=$((BACKUP_SIZE + size))
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
        echo -e "  ${GREEN}✓${RESET} Volume: ${CYAN}$vol_name${RESET}  ${DIM}($size_str)${RESET}"
    else
        echo -e "  ${RED}✗${RESET} Volume: ${CYAN}$vol_name${RESET}  ${DIM}(falha)${RESET}"
    fi
}

backup_container_config() {
    local container_id="$1"
    local dest="$BACKUP_DIR/containers"

    local real_id
    real_id=$(docker inspect --format '{{.Id}}' "$container_id" 2>/dev/null | head -1)
    if [ -z "$real_id" ]; then
        echo -e "  ${RED}✗${RESET} Container '$container_id' nao encontrado"
        return 1
    fi

    mkdir -p "$dest"

    local name
    name=$(docker inspect --format '{{.Name}}' "$container_id" 2>/dev/null | sed 's|/||')

    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} Config: ${CYAN}$name${RESET}"
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
        return 0
    fi

    docker inspect "$container_id" > "$dest/${name}.json" 2>/dev/null

    if [ -f "$dest/${name}.json" ]; then
        local size
        size=$(stat -c '%s' "$dest/${name}.json" 2>/dev/null || echo 0)
        BACKUP_SIZE=$((BACKUP_SIZE + size))
        BACKUP_COUNT=$((BACKUP_COUNT + 1))
        echo -e "  ${GREEN}✓${RESET} Config: ${CYAN}$name${RESET}  ${DIM}(docker inspect)${RESET}"
    else
        echo -e "  ${RED}✗${RESET} Config: ${CYAN}$name${RESET}  ${DIM}(falha)${RESET}"
    fi
}

echo ""
echo -e "  ${BOLD}Docker Backup${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem criar backup"
fi

echo ""

# Coletar volumes alvo
if $BACKUP_ALL; then
    while IFS= read -r vol; do
        TARGET_VOLUMES+=("$vol")
    done < <(docker volume ls -q 2>/dev/null)
fi

if [ ${#TARGET_VOLUMES[@]} -eq 0 ] && [ ${#TARGET_CONTAINERS[@]} -eq 0 ]; then
    echo -e "  ${DIM}Nenhum alvo especificado. Use --all, --volume ou --container.${RESET}"
    echo ""
    exit 0
fi

if ! $DRY_RUN; then
    mkdir -p "$BACKUP_DIR"
fi

# Backup de volumes
if [ ${#TARGET_VOLUMES[@]} -gt 0 ]; then
    echo -e "  ${BOLD}── Volumes (${#TARGET_VOLUMES[@]}) ──${RESET}"
    echo ""

    for vol in "${TARGET_VOLUMES[@]}"; do
        backup_volume "$vol" || true
    done

    echo ""
fi

# Backup de configs
if [ ${#TARGET_CONTAINERS[@]} -gt 0 ]; then
    echo -e "  ${BOLD}── Container Configs (${#TARGET_CONTAINERS[@]}) ──${RESET}"
    echo ""

    for ctr in "${TARGET_CONTAINERS[@]}"; do
        backup_container_config "$ctr" || true
    done

    echo ""
fi

# Backup de configs de containers que usam os volumes (auto)
if [ ${#TARGET_VOLUMES[@]} -gt 0 ] && ! $DRY_RUN; then
    echo -e "  ${BOLD}── Container Configs (auto) ──${RESET}"
    echo -e "  ${DIM}Detectando containers que usam os volumes acima${RESET}"
    echo ""

    auto_dir="$BACKUP_DIR/containers"
    mkdir -p "$auto_dir"

    docker ps -a --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
        for vol in "${TARGET_VOLUMES[@]}"; do
            if docker inspect "$cid" --format '{{range .Mounts}}{{.Name}} {{end}}' 2>/dev/null | grep -qF "$vol"; then
                if [ ! -f "$auto_dir/${cname}.json" ]; then
                    docker inspect "$cid" > "$auto_dir/${cname}.json" 2>/dev/null
                    echo -e "  ${DIM}→${RESET} ${CYAN}$cname${RESET} usa volume ${DIM}$vol${RESET}"
                fi
            fi
        done
    done

    echo ""
fi

# Rotacao
if ! $DRY_RUN; then
    existing=$(find "$OUTPUT_DIR" -maxdepth 1 -type d -name '20*' 2>/dev/null | sort)
    existing_count=$(echo "$existing" | grep -c '.' || echo 0)

    if [ "$existing_count" -gt "$KEEP_VERSIONS" ]; then
        remove_count=$((existing_count - KEEP_VERSIONS))
        echo "$existing" | head -n "$remove_count" | while read -r old_dir; do
            rm -rf "$old_dir"
            echo -e "  ${DIM}Removido: $(basename "$old_dir")${RESET}"
        done
        echo ""
    fi
fi

# Resumo
echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  Backups criados:  ${GREEN}${BOLD}$BACKUP_COUNT${RESET}"

if ! $DRY_RUN; then
    echo -e "  Tamanho total:    ${CYAN}$(human_size "$BACKUP_SIZE")${RESET}"
    echo -e "  Destino:          ${DIM}$BACKUP_DIR${RESET}"
    echo -e "  Rotacao:          mantendo ${KEEP_VERSIONS} ultimos"
else
    echo -e "  ${DIM}Execute sem --dry-run para criar os backups.${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""
echo -e "  ${DIM}Restaure com: docker-restore.sh --input $BACKUP_DIR${RESET}"
echo ""