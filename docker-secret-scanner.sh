#!/bin/bash
# docker-secret-scanner.sh — Escaneia containers em busca de segredos expostos
# Uso: ./docker-secret-scanner.sh [opcoes]
# Opcoes:
#   --all           Escaneia todos os containers rodando (padrao)
#   --container C   Escaneia apenas container especifico
#   --env-only      Escaneia apenas variaveis de ambiente
#   --labels-only   Escaneia apenas labels
#   --severity LEVEL Filtra por severidade: low, medium, high, critical
#   --json           Saida em formato JSON
#   --help           Mostra esta ajuda
#   --version        Mostra versao

set -euo pipefail


readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi




FILTER_CONTAINER=""
ENV_ONLY=false
LABELS_ONLY=false
SEVERITY_FILTER=""
JSON_OUTPUT=false

total_high=0
total_medium=0
total_low=0
json_results=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all|-a) shift ;;
        --container|-c)
            [[ -z "${2-}" ]] && { echo "Flag --container requer um valor" >&2; exit 1; }
            FILTER_CONTAINER="$2"; shift 2 ;;
        --env-only) ENV_ONLY=true; shift ;;
        --labels-only) LABELS_ONLY=true; shift ;;
        --severity|-s)
            [[ -z "${2-}" ]] && { echo "Flag --severity requer um valor" >&2; exit 1; }
            SEVERITY_FILTER="$2"; shift 2 ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-secret-scanner.sh — Detecta segredos expostos em containers"
            echo ""
            echo "  Uso: ./docker-secret-scanner.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all           Escaneia todos os containers (padrao)"
            echo "    --container C   Escaneia apenas container especifico"
            echo "    --env-only      Apenas variaveis de ambiente"
            echo "    --labels-only   Apenas labels"
            echo "    --severity LEVEL Filtra: low, medium, high, critical"
            echo "    --json           Saida em formato JSON"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Padroes detectados:"
            echo "    AWS keys, tokens, secrets"
            echo "    Connection strings com credenciais"
            echo "    Private keys (BEGIN RSA/PRIVATE)"
            echo "    Generic passwords/secrets em env vars"
            echo "    API keys (generic headers)"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-secret-scanner.sh"
            echo "    ./docker-secret-scanner.sh --container nginx"
            echo "    ./docker-secret-scanner.sh --severity high --json"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-secret-scanner.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

add_finding() {
    local container="$1"
    local location="$2"
    local key="$3"
    local value_preview="$4"
    local severity="$5"
    local rule="$6"

    if [ -n "$SEVERITY_FILTER" ] && [ "$severity" != "$SEVERITY_FILTER" ]; then
        return
    fi

    case "$severity" in
        high|critical) total_high=$((total_high + 1)); icon="${RED}HIGH${RESET}" ;;
        medium) total_medium=$((total_medium + 1)); icon="${YELLOW}MED${RESET}" ;;
        low) total_low=$((total_low + 1)); icon="${CYAN}LOW${RESET}" ;;
    esac

    if ! $JSON_OUTPUT; then
        value_safe=$(echo "$value_preview" | cut -c1-40)
        echo -e "  ${icon}  [${location}]  ${BOLD}${key}${RESET}=${DIM}${value_safe}${RESET}  (${rule})"
    else
        json_results="${json_results}{\"container\":\"$container\",\"location\":\"$location\",\"key\":\"$key\",\"severity\":\"$severity\",\"rule\":\"$rule\"},"
    fi
}

scan_env() {
    local cid="$1"
    local cname="$2"
    local env_content
    env_content=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$cid" 2>/dev/null)

    echo "$env_content" | while IFS='=' read -r key value; do
        [ -z "$key" ] && continue
        key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')
        value_lower=$(echo "$value" | tr '[:upper:]' '[:lower:]')

        if echo "$value" | grep -qE '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----'; then
            add_finding "$cname" "env" "$key" "[PRIVATE KEY]" "high" "private-key-in-env"
            continue
        fi

        case "$key_lower" in
            *aws_access_key_id*)
                if echo "$value" | grep -qE '^AKIA[0-9A-Z]{16,}$'; then
                    add_finding "$cname" "env" "$key" "$value" "high" "aws-access-key"
                fi
                ;;
            *aws_secret_access_key*)
                add_finding "$cname" "env" "$key" "[redacted]" "high" "aws-secret-key"
                ;;
            *github_token*|*gh_token*|*gitlab_token*)
                add_finding "$cname" "env" "$key" "[redacted]" "high" "vcs-token-in-env"
                ;;
            *slack_token*|*slack_webhook*|*discord_token*|*discord_webhook*)
                add_finding "$cname" "env" "$key" "[redacted]" "medium" "chat-token-in-env"
                ;;
            *secret_key*|*secretkey*|*secret_token*)
                add_finding "$cname" "env" "$key" "[redacted]" "high" "generic-secret"
                ;;
            *password*|*passwd*|*pass_word*|*pwd*)
                if [ -n "$value" ] && [ "$value" != "" ]; then
                    add_finding "$cname" "env" "$key" "[redacted]" "medium" "password-in-env"
                fi
                ;;
            *api_key*|*apikey*|*api_token*|*apitoken*)
                add_finding "$cname" "env" "$key" "[redacted]" "medium" "api-key-in-env"
                ;;
            *database_url*|*db_url*|*mongodb_uri*|*postgres_url*|*mysql_url*|*redis_url*|*amqp_url*|*rabbitmq_url*)
                if echo "$value_lower" | grep -qE '://[^:]+:[^@]+@'; then
                    add_finding "$cname" "env" "$key" "[creds-in-url]" "high" "credentials-in-connection-string"
                fi
                ;;
            *ssh_key*|*sshkey*)
                add_finding "$cname" "env" "$key" "[redacted]" "high" "ssh-key-in-env"
                ;;
            *private_key*|*privatekey*|*priv_key*)
                add_finding "$cname" "env" "$key" "[redacted]" "high" "private-key-reference"
                ;;
            *token*|*jwt*|*bearer*)
                if echo "$value" | grep -qE '^[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*$' && [ ${#value} -gt 30 ]; then
                    add_finding "$cname" "env" "$key" "[jwt-like]" "medium" "jwt-token-in-env"
                fi
                ;;
        esac

        if echo "$value" | grep -qE '^(sk-|pk_)[a-zA-Z0-9]{20,}'; then
            add_finding "$cname" "env" "$key" "[stripe/openai-key-like]" "high" "api-key-pattern"
        fi
    done
}

scan_labels() {
    local cid="$1"
    local cname="$2"
    local labels_content
    labels_content=$(docker inspect --format '{{range $k, $v := .Config.Labels}}{{$k}}={{$v}}{{println}}{{end}}' "$cid" 2>/dev/null)

    echo "$labels_content" | while IFS='=' read -r key value; do
        [ -z "$key" ] && continue
        key_lower=$(echo "$key" | tr '[:upper:]' '[:lower:]')

        case "$key_lower" in
            *password*|*secret*|*token*|*api_key*|*apikey*|*private_key*)
                add_finding "$cname" "label" "$key" "[redacted]" "low" "sensitive-label"
                ;;
        esac

        if echo "$value" | grep -qE '-----BEGIN [A-Z ]*PRIVATE KEY-----'; then
            add_finding "$cname" "label" "$key" "[private-key]" "high" "private-key-in-label"
        fi

        if echo "$value" | grep -qE '^[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*$' && [ ${#value} -gt 30 ]; then
            add_finding "$cname" "label" "$key" "[jwt-like]" "low" "jwt-pattern-in-label"
        fi
    done
}

container_list=""
if [ -n "$FILTER_CONTAINER" ]; then
    container_list=$(docker ps --filter "name=$FILTER_CONTAINER" --format '{{.ID}}|{{.Names}}' 2>/dev/null)
else
    container_list=$(docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null)
fi

total_containers=$(echo "$container_list" | grep -c '|' || echo 0)
total_containers=$(echo "$total_containers" | tr -d '[:space:]')
[[ "$total_containers" =~ ^[0-9]+$ ]] || total_containers=0

if ! $JSON_OUTPUT; then
    echo ""
    echo -e "  ${BOLD}Docker Secret Scanner${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""

    if [ "$total_containers" -eq 0 ]; then
        echo -e "  ${DIM}Nenhum container rodando para escanear.${RESET}"
        exit 0
    fi

    echo -e "  Escaneando ${BOLD}$total_containers${RESET} container(s)..."
    echo ""
fi

while IFS='|' read -r cid cname; do
    [ -z "$cid" ] && continue

    if ! $JSON_OUTPUT; then
        echo -e "  ${BOLD}── ${cname} ──${RESET}"
    fi

    if ! $LABELS_ONLY; then
        scan_env "$cid" "$cname"
    fi

    if ! $ENV_ONLY; then
        scan_labels "$cid" "$cname"
    fi

    if ! $JSON_OUTPUT; then
        echo ""
    fi
done <<< "$container_list"

# =============================================
# Resumo
# =============================================

if $JSON_OUTPUT; then
    json_results="${json_results%,}"
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"high\":$total_high,\"medium\":$total_medium,\"low\":$total_low,\"results\":[$json_results]}"
    exit 0
fi

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo${RESET}"
echo ""
echo -e "  ${RED}HIGH/CRITICAL${RESET}:  ${RED}${BOLD}$total_high${RESET}"
echo -e "  ${YELLOW}MEDIUM${RESET}:      ${YELLOW}${BOLD}$total_medium${RESET}"
echo -e "  ${CYAN}LOW${RESET}:         ${CYAN}${BOLD}$total_low${RESET}"
echo ""

if [ "$total_high" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}ALERTA: $total_high segredo(s) com severidade alta/critica encontrado(s)!${RESET}"
    echo -e "  ${DIM}Mova segredos para Docker secrets ou vault externo.${RESET}"
elif [ "$total_medium" -gt 0 ]; then
    echo -e "  ${YELLOW}$total_medium aviso(s) — revise as descobertas de severidade media${RESET}"
elif [ "$total_low" -gt 0 ]; then
    echo -e "  ${DIM}Apenas descobertas de baixa severidade.${RESET}"
else
    echo -e "  ${GREEN}✓ Nenhum segredo obvio detectado nos containers rodando${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""