#!/bin/bash
# impact-analyzer.sh — Analisa o impacto de alteracoes em arquivos especificos
# Uso: ./impact-analyzer.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --file FILE         Arquivo a analisar (obrigatorio)
#   --project PATH      Caminho do projeto (padrao: diretorio atual)
#   --depth N           Profundidade da analise de dependencias (padrao: 2)
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
TARGET_FILE=""
MAX_DEPTH=2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --file|-f)
            [[ -z "${2-}" ]] && error "Flag --file requer um valor"
            TARGET_FILE="$2"; shift 2 ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --depth|-d)
            [[ -z "${2-}" ]] && error "Flag --depth requer um valor"
            MAX_DEPTH="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  impact-analyzer.sh — Analisa o impacto de alteracoes em arquivos especificos"
            echo ""
            echo "  Uso: ./impact-analyzer.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --file|-f FILE      Arquivo a analisar (obrigatorio)"
            echo "    --project|-p PATH   Caminho do projeto (padrao: diretorio atual)"
            echo "    --depth|-d N        Profundidade da analise (padrao: 2)"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "impact-analyzer.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ -z "$TARGET_FILE" ]] && error "Flag --file e obrigatoria. Use --help para mais informacoes."
[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)

# Resolver caminho absoluto do arquivo alvo
if [[ "$TARGET_FILE" == /* ]]; then
    ABS_TARGET="$TARGET_FILE"
else
    ABS_TARGET="$PROJECT_PATH/$TARGET_FILE"
fi
[[ ! -f "$ABS_TARGET" ]] && error "Arquivo nao encontrado: $TARGET_FILE"

# Extrair basename sem extensao
TARGET_BASENAME=$(basename "$ABS_TARGET")
TARGET_NAME="${TARGET_BASENAME%.*}"
TARGET_EXT="${TARGET_BASENAME##*.}"

# --- Funcao de busca de importadores ---

find_importers() {
    local file="$1"
    local depth="$2"
    local current_depth="$3"

    if [[ $current_depth -ge $depth ]]; then
        return
    fi

    local basename_no_ext
    basename_no_ext=$(basename "$file")
    basename_no_ext="${basename_no_ext%.*}"

    # Buscar arquivos que importam este arquivo
    while IFS= read -r -d '' importer; do
        echo "$importer"
    done < <(grep -rl --include='*.py' --include='*.js' --include='*.ts' --include='*.tsx' --include='*.jsx' --include='*.go' --include='*.rs' --include='*.java' \
        -E "(import|from|require).*${basename_no_ext}" "$PROJECT_PATH" \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/__pycache__/*' \
        -not -path '*/.venv/*' \
        -not -path '*/target/*' \
        -not -path '*/vendor/*' \
        2>/dev/null | grep -v "$file" || true)
}

# --- Coleta de dados ---

# Imports diretos do arquivo alvo
direct_imports=""
case "$TARGET_EXT" in
    py)
        direct_imports=$(grep -n '^\s*from \|^\s*import ' "$ABS_TARGET" 2>/dev/null | \
            sed 's/.*from \+\([a-zA-Z_][a-zA-Z0-9_.]*\).*/\1/;s/.*import \+\([a-zA-Z_][a-zA-Z0-9_.]*\).*/\1/' | \
            while read -r imp; do
                # Resolver import local
                imp_path="${imp//./\/}"
                for candidate in "$PROJECT_PATH/${imp_path}.py" "$PROJECT_PATH/${imp_path}/__init__.py"; do
                    if [[ -f "$candidate" ]]; then
                        echo "${candidate#$PROJECT_PATH/}"
                        break
                    fi
                done
            done 2>/dev/null || echo "")
        ;;
    js|ts|jsx|tsx)
        direct_imports=$(grep -n "from ['\"]\|require(['\"]" "$ABS_TARGET" 2>/dev/null | \
            sed "s/.*from ['\"]\\([^'\"]*\\['\").*/\\1/;s/.*require(['\"]\\([^'\"]*\\['\").*/\\1/" | \
            while read -r imp; do
                if [[ "$imp" == ./* || "$imp" == ../* ]]; then
                    candidate="$PROJECT_PATH/${imp#./}"
                    for ext in .js .ts .jsx .tsx ""; do
                        if [[ -f "${candidate}${ext}" ]]; then
                            echo "${candidate}${ext}" | sed "s|$PROJECT_PATH/||"
                            break
                        fi
                    done
                fi
            done 2>/dev/null || echo "")
        ;;
    go)
        direct_imports=$(grep -o '"[^"]*"' "$ABS_TARGET" 2>/dev/null | tr -d '"' | \
            grep -v '^[a-z]' | \
            sed 's|.*/||' | \
            while read -r imp; do
                find "$PROJECT_PATH" -name "${imp}.go" -not -path '*/.git/*' 2>/dev/null | head -1 | sed "s|$PROJECT_PATH/||"
            done 2>/dev/null || echo "")
        ;;
esac

# Converter para array
declare -a direct_imports_arr=()
if [[ -n "$direct_imports" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" ]] && direct_imports_arr+=("$line")
    done <<< "$direct_imports"
fi

# Buscar importadores indiretos (depth > 1)
declare -a indirect_imports_arr=()
declare -A visited=()
visited["$ABS_TARGET"]=true

if [[ $MAX_DEPTH -gt 1 ]]; then
    queue="${direct_imports_arr[*]}"
    current_depth=1

    while [[ -n "$queue" ]] && [[ $current_depth -lt $MAX_DEPTH ]]; do
        next_queue=""
        for imp_file in $queue; do
            abs_imp="$PROJECT_PATH/$imp_file"
            [[ "${visited[$abs_imp]:-}" == "true" ]] && continue
            visited["$abs_imp"]=true

            while IFS= read -r -d '' importer; do
                [[ "${visited[$importer]:-}" == "true" ]] && continue
                imp_rel="${importer#$PROJECT_PATH/}"
                indirect_imports_arr+=("$imp_rel")
                next_queue="$next_queue $imp_rel"
            done < <(grep -rl --include='*.py' --include='*.js' --include='*.ts' --include='*.tsx' --include='*.jsx' --include='*.go' --include='*.rs' \
                -E "(import|from|require).*$(basename "$imp_file" .${imp_file##*.})" "$PROJECT_PATH" \
                -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' \
                2>/dev/null | grep -v "$imp_file" | grep -v "$ABS_TARGET" || true)
        done
        queue="$next_queue"
        current_depth=$((current_depth + 1))
    done
fi

# Arquivos de teste
test_files_arr=()
while IFS= read -r -d '' tf; do
    test_files_arr+=("${tf#$PROJECT_PATH/}")
done < <(find "$PROJECT_PATH" -type f \( \
    -name "test_${TARGET_NAME}*" -o \
    -name "*_test.${TARGET_EXT}" -o \
    -name "*${TARGET_NAME}*test*" -o \
    -name "*${TARGET_NAME}*spec*" \
    \) -not -path '*/.git/*' -not -path '*/node_modules/*' -print0 2>/dev/null || true)

# Nivel de risco
total_affected=$(( ${#direct_imports_arr[@]} + ${#indirect_imports_arr[@]} + ${#test_files_arr[@]} ))
risk_level="low"
risk_factors=()

if [[ $total_affected -ge 5 ]]; then
    risk_level="high"
    risk_factors+=("Arquivo importado por $total_affected outros arquivos")
elif [[ $total_affected -ge 3 ]]; then
    risk_level="medium"
    risk_factors+=("Arquivo importado por $total_affected outros arquivos")
fi

[[ ${#test_files_arr[@]} -gt 0 ]] && risk_factors+=("Possui testes associados")
file_lines=$(wc -l < "$ABS_TARGET" 2>/dev/null || echo 0)
[[ $file_lines -gt 500 ]] && risk_factors+=("Arquivo grande ($file_lines linhas)")

if [[ "$TARGET_NAME" == "main" || "$TARGET_NAME" == "index" || "$TARGET_NAME" == "app" || "$TARGET_NAME" == "__init__" ]]; then
    risk_factors+=("Arquivo central no modulo")
    [[ "$risk_level" == "low" ]] && risk_level="medium"
fi

# Sugestoes
suggestions_arr=()
if [[ ${#test_files_arr[@]} -gt 0 ]]; then
    suggestions_arr+=("Executar testes: pytest ${test_files_arr[0]}")
fi
if [[ ${#direct_imports_arr[@]} -gt 0 ]]; then
    for imp in "${direct_imports_arr[@]}"; do
        suggestions_arr+=("Verificar imports em $imp")
    done
fi

# --- Output ---

# Montar JSON arrays
direct_json="["
d_first=true
for f in "${direct_imports_arr[@]}"; do
    [[ "$d_first" == true ]] && d_first=false || direct_json+=","
    direct_json+="\"$f\""
done
direct_json+="]"

indirect_json="["
i_first=true
for f in "${indirect_imports_arr[@]}"; do
    [[ "$i_first" == true ]] && i_first=false || indirect_json+=","
    indirect_json+="\"$f\""
done
indirect_json+="]"

tests_json="["
t_first=true
for f in "${test_files_arr[@]}"; do
    [[ "$t_first" == true ]] && t_first=false || tests_json+=","
    tests_json+="\"$f\""
done
tests_json+="]"

factors_json="["
fa_first=true
for f in "${risk_factors[@]}"; do
    [[ "$fa_first" == true ]] && fa_first=false || factors_json+=","
    factors_json+="\"${f//\"/\\\"}\""
done
factors_json+="]"

suggestions_json="["
s_first=true
for s in "${suggestions_arr[@]}"; do
    [[ "$s_first" == true ]] && s_first=false || suggestions_json+=","
    suggestions_json+="\"${s//\"/\\\"}\""
done
suggestions_json+="]"

if [[ "$JSON_MODE" == true ]]; then
    cat <<EOF
{
  "status": "ok",
  "file": "$TARGET_FILE",
  "impact": {
    "direct_imports": $direct_json,
    "indirect_imports": $indirect_json,
    "test_files": $tests_json,
    "total_affected": $total_affected
  },
  "risk_level": "$risk_level",
  "risk_factors": $factors_json,
  "suggestions": $suggestions_json
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Analise de Impacto${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Arquivo:${RESET}  $TARGET_FILE"
    echo -e "  ${BOLD}Linhas:${RESET}   $file_lines"
    echo ""

    # Risk indicator
    case "$risk_level" in
        high)   echo -e "  ${BOLD}Risco:${RESET}    ${RED}${BOLD}ALTO${RESET}" ;;
        medium) echo -e "  ${BOLD}Risco:${RESET}    ${YELLOW}${BOLD}MEDIO${RESET}" ;;
        low)    echo -e "  ${BOLD}Risco:${RESET}    ${GREEN}${BOLD}BAIXO${RESET}" ;;
    esac

    if [[ ${#risk_factors[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Fatores:${RESET}"
        for f in "${risk_factors[@]}"; do
            echo -e "    ${DIM}•${RESET} $f"
        done
    fi

    echo ""
    echo -e "  ${BOLD}Imports diretos:${RESET}     ${#direct_imports_arr[@]}"
    for f in "${direct_imports_arr[@]}"; do
        echo -e "    ${GREEN}→${RESET} $f"
    done

    echo -e "  ${BOLD}Imports indiretos:${RESET}   ${#indirect_imports_arr[@]}"
    for f in "${indirect_imports_arr[@]}"; do
        echo -e "    ${YELLOW}→${RESET} $f"
    done

    echo -e "  ${BOLD}Testes:${RESET}              ${#test_files_arr[@]}"
    for f in "${test_files_arr[@]}"; do
        echo -e "    ${CYAN}✓${RESET} $f"
    done

    echo ""
    echo -e "  ${BOLD}Total afetado:${RESET}  $total_affected"
    echo ""

    if [[ ${#suggestions_arr[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Sugestoes:${RESET}"
        for s in "${suggestions_arr[@]}"; do
            echo -e "    ${DIM}•${RESET} $s"
        done
    fi

    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
