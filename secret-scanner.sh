#!/bin/bash
# secret-scanner.sh — Busca segredos expostos em codigo e configuracao (Linux)
# Uso: ./secret-scanner.sh [opcoes]
# Opcoes:
#   --json              Saida em formato JSON
#   --path PATH         Caminho para escanear (padrao: diretorio atual)
#   --type TYPE         Tipo de segredo: all, api-key, password, token, private-key (padrao: all)
#   --severity LEVEL    Severidade minima: low, medium, high, critical (padrao: low)
#   --exclude DIR       Diretorio para excluir (pode ser repetido)
#   --fix               Exibe sugestoes detalhadas de correcao
#   --help|-h           Mostra esta ajuda
#   --version|-V        Mostra versao

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
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "grep" "$INSTALLER" "grep"
fi

JSON_MODE=false
SCAN_PATH="."
SECRET_TYPE="all"
MIN_SEVERITY="low"
SHOW_FIX=false
EXCLUDES=(".git" "node_modules" ".venv" "venv" ".kata" "target" "dist" "build")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_MODE=true; shift ;;
        --path)
            [[ -z "${2-}" ]] && error "Flag --path requer um valor"
            SCAN_PATH="$2"; shift 2 ;;
        --type)
            [[ -z "${2-}" ]] && error "Flag --type requer um valor"
            SECRET_TYPE="$2"; shift 2 ;;
        --severity)
            [[ -z "${2-}" ]] && error "Flag --severity requer um valor"
            MIN_SEVERITY="$2"; shift 2 ;;
        --exclude)
            [[ -z "${2-}" ]] && error "Flag --exclude requer um valor"
            EXCLUDES+=("$2"); shift 2 ;;
        --fix) SHOW_FIX=true; shift ;;
        --help|-h)
            echo ""
            echo "  secret-scanner.sh — Busca segredos expostos em codigo e configuracao"
            echo ""
            echo "  Uso: ./secret-scanner.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --json              Saida em formato JSON"
            echo "    --path PATH         Caminho para escanear (padrao: .)"
            echo "    --type TYPE         Tipo de segredo: all, api-key, password, token, private-key (padrao: all)"
            echo "    --severity LEVEL    Severidade minima: low, medium, high, critical (padrao: low)"
            echo "    --exclude DIR       Diretorio para excluir (pode ser repetido)"
            echo "    --fix               Exibe sugestoes detalhadas de correcao"
            echo "    --help|-h           Mostra esta ajuda"
            echo "    --version|-V        Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "secret-scanner.sh $SCRIPT_VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
    esac
done

[[ ! -d "$SCAN_PATH" ]] && error "Diretorio nao encontrado: $SCAN_PATH"

# Severidade ranking
sev_num() {
    case "$1" in
        critical) echo 4 ;;
        high) echo 3 ;;
        medium) echo 2 ;;
        low|*) echo 1 ;;
    esac
}

MIN_SEV_NUM=$(sev_num "$MIN_SEVERITY")

# Montar argumentos do find para exclusao
FIND_CMD=(find "$SCAN_PATH" -type f)
for exc in "${EXCLUDES[@]}"; do
    FIND_CMD+=(-not -path "*/$exc/*" -not -path "*/$exc")
done

# Arquivos temporários para findings
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

FINDINGS_FILE="$TMP_DIR/findings.tsv"
touch "$FINDINGS_FILE"

FILES_SCANNED=0

# Coleta de arquivos regulares
while IFS= read -r file; do
    # Pular arquivos binários
    if ! grep -qI . "$file" 2>/dev/null; then
        continue
    fi
    FILES_SCANNED=$((FILES_SCANNED + 1))

    # Regra 1: Private Key
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "private-key" ]]; then
        if [ "$MIN_SEV_NUM" -le 4 ]; then
            (grep -n -H -E '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "private-key" "critical" "PRIVATE_KEY_BLOCK" "Revogar chave e mover para secret manager ou SSH agent" >> "$FINDINGS_FILE"
            done
        fi
    fi

    # Regra 2: AWS Access Key
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "api-key" ]]; then
        if [ "$MIN_SEV_NUM" -le 3 ]; then
            (grep -n -H -E 'AKIA[0-9A-Z]{16}' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "api-key" "high" "AWS_ACCESS_KEY" "Rotacionar credencial AWS e configurar AWS Secrets Manager ou IAM Role" >> "$FINDINGS_FILE"
            done
        fi
    fi

    # Regra 3: GitHub Token
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "token" ]]; then
        if [ "$MIN_SEV_NUM" -le 3 ]; then
            (grep -n -H -E '(ghp_[0-9a-zA-Z]{36}|github_pat_[0-9a-zA-Z_]{82})' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "token" "high" "GITHUB_TOKEN" "Revogar o Personal Access Token no GitHub e usar secrets de CI/CD" >> "$FINDINGS_FILE"
            done
        fi
    fi

    # Regra 4: OpenAI / Stripe API Key
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "api-key" ]]; then
        if [ "$MIN_SEV_NUM" -le 3 ]; then
            (grep -n -H -E 'sk_(live|test)_[0-9a-zA-Z]{24,}' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "api-key" "high" "OPENAI_OR_STRIPE_KEY" "Rotacionar API key imediatamente e referenciar via variavel de ambiente" >> "$FINDINGS_FILE"
            done
        fi
    fi

    # Regra 5: Slack Token
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "token" ]]; then
        if [ "$MIN_SEV_NUM" -le 3 ]; then
            (grep -n -H -E 'xox[baprs]-[0-9a-zA-Z]{10,}' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "token" "high" "SLACK_TOKEN" "Revogar token do Slack e usar variavel de ambiente ou OAuth" >> "$FINDINGS_FILE"
            done
        fi
    fi

    # Regra 6: Senha exposta em atribuição explícita
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "password" ]]; then
        if [ "$MIN_SEV_NUM" -le 2 ]; then
            (grep -n -H -i -E '(password|passwd|pwd|db_pass)\s*[:=]\s*["'\''"][^"'\'']{6,}["'\''"]' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                # Ignorar placeholders óbvios
                if ! echo "$match" | grep -qi -E '(example|placeholder|changeme|test|secret123|default|your_password|xxx|\*\*\*)'; then
                    printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "password" "medium" "PLAINTEXT_PASSWORD" "Mover senha para .env ou cofre de senhas" >> "$FINDINGS_FILE"
                fi
            done
        fi
    fi

    # Regra 7: JWT token
    if [[ "$SECRET_TYPE" == "all" || "$SECRET_TYPE" == "token" ]]; then
        if [ "$MIN_SEV_NUM" -le 1 ]; then
            (grep -n -H -E 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9._-]{10,}' "$file" 2>/dev/null || true) | while IFS=: read -r f l match; do
                [ -z "$f" ] && continue
                printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$f" "$l" "token" "low" "JWT_TOKEN" "Verificar se e token temporario ou de teste; evitar hardcode" >> "$FINDINGS_FILE"
            done
        fi
    fi

done < <("${FIND_CMD[@]}" 2>/dev/null)

TOTAL_FINDINGS=$(wc -l < "$FINDINGS_FILE" | tr -d ' ')

COUNT_CRITICAL=0
COUNT_HIGH=0
COUNT_MEDIUM=0
COUNT_LOW=0

COUNT_API_KEY=0
COUNT_PASS=0
COUNT_TOKEN=0
COUNT_PRIV_KEY=0

if [ "$TOTAL_FINDINGS" -gt 0 ]; then
    while IFS=$'\t' read -r f l type sev pat sug; do
        case "$sev" in
            critical) COUNT_CRITICAL=$((COUNT_CRITICAL + 1)) ;;
            high) COUNT_HIGH=$((COUNT_HIGH + 1)) ;;
            medium) COUNT_MEDIUM=$((COUNT_MEDIUM + 1)) ;;
            low) COUNT_LOW=$((COUNT_LOW + 1)) ;;
        esac
        case "$type" in
            api-key) COUNT_API_KEY=$((COUNT_API_KEY + 1)) ;;
            password) COUNT_PASS=$((COUNT_PASS + 1)) ;;
            token) COUNT_TOKEN=$((COUNT_TOKEN + 1)) ;;
            private-key) COUNT_PRIV_KEY=$((COUNT_PRIV_KEY + 1)) ;;
        esac
    done < "$FINDINGS_FILE"
fi

if [ "$JSON_MODE" = true ]; then
    python3 - "$SCAN_PATH" "$FILES_SCANNED" "$TOTAL_FINDINGS" "$COUNT_CRITICAL" "$COUNT_HIGH" "$COUNT_MEDIUM" "$COUNT_LOW" \
              "$COUNT_API_KEY" "$COUNT_PASS" "$COUNT_TOKEN" "$COUNT_PRIV_KEY" "$FINDINGS_FILE" <<'PY_JSON'
import sys, json

scan_path, files_scanned, total_findings = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
c_crit, c_high, c_med, c_low = int(sys.argv[4]), int(sys.argv[5]), int(sys.argv[6]), int(sys.argv[7])
t_api, t_pass, t_token, t_priv = int(sys.argv[8]), int(sys.argv[9]), int(sys.argv[10]), int(sys.argv[11])
findings_file = sys.argv[12]

findings = []
if total_findings > 0:
    with open(findings_file, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            parts = line.strip().split('\t')
            if len(parts) >= 6:
                findings.append({
                    "file": parts[0],
                    "line": int(parts[1]),
                    "type": parts[2],
                    "severity": parts[3],
                    "pattern": parts[4],
                    "suggestion": parts[5]
                })

recommendations = [
    "Mover segredos para variáveis de ambiente ou .env",
    "Garantir que .env esteja registrado no .gitignore",
    "Usar ferramentas de secret scanning pré-commit (git-secrets, talisman, gitleaks)",
    "Rotacionar quaisquer chaves que possam ter sido commitadas"
]

data = {
    "status": "ok",
    "scan_path": scan_path,
    "files_scanned": files_scanned,
    "secrets_found": total_findings,
    "findings": findings,
    "by_severity": {
        "critical": c_crit,
        "high": c_high,
        "medium": c_med,
        "low": c_low
    },
    "by_type": {
        "api-key": t_api,
        "password": t_pass,
        "token": t_token,
        "private-key": t_priv
    },
    "recommendations": recommendations
}

print(json.dumps(data, indent=2, ensure_ascii=False))
PY_JSON
    exit 0
fi

# Formato humano
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}🛡️  Secret Scanner — Varredura de Segredos${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${DIM}Caminho:${RESET}        $SCAN_PATH"
echo -e "  ${DIM}Arquivos:${RESET}       $FILES_SCANNED escaneados"
echo -e "  ${DIM}Filtro:${RESET}         tipo=$SECRET_TYPE, severidade>=$MIN_SEVERITY"
echo ""

if [ "$TOTAL_FINDINGS" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✓ Nenhum segredo exposto encontrado!${RESET}"
    echo ""
    exit 0
fi

echo -e "  ${RED}${BOLD}⚠ Encontrado(s) $TOTAL_FINDINGS segredo(s) potencial(is):${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────────────────${RESET}"
printf "  ${BOLD}%-10s %-12s %-35s %s${RESET}\n" "SEV" "TIPO" "ARQUIVO:LINHA" "PADRAO"
echo -e "  ${DIM}────────────────────────────────────────────────────────────────────────────${RESET}"

while IFS=$'\t' read -r f l type sev pat sug; do
    sev_color="$DIM"
    case "$sev" in
        critical) sev_color="$RED" ;;
        high) sev_color="$RED" ;;
        medium) sev_color="$YELLOW" ;;
        low) sev_color="$BLUE" ;;
    esac

    loc="${f}:${l}"
    if [ ${#loc} -gt 35 ]; then
        loc="...${loc: -32}"
    fi

    printf "  ${sev_color}%-10s${RESET} %-12s %-35s ${DIM}%s${RESET}\n" "$sev" "$type" "$loc" "$pat"
    if [ "$SHOW_FIX" = true ]; then
        echo -e "             ${CYAN}→ Correção:${RESET} $sug"
    fi
done < "$FINDINGS_FILE"

echo -e "  ${DIM}────────────────────────────────────────────────────────────────────────────${RESET}"
echo ""
echo -e "  ${BOLD}Resumo por Severidade:${RESET}"
[ "$COUNT_CRITICAL" -gt 0 ] && echo -e "    ${RED}● Crítico:${RESET}  $COUNT_CRITICAL"
[ "$COUNT_HIGH" -gt 0 ]     && echo -e "    ${RED}● Alto:${RESET}     $COUNT_HIGH"
[ "$COUNT_MEDIUM" -gt 0 ]   && echo -e "    ${YELLOW}● Médio:${RESET}    $COUNT_MEDIUM"
[ "$COUNT_LOW" -gt 0 ]      && echo -e "    ${BLUE}● Baixo:${RESET}    $COUNT_LOW"
echo ""

if [ "$SHOW_FIX" = false ]; then
    echo -e "  ${DIM}Dica: execute com --fix para visualizar sugestões de remediação.${RESET}"
    echo ""
fi
