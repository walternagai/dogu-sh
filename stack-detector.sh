#!/bin/bash
# stack-detector.sh — Detecta automaticamente a stack tecnologica do projeto
# Uso: ./stack-detector.sh [opcoes]
# Opcoes:
#   --json          Saida em formato JSON
#   --path PATH     Caminho do projeto (padrao: diretorio atual)
#   --verbose       Mostra detalhes da deteccao
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

JSON_MODE=false
PROJECT_PATH="."
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --path|-p)
            [[ -z "${2-}" ]] && error "Flag --path requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            echo ""
            echo "  stack-detector.sh — Detecta automaticamente a stack tecnologica do projeto"
            echo ""
            echo "  Uso: ./stack-detector.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j       Saida em formato JSON"
            echo "    --path|-p PATH  Caminho do projeto (padrao: diretorio atual)"
            echo "    --verbose|-v    Mostra detalhes da deteccao"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "stack-detector.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)

# --- Deteccao ---

detected=false
primary_lang="unknown"
languages=""
frameworks=""
package_managers=""
test_framework="none"
linters=""
formatters=""
build_tools=""
ci_cd="none"
containerization="none"
node_version=""
python_version=""

# Linguagens por manifest files
declare -A lang_detected
if [[ -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/setup.py" || -f "$PROJECT_PATH/requirements.txt" || -f "$PROJECT_PATH/Pipfile" ]]; then
    lang_detected[python]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/package.json" ]]; then
    lang_detected[javascript]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/go.mod" ]]; then
    lang_detected[go]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
    lang_detected[rust]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/pom.xml" || -f "$PROJECT_PATH/build.gradle" || -f "$PROJECT_PATH/build.gradle.kts" ]]; then
    lang_detected[java]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/Gemfile" ]]; then
    lang_detected[ruby]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/composer.json" ]]; then
    lang_detected[php]=true
    detected=true
fi
if [[ -f "$PROJECT_PATH/CMakeLists.txt" || -f "$PROJECT_PATH/Makefile" ]] && find "$PROJECT_PATH" -maxdepth 2 -name "*.c" -o -name "*.h" 2>/dev/null | head -1 | grep -q .; then
    lang_detected[c]=true
    detected=true
fi

# Contar arquivos por extensao para confirmar linguagens
declare -A ext_count
while IFS= read -r -d '' file; do
    ext="${file##*.}"
    ext_count["$ext"]=$(( ${ext_count["$ext"]:-0} + 1 ))
done < <(find "$PROJECT_PATH" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -print0 2>/dev/null || true)

# Confirmar linguagens por extensoes
for ext in "${!ext_count[@]}"; do
    case "$ext" in
        py) lang_detected[python]=true ;;
        sh|bash) lang_detected[bash]=true ;;
        js|mjs) lang_detected[javascript]=true ;;
        ts|mts) lang_detected[typescript]=true ;;
        go) lang_detected[go]=true ;;
        rs) lang_detected[rust]=true ;;
        java) lang_detected[java]=true ;;
        kt) lang_detected[kotlin]=true ;;
        rb) lang_detected[ruby]=true ;;
        php) lang_detected[php]=true ;;
        c|h) lang_detected[c]=true ;;
        cpp|cc|cxx) lang_detected[cpp]=true ;;
        cs) lang_detected[csharp]=true ;;
    esac
done

# Linguagem primaria
max_count=0
for ext in "${!ext_count[@]}"; do
    if [[ ${ext_count[$ext]} -gt $max_count ]]; then
        case "$ext" in
            py) primary_lang="python" ;;
            sh|bash) primary_lang="bash" ;;
            js|mjs) primary_lang="javascript" ;;
            ts|mts) primary_lang="typescript" ;;
            go) primary_lang="go" ;;
            rs) primary_lang="rust" ;;
            java) primary_lang="java" ;;
            kt) primary_lang="kotlin" ;;
            rb) primary_lang="ruby" ;;
            php) primary_lang="php" ;;
            c|h) primary_lang="c" ;;
            cpp|cc|cxx) primary_lang="cpp" ;;
            cs) primary_lang="csharp" ;;
        esac
        max_count=${ext_count[$ext]}
    fi
done
[[ "$max_count" -gt 0 ]] && detected=true

# Montar lista de linguagens
languages_json="["
lang_first=true
for lang in "${!lang_detected[@]}"; do
    [[ "$lang_first" == true ]] && lang_first=false || languages_json+=","
    languages_json+="\"$lang\""
done
languages_json+="]"

# Frameworks
frameworks_json="["
fw_first=true

# Python frameworks
if [[ -f "$PROJECT_PATH/pyproject.toml" ]]; then
    if grep -q 'fastapi' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"fastapi\""
    fi
    if grep -q 'django' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"django\""
    fi
    if grep -q 'flask' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"flask\""
    fi
    if grep -q 'sqlalchemy\|SQLAlchemy' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"sqlalchemy\""
    fi
    if grep -q 'pydantic\|Pydantic' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"pydantic\""
    fi
fi

# Node frameworks
if [[ -f "$PROJECT_PATH/package.json" ]]; then
    if grep -q '"next"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"nextjs\""
    fi
    if grep -q '"react"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"react\""
    fi
    if grep -q '"vue"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"vue\""
    fi
    if grep -q '"express"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        [[ "$fw_first" == true ]] && fw_first=false || frameworks_json+=","
        frameworks_json+="\"express\""
    fi
fi
frameworks_json+="]"

# Package managers
pm_json="["
pm_first=true
[[ -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/Pipfile" ]] && { [[ "$pm_first" == true ]] && pm_first=false || pm_json+=","; pm_json+="\"pip\""; }
grep -q 'poetry' "$PROJECT_PATH/pyproject.toml" 2>/dev/null && { [[ "$pm_first" == true ]] && pm_first=false || pm_json+=","; pm_json+="\"poetry\""; }
[[ -f "$PROJECT_PATH/package.json" ]] && { [[ "$pm_first" == true ]] && pm_first=false || pm_json+=","; pm_json+="\"npm\""; }
[[ -f "$PROJECT_PATH/Cargo.toml" ]] && { [[ "$pm_first" == true ]] && pm_first=false || pm_json+=","; pm_json+="\"cargo\""; }
[[ -f "$PROJECT_PATH/go.mod" ]] && { [[ "$pm_first" == true ]] && pm_first=false || pm_json+=","; pm_json+="\"go\""; }
pm_json+="]"

# Test frameworks
if [[ -f "$PROJECT_PATH/pyproject.toml" ]] && grep -q 'pytest\|unittest' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
    test_framework="pytest"
elif [[ -f "$PROJECT_PATH/pytest.ini" ]]; then
    test_framework="pytest"
elif [[ -f "$PROJECT_PATH/package.json" ]]; then
    if grep -q '"jest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        test_framework="jest"
    elif grep -q '"mocha"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        test_framework="mocha"
    elif grep -q '"vitest"' "$PROJECT_PATH/package.json" 2>/dev/null; then
        test_framework="vitest"
    fi
elif [[ -f "$PROJECT_PATH/go.mod" ]]; then
    test_framework="go test"
elif [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
    test_framework="cargo test"
fi

# Linters
linters_json="["
l_first=true
if [[ -f "$PROJECT_PATH/pyproject.toml" ]] && grep -q '\[tool.ruff\]\|ruff' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
    [[ "$l_first" == true ]] && l_first=false || linters_json+=","
    linters_json+="\"ruff\""
fi
[[ -f "$PROJECT_PATH/.ruff.toml" || -f "$PROJECT_PATH/ruff.toml" ]] && { [[ "$l_first" == true ]] && l_first=false || linters_json+=","; linters_json+="\"ruff\""; }
[[ -f "$PROJECT_PATH/.eslintrc" || -f "$PROJECT_PATH/.eslintrc.js" || -f "$PROJECT_PATH/.eslintrc.json" ]] && { [[ "$l_first" == true ]] && l_first=false || linters_json+=","; linters_json+="\"eslint\""; }
[[ -f "$PROJECT_PATH/.golangci.yml" ]] && { [[ "$l_first" == true ]] && l_first=false || linters_json+=","; linters_json+="\"golangci-lint\""; }
[[ -f "$PROJECT_PATH/.clippy.toml" ]] && { [[ "$l_first" == true ]] && l_first=false || linters_json+=","; linters_json+="\"clippy\""; }
linters_json+="]"

# Formatters
formatters_json="["
ff_first=true
grep -q 'black' "$PROJECT_PATH/pyproject.toml" 2>/dev/null && { [[ "$ff_first" == true ]] && ff_first=false || formatters_json+=","; formatters_json+="\"black\""; }
grep -q '\[tool.ruff.format\]' "$PROJECT_PATH/pyproject.toml" 2>/dev/null && { [[ "$ff_first" == true ]] && ff_first=false || formatters_json+=","; formatters_json+="\"ruff format\""; }
[[ -f "$PROJECT_PATH/.prettierrc" || -f "$PROJECT_PATH/.prettierrc.json" ]] && { [[ "$ff_first" == true ]] && ff_first=false || formatters_json+=","; formatters_json+="\"prettier\""; }
formatters_json+="]"

# Build tools
build_json="["
bt_first=true
grep -q 'setuptools\|build' "$PROJECT_PATH/pyproject.toml" 2>/dev/null && { [[ "$bt_first" == true ]] && bt_first=false || build_json+=","; build_json+="\"setuptools\""; }
[[ -f "$PROJECT_PATH/Makefile" ]] && { [[ "$bt_first" == true ]] && bt_first=false || build_json+=","; build_json+="\"make\""; }
[[ -f "$PROJECT_PATH/CMakeLists.txt" ]] && { [[ "$bt_first" == true ]] && bt_first=false || build_json+=","; build_json+="\"cmake\""; }
build_json+="]"

# CI/CD
if [[ -d "$PROJECT_PATH/.github/workflows" ]]; then
    ci_cd="github-actions"
elif [[ -f "$PROJECT_PATH/.gitlab-ci.yml" ]]; then
    ci_cd="gitlab-ci"
elif [[ -f "$PROJECT_PATH/Jenkinsfile" ]]; then
    ci_cd="jenkins"
elif [[ -f "$PROJECT_PATH/.circleci/config.yml" ]]; then
    ci_cd="circleci"
elif [[ -f "$PROJECT_PATH/.travis.yml" ]]; then
    ci_cd="travis"
fi

# Containerizacao
if [[ -f "$PROJECT_PATH/Dockerfile" || -f "$PROJECT_PATH/docker-compose.yml" || -f "$PROJECT_PATH/docker-compose.yaml" ]]; then
    containerization="docker"
elif [[ -f "$PROJECT_PATH/.dockerignore" ]]; then
    containerization="docker"
fi

# Versoes
if [[ -f "$PROJECT_PATH/.python-version" ]]; then
    python_version=$(cat "$PROJECT_PATH/.python-version" 2>/dev/null | tr -d '[:space:]')
elif [[ -f "$PROJECT_PATH/.tool-versions" ]]; then
    python_version=$(grep 'python' "$PROJECT_PATH/.tool-versions" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]')
fi

if [[ -f "$PROJECT_PATH/.nvmrc" ]]; then
    node_version=$(cat "$PROJECT_PATH/.nvmrc" 2>/dev/null | tr -d '[:space:]')
elif [[ -f "$PROJECT_PATH/.tool-versions" ]]; then
    node_version=$(grep 'nodejs\|node' "$PROJECT_PATH/.tool-versions" 2>/dev/null | awk '{print $2}' | tr -d '[:space:]')
fi

# Recomendacoes
test_cmd="echo 'Nenhum teste detectado'"
lint_cmd="echo 'Nenhum linter detectado'"
format_cmd="echo 'Nenhum formatador detectado'"
build_cmd="echo 'Nenhum build detectado'"

case "$test_framework" in
    pytest) test_cmd="pytest" ;;
    jest) test_cmd="jest" ;;
    mocha) test_cmd="mocha" ;;
    vitest) test_cmd="vitest" ;;
    "go test") test_cmd="go test ./..." ;;
    "cargo test") test_cmd="cargo test" ;;
esac

if echo "$linters_json" | grep -q 'ruff'; then
    lint_cmd="ruff check"
elif echo "$linters_json" | grep -q 'eslint'; then
    lint_cmd="eslint ."
fi

if echo "$formatters_json" | grep -q 'ruff format'; then
    format_cmd="ruff format"
elif echo "$formatters_json" | grep -q 'black'; then
    format_cmd="black ."
elif echo "$formatters_json" | grep -q 'prettier'; then
    format_cmd="prettier --write ."
fi

if echo "$build_json" | grep -q 'setuptools'; then
    build_cmd="python -m build"
elif echo "$build_json" | grep -q 'make'; then
    build_cmd="make"
fi

# --- Output ---

if [[ "$JSON_MODE" == true ]]; then
    cat <<EOF
{
  "status": "ok",
  "detected": $detected,
  "primary_language": "$primary_lang",
  "languages": $languages_json,
  "frameworks": $frameworks_json,
  "package_managers": $pm_json,
  "test_framework": "$test_framework",
  "linters": $linters_json,
  "formatters": $formatters_json,
  "build_tools": $build_json,
  "ci_cd": "$ci_cd",
  "containerization": "$containerization",
  "node_version": ${node_version:+\"$node_version\"}${node_version:-null},
  "python_version": ${python_version:+\"$python_version\"}${python_version:-null},
  "recommendations": {
    "test_command": "$test_cmd",
    "lint_command": "$lint_cmd",
    "format_command": "$format_cmd",
    "build_command": "$build_cmd"
  }
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Deteccao de Stack${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    if $detected; then
        echo -e "  ${GREEN}✓${RESET} Stack detectada"
    else
        echo -e "  ${YELLOW}⚠${RESET} Nenhuma stack detectada"
    fi

    echo ""
    echo -e "  ${BOLD}Linguagem primaria:${RESET} $primary_lang"
    echo -e "  ${BOLD}Linguagens:${RESET}        ${languages_json//\"/}"
    echo -e "  ${BOLD}Frameworks:${RESET}        ${frameworks_json//\"/}"
    echo -e "  ${BOLD}Gerenciadores:${RESET}     ${pm_json//\"/}"
    echo ""

    echo -e "  ${BOLD}Testes:${RESET}           $test_framework"
    echo -e "  ${BOLD}Linters:${RESET}          ${linters_json//\"/}"
    echo -e "  ${BOLD}Formatters:${RESET}       ${formatters_json//\"/}"
    echo -e "  ${BOLD}Build tools:${RESET}      ${build_json//\"/}"
    echo ""

    echo -e "  ${BOLD}CI/CD:${RESET}            $ci_cd"
    echo -e "  ${BOLD}Containerizacao:${RESET}  $containerization"
    [[ -n "$python_version" ]] && echo -e "  ${BOLD}Python:${RESET}           $python_version"
    [[ -n "$node_version" ]] && echo -e "  ${BOLD}Node:${RESET}             $node_version"

    echo ""
    echo -e "  ${BOLD}Comandos recomendados:${RESET}"
    echo -e "    Teste:     ${GREEN}$test_cmd${RESET}"
    echo -e "    Lint:      ${GREEN}$lint_cmd${RESET}"
    echo -e "    Format:    ${GREEN}$format_cmd${RESET}"
    echo -e "    Build:     ${GREEN}$build_cmd${RESET}"

    if $VERBOSE; then
        echo ""
        echo -e "  ${BOLD}Arquivos por extensao:${RESET}"
        for ext in $(for e in "${!ext_count[@]}"; do echo "$e ${ext_count[$e]}"; done | sort -k2 -rn | head -10 | awk '{print $1}'); do
            echo -e "    %-8s %d\n" ".$ext" "${ext_count[$ext]}"
        done
    fi

    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
