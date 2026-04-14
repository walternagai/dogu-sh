#!/bin/bash
# docker-bottleneck-detect.sh — Detecta gargalos comparando limites config vs uso real
# Uso: ./docker-bottleneck-detect.sh [opcoes]
# Opcoes:
#   --all           Analisa todos os containers rodando (padrao)
#   --container C   Analisa apenas container especifico
#   --threshold PCT Percentual de uso para alerta (padrao: 90)
#   --waste PCT     Percentual para desperdicio (padrao: 20)
#   --watch N       Atualiza a cada N segundos (modo continuo)
#   --json          Saida em formato JSON
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER docker.io"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

FILTER_CONTAINER=""
ALERT_THRESHOLD=90
WASTE_THRESHOLD=20
WATCH_INTERVAL=0
JSON_OUTPUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --all|-a) shift ;;
        --container|-c) FILTER_CONTAINER="$2"; shift 2 ;;
        --threshold|-t) ALERT_THRESHOLD="$2"; shift 2 ;;
        --waste|-w) WASTE_THRESHOLD="$2"; shift 2 ;;
        --watch|-W) WATCH_INTERVAL="${2:-10}"; shift 2 ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-bottleneck-detect.sh — Detecta gargalos: limites vs uso real"
            echo ""
            echo "  Uso: ./docker-bottleneck-detect.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all           Analisa todos os containers (padrao)"
            echo "    --container C   Analisa apenas container especifico"
            echo "    --threshold PCT Percentual de uso para alerta (padrao: 90)"
            echo "    --waste PCT     Percentual para desperdicio (padrao: 20)"
            echo "    --watch N       Atualiza a cada N segundos"
            echo "    --json          Saida em formato JSON"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Tipos de deteccao:"
            echo "    Gargalo: uso >= threshold% do limite (risco OOM/throttle)"
            echo "    Desperdicio: uso <= waste% do limite (recursos alocados sem necessidade)"
            echo "    Sem limite: container sem memoria/CPU limites definidos"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-bottleneck-detect.sh"
            echo "    ./docker-bottleneck-detect.sh --threshold 80 --waste 30"
            echo "    ./docker-bottleneck-detect.sh --container nginx"
            echo "    ./docker-bottleneck-detect.sh --json"
            echo ""
            exit 0
            ;;
        --version) echo "docker-bottleneck-detect.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

get_total_memory_mb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal/ {printf "%.0f", $2 / 1024}' /proc/meminfo
    else
        echo "0"
    fi
}

HOST_MEM_MB=$(get_total_memory_mb)

to_mb() {
    local value="$1"
    local unit="$2"
    case "$unit" in
        *GiB*|*GB*|*Gib*) echo "$value" | awk '{printf "%.0f", $1 * 1024}' ;;
        *MiB*|*MB*|*Mib*) echo "$value" | awk '{printf "%.0f", $1}' ;;
        *KiB*|*KB*|*Kib*) echo "$value" | awk '{printf "%.0f", $1 / 1024}' ;;
        *B*)  echo "$value" | awk '{printf "%.0f", $1 / 1048576}' ;;
        *)    echo "0" ;;
    esac
}

run_analysis() {
    local container_list=""
    if [ -n "$FILTER_CONTAINER" ]; then
        container_list=$(docker ps --filter "name=$FILTER_CONTAINER" --format '{{.ID}}|{{.Names}}' 2>/dev/null)
    else
        container_list=$(docker ps --format '{{.ID}}|{{.Names}}' 2>/dev/null)
    fi

    local total_running
    total_running=$(echo "$container_list" | grep -c '|' || echo 0)
    total_running=$(echo "$total_running" | tr -d '[:space:]')
    [[ "$total_running" =~ ^[0-9]+$ ]] || total_running=0

    local bottleneck_count=0
    local waste_count=0
    local nolimit_count=0
    local healthy_count=0
    local json_container_results=""

    if ! $JSON_OUTPUT; then
        if [ "$WATCH_INTERVAL" -gt 0 ]; then
            clear 2>/dev/null || true
        fi
        echo ""
        echo -e "  ${BOLD}Docker Bottleneck Detect${RESET}  ${DIM}v$VERSION${RESET}  ${DIM}$(date '+%H:%M:%S')${RESET}"
        echo ""
        echo -e "  Threshold: ${RED}${ALERT_THRESHOLD}%${RESET}  |  Desperdicio: ${YELLOW}${WASTE_THRESHOLD}%${RESET}"
        echo ""
    fi

    while IFS='|' read -r cid cname; do
        [ -z "$cid" ] && continue

        mem_limit_raw=$(docker inspect --format '{{.HostConfig.Memory}}' "$cid" 2>/dev/null | tr -d '[:space:]')
        mem_swap_limit=$(docker inspect --format '{{.HostConfig.MemorySwap}}' "$cid" 2>/dev/null | tr -d '[:space:]')
        cpu_quota=$(docker inspect --format '{{.HostConfig.CpuQuota}}' "$cid" 2>/dev/null | tr -d '[:space:]')
        cpu_period=$(docker inspect --format '{{.HostConfig.CpuPeriod}}' "$cid" 2>/dev/null | tr -d '[:space:]')
        cpu_shares=$(docker inspect --format '{{.HostConfig.CpuShares}}' "$cid" 2>/dev/null | tr -d '[:space:]')

        [[ "$mem_limit_raw" =~ ^[0-9]+$ ]] || mem_limit_raw=0
        [[ "$cpu_quota" =~ ^[0-9]+$ ]] || cpu_quota=0
        [[ "$cpu_period" =~ ^[0-9]+$ ]] || cpu_period=0
        [[ "$cpu_shares" =~ ^[0-9]+$ ]] || cpu_shares=0

        mem_limit_mb=0
        if [ "$mem_limit_raw" -gt 0 ]; then
            mem_limit_mb=$((mem_limit_raw / 1048576))
        fi

        cpu_limit_pct=0
        if [ "$cpu_quota" -gt 0 ] && [ "$cpu_period" -gt 0 ]; then
            cpu_limit_pct=$(echo "scale=1; $cpu_quota * 100 / $cpu_period" | bc 2>/dev/null)
        fi

        stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" "$cid" 2>/dev/null | head -1)
        [ -z "$stats" ] && continue

        IFS='|' read -r cpu_pct_raw mem_usage_raw mem_pct_raw <<< "$stats"

        cpu_pct=$(echo "$cpu_pct_raw" | tr -d '%' | tr -d '[:space:]')
        mem_pct=$(echo "$mem_pct_raw" | tr -d '%' | tr -d '[:space:]')

        if ! [[ "$cpu_pct" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then cpu_pct=0; fi
        if ! [[ "$mem_pct" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then mem_pct=0; fi

        cpu_int=${cpu_pct%.*}
        mem_int=${mem_pct%.*}
        [[ "$cpu_int" =~ ^[0-9]+$ ]] || cpu_int=0
        [[ "$mem_int" =~ ^[0-9]+$ ]] || mem_int=0

        mem_usage_val=$(echo "$mem_usage_raw" | awk -F'/' '{print $1}' | tr -d '[:space:]')
        mem_limit_val=$(echo "$mem_usage_raw" | awk -F'/' '{print $2}' | tr -d '[:space:]')

        issues=""
        severity="healthy"

        if [ "$mem_limit_raw" -eq 0 ]; then
            issues="${issues}${RED}SEM-LIMITE-MEM${RESET} "
            nolimit_count=$((nolimit_count + 1))
            severity="nolimit"
        elif [ "$mem_int" -ge "$ALERT_THRESHOLD" ]; then
            issues="${issues}${RED}GARGALO-MEM ${mem_pct}%${RESET} "
            bottleneck_count=$((bottleneck_count + 1))
            severity="bottleneck"
        elif [ "$mem_int" -le "$WASTE_THRESHOLD" ] && [ "$mem_int" -gt 0 ]; then
            issues="${issues}${YELLOW}DESPERDICIO-MEM ${mem_pct}%/${ALERT_THRESHOLD}%${RESET} "
            waste_count=$((waste_count + 1))
            if [ "$severity" = "healthy" ]; then severity="waste"; fi
        else
            healthy_count=$((healthy_count + 1))
        fi

        if [ "$cpu_quota" -eq 0 ]; then
            if [ "$cpu_int" -ge "$ALERT_THRESHOLD" ]; then
                issues="${issues}${RED}GARGALO-CPU ${cpu_pct}% (sem limite!)${RESET} "
                bottleneck_count=$((bottleneck_count + 1))
                severity="bottleneck"
            fi
            issues="${issues}${DIM}SEM-LIMITE-CPU${RESET} "
        else
            if [ "$cpu_int" -ge "$ALERT_THRESHOLD" ]; then
                issues="${issues}${RED}GARGALO-CPU ${cpu_pct}%${RESET} "
                bottleneck_count=$((bottleneck_count + 1))
                severity="bottleneck"
            elif [ "$cpu_int" -le "$WASTE_THRESHOLD" ] && [ "$cpu_int" -gt 0 ]; then
                issues="${issues}${YELLOW}DESPERDICIO-CPU ${cpu_pct}%${RESET} "
                waste_count=$((waste_count + 1))
                if [ "$severity" = "healthy" ]; then severity="waste"; fi
            else
                if [ "$severity" != "bottleneck" ] && [ "$severity" != "nolimit" ]; then
                    healthy_count=$((healthy_count + 1))
                fi
            fi
        fi

        if ! $JSON_OUTPUT; then
            mem_limit_display="${mem_limit_mb}MB"
            if [ "$mem_limit_raw" -eq 0 ]; then
                mem_limit_display="${DIM}ilimitado${RESET}"
            fi

            cpu_limit_display="${cpu_limit_pct}%"
            if [ "$cpu_quota" -eq 0 ]; then
                cpu_limit_display="${DIM}ilimitado${RESET}"
            fi

            echo -e "  ${BOLD}${cname}${RESET}"
            echo -e "    CPU: ${cpu_pct_raw}  (limite: ${cpu_limit_display})  |  MEM: ${mem_pct_raw}  (${mem_usage_raw}, limite: ${mem_limit_display})"
            if [ -n "$issues" ]; then
                echo -e "    ${issues}"
            else
                echo -e "    ${GREEN}OK${RESET} — dentro dos parametros"
            fi
            echo ""
        else
            json_container_results="${json_container_results}{\"name\":\"$cname\",\"cpu_pct\":\"$cpu_pct\",\"mem_pct\":\"$mem_pct\",\"cpu_limit\":\"$cpu_limit_pct\",\"mem_limit_mb\":\"$mem_limit_mb\",\"severity\":\"$severity\"},"
        fi
    done <<< "$container_list"

    if $JSON_OUTPUT; then
        json_container_results="${json_container_results%,}"
        echo "{\"timestamp\":\"$(date -Iseconds)\",\"bottlenecks\":$bottleneck_count,\"waste\":$waste_count,\"nolimit\":$nolimit_count,\"healthy\":$healthy_count,\"containers\":[$json_container_results]}"
        return
    fi

    echo "  ─────────────────────────────────"
    echo -e "  ${BOLD}Resumo${RESET}"
    echo ""
    echo -e "  ${RED}Gargalos${RESET}:       ${RED}${BOLD}$bottleneck_count${RESET}  (uso >= ${ALERT_THRESHOLD}%)"
    echo -e "  ${YELLOW}Desperdicio${RESET}:   ${YELLOW}${BOLD}$waste_count${RESET}  (uso <= ${WASTE_THRESHOLD}%)"
    echo -e "  ${DIM}Sem limite${RESET}:    ${DIM}${BOLD}$nolimit_count${RESET}  (sem mem/cpu limites)"
    echo -e "  ${GREEN}Saudavel${RESET}:     ${GREEN}${BOLD}$healthy_count${RESET}"
    echo ""

    if [ "$bottleneck_count" -gt 0 ]; then
        echo -e "  ${RED}Acao: aumente limites ou otimize containers com gargalo${RESET}"
    fi
    if [ "$waste_count" -gt 0 ]; then
        echo -e "  ${YELLOW}Dica: reduza limites de containers com desperdicio para liberar recursos${RESET}"
    fi
    if [ "$nolimit_count" -gt 0 ]; then
        echo -e "  ${DIM}Recomendacao: defina limites de memoria e CPU para todos os containers${RESET}"
    fi

    if [ "$bottleneck_count" -eq 0 ] && [ "$waste_count" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Nenhum gargalo ou desperdicio detectado${RESET}"
    fi

    echo "  ─────────────────────────────────"

    if [ "$WATCH_INTERVAL" -gt 0 ]; then
        echo -e "  ${DIM}Proxima verificacao em ${WATCH_INTERVAL}s — Ctrl+C para sair${RESET}"
    fi
    echo ""
}

if [ "$WATCH_INTERVAL" -gt 0 ]; then
    while true; do
        run_analysis
        sleep "$WATCH_INTERVAL"
    done
else
    run_analysis
fi