#!/bin/bash
# calculator.sh — Calculadora interativa com historico e suporte a expressoes
# Uso: ./calculator.sh [opcoes]
# Opcoes:
#   -e, --eval EXPR    Avalia expressao e sai
#   --history          Mostra historico de calculos
#   --clear            Limpa historico
#   --help             Mostra esta ajuda
#   --version          Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; check_and_install bc "$(detect_installer)" "bc" 2>/dev/null || { echo -e "${RED}[ERROR] bc necessario.${RESET}" >&2; exit 1; }; fi

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


DATA_DIR="$HOME/.config/calculator"
mkdir -p "$DATA_DIR"
HISTORY_FILE="$DATA_DIR/history.csv"

ACTION="interactive"
EVAL_EXPR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--eval)
            [[ -z "${2-}" ]] && { echo "Flag --eval requer um valor" >&2; exit 1; }
            EVAL_EXPR="$2"; ACTION="eval"; shift 2 ;;
        --history) ACTION="history"; shift ;;
        --clear|-c) ACTION="clear"; shift ;;
        --help|-h)
            echo ""
            echo "  calculator.sh — Calculadora interativa com historico"
            echo ""
            echo "  Uso: ./calculator.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -e, --eval EXPR    Avalia expressao e sai"
            echo "    --history          Mostra historico de calculos"
            echo "    --clear            Limpa historico"
            echo "    --help             Mostra esta ajuda"
            echo "    --version          Mostra versao"
            echo ""
            echo "  Operadores: + - * / ^ %"
            echo "  Funcoes:   sqrt() sin() cos() tan() log() ln()"
            echo ""
            echo "  Exemplos:"
            echo "    ./calculator.sh -e '2+2'"
            echo "    ./calculator.sh -e 'sqrt(144)'"
            echo "    ./calculator.sh -e 'sin(3.14159/2)'"
            echo ""
            exit 0
            ;;
        --version|-V) echo "calculator.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done



calc_expr() {
    local expr="$1"
    local result
    local math_expr
    math_expr=$(echo "$expr" | sed \
        -e 's/sin(/s(/g' \
        -e 's/cos(/c(/g' \
        -e 's/tan(/t(/g' \
        -e 's/ln(/l(/g' \
        -e 's/log(/l(/g')
    result=$(echo "scale=6; ${math_expr}" | bc -l 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$result" ]; then
        echo ""
        echo -e "  ${RED}Erro: expressao invalida${RESET}"
        return 1
    fi
    result=$(echo "$result" | sed 's/^\./0./; s/^-\./-0./')
    if [[ "$result" == *"."* ]]; then
        result=$(echo "$result" | sed 's/0*$//' | sed 's/\.$//')
    fi
    echo "$result"
}

save_history() {
    local expr="$1"
    local result="$2"
    local now=$(date '+%Y-%m-%d %H:%M:%S')
    if [ ! -f "$HISTORY_FILE" ]; then
        echo "data,expressao,resultado" > "$HISTORY_FILE"
    fi
    echo "$now,\"$expr\",\"$result\"" >> "$HISTORY_FILE"
}

case "$ACTION" in
    eval)
        result=$(calc_expr "$EVAL_EXPR")
        if [ $? -eq 0 ]; then
            echo "$result"
            save_history "$EVAL_EXPR" "$result"
        fi
        ;;

    history)
        if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
            echo ""
            echo -e "  ${DIM}Historico vazio.${RESET}"
            echo ""
            exit 0
        fi
        echo ""
        echo -e "  ${BOLD}── Historico de Calculos ──${RESET}"
        echo ""
        tail -n +2 "$HISTORY_FILE" | while IFS=',' read -r date expr result; do
            expr=$(echo "$expr" | tr -d '"')
            result=$(echo "$result" | tr -d '"')
            printf "  ${DIM}%s${RESET}  ${CYAN}%s${RESET} = ${GREEN}%s${RESET}\n" "$date" "$expr" "$result"
        done
        echo ""
        ;;

    clear)
        echo "data,expressao,resultado" > "$HISTORY_FILE"
        echo ""
        echo -e "  ${GREEN}✓${RESET} Historico limpo"
        echo ""
        ;;

    interactive)
        echo ""
        echo -e "  ${BOLD}Calculator${RESET}  ${DIM}v$VERSION${RESET}"
        echo -e "  ${DIM}Operadores: + - * / ^ % | Funcoes: sqrt() sin() cos() tan() log() ln()"
        echo -e "  ${DIM}Comandos: history, clear, quit${RESET}"
        echo ""

        while true; do
            printf "  ${CYAN}>>>${RESET} "
            read -r input < /dev/tty 2>/dev/null || break

            input=$(echo "$input" | xargs)
            [ -z "$input" ] && continue

            case "$input" in
                quit|exit|q)
                    echo -e "  ${DIM}Ate logo!${RESET}"
                    echo ""
                    break
                    ;;
                history)
                    if [ -f "$HISTORY_FILE" ] && [ -s "$HISTORY_FILE" ]; then
                        tail -n +2 "$HISTORY_FILE" | tail -10 | while IFS=',' read -r date expr result; do
                            expr=$(echo "$expr" | tr -d '"')
                            result=$(echo "$result" | tr -d '"')
                            printf "    ${DIM}%s${RESET}  %s = ${GREEN}%s${RESET}\n" "$date" "$expr" "$result"
                        done
                    else
                        echo -e "  ${DIM}Historico vazio.${RESET}"
                    fi
                    continue
                    ;;
                clear)
                    echo "data,expressao,resultado" > "$HISTORY_FILE"
                    echo -e "  ${GREEN}✓${RESET} Historico limpo"
                    continue
                    ;;
            esac

            result=$(calc_expr "$input")
            if [ $? -eq 0 ]; then
                echo -e "  ${GREEN}= ${result}${RESET}"
                save_history "$input" "$result"
            fi
        done
        ;;
esac