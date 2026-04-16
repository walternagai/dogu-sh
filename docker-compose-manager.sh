#!/bin/bash
# docker-compose-manager.sh — Gerencia multiplos docker-compose.yml (Linux)
# Uso: ./docker-compose-manager.sh [diretorio] [acao]
# Opcoes:
#   --status        Lista compose files e seus status (padrao)
#   --up            Inicia todos os compose encontrados
#   --down          Para todos os compose encontrados
#   --restart       Restart de todos os compose
#   --pull          Pull + recreate de todos
#   --depth N       Profundidade de busca (padrao: 5)
#   --dry-run       Preview sem executar
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER docker.io"; check_and_install "docker-compose" "$INSTALLER docker-compose"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

ACTION="status"
BASE_DIR="."
MAX_DEPTH=5
DRY_RUN=false
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --status|-s) ACTION="status"; shift ;;
        --up|-u) ACTION="up"; shift ;;
        --down|-d) ACTION="down"; shift ;;
        --restart|-r) ACTION="restart"; shift ;;
        --pull|-p) ACTION="pull"; shift ;;
        --depth) MAX_DEPTH="${2:-5}"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-compose-manager.sh — Gerencia multiplos docker-compose.yml"
            echo ""
            echo "  Uso: ./docker-compose-manager.sh [opcoes] [diretorio]"
            echo ""
            echo "  Opcoes:"
            echo "    --status        Lista compose files e seus status (padrao)"
            echo "    --up            Inicia todos"
            echo "    --down          Para todos"
            echo "    --restart       Restart de todos"
            echo "    --pull          Pull + recreate de todos"
            echo "    --depth N       Profundidade de busca (padrao: 5)"
            echo "    --dry-run       Preview sem executar"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-compose-manager.sh --status ~/Projects"
            echo "    ./docker-compose-manager.sh --up ~/docker"
            echo "    ./docker-compose-manager.sh --pull --dry-run ."
            echo ""
            exit 0
            ;;
        --version) echo "docker-compose-manager.sh $VERSION"; exit 0 ;;
        -*) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

BASE_DIR="${POSITIONAL_ARGS[0]:-.}"
BASE_DIR="${BASE_DIR%/}"

if [ ! -d "$BASE_DIR" ]; then
    echo "Erro: '$BASE_DIR' nao e um diretorio valido." >&2
    exit 1
fi

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

if command -v docker &>/dev/null; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "  ${RED}Erro: docker compose ou docker-compose nao encontrado.${RESET}" >&2
    exit 1
fi

TMPWORK=$(mktemp -d)
trap 'rm -rf "$TMPWORK"' EXIT

find "$BASE_DIR" -maxdepth "$MAX_DEPTH" \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'compose.yml' -o -name 'compose.yaml' \) -type f 2>/dev/null | sort > "$TMPWORK/compose_files.txt"

total_files=$(wc -l < "$TMPWORK/compose_files.txt" | tr -d ' ')

if [ "$total_files" -eq 0 ]; then
    echo ""
    echo -e "  ${DIM}Nenhum docker-compose encontrado em $BASE_DIR${RESET}"
    echo ""
    exit 0
fi

get_project_name() {
    local compose_dir="$1"
    basename "$compose_dir" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

get_project_status() {
    local project_name="$1"
    local running
    running=$(docker ps --filter "label=com.docker.compose.project=$project_name" -q 2>/dev/null | wc -l | tr -d ' ')
    local total
    total=$(docker ps -a --filter "label=com.docker.compose.project=$project_name" -q 2>/dev/null | wc -l | tr -d ' ')
    [[ "$running" =~ ^[0-9]+$ ]] || running=0
    [[ "$total" =~ ^[0-9]+$ ]] || total=0
    echo "$running $total"
}

echo ""
echo -e "  ${BOLD}Docker Compose Manager${RESET} — ${total_files} projeto(s)"
echo -e "  ${DIM}Comando: $COMPOSE_CMD${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo ""

run_compose() {
    local compose_file="$1"
    local compose_dir
    compose_dir=$(dirname "$compose_file")
    local project_name
    project_name=$(get_project_name "$compose_dir")

    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} $COMPOSE_CMD -f $compose_file $1"
        return 0
    fi

    cd "$compose_dir"
}

count_up=0
count_down=0
count_partial=0
count_error=0

# -- STATUS --
if [ "$ACTION" = "status" ]; then
    echo -e "  ${BOLD}── Status dos Projetos ──${RESET}"
    echo ""
    printf "  %-25s %-12s %-10s %s\n" "PROJETO" "STATUS" "CONTAINERS" "CAMINHO"
    printf "  %-25s %-12s %-10s %s\n" "─────────────────────" "──────────" "────────" "──────────────────"

    while IFS= read -r compose_file; do
        compose_dir=$(dirname "$compose_file")
        project_name=$(get_project_name "$compose_dir")
        short_name=$(echo "$project_name" | cut -c1-23)
        relative_path=$(echo "$compose_dir" | sed "s|$BASE_DIR/||" | sed "s|$BASE_DIR||")

        read -r running total <<< "$(get_project_status "$project_name")"

        if [ "$total" -eq 0 ]; then
            status_label="${DIM}inativo${RESET}"
            count_down=$((count_down + 1))
        elif [ "$running" -eq "$total" ]; then
            status_label="${GREEN}rodando${RESET}"
            count_up=$((count_up + 1))
        else
            status_label="${YELLOW}parcial${RESET}"
            count_partial=$((count_partial + 1))
        fi

        printf "  %-25s %-12s %s/%-6s %s\n" "$short_name" "$status_label" "$running" "$total" "$relative_path"
    done < "$TMPWORK/compose_files.txt"

    echo ""
    echo "  ─────────────────────────────────"
    echo -e "  ${GREEN}✓${RESET} Rodando:    ${GREEN}${BOLD}$count_up${RESET}"
    echo -e "  ${YELLOW}◐${RESET} Parcial:    ${YELLOW}${BOLD}$count_partial${RESET}"
    echo -e "  ${DIM}○${RESET} Inativo:    ${DIM}${BOLD}$count_down${RESET}"
    echo "  ─────────────────────────────────"
    echo ""
    exit 0
fi

# -- ACOES (up/down/restart/pull) --
action_label=""
case "$ACTION" in
    up) action_label="Iniciando" ;;
    down) action_label="Parando" ;;
    restart) action_label="Reiniciando" ;;
    pull) action_label="Atualizando" ;;
esac

echo -e "  ${BOLD}── ${action_label} Projetos ──${RESET}"
echo ""

while IFS= read -r compose_file; do
    compose_dir=$(dirname "$compose_file")
    project_name=$(get_project_name "$compose_dir")
    relative_path=$(echo "$compose_dir" | sed "s|$BASE_DIR/||" | sed "s|$BASE_DIR||")

    echo -ne "  ${CYAN}$project_name${RESET} "

    if $DRY_RUN; then
        case "$ACTION" in
            up) echo -e "${DIM}[dry-run] docker compose up -d${RESET}" ;;
            down) echo -e "${DIM}[dry-run] docker compose down${RESET}" ;;
            restart) echo -e "${DIM}[dry-run] docker compose restart${RESET}" ;;
            pull) echo -e "${DIM}[dry-run] docker compose pull && docker compose up -d${RESET}" ;;
        esac
        continue
    fi

    case "$ACTION" in
        up)
            if $COMPOSE_CMD -f "$compose_file" up -d 2>/dev/null; then
                echo -e "${GREEN}✓ iniciado${RESET}"
            else
                echo -e "${RED}✗ falha${RESET}"
                count_error=$((count_error + 1))
            fi
            ;;
        down)
            if $COMPOSE_CMD -f "$compose_file" down 2>/dev/null; then
                echo -e "${GREEN}✓ parado${RESET}"
            else
                echo -e "${RED}✗ falha${RESET}"
                count_error=$((count_error + 1))
            fi
            ;;
        restart)
            if $COMPOSE_CMD -f "$compose_file" restart 2>/dev/null; then
                echo -e "${GREEN}✓ reiniciado${RESET}"
            else
                echo -e "${RED}✗ falha${RESET}"
                count_error=$((count_error + 1))
            fi
            ;;
        pull)
            $COMPOSE_CMD -f "$compose_file" pull 2>/dev/null
            if $COMPOSE_CMD -f "$compose_file" up -d 2>/dev/null; then
                echo -e "${GREEN}✓ atualizado${RESET}"
            else
                echo -e "${RED}✗ falha${RESET}"
                count_error=$((count_error + 1))
            fi
            ;;
    esac
done < "$TMPWORK/compose_files.txt"

echo ""

if [ "$count_error" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}$count_error${RESET} ${RED}projeto(s) com falha${RESET}"
fi

echo -e "  ${GREEN}✓${RESET} ${action_label} concluido"
echo ""