#!/bin/bash
# git-sync.sh — Sincroniza multiplos repositorios git (Linux)
# Uso: ./git-sync.sh [diretorio-base]
# Opcoes:
#   --dry-run       Preview sem fazer fetch/pull/push
#   --push          Faz push apos pull (apenas repos sem conflito)
#   --fetch         Apenas fetch, sem pull/push
#   --all           Executa sem confirmacao
#   --depth N       Profundidade maxima de busca (padrao: 5)
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "git" "$INSTALLER git"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
DO_PUSH=false
DO_FETCH_ONLY=false
CLEAN_ALL=false
MAX_DEPTH=5
POSITIONAL_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --push|-p) DO_PUSH=true; shift ;;
        --fetch|-f) DO_FETCH_ONLY=true; shift ;;
        --all|-a) CLEAN_ALL=true; shift ;;
        --depth) MAX_DEPTH="${2:-5}"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  git-sync.sh — Sincroniza multiplos repositorios git"
            echo ""
            echo "  Uso: ./git-sync.sh [opcoes] [diretorio-base]"
            echo ""
            echo "  Argumentos:"
            echo "    diretorio-base  Diretorio para buscar repos (padrao: .)"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run       Preview sem fazer fetch/pull/push"
            echo "    --push          Faz push apos pull (apenas se sem conflito)"
            echo "    --fetch         Apenas fetch, sem pull/push"
            echo "    --all           Executa sem confirmacao"
            echo "    --depth N       Profundidade maxima de busca (padrao: 5)"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./git-sync.sh ~/Projects"
            echo "    ./git-sync.sh --dry-run --fetch ~/repos"
            echo "    ./git-sync.sh --push --all ."
            echo ""
            exit 0
            ;;
        --version|-v) echo "git-sync.sh $VERSION"; exit 0 ;;
        -*) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

BASE_DIR="${POSITIONAL_ARGS[0]:-.}"
BASE_DIR="${BASE_DIR%/}"

if [ ! -d "$BASE_DIR" ]; then
    echo "Erro: '$BASE_DIR' nao e um diretorio valido." >&2
    exit 1
fi

TMPWORK=$(mktemp -d)
trap 'rm -rf "$TMPWORK"' EXIT

REPO_LIST="$TMPWORK/repos.txt"

find "$BASE_DIR" -maxdepth "$MAX_DEPTH" -name ".git" -type d 2>/dev/null | \
    sed 's/\/.git$//' | sort > "$REPO_LIST"

total_repos=$(wc -l < "$REPO_LIST" | tr -d ' ')

if [ "$total_repos" -eq 0 ]; then
    echo ""
    echo -e "  ${DIM}Nenhum repositorio git encontrado em $BASE_DIR${RESET}"
    echo ""
    exit 0
fi

echo ""
echo -e "  ${BOLD}Git Sync${RESET} — ${total_repos} repositorio(s) em ${CYAN}$BASE_DIR${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem alterar repos"
fi

echo ""

count_clean=0
count_dirty=0
count_ahead=0
count_behind=0
count_diverged=0
count_error=0

while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue

    repo_name=$(echo "$repo_path" | sed "s|$BASE_DIR/||" | sed "s|$BASE_DIR||")

    if ! cd "$repo_path" 2>/dev/null; then
        echo -e "  ${RED}✗${RESET} $repo_name  ${DIM}(erro ao acessar)${RESET}"
        count_error=$((count_error + 1))
        continue
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        continue
    fi

    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

    if [ "$branch" = "HEAD" ] || [ "$branch" = "detached" ]; then
        echo -e "  ${DIM}○${RESET} $repo_name  ${DIM}(detached HEAD)${RESET}"
        count_dirty=$((count_dirty + 1))
        continue
    fi

    if $DO_FETCH_ONLY || ! $DRY_RUN; then
        git fetch --all --prune 2>/dev/null || true
    fi

    has_remote=false
    if git config "branch.${branch}.remote" &>/dev/null; then
        has_remote=true
    fi

    if ! $has_remote; then
        dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [ "$dirty" -gt 0 ]; then
            echo -e "  ${YELLOW}■${RESET} $repo_name  ${DIM}[$branch] ${dirty} alteracao(oes) (sem remote)${RESET}"
            count_dirty=$((count_dirty + 1))
        else
            echo -e "  ${DIM}○${RESET} $repo_name  ${DIM}[$branch] (sem remote)${RESET}"
            count_clean=$((count_clean + 1))
        fi
        continue
    fi

    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null || echo 0)
    behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null || echo 0)

    ahead=$(echo "$ahead" | tr -d '[:space:]')
    behind=$(echo "$behind" | tr -d '[:space:]')

    if ! [[ "$ahead" =~ ^[0-9]+$ ]]; then ahead=0; fi
    if ! [[ "$behind" =~ ^[0-9]+$ ]]; then behind=0; fi

    status_icon=""
    status_detail=""
    needs_action=false

    if [ "$dirty" -gt 0 ]; then
        status_icon="${YELLOW}■${RESET}"
        status_detail="${YELLOW}+${dirty} alterado${RESET}"
        needs_action=false
        count_dirty=$((count_dirty + 1))
    elif [ "$ahead" -gt 0 ] && [ "$behind" -gt 0 ]; then
        status_icon="${RED}↕${RESET}"
        status_detail="${RED}divergiu (+${ahead}/-${behind})${RESET}"
        needs_action=false
        count_diverged=$((count_diverged + 1))
    elif [ "$ahead" -gt 0 ]; then
        status_icon="${CYAN}↑${RESET}"
        status_detail="${CYAN}+${ahead} nao enviado${RESET}"
        needs_action=true
        count_ahead=$((count_ahead + 1))
    elif [ "$behind" -gt 0 ]; then
        status_icon="${YELLOW}↓${RESET}"
        status_detail="${YELLOW}-${behind} atrasado${RESET}"
        needs_action=true
        count_behind=$((count_behind + 1))
    else
        status_icon="${GREEN}✓${RESET}"
        status_detail="${GREEN}atualizado${RESET}"
        count_clean=$((count_clean + 1))
    fi

    echo -e "  $status_icon $repo_name  ${DIM}[$branch]${RESET}  $status_detail"

    if $needs_action && ! $DRY_RUN && ! $DO_FETCH_ONLY; then
        if [ "$behind" -gt 0 ] && [ "$ahead" -eq 0 ]; then
            if $CLEAN_ALL; then
                echo -e "    ${DIM}→ git pull${RESET}"
                git pull --ff-only 2>/dev/null && \
                    echo -e "    ${GREEN}  ✓ atualizado${RESET}" || \
                    echo -e "    ${RED}  ✗ falha no pull${RESET}"
            else
                printf "    Puxar atualizacoes? [s/N]: "
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS]|[yY]*)
                        git pull --ff-only 2>/dev/null && \
                            echo -e "    ${GREEN}  ✓ atualizado${RESET}" || \
                            echo -e "    ${RED}  ✗ falha no pull${RESET}"
                        ;;
                esac
            fi
        elif [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ] && $DO_PUSH; then
            if $CLEAN_ALL; then
                echo -e "    ${DIM}→ git push${RESET}"
                git push 2>/dev/null && \
                    echo -e "    ${GREEN}  ✓ enviado${RESET}" || \
                    echo -e "    ${RED}  ✗ falha no push${RESET}"
            else
                printf "    Enviar commits? [s/N]: "
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS]|[yY]*)
                        git push 2>/dev/null && \
                            echo -e "    ${GREEN}  ✓ enviado${RESET}" || \
                            echo -e "    ${RED}  ✗ falha no push${RESET}"
                        ;;
                esac
            fi
        fi
    fi

done < "$REPO_LIST"

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  ${GREEN}✓${RESET} Atualizados:   ${GREEN}${BOLD}$count_clean${RESET}"
echo -e "  ${CYAN}↑${RESET} Nao enviado:   ${CYAN}${BOLD}$count_ahead${RESET}"
echo -e "  ${YELLOW}↓${RESET} Atrasados:     ${YELLOW}${BOLD}$count_behind${RESET}"
echo -e "  ${YELLOW}■${RESET} Modificados:   ${YELLOW}${BOLD}$count_dirty${RESET}"
echo -e "  ${RED}↕${RESET} Divergidos:     ${RED}${BOLD}$count_diverged${RESET}"

if [ "$count_error" -gt 0 ]; then
    echo -e "  ${RED}✗${RESET} Erros:          ${RED}${BOLD}$count_error${RESET}"
fi

echo "  ─────────────────────────────────"

if $DO_PUSH; then
    echo -e "  ${DIM}Dica: use --push --all para sincronizar tudo automaticamente.${RESET}"
fi

echo ""