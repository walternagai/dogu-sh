#!/bin/bash
# env-validator.sh — Valida variaveis de ambiente obrigatorias para o projeto
# Uso: ./env-validator.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --project PATH      Caminho do projeto (padrao: diretorio atual)
#   --env-file FILE     Arquivo .env para validar (padrao: .env)
#   --strict            Falha se variaveis obrigatorias estiverem faltando
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
ENV_FILE=".env"
STRICT_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json|-j) JSON_MODE=true; shift ;;
        --project|-p)
            [[ -z "${2-}" ]] && error "Flag --project requer um valor"
            PROJECT_PATH="$2"; shift 2 ;;
        --env-file|-e)
            [[ -z "${2-}" ]] && error "Flag --env-file requer um valor"
            ENV_FILE="$2"; shift 2 ;;
        --strict|-s) STRICT_MODE=true; shift ;;
        --help|-h)
            echo ""
            echo "  env-validator.sh — Valida variaveis de ambiente obrigatorias para o projeto"
            echo ""
            echo "  Uso: ./env-validator.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json|-j           Saida em formato JSON"
            echo "    --project|-p PATH   Caminho do projeto (padrao: diretorio atual)"
            echo "    --env-file|-e FILE  Arquivo .env para validar (padrao: .env)"
            echo "    --strict|-s         Falha se variaveis obrigatorias estiverem faltando"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "env-validator.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

[[ ! -d "$PROJECT_PATH" ]] && error "Diretorio nao encontrado: $PROJECT_PATH"
PROJECT_PATH=$(cd "$PROJECT_PATH" && pwd)

# Resolver caminho do .env
if [[ "$ENV_FILE" == /* ]]; then
    ENV_ABS="$ENV_FILE"
else
    ENV_ABS="$PROJECT_PATH/$ENV_FILE"
fi

# Variaveis obrigatorias comuns (detectadas por contexto)
declare -A REQUIRED_VARS

# Detectar framework/language para definir variaveis obrigatorias
if [[ -f "$PROJECT_PATH/pyproject.toml" || -f "$PROJECT_PATH/requirements.txt" ]]; then
    REQUIRED_VARS[DATABASE_URL]="URL de conexao com o banco de dados"
    REQUIRED_VARS[SECRET_KEY]="Chave secreta da aplicacao"
fi
if [[ -f "$PROJECT_PATH/package.json" ]]; then
    REQUIRED_VARS[NODE_ENV]="Ambiente de execucao (development/production)"
fi
# Variaveis sempre relevantes
REQUIRED_VARS[API_KEY]="Chave de API externa"

# Ler variaveis do .env
declare -A env_vars=()
env_file_exists=false

if [[ -f "$ENV_ABS" ]]; then
    env_file_exists=true
    while IFS= read -r line; do
        # Ignorar comentarios e linhas vazias
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$line" ]] && continue
        # Parse KEY=VALUE
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Remover aspas
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            env_vars["$key"]="$value"
        fi
    done < "$ENV_ABS"
fi

# Validar variaveis
declare -A variables_json=()
required_missing=()
empty_required=()
suggestions=()

for var in "${!REQUIRED_VARS[@]}"; do
    value="${env_vars[$var]:-}"
    source="env"

    # Verificar se esta no ambiente
    if [[ -n "${!var:-}" ]]; then
        value="${!var}"
        source="environment"
    fi

    defined=false
    empty=true

    if [[ -n "$value" ]]; then
        defined=true
        empty=false
    elif [[ -n "${!var:-}" ]]; then
        defined=true
        empty=false
    fi

    variables_json["$var"]="{\"defined\":$defined,\"empty\":$empty,\"source\":\"$source\"}"

    if ! $defined; then
        required_missing+=("$var")
        suggestions+=("Adicione $var ao $ENV_FILE")
    elif $empty; then
        empty_required+=("$var")
        suggestions+=("Defina $var com um valor seguro")
    fi
done

validation_passed=true
[[ ${#required_missing[@]} -gt 0 ]] && validation_passed=false
[[ ${#empty_required[@]} -gt 0 ]] && validation_passed=false

# Montar JSON
vars_json="{"
v_first=true
for var in "${!variables_json[@]}"; do
    [[ "$v_first" == true ]] && v_first=false || vars_json+=","
    vars_json+="\"$var\":${variables_json[$var]}"
done
vars_json+="}"

missing_json="["
m_first=true
for v in "${required_missing[@]}"; do
    [[ "$m_first" == true ]] && m_first=false || missing_json+=","
    missing_json+="\"$v\""
done
missing_json+="]"

empty_json="["
e_first=true
for v in "${empty_required[@]}"; do
    [[ "$e_first" == true ]] && e_first=false || empty_json+=","
    empty_json+="\"$v\""
done
empty_json+="]"

suggestions_json="["
s_first=true
for s in "${suggestions[@]}"; do
    [[ "$s_first" == true ]] && s_first=false || suggestions_json+=","
    suggestions_json+="\"${s//\"/\\\"}\""
done
suggestions_json+="]"

if [[ "$JSON_MODE" == true ]]; then
    cat <<EOF
{
  "status": "ok",
  "env_file": "$ENV_FILE",
  "env_file_exists": $env_file_exists,
  "variables": $vars_json,
  "required_missing": $missing_json,
  "empty_required": $empty_json,
  "validation_passed": $validation_passed,
  "suggestions": $suggestions_json
}
EOF
else
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Validacao de Variaveis de Ambiente${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${BOLD}Arquivo:${RESET}  $ENV_FILE"
    if $env_file_exists; then
        echo -e "  ${GREEN}✓${RESET} Arquivo encontrado"
    else
        echo -e "  ${YELLOW}⚠${RESET} Arquivo nao encontrado"
    fi
    echo ""

    echo -e "  ${BOLD}Variaveis:${RESET}"
    for var in "${!variables_json[@]}"; do
        value="${env_vars[$var]:-}"
        [[ -n "${!var:-}" ]] && value="${!var}" && source="env" || source="env"

        defined=false
        empty=true
        if [[ -n "$value" ]]; then
            defined=true
            empty=false
        elif [[ -n "${!var:-}" ]]; then
            defined=true
            empty=false
        fi

        if $defined && ! $empty; then
            echo -e "    ${GREEN}✓${RESET} $var"
        elif $defined && $empty; then
            echo -e "    ${YELLOW}⚠${RESET} $var ${DIM}(vazio)${RESET}"
        else
            echo -e "    ${RED}✗${RESET} $var ${DIM}(nao definido)${RESET}"
        fi
    done

    echo ""

    if [[ ${#required_missing[@]} -gt 0 ]]; then
        echo -e "  ${RED}Variaveis faltando:${RESET}"
        for v in "${required_missing[@]}"; do
            echo -e "    ${RED}✗${RESET} $v — ${REQUIRED_VARS[$v]}"
        done
    fi

    if [[ ${#empty_required[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Variaveis vazias:${RESET}"
        for v in "${empty_required[@]}"; do
            echo -e "    ${YELLOW}⚠${RESET} $v"
        done
    fi

    echo ""
    if $validation_passed; then
        echo -e "  ${GREEN}✓ Validacao passou${RESET}"
    else
        echo -e "  ${RED}✗ Validacao falhou${RESET}"
    fi

    if [[ ${#suggestions[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${BOLD}Sugestoes:${RESET}"
        for s in "${suggestions[@]}"; do
            echo -e "    ${DIM}•${RESET} $s"
        done
    fi

    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
fi

# Exit code no modo strict
if $STRICT_MODE && ! $validation_passed; then
    exit 1
fi
