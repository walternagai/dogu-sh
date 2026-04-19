#!/bin/bash
# process-killer.sh — Seletor interativo de processos para termino (Linux)
# Uso: ./process-killer.sh [opcoes]
# Opcoes:
#   --signal|-s SIG  Sinal a enviar (padrao: SIGTERM, use 9 ou SIGKILL para forcar)
#   --user|-u USER   Filtra processos por usuario
#   --help           Mostra esta ajuda
#   --version        Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "fzf" "$INSTALLER" "fzf"; fi

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


readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

SIGNAL="SIGTERM"
USER_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --signal|-s)
            [[ -z "${2-}" ]] && { echo "Flag --signal requer um valor" >&2; exit 1; }
            SIGNAL="${2:-SIGTERM}"; shift 2 ;;
        --user|-u)
            [[ -z "${2-}" ]] && { echo "Flag --user requer um valor" >&2; exit 1; }
            USER_FILTER="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  process-killer.sh — Seletor interativo de processos para termino"
            echo ""
            echo "  Uso: ./process-killer.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --signal|-s SIG  Sinal a enviar (padrao: SIGTERM, use 9 ou SIGKILL para forcar)"
            echo "    --user|-u USER   Filtra processos por usuario"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./process-killer.sh                     Seleciona e termina processo"
            echo "    ./process-killer.sh -s 9                Forca termino (SIGKILL)"
            echo "    ./process-killer.sh -u www-data         Filtra por usuario"
            echo ""
            exit 0
            ;;
        --version|-V) echo "process-killer.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}"
            exit 1
            ;;
    esac
done

if ! command -v fzf &>/dev/null; then
    echo -e "${RED}Erro: fzf e necessario para este script.${RESET}"
    echo -e "Instale via: sudo apt install fzf (ou equivalente da sua distro)"
    exit 1
fi

echo -e "${CYAN}${BOLD}dogu-sh Process Killer${RESET}"
echo -e "${DIM}Sinal: $SIGNAL${RESET}\n"

PS_CMD="ps aux --sort=-%cpu"
if [ -n "$USER_FILTER" ]; then
    PS_CMD="$PS_CMD | grep -i '$USER_FILTER'"
fi

SELECTED=$(eval "$PS_CMD" | \
    awk 'NR==1 || !seen[$2]++' | \
    fzf --multi \
        --header="PID  USER  %CPU  %MEM  COMMAND" \
        --prompt="Matar processo > " \
        --preview="ps -p {1} -o pid,ppid,user,%cpu,%mem,etime,cmd 2>/dev/null || echo 'Processo nao encontrado'" \
        --preview-window='down:3:wrap' \
        --bind 'enter:accept' 2>/dev/null)

if [ -z "$SELECTED" ]; then
    echo -e "${DIM}Nenhum processo selecionado.${RESET}"
    exit 0
fi

PIDS=$(echo "$SELECTED" | awk '{print $1}')

echo ""
echo -e "${YELLOW}Processos selecionados:${RESET}"
echo "$SELECTED" | awk '{printf "  PID %-8s USER %-10s CPU %5s%%  MEM %5s%%  %s\n", $1, $2, $3, $4, $11}'

echo ""
read -p "Confirmar termino (sinal $SIGNAL)? [s/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo -e "${DIM}Operacao cancelada.${RESET}"
    exit 0
fi

echo ""
for pid in $PIDS; do
    if kill -s "$SIGNAL" "$pid" 2>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} PID $pid — sinal $SIGNAL enviado"
    else
        echo -e "  ${RED}✗${RESET} PID $pid — falha ao enviar sinal (tente sudo ou sinal 9)"
    fi
done

echo ""
echo -e "${DIM}Concluido.${RESET}"