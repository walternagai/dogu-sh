#!/bin/bash
# test-coverage.sh — Analise de cobertura de testes por modulo
# Uso: ./test-coverage.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --project PATH      Caminho do projeto (padrao: diretorio atual)
#   --source DIR        Diretorio fonte para analise (padrao: src/)
#   --tests DIR         Diretorio de testes (padrao: tests/)
#   --help              Mostra esta ajuda
#   --version           Mostra versao

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
SOURCE_DIR="src/"
TESTS_DIR="tests/"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --source|-s)
            [[ -z "${2-}" ]] && error "Flag --source requer um valor"
            SOURCE_DIR="$2"; shift 2 ;;
        --tests|-t)
            [[ -z "${2-}" ]] && error "Flag --tests requer um valor"
            TESTS_DIR="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  test-coverage.sh — Analise de cobertura de testes por modulo"
            echo ""
            echo "  Uso: ./test-coverage.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --project|-p PATH   Caminho do projeto (padrao: diretorio atual)"
            echo "    --source|-s DIR     Diretorio fonte (padrao: src/)"
            echo "    --tests|-t DIR      Diretorio de testes (padrao: tests/)"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "test-coverage.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Resolver diretorios fonte e de testes
SOURCE_PATH="$PROJECT_PATH/$SOURCE_DIR"
TESTS_PATH="$PROJECT_PATH/$TESTS_DIR"

# Auto-detectar se src/ nao existe
if [[ ! -d "$SOURCE_PATH" ]]; then
    # Procurar diretorio de codigo fonte
    for candidate in app/ lib/ pkg/ source/ cmd/ internal/; do
        if [[ -d "$PROJECT_PATH/$candidate" ]]; then
            SOURCE_PATH="$PROJECT_PATH/$candidate"
            SOURCE_DIR="$candidate"
            break
        fi
    done
fi

# Auto-detectar diretorio de testes
if [[ ! -d "$TESTS_PATH" ]]; then
    for candidate in test/ spec/ __tests__/ testsuite/; do
        if [[ -d "$PROJECT_PATH/$candidate" ]]; then
            TESTS_PATH="$PROJECT_PATH/$candidate"
            TESTS_DIR="$candidate"
            break
        fi
    done
fi

# --- Coletar arquivos fonte ---
declare -a source_files=()
declare -A source_by_module=()

while IFS= read -r -d '' file; do
    source_files+=("$file")
    rel="${file#$SOURCE_PATH/}"
    module=$(dirname "$rel")
    [[ "$module" == "." ]] && module="(root)"
    source_by_module["$module"]="${source_by_module[$module]:-} $rel"
done < <(find "$SOURCE_PATH" -type f \
    \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' \
       -o -name '*.go' -o -name '*.rs' -o -name '*.java' \) \
    -not -path '*/__pycache__/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/.venv/*' \
    -not -path '*/target/*' \
    -print0 2>/dev/null || true)

# --- Coletar arquivos de teste ---
declare -a test_files=()
declare -A tests_for_source=()

while IFS= read -r -d '' file; do
    test_files+=("$file")
    rel="${file#$TESTS_PATH/}"
    basename_file=$(basename "$file")
    basename_no_ext="${basename_file%.*}"

    # Encontrar arquivos fonte correspondentes
    for src in "${source_files[@]}"; do
        src_basename=$(basename "$src")
        src_no_ext="${src_basename%.*}"
        # Match: test_auth.py -> auth.py, auth.test.js -> auth.js
        if [[ "$basename_no_ext" == *"$src_no_ext"* || "$src_no_ext" == *"$basename_no_ext"* ]]; then
            src_rel="${src#$SOURCE_PATH/}"
            current="${tests_for_source[$src_rel]:-}"
            tests_for_source["$src_rel"]="${current:+$current }$rel"
        fi
    done
done < <(find "$TESTS_PATH" -type f \
    \( -name 'test_*.py' -o -name '*_test.py' \
       -o -name '*.test.js' -o -name '*.test.ts' -o -name '*.spec.js' -o -name '*.spec.ts' \
       -o -name '*_test.go' -o -name '*_test.rb' \
       -o -name '*.test.jsx' -o -name '*.test.tsx' \) \
    -not -path '*/__pycache__/*' \
    -not -path '*/node_modules/*' \
    -print0 2>/dev/null || true)

# --- Calcular metricas ---
total_source=${#source_files[@]}
total_tests=${#test_files[@]}
tested_files=0
untested_files=()

declare -A by_module_json_data=()

for src in "${source_files[@]}"; do
    src_rel="${src#$SOURCE_PATH/}"
    tests="${tests_for_source[$src_rel]:-}"
    has_test=false
    test_list="[]"

    if [[ -n "$tests" ]]; then
        has_test=true
        tested_files=$((tested_files + 1))
        test_list="["
        tl_first=true
        for t in $tests; do
            [[ "$tl_first" == true ]] && tl_first=false || test_list+=","
            test_list+="\"$t\""
        done
        test_list+="]"
    else
        untested_files+=("$src_rel")
    fi

    by_module_json_data["$src_rel"]="{\"has_test\":$has_test,\"test_files\":$test_list}"
done

coverage_ratio=0
if [[ $total_source -gt 0 ]]; then
    coverage_ratio=$(echo "scale=2; $tested_files / $total_source" | bc 2>/dev/null || echo "0.00")
fi

# Montar JSON
by_module_json="{"
bm_first=true
for src in $(echo "${!by_module_json_data[@]}" | tr ' ' '\n' | sort); do
    [[ "$bm_first" == true ]] && bm_first=false || by_module_json+=","
    by_module_json+="\"$src\":${by_module_json_data[$src]}"
done
by_module_json+="}"

untested_json="["
u_first=true
for u in "${untested_files[@]}"; do
    [[ "$u_first" == true ]] && u_first=false || untested_json+=","
    untested_json+="\"$u\""
done
untested_json+="]"

suggestions_json="["
s_first=true
for u in "${untested_files[@]}"; do
    [[ "$s_first" == true ]] && s_first=false || suggestions_json+=","
    suggestions_json+="\"Adicionar testes para $u\""
done
suggestions_json+="]"

if [[ "$JSON_MODE" == true ]]; then
    cat <<EOF
{
  "status": "ok",
  "project": "$PROJECT_NAME",
  "source_files": $total_source,
  "test_files": $total_tests,
  "coverage_ratio": $coverage_ratio,
  "by_module": $by_module_json,
  "untested_files": $untested_json,
  "suggestions": $suggestions_json
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Analise de Cobertura de Testes${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Projeto:${RESET}    $PROJECT_NAME"
    echo -e "  ${BOLD}Fonte:${RESET}      $SOURCE_DIR (${total_source} arquivos)"
    echo -e "  ${BOLD}Testes:${RESET}     $TESTS_DIR (${total_tests} arquivos)"
    echo -e "  ${BOLD}Cobertura:${RESET}  $coverage_ratio"
    echo ""

    # Barra visual de cobertura
    pct=$(echo "$coverage_ratio * 100" | bc 2>/dev/null || echo 0)
    bar_width=40
    filled=$(echo "$pct * $bar_width / 100" | bc 2>/dev/null || echo 0)
    empty=$((bar_width - filled))
    bar=""
    for ((i=0; i<filled; i++)); do bar="${bar}█"; done
    for ((i=0; i<empty; i++)); do bar="${bar}░"; done

    if (( $(echo "$pct >= 70" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${GREEN}${bar} ${pct}%${RESET}"
    elif (( $(echo "$pct >= 40" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "  ${YELLOW}${bar} ${pct}%${RESET}"
    else
        echo -e "  ${RED}${bar} ${pct}%${RESET}"
    fi

    echo ""
    echo -e "  ${BOLD}Por modulo:${RESET}"
    for src in $(echo "${!by_module_json_data[@]}" | tr ' ' '\n' | sort); do
        has_test=$(echo "${by_module_json_data[$src]}" | grep -o '"has_test":[a-z]*' | cut -d: -f2)
        if [[ "$has_test" == "true" ]]; then
            echo -e "    ${GREEN}✓${RESET} $src"
        else
            echo -e "    ${RED}✗${RESET} $src"
        fi
    done

    echo ""

    if [[ ${#untested_files[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Arquivos sem teste:${RESET}"
        for u in "${untested_files[@]}"; do
            echo -e "    ${RED}✗${RESET} $u"
        done
        echo ""
    fi

    if [[ ${#untested_files[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Sugestoes:${RESET}"
        for u in "${untested_files[@]}"; do
            echo -e "    ${DIM}•${RESET} Adicionar testes para $u"
        done
    fi

    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
