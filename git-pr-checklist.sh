#!/bin/bash
# git-pr-checklist.sh — Checklist automatico antes de criar PR (Linux)
# Uso: ./git-pr-checklist.sh [opcoes]
# Opcoes:
#   --json          Saida em formato JSON
#   --project PATH  Caminho do repositorio (padrao: diretorio atual)
#   --branch BRANCH Branch a verificar (padrao: branch atual)
#   --fix           Tenta corrigir problemas automaticamente
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
BRANCH_NAME=""
DO_FIX=false

# --- Parse de argumentos ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_DIR="$2"; shift 2 ;;
        --branch|-b)
            [[ -z "${2-}" ]] && error "Flag --branch requer um valor"
            BRANCH_NAME="$2"; shift 2 ;;
        --fix|-f) DO_FIX=true; shift ;;
        --help|-h)
            echo ""
            echo "  git-pr-checklist.sh — Checklist automatico antes de criar PR"
            echo ""
            echo "  Uso: ./git-pr-checklist.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j            Saida em formato JSON"
            echo "    --project|-p PATH    Caminho do repositorio (padrao: diretorio atual)"
            echo "    --branch|-b BRANCH   Branch a verificar (padrao: branch atual)"
            echo "    --fix|-f             Tenta corrigir problemas automaticamente"
            echo "    --help|-h            Mostra esta ajuda"
            echo "    --version|-V         Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./git-pr-checklist.sh"
            echo "    ./git-pr-checklist.sh --json --branch feature-x"
            echo "    ./git-pr-checklist.sh --fix"
            echo ""
            exit 0
            ;;
        --version|-V) echo "git-pr-checklist.sh $SCRIPT_VERSION"; exit 0 ;;
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
[ -z "$BRANCH_NAME" ] && BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || error "Nao foi possivel detectar branch")

# Detectar branch principal
BASE_BRANCH=""
for candidate in main master mainline develop; do
    if git rev-parse --verify "$candidate" &>/dev/null 2>&1; then
        BASE_BRANCH="$candidate"
        break
    fi
done
[ -z "$BASE_BRANCH" ] && BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || true
[ -z "$BASE_BRANCH" ] && BASE_BRANCH="HEAD"

# --- Arrays de checks ---
CHECK_NAMES=()
CHECK_STATUS=()
CHECK_DETAILS=()
PASSED=0
FAILED=0
WARNINGS=0
SUGGESTIONS=()

add_check() {
    local name="$1" status="$2" detail="$3"
    CHECK_NAMES+=("$name")
    CHECK_STATUS+=("$status")
    CHECK_DETAILS+=("$detail")
    case "$status" in
        pass) PASSED=$((PASSED + 1)) ;;
        fail) FAILED=$((FAILED + 1)) ;;
        warn) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# --- Check 1: Branch atualizada com main ---
echo -e "  ${DIM}Verificando branch vs $BASE_BRANCH...${RESET}" >&2

if [ "$BRANCH_NAME" = "$BASE_BRANCH" ]; then
    add_check "Branch atualizada" "warn" "Branch e a principal ($BASE_BRANCH)"
else
    # Verificar se branch existe no remote
    if git rev-parse --verify "$BASE_BRANCH" &>/dev/null 2>&1; then
        git fetch origin "$BASE_BRANCH" 2>/dev/null || true
        if git merge-base --is-ancestor "$BASE_BRANCH" "$BRANCH_NAME" 2>/dev/null; then
            add_check "Branch atualizada" "pass" "Branch esta atualizada com $BASE_BRANCH"
        else
            add_check "Branch atualizada" "fail" "Branch esta atrasada com relacao a $BASE_BRANCH"
            SUGGESTIONS+=("Rebase/merge com $BASE_BRANCH: git rebase $BASE_BRANCH")
        fi
    else
        add_check "Branch atualizada" "warn" "Branch principal $BASE_BRANCH nao encontrada no remote"
    fi
fi

# --- Check 2: Testes passam ---
echo -e "  ${DIM}Verificando testes...${RESET}" >&2

TEST_CMD=""
TEST_PATH=""

# Detectar framework de teste
if [ -f "package.json" ]; then
    if grep -q '"test"' package.json 2>/dev/null; then
        TEST_CMD="npm test"
    fi
elif [ -f "pytest.ini" ] || [ -f "setup.cfg" ] || [ -f "pyproject.toml" ]; then
    TEST_CMD="python -m pytest"
elif [ -f "Makefile" ] && grep -q '^test:' Makefile 2>/dev/null; then
    TEST_CMD="make test"
elif [ -f "Cargo.toml" ]; then
    TEST_CMD="cargo test"
elif [ -f "go.mod" ]; then
    TEST_CMD="go test ./..."
fi

if [ -n "$TEST_CMD" ]; then
    TEST_OUTPUT=$(eval "$TEST_CMD" 2>&1) || true
    TEST_EXIT=$?
    if [ "$TEST_EXIT" -eq 0 ]; then
        TEST_COUNT=$(echo "$TEST_OUTPUT" | grep -oP '(\d+) passed' | head -1 | grep -oP '\d+' || echo "?")
        add_check "Testes passam" "pass" "${TEST_COUNT} testes passaram"
    else
        add_check "Testes passam" "fail" "Testes falharam (exit code: $TEST_EXIT)"
        SUGGESTIONS+=("Rodar: $TEST_CMD")
    fi
else
    # Tentar testes genericos
    if [ -d "tests" ] || [ -d "test" ] || [ -d "spec" ]; then
        add_check "Testes passam" "warn" "Diretorio de testes encontrado, mas framework nao detectado"
    else
        add_check "Testes passam" "warn" "Nenhum framework de teste detectado"
    fi
fi

# --- Check 3: Lint limpo ---
echo -e "  ${DIM}Verificando lint...${RESET}" >&2

LINT_CMD=""
if [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    LINT_CMD="npx eslint ."
elif [ -f "pyproject.toml" ] && grep -q 'ruff' pyproject.toml 2>/dev/null; then
    LINT_CMD="ruff check"
elif [ -f ".ruff.toml" ] || [ -f "ruff.toml" ]; then
    LINT_CMD="ruff check"
elif [ -f ".shellcheckrc" ] || command -v shellcheck &>/dev/null; then
    # Detectar scripts bash para shellcheck
    LINT_CMD="shellcheck -S warning"
fi

if [ -n "$LINT_CMD" ]; then
    LINT_OUTPUT=$(eval "$LINT_CMD" 2>&1) || true
    LINT_EXIT=$?
    if [ "$LINT_EXIT" -eq 0 ]; then
        add_check "Lint limpo" "pass" "Nenhum problema de lint encontrado"
    else
        LINT_COUNT=$(echo "$LINT_OUTPUT" | grep -cE '^(warning|error)' || echo "?")
        add_check "Lint limpo" "fail" "${LINT_COUNT} problemas encontrados"
        SUGGESTIONS+=("Rodar: $LINT_CMD --fix (se disponivel)")
    fi
else
    add_check "Lint limpo" "warn" "Nenhum linter configurado no projeto"
fi

# --- Check 4: Commits convencionais ---
echo -e "  ${DIM}Verificando formato dos commits...${RESET}" >&2

if [ "$BRANCH_NAME" != "$BASE_BRANCH" ] && git rev-parse --verify "$BASE_BRANCH" &>/dev/null 2>&1; then
    NON_CONVENTIONAL=0
    TOTAL_COMMITS=0
    while IFS= read -r msg; do
        [ -z "$msg" ] && continue
        TOTAL_COMMITS=$((TOTAL_COMMITS + 1))
        # Verificar formato: type(scope): desc ou type: desc
        if ! echo "$msg" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore|ci|build|revert)(\(.+\))?!?: '; then
            NON_CONVENTIONAL=$((NON_CONVENTIONAL + 1))
        fi
    done < <(git log "$BASE_BRANCH..$BRANCH_NAME" --pretty=format:"%s" 2>/dev/null)

    if [ "$TOTAL_COMMITS" -eq 0 ]; then
        add_check "Commits convencionais" "warn" "Nenhum commit novo para verificar"
    elif [ "$NON_CONVENTIONAL" -eq 0 ]; then
        add_check "Commits convencionais" "pass" "Todos os $TOTAL_COMMITS commits seguem formato conventional"
    else
        add_check "Commits convencionais" "warn" "$NON_CONVENTIONAL de $TOTAL_COMMITS commits sem formato conventional"
        SUGGESTIONS+=("Reescrever commits: git rebase -i $BASE_BRANCH")
    fi
else
    add_check "Commits convencionais" "warn" "Branch e a principal, sem commits para verificar"
fi

# --- Check 5: Docs atualizadas ---
echo -e "  ${DIM}Verificando documentacao...${RESET}" >&2

if [ "$BRANCH_NAME" != "$BASE_BRANCH" ] && git rev-parse --verify "$BASE_BRANCH" &>/dev/null 2>&1; then
    CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH..$BRANCH_NAME" 2>/dev/null || echo "")
    CODE_CHANGED=false
    DOCS_CHANGED=false

    while IFS= read -r file; do
        [ -z "$file" ] && continue
        # Verificar se mudou codigo (nao-docs)
        if echo "$file" | grep -qE '\.(sh|py|js|ts|jsx|tsx|go|rs|java|rb|c|cpp|h|hpp|cs)$'; then
            CODE_CHANGED=true
        fi
        # Verificar se mudou docs
        if echo "$file" | grep -qE '(README|CHANGELOG|docs/|\.md$|\.txt$)'; then
            DOCS_CHANGED=true
        fi
    done <<< "$CHANGED_FILES"

    if [ "$CODE_CHANGED" = true ] && [ "$DOCS_CHANGED" = false ]; then
        add_check "Docs atualizadas" "fail" "Codigo alterado mas documentacao nao atualizada"
        SUGGESTIONS+=("Atualizar README.md ou documentacao relevante")
    elif [ "$CODE_CHANGED" = true ] && [ "$DOCS_CHANGED" = true ]; then
        add_check "Docs atualizadas" "pass" "Documentacao atualizada junto com o codigo"
    elif [ "$CODE_CHANGED" = false ]; then
        add_check "Docs atualizadas" "pass" "Apenas arquivos de documentacao alterados"
    fi
else
    add_check "Docs atualizadas" "warn" "Branch principal — verificacao pulada"
fi

# --- Check 6: Branch protegida ---
echo -e "  ${DIM}Verificando branch protegida...${RESET}" >&2

PROTECTED_BRANCHES="main master mainline develop production release"
IS_PROTECTED=false
for pb in $PROTECTED_BRANCHES; do
    if [ "$BRANCH_NAME" = "$pb" ]; then
        IS_PROTECTED=true
        break
    fi
done

if [ "$IS_PROTECTED" = true ]; then
    add_check "Branch protegida" "fail" "Branch '$BRANCH_NAME' e uma branch protegida — crie uma branch de feature"
    SUGGESTIONS+=("Criar branch de feature: git checkout -b feature/nome-da-feature")
else
    add_check "Branch protegida" "pass" "Branch nao e protegida (ok para PR)"
fi

# --- Fix automatico ---
if [ "$DO_FIX" = true ]; then
    echo ""
    echo -e "  ${BOLD}Tentando correcoes automaticas:${RESET}"

    # Fix: rebase com main
    for i in "${!CHECK_NAMES[@]}"; do
        if [ "${CHECK_NAMES[$i]}" = "Branch atualizada" ] && [ "${CHECK_STATUS[$i]}" = "fail" ]; then
            echo -e "  ${DIM}→ Rebaseando com $BASE_BRANCH...${RESET}"
            if git rebase "$BASE_BRANCH" 2>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} Rebase concluido"
                CHECK_STATUS[$i]="pass"
                CHECK_DETAILS[$i]="Corrigido via rebase automatico"
                FAILED=$((FAILED - 1))
                PASSED=$((PASSED + 1))
            else
                echo -e "  ${RED}✗${RESET} Falha no rebase — resolva conflitos manualmente"
                git rebase --abort 2>/dev/null || true
            fi
        fi
    done

    # Fix: lint
    for i in "${!CHECK_NAMES[@]}"; do
        if [ "${CHECK_NAMES[$i]}" = "Lint limpo" ] && [ "${CHECK_STATUS[$i]}" = "fail" ]; then
            echo -e "  ${DIM}→ Rodando linter com --fix...${RESET}"
            if [ -n "$LINT_CMD" ]; then
                FIX_CMD=$(echo "$LINT_CMD" | sed 's/check/ --fix/check --fix/')
                if eval "$FIX_CMD" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${RESET} Lint corrigido"
                    CHECK_STATUS[$i]="pass"
                    CHECK_DETAILS[$i]="Corrigido via lint --fix"
                    FAILED=$((FAILED - 1))
                    PASSED=$((PASSED + 1))
                else
                    echo -e "  ${RED}✗${RESET} Alguns problemas nao puderam ser corrigidos automaticamente"
                fi
            fi
        fi
    done
fi

# --- Saida JSON ---
if [[ "$JSON_MODE" == true ]]; then
    READY_TO_MERGE=false
    [ "$FAILED" -eq 0 ] && READY_TO_MERGE=true

    echo "{"
    echo "  \"status\": \"ok\","
    echo "  \"repository\": \"$REPO_NAME\","
    echo "  \"branch\": \"$BRANCH_NAME\","
    echo "  \"checks\": ["

    for i in "${!CHECK_NAMES[@]}"; do
        if [ "$i" -gt 0 ]; then
            echo ","
        fi
        printf '    {"name": "%s", "status": "%s", "detail": "%s"}' \
            "${CHECK_NAMES[$i]}" "${CHECK_STATUS[$i]}" "${CHECK_DETAILS[$i]}"
    done
    echo ""
    echo "  ],"
    echo "  \"total_checks\": ${#CHECK_NAMES[@]},"
    echo "  \"passed\": $PASSED,"
    echo "  \"failed\": $FAILED,"
    echo "  \"warnings\": $WARNINGS,"
    echo "  \"ready_to_merge\": $READY_TO_MERGE,"

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
        echo '    "Nenhuma correcao necessaria"'
    fi
    echo ""
    echo "  ]"
    echo "}"
    exit 0
fi

# --- Saida para humano ---
echo ""
echo -e "  ${BOLD}PR Checklist${RESET} — ${CYAN}$REPO_NAME${RESET} @ ${CYAN}$BRANCH_NAME${RESET}"
echo -e "  ${DIM}Branch principal: $BASE_BRANCH${RESET}"
echo ""

for i in "${!CHECK_NAMES[@]}"; do
    case "${CHECK_STATUS[$i]}" in
        pass) echo -e "  ${GREEN}✓${RESET} ${CHECK_NAMES[$i]} ${DIM}— ${CHECK_DETAILS[$i]}${RESET}" ;;
        fail) echo -e "  ${RED}✗${RESET} ${CHECK_NAMES[$i]} ${RED}— ${CHECK_DETAILS[$i]}${RESET}" ;;
        warn) echo -e "  ${YELLOW}!${RESET} ${CHECK_NAMES[$i]} ${YELLOW}— ${CHECK_DETAILS[$i]}${RESET}" ;;
    esac
done

echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo -e "  ${BOLD}Resumo:${RESET}"
echo -e "  ${GREEN}✓${RESET} Passaram:    ${GREEN}${BOLD}$PASSED${RESET}"
echo -e "  ${RED}✗${RESET} Falharam:    ${RED}${BOLD}$FAILED${RESET}"
echo -e "  ${YELLOW}!${RESET} Avisos:      ${YELLOW}${BOLD}$WARNINGS${RESET}"
echo ""

if [ "${#SUGGESTIONS[@]}" -gt 0 ]; then
    echo -e "  ${BOLD}Sugestoes:${RESET}"
    for sug in "${SUGGESTIONS[@]}"; do
        echo -e "  ${CYAN}→${RESET} $sug"
    done
    echo ""
fi

READY_TO_MERGE=false
[ "$FAILED" -eq 0 ] && READY_TO_MERGE=true

if [ "$READY_TO_MERGE" = true ]; then
    echo -e "  ${GREEN}${BOLD}✅ Pronto para criar PR!${RESET}"
else
    echo -e "  ${RED}${BOLD}❌ Corrija os problemas antes de criar PR.${RESET}"
fi
echo ""
