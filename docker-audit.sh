#!/bin/bash
# docker-audit.sh — Auditoria de seguranca de containers Docker (Linux)
# Uso: ./docker-audit.sh [opcoes]
# Opcoes:
#   --verbose       Mostra detalhes de cada verificacao
#   --json          Saida em JSON
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

VERBOSE=false
JSON_OUTPUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --verbose|-v) VERBOSE=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-audit.sh — Auditoria de seguranca de containers Docker"
            echo ""
            echo "  Uso: ./docker-audit.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --verbose       Mostra detalhes de cada verificacao"
            echo "    --json          Saida em formato JSON"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Verificacoes:"
            echo "    ✓ Containers rodando como root"
            echo "    ✓ Portas expostas ao host"
            echo "    ✓ Privilegios elevados (privileged mode)"
            echo "    ✓ Capacidades perigosas (CAP_SYS_ADMIN, etc)"
            echo "    ✓ Mounts sensíveis (/etc, /var/run/docker.sock)"
            echo "    ✓ Imagens sem tag (dangling)"
            echo "    ✓ Containers sem resource limits"
            echo "    ✓ Docker socket exposto em containers"
            echo "    ✓ Network mode host"
            echo "    ✓ Variaveis de ambiente sensiveis"
            echo ""
            exit 0
            ;;
        --version) echo "docker-audit.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

TOTAL_ISSUES=0
CRITICAL=0
WARNING=0
INFO=0

issue() {
    local severity="$1"
    local message="$2"
    local detail="${3:-}"

    TOTAL_ISSUES=$((TOTAL_ISSUES + 1))

    case "$severity" in
        critical) CRITICAL=$((CRITICAL + 1)); icon="${RED}CRIT${RESET}" ;;
        warning) WARNING=$((WARNING + 1)); icon="${YELLOW}WARN${RESET}" ;;
        info) INFO=$((INFO + 1)); icon="${CYAN}INFO${RESET}" ;;
    esac

    echo -e "  [$icon] $message"
    if $VERBOSE && [ -n "$detail" ]; then
        echo -e "         ${DIM}$detail${RESET}"
    fi
}

echo ""
echo -e "  ${BOLD}Docker Security Audit${RESET}"
echo ""

# =============================================
# 1. Containers rodando como root
# =============================================

echo -e "  ${BOLD}── Containers como Root ──${RESET}"
echo ""

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    user=$(docker inspect --format '{{.Config.User}}' "$cid" 2>/dev/null)
    if [ -z "$user" ] || [ "$user" = "root" ] || [ "$user" = "0" ] || [ "$user" = "" ]; then
        issue "warning" "Container '$cname' rodando como root" "User: ${user:-root}"
    fi
done

echo ""

# =============================================
# 2. Portas expostas
# =============================================

echo -e "  ${BOLD}── Portas Expostas ──${RESET}"
echo ""

docker ps --format '{{.ID}}|{{.Names}}|{{.Ports}}' 2>/dev/null | while IFS='|' read -r cid cname ports; do
    if [ -n "$ports" ]; then
        # Portas com 0.0.0.0 (expostas a todos)
        if echo "$ports" | grep -q '0\.0\.0\.0'; then
            exposed=$(echo "$ports" | grep -oE '0\.0\.0\.0:[0-9]+' | tr '\n' ' ')
            issue "warning" "Container '$cname' exposto em $exposed" "Bind: 0.0.0.0 (todas as interfaces)"
        elif $VERBOSE; then
            echo -e "  ${GREEN}✓${RESET} $cname: $ports"
        fi
    fi
done

echo ""

# =============================================
# 3. Privileged mode
# =============================================

echo -e "  ${BOLD}── Modo Privilegiado ──${RESET}"
echo ""

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$cid" 2>/dev/null)
    if [ "$privileged" = "true" ]; then
        issue "critical" "Container '$cname' rodando em modo privilegiado" "HostConfig.Privileged = true"
    fi
done

echo ""

# =============================================
# 4. Capacidades perigosas
# =============================================

echo -e "  ${BOLD}── Capacidades Perigosas ──${RESET}"
echo ""

DANGEROUS_CAPS="SYS_ADMIN SYS_PTRACE NET_ADMIN SYS_PTRACE DAC_OVERRIDE SETUID SETGID"

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    caps=$(docker inspect --format '{{range .HostConfig.CapAdd}}{{.}} {{end}}' "$cid" 2>/dev/null)
    if [ -n "$caps" ]; then
        for cap in $DANGEROUS_CAPS; do
            if echo "$caps" | grep -qw "$cap"; then
                issue "warning" "Container '$cname' com CAP_$cap" "CapAdd: $caps"
                break
            fi
        done
    fi
done

echo ""

# =============================================
# 5. Mounts sensiveis
# =============================================

echo -e "  ${BOLD}── Mounts Sensíveis ──${RESET}"
echo ""

SENSITIVE_PATHS="/etc /var/run/docker.sock /proc /sys /dev /root /home"

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    mounts=$(docker inspect --format '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$cid" 2>/dev/null)
    for mount in $mounts; do
        src=$(echo "$mount" | cut -d: -f1)
        dst=$(echo "$mount" | cut -d: -f2)
        for spath in $SENSITIVE_PATHS; do
            if [ "$src" = "$spath" ] || echo "$src" | grep -q "^${spath}/"; then
                if [ "$src" = "/var/run/docker.sock" ]; then
                    issue "critical" "Container '$cname' com docker.sock montado" "$src → $dst"
                else
                    issue "warning" "Container '$cname' com path sensivel montado" "$src → $dst"
                fi
                break
            fi
        done
    done
done

echo ""

# =============================================
# 6. Network mode host
# =============================================

echo -e "  ${BOLD}── Network Mode ──${RESET}"
echo ""

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    net_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$cid" 2>/dev/null)
    if [ "$net_mode" = "host" ]; then
        issue "warning" "Container '$cname' usando network mode host" "Acesso direto a rede do host"
    fi
done

echo ""

# =============================================
# 7. Resource limits
# =============================================

echo -e "  ${BOLD}── Resource Limits ──${RESET}"
echo ""

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    mem_limit=$(docker inspect --format '{{.HostConfig.Memory}}' "$cid" 2>/dev/null)
    cpu_quota=$(docker inspect --format '{{.HostConfig.CpuQuota}}' "$cid" 2>/dev/null)

    has_limits=true

    mem_limit=$(echo "$mem_limit" | tr -d '[:space:]')
    cpu_quota=$(echo "$cpu_quota" | tr -d '[:space:]')

    if [ -z "$mem_limit" ] || [ "$mem_limit" = "0" ]; then
        has_limits=false
    fi

    if [ -z "$cpu_quota" ] || [ "$cpu_quota" = "0" ]; then
        : 
    fi

    if ! $has_limits; then
        issue "info" "Container '$cname' sem limites de memoria" "Memory: ${mem_limit:-0}, CPU quota: ${cpu_quota:-0}"
    fi
done

echo ""

# =============================================
# 8. Variaveis de ambiente sensiveis
# =============================================

echo -e "  ${BOLD}── Variaveis Sensíveis ──${RESET}"
echo ""

SENSITIVE_ENV="PASSWORD SECRET TOKEN KEY API_KEY PRIVATE CREDENTIAL AUTH"

docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null | while IFS='|' read -r cid cname; do
    env_vars=$(docker inspect --format '{{range .Config.Env}}{{.}}|{{end}}' "$cid" 2>/dev/null)
    found_sensitive=""
    for env_var in $(echo "$env_vars" | tr '|' '\n'); do
        env_name=$(echo "$env_var" | cut -d= -f1 | tr '[:lower:]' '[:upper:]')
        for pattern in $SENSITIVE_ENV; do
            if echo "$env_name" | grep -qF "$pattern"; then
                found_sensitive="${found_sensitive}${env_name} "
                break
            fi
        done
    done
    if [ -n "$found_sensitive" ]; then
        issue "warning" "Container '$cname' com envs sensiveis: $found_sensitive"
    fi
done

echo ""

# =============================================
# 9. Imagens dangling
# =============================================

echo -e "  ${BOLD}── Imagens Dangling ──${RESET}"
echo ""

dangling_count=$(docker images -f dangling=true -q 2>/dev/null | sort -u | wc -l | tr -d ' ')
[[ "$dangling_count" =~ ^[0-9]+$ ]] || dangling_count=0

if [ "$dangling_count" -gt 0 ]; then
    issue "info" "$dangling_count imagem(ns) dangling (sem tag)" "Use docker-clean.sh para remover"
else
    echo -e "  ${GREEN}✓${RESET} Nenhuma imagem dangling"
fi

echo ""

# =============================================
# Resumo
# =============================================

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo da Auditoria:${RESET}"
echo -e "  Critico:   ${RED}${BOLD}$CRITICAL${RESET}"
echo -e "  Aviso:     ${YELLOW}${BOLD}$WARNING${RESET}"
echo -e "  Info:      ${CYAN}${BOLD}$INFO${RESET}"
echo -e "  Total:     ${BOLD}$TOTAL_ISSUES${RESET}"
echo "  ─────────────────────────────────"

if [ "$CRITICAL" -gt 0 ]; then
    echo ""
    echo -e "  ${RED}${BOLD}ACAO RECOMENDADA:${RESET} Corrija os itens criticos imediatamente."
elif [ "$WARNING" -gt 0 ]; then
    echo ""
    echo -e "  ${YELLOW}Verifique os avisos acima quando possivel.${RESET}"
else
    echo ""
    echo -e "  ${GREEN}Nenhum problema de seguranca detectado.${RESET}"
fi

echo ""