#!/bin/bash
# menu-launcher.sh — Menu interativo para execução de scripts do repositório (Linux/macOS)
# Uso: ./menu-launcher.sh [opcoes]

set -eo pipefail

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
RESET='\033[0m'

VERSION="1.1.0"

DIM='\033[0;90m'

log() { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

declare -A SCRIPT_DESC
SCRIPT_DESC=(
    [clean-cache.sh]="Limpa arquivos temporários e caches de aplicações"
    [clean-system.sh]="Limpeza profunda do sistema baseada na distro"
    [dependency-helper.sh]="Biblioteca de verificação e auto-instalação de dependências"
    [disk-health.sh]="Monitora saúde SMART do disco"
    [disk-scanner.sh]="Identifica os maiores arquivos e pastas no disco"
    [docker-audit.sh]="Auditoria de segurança de containers Docker"
    [docker-backup.sh]="Backup de volumes e configurações de containers"
    [docker-clean.sh]="Limpa recursos não utilizados do Docker"
    [docker-compose-manager.sh]="Gerencia múltiplos docker-compose.yml"
    [docker-healthcheck.sh]="Verifica saúde e reinicia containers unhealthy"
    [docker-logs-watcher.sh]="Monitora logs de containers com filtros"
    [docker-resource-alert.sh]="Alerta quando container ultrapassa limites de CPU/RAM"
    [docker-restore.sh]="Restaura volumes e configurações de containers"
    [docker-status.sh]="Painel resumido do estado do Docker"
    [env-manager.sh]="Orquestra dependências de projetos multiplataforma"
    [folder-sync.sh]="Sincroniza diretórios com rsync"
    [git-sync.sh]="Sincroniza múltiplos repositórios Git"
    [hunt-duplicates.sh]="Busca arquivos duplicados via SHA-256"
    [install-scripts.sh]="Instala scripts em ~/.local/bin e configura o PATH"
    [menu-launcher.sh]="Menu interativo para execução de scripts"
    [organize-downloads.sh]="Organiza arquivos por tipo de extensão"
    [pomodor.sh]="Timer Pomodoro com notificações"
    [quick-backup.sh]="Backup incremental com rsync"
    [setup-workspace.sh]="Gerenciador de layouts de multi-monitores"
    [speedtest-log.sh]="Histórico de testes de velocidade da internet"
    [wifi-scanner.sh]="Escaneia redes Wi-Fi e sugere melhor canal"
)

declare -A SCRIPT_CATEGORY
SCRIPT_CATEGORY=(
    [clean-cache.sh]="Sistema e Manutenção"
    [clean-system.sh]="Sistema e Manutenção"
    [dependency-helper.sh]="Infraestrutura"
    [disk-health.sh]="Sistema e Manutenção"
    [disk-scanner.sh]="Sistema e Manutenção"
    [docker-audit.sh]="Docker"
    [docker-backup.sh]="Docker"
    [docker-clean.sh]="Docker"
    [docker-compose-manager.sh]="Docker"
    [docker-healthcheck.sh]="Docker"
    [docker-logs-watcher.sh]="Docker"
    [docker-resource-alert.sh]="Docker"
    [docker-restore.sh]="Docker"
    [docker-status.sh]="Docker"
    [env-manager.sh]="Instalação e Execução"
    [folder-sync.sh]="Sincronização e Backup"
    [git-sync.sh]="Sincronização e Backup"
    [hunt-duplicates.sh]="Sistema e Manutenção"
    [install-scripts.sh]="Instalação e Execução"
    [menu-launcher.sh]="Instalação e Execução"
    [organize-downloads.sh]="Sistema e Manutenção"
    [pomodor.sh]="Produtividade"
    [quick-backup.sh]="Sincronização e Backup"
    [setup-workspace.sh]="Produtividade"
    [speedtest-log.sh]="Produtividade"
    [wifi-scanner.sh]="Produtividade"
)

CATEGORY_ORDER=("Instalação e Execução" "Docker" "Sistema e Manutenção" "Sincronização e Backup" "Produtividade" "Infraestrutura")

# Identifica o diretório de instalação (seja local ou ~/.local/bin)
if [[ "$(basename "$0")" == "menu-launcher.sh" ]]; then
    if [[ "$0" == *".local/bin"* ]]; then
        SCRIPT_DIR="$HOME/.local/bin"
    else
        SCRIPT_DIR="$(pwd)"
    fi
fi

SCRIPTS_LIST=()

show_menu() {
    local idx=1
    for cat in "${CATEGORY_ORDER[@]}"; do
        local cat_scripts=()
        for script in $(ls "$SCRIPT_DIR"/*.sh 2>/dev/null | sort | sed 's/.*\///'); do
            if [[ "${SCRIPT_CATEGORY[$script]}" == "$cat" ]]; then
                cat_scripts+=("$script")
            fi
        done
        if [[ ${#cat_scripts[@]} -eq 0 ]]; then
            continue
        fi
        echo -e "\n  ${BOLD}${CYAN}── $cat ──${RESET}"
        for script in "${cat_scripts[@]}"; do
            local desc="${SCRIPT_DESC[$script]:-Sem descrição}"
            printf "  ${GREEN}%2d${RESET}) %-30s ${DIM}%s${RESET}\n" "$idx" "$script" "$desc"
            SCRIPTS_LIST[$idx]="$script"
            ((idx++))
        done
    done
    echo -e "\n  ${BOLD} 0) Sair${RESET}"
    echo ""
}

# Main logic
clear
echo -e "${CYAN}${BOLD}=== My Util Scripts Launcher ===${RESET}"
echo -e "Versão: $VERSION | Pasta: $SCRIPT_DIR"

if command -v fzf >/dev/null 2>&1; then
    SELECTED=$(ls "$SCRIPT_DIR"/*.sh 2>/dev/null | sort | sed 's/.*\///' | fzf --prompt="🚀 Selecione um script: " --height=~50% --border --preview="head -5 $SCRIPT_DIR/{}")
else
    show_menu
    read -p "Opção: " choice
    if [[ "$choice" -gt 0 && "$choice" -le "${#SCRIPTS_LIST[@]}" ]]; then
        SELECTED="${SCRIPTS_LIST[$choice]}"
    fi
fi

if [ -z "$SELECTED" ]; then
    echo "Saindo..."
    exit 0
fi

# Executa o script selecionado
SCRIPT_PATH="$SCRIPT_DIR/$SELECTED"
if [ -f "$SCRIPT_PATH" ]; then
    echo -e "\n${YELLOW}Executando: $SELECTED${RESET}"
    read -p "Deseja passar argumentos extras? (Enter para nenhum): " ARGS
    
    # Execução
    chmod +x "$SCRIPT_PATH"
    "$SCRIPT_PATH" $ARGS
    
    echo -e "\n${CYAN}--------------------------------------------------${RESET}"
    echo "Script finalizado. Pressione Enter para voltar ao menu."
    read
    exec "$0" # Reinicia o menu
else
    error "Script não encontrado: $SCRIPT_PATH"
    exit 1
fi
