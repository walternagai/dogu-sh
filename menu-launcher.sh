#!/bin/bash
# menu-launcher.sh — Menu interativo com barra luminosa para selecao de scripts
# Uso: ./menu-launcher.sh

set -eo pipefail

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

VERSION="2.0.0"

declare -A SCRIPT_DESC
SCRIPT_DESC=(
    [log-analyzer.sh]="Analisa logs com cores e filtros"
    [process-killer.sh]="Busca e mata processos interativamente"
    [ssh-tunnel-mgr.sh]="Gerencia túneis SSH persistentes"
    [clean-cache.sh]="Limpa arquivos temporarios e caches de aplicacoes"
    [clean-system.sh]="Limpeza profunda do sistema baseada na distro"
    [clipboard-manager.sh]="Historico do clipboard com busca e persistencia"
    [dependency-helper.sh]="Biblioteca de verificacao e auto-instalacao de dependencias"
    [disk-health.sh]="Monitora saude SMART do disco"
    [disk-scanner.sh]="Identifica os maiores arquivos e pastas no disco"
    [docker-audit.sh]="Auditoria de seguranca de containers Docker"
    [docker-backup.sh]="Backup de volumes e configuracoes de containers"
    [docker-clean.sh]="Limpa recursos nao utilizados do Docker"
    [docker-compose-manager.sh]="Gerencia multiplos docker-compose.yml"
    [docker-healthcheck.sh]="Verifica saude e reinicia containers unhealthy"
    [docker-image-slimmer.sh]="Analisa camadas de imagens e sugere reducoes"
    [docker-logs-watcher.sh]="Monitora logs de containers com filtros"
    [docker-network-manager.sh]="Gerencia redes Docker (criar, remover, conectar)"
    [docker-resource-alert.sh]="Alerta quando container ultrapassa limites de CPU/RAM"
    [docker-restore.sh]="Restaura volumes e configuracoes de containers"
    [docker-stats-history.sh]="Registra historico de CPU/RAM dos containers em CSV"
    [docker-status.sh]="Painel resumido do estado do Docker"
    [docker-volume-mgr.sh]="Lista, identifica orfaos, faz backup e restaura volumes"
    [env-manager.sh]="Orquestra dependencias de projetos multiplataforma"
    [folder-sync.sh]="Sincroniza diretorios com rsync"
    [git-sync.sh]="Sincroniza multiplos repositorios Git"
    [hunt-duplicates.sh]="Busca arquivos duplicados via SHA-256"
    [install-scripts.sh]="Instala scripts em ~/.local/bin e configura o PATH"
    [menu-launcher.sh]="Menu interativo para execucao de scripts"
    [organize-downloads.sh]="Organiza arquivos por tipo de extensao"
    [package-list-backup.sh]="Exporta/importa lista de pacotes instalados"
    [pomodor.sh]="Timer Pomodoro com notificacoes"
    [quick-backup.sh]="Backup incremental com rsync"
    [setup-workspace.sh]="Gerenciador de layouts de multi-monitores"
    [snap-flatpak-manager.sh]="Lista, atualiza e limpa snaps e flatpaks"
    [speedtest-log.sh]="Historico de testes de velocidade da internet"
    [ssh-key-manager.sh]="Gerencia chaves SSH (gerar, listar, rotacionar)"
    [update-all.sh]="Atualiza pacotes do sistema e linguagens em um comando"
    [wifi-scanner.sh]="Escaneia redes Wi-Fi e sugere melhor canal"
    [calculator.sh]="Calculadora interativa com historico e expressoes"
    [unit-converter.sh]="Conversao entre unidades de medida"
    [currency-converter.sh]="Cotacao de moedas em tempo real via API"
    [subnet-calc.sh]="Calculadora de sub-redes IPv4/CIDR"
    [color-converter.sh]="Conversao entre HEX, RGB, HSL e nome de cor"
    [weather.sh]="Previsao do tempo via wttr.in"
    [world-clock.sh]="Relogio com multiplos fusos horarios"
    [alarm.sh]="Alarme/cronometro com notificacoes"
    [stopwatch.sh]="Cronometro com voltas (laps)"
    [calendar.sh]="Calendario mensal com marcacao de eventos"
    [todo.sh]="Lista de tarefas com prioridades e categorias"
    [quick-notes.sh]="Bloco de notas rapido com busca e tags"
    [password-gen.sh]="Gerador de senhas configuravel"
    [qr-gen.sh]="Gera QR Code no terminal ou salva como PNG"
    [base64-tool.sh]="Codifica/decodifica Base64, URL e Hex"
    [uuid-gen.sh]="Gera UUIDs v4 (um ou em lote)"
    [battery-monitor.sh]="Status da bateria com alerta de nivel baixo"
    [brightness.sh]="Controle de brilho do monitor"
    [screenshot.sh]="Captura de tela com salvamento automatico"
    [volume.sh]="Controle de volume e mute via PulseAudio/PipeWire"
    [media-control.sh]="Controla players MPRIS e mostra now playing"
    [dark-mode.sh]="Alterna tema claro/escuro em GTK e terminais"
    [ip-info.sh]="Info do IP publico, ISP e localizacao geografica"
    [dns-lookup.sh]="Lookup DNS (A, AAAA, MX, NS, TXT, CNAME)"
    [port-check.sh]="Verifica se portas estao abertas em um host"
    [whois.sh]="Consulta WHOIS de dominios"
    [nvidia-gpu-monitor.sh]="Monitora atividade da GPU NVIDIA em segundo plano"
    [docker-cis-benchmark.sh]="Verifica conformidade com CIS Docker Benchmark"
    [docker-bottleneck-detect.sh]="Detecta gargalos comparando limites config vs uso real"
    [docker-dependency-map.sh]="Mapeia relacoes de dependencia entre containers"
    [docker-secret-scanner.sh]="Escaneia containers em busca de segredos expostos"
    [docx-to-md.sh]="Converte arquivos .docx para Markdown (.md) via pandoc"
    [xlsx-to-csv.sh]="Converte arquivos .xlsx para CSV, extraindo cada aba separadamente"
    [env-keygen.sh]="Gera chaves secretas seguras para arquivos .env via openssl"
)

declare -A SCRIPT_CATEGORY
SCRIPT_CATEGORY=(
    [log-analyzer.sh]="Sistema e Monitoramento"
    [process-killer.sh]="Sistema e Monitoramento"
    [ssh-tunnel-mgr.sh]="Infraestrutura"
    [clean-cache.sh]="Sistema e Manutencao"
    [clean-system.sh]="Sistema e Manutencao"
    [clipboard-manager.sh]="Produtividade e Notas"
    [dependency-helper.sh]="Infraestrutura"
    [disk-health.sh]="Sistema e Manutencao"
    [disk-scanner.sh]="Sistema e Manutencao"
    [docker-audit.sh]="Docker"
    [docker-backup.sh]="Docker"
    [docker-clean.sh]="Docker"
    [docker-compose-manager.sh]="Docker"
    [docker-healthcheck.sh]="Docker"
    [docker-image-slimmer.sh]="Docker"
    [docker-logs-watcher.sh]="Docker"
    [docker-network-manager.sh]="Docker"
    [docker-resource-alert.sh]="Docker"
    [docker-restore.sh]="Docker"
    [docker-stats-history.sh]="Docker"
    [docker-status.sh]="Docker"
    [docker-volume-mgr.sh]="Docker"
    [env-manager.sh]="Instalacao e Execucao"
    [folder-sync.sh]="Sincronizacao e Backup"
    [git-sync.sh]="Sincronizacao e Backup"
    [hunt-duplicates.sh]="Sistema e Manutencao"
    [install-scripts.sh]="Instalacao e Execucao"
    [menu-launcher.sh]="Instalacao e Execucao"
    [organize-downloads.sh]="Sistema e Manutencao"
    [package-list-backup.sh]="Sistema e Manutencao"
    [pomodor.sh]="Produtividade e Notas"
    [quick-backup.sh]="Sincronizacao e Backup"
    [setup-workspace.sh]="Produtividade e Notas"
    [snap-flatpak-manager.sh]="Sistema e Manutencao"
    [speedtest-log.sh]="Produtividade e Notas"
    [ssh-key-manager.sh]="Infraestrutura"
    [update-all.sh]="Sistema e Manutencao"
    [wifi-scanner.sh]="Produtividade e Notas"
    [calculator.sh]="Calculadoras e Conversores"
    [unit-converter.sh]="Calculadoras e Conversores"
    [currency-converter.sh]="Calculadoras e Conversores"
    [subnet-calc.sh]="Calculadoras e Conversores"
    [color-converter.sh]="Calculadoras e Conversores"
    [weather.sh]="Tempo e Relogio"
    [world-clock.sh]="Tempo e Relogio"
    [alarm.sh]="Tempo e Relogio"
    [stopwatch.sh]="Tempo e Relogio"
    [calendar.sh]="Tempo e Relogio"
    [todo.sh]="Produtividade e Notas"
    [quick-notes.sh]="Produtividade e Notas"
    [password-gen.sh]="Produtividade e Notas"
    [qr-gen.sh]="Produtividade e Notas"
    [base64-tool.sh]="Produtividade e Notas"
    [uuid-gen.sh]="Produtividade e Notas"
    [battery-monitor.sh]="Sistema e Monitoramento"
    [brightness.sh]="Sistema e Monitoramento"
    [screenshot.sh]="Sistema e Monitoramento"
    [volume.sh]="Sistema e Monitoramento"
    [media-control.sh]="Sistema e Monitoramento"
    [dark-mode.sh]="Sistema e Monitoramento"
    [ip-info.sh]="Rede e Lookup"
    [dns-lookup.sh]="Rede e Lookup"
    [port-check.sh]="Rede e Lookup"
    [whois.sh]="Rede e Lookup"
    [nvidia-gpu-monitor.sh]="Sistema e Monitoramento"
    [docker-cis-benchmark.sh]="Docker"
    [docker-bottleneck-detect.sh]="Docker"
    [docker-dependency-map.sh]="Docker"
    [docker-secret-scanner.sh]="Docker"
    [docx-to-md.sh]="Produtividade e Notas"
    [xlsx-to-csv.sh]="Produtividade e Notas"
    [env-keygen.sh]="Seguranca e Criptografia"
)

CATEGORY_ORDER=("Instalacao e Execucao" "Docker" "Sistema e Manutencao" "Sincronizacao e Backup" "Infraestrutura" "Calculadoras e Conversores" "Tempo e Relogio" "Produtividade e Notas" "Sistema e Monitoramento" "Rede e Lookup" "Seguranca e Criptografia")

CATEGORY_ICONS=()
CATEGORY_ICONS_BY_NAME=()
# Icons indexed by name using parallel arrays (bash 4 compatible)
CAT_ICO_PKG="📦 Instalacao e Execucao"
CAT_ICO_DKR="🐳 Docker"
CAT_ICO_SYS="🛠  Sistema e Manutencao"
CAT_ICO_BKP="📂 Sincronizacao e Backup"
CAT_ICO_INF="🛡  Infraestrutura"
CAT_ICO_CALC="🔢 Calculadoras e Conversores"
CAT_ICO_TM="🕐 Tempo e Relogio"
CAT_ICO_NOTES="📝 Produtividade e Notas"
CAT_ICO_MON="🖥  Sistema e Monitoramento"
CAT_ICO_NET="🌐 Rede e Lookup"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MENU_RESULT=""

# Build ordered arrays of categories and their scripts
# CAT_NAMES[i] = category name, CAT_SCRIPTS[i] = "script1 script2 ..."
CAT_NAMES=()
CAT_SCRIPTS=()
CAT_COUNTS=()

build_categories() {
    CAT_NAMES=()
    CAT_SCRIPTS=()
    CAT_COUNTS=()
    for cat in "${CATEGORY_ORDER[@]}"; do
        scripts_for_cat=""
        count=0
        for script in $(ls "$SCRIPT_DIR"/*.sh 2>/dev/null | sort | sed 's/.*\///'); do
            if [[ "${SCRIPT_CATEGORY[$script]}" == "$cat" ]]; then
                if [[ -n "$scripts_for_cat" ]]; then
                    scripts_for_cat="$scripts_for_cat|$script"
                else
                    scripts_for_cat="$script"
                fi
                count=$((count + 1))
            fi
        done
        if [[ $count -gt 0 ]]; then
            CAT_NAMES+=("$cat")
            CAT_SCRIPTS+=("$scripts_for_cat")
            CAT_COUNTS+=("$count")
        fi
    done
}

get_cat_icon() {
    case "$1" in
        "Instalacao e Execucao") echo "📦" ;;
        "Docker") echo "🐳" ;;
        "Sistema e Manutencao") echo "🛠" ;;
        "Sincronizacao e Backup") echo "📂" ;;
        "Infraestrutura") echo "🛡" ;;
        "Calculadoras e Conversores") echo "🔢" ;;
        "Tempo e Relogio") echo "🕐" ;;
        "Produtividade e Notas") echo "📝" ;;
        "Sistema e Monitoramento") echo "🖥" ;;
        "Rede e Lookup") echo "🌐" ;;
        *) echo "📁" ;;
    esac
}

get_term_height() { tput lines 2>/dev/null || echo 24; }
get_term_width()  { tput cols 2>/dev/null || echo 80; }

setup_terminal()   { tput smcup 2>/dev/null || true; stty -echo 2>/dev/null || true; }
restore_terminal() { stty echo 2>/dev/null || true; tput rmcup 2>/dev/null || true; tput cnorm 2>/dev/null || true; }
clear_screen()     { printf '\033[2J\033[H'; }
hide_cursor()     { printf '\033[?25l'; }
show_cursor()     { printf '\033[?25h'; }

draw_header() {
    local title="$1" subtitle="$2"
    local width=$(get_term_width)
    local line=""
    for ((i=0; i<width; i++)); do line="${line}━"; done
    echo -e "${CYAN}${line}${RESET}"
    echo -e "  ${BOLD}${CYAN}dō${RESET}${BOLD}gu-sh${RESET}  ${DIM}│${RESET}  ${BOLD}${title}${RESET}"
    [ -n "$subtitle" ] && echo -e "  ${DIM}${subtitle}${RESET}"
    echo -e "${CYAN}${line}${RESET}"
    echo ""
}

draw_footer() {
    local hint="$1"
    local width=$(get_term_width)
    local line=""
    for ((i=0; i<width; i++)); do line="${line}─"; done
    echo ""
    echo -e "${DIM}${line}${RESET}"
    echo -e "  ${DIM}↑↓ navegar${RESET}  ${DIM}│${RESET}  ${GREEN}Enter${RESET} selecionar  ${DIM}│${RESET}  ${YELLOW}Esc${RESET} voltar/sair  ${DIM}│${RESET}  ${DIM}${hint}${RESET}"
    echo -e "${DIM}${line}${RESET}"
}

read_key() {
    local key
    IFS= read -rsn1 key 2>/dev/null || key=""
    if [ -z "$key" ]; then
        echo "enter"; return
    fi
    case "$key" in
        $'\x1b')
            local seq=""
            read -rsn2 -t0.05 seq 2>/dev/null || true
            case "$seq" in
                '[A'|'A') echo "up" ;;
                '[B'|'B') echo "down" ;;
                '[D'|'D') echo "left" ;;
                '[C'|'C') echo "right" ;;
                *) echo "esc" ;;
            esac
            ;;
        q|Q) echo "esc" ;;
        j) echo "down" ;;
        k) echo "up" ;;
        l) echo "right" ;;
        h) echo "left" ;;
        g) echo "home" ;;
        G) echo "end" ;;
        '') echo "space" ;;
        *) echo "key:$key" ;;
    esac
}

show_category_menu() {
    local selected=0
    local start=0
    local total=${#CAT_NAMES[@]}
    local redraw=true

    while true; do
        if $redraw; then
            clear_screen
            draw_header "Selecione uma categoria" "${total} categorias disponiveis"

            local term_height=$(get_term_height)
            local visible=$((term_height - 8))
            [ $visible -lt 3 ] && visible=3
            [ $visible -gt $total ] && visible=$total

            [ $selected -lt $start ] && start=$selected
            [ $selected -ge $((start + visible)) ] && start=$((selected - visible + 1))
            [ $start -lt 0 ] && start=0

            local end=$((start + visible - 1))
            [ $end -ge $total ] && end=$((total - 1))

            for ((i=start; i<=end; i++)); do
                local cat="${CAT_NAMES[$i]}"
                local icon=$(get_cat_icon "$cat")
                local count="${CAT_COUNTS[$i]}"
                local count_str="(${count})"
                local width=$(get_term_width)

                if [ "$i" -eq "$selected" ]; then
                    # Barra destacada: "  [SP]cat  (count)[padding]"
                    # prefixo visível = 3 ("  " + espaço do formato)
                    local bar_width=$((width - 3))
                    local inner="${cat}  ${count_str}"
                    printf "  \033[7m${BOLD} %-${bar_width}s\033[27m${RESET}\n" "$inner"
                else
                    # Linha normal: "  icon  [cat padded]  (count)"
                    # prefixo visível = 6 ("  " + emoji 2 colunas + "  ")
                    # sufixo = " (count)" = 1 + len(count_str)
                    local cat_width=$((width - 6 - 1 - ${#count_str}))
                    [ $cat_width -lt 1 ] && cat_width=1
                    printf "  ${icon}  %-${cat_width}s ${DIM}${count_str}${RESET}\n" "$cat"
                fi
            done

            local scroll_hints=""
            [ $start -gt 0 ] && scroll_hints="${scroll_hints}▲ mais acima  "
            [ $end -lt $((total - 1)) ] && scroll_hints="${scroll_hints}▼ mais abaixo  "
            draw_footer "$scroll_hints"
            hide_cursor
            redraw=false
        fi

        local key=$(read_key)
        case "$key" in
            up)    [ $selected -gt 0 ] && selected=$((selected - 1)); redraw=true ;;
            down)  [ $selected -lt $((total - 1)) ] && selected=$((selected + 1)); redraw=true ;;
            home)  selected=0; redraw=true ;;
            end)   selected=$((total - 1)); redraw=true ;;
            enter) MENU_RESULT="$selected"; return ;;
            esc)   MENU_RESULT=""; return ;;
        esac
    done
}

show_script_menu() {
    local cat_idx="$1"
    local category="${CAT_NAMES[$cat_idx]}"
    local scripts_str="${CAT_SCRIPTS[$cat_idx]}"
    local -a scripts=()
    local IFS_OLD="$IFS"
    IFS='|'
    read -ra scripts <<< "$scripts_str"
    IFS="$IFS_OLD"
    local selected=0
    local start=0
    local total=${#scripts[@]}
    local redraw=true

    while true; do
        if $redraw; then
            clear_screen
            local icon=$(get_cat_icon "$category")
            draw_header "${icon} ${category}" "${total} scripts disponiveis"

            local term_height=$(get_term_height)
            local visible=$((term_height - 8))
            [ $visible -lt 3 ] && visible=3
            [ $visible -gt $total ] && visible=$total

            [ $selected -lt $start ] && start=$selected
            [ $selected -ge $((start + visible)) ] && start=$((selected - visible + 1))
            [ $start -lt 0 ] && start=0

            local end=$((start + visible - 1))
            [ $end -ge $total ] && end=$((total - 1))

            for ((i=start; i<=end; i++)); do
                local script="${scripts[$i]}"
                local desc="${SCRIPT_DESC[$script]:-Sem descricao}"
                local width=$(get_term_width)
                local padding=$((width - 4))

                if [ "$i" -eq "$selected" ]; then
                    printf "  \033[7m${BOLD} %-${padding}s\033[27m${RESET}\n" "${script}  ${desc}"
                else
                    printf "  ${GREEN}%-28s${RESET} ${DIM}%-$((${padding} - 28))s${RESET}\n" "$script" "$desc"
                fi
            done

            local scroll_hints=""
            [ $start -gt 0 ] && scroll_hints="${scroll_hints}▲ mais acima  "
            [ $end -lt $((total - 1)) ] && scroll_hints="${scroll_hints}▼ mais abaixo  "
            draw_footer "$scroll_hints"
            hide_cursor
            redraw=false
        fi

        local key=$(read_key)
        case "$key" in
            up|left) [ $selected -gt 0 ] && selected=$((selected - 1)); redraw=true ;;
            down)    [ $selected -lt $((total - 1)) ] && selected=$((selected + 1)); redraw=true ;;
            home)    selected=0; redraw=true ;;
            end)     selected=$((total - 1)); redraw=true ;;
            esc)     MENU_RESULT=""; return ;;
            enter)   MENU_RESULT="${scripts[$selected]}"; return ;;
        esac
    done
}

run_script() {
    local script="$1"
    local script_path="$SCRIPT_DIR/$script"
    show_cursor
    restore_terminal
    clear_screen

    echo ""
    echo -e "  ${YELLOW}${BOLD}▶ Executando: ${script}${RESET}"
    echo -e "  ${DIM}Descricao: ${SCRIPT_DESC[$script]:-}${RESET}"
    echo ""

    read -p "  Argumentos extras (Enter para nenhum): " args
    echo ""

    chmod +x "$script_path" 2>/dev/null
    "$script_path" $args
    local exit_code=$?

    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────────────${RESET}"
    if [ $exit_code -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}✓${RESET} Script finalizado com sucesso"
    else
        echo -e "  ${RED}${BOLD}✗${RESET} Script finalizou com codigo ${exit_code}"
    fi
    echo -e "  ${DIM}────────────────────────────────────────────────────${RESET}"
    echo ""
    read -p "  Pressione Enter para voltar ao menu..." dummy
}

fzf_mode() {
    local selected
    selected=$(ls "$SCRIPT_DIR"/*.sh 2>/dev/null | sort | sed 's/.*\///' | \
        fzf --prompt="dogu-sh> " \
            --height=~80% \
            --border \
            --preview="head -8 $SCRIPT_DIR/{}" \
            --preview-window='right:50%:wrap' 2>/dev/null)
    echo "$selected"
}

main() {
    build_categories

    if [ ${#CAT_NAMES[@]} -eq 0 ]; then
        echo -e "${RED}Nenhum script encontrado em: ${SCRIPT_DIR}${RESET}"
        exit 1
    fi

    if [[ "$1" == "--fzf" ]] && command -v fzf &>/dev/null; then
        while true; do
            local selected
            selected=$(fzf_mode)
            [ -z "$selected" ] && break
            local script_path="$SCRIPT_DIR/$selected"
            [ -f "$script_path" ] && run_script "$selected"
        done
        exit 0
    fi

    trap 'restore_terminal; show_cursor; echo ""; exit 0' INT TERM
    setup_terminal
    hide_cursor

    while true; do
        show_category_menu
        local chosen_idx="$MENU_RESULT"
        [ -z "$chosen_idx" ] && break

        show_script_menu "$chosen_idx"
        local chosen_script="$MENU_RESULT"
        [ -z "$chosen_script" ] && continue

        run_script "$chosen_script"
    done

    restore_terminal
    show_cursor
    clear_screen
    echo -e "  ${DIM}Ate logo!${RESET}"
    echo ""
}

main "$@"