#!/bin/bash
# log-analyzer.sh — Analisador de logs com coloracao e filtros (Linux)
# Uso: ./log-analyzer.sh [opcoes] [arquivo] [padrao]
# Opcoes:
#   --follow|-f     Acompanha o log em tempo real (tail -f)
#   --lines|-n N    Numero de linhas a exibir (padrao: 50)
#   --stats|-s      Exibe estatisticas por nivel de log
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "grep" "$INSTALLER" "grep"; fi

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly BLUE='\033[1;34m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }


readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

FOLLOW=false
LINES=50
SHOW_STATS=false
FILE=""
PATTERN="."

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --follow|-f) FOLLOW=true; shift ;;
            --lines|-n)
                [[ -z "${2-}" ]] && { echo "Flag --lines requer um valor" >&2; exit 1; }
                LINES="${2:-50}"; shift 2 ;;
            --stats|-s) SHOW_STATS=true; shift ;;
            --help|-h)
                echo ""
                echo "  log-analyzer.sh — Analisador de logs com coloracao e filtros"
                echo ""
                echo "  Uso: ./log-analyzer.sh [opcoes] [arquivo] [padrao]"
                echo ""
                echo "  Opcoes:"
                echo "    --follow|-f     Acompanha o log em tempo real (tail -f)"
                echo "    --lines|-n N    Numero de linhas a exibir (padrao: 50)"
                echo "    --stats|-s     Exibe contagem por nivel de log"
                echo "    --help         Mostra esta ajuda"
                echo "    --version      Mostra versao"
                echo ""
                echo "  Exemplos:"
                echo "    ./log-analyzer.sh /var/log/syslog error"
                echo "    ./log-analyzer.sh -f -n 100 /var/log/kern.log warning"
                echo "    ./log-analyzer.sh --stats /var/log/auth.log"
                echo ""
                exit 0
                ;;
            --version|-V) echo "log-analyzer.sh $VERSION"; exit 0 ;;
            -*)
                echo -e "${RED}Opcao desconhecida: $1${RESET}"
                exit 1
                ;;
        --) shift; break ;;
            *)
                if [ -z "$FILE" ]; then
                    FILE="$1"
                elif [ "$PATTERN" = "." ]; then
                    PATTERN="$1"
                fi
                shift
                ;;
        esac
    done
}

colorize() {
    sed \
        -e "s/\bERROR\b/${RED}${BOLD}&${RESET}/gI" \
        -e "s/\bERR\b/${RED}${BOLD}&${RESET}/gI" \
        -e "s/\bCRITICAL\b/${RED}${BOLD}&${RESET}/gI" \
        -e "s/\bCRIT\b/${RED}${BOLD}&${RESET}/gI" \
        -e "s/\bFATAL\b/${RED}${BOLD}&${RESET}/gI" \
        -e "s/\bWARNING\b/${YELLOW}${BOLD}&${RESET}/gI" \
        -e "s/\bWARN\b/${YELLOW}${BOLD}&${RESET}/gI" \
        -e "s/\bINFO\b/${GREEN}&${RESET}/gI" \
        -e "s/\bDEBUG\b/${BLUE}&${RESET}/gI" \
        -e "s/\bTRACE\b/${DIM}&${RESET}/gI"
}

show_stats() {
    local f="$1"
    echo -e ""
    echo -e "  ${CYAN}${BOLD}Estatisticas de $f${RESET}"
    echo -e "  ${DIM}────────────────────────────────────${RESET}"
    local total
    total=$(wc -l < "$f" 2>/dev/null || echo 0)
    echo -e "  Total de linhas: ${BOLD}$total${RESET}"

    for level in ERROR ERR CRITICAL CRIT FATAL WARNING WARN INFO DEBUG TRACE; do
        local count
        count=$(grep -ciw "$level" "$f" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            local color=""
            case "$level" in
                ERROR|ERR|CRITICAL|CRIT|FATAL) color="$RED" ;;
                WARNING|WARN) color="$YELLOW" ;;
                INFO) color="$GREEN" ;;
                DEBUG) color="$BLUE" ;;
                TRACE) color="$DIM" ;;
            esac
            printf "  ${color}%-10s${RESET} %s\n" "$level" "$count"
        fi
    done
    echo ""
}

parse_args "$@"

if [ -z "$FILE" ]; then
    echo -e "${RED}Erro: Arquivo de log nao especificado.${RESET}"
    echo -e "Use --help para ver as opcoes."
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo -e "${RED}Erro: Arquivo $FILE nao encontrado.${RESET}"
    exit 1
fi

if [ "$SHOW_STATS" = true ]; then
    show_stats "$FILE"
fi

echo -e "${CYAN}${BOLD}Analisando $FILE (padrao: $PATTERN)${RESET}"
echo -e "${DIM}Exibindo $LINES linhas${RESET}\n"

if [ "$FOLLOW" = true ]; then
    tail -n "$LINES" -f "$FILE" | grep --line-buffered -i "$PATTERN" | colorize &
    TAIL_PID=$!
    trap "kill -TERM "$TAIL_PID" 2>/dev/null 2>/dev/null; exit 0" INT TERM
    wait $TAIL_PID
else
    grep -i "$PATTERN" "$FILE" | tail -n "$LINES" | colorize
fi