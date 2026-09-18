#!/bin/bash
# codebase-summary.sh — Resumo completo do projeto para agentes de IA entenderem o codebase
# Uso: ./codebase-summary.sh [opcoes]
# Opcoes:
#   --json          Saida em formato JSON
#   --path PATH     Caminho do projeto (padrao: diretorio atual)
#   --deep          Analise profunda (inclui complexidade)
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
DEEP_ANALYSIS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --path|-p)
            [[ -z "${2-}" ]] && error "Flag --path requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --deep|-d) DEEP_ANALYSIS=true; shift ;;
        --help|-h)
            echo ""
            echo "  codebase-summary.sh — Resumo completo do projeto para agentes de IA"
            echo ""
            echo "  Uso: ./codebase-summary.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j       Saida em formato JSON"
            echo "    --path|-p PATH  Caminho do projeto (padrao: diretorio atual)"
            echo "    --deep|-d       Analise profunda (inclui complexidade)"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "codebase-summary.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"

PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# --- Coleta de dados ---

# Contar arquivos por extensao
declare -A ext_counts
while IFS= read -r -d '' file; do
    ext="${file##*.}"
    if [[ "$ext" == "$file" ]] || [[ -z "$ext" ]]; then
        ext="(no ext)"
    fi
    ext_counts["$ext"]=$(( ${ext_counts["$ext"]:-0} + 1 ))
done < <(find "$PROJECT_PATH" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/venv/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -path '*/.tox/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -print0 2>/dev/null || true)

total_files=0
for ext in "${!ext_counts[@]}"; do
    total_files=$((total_files + ext_counts[$ext]))
done

# Contar linhas por linguagem (baseado na extensao)
declare -A lang_lines
while IFS= read -r -d '' file; do
    ext="${file##*.}"
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    case "$ext" in
        py) lang="python" ;;
        sh|bash) lang="bash" ;;
        js|mjs|cjs) lang="javascript" ;;
        ts|tsx|mts) lang="typescript" ;;
        go) lang="go" ;;
        rs) lang="rust" ;;
        java) lang="java" ;;
        kt|kts) lang="kotlin" ;;
        rb) lang="ruby" ;;
        c|h) lang="c" ;;
        cpp|cc|cxx|hpp) lang="cpp" ;;
        cs) lang="csharp" ;;
        php) lang="php" ;;
        swift) lang="swift" ;;
        sql) lang="sql" ;;
        md|markdown) lang="markdown" ;;
        yaml|yml) lang="yaml" ;;
        json) lang="json" ;;
        xml) lang="xml" ;;
        html|htm) lang="html" ;;
        css) lang="css" ;;
        scss|sass) lang="scss" ;;
        lua) lang="lua" ;;
        r) lang="r" ;;
        *) lang="other" ;;
    esac
    lang_lines["$lang"]=$(( ${lang_lines["$lang"]:-0} + lines ))
done < <(find "$PROJECT_PATH" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -path '*/.tox/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -print0 2>/dev/null || true)

total_lines=0
for lang in "${!lang_lines[@]}"; do
    total_lines=$((total_lines + lang_lines[$lang]))
done

# Linguagem primaria
primary_lang="unknown"
max_lines=0
for lang in "${!lang_lines[@]}"; do
    if [[ ${lang_lines[$lang]} -gt $max_lines ]]; then
        max_lines=${lang_lines[$lang]}
        primary_lang="$lang"
    fi
done

# Linguagens (array ordenado)
languages_json="["
lang_first=true
for lang in $(for l in "${!lang_lines[@]}"; do echo "$lang ${lang_lines[$l]}"; done | sort -k2 -rn | awk '{print $1}'); do
    [[ "$lang_first" == true ]] && lang_first=false || languages_json+=","
    languages_json+="\"$lang\""
done
languages_json+="]"

# Arquivos por extensao (JSON object)
by_extension_json="{"
ext_first=true
for e in "${!ext_counts[@]}"; do
    [[ "$ext_first" == true ]] && ext_first=false || by_extension_json+=","
    by_extension_json+="\".$e\":${ext_counts[$e]}"
done
by_extension_json+="}"

# Linhas por linguagem (JSON object)
by_language_json="{"
lang_first=true
for l in "${!lang_lines[@]}"; do
    [[ "$lang_first" == true ]] && lang_first=false || by_language_json+=","
    by_language_json+="\"$l\":${lang_lines[$l]}"
done
by_language_json+="}"

# --- Dependencias ---
has_lockfile=false
has_docker=false
has_ci=false
package_managers="[]"

# Detectar package managers
pm_list=""
if [[ -f "$PROJECT_PATH/package.json" ]]; then
    has_lockfile=true
    [[ -f "$PROJECT_PATH/package-lock.json" || -f "$PROJECT_PATH/yarn.lock" || -f "$PROJECT_PATH/pnpm-lock.yaml" ]] && has_lockfile=true
    pm_list="${pm_list:+$pm_list,}\"npm\""
fi
if [[ -f "$PROJECT_PATH/requirements.txt" || -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/setup.py" || -f "$PROJECT_PATH/setup.cfg" ]]; then
    pm_list="${pm_list:+$pm_list,}\"pip\""
fi
if [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
    pm_list="${pm_list:+$pm_list,}\"cargo\""
fi
if [[ -f "$PROJECT_PATH/go.mod" ]]; then
    pm_list="${pm_list:+$pm_list,}\"go\""
fi
if [[ -f "$PROJECT_PATH/pom.xml" || -f "$PROJECT_PATH/build.gradle" ]]; then
    pm_list="${pm_list:+$pm_list,}\"gradle\""
fi
if [[ -f "$PROJECT_PATH/Gemfile" ]]; then
    pm_list="${pm_list:+$pm_list,}\"bundler\""
fi
if [[ -f "$PROJECT_PATH/composer.json" ]]; then
    pm_list="${pm_list:+$pm_list,}\"composer\""
fi
package_managers="[${pm_list}]"

# Docker
[[ -f "$PROJECT_PATH/Dockerfile" || -f "$PROJECT_PATH/docker-compose.yml" || -f "$PROJECT_PATH/docker-compose.yaml" ]] && has_docker=true

# CI
[[ -d "$PROJECT_PATH/.github/workflows" || -f "$PROJECT_PATH/.gitlab-ci.yml" || -f "$PROJECT_PATH/Jenkinsfile" || -f "$PROJECT_PATH/.circleci/config.yml" || -f "$PROJECT_PATH/.travis.yml" ]] && has_ci=true

# --- Testes ---
has_tests=false
test_files=0
test_framework="none"

# Detectar framework de testes
if [[ -f "$PROJECT_PATH/pyproject.toml" ]] && grep -q '\[tool.pytest' "$PROJECT_PATH/pyproject.toml" 2>/dev/null; then
    test_framework="pytest"
elif [[ -f "$PROJECT_PATH/pytest.ini" ]] || { [[ -f "$PROJECT_PATH/setup.cfg" ]] && grep -q '\[tool:pytest\]' "$PROJECT_PATH/setup.cfg" 2>/dev/null; }; then
    test_framework="pytest"
elif [[ -f "$PROJECT_PATH/jest.config.js" || -f "$PROJECT_PATH/jest.config.ts" ]]; then
    test_framework="jest"
elif [[ -f "$PROJECT_PATH/.mocharc.yml" || -f "$PROJECT_PATH/.mocharc.js" ]]; then
    test_framework="mocha"
elif [[ -f "$PROJECT_PATH/go.mod" ]]; then
    test_framework="go test"
fi

# Contar arquivos de teste
while IFS= read -r -d '' file; do
    test_files=$((test_files + 1))
done < <(find "$PROJECT_PATH" -type f \
    \( -name 'test_*.py' -o -name '*_test.py' \
       -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \
       -o -name '*_test.go' -o -name '*_test.rb' \
       -o -name '*.test.jsx' -o -name '*.test.tsx' \) \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/vendor/*' \
    -print0 2>/dev/null || true)

[[ $test_files -gt 0 ]] && has_tests=true

# --- Documentacao ---
has_readme=false
has_changelog=false
has_license=false
readme_lines=0

[[ -f "$PROJECT_PATH/README.md" || -f "$PROJECT_PATH/README.rst" || -f "$PROJECT_PATH/README" ]] && has_readme=true
[[ -f "$PROJECT_PATH/CHANGELOG.md" || -f "$PROJECT_PATH/CHANGELOG" || -f "$PROJECT_PATH/CHANGES.md" ]] && has_changelog=true
[[ -f "$PROJECT_PATH/LICENSE" || -f "$PROJECT_PATH/LICENSE.md" || -f "$PROJECT_PATH/LICENCE" ]] && has_license=true

if $has_readme; then
    readme_file=""
    for f in README.md README.rst README; do
        [[ -f "$PROJECT_PATH/$f" ]] && readme_file="$PROJECT_PATH/$f" && break
    done
    [[ -n "$readme_file" ]] && readme_lines=$(wc -l < "$readme_file" 2>/dev/null || echo 0)
fi

# --- Output ---

if [[ "$JSON_MODE" == true ]]; then
    # Construir JSON
    cat <<EOF
{
  "status": "ok",
  "project": {
    "name": "$PROJECT_NAME",
    "path": "$PROJECT_PATH",
    "primary_language": "$primary_lang",
    "languages": $languages_json
  },
  "files": {
    "total": $total_files,
    "by_extension": $by_extension_json
  },
  "lines": {
    "total": $total_lines,
    "by_language": $by_language_json
  },
  "dependencies": {
    "package_managers": $package_managers,
    "has_lockfile": $( $has_lockfile && echo "true" || echo "false" ),
    "has_docker": $( $has_docker && echo "true" || echo "false" ),
    "has_ci": $( $has_ci && echo "true" || echo "false" )
  },
  "tests": {
    "has_tests": $( $has_tests && echo "true" || echo "false" ),
    "test_files": $test_files,
    "test_framework": "$test_framework"
  },
  "documentation": {
    "has_readme": $( $has_readme && echo "true" || echo "false" ),
    "has_changelog": $( $has_changelog && echo "true" || echo "false" ),
    "has_license": $( $has_license && echo "true" || echo "false" ),
    "readme_lines": $readme_lines
  }
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Resumo do Codebase${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Projeto:${RESET}    $PROJECT_NAME"
    echo -e "  ${BOLD}Caminho:${RESET}    $PROJECT_PATH"
    echo -e "  ${BOLD}Linguagem:${RESET}  $primary_lang"
    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}Arquivos:${RESET}   $total_files"
    echo -e "  ${BOLD}Linhas:${RESET}     $total_lines"
    echo ""

    echo -e "  ${BOLD}Por extensao:${RESET}"
    for e in "${!ext_counts[@]}"; do
        count=${ext_counts[$e]}
        pct=$((count * 100 / total_files))
        bar=""
        for ((i=0; i<pct/2; i++)); do bar="${bar}█"; done
        printf "  %-12s %4d ${DIM}%s${RESET}\n" ".$e" "$count" "$bar"
    done | sort -t' ' -k2 -rn | head -10

    echo ""
    echo -e "  ${BOLD}Por linguagem:${RESET}"
    for l in "${!lang_lines[@]}"; do
        lines=${lang_lines[$l]}
        pct=$((lines * 100 / total_lines))
        printf "  %-14s %6d ${DIM}(%d%%)${RESET}\n" "$l" "$lines" "$pct"
    done | sort -t' ' -k2 -rn | head -5

    echo ""
    echo -e "  ${BOLD}Dependencias:${RESET}"
    echo -e "    Gerenciadores: ${package_managers//\"/}"
    $has_docker && echo -e "    ${GREEN}✓${RESET} Docker" || echo -e "    ${DIM}✗${RESET} Docker"
    $has_ci && echo -e "    ${GREEN}✓${RESET} CI/CD" || echo -e "    ${DIM}✗${RESET} CI/CD"
    $has_lockfile && echo -e "    ${GREEN}✓${RESET} Lockfile" || echo -e "    ${DIM}✗${RESET} Lockfile"

    echo ""
    echo -e "  ${BOLD}Testes:${RESET}"
    if $has_tests; then
        echo -e "    ${GREEN}✓${RESET} Framework: $test_framework (${test_files} arquivos)"
    else
        echo -e "    ${DIM}✗${RESET} Nenhum teste detectado"
    fi

    echo ""
    echo -e "  ${BOLD}Documentacao:${RESET}"
    $has_readme && echo -e "    ${GREEN}✓${RESET} README (${readme_lines} linhas)" || echo -e "    ${DIM}✗${RESET} README"
    $has_changelog && echo -e "    ${GREEN}✓${RESET} CHANGELOG" || echo -e "    ${DIM}✗${RESET} CHANGELOG"
    $has_license && echo -e "    ${GREEN}✓${RESET} LICENSE" || echo -e "    ${DIM}✗${RESET} LICENSE"

    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
