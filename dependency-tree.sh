#!/bin/bash
# dependency-tree.sh — Mostra arvore de dependencias internas do projeto
# Uso: ./dependency-tree.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --file FILE         Arquivo especifico para analisar
#   --project PATH      Caminho do projeto (padrao: diretorio atual)
#   --max-depth N       Profundidade maxima (padrao: 3)
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
MAX_DEPTH=3

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --file|-f)
            [[ -z "${2-}" ]] && error "Flag --file requer um valor"
            TARGET_FILE="$2"; shift 2 ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --max-depth|-d)
            [[ -z "${2-}" ]] && error "Flag --max-depth requer um valor"
            MAX_DEPTH="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  dependency-tree.sh — Mostra arvore de dependencias internas do projeto"
            echo ""
            echo "  Uso: ./dependency-tree.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --file|-f FILE      Arquivo especifico para analisar"
            echo "    --project|-p PATH   Caminho do projeto (padrao: diretorio atual)"
            echo "    --max-depth|-d N    Profundidade maxima (padrao: 3)"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "dependency-tree.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# --- Coleta de todos os arquivos de codigo ---
declare -a code_files=()
while IFS= read -r -d '' file; do
    code_files+=("$file")
done < <(find "$PROJECT_PATH" -type f \
    \( -name '*.py' -o -name '*.js' -o -name '*.ts' -o -name '*.tsx' -o -name '*.jsx' \
       -o -name '*.go' -o -name '*.rs' -o -name '*.java' -o -name '*.sh' -o -name '*.bash' \) \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/.venv/*' \
    -not -path '*/target/*' \
    -not -path '*/vendor/*' \
    -not -path '*/dist/*' \
    -not -path '*/build/*' \
    -print0 2>/dev/null || true)

# --- Funcao para resolver import local ---

resolve_import() {
    local file="$1"
    local imp="$2"
    local project="$3"

    # Python: from src.auth import ...
    if [[ "$imp" == src.* ]]; then
        imp_path="${imp//src\//src/}"
        for ext in .py ""; do
            candidate="$project/${imp_path}${ext}"
            if [[ -f "$candidate" ]]; then
                echo "${candidate#$project/}"
                return
            fi
        done
    fi

    # JavaScript/TypeScript: ./auth, ../utils/crypto
    if [[ "$imp" == .* ]]; then
        local dir
        dir=$(dirname "$file")
        for ext in .js .ts .jsx .tsx .mjs ""; do
            candidate="$project/$dir/${imp}${ext}"
            if [[ -f "$candidate" ]]; then
                echo "${candidate#$project/}"
                return
            fi
        done
    fi
}

# --- Construir grafo de dependencias ---
declare -A tree=()       # arquivo -> imports (separados por ;)
declare -A imported_by=() # arquivo -> quem importa (separados por ;)

files_analyzed=0

for file in "${code_files[@]}"; do
    rel_file="${file#$PROJECT_PATH/}"
    ext="${file##*.}"

    # Extrair imports locais
    local_imports=""
    case "$ext" in
        py)
            local_imports=$(grep -n '^\s*from \.\|^\s*from src\.\|^\s*import \.' "$file" 2>/dev/null | \
                sed 's/.*from \([a-zA-Z_.][a-zA-Z0-9_.]*\).*/\1/;s/.*import \([a-zA-Z_.][a-zA-Z0-9_.]*\).*/\1/' | \
                while read -r imp; do
                    resolved=$(resolve_import "$rel_file" "$imp" "$PROJECT_PATH")
                    [[ -n "$resolved" ]] && echo "$resolved"
                done 2>/dev/null || echo "")
            ;;
        js|ts|jsx|tsx)
            local_imports=$(grep -n "from ['\"]\\.\|require(['\"]\\." "$file" 2>/dev/null | \
                sed "s/.*from ['\"]\\([^'\"]*\\['\").*/\\1/;s/.*require(['\"]\\([^'\"]*\\['\").*/\\1/" | \
                while read -r imp; do
                    resolved=$(resolve_import "$rel_file" "$imp" "$PROJECT_PATH")
                    [[ -n "$resolved" ]] && echo "$resolved"
                done 2>/dev/null || echo "")
            ;;
        go)
            local_imports=$(grep -o '"\\./[^"]*"' "$file" 2>/dev/null | tr -d '"' | \
                while read -r imp; do
                    resolved=$(resolve_import "$rel_file" "$imp" "$PROJECT_PATH")
                    [[ -n "$resolved" ]] && echo "$resolved"
                done 2>/dev/null || echo "")
            ;;
    esac

    # Armazenar imports
    imports_csv=""
    if [[ -n "$local_imports" ]]; then
        while IFS= read -r imp; do
            [[ -z "$imp" ]] && continue
            imports_csv="${imports_csv:+$imports_csv;}$imp"
            # Atualizar imported_by
            current="${imported_by[$imp]:-}"
            imported_by["$imp"]="${current:+$current;}$rel_file"
        done <<< "$local_imports"
    fi

    tree["$rel_file"]="$imports_csv"
    files_analyzed=$((files_analyzed + 1))
done

# --- Detectar dependencias circulares ---
circular_deps=()
declare -A visited_dfs=()

check_circular() {
    local file="$1"
    local path="$2"

    if [[ "${visited_dfs[$file]:-}" == "visiting" ]]; then
        circular_deps+=("$path → $file")
        return
    fi
    [[ "${visited_dfs[$file]:-}" == "done" ]] && return

    visited_dfs["$file"]="visiting"
    IFS=';' read -ra imports <<< "${tree[$file]:-}"
    for imp in "${imports[@]}"; do
        [[ -z "$imp" ]] && continue
        check_circular "$imp" "$path → $imp"
    done
    visited_dfs["$file"]="done"
}

for file in "${code_files[@]}"; do
    rel="${file#$PROJECT_PATH/}"
    check_circular "$rel" "$rel"
done

# --- Detectar arquivos orfaos ---
orphan_files=()
for file in "${code_files[@]}"; do
    rel="${file#$PROJECT_PATH/}"
    # Arquivo e orphan se ninguem importa ele e ele nao importa ninguem
    [[ -z "${imported_by[$rel]:-}" && -z "${tree[$rel]:-}" ]] && orphan_files+=("$rel")
done

# --- Acoplamento alto ---
high_coupling=()
for file in "${code_files[@]}"; do
    rel="${file#$PROJECT_PATH/}"
    dep_count=$(echo "${imported_by[$rel]:-}" | tr ';' '\n' | grep -c . 2>/dev/null) || dep_count=0
    if [[ $dep_count -ge 3 ]]; then
        high_coupling+=("$rel ($dep_count dependents)")
    fi
done

# --- Output JSON ---

tree_json="{"
t_first=true
for file in "${!tree[@]}"; do
    [[ "$t_first" == true ]] && t_first=false || tree_json+=","
    imports_arr="["
    ib_first=true
    IFS=';' read -ra imps <<< "${tree[$file]:-}"
    for imp in "${imps[@]}"; do
        [[ -z "$imp" ]] && continue
        [[ "$ib_first" == true ]] && ib_first=false || imports_arr+=","
        imports_arr+="\"$imp\""
    done
    imports_arr+="]"

    imported_by_arr="["
    ib2_first=true
    IFS=';' read -ra ibers <<< "${imported_by[$file]:-}"
    for ib in "${ibers[@]}"; do
        [[ -z "$ib" ]] && continue
        [[ "$ib2_first" == true ]] && ib2_first=false || imported_by_arr+=","
        imported_by_arr+="\"$ib\""
    done
    imported_by_arr+="]"

    tree_json+="\"$file\":{\"imports\":$imports_arr,\"imported_by\":$imported_by_arr}"
done
tree_json+="}"

circular_json="["
c_first=true
for c in "${circular_deps[@]}"; do
    [[ "$c_first" == true ]] && c_first=false || circular_json+=","
    circular_json+="\"${c//\"/\\\"}\""
done
circular_json+="]"

orphan_json="["
o_first=true
for o in "${orphan_files[@]}"; do
    [[ "$o_first" == true ]] && o_first=false || orphan_json+=","
    orphan_json+="\"$o\""
done
orphan_json+="]"

coupling_json="["
c2_first=true
for c in "${high_coupling[@]}"; do
    [[ "$c2_first" == true ]] && c2_first=false || coupling_json+=","
    coupling_json+="\"${c//\"/\\\"}\""
done
coupling_json+="]"

if [[ "$JSON_MODE" == true ]]; then
    cat <<EOF
{
  "status": "ok",
  "project": "$PROJECT_NAME",
  "files_analyzed": $files_analyzed,
  "tree": $tree_json,
  "circular_dependencies": $circular_json,
  "orphan_files": $orphan_json,
  "high_coupling": $coupling_json
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Arvore de Dependencias${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Projeto:${RESET}       $PROJECT_NAME"
    echo -e "  ${BOLD}Arquivos analisados:${RESET} $files_analyzed"
    echo ""

    # Arvore visual
    echo -e "  ${BOLD}Arvore:${RESET}"
    for file in $(echo "${!tree[@]}" | tr ' ' '\n' | sort); do
        imports="${tree[$file]:-}"
        ib="${imported_by[$file]:-}"
        ib_count=$(echo "$ib" | tr ';' '\n' | grep -c . || echo 0)

        if [[ -n "$imports" ]]; then
            echo -e "  ${GREEN}→${RESET} $file"
            IFS=';' read -ra imps <<< "$imports"
            for imp in "${imps[@]}"; do
                [[ -z "$imp" ]] && continue
                echo -e "    ${DIM}├─ $imp${RESET}"
            done
        else
            echo -e "  ${DIM}→ $file${RESET}  ${DIM}(sem imports locais)${RESET}"
        fi
    done

    echo ""

    if [[ ${#circular_deps[@]} -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}Dependencias circulares:${RESET}"
        for c in "${circular_deps[@]}"; do
            echo -e "    ${RED}⚠ $c${RESET}"
        done
        echo ""
    fi

    if [[ ${#orphan_files[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Arquivos orfaos:${RESET}"
        for o in "${orphan_files[@]}"; do
            echo -e "    ${YELLOW}• $o${RESET}"
        done
        echo ""
    fi

    if [[ ${#high_coupling[@]} -gt 0 ]]; then
        echo -e "  ${RED}Acoplamento alto:${RESET}"
        for c in "${high_coupling[@]}"; do
            echo -e "    ${RED}⚠ $c${RESET}"
        done
        echo ""
    fi

    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
