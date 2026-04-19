#!/bin/bash
# speedtest-log.sh — Executa testes de velocidade e mantem historico em CSV (Linux)
# Uso: ./speedtest-log.sh [opcoes]
# Opcoes:
#   --run           Executa um teste de velocidade agora
#   --history       Mostra historico de testes
#   --today         Mostra apenas resultados de hoje
#   --chart         Mostra grafico ASCII dos resultados recentes
#   --csv           Exporta historico completo como CSV para stdout
#   --output DIR    Diretorio para dados (padrao: ~/.local/share/speedtest-log)
#   --help          Mostra esta ajuda
#   --version       Mostra versao

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "speedtest" "$INSTALLER" "speedtest-cli"; fi




ACTION="run"
DATA_DIR="$HOME/.local/share/speedtest-log"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run|-r) ACTION="run"; shift ;;
        --history|-h) ACTION="history"; shift ;;
        --today|-t) ACTION="today"; shift ;;
        --chart|-c) ACTION="chart"; shift ;;
        --csv) ACTION="csv"; shift ;;
        --output|-o)
            [[ -z "${2-}" ]] && { echo "Flag --output requer um valor" >&2; exit 1; }
            DATA_DIR="$2"; shift 2 ;;
        --help)
            echo ""
            echo "  speedtest-log.sh — Run speedtests and keep history in CSV"
            echo ""
            echo "  Usage: ./speedtest-log.sh [options]"
            echo ""
            echo "  Options:"
            echo "    --run           Run a speedtest now (default)"
            echo "    --history       Show test history"
            echo "    --today         Show today's results only"
            echo "    --chart         Show ASCII chart of recent results"
            echo "    --csv           Export full history as CSV"
            echo "    --output DIR    Data directory (default: ~/.local/share/speedtest-log)"
            echo "    --help          Show this help"
            echo "    --version       Show version"
            echo ""
            echo "  Requires: speedtest-cli or speedtest"
            echo "    pip install speedtest-cli"
            echo "    or: sudo apt install speedtest-cli"
            echo ""
            echo "  Examples:"
            echo "    ./speedtest-log.sh"
            echo "    ./speedtest-log.sh --chart"
            echo "    ./speedtest-log.sh --today"
            echo ""
            exit 0
            ;;
        --version|-V) echo "speedtest-log.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

mkdir -p "$DATA_DIR"

CSV_FILE="$DATA_DIR/speedtest.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo "timestamp,isp,server,ping_ms,download_mbps,upload_mbps,jitter_ms,packet_loss_pct" > "$CSV_FILE"
fi

detect_speedtest() {
    if command -v speedtest &>/dev/null; then
        echo "speedtest"
    elif command -v speedtest-cli &>/dev/null; then
        echo "speedtest-cli"
    else
        echo ""
    fi
}

run_test() {
    local cmd
    cmd=$(detect_speedtest)

    if [ -z "$cmd" ]; then
        echo -e "  ${RED}Error: speedtest-cli not found.${RESET}" >&2
        echo -e "  ${DIM}Install: pip install speedtest-cli${RESET}" >&2
        exit 1
    fi

    echo ""
    echo -e "  ${BOLD}Running speedtest...${RESET}"
    echo -e "  ${DIM}Using: $cmd${RESET}"
    echo ""

    local output
    output=$($cmd --simple 2>&1) || {
        echo -e "  ${RED}Speedtest failed.${RESET}" >&2
        echo -e "  ${DIM}Try: $cmd --simple${RESET}" >&2
        exit 1
    }

    local ping download upload
    ping=$(echo "$output" | grep -i "ping" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    download=$(echo "$output" | grep -i "download" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)
    upload=$(echo "$output" | grep -i "upload" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1)

    ping=$(echo "${ping:-0}" | tr -d '[:space:]')
    download=$(echo "${download:-0}" | tr -d '[:space:]')
    upload=$(echo "${upload:-0}" | tr -d '[:space:]')

    local isp server
    if [ "$cmd" = "speedtest" ]; then
        local json_output
        json_output=$($cmd --format json 2>/dev/null || echo "{}")
        isp=$(echo "$json_output" | grep -oP '"isp"\s*:\s*"\K[^"]+' || echo "unknown")
        server=$(echo "$json_output" | grep -oP '"name"\s*:\s*"\K[^"]+' | head -1 || echo "unknown")
    else
        local extended
        extended=$($cmd --secure 2>/dev/null || echo "")
        isp="unknown"
        server="unknown"
    fi

    local now
    now=$(date '+%Y-%m-%dT%H:%M:%S')

    echo "$now,$isp,$server,$ping,$download,$upload,0,0" >> "$CSV_FILE"

    echo -e "  ${BOLD}Results:${RESET}"
    echo ""
    echo -e "  Ping:      ${CYAN}${ping} ms${RESET}"
    echo -e "  Download:  ${GREEN}${download} Mbps${RESET}"
    echo -e "  Upload:    ${YELLOW}${upload} Mbps${RESET}"
    echo -e "  Server:    ${DIM}${server:-unknown}${RESET}"
    echo ""
    echo -e "  ${DIM}Saved to: $CSV_FILE${RESET}"
    echo ""
}

show_history() {
    local lines="${1:-20}"

    if [ ! -s "$CSV_FILE" ]; then
        echo -e "  ${DIM}No test history found.${RESET}"
        return
    fi

    echo ""
    echo -e "  ${BOLD}Speedtest History${RESET} (last $lines)"
    echo ""
    printf "  %-20s %-8s %-12s %-12s %s\n" "Date" "Ping" "Download" "Upload" "Server"
    printf "  %-20s %-8s %-12s %-12s %s\n" "────────────────────" "────────" "────────────" "────────────" "──────────"

    tail -n +2 "$CSV_FILE" | tail -n "$lines" | while IFS=',' read -r timestamp isp server ping download upload jitter loss; do
        local date_only
        date_only=$(echo "$timestamp" | cut -dT -f1-2 | tr 'T' ' ' | cut -c1-16)

        local dl_color="$GREEN"
        local dl_num
        dl_num=$(echo "$download" | tr -d '[:space:]')
        if [[ "$dl_num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            dl_int=${dl_num%.*}
            [[ "$dl_int" =~ ^[0-9]+$ ]] || dl_int=0
            if [ "$dl_int" -lt 25 ]; then dl_color="${RED}"
            elif [ "$dl_int" -lt 50 ]; then dl_color="${YELLOW}"
            fi
        fi

        local ul_color="$CYAN"
        local ul_num
        ul_num=$(echo "$upload" | tr -d '[:space:]')
        if [[ "$ul_num" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            ul_int=${ul_num%.*}
            [[ "$ul_int" =~ ^[0-9]+$ ]] || ul_int=0
            if [ "$ul_int" -lt 10 ]; then ul_color="${RED}"
            elif [ "$ul_int" -lt 25 ]; then ul_color="${YELLOW}"
            fi
        fi

        local short_server
        short_server=$(echo "$server" | cut -c1-16)

        printf "  %-20s %-8s ${dl_color}%-12s${RESET} ${ul_color}%-12s${RESET} %s\n" \
            "$date_only" "${ping}ms" "${download}Mbps" "${upload}Mbps" "$short_server"
    done

    echo ""
}

show_today() {
    local today
    today=$(date '+%Y-%m-%d')

    if [ ! -s "$CSV_FILE" ]; then
        echo -e "  ${DIM}No test history found.${RESET}"
        return
    fi

    local today_count
    today_count=$(tail -n +2 "$CSV_FILE" | grep -c "^$today" || echo 0)
    [[ "$today_count" =~ ^[0-9]+$ ]] || today_count=0

    if [ "$today_count" -eq 0 ]; then
        echo ""
        echo -e "  ${DIM}No tests run today ($today).${RESET}"
        echo ""
        return
    fi

    echo ""
    echo -e "  ${BOLD}Today's Results ($today)${RESET} — $today_count test(s)"
    echo ""

    local avg_ping avg_dl avg_ul
    avg_ping=$(tail -n +2 "$CSV_FILE" | grep "^$today" | awk -F',' '{sum+=$4; n++} END {if(n>0) printf "%.1f", sum/n; else print "0"}')
    avg_dl=$(tail -n +2 "$CSV_FILE" | grep "^$today" | awk -F',' '{sum+=$5; n++} END {if(n>0) printf "%.1f", sum/n; else print "0"}')
    avg_ul=$(tail -n +2 "$CSV_FILE" | grep "^$today" | awk -F',' '{sum+=$6; n++} END {if(n>0) printf "%.1f", sum/n; else print "0"}')

    local max_dl min_dl
    max_dl=$(tail -n +2 "$CSV_FILE" | grep "^$today" | awk -F',' '{if(max=="") max=$5; if($5>max) max=$5} END {print max+0}')
    min_dl=$(tail -n +2 "$CSV_FILE" | grep "^$today" | awk -F',' '{if(min=="") min=$5; if($5<min && $5>0) min=$5} END {print min+0}')

    echo -e "  Avg Ping:      ${CYAN}${avg_ping} ms${RESET}"
    echo -e "  Avg Download:  ${GREEN}${avg_dl} Mbps${RESET}"
    echo -e "  Avg Upload:    ${YELLOW}${avg_ul} Mbps${RESET}"
    echo ""
    echo -e "  Best DL:       ${GREEN}${max_dl} Mbps${RESET}"
    echo -e "  Worst DL:      ${RED}${min_dl} Mbps${RESET}"

    echo ""
    show_history 10
}

show_chart() {
    local count="${1:-30}"

    if [ ! -s "$CSV_FILE" ]; then
        echo -e "  ${DIM}No test history found.${RESET}"
        return
    fi

    local total_lines
    total_lines=$(tail -n +2 "$CSV_FILE" | wc -l | tr -d ' ')
    if [ "$total_lines" -eq 0 ]; then
        echo -e "  ${DIM}No data to chart.${RESET}"
        return
    fi

    local data
    data=$(tail -n +2 "$CSV_FILE" | tail -n "$count")

    local max_dl=0
    while IFS=',' read -r _ _ _ _ download _ _ _; do
        download=$(echo "$download" | tr -d '[:space:]')
        if [[ "$download" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            dl_int=${download%.*}
            [[ "$dl_int" =~ ^[0-9]+$ ]] || dl_int=0
            if [ "$dl_int" -gt "$max_dl" ]; then
                max_dl=$dl_int
            fi
        fi
    done <<< "$data"

    if [ "$max_dl" -eq 0 ]; then
        max_dl=100
    fi

    echo ""
    echo -e "  ${BOLD}Download Speed Chart${RESET} (last $count tests, max ${max_dl} Mbps)"
    echo ""
    echo -e "  ${DIM}Mbps${RESET}"

    local bar_max=40

    while IFS=',' read -r timestamp _ _ _ download upload _ _; do
        download=$(echo "$download" | tr -d '[:space:]')
        upload=$(echo "$upload" | tr -d '[:space:]')

        if ! [[ "$download" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            download=0
        fi

        local dl_int=${download%.*}
        [[ "$dl_int" =~ ^[0-9]+$ ]] || dl_int=0
        local bar_len=$((dl_int * bar_max / max_dl))
        [ "$bar_len" -gt "$bar_max" ] && bar_len=$bar_max

        local bar=""
        local i=0
        while [ $i -lt $bar_len ]; do
            bar="${bar}█"
            i=$((i + 1))
        done
        while [ $i -lt $bar_max ]; do
            bar="${bar}░"
            i=$((i + 1))
        done

        local date_short
        date_short=$(echo "$timestamp" | cut -c1-16 | tr 'T' ' ')

        local color="$GREEN"
        if [ "$dl_int" -lt 25 ]; then color="$RED"
        elif [ "$dl_int" -lt 50 ]; then color="$YELLOW"
        fi

        printf "  %s %s${color}%s${RESET} %s\n" "$date_short" "$bar" "${download}Mbps"
    done <<< "$data"

    echo ""
    echo -e "  ${DIM}Scale: ${max_dl} Mbps | █ = download speed${RESET}"
    echo ""
}

export_csv() {
    if [ -s "$CSV_FILE" ]; then
        cat "$CSV_FILE"
    else
        echo -e "  ${DIM}No data to export.${RESET}" >&2
        exit 1
    fi
}

case "$ACTION" in
    run) run_test ;;
    history) show_history 20 ;;
    today) show_today ;;
    chart) show_chart 30 ;;
    csv) export_csv ;;
esac