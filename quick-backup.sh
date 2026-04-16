#!/bin/bash
# quick-backup.sh — Backup incremental com rsync (Linux)
# Uso: ./quick-backup.sh [dir-origem] [dir-destino]
# Opcoes:
#   --dry-run       Preview sem copiar
#   --all           Executa sem confirmacao
#   --compress      Comprime durante transferencia
#   --keep N        Manter N ultimos backups (padrao: 5)
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "rsync" "$INSTALLER rsync"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
CLEAN_ALL=false
USE_COMPRESS=false
KEEP_VERSIONS=5
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --all|-a) CLEAN_ALL=true; shift ;;
        --compress) USE_COMPRESS=true; shift ;;
        --keep) KEEP_VERSIONS="${2:-5}"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  quick-backup.sh — Backup incremental com rsync"
            echo ""
            echo "  Uso: ./quick-backup.sh [opcoes] [origem] [destino]"
            echo ""
            echo "  Argumentos:"
            echo "    origem        Diretorio de origem (padrao: ~)"
            echo "    destino       Diretorio de destino (obrigatorio)"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem copiar"
            echo "    --all         Executa sem confirmacao"
            echo "    --compress    Comprime durante transferencia"
            echo "    --keep N      Manter N ultimos backups (padrao: 5)"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Excluidos automaticamente:"
            echo "    .git, node_modules, .venv, venv, __pycache__, .cache, .local/share/Trash"
            echo ""
            echo "  Exemplos:"
            echo "    ./quick-backup.sh --dry-run ~/Documents /mnt/backup"
            echo "    ./quick-backup.sh --all --compress ~/Projects /run/media/user/hd"
            echo "    ./quick-backup.sh --keep 10 ~/ /mnt/nas/backup-pc"
            echo ""
            exit 0
            ;;
        --version|-v) echo "quick-backup.sh $VERSION"; exit 0 ;;
        -*) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

SOURCE="${POSITIONAL_ARGS[0]:-$HOME}"
SOURCE="${SOURCE%/}"

if [ -z "${POSITIONAL_ARGS[1]:-}" ]; then
    echo "Erro: destino nao especificado." >&2
    echo "Uso: quick-backup.sh [origem] <destino>" >&2
    exit 1
fi

DEST="${POSITIONAL_ARGS[1]}"
DEST="${DEST%/}"

if [ ! -d "$SOURCE" ]; then
    echo "Erro: origem '$SOURCE' nao existe." >&2
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo -e "  ${DIM}Criando destino: $DEST${RESET}"
    mkdir -p "$DEST"
fi

LOG_DIR="$HOME/.local/share/quick-backup"
mkdir -p "$LOG_DIR"

EXCLUDE_FILE=$(mktemp)
trap 'rm -f "$EXCLUDE_FILE"' EXIT

cat > "$EXCLUDE_FILE" <<'EXCLUDES'
.git
.svn
.hg
node_modules
.venv
venv
__pycache__
.cache
.local/share/Trash
.Discord
.thumbnails
*.pyc
*.o
*.so
*.tmp
lost+found
EXCLUDES

RSYNC_OPTS=(-a -h --delete --delete-excluded --stats --human-readable)

if $DRY_RUN; then
    RSYNC_OPTS+=(--dry-run)
fi

if $USE_COMPRESS; then
    RSYNC_OPTS+=(-z)
fi

RSYNC_OPTS+=(--exclude-from="$EXCLUDE_FILE")

echo ""
echo -e "  ${BOLD}Backup Rapido${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem copiar"
fi

echo ""
echo -e "  Origem:   ${CYAN}$SOURCE${RESET}"
echo -e "  Destino:  ${CYAN}$DEST${RESET}"
echo ""

if ! $CLEAN_ALL && ! $DRY_RUN; then
    printf "  Confirmar backup? [s/N]: "
    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    case "$confirm" in
        [sS]) ;;
        *) echo -e "  ${DIM}Cancelado.${RESET}"; echo ""; exit 0 ;;
    esac
fi

TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
LOG_FILE="$LOG_DIR/backup-${TIMESTAMP}.log"

echo -e "  ${DIM}Copiando...${RESET}"
echo ""

rsync "${RSYNC_OPTS[@]}" "$SOURCE/" "$DEST/" 2>&1 | tee "$LOG_FILE"

echo ""
echo -e "  ${GREEN}✓ Backup concluido${RESET}"
echo -e "  ${DIM}Log: $LOG_FILE${RESET}"

# Rotacao de logs
log_count=$(find "$LOG_DIR" -name 'backup-*.log' -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$log_count" -gt "$KEEP_VERSIONS" ]; then
    remove_count=$((log_count - KEEP_VERSIONS))
    find "$LOG_DIR" -name 'backup-*.log' -type f -printf '%T+ %p\n' 2>/dev/null | \
        sort | head -n "$remove_count" | awk '{print $2}' | while read -r old_log; do
        rm -f "$old_log"
    done
    echo -e "  ${DIM}$remove_count log(s) antigo(s) removido(s) (mantendo $KEEP_VERSIONS)${RESET}"
fi

echo ""