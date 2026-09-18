#!/bin/bash
# git-stale.sh — Lista branches antigas sem merge que podem ser limpas (Linux)
# Uso: ./git-stale.sh [opcoes]
# Opcoes:
#   --json          Saida em formato JSON
#   --project PATH  Caminho do repositorio (padrao: diretorio atual)
#   --days N        Dias sem commit para considerar stale (padrao: 30)
#   --merged        Mostra apenas branches ja merged
#   --no-merged     Mostra apenas branches nao merged
#   --delete        Deleta branches stale (requer confirmacao)
#   --force         Deleta sem confirmacao
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "git" "$INSTALLER" "git"
fi

# --- Variaveis globais ---
JSON_MODE=false
PROJECT_DIR="."
STALE_DAYS=30
SHOW_MERGED=""
DO_DELETE=false
FORCE_DELETE=false

# --- Parse de argumentos ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_DIR="$2"; shift 2 ;;
        --days|-d)
            [[ -z "${2-}" ]] && error "Flag --days requer um valor"
            STALE_DAYS="$2"; shift 2 ;;
        --merged) SHOW_MERGED="merged"; shift ;;
        --no-merged) SHOW_MERGED="unmerged"; shift ;;
        --delete) DO_DELETE=true; shift ;;
        --force) FORCE_DELETE=true; shift ;;
        --help|-h)
            echo ""
            echo "  git-stale.sh — Lista branches antigas sem merge que podem ser limpas"
            echo ""
            echo "  Uso: ./git-stale.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --project|-p PATH   Caminho do repositorio (padrao: diretorio atual)"
            echo "    --days|-d N         Dias sem commit para stale (padrao: 30)"
            echo "    --merged            Mostra apenas branches ja merged"
            echo "    --no-merged         Mostra apenas branches nao merged"
            echo "    --delete            Deleta branches stale (requer confirmacao)"
            echo "    --force             Deleta sem confirmacao"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./git-stale.sh"
            echo "    ./git-stale.sh --days 60 --json"
            echo "    ./git-stale.sh --merged --delete ~/meu-projeto"
            echo ""
            exit 0
            ;;
        --version|-V) echo "git-stale.sh $SCRIPT_VERSION"; exit 0 ;;
        -*) error "Opcao desconhecida: $1" ;;
        *) PROJECT_DIR="$1"; shift ;;
    esac
done

# --- Validacao ---
cd "$PROJECT_DIR" || error "Diretorio nao encontrado: $PROJECT_DIR"

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    error "Nao e um repositorio git: $PROJECT_DIR"
fi

REPO_NAME=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown")
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")
BASE_BRANCH=""

# Detectar branch principal
for candidate in main master mainline develop; do
    if git rev-parse --verify "$candidate" &>/dev/null 2>&1; then
        BASE_BRANCH="$candidate"
        break
    fi
done

if [ -z "$BASE_BRANCH" ]; then
    # Tentar detectar via remote
    BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
fi

if [ -z "$BASE_BRANCH" ]; then
    warn "Branch principal (main/master) nao encontrada. Usando HEAD como referencia."
    BASE_BRANCH="HEAD"
fi

# --- Coleta de dados ---
TODAY_EPOCH=$(date +%s)
STALE_BRANCHES=()
MERGED_COUNT=0
UNMERGED_COUNT=0
TOTAL_BRANCHES=0

while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    # Pular branch atual
    [ "$branch" = "$CURRENT_BRANCH" ] && continue
    # Pular branch principal
    [ "$branch" = "$BASE_BRANCH" ] && continue
    # Pular HEAD simbolico
    [[ "$branch" == "HEAD" ]] && continue

    TOTAL_BRANCHES=$((TOTAL_BRANCHES + 1))

    # Ultimo commit
    LAST_COMMIT_DATE=$(git log -1 --format=%cd --date=short "$branch" 2>/dev/null || echo "unknown")
    if [ "$LAST_COMMIT_DATE" = "unknown" ]; then
        continue
    fi

    COMMIT_EPOCH=$(date -d "$LAST_COMMIT_DATE" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$LAST_COMMIT_DATE" +%s 2>/dev/null || echo "0")
    DAYS_STALE=$(( (TODAY_EPOCH - COMMIT_EPOCH) / 86400 ))

    # Verificar se e stale
    if [ "$DAYS_STALE" -lt "$STALE_DAYS" ]; then
        continue
    fi

    # Verificar se esta merged
    IS_MERGED=false
    if git merge-base --is-merged "$branch" "$BASE_BRANCH" 2>/dev/null; then
        IS_MERGED=true
    fi

    # Filtrar por merged/unmerged
    if [ "$SHOW_MERGED" = "merged" ] && [ "$IS_MERGED" = false ]; then
        continue
    fi
    if [ "$SHOW_MERGED" = "unmerged" ] && [ "$IS_MERGED" = true ]; then
        continue
    fi

    # Commits ahead/behind
    COMMITS_AHEAD=$(git rev-list --count "$BASE_BRANCH..$branch" 2>/dev/null || echo "0")
    COMMITS_BEHIND=$(git rev-list --count "$branch..$BASE_BRANCH" 2>/dev/null || echo "0")
    AUTHOR=$(git log -1 --format=%an "$branch" 2>/dev/null || echo "unknown")

    if [ "$IS_MERGED" = true ]; then
        MERGED_COUNT=$((MERGED_COUNT + 1))
    else
        UNMERGED_COUNT=$((UNMERGED_COUNT + 1))
    fi

    STALE_BRANCHES+=("$branch|$LAST_COMMIT_DATE|$DAYS_STALE|$IS_MERGED|$AUTHOR|$COMMITS_AHEAD|$COMMITS_BEHIND")
done < <(git for-each-ref --format='%(refname:short)' refs/heads/ 2>/dev/null)

# --- Gerar sugestoes ---
SUGGESTIONS=()
if [ "$MERGED_COUNT" -gt 0 ]; then
    SUGGESTIONS+=("${MERGED_COUNT} branches merged podem ser deletadas")
fi
if [ "$UNMERGED_COUNT" -gt 0 ]; then
    SUGGESTIONS+=("${UNMERGED_COUNT} branches unmerged precisam de review")
fi

# --- Modo JSON ---
if [[ "$JSON_MODE" == true ]]; then
    echo "{"
    echo "  \"status\": \"ok\","
    echo "  \"repository\": \"$REPO_NAME\","
    echo "  \"current_branch\": \"$CURRENT_BRANCH\","
    echo "  \"total_branches\": $TOTAL_BRANCHES,"

    echo "  \"stale_branches\": ["
    FIRST=true
    for entry in "${STALE_BRANCHES[@]}"; do
        IFS='|' read -r name last_date days stale merged author ahead behind <<< "$entry"
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi
        MERGED_BOOL="false"
        [ "$merged" = "true" ] && MERGED_BOOL="true"
        printf '    {"name": "%s", "last_commit": "%s", "days_stale": %d, "merged": %s, "author": "%s", "commits_ahead": %d, "commits_behind": %d}' \
            "$name" "$last_date" "$days" "$MERGED_BOOL" "$author" "$ahead" "$behind"
    done
    echo ""
    echo "  ],"

    echo "  \"stale_count\": ${#STALE_BRANCHES[@]},"
    echo "  \"merged_stale\": $MERGED_COUNT,"
    echo "  \"unmerged_stale\": $UNMERGED_COUNT,"

    echo "  \"suggestions\": ["
    FIRST=true
    for sug in "${SUGGESTIONS[@]}"; do
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            echo ","
        fi
        printf '    "%s"' "$sug"
    done
    if [ "$FIRST" = true ]; then
        echo '    "Nenhuma branch stale encontrada"'
    fi
    echo ""
    echo "  ]"
    echo "}"
    exit 0
fi

# --- Saida para humano ---
echo ""
echo -e "  ${BOLD}Git Stale Branches${RESET} — ${CYAN}$REPO_NAME${RESET}"
echo -e "  ${DIM}Referencia: $BASE_BRANCH | Branch atual: $CURRENT_BRANCH${RESET}"
echo ""

if [ "${#STALE_BRANCHES[@]}" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Nenhuma branch stale encontrada (ultimos $STALE_DAYS dias)${RESET}"
    echo ""
    exit 0
fi

echo -e "  ${BOLD}Branches stale (${#STALE_BRANCHES[@]} de $TOTAL_BRANCHES):${RESET}"
echo ""

for entry in "${STALE_BRANCHES[@]}"; do
    IFS='|' read -r name last_date days merged author ahead behind <<< "$entry"

    if [ "$merged" = "true" ]; then
        ICON="${GREEN}✓${RESET}"
        TAG="${GREEN}[merged]${RESET}"
    else
        ICON="${YELLOW}!${RESET}"
        TAG="${YELLOW}[unmerged]${RESET}"
    fi

    echo -e "  $ICON ${BOLD}$name${RESET} $TAG"
    echo -e "    ${DIM}Ultimo commit: $last_date ($days dias) | Autor: $author${RESET}"
    if [ "$ahead" -gt 0 ] || [ "$behind" -gt 0 ]; then
        echo -e "    ${DIM}Ahead: $ahead | Behind: $behind${RESET}"
    fi
    echo ""
done

echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  ${GREEN}✓${RESET} Merged stale:   ${GREEN}${BOLD}$MERGED_COUNT${RESET}"
echo -e "  ${YELLOW}!${RESET} Unmerged stale: ${YELLOW}${BOLD}$UNMERGED_COUNT${RESET}"
echo ""

for sug in "${SUGGESTIONS[@]}"; do
    echo -e "  ${CYAN}→${RESET} $sug"
done
echo ""

# --- Delecao ---
if [ "$DO_DELETE" = true ] && [ "${#STALE_BRANCHES[@]}" -gt 0 ]; then
    if [ "$FORCE_DELETE" = false ]; then
        echo -e "  ${YELLOW}ATENCAO: Ira deletar ${#STALE_BRANCHES[@]} branch(es) stale(s)${RESET}"
        if [ -t 0 ]; then
            read -r -p "  Confirmar delecao? [s/N] " CONFIRM < /dev/tty 2>/dev/null || CONFIRM="n"
        else
            error "Execucao nao interativa detectada. Use --force para deletar sem confirmacao."
        fi
        if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
            echo -e "  ${DIM}Operacao cancelada.${RESET}"
            exit 0
        fi
    fi

    echo ""
    echo -e "  ${BOLD}Deletando branches stale:${RESET}"

    for entry in "${STALE_BRANCHES[@]}"; do
        IFS='|' read -r name last_date days merged author ahead behind <<< "$entry"

        if [ "$merged" = "true" ]; then
            if git branch -d "$name" 2>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} Deletada (merged): $name"
            else
                echo -e "  ${RED}✗${RESET} Falha ao deletar: $name"
            fi
        else
            if [ "$FORCE_DELETE" = true ]; then
                if git branch -D "$name" 2>/dev/null; then
                    echo -e "  ${YELLOW}!${RESET} Deletada (force): $name"
                else
                    echo -e "  ${RED}✗${RESET} Falha ao deletar: $name"
                fi
            else
                echo -e "  ${YELLOW}△${RESET} Pulada (unmerged): $name — use --force para deletar"
            fi
        fi
    done
    echo ""
fi
