#!/bin/bash
# battery-monitor.sh — Status da bateria com alerta de nivel baixo/critico
# Uso: ./battery-monitor.sh [opcoes]
# Opcoes:
#   --status            Mostra status atual (padrao)
#   --watch             Monitora continuamente com alertas
#   --low N             Percentual de alerta baixo (padrao: 20)
#   --critical N        Percentual de alerta critico (padrao: 5)
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

ACTION="status"
LOW_THRESHOLD=20
CRITICAL_THRESHOLD=5

while [ $# -gt 0 ]; do
    case "$1" in
        --status|-s) ACTION="status"; shift ;;
        --watch|-w) ACTION="watch"; shift ;;
        --low) LOW_THRESHOLD="$2"; shift 2 ;;
        --critical) CRITICAL_THRESHOLD="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  battery-monitor.sh — Monitor de bateria com alertas"
            echo ""
            echo "  Uso: ./battery-monitor.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --status       Mostra status atual (padrao)"
            echo "    --watch        Monitora continuamente com alertas"
            echo "    --low N        Alerta baixo (padrao: 20%)"
            echo "    --critical N   Alerta critico (padrao: 5%)"
            echo "    --help         Mostra esta ajuda"
            echo "    --version      Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./battery-monitor.sh"
            echo "    ./battery-monitor.sh --watch"
            echo "    ./battery-monitor.sh --low 15 --critical 3 --watch"
            echo ""
            exit 0
            ;;
        --version|-v) echo "battery-monitor.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

detect_battery() {
    if [ -d "/sys/class/power_supply/BAT0" ]; then
        echo "BAT0"
    elif [ -d "/sys/class/power_supply/BAT1" ]; then
        echo "BAT1"
    elif [ -d "/sys/class/power_supply/battery" ]; then
        echo "battery"
    else
        echo ""
    fi
}

get_battery_info() {
    local bat="$1"

    if [ -n "$bat" ] && [ -d "/sys/class/power_supply/$bat" ]; then
        local capacity=$(cat "/sys/class/power_supply/$bat/capacity" 2>/dev/null || echo "0")
        local status=$(cat "/sys/class/power_supply/$bat/status" 2>/dev/null || echo "Unknown")
        local vendor=$(cat "/sys/class/power_supply/$bat/manufacturer" 2>/dev/null || echo "N/A")
        local model=$(cat "/sys/class/power_supply/$bat/model_name" 2>/dev/null || echo "N/A")
        local energy_now=$(cat "/sys/class/power_supply/$bat/energy_now" 2>/dev/null || echo "0")
        local energy_full=$(cat "/sys/class/power_supply/$bat/energy_full" 2>/dev/null || echo "0")
        local power_now=$(cat "/sys/class/power_supply/$bat/power_now" 2>/dev/null || echo "0")
        local voltage_now=$(cat "/sys/class/power_supply/$bat/voltage_now" 2>/dev/null || echo "0")
        local cycle_count=$(cat "/sys/class/power_supply/$bat/cycle_count" 2>/dev/null || echo "N/A")

        echo "${capacity}|${status}|${vendor}|${model}|${energy_now}|${energy_full}|${power_now}|${voltage_now}|${cycle_count}"
    else
        echo ""
    fi
}

format_bar() {
    local pct="$1"
    local bar_filled=$((pct / 5))
    local bar_empty=$((20 - bar_filled))

    local color=""
    if [ "$pct" -ge 60 ]; then color="$GREEN"
    elif [ "$pct" -ge 30 ]; then color="$YELLOW"
    else color="$RED"
    fi

    local bar=""
    for ((i=0; i<20; i++)); do
        if [ $i -lt $bar_filled ]; then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
    done

    echo -e "${color}${bar}${RESET}"
}

show_status() {
    local bat=$(detect_battery)

    if [ -z "$bat" ]; then
        if command -v upower &>/dev/null; then
            bat_device=$(upower -e 2>/dev/null | grep -i bat | head -1)
            if [ -n "$bat_device" ]; then
                upower -i "$bat_device" 2>/dev/null
                return
            fi
        fi
        echo ""
        echo -e "  ${RED}Nenhuma bateria detectada.${RESET}"
        echo -e "  ${DIM}Este equipamento pode nao ter bateria.${RESET}"
        echo ""
        exit 0
    fi

    local info=$(get_battery_info "$bat")
    if [ -z "$info" ]; then
        echo -e "  ${RED}Erro ao ler informacoes da bateria.${RESET}"
        exit 1
    fi

    IFS='|' read -r capacity status vendor model energy_now energy_full power_now voltage_now cycle_count <<< "$info"

    local bar=$(format_bar "$capacity")

    echo ""
    echo -e "  ${BOLD}── Battery Monitor ──${RESET}"
    echo ""
    echo -e "  ${bar}  ${BOLD}${capacity}%${RESET}"
    echo ""

    local status_color=""
    case "$status" in
        Charging) status_color="${GREEN}" ;;
        Discharging) status_color="${YELLOW}" ;;
        Full) status_color="${GREEN}" ;;
        *) status_color="${DIM}" ;;
    esac
    echo -e "  Status:      ${status_color}${BOLD}${status}${RESET}"
    echo -e "  Fabricante:  ${DIM}${vendor}${RESET}"
    echo -e "  Modelo:      ${DIM}${model}${RESET}"

    if [ "$cycle_count" != "N/A" ]; then
        echo -e "  Ciclos:      ${CYAN}${cycle_count}${RESET}"
    fi

    if [ "$energy_full" -gt 0 ] 2>/dev/null; then
        local wh_now=$(echo "scale=1; $energy_now / 1000000" | bc 2>/dev/null || echo "0")
        local wh_full=$(echo "scale=1; $energy_full / 1000000" | bc 2>/dev/null || echo "0")
        echo -e "  Energia:     ${CYAN}${wh_now} / ${wh_full} Wh${RESET}"
    fi

    if [ "$power_now" -gt 0 ] 2>/dev/null && [ "$status" = "Discharging" ]; then
        local discharge_rate=$(echo "scale=1; $power_now / 1000000" | bc 2>/dev/null || echo "0")
        echo -e "  Consumo:     ${CYAN}${discharge_rate} W${RESET}"

        if [ "$energy_now" -gt 0 ] 2>/dev/null && [ "$power_now" -gt 0 ] 2>/dev/null; then
            local remaining_h=$(echo "scale=1; $energy_now / $power_now" | bc 2>/dev/null || echo "0")
            local remaining_min=$(echo "scale=0; ($remaining_h - ${remaining_h%.*}) * 60" | bc 2>/dev/null || echo "0")
            echo -e "  Restante:    ${YELLOW}${remaining_h%.*}h ${remaining_min}min${RESET}"
        fi
    fi

    echo ""

    if [ "$capacity" -le "$CRITICAL_THRESHOLD" ] && [ "$status" = "Discharging" ]; then
        echo -e "  ${RED}${BOLD}⚠ BATERIA CRITICA! Conecte o carregador!${RESET}"
        command -v notify-send &>/dev/null && notify-send -u critical "⚠ Bateria Critica" "${capacity}% restante" 2>/dev/null
    elif [ "$capacity" -le "$LOW_THRESHOLD" ] && [ "$status" = "Discharging" ]; then
        echo -e "  ${YELLOW}⚠ Bateria baixa. Considere carregar.${RESET}"
        command -v notify-send &>/dev/null && notify-send -u normal "Bateria Baixa" "${capacity}% restante" 2>/dev/null
    fi
}

case "$ACTION" in
    status)
        show_status
        ;;

    watch)
        trap 'echo -e "\n\n  ${DIM}Monitoramento encerrado.${RESET}\n"; exit 0' INT
        while true; do
            show_status
            sleep 60
        done
        ;;
esac