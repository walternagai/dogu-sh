#!/bin/bash
# wifi-scanner.sh — Escaneia redes Wi-Fi e sugere o melhor canal (Linux)
# Uso: ./wifi-scanner.sh
# Metodo primario: nmcli (NetworkManager)
# Fallback: iwlist (wireless-tools)
# Opcoes:
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail


readonly VERSION="1.1.0"
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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "nmcli" "$INSTALLER" "network-manager"; check_and_install "iwlist" "$INSTALLER" "wireless-tools"; fi




show_help() {
    echo ""
    echo "  wifi-scanner.sh — Escaneia redes Wi-Fi e sugere o melhor canal"
    echo ""
    echo "  Uso: ./wifi-scanner.sh"
    echo ""
    echo "  Opcoes:"
    echo "    --help      Mostra esta ajuda"
    echo "    --version   Mostra versao"
    echo ""
    echo "  Requer:"
    echo "    nmcli (NetworkManager) ou iwlist (wireless-tools)"
    echo ""
    echo "  Funcionalidades:"
    echo "    - Lista redes 2.4 GHz (canais 1-14) e 5 GHz"
    echo "    - Destaca canais congestionados"
    echo "    - Recomenda canal ideal (nao-sobreposto)"
    echo ""
}

case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --version|-V)
        echo "wifi-scanner.sh $VERSION"
        exit 0
        ;;
esac

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

PARSED_FILE="$TMPDIR_WORK/parsed.txt"
CHANNEL_COUNTS="$TMPDIR_WORK/channel_counts.txt"

get_current_ssid() {
    if command -v nmcli &>/dev/null; then
        nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2 || echo ""
    elif command -v iwgetid &>/dev/null; then
        iwgetid -r 2>/dev/null || echo ""
    else
        echo ""
    fi
}

get_current_channel() {
    if command -v iwconfig &>/dev/null; then
        iwconfig 2>/dev/null | awk '/Channel/{gsub(/[^0-9]/,"",$2); print $2}' | head -1
    elif command -v iw &>/dev/null; then
        local iface
        iface=$(detect_wireless_interface)
        if [ -n "$iface" ]; then
            iw dev "$iface" info 2>/dev/null | awk '/channel/{print $2}' | head -1
        fi
    elif command -v nmcli &>/dev/null; then
        local ssid
        ssid=$(get_current_ssid)
        if [ -n "$ssid" ]; then
            nmcli -t -f SSID,CHAN dev wifi list 2>/dev/null | grep "^${ssid}:" | head -1 | cut -d: -f2
        fi
    fi
}

detect_wireless_interface() {
    if command -v iw &>/dev/null; then
        local iface
        iface=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
        if [ -n "$iface" ]; then
            echo "$iface"
            return
        fi
    fi

    if [ -d /sys/class/net ]; then
        local dev
        for dev in /sys/class/net/*/wireless; do
            if [ -d "$dev" ]; then
                echo "$(basename "$(dirname "$dev")")"
                return
            fi
        done
    fi

    if [ -f /proc/net/wireless ]; then
        awk 'NR>2 {print $1; exit}' /proc/net/wireless 2>/dev/null | tr -d ':'
        return
    fi

    echo ""
}

scan_networks() {
    if command -v nmcli &>/dev/null; then
        nmcli dev wifi rescan 2>/dev/null || true
        sleep 1

        # Usa o ultimo campo como canal para suportar SSID com ':'
        nmcli -t -f SSID,CHAN dev wifi list 2>/dev/null | while IFS= read -r line; do
            [ -z "$line" ] && continue
            chan="${line##*:}"
            ssid="${line%:*}"
            [ -z "$chan" ] && continue
            [ "$ssid" = "--" ] && continue
            [ -z "$ssid" ] && continue
            echo "${chan}|${ssid}" >> "$PARSED_FILE"
        done

        # Fallback: se nmcli nao retornou redes, tenta iwlist
        if [ -s "$PARSED_FILE" ]; then
            return
        fi
    fi

    if command -v iwlist &>/dev/null; then
        local iface
        iface=$(detect_wireless_interface)
        if [ -z "$iface" ]; then
            iface="wlan0"
        fi

        local scan_output
        scan_output=$(iwlist "$iface" scan 2>/dev/null) || {
            echo -e "  ${RED}Erro ao escanear. Tente executar com sudo.${RESET}" >&2
            exit 1
        }

        echo "$scan_output" | awk '
        /Cell/ { ssid=""; chan="" }
        /Channel:/ { gsub(/[^0-9]/, "", $0); chan=$0 }
        /ESSID:/ { gsub(/.*ESSID:"/, ""); gsub(/".*/, ""); ssid=$0 }
        /Cell/ || /^$/ {
            if (chan != "" && ssid != "") {
                print chan "|" ssid
            }
        }
        END {
            if (chan != "" && ssid != "") {
                print chan "|" ssid
            }
        }
        ' >> "$PARSED_FILE"
    else
        echo -e "  ${RED}Erro: nenhuma ferramenta de scan Wi-Fi encontrada.${RESET}" >&2
        echo -e "  ${DIM}Instale NetworkManager (nmcli) ou wireless-tools (iwlist).${RESET}" >&2
        exit 1
    fi
}

signal_bar() {
    local count=$1
    local bar=""
    local i=0
    while [ $i -lt 8 ]; do
        if [ $i -lt "$count" ]; then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
        i=$((i + 1))
    done
    echo "$bar"
}

echo ""
echo -e "  Escaneando redes Wi-Fi..."
echo ""

current_ssid=$(get_current_ssid)
current_channel=$(get_current_channel)

> "$PARSED_FILE"
scan_networks

if [ ! -s "$PARSED_FILE" ]; then
    echo -e "  ${RED}Nenhuma rede encontrada.${RESET}"
    echo -e "  ${DIM}Verifique se o Wi-Fi esta ligado.${RESET}"
    exit 1
fi

# -- Contar redes por canal --

# Canais 2.4 GHz (1-14)
echo -e "  ${BOLD}Redes encontradas (2.4 GHz):${RESET}"
echo ""
printf "  %-6s %-6s %-10s %s\n" "Canal" "Redes" "Sinal" "Nomes"
printf "  %-6s %-6s %-10s %s\n" "─────" "─────" "────────" "──────────────────────────────"

best_24_ch=""
best_24_count=999

for ch in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
    count=$(awk -F'|' -v c="$ch" '$1 == c' "$PARSED_FILE" | wc -l | tr -d ' ')
    names=$(awk -F'|' -v c="$ch" '$1 == c {print $2}' "$PARSED_FILE" | paste -sd', ' -)

    case $ch in
        1|6|11)
            if [ "$count" -lt "$best_24_count" ]; then
                best_24_count=$count
                best_24_ch=$ch
            fi
            ;;
    esac

    if [ "$count" -eq 0 ]; then
        case $ch in
            1|6|11) ;;
            *) continue ;;
        esac
    fi

    bar=$(signal_bar "$count")

    if [ -n "$current_ssid" ] && echo "$names" | grep -qF "$current_ssid"; then
        names=$(echo "$names" | sed "s/$current_ssid/$(printf "${GREEN}${current_ssid}${RESET}")/")
    fi

    if [ "$count" -ge 5 ]; then
        printf "  ${RED}%4d    %d    %s${RESET}  %b\n" "$ch" "$count" "$bar" "$names"
    elif [ "$count" -ge 3 ]; then
        printf "  ${YELLOW}%4d    %d    %s${RESET}  %b\n" "$ch" "$count" "$bar" "$names"
    elif [ "$count" -eq 0 ]; then
        printf "  %4d    %d    %s  ${DIM}(vazio)${RESET}\n" "$ch" "$count" "$bar"
    else
        printf "  %4d    %d    %s  %b\n" "$ch" "$count" "$bar" "$names"
    fi
done

echo ""

# -- 5 GHz --

has_5ghz=false
best_5_ch=""
best_5_count=999

for ch in 36 40 44 48 52 56 60 64 149 153 157 161 165; do
    count=$(awk -F'|' -v c="$ch" '$1 == c' "$PARSED_FILE" | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        has_5ghz=true
    fi
done

if $has_5ghz; then
    echo -e "  ${BOLD}Redes encontradas (5 GHz):${RESET}"
    echo ""
    printf "  %-6s %-6s %-10s %s\n" "Canal" "Redes" "Sinal" "Nomes"
    printf "  %-6s %-6s %-10s %s\n" "─────" "─────" "────────" "──────────────────────────────"

    for ch in 36 40 44 48 52 56 60 64 149 153 157 161 165; do
        count=$(awk -F'|' -v c="$ch" '$1 == c' "$PARSED_FILE" | wc -l | tr -d ' ')
        names=$(awk -F'|' -v c="$ch" '$1 == c {print $2}' "$PARSED_FILE" | paste -sd', ' -)

        if [ "$count" -eq 0 ]; then
            if [ -z "$best_5_ch" ]; then
                best_5_ch=$ch
                best_5_count=0
            fi
            continue
        fi

        if [ "$count" -lt "$best_5_count" ]; then
            best_5_count=$count
            best_5_ch=$ch
        fi

        bar=$(signal_bar "$count")

        if [ -n "$current_ssid" ] && echo "$names" | grep -qF "$current_ssid"; then
            names=$(echo "$names" | sed "s/$current_ssid/$(printf "${GREEN}${current_ssid}${RESET}")/")
        fi

        printf "  %4d    %d    %s  %b\n" "$ch" "$count" "$bar" "$names"
    done

    echo ""
fi

# -- Diagnostico --

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Diagnostico:${RESET}"
echo ""

if [ -n "$current_ssid" ]; then
    echo -e "  Sua rede:        ${GREEN}$current_ssid${RESET}"
else
    echo -e "  Sua rede:        ${DIM}(nao detectada)${RESET}"
fi

if [ -n "$current_channel" ]; then
    current_count=$(awk -F'|' -v c="$current_channel" '$1 == c' "$PARSED_FILE" | wc -l | tr -d ' ')
    if [ "$current_count" -ge 5 ]; then
        echo -e "  Canal atual:     ${RED}$current_channel — CONGESTIONADO ($current_count redes)${RESET}"
    elif [ "$current_count" -ge 3 ]; then
        echo -e "  Canal atual:     ${YELLOW}$current_channel — MODERADO ($current_count redes)${RESET}"
    else
        echo -e "  Canal atual:     ${GREEN}$current_channel — BOM ($current_count redes)${RESET}"
    fi
fi

echo ""
echo -e "  ${BOLD}Recomendacao:${RESET}"

if [ -n "$best_24_ch" ]; then
    if [ "$best_24_count" -eq 0 ]; then
        echo -e "  Canal ideal 2.4: ${GREEN}$best_24_ch — LIVRE${RESET}"
    else
        echo -e "  Canal ideal 2.4: ${GREEN}$best_24_ch ($best_24_count redes — menos congestionado)${RESET}"
    fi
fi

if [ -n "$best_5_ch" ]; then
    if [ "$best_5_count" -eq 0 ]; then
        echo -e "  Canal ideal 5G:  ${GREEN}$best_5_ch — LIVRE${RESET}"
    else
        echo -e "  Canal ideal 5G:  ${GREEN}$best_5_ch ($best_5_count redes — menos congestionado)${RESET}"
    fi
fi

echo "  ─────────────────────────────────"
echo ""
echo -e "  ${DIM}Acesse o painel do roteador (geralmente 192.168.1.1)${RESET}"
echo -e "  ${DIM}e altere o canal nas configuracoes de Wi-Fi.${RESET}"
echo ""
