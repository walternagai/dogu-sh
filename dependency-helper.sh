#!/bin/bash
# dependency-helper.sh — Utilitário interno para verificação e instalação de dependências

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
RESET='\033[0m'

check_and_install() {
    local pkg_name=$1
    local install_cmd=$2

    if command -v "$pkg_name" >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${YELLOW}[WARN] Dependência '$pkg_name' não encontrada.${RESET}"
    read -p "Deseja instalar '$pkg_name' agora? (s/n): " choice
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
        echo -e "${CYAN}Instalando $pkg_name...${RESET}"
        if eval "$install_cmd"; then
            echo -e "${GREEN}[SUCCESS] $pkg_name instalado.${RESET}"
        else
            echo -e "${RED}[ERROR] Falha ao instalar $pkg_name.${RESET}"
            exit 1
        fi
    else
        echo -e "${RED}[ERROR] O script requer '$pkg_name' para funcionar.${RESET}"
        exit 1
    fi
}

# Detecta o gerenciador de pacotes do sistema
detect_installer() {
    if command -v apt-get >/dev/null 2>&1; then echo "sudo apt-get install -y";
    elif command -v pacman >/dev/null 2>&1; then echo "sudo pacman -S --noconfirm";
    elif command -v dnf >/dev/null 2>&1; then echo "sudo dnf install -y";
    elif command -v brew >/dev/null 2>&1; then echo "brew install";
    else echo "echo 'Gerenciador de pacotes não suportado. Por favor, instale manualmente.'"; fi
}
