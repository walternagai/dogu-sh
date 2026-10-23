#!/bin/bash
# json-yaml-tool.sh — Valida, formata, consulta e converte JSON/YAML
# Uso: ./json-yaml-tool.sh [opcoes] ARQUIVO
# Opcoes:
#   --validate          Valida o arquivo (exit 0/1)
#   --format            Formata (pretty-print) o arquivo
#   --query EXPR        Aplica uma expressao jq (JSON ou YAML convertido)
#   --to-yaml           Converte JSON para YAML
#   --to-json           Converte YAML para JSON
#   -o, --output FILE   Escreve o resultado em FILE
#   -h, --help          Mostra esta ajuda
#   -V, --version       Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

INPUT=""
OUTPUT=""
MODE=""
QUERY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --validate) MODE="validate"; shift ;;
        --format)   MODE="format"; shift ;;
        --to-yaml)  MODE="to-yaml"; shift ;;
        --to-json)  MODE="to-json"; shift ;;
        --query)
            [[ -z "${2-}" ]] && { echo "Flag --query requer um valor" >&2; exit 2; }
            MODE="query"; QUERY="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 2; }
            OUTPUT="$2"; shift 2 ;;
        -h|--help)
            echo ""
            echo "  json-yaml-tool.sh — Valida, formata, consulta e converte JSON/YAML"
            echo ""
            echo "  Uso: ./json-yaml-tool.sh [opcoes] ARQUIVO"
            echo ""
            echo "  Opcoes:"
            echo "    --validate          Valida o arquivo (exit 0/1)"
            echo "    --format            Formata (pretty-print)"
            echo "    --query EXPR        Aplica uma expressao jq"
            echo "    --to-yaml           Converte JSON para YAML"
            echo "    --to-json           Converte YAML para JSON"
            echo "    -o, --output FILE   Escreve em FILE"
            echo "    -h, --help          Mostra esta ajuda"
            echo "    -V, --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./json-yaml-tool.sh --format config.json"
            echo "    ./json-yaml-tool.sh --query '.users[] | .name' dados.json"
            echo "    ./json-yaml-tool.sh --to-yaml config.json -o config.yaml"
            echo "    ./json-yaml-tool.sh --to-json config.yaml"
            echo "    ./json-yaml-tool.sh --validate dados.json"
            echo ""
            exit 0
            ;;
        -V|--version) echo "json-yaml-tool.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            error "Opcao desconhecida: $1" ;;
        *)
            [[ -z "$INPUT" ]] && INPUT="$1" || error "Argumento inesperado: $1"
            shift ;;
    esac
done

command -v jq &>/dev/null || error "jq nao encontrado. Instale jq."
[[ -n "$INPUT" ]] || error "Informe um arquivo JSON ou YAML."
[[ -f "$INPUT" ]] || error "Arquivo nao encontrado: $INPUT"

EXT="${INPUT##*.}"
case "${EXT,,}" in
    json) KIND="json" ;;
    yaml|yml) KIND="yaml" ;;
    *) error "Extensao nao suportada: .$EXT (use .json, .yaml ou .yml)" ;;
esac

require_yaml() {
    python3 -c 'import yaml' 2>/dev/null || error "PyYAML nao encontrado. Instale com: python3 -m pip install --user pyyaml"
}

yaml_to_json() {
    require_yaml
    python3 - "$INPUT" <<'PY'
import json, sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)
json.dump(data, sys.stdout, ensure_ascii=False)
PY
}

json_to_yaml() {
    require_yaml
    python3 - "$INPUT" <<'PY'
import json, sys, yaml
with open(sys.argv[1]) as f:
    data = json.load(f)
yaml.safe_dump(data, sys.stdout, sort_keys=False, allow_unicode=True)
PY
}

json_source() {
    if [[ "$KIND" == "yaml" ]]; then
        yaml_to_json
    else
        cat "$INPUT"
    fi
}

run_mode() {
    case "$MODE" in
        validate)
            if [[ "$KIND" == "yaml" ]]; then
                require_yaml
                python3 -c 'import sys,yaml; yaml.safe_load(open(sys.argv[1]))' "$INPUT" \
                    && success "YAML valido: $INPUT"
            else
                jq empty "$INPUT" && success "JSON valido: $INPUT"
            fi
            ;;
        to-yaml)
            [[ "$KIND" == "json" ]] || error "--to-yaml exige um arquivo .json"
            json_to_yaml
            ;;
        to-json)
            [[ "$KIND" == "yaml" ]] || error "--to-json exige um arquivo .yaml/.yml"
            yaml_to_json | jq .
            ;;
        query)
            json_source | jq "$QUERY"
            ;;
        format|"")
            if [[ "$KIND" == "yaml" ]]; then
                yaml_to_json | jq .
            else
                jq . "$INPUT"
            fi
            ;;
    esac
}

if [[ -n "$OUTPUT" ]]; then
    run_mode > "$OUTPUT"
    success "Resultado salvo em: $OUTPUT"
else
    run_mode
fi
