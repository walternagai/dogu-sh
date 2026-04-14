#!/bin/bash
# folder-sync.sh — Sync directories with rsync (Linux)
# Uso: ./folder-sync.sh [origem] [destino]
# Opcoes:
#   --dry-run       Preview sem copiar
#   --all           Executa sem confirmacao
#   --mirror        Espelha origem no destino (remove arquivos ausentes na origem)
#   --watch         Monitora mudancas e sincroniza continuamente
#   --compress      Comprime durante transferencia
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

DRY_RUN=false
CLEAN_ALL=false
MIRROR=false
WATCH=false
USE_COMPRESS=false
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --all|-a) CLEAN_ALL=true; shift ;;
        --mirror|-m) MIRROR=true; shift ;;
        --watch|-w) WATCH=true; shift ;;
        --compress|-z) USE_COMPRESS=true; shift ;;
        --help|-h)
            echo ""
            echo "  folder-sync.sh — Sincroniza diretorios com rsync"
            echo ""
            echo "  Uso: ./folder-sync.sh [opcoes] <origem> <destino>"
            echo ""
            echo "  Argumentos:"
            echo "    origem        Diretorio de origem"
            echo "    destino       Diretorio de destino"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem copiar"
            echo "    --all         Executa sem confirmacao"
            echo "    --mirror      Espelha origem no destino (remove arquivos extras no destino)"
            echo "    --watch       Monitora mudancas e sincroniza continuamente"
            echo "    --compress    Comprime durante transferencia"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./folder-sync.sh --dry-run ~/Documents /run/media/user/hd/Documents"
            echo "    ./folder-sync.sh --mirror ~/Projects /mnt/nas/projects"
            echo "    ./folder-sync.sh --watch ~/Notes /mnt/sync/notes"
            echo ""
            exit 0
            ;;
        --version|-v) echo "folder-sync.sh $VERSION"; exit 0 ;;
        -*) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

SOURCE="${POSITIONAL_ARGS[0]:-}"
DEST="${POSITIONAL_ARGS[1]:-}"

if [ -z "$SOURCE" ] || [ -z "$DEST" ]; then
    echo "Erro: origem e destino sao obrigatorios." >&2
    echo "Uso: folder-sync.sh <origem> <destino>" >&2
    exit 1
fi

SOURCE="${SOURCE%/}"
DEST="${DEST%/}"

if [ ! -d "$SOURCE" ]; then
    echo "Erro: origem '$SOURCE' nao existe." >&2
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo -e "  ${DIM}Criando destino: $DEST${RESET}"
    mkdir -p "$DEST"
fi

if [ "$SOURCE" = "$DEST" ]; then
    echo "Erro: origem e destino sao iguais." >&2
    exit 1
fi

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
.thumbnails
*.pyc
*.tmp
lost+found
EXCLUDES

RSYNC_OPTS=(-a -h --stats --human-readable --exclude-from="$EXCLUDE_FILE")

if $DRY_RUN; then
    RSYNC_OPTS+=(--dry-run)
fi

if $MIRROR; then
    RSYNC_OPTS+=(--delete)
fi

if $USE_COMPRESS; then
    RSYNC_OPTS+=(-z)
fi

show_notify() {
    local title="$1"
    local body="$2"
    if command -v notify-send &>/dev/null; then
        notify-send "$title" "$body" 2>/dev/null || true
    fi
}

run_sync() {
    local mode_label=""
    if $MIRROR; then
        mode_label=" (espelho)"
    fi

    echo ""
    echo -e "  ${BOLD}Sincronizacao${mode_label}${RESET}"

    if $DRY_RUN; then
        echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem copiar"
    fi

    echo ""
    echo -e "  Origem:   ${CYAN}$SOURCE${RESET}"
    echo -e "  Destino:  ${CYAN}$DEST${RESET}"

    if $MIRROR; then
        echo -e "  Modo:     ${RED}ESPPELHO${RESET} (arquivos ausentes na origem serao removidos no destino)"
    else
        echo -e "  Modo:     ${GREEN}INCREMENTAL${RESET} (apenas adiciona/atualiza)"
    fi

    echo ""

    if ! $CLEAN_ALL && ! $DRY_RUN; then
        if $MIRROR; then
            printf "  ${RED}ATENCAO:${RESET} Arquivos no destino que nao existem na origem serao deletados. Confirmar? [s/N]: "
        else
            printf "  Confirmar sincronizacao? [s/N]: "
        fi
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS]|[yY]*) ;;
            *) echo -e "  ${DIM}Cancelado.${RESET}"; echo ""; exit 0 ;;
        esac
    fi

    echo -e "  ${DIM}Sincronizando...${RESET}"
    echo ""

    rsync "${RSYNC_OPTS[@]}" "$SOURCE/" "$DEST/" 2>&1

    echo ""
    echo -e "  ${GREEN}✓ Sincronizacao concluida${RESET}"
    show_notify "sync-pastas" "Sincronizacao concluida: $SOURCE → $DEST"
    echo ""
}

if $WATCH; then
    if ! command -v inotifywait &>/dev/null; then
        echo -e "  ${RED}Erro: inotifywait nao encontrado.${RESET}" >&2
        echo -e "  ${DIM}Instale: sudo apt install inotify-tools${RESET}" >&2
        exit 1
    fi

    echo ""
    echo -e "  ${BOLD}Modo Watch${RESET} — monitorando mudancas"
    echo -e "  Origem:  ${CYAN}$SOURCE${RESET}"
    echo -e "  Destino: ${CYAN}$DEST${RESET}"
    echo -e "  ${DIM}Pressione Ctrl+C para parar${RESET}"
    echo ""

    run_sync

    while inotifywait -r -e modify,create,delete,move --format '%w%f %e' "$SOURCE" 2>/dev/null; do
        echo -e "  ${DIM}Mudanca detectada — sincronizando...${RESET}"
        rsync "${RSYNC_OPTS[@]}" "$SOURCE/" "$DEST/" 2>/dev/null
        echo -e "  ${GREEN}✓${RESET} $(date '+%H:%M:%S')"
        echo ""
    done
else
    run_sync
fi