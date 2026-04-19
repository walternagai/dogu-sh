#!/bin/bash
# docker-restore.sh — Restaura volumes e configs de containers (Linux)
# Uso: ./docker-restore.sh [opcoes]
# Opcoes:
#   --input DIR      Diretorio de backup (obrigatorio)
#   --volume NOME    Restaura volume especifico
#   --all            Restaura todos os volumes do backup
#   --dry-run        Preview sem restaurar
#   --help           Mostra esta ajuda
#   --version        Mostra versao

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi




INPUT_DIR=""
RESTORE_ALL=false
TARGET_VOLUMES=()
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input|-i)
            [[ -z "${2-}" ]] && { echo "Flag --input requer um valor" >&2; exit 1; }
            INPUT_DIR="$2"; shift 2 ;;
        --volume|-V)
            [[ -z "${2-}" ]] && { echo "Flag --volume requer um valor" >&2; exit 1; }
            TARGET_VOLUMES+=("$2"); shift 2 ;;
        --all|-a) RESTORE_ALL=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-restore.sh — Restaura volumes e configs de containers"
            echo ""
            echo "  Uso: ./docker-restore.sh --input <dir> [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --input DIR      Diretorio de backup (obrigatorio)"
            echo "    --volume NOME    Restaura volume especifico"
            echo "    --all            Restaura todos os volumes do backup"
            echo "    --dry-run        Preview sem restaurar"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-restore.sh --input ~/docker-backups/20240113_143000 --all"
            echo "    ./docker-restore.sh --input ~/docker-backups/20240113_143000 --volume pgdata"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-restore.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if [ -z "$INPUT_DIR" ]; then
    echo -e "  ${RED}Erro: diretorio de backup nao especificado.${RESET}" >&2
    echo "  Uso: docker-restore.sh --input <dir>" >&2
    exit 1
fi

if [ ! -d "$INPUT_DIR" ]; then
    echo -e "  ${RED}Erro: '$INPUT_DIR' nao existe.${RESET}" >&2
    exit 1
fi

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

VOLUMES_DIR="$INPUT_DIR/volumes"
CONTAINERS_DIR="$INPUT_DIR/containers"

RESTORE_COUNT=0

restore_volume() {
    local vol_name="$1"
    local archive=""

    for ext in tar.gz tar; do
        if [ -f "$VOLUMES_DIR/${vol_name}.${ext}" ]; then
            archive="$VOLUMES_DIR/${vol_name}.${ext}"
            break
        fi
    done

    if [ -z "$archive" ]; then
        echo -e "  ${RED}✗${RESET} Volume '$vol_name' — arquivo de backup nao encontrado em $VOLUMES_DIR"
        return 1
    fi

    local compress_flag=""
    if [[ "$archive" == *.tar.gz ]]; then
        compress_flag="z"
    fi

    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} Volume: ${CYAN}$vol_name${RESET}  ${DIM}($archive)${RESET}"
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
        return 0
    fi

    if docker volume inspect "$vol_name" &>/dev/null; then
        echo -e "  ${YELLOW}⚠${RESET} Volume '$vol_name' ja existe — sobrescrevendo conteudo"
    else
        docker volume create "$vol_name" &>/dev/null
    fi

    docker run --rm -v "$vol_name:/target" -v "$VOLUMES_DIR:/backup" alpine \
        tar x${compress_flag}f "/backup/$(basename "$archive")" -C /target 2>/dev/null

    if [ $? -eq 0 ]; then
        RESTORE_COUNT=$((RESTORE_COUNT + 1))
        echo -e "  ${GREEN}✓${RESET} Volume: ${CYAN}$vol_name${RESET}"
    else
        echo -e "  ${RED}✗${RESET} Volume: ${CYAN}$vol_name${RESET}  ${DIM}(falha)${RESET}"
    fi
}

echo ""
echo -e "  ${BOLD}Docker Restore${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem restaurar"
fi

echo ""
echo -e "  Backup: ${CYAN}$INPUT_DIR${RESET}"
echo ""

# Listar conteudo disponivel
if [ -d "$VOLUMES_DIR" ]; then
    available_volumes=()
    echo -e "  ${BOLD}Volumes disponiveis no backup:${RESET}"
    for f in "$VOLUMES_DIR"/*.tar.gz "$VOLUMES_DIR"/*.tar; do
        [ -f "$f" ] || continue
        vol_name=$(basename "$f" | sed 's/\.tar\.gz$//' | sed 's/\.tar$//')
        echo -e "    ${CYAN}$vol_name${RESET}"
        available_volumes+=("$vol_name")
    done
    echo ""
fi

if [ -d "$CONTAINERS_DIR" ]; then
    echo -e "  ${BOLD}Configs de containers no backup:${RESET}"
    for f in "$CONTAINERS_DIR"/*.json; do
        [ -f "$f" ] || continue
        cname=$(basename "$f" .json)
        echo -e "    ${CYAN}$cname${RESET}"
    done
    echo ""
fi

# Determinar alvos
if $RESTORE_ALL; then
    for vol in "${available_volumes[@]}"; do
        TARGET_VOLUMES+=("$vol")
    done
fi

if [ ${#TARGET_VOLUMES[@]} -eq 0 ]; then
    echo -e "  ${DIM}Nenhum volume selecionado. Use --all ou --volume NOME.${RESET}"
    echo ""
    exit 0
fi

# Confirmar
if ! $DRY_RUN; then
    echo -e "  ${RED}ATENCAO: Isso vai sobrescrever dados existentes nos volumes!${RESET}"
    echo ""
    printf "  Confirmar restauracao de ${#TARGET_VOLUMES[@]} volume(s)? [s/N]: "
    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    case "$confirm" in
        [sS]) ;;
        --) shift; break ;;
        *) echo -e "  ${DIM}Cancelado.${RESET}"; echo ""; exit 0 ;;
    esac
fi

# Restaurar volumes
echo -e "  ${BOLD}── Restaurando Volumes ──${RESET}"
echo ""

for vol in "${TARGET_VOLUMES[@]}"; do
    restore_volume "$vol" || true
done

echo ""

# Resumo
echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  Volumes restaurados:  ${GREEN}${BOLD}$RESTORE_COUNT${RESET}"

if $DRY_RUN; then
    echo -e "  ${DIM}Execute sem --dry-run para restaurar.${RESET}"
else
    echo -e "  ${DIM}Verifique os containers que usam estes volumes.${RESET}"
    echo -e "  ${DIM}Reinicie-os se necessario: docker restart <container>${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""