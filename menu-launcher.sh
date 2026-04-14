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

VERSION="1.0.0"

log() { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# Identifica o diretório de instalação (seja local ou ~/.local/bin)
if [[ "$(basename "$0")" == "menu-launcher.sh" ]]; then
    # Se executado via path global, tenta achar onde os outros scripts estão
    if [[ "$0" == *".local/bin"* ]]; then
        SCRIPT_DIR="$HOME/.local/bin"
    else
        SCRIPT_DIR="$(pwd)"
    fi
fi

# Função para listar scripts
list_scripts() {
    find "$SCRIPT_DIR" -maxdepth 1 -name "*.sh" | sort | sed 's/.*\///'
}

# Interface com FZF (se disponível)
launch_fzf() {
    SELECTED=$(list_scripts | fzf --prompt="🚀 Selecione um script: " --height=10 --border)
    if [ -n "$SELECTED" ]; then
        echo "$SELECTED"
    fi
}

# Interface Simples (fallback)
launch_simple() {
    scripts=($(list_scripts))
    echo -e "${BOLD}Selecione um script:${RESET}"
    for i in "${!scripts[@]}"; do
        echo -e "  $((i+1))) ${scripts[$i]}"
    done
    echo -e "  0) Sair"
    
    read -p "Opção: " choice
    if [[ "$choice" -gt 0 && "$choice" -le "${#scripts[@]}" ]]; then
        echo "${scripts[$((choice-1))]}"
    fi
}

# Main logic
clear
echo -e "${CYAN}${BOLD}=== My Util Scripts Launcher ===${RESET}"
echo -e "Versão: $VERSION | Pasta: $SCRIPT_DIR\n"

if command -v fzf >/dev/null 2>&1; then
    SELECTED=$(launch_fzf)
else
    SELECTED=$(launch_simple)
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
