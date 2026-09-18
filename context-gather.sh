#!/bin/bash
# context-gather.sh — Coleta contexto do projeto para agentes de IA antes de modificar codigo
# Uso: ./context-gather.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --project PATH      Caminho do projeto (padrao: diretorio atual)
#   --file FILE         Arquivo especifico para analisar
#   --include-deps      Inclui analise de dependencias
#   --include-tests     Inclui testes relacionados
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
INCLUDE_DEPS=false
INCLUDE_TESTS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --file|-f)
            [[ -z "${2-}" ]] && error "Flag --file requer um valor"
            TARGET_FILE="$2"; shift 2 ;;
        --include-deps) INCLUDE_DEPS=true; shift ;;
        --include-tests) INCLUDE_TESTS=true; shift ;;
        --help|-h)
            echo ""
            echo "  context-gather.sh — Coleta contexto do projeto para agentes de IA"
            echo ""
            echo "  Uso: ./context-gather.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --project|-p PATH   Caminho do projeto (padrao: diretorio atual)"
            echo "    --file|-f FILE      Arquivo especifico para analisar"
            echo "    --include-deps      Inclui analise de dependencias"
            echo "    --include-tests     Inclui testes relacionados"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "context-gather.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)
PROJECT_NAME=$(basename "$PROJECT_PATH")

# Detectar linguagem primaria por manifest files
primary_lang="unknown"
stack="unknown"
if [[ -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/setup.py" || -f "$PROJECT_PATH/requirements.txt" ]]; then
    primary_lang="python"
    stack="python"
    if grep -q 'fastapi' "$PROJECT_PATH/pyproject.toml" 2>/dev/null || grep -q 'fastapi' "$PROJECT_PATH/requirements.txt" 2>/dev/null; then
        stack="python+fastapi"
    elif grep -q 'django' "$PROJECT_PATH/pyproject.toml" 2>/dev/null || grep -q 'django' "$PROJECT_PATH/requirements.txt" 2>/dev/null; then
        stack="python+django"
    elif grep -q 'flask' "$PROJECT_PATH/pyproject.toml" 2>/dev/null || grep -q 'flask' "$PROJECT_PATH/requirements.txt" 2>/dev/null; then
        stack="python+flask"
    fi
elif [[ -f "$PROJECT_PATH/package.json" ]]; then
    primary_lang="javascript"
    stack="node"
    if grep -q 'next' "$PROJECT_PATH/package.json" 2>/dev/null; then
        stack="node+nextjs"
    elif grep -q 'express' "$PROJECT_PATH/package.json" 2>/dev/null; then
        stack="node+express"
    elif grep -q 'react' "$PROJECT_PATH/package.json" 2>/dev/null; then
        stack="node+react"
    fi
elif [[ -f "$PROJECT_PATH/go.mod" ]]; then
    primary_lang="go"
    stack="go"
elif [[ -f "$PROJECT_PATH/Cargo.toml" ]]; then
    primary_lang="rust"
    stack="rust"
fi

# Ler description do README
readme_summary=""
readme_file=""
for f in README.md README.rst README; do
    if [[ -f "$PROJECT_PATH/$f" ]]; then
        readme_file="$PROJECT_PATH/$f"
        break
    fi
done
if [[ -n "$readme_file" ]]; then
    # Pegar primeira linha nao-vazia que nao e titulo
    readme_summary=$(awk 'NR>1 && NF && $0 !~ /^#/ {gsub(/^[ \t]+/,"",$0); print; exit}' "$readme_file" 2>/dev/null || echo "")
fi

# Recent git changes
recent_changes=""
if command -v git &>/dev/null && [[ -d "$PROJECT_PATH/.git" ]]; then
    recent_changes=$(git -C "$PROJECT_PATH" log --oneline -10 2>/dev/null | sed 's/"/\\"/g' || echo "")
fi

# Convencoes do codigo
conventions="[]"
if [[ "$primary_lang" == "python" ]]; then
    conventions='["snake_case", "type hints"]'
elif [[ "$primary_lang" == "javascript" || "$primary_lang" == "typescript" ]]; then
    conventions='["camelCase", "ES modules"]'
elif [[ "$primary_lang" == "go" ]]; then
    conventions='["Go conventions", "camelCase"]'
elif [[ "$primary_lang" == "rust" ]]; then
    conventions='["snake_case", "Rust idioms"]'
fi

# --- Output ---

if [[ "$JSON_MODE" == true ]]; then
    if [[ -n "$TARGET_FILE" ]]; then
        # Analise de arquivo especifico
        [[ ! -f "$PROJECT_PATH/$TARGET_FILE" ]] && error "Arquivo nao encontrado: $TARGET_FILE"

        # Extrair funcoes, classes, imports
        file_ext="${TARGET_FILE##*.}"
        file_lines=$(wc -l < "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null || echo 0)

        funcs_json="[]"
        classes_json="[]"
        imports_json="[]"

        case "$file_ext" in
            py)
                funcs=$(grep -n '^\s*def \|^def ' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/.*def \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | tr '\n' ',' || echo "")
                classes=$(grep -n '^\s*class \|^class ' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/.*class \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | tr '\n' ',' || echo "")
                imports=$(grep -n '^\s*import \|^from ' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/.*import \+\([a-zA-Z_][a-zA-Z0-9_.]*\).*/\1/' | tr '\n' ',' || echo "")
                [[ -n "$funcs" ]] && funcs_json="[\"${funcs%,}\"]"
                [[ -n "$classes" ]] && classes_json="[\"${classes%,}\"]"
                [[ -n "$imports" ]] && imports_json="[\"${imports%,}\"]"
                ;;
            js|ts|jsx|tsx)
                funcs=$(grep -n 'function \+\|const \+[a-zA-Z_]* *=' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/.*function \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/;s/.*const \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | tr '\n' ',' || echo "")
                classes=$(grep -n 'class \+' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/.*class \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | tr '\n' ',' || echo "")
                imports=$(grep -n "from ['\"]\|require(['\"]\|import " "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed "s/.*from ['\"]\\([^'\"]*\\['\").*/\\1/;s/.*require(['\"]\\([^'\"]*\\['\").*/\\1/;s/.*import ['\"]\\([^'\"]*\\['\").*/\\1/" | tr '\n' ',' || echo "")
                [[ -n "$funcs" ]] && funcs_json="[\"${funcs%,}\"]"
                [[ -n "$classes" ]] && classes_json="[\"${classes%,}\"]"
                [[ -n "$imports" ]] && imports_json="[\"${imports%,}\"]"
                ;;
            go)
                funcs=$(grep -n '^func ' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/^func \+\([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | tr '\n' ',' || echo "")
                imports=$(grep -n '"[^"]*"' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | grep -v '//' | sed 's/.*"\([^"]*\)".*/\1/' | tr '\n' ',' || echo "")
                [[ -n "$funcs" ]] && funcs_json="[\"${funcs%,}\"]"
                [[ -n "$imports" ]] && imports_json="[\"${imports%,}\"]"
                ;;
            sh|bash)
                funcs=$(grep -n '^[a-zA-Z_][a-zA-Z0-9_]*()' "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null | sed 's/:.*//;s/().*//' | tr '\n' ',' || echo "")
                [[ -n "$funcs" ]] && funcs_json="[\"${funcs%,}\"]"
                ;;
        esac

        # Arquivos relacionados
        related_files="[]"
        if $INCLUDE_TESTS; then
            # Encontrar testes para este arquivo
            basename_no_ext=$(basename "$TARGET_FILE" ".$file_ext")
            test_files=""
            while IFS= read -r -d '' tf; do
                test_files="${test_files:+$test_files,}\"${tf#$PROJECT_PATH/}\""
            done < <(find "$PROJECT_PATH" -type f \( -name "test_${basename_no_ext}*" -o -name "*_test.${file_ext}" -o -name "*${basename_no_ext}*test*" \) -not -path '*/.git/*' -print0 2>/dev/null || true)
            [[ -n "$test_files" ]] && related_files="[$test_files]"
        fi

        # Construir JSON de recent changes como array
        changes_json="[]"
        if [[ -n "$recent_changes" ]]; then
            changes_json="["
            ch_first=true
            while IFS= read -r ch; do
                [[ -z "$ch" ]] && continue
                [[ "$ch_first" == true ]] && ch_first=false || changes_json+=","
                changes_json+="\"${ch//\"/\\\"}\""
            done <<< "$recent_changes"
            changes_json+="]"
        fi

        cat <<EOF
{
  "status": "ok",
  "project": {
    "name": "$PROJECT_NAME",
    "stack": "$stack",
    "description": "$readme_summary"
  },
  "file": {
    "path": "$TARGET_FILE",
    "language": "$file_ext",
    "lines": $file_lines,
    "functions": $funcs_json,
    "classes": $classes_json,
    "imports": $imports_json,
    "related_files": $related_files
  },
  "context": {
    "readme_summary": "${readme_summary//\"/\\\"}",
    "recent_changes": $changes_json,
    "conventions": $conventions
  }
}
EOF
    else
        # Resumo geral do projeto
        changes_json="[]"
        if [[ -n "$recent_changes" ]]; then
            changes_json="["
            ch_first=true
            while IFS= read -r ch; do
                [[ -z "$ch" ]] && continue
                [[ "$ch_first" == true ]] && ch_first=false || changes_json+=","
                changes_json+="\"${ch//\"/\\\"}\""
            done <<< "$recent_changes"
            changes_json+="]"
        fi

        cat <<EOF
{
  "status": "ok",
  "project": {
    "name": "$PROJECT_NAME",
    "stack": "$stack",
    "description": "${readme_summary//\"/\\\"}"
  },
  "context": {
    "readme_summary": "${readme_summary//\"/\\\"}",
    "recent_changes": $changes_json,
    "conventions": $conventions
  }
}
EOF
    fi
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Contexto do Projeto${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Projeto:${RESET}  $PROJECT_NAME"
    echo -e "  ${BOLD}Stack:${RESET}    $stack"
    [[ -n "$readme_summary" ]] && echo -e "  ${BOLD}Descricao:${RESET} $readme_summary"
    echo ""

    if [[ -n "$TARGET_FILE" ]]; then
        [[ ! -f "$PROJECT_PATH/$TARGET_FILE" ]] && error "Arquivo nao encontrado: $TARGET_FILE"
        echo -e "  ${BOLD}Arquivo:${RESET}  $TARGET_FILE"
        echo -e "  ${BOLD}Linhas:${RESET}   $(wc -l < "$PROJECT_PATH/$TARGET_FILE" 2>/dev/null || echo 0)"
        echo ""
    fi

    if [[ -n "$recent_changes" ]]; then
        echo -e "  ${BOLD}Mudancas recentes:${RESET}"
        echo "$recent_changes" | while IFS= read -r ch; do
            echo -e "    ${DIM}•${RESET} $ch"
        done
    fi

    echo ""
    echo -e "  ${BOLD}Convencoes:${RESET}  ${conventions//\"/}"
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi
