#!/bin/bash
# dependency-helper.sh — Utilitário interno para verificação e instalação de dependências

check_and_install() {
    local pkg_name=$1
    local install_cmd=$2
    local green="${GREEN-$'\033[1;32m'}"
    local yellow="${YELLOW-$'\033[1;33m'}"
    local red="${RED-$'\033[1;31m'}"
    local cyan="${CYAN-$'\033[1;36m'}"
    local reset="${RESET-$'\033[0m'}"

    if command -v "$pkg_name" >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${yellow}[WARN] Dependência '$pkg_name' não encontrada.${reset}"
    read -p "Deseja instalar '$pkg_name' agora? (s/n): " choice
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
        echo -e "${cyan}Instalando $pkg_name...${reset}"
        if eval "$install_cmd"; then
            echo -e "${green}[SUCCESS] $pkg_name instalado.${reset}"
        else
            echo -e "${red}[ERROR] Falha ao instalar $pkg_name.${reset}"
            exit 1
        fi
    else
        echo -e "${red}[ERROR] O script requer '$pkg_name' para funcionar.${reset}"
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
