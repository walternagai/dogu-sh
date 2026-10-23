#!/bin/bash
# cron-manager.sh — Lista, adiciona e remove tarefas do crontab do usuario
# Uso: ./cron-manager.sh [opcoes]
# Opcoes:
#   --list                 Lista tarefas (padrao)
#   --add "SCHEDULE CMD"   Adiciona uma tarefa (5 campos + comando)
#   --remove ID            Remove por ID ou numero de linha
#       --force            Nao pede confirmacao
#       --dry-run          Mostra o crontab resultante sem gravar
#       --json             Saida em formato JSON
#   -h, --help             Mostra esta ajuda
#   -V, --version          Mostra versao
#
# As tarefas adicionadas recebem um marcador "# dogu:<id>" para remocao segura.
# Um backup do crontab e gravado antes de qualquer alteracao.

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

CRONTAB_BIN="${CRONTAB_BIN:-crontab}"
ACTION="list"
ADD_ENTRY=""
REMOVE_ID=""
FORCE=false
DRY_RUN=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list) ACTION="list"; shift ;;
        --add)
            [[ -z "${2-}" ]] && { echo "Flag --add requer um valor" >&2; exit 2; }
            ACTION="add"; ADD_ENTRY="$2"; shift 2 ;;
        --remove)
            [[ -z "${2-}" ]] && { echo "Flag --remove requer um valor" >&2; exit 2; }
            ACTION="remove"; REMOVE_ID="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  cron-manager.sh — Lista, adiciona e remove tarefas do crontab"
            echo ""
            echo "  Uso: ./cron-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --list                 Lista tarefas (padrao)"
            echo "    --add \"SCHEDULE CMD\"   Adiciona (5 campos + comando)"
            echo "    --remove ID            Remove por ID ou linha"
            echo "        --force            Nao pede confirmacao"
            echo "        --dry-run          Mostra sem gravar"
            echo "        --json             Saida em formato JSON"
            echo "    -h, --help             Mostra esta ajuda"
            echo "    -V, --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./cron-manager.sh --list"
            echo "    ./cron-manager.sh --add \"0 3 * * * /home/user/backup.sh\""
            echo "    ./cron-manager.sh --remove dogu-a1b2c3d4 --dry-run"
            echo ""
            exit 0
            ;;
        -V|--version) echo "cron-manager.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

command -v "$CRONTAB_BIN" &>/dev/null || error "$CRONTAB_BIN nao encontrado."

CURRENT=$("$CRONTAB_BIN" -l 2>/dev/null || true)

print_jobs_json() {
    local first=true
    local n=0
    local count=0
    printf '{"jobs":['
    while IFS= read -r line; do
        n=$((n + 1))
        [[ -z "$line" || "$line" == \#* ]] && continue
        count=$((count + 1))
        local marker id schedule command
        marker=$(printf '%s\n' "$line" | grep -o 'dogu:[A-Za-z0-9_-]*' | head -1 || true)
        id="${marker#dogu:}"
        [ -z "$id" ] && id="$n"
        schedule=$(printf '%s\n' "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
        command=$(printf '%s\n' "$line" | cut -d' ' -f6- | sed 's/[[:space:]]*# dogu:.*//')
        $first || printf ','
        first=false
        printf '{"id":"%s","line":%s,"schedule":"%s","command":"%s"}' \
            "$(json_escape "$id")" "$n" "$(json_escape "$schedule")" "$(json_escape "$command")"
    done <<< "$CURRENT"
    printf '],"count":%s}\n' "$count"
}

case "$ACTION" in
    list)
        if $JSON_MODE; then
            print_jobs_json
        else
            echo ""
            echo -e "  ${BOLD}Cron Manager${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
            echo ""
            if [ -z "$CURRENT" ]; then
                echo -e "  ${DIM}Nenhuma tarefa no crontab.${RESET}"
            else
                n=0
                while IFS= read -r line; do
                    n=$((n + 1))
                    [[ -z "$line" || "$line" == \#* ]] && continue
                    marker=$(printf '%s\n' "$line" | grep -o 'dogu:[A-Za-z0-9_-]*' | head -1 || true)
                    id="${marker#dogu:}"
                    [ -z "$id" ] && id="$n"
                    schedule=$(printf '%s\n' "$line" | awk '{print $1" "$2" "$3" "$4" "$5}')
                    command=$(printf '%s\n' "$line" | cut -d' ' -f6- | sed 's/[[:space:]]*# dogu:.*//')
                    printf "  %-14s ${DIM}%s${RESET}  %s\n" "$id" "$schedule" "$command"
                done <<< "$CURRENT"
            fi
            echo ""
        fi
        ;;

    add)
        read -r m h dom mon dow command <<< "$ADD_ENTRY" || true
        if [ -z "${command:-}" ] || [ -z "${dow:-}" ]; then
            error "Entrada invalida. Use: \"MIN HORA DIA_MES MES DIA_SEMANA COMANDO\""
        fi
        id="dogu-$(printf '%04x%04x' $RANDOM $RANDOM)"
        line="$ADD_ENTRY # dogu:$id"
        NEW="$CURRENT"
        [ -n "$NEW" ] && NEW+=$'\n'
        NEW+="$line"

        if $DRY_RUN; then
            printf '%s\n' "$NEW"
            $JSON_MODE && printf '{"action":"add","id":"%s","dry_run":true}\n' "$(json_escape "$id")"
            exit 0
        fi

        if ! $FORCE && [ "${DOGU_CONFIRMED:-}" != "1" ]; then
            if [ -t 0 ]; then
                read -r -p "Adicionar ao crontab? [s/N] " CONFIRM
                [[ "$CONFIRM" =~ ^[Ss]$ ]] || { log "Cancelado."; exit 0; }
            else
                error "Execucao nao interativa. Use --force ou rode via 'dogu ... --yes'."
            fi
        fi

        BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dogu-sh"
        mkdir -p "$BACKUP_DIR"
        printf '%s\n' "$CURRENT" > "$BACKUP_DIR/cron-backup-$(date '+%Y%m%d_%H%M%S').txt"
        printf '%s\n' "$NEW" | "$CRONTAB_BIN" -

        if $JSON_MODE; then
            printf '{"action":"add","id":"%s","schedule":"%s","command":"%s"}\n' \
                "$(json_escape "$id")" "$(json_escape "$m $h $dom $mon $dow")" "$(json_escape "$command")"
        else
            success "Tarefa adicionada: $id"
        fi
        ;;

    remove)
        [[ -n "$REMOVE_ID" ]] || error "Informe o ID ou numero da linha."
        NEW=""
        removed=false
        n=0
        while IFS= read -r line; do
            n=$((n + 1))
            marker=$(printf '%s\n' "$line" | grep -o 'dogu:[A-Za-z0-9_-]*' | head -1 || true)
            id="${marker#dogu:}"
            if [ "$REMOVE_ID" = "$id" ] || [ "$REMOVE_ID" = "$n" ]; then
                removed=true
                continue
            fi
            [ -n "$NEW" ] && NEW+=$'\n'
            NEW+="$line"
        done <<< "$CURRENT"

        $removed || error "Tarefa nao encontrada: $REMOVE_ID"

        if $DRY_RUN; then
            printf '%s\n' "$NEW"
            $JSON_MODE && printf '{"action":"remove","id":"%s","dry_run":true}\n' "$(json_escape "$REMOVE_ID")"
            exit 0
        fi

        if ! $FORCE && [ "${DOGU_CONFIRMED:-}" != "1" ]; then
            if [ -t 0 ]; then
                read -r -p "Remover do crontab? [s/N] " CONFIRM
                [[ "$CONFIRM" =~ ^[Ss]$ ]] || { log "Cancelado."; exit 0; }
            else
                error "Execucao nao interativa. Use --force ou rode via 'dogu ... --yes'."
            fi
        fi

        BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dogu-sh"
        mkdir -p "$BACKUP_DIR"
        printf '%s\n' "$CURRENT" > "$BACKUP_DIR/cron-backup-$(date '+%Y%m%d_%H%M%S').txt"
        printf '%s\n' "$NEW" | "$CRONTAB_BIN" -

        if $JSON_MODE; then
            printf '{"action":"remove","id":"%s"}\n' "$(json_escape "$REMOVE_ID")"
        else
            success "Tarefa removida: $REMOVE_ID"
        fi
        ;;
esac
