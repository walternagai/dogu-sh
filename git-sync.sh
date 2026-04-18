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
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
DO_PUSH=false
DO_FETCH_ONLY=false
DO_COMMIT=false
CLEAN_ALL=false
MAX_DEPTH=5
POSITIONAL_ARGS=()

COMMIT_TAGS="feat fix docs style refactor perf test chore"

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --push|-p) DO_PUSH=true; shift ;;
        --fetch|-f) DO_FETCH_ONLY=true; shift ;;
        --commit|-C) DO_COMMIT=true; shift ;;
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
            echo "    --commit        Oferece commit para repos modificados"
            echo "    --all           Executa sem confirmacao"
            echo "    --depth N       Profundidade maxima de busca (padrao: 5)"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./git-sync.sh ~/Projects"
            echo "    ./git-sync.sh --dry-run --fetch ~/repos"
            echo "    ./git-sync.sh --push --all ."
            echo "    ./git-sync.sh --commit ~/Projects"
            echo ""
            echo "  Tags de commit disponiveis:"
            echo "    feat fix docs style refactor perf test chore"
            echo ""
            echo "  Variavel de ambiente:"
            echo "    OLLAMA_DEFAULT_MODEL  Modelo padrao do Ollama (ex: llama3, mistral)"
            echo ""
            exit 0
            ;;
        --version|-v) echo "git-sync.sh $VERSION"; exit 0 ;;
        -*) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
        *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
done

check_ollama_model() {
    if ! command -v ollama &>/dev/null; then
        return 1
    fi
    local ollama_list_output
    ollama_list_output=$(ollama list 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "  ${YELLOW}Aviso: Ollama instalado mas nao esta em execucao.${RESET}" >&2
        return 1
    fi
    if [ -n "$OLLAMA_DEFAULT_MODEL" ]; then
        OLLAMA_MODEL="$OLLAMA_DEFAULT_MODEL"
    else
        echo ""
        echo -e "  ${BOLD}Modelos Ollama disponiveis:${RESET}"
        models=$(echo "$ollama_list_output" | tail -n +2 | awk '{print "    - " $1}')
        if [ -n "$models" ]; then
            echo "$models"
        else
            echo "    (nenhum modelo encontrado)"
        fi
        echo ""
        printf "  Informe o modelo padrao para commits: "
        read -r OLLAMA_MODEL < /dev/tty 2>/dev/null || OLLAMA_MODEL=""
        if [ -z "$OLLAMA_MODEL" ]; then
            echo -e "  ${RED}Erro: Nenhum modelo informado.${RESET}" >&2
            return 1
        fi
        OLLAMA_DEFAULT_MODEL="$OLLAMA_MODEL"
    fi
    return 0
}

generate_commit_message() {
    local diff_output
    diff_output=$(git diff --stat 2>/dev/null)
    local diff_full
    local diff_raw diff_line_count
    diff_raw=$(git diff 2>/dev/null)
    diff_line_count=$(echo "$diff_raw" | wc -l | tr -d ' ')
    if [ "$diff_line_count" -gt 200 ]; then
        diff_full=$(echo "$diff_raw" | awk 'NR<=200{lines[NR]=$0; if(/^@@/) last_hunk=NR} END{for(i=1;i<=last_hunk;i++) print lines[i]}')
    else
        diff_full="$diff_raw"
    fi

    if command -v ollama &>/dev/null && [ -n "$OLLAMA_MODEL" ]; then
        echo -e "    ${DIM}→ Gerando commit com Ollama ($OLLAMA_MODEL)...${RESET}" >&2
        local prompt
        prompt="Analyze this git diff and generate a concise commit message using Conventional Commits format. Use one of these tags: feat, fix, docs, style, refactor, perf, test, chore. Format: tag: description. Return ONLY the commit message, nothing else. Diff stats: ${diff_output}. Diff: ${diff_full}"
        local msg
        if command -v curl &>/dev/null && command -v jq &>/dev/null; then
            local ollama_host="${OLLAMA_HOST:-http://127.0.0.1:11434}"
            local json_prompt
            json_prompt=$(printf '%s' "$prompt" | jq -Rs .)
            local response
            response=$(curl -s --max-time 120 "$ollama_host/api/generate" \
                -d "{\"model\":\"$OLLAMA_MODEL\",\"prompt\":$json_prompt,\"stream\":false}" 2>/dev/null) || true
            msg=$(echo "$response" | jq -r '.response // empty' 2>/dev/null | head -5 | sed '/^$/d' | head -1) || true
        else
            msg=$(ollama run "$OLLAMA_MODEL" --hidethinking "$prompt" 2>/dev/null | head -5 | sed '/^$/d' | head -1) || true
        fi
        if [ -n "$msg" ]; then
            msg=$(echo "$msg" | sed 's/^[`"'"'"']//;s/[`"'"'"']$//' | head -c 200)
            echo -e "    ${GREEN}Mensagem sugerida:${RESET} $msg" >&2
            printf "    Usar esta mensagem? [S/n/e=editar]: " >&2
            read -r choice < /dev/tty 2>/dev/null || choice="s"
            case "$choice" in
                [nN]*)
                    echo -e "    ${BOLD}Tags disponiveis:${RESET} $COMMIT_TAGS" >&2
                    printf "    Digite a mensagem de commit: " >&2
                    read -r msg < /dev/tty 2>/dev/null || msg=""
                    ;;
                [eE]*)
                    printf "    Edite a mensagem: " >&2
                    read -r -e -i "$msg" msg < /dev/tty 2>/dev/null || msg="$msg"
                    ;;
            esac
            echo "$msg"
        else
            echo -e "    ${YELLOW}Ollama nao retornou mensagem.${RESET}" >&2
            echo -e "    ${BOLD}Tags disponiveis:${RESET} $COMMIT_TAGS" >&2
            printf "    Digite a mensagem de commit: " >&2
            read -r msg < /dev/tty 2>/dev/null || msg=""
            echo "$msg"
        fi
    else
        echo -e "    ${BOLD}Tags de commit:${RESET} $COMMIT_TAGS" >&2
        printf "    Digite a mensagem de commit: " >&2
        read -r msg < /dev/tty 2>/dev/null || msg=""
        echo "$msg"
    fi
}



resolve_merge_conflicts() {
    local conflicted
    conflicted=$(git diff --name-only --diff-filter=U 2>/dev/null)
    if [ -z "$conflicted" ]; then
        return 0
    fi

    local file_count
    file_count=$(echo "$conflicted" | wc -l | tr -d ' ')
    echo -e "    ${RED}${file_count} arquivo(s) com conflito:${RESET}"
    echo "$conflicted" | while IFS= read -r f; do
        echo -e "      ${RED}•${RESET} $f"
    done
    echo ""

    while true; do
        echo -e "    ${BOLD}Opcoes de resolucao:${RESET}"
        echo -e "      ${CYAN}1${RESET} Aceitar versao local   (ours)"
        echo -e "      ${CYAN}2${RESET} Aceitar versao remota  (theirs)"
        echo -e "      ${CYAN}3${RESET} Abrir editor           (\$EDITOR)"
        echo -e "      ${CYAN}4${RESET} Resolver arquivo por arquivo"
        echo -e "      ${CYAN}0${RESET} Abortar e sair"
        echo ""
        printf "    Escolha [0-4]: "
        read -r choice < /dev/tty 2>/dev/null || choice="0"

        case "$choice" in
            1)
                echo "$conflicted" | while IFS= read -r f; do
                    git checkout --ours -- "$f" 2>/dev/null
                    git add -- "$f" 2>/dev/null
                    echo -e "      ${GREEN}✓${RESET} nosso: $f"
                done
                return 0
                ;;
            2)
                echo "$conflicted" | while IFS= read -r f; do
                    git checkout --theirs -- "$f" 2>/dev/null
                    git add -- "$f" 2>/dev/null
                    echo -e "      ${GREEN}✓${RESET} remoto: $f"
                done
                return 0
                ;;
            3)
                local editor="${EDITOR:-nano}"
                echo "$conflicted" | while IFS= read -r f; do
                    $editor "$f" < /dev/tty
                    git add -- "$f" 2>/dev/null
                    echo -e "      ${GREEN}✓${RESET} editado: $f"
                done
                remaining=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')
                if [ "$remaining" -gt 0 ]; then
                    echo -e "    ${YELLOW}Ainda ha ${remaining} conflito(s) nao resolvido(s).${RESET}"
                    continue
                fi
                return 0
                ;;
            4)
                echo "$conflicted" | while IFS= read -r f; do
                    echo ""
                    echo -e "      ${BOLD}Arquivo:${RESET} $f"
                    echo -e "        ${CYAN}o${RESET}) ours   ${CYAN}t${RESET}) theirs   ${CYAN}e${RESET}) editor   ${CYAN}s${RESET}) pular"
                    printf "        Resolucao para $f: "
                    read -r fchoice < /dev/tty 2>/dev/null || fchoice="s"
                    case "$fchoice" in
                        [oO])
                            git checkout --ours -- "$f" 2>/dev/null
                            git add -- "$f" 2>/dev/null
                            echo -e "        ${GREEN}✓${RESET} nosso: $f"
                            ;;
                        [tT])
                            git checkout --theirs -- "$f" 2>/dev/null
                            git add -- "$f" 2>/dev/null
                            echo -e "        ${GREEN}✓${RESET} remoto: $f"
                            ;;
                        [eE])
                            local editor="${EDITOR:-nano}"
                            $editor "$f" < /dev/tty
                            git add -- "$f" 2>/dev/null
                            echo -e "        ${GREEN}✓${RESET} editado: $f"
                            ;;
                        *)
                            echo -e "        ${DIM}Pulado: $f${RESET}"
                            ;;
                    esac
                done
                remaining=$(git diff --name-only --diff-filter=U 2>/dev/null | wc -l | tr -d ' ')
                if [ "$remaining" -gt 0 ]; then
                    echo -e "    ${YELLOW}Ainda ha ${remaining} conflito(s) nao resolvido(s).${RESET}"
                    continue
                fi
                return 0
                ;;
            *)
                echo -e "    ${RED}Abortando resolucao de conflitos.${RESET}"
                git rebase --abort 2>/dev/null || git merge --abort 2>/dev/null || true
                return 1
                ;;
        esac
    done
}

resolve_diverged_repo() {
    local repo_name="$1"
    local branch="$2"
    local ahead="$3"
    local behind="$4"

    echo -e "    ${RED}Repositorio divergiu: +${ahead} local / -${behind} remoto${RESET}"
    echo -e "    ${BOLD}Opcoes:${RESET}"
    echo -e "      ${CYAN}1${RESET} Rebase (reaplicar commits locais sobre remoto)"
    echo -e "      ${CYAN}2${RESET} Merge  (criar merge commit)"
    echo -e "      ${CYAN}3${RESET} Reset  (descartar commits locais, usar remoto)"
    echo -e "      ${CYAN}0${RESET} Pular este repositorio"
    echo ""
    printf "    Escolha [0-3]: "
    read -r choice < /dev/tty 2>/dev/null || choice="0"

    case "$choice" in
        1)
            echo -e "    ${DIM}→ git pull --rebase${RESET}"
            if ! git pull --rebase 2>/dev/null; then
                if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                    echo -e "    ${YELLOW}Conflitos durante rebase. Resolvendo...${RESET}"
                    if ! resolve_merge_conflicts; then
                        return 1
                    fi
                    if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                        echo -e "    ${RED}Ainda ha conflitos apos resolucao. Abortando.${RESET}"
                        git rebase --abort 2>/dev/null || true
                        return 1
                    fi
                    git rebase --continue 2>/dev/null
                    if [ $? -ne 0 ]; then
                        echo -e "    ${RED}Falha ao continuar rebase. Abortando.${RESET}"
                        git rebase --abort 2>/dev/null || true
                        return 1
                    fi
                else
                    echo -e "    ${RED}Falha no rebase sem conflitos de arquivo. Abortando.${RESET}"
                    git rebase --abort 2>/dev/null || true
                    return 1
                fi
            fi
            echo -e "    ${GREEN}✓ rebase concluido${RESET}"
            return 0
            ;;
        2)
            echo -e "    ${DIM}→ git pull (merge)${RESET}"
            if ! git pull --no-rebase 2>/dev/null; then
                if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                    echo -e "    ${YELLOW}Conflitos durante merge. Resolvendo...${RESET}"
                    if ! resolve_merge_conflicts; then
                        return 1
                    fi
                    if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                        echo -e "    ${RED}Ainda ha conflitos apos resolucao. Abortando.${RESET}"
                        git merge --abort 2>/dev/null || true
                        return 1
                    fi
                    git commit --no-edit 2>/dev/null
                else
                    echo -e "    ${RED}Falha no merge sem conflitos de arquivo. Abortando.${RESET}"
                    git merge --abort 2>/dev/null || true
                    return 1
                fi
            fi
            echo -e "    ${GREEN}✓ merge concluido${RESET}"
            return 0
            ;;
        3)
            echo -e "    ${RED}ATENCAO: Isso descartara ${ahead} commit(s) local(is)!${RESET}"
            printf "    Confirmar reset para remoto? [s/N]: "
            read -r confirm < /dev/tty 2>/dev/null || confirm="n"
            case "$confirm" in
                [sS])
                    git reset --hard "@{upstream}" 2>/dev/null
                    echo -e "    ${GREEN}✓ resetado para remoto${RESET}"
                    return 0
                    ;;
                *)
                    echo -e "    ${DIM}Reset cancelado.${RESET}"
                    return 2
                    ;;
            esac
            ;;
        *)
            echo -e "    ${DIM}Repositorio pulado.${RESET}"
            return 2
            ;;
    esac
}

count_diverged=0

if $DO_COMMIT || ($DO_PUSH && $CLEAN_ALL); then
    check_ollama_model
    ollama_rc=$?
    if [ "$ollama_rc" -eq 0 ]; then
        echo -e "  ${GREEN}Ollama disponivel${RESET} — modelo: ${CYAN}$OLLAMA_MODEL${RESET}"
    else
        echo -e "  ${YELLOW}Ollama nao disponivel${RESET} — commit sera manual"
    fi
    echo -e "  ${BOLD}Tags de commit:${RESET} $COMMIT_TAGS"
fi

BASE_DIR="${POSITIONAL_ARGS[0]:-.}"
BASE_DIR="${BASE_DIR%/}"
BASE_DIR="$(cd "$BASE_DIR" && pwd)"

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
count_error=0

while IFS= read -r repo_path; do
    [ -z "$repo_path" ] && continue

    repo_name="${repo_path#$BASE_DIR/}"
    repo_name="${repo_name#$BASE_DIR}"

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
            if $DO_COMMIT && ! $DRY_RUN && ! $DO_FETCH_ONLY; then
                if $CLEAN_ALL; then
                    commit_msg=$(generate_commit_message)
                    if [ -n "$commit_msg" ]; then
                        git add -A 2>/dev/null
                        git commit -m "$commit_msg" 2>/dev/null && \
                            echo -e "    ${GREEN}✓ commit: ${DIM}${commit_msg}${RESET}" || \
                            echo -e "    ${RED}✗ falha no commit${RESET}"
                    fi
                else
                    printf "    Fazer commit de %s alteracao(oes)? [s/N]: " "$dirty"
                    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                    case "$confirm" in
                        [sS])
                            commit_msg=$(generate_commit_message)
                            if [ -n "$commit_msg" ]; then
                                git add -A 2>/dev/null
                                git commit -m "$commit_msg" 2>/dev/null && \
                                    echo -e "    ${GREEN}✓ commit: ${DIM}${commit_msg}${RESET}" || \
                                    echo -e "    ${RED}✗ falha no commit${RESET}"
                            else
                                echo -e "    ${YELLOW}Commit cancelado (mensagem vazia).${RESET}"
                            fi
                            ;;
                    esac
                fi
            fi
            count_dirty=$((count_dirty + 1))
        else
            echo -e "  ${DIM}○${RESET} $repo_name  ${DIM}[$branch] (sem remote)${RESET}"
            count_clean=$((count_clean + 1))
        fi
        continue
    fi

    dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    # Resolve upstream tracking ref explicitly (evita falha silenciosa de @{upstream})
    upstream_ref=$(git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>/dev/null)
    if [ -z "$upstream_ref" ] || [ "$upstream_ref" = "@{upstream}" ]; then
        _remote=$(git config "branch.${branch}.remote" 2>/dev/null || echo "")
        _merge=$(git config "branch.${branch}.merge" 2>/dev/null || echo "")
        if [ -n "$_remote" ] && [ -n "$_merge" ]; then
            upstream_ref="${_remote}/${_merge#refs/heads/}"
        fi
    fi

    if [ -n "$upstream_ref" ] && git rev-parse "$upstream_ref" &>/dev/null; then
        ahead=$(git rev-list --count "${upstream_ref}..HEAD" 2>/dev/null || echo 0)
        behind=$(git rev-list --count "HEAD..${upstream_ref}" 2>/dev/null || echo 0)
    else
        ahead=0
        behind=0
    fi

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
        echo -e "  ${RED}↕${RESET} $repo_name  ${DIM}[$branch]${RESET}  ${RED}divergiu (+${ahead}/-${behind})${RESET}"
        count_diverged=$((count_diverged + 1))
        if ! $DRY_RUN && ! $DO_FETCH_ONLY; then
            if $CLEAN_ALL; then
                echo -e "    ${DIM}→ tentando rebase automatico${RESET}"
                if ! git pull --rebase 2>/dev/null; then
                    if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                        echo -e "    ${RED}Conflitos no rebase. Use modo interativo para resolver.${RESET}"
                        echo -e "    ${RED}Execute: ./git-sync.sh $BASE_DIR${RESET}"
                        echo ""
                        exit 1
                    else
                        git rebase --abort 2>/dev/null || true
                        echo -e "    ${RED}Falha no rebase. Abortando.${RESET}"
                        echo ""
                        exit 1
                    fi
                fi
                echo -e "    ${GREEN}  ✓ rebase concluido${RESET}"
            else
                resolve_diverged_repo "$repo_name" "$branch" "$ahead" "$behind"
                resolve_result=$?
                if [ "$resolve_result" -eq 1 ]; then
                    echo ""
                    exit 1
                fi
            fi
        fi
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

    if [ "$dirty" -gt 0 ] && ($DO_COMMIT || ($DO_PUSH && $CLEAN_ALL)) && ! $DRY_RUN && ! $DO_FETCH_ONLY; then
        if $CLEAN_ALL; then
            commit_msg=$(generate_commit_message)
            if [ -n "$commit_msg" ]; then
                git add -A 2>/dev/null
                if git commit -m "$commit_msg" 2>/dev/null; then
                    echo -e "    ${GREEN}✓ commit: ${DIM}${commit_msg}${RESET}"
                    if $DO_PUSH; then
                        echo -e "    ${DIM}→ git push${RESET}"
                        git push 2>/dev/null && \
                            echo -e "    ${GREEN}✓ enviado${RESET}" || \
                            echo -e "    ${RED}✗ falha no push${RESET}"
                    fi
                else
                    echo -e "    ${RED}✗ falha no commit${RESET}"
                fi
            fi
        else
            printf "    Fazer commit de %s alteracao(oes)? [s/N]: " "$dirty"
            read -r confirm < /dev/tty 2>/dev/null || confirm="n"
            case "$confirm" in
                [sS])
                    commit_msg=$(generate_commit_message)
                    if [ -n "$commit_msg" ]; then
                        git add -A 2>/dev/null
                        git commit -m "$commit_msg" 2>/dev/null && \
                            echo -e "    ${GREEN}✓ commit: ${DIM}${commit_msg}${RESET}" || \
                            echo -e "    ${RED}✗ falha no commit${RESET}"
                    else
                        echo -e "    ${YELLOW}Commit cancelado (mensagem vazia).${RESET}"
                    fi
                    ;;
            esac
        fi
    fi

    if $needs_action && ! $DRY_RUN && ! $DO_FETCH_ONLY; then
        if [ "$behind" -gt 0 ] && [ "$ahead" -eq 0 ]; then
            if $CLEAN_ALL; then
                echo -e "    ${DIM}→ git pull${RESET}"
                if ! git pull --ff-only 2>/dev/null; then
                    echo -e "    ${YELLOW}ff-only falhou. Tentando rebase...${RESET}"
                    if ! git pull --rebase 2>/dev/null; then
                        if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                            echo -e "    ${YELLOW}Conflitos durante rebase. Resolvendo...${RESET}"
                            if ! resolve_merge_conflicts; then
                                echo ""
                                exit 1
                            fi
                            if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                echo -e "    ${RED}Conflitos remanescentes. Abortando.${RESET}"
                                git rebase --abort 2>/dev/null || true
                                echo ""
                                exit 1
                            fi
                            git rebase --continue 2>/dev/null || true
                        else
                            echo -e "    ${RED}✗ CONFLITO: falha no pull de ${repo_name}${RESET}"
                            echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                            echo ""
                            exit 1
                        fi
                    fi
                    echo -e "    ${GREEN}  ✓ atualizado via rebase${RESET}"
                else
                    echo -e "    ${GREEN}  ✓ atualizado${RESET}"
                fi
            else
                printf "    Puxar atualizacoes? [s/N]: "
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS])
                        if ! git pull --ff-only 2>/dev/null; then
                            echo -e "    ${YELLOW}ff-only falhou. Tentando rebase...${RESET}"
                            if ! git pull --rebase 2>/dev/null; then
                                if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                    echo -e "    ${YELLOW}Conflitos durante rebase. Resolvendo...${RESET}"
                                    if ! resolve_merge_conflicts; then
                                        echo ""
                                        exit 1
                                    fi
                                    if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                        echo -e "    ${RED}Conflitos remanescentes. Abortando.${RESET}"
                                        git rebase --abort 2>/dev/null || true
                                        echo ""
                                        exit 1
                                    fi
                                    git rebase --continue 2>/dev/null || true
                                    echo -e "    ${GREEN}  ✓ atualizado via rebase${RESET}"
                                else
                                    echo -e "    ${RED}✗ CONFLITO: falha no pull de ${repo_name}${RESET}"
                                    echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                                    echo ""
                                    exit 1
                                fi
                            else
                                echo -e "    ${GREEN}  ✓ atualizado via rebase${RESET}"
                            fi
                        else
                            echo -e "    ${GREEN}  ✓ atualizado${RESET}"
                        fi
                        ;;
                esac
            fi
        elif [ "$ahead" -gt 0 ] && [ "$behind" -eq 0 ] && $DO_PUSH; then
            if $CLEAN_ALL; then
                echo -e "    ${DIM}→ git push${RESET}"
                if ! git push 2>/dev/null; then
                    echo -e "    ${YELLOW}Push rejeitado. Tentando pull --rebase...${RESET}"
                    if git pull --rebase 2>/dev/null; then
                        echo -e "    ${DIM}→ retry git push${RESET}"
                        if ! git push 2>/dev/null; then
                            echo -e "    ${RED}✗ CONFLITO: falha no push de ${repo_name} apos rebase${RESET}"
                            echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                            echo ""
                            exit 1
                        fi
                        echo -e "    ${GREEN}  ✓ enviado via rebase${RESET}"
                    else
                        if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                            echo -e "    ${YELLOW}Conflitos durante rebase. Resolvendo...${RESET}"
                            if ! resolve_merge_conflicts; then
                                echo ""
                                exit 1
                            fi
                            if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                echo -e "    ${RED}Conflitos remanescentes. Abortando.${RESET}"
                                git rebase --abort 2>/dev/null || true
                                echo ""
                                exit 1
                            fi
                            git rebase --continue 2>/dev/null || true
                            echo -e "    ${DIM}→ retry git push${RESET}"
                            if ! git push 2>/dev/null; then
                                echo -e "    ${RED}✗ CONFLITO: falha no push de ${repo_name} apos resolucao${RESET}"
                                echo ""
                                exit 1
                            fi
                            echo -e "    ${GREEN}  ✓ enviado apos resolucao${RESET}"
                        else
                            echo -e "    ${RED}✗ CONFLITO: falha no push de ${repo_name}${RESET}"
                            echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                            echo ""
                            exit 1
                        fi
                    fi
                else
                    echo -e "    ${GREEN}  ✓ enviado${RESET}"
                fi
            else
                printf "    Enviar commits? [s/N]: "
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS])
                        if ! git push 2>/dev/null; then
                            echo -e "    ${YELLOW}Push rejeitado. Tentando pull --rebase...${RESET}"
                            if git pull --rebase 2>/dev/null; then
                                echo -e "    ${DIM}→ retry git push${RESET}"
                                if ! git push 2>/dev/null; then
                                    echo -e "    ${RED}✗ CONFLITO: falha no push de ${repo_name}apos rebase${RESET}"
                                    echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                                    echo ""
                                    exit 1
                                fi
                                echo -e "    ${GREEN}  ✓ enviado via rebase${RESET}"
                            else
                                if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                    echo -e "    ${YELLOW}Conflitos durante rebase. Resolvendo...${RESET}"
                                    if ! resolve_merge_conflicts; then
                                        echo ""
                                        exit 1
                                    fi
                                    if git diff --name-only --diff-filter=U 2>/dev/null | grep -q .; then
                                        echo -e "    ${RED}Conflitos remanescentes. Abortando.${RESET}"
                                        git rebase --abort 2>/dev/null || true
                                        echo ""
                                        exit 1
                                    fi
                                    git rebase --continue 2>/dev/null || true
                                    echo -e "    ${DIM}→ retry git push${RESET}"
                                    if ! git push 2>/dev/null; then
                                        echo -e "    ${RED}✗ CONFLITO: falha no push apos resolucao${RESET}"
                                        echo ""
                                        exit 1
                                    fi
                                    echo -e "    ${GREEN}  ✓ enviado apos resolucao${RESET}"
                                else
                                    echo -e "    ${RED}✗ CONFLITO: falha no push de ${repo_name}${RESET}"
                                    echo -e "    ${RED}Resolva o conflito manualmente.${RESET}"
                                    echo ""
                                    exit 1
                                fi
                            fi
                        else
                            echo -e "    ${GREEN}  ✓ enviado${RESET}"
                        fi
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
if [ "$count_diverged" -gt 0 ]; then
    echo -e "  ${RED}↕${RESET} Divergidos:     ${RED}${BOLD}$count_diverged${RESET}"
fi

if [ "$count_error" -gt 0 ]; then
    echo -e "  ${RED}✗${RESET} Erros:          ${RED}${BOLD}$count_error${RESET}"
fi

echo "  ─────────────────────────────────"

if $DO_PUSH; then
    echo -e "  ${DIM}Dica: use --push --all para sincronizar tudo automaticamente.${RESET}"
fi

if $DO_COMMIT; then
    echo -e "  ${DIM}Dica: use --commit --all para commitar tudo automaticamente.${RESET}"
fi

echo ""