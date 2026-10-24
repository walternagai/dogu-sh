#!/bin/bash
# systemd-timer.sh — Gerencia timers systemd --user (adicionar, listar, remover)
# Uso: ./systemd-timer.sh [opcoes]
# Opcoes:
#   --list                    Lista timers gerenciados (padrao)
#   --add CALENDAR            Adiciona um timer (ex: "*-*-* 03:00:00")
#       --command CMD         Comando executado pelo timer
#   --remove ID               Remove um timer
#       --force               Nao pede confirmacao
#       --dry-run             Mostra o que seria feito
#       --json                Saida em formato JSON
#   -h, --help                Mostra esta ajuda
#   -V, --version             Mostra versao

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

ACTION="list"
CALENDAR=""
COMMAND=""
REMOVE_ID=""
FORCE=false
DRY_RUN=false
JSON_MODE=false

SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dogu-sh/timers"
SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list) ACTION="list"; shift ;;
        --add)
            [[ -z "${2-}" ]] && { echo "Flag --add requer um valor" >&2; exit 2; }
            ACTION="add"; CALENDAR="$2"; shift 2 ;;
        --command)
            [[ -z "${2-}" ]] && { echo "Flag --command requer um valor" >&2; exit 2; }
            COMMAND="$2"; shift 2 ;;
        --remove)
            [[ -z "${2-}" ]] && { echo "Flag --remove requer um valor" >&2; exit 2; }
            ACTION="remove"; REMOVE_ID="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  systemd-timer.sh — Gerencia timers systemd --user"
            echo ""
            echo "  Uso: ./systemd-timer.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --list                    Lista timers (padrao)"
            echo "    --add CALENDAR            Adiciona timer (ex: \"*-*-* 03:00:00\")"
            echo "        --command CMD         Comando executado"
            echo "    --remove ID               Remove timer"
            echo "        --force               Nao pede confirmacao"
            echo "        --dry-run             Mostra o que seria feito"
            echo "        --json                Saida em formato JSON"
            echo "    -h, --help                Mostra esta ajuda"
            echo "    -V, --version             Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./systemd-timer.sh --add \"*-*-* 03:00:00\" --command /home/user/backup.sh"
            echo "    ./systemd-timer.sh --list --json"
            echo "    ./systemd-timer.sh --remove dogu-a1b2c3d4"
            echo ""
            exit 0
            ;;
        -V|--version) echo "systemd-timer.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

confirm() {
    local msg="$1"
    if $FORCE || [ "${DOGU_CONFIRMED:-}" = "1" ]; then return 0; fi
    if [ -t 0 ]; then
        read -r -p "$msg [s/N] " c
        [[ "$c" =~ ^[Ss]$ ]]
    else
        error "Execucao nao interativa. Use --force ou rode via 'dogu ... --yes'."
    fi
}

timer_ids() {
    find "$SYSTEMD_DIR" -maxdepth 1 -name 'dogu-*.timer' -type f 2>/dev/null | while IFS= read -r f; do basename "$f" .timer; done | sort
}

case "$ACTION" in
    add)
        [[ -n "$CALENDAR" ]] || error "--add exige uma expressao OnCalendar."
        [[ -n "$COMMAND" ]] || error "--command e obrigatorio com --add."
        if command -v systemd-analyze >/dev/null 2>&1; then
            systemd-analyze calendar "$CALENDAR" >/dev/null 2>&1 || error "OnCalendar invalido: $CALENDAR"
        fi
        id="dogu-$(printf '%04x%04x' $RANDOM $RANDOM)"
        service="$SYSTEMD_DIR/${id}.service"
        timer="$SYSTEMD_DIR/${id}.timer"
        wrapper="$DATA_DIR/${id}.sh"

        if $DRY_RUN; then
            echo "mkdir -p $SYSTEMD_DIR $DATA_DIR"
            echo "write $wrapper: $COMMAND"
            echo "write $service e $timer (OnCalendar=$CALENDAR)"
            echo "$SYSTEMCTL_BIN --user daemon-reload && $SYSTEMCTL_BIN --user enable --now ${id}.timer"
            $JSON_MODE && printf '{"action":"add","id":"%s","dry_run":true}\n' "$(json_escape "$id")"
            exit 0
        fi

        confirm "Criar timer $id e habilitar agora?" || { log "Cancelado."; exit 0; }
        mkdir -p "$SYSTEMD_DIR" "$DATA_DIR"
        cat > "$wrapper" <<EOF
#!/bin/bash
$COMMAND
EOF
        chmod +x "$wrapper"
        cat > "$service" <<EOF
[Unit]
Description=dogu-sh timer $id

[Service]
Type=oneshot
ExecStart=/bin/bash $wrapper
EOF
        cat > "$timer" <<EOF
[Unit]
Description=dogu-sh timer $id

[Timer]
OnCalendar=$CALENDAR
Persistent=true

[Install]
WantedBy=timers.target
EOF
        "$SYSTEMCTL_BIN" --user daemon-reload
        "$SYSTEMCTL_BIN" --user enable --now "${id}.timer"

        if $JSON_MODE; then
            printf '{"action":"add","id":"%s","calendar":"%s","command":"%s"}\n' \
                "$(json_escape "$id")" "$(json_escape "$CALENDAR")" "$(json_escape "$COMMAND")"
        else
            success "Timer criado e habilitado: $id"
        fi
        ;;

    remove)
        [[ -n "$REMOVE_ID" ]] || error "Informe o ID do timer."
        [[ -f "$SYSTEMD_DIR/${REMOVE_ID}.timer" ]] || error "Timer nao encontrado: $REMOVE_ID"
        confirm "Remover timer $REMOVE_ID?" || { log "Cancelado."; exit 0; }
        if $DRY_RUN; then
            echo "$SYSTEMCTL_BIN --user disable --now ${REMOVE_ID}.timer"
            echo "rm -f $SYSTEMD_DIR/${REMOVE_ID}.service $SYSTEMD_DIR/${REMOVE_ID}.timer $DATA_DIR/${REMOVE_ID}.sh"
            $JSON_MODE && printf '{"action":"remove","id":"%s","dry_run":true}\n' "$(json_escape "$REMOVE_ID")"
            exit 0
        fi
        "$SYSTEMCTL_BIN" --user disable --now "${REMOVE_ID}.timer" 2>/dev/null || true
        rm -f "$SYSTEMD_DIR/${REMOVE_ID}.service" "$SYSTEMD_DIR/${REMOVE_ID}.timer" "$DATA_DIR/${REMOVE_ID}.sh"
        "$SYSTEMCTL_BIN" --user daemon-reload
        if $JSON_MODE; then
            printf '{"action":"remove","id":"%s"}\n' "$(json_escape "$REMOVE_ID")"
        else
            success "Timer removido: $REMOVE_ID"
        fi
        ;;

    list)
        json_items=""
        human_rows=""
        json_first=true
        count=0
        while IFS= read -r id; do
            [ -z "$id" ] && continue
            count=$((count + 1))
            calendar=$(grep -m1 '^OnCalendar=' "$SYSTEMD_DIR/${id}.timer" 2>/dev/null | cut -d= -f2- || true)
            command=$(sed -n '2,$p' "$DATA_DIR/${id}.sh" 2>/dev/null | head -1 || true)
            active="inactive"
            if command -v "$SYSTEMCTL_BIN" >/dev/null 2>&1; then
                active=$("$SYSTEMCTL_BIN" --user is-active "${id}.timer" 2>/dev/null || true)
            fi
            if ! $JSON_MODE; then
                human_rows+=$(printf "  %-16s %-22s %-10s %s\n" "$id" "$calendar" "$active" "$command")
            fi
            $json_first || json_items+=","
            json_first=false
            json_items+=$(printf '{"id":"%s","calendar":"%s","active":"%s","command":"%s"}' \
                "$(json_escape "$id")" "$(json_escape "$calendar")" "$(json_escape "$active")" "$(json_escape "$command")")
        done <<< "$(timer_ids)"

        if $JSON_MODE; then
            printf '{"timers":[%s],"count":%s}\n' "$json_items" "$count"
        else
            echo ""
            echo -e "  ${BOLD}Systemd Timers${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
            echo ""
            if [ "$count" -eq 0 ]; then
                echo -e "  ${DIM}Nenhum timer gerenciado. Use --add.${RESET}"
            else
                printf "  %-16s %-22s %-10s %s\n" "ID" "ONCALENDAR" "ATIVO" "COMANDO"
                printf '%s' "$human_rows"
            fi
            echo ""
        fi
        ;;
esac
