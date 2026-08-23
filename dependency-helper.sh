#!/bin/bash
# dependency-helper.sh — Utilitário interno para verificação e instalação de dependências
# Uso: source ./dependency-helper.sh
# Opcoes: N/A (script importado por outros scripts)

check_and_install() {
    local pkg_name=$1
    local install_cmd=$2
    local pkg=${3:-}
    local green="${GREEN-$'\033[1;32m'}"
    local yellow="${YELLOW-$'\033[1;33m'}"
    local red="${RED-$'\033[1;31m'}"
    local cyan="${CYAN-$'\033[1;36m'}"
    local reset="${RESET-$'\033[0m'}"

    if command -v "$pkg_name" >/dev/null 2>&1; then
        return 0
    fi

    echo -e "${yellow}[WARN] Dependência '$pkg_name' não encontrada.${reset}"
    if [ -t 0 ]; then
        read -r -p "Deseja instalar '$pkg_name' agora? [s/N]: " choice
    else
        error "Execucao nao interativa detectada. Rode em terminal interativo (TTY) para confirmar."
    fi
    if [[ "$choice" =~ ^[Ss]$ ]]; then
        echo -e "${cyan}Instalando $pkg_name...${reset}"
        if eval "$install_cmd $pkg"; then
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

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    VERSION="1.0.0"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                echo ""
                echo "  dependency-helper.sh — Utilitario de verificacao e auto-instalacao de dependencias"
                echo ""
                echo "  Uso: source ./dependency-helper.sh  (importado por outros scripts)"
                echo ""
                echo "  Opcoes:"
                echo "    --help|-h       Mostra esta ajuda"
                echo "    --version|-V    Mostra versao"
                echo ""
                exit 0
                ;;
            --version|-V) echo "dependency-helper.sh $VERSION"; exit 0 ;;
            *) shift ;;
        esac
    done
    echo "Este script e uma biblioteca — use 'source ./dependency-helper.sh' em outros scripts."
    exit 1
fi
