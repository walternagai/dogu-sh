#!/bin/bash
# env-manager.sh — Orquestrador de ambientes e dependências multiplataforma (Linux/macOS)
# Uso: ./env-manager.sh [pasta]
# Opcoes: Deteccao automatica de gerenciadores de pacotes e dependencias

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

TARGET_DIR=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo ""
            echo "  env-manager.sh — Orquestrador de ambientes e dependências"
            echo ""
            echo "  Uso: ./env-manager.sh [diretório] [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versão"
            echo ""
            exit 0
            ;;
        --version|-V) echo "env-manager.sh $VERSION"; exit 0 ;;
        *)
            TARGET_DIR="$1"
            ;;
    esac
    shift
done
TARGET_DIR="${TARGET_DIR:-$(pwd)}"

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

if [ ! -d "$TARGET_DIR" ]; then
    error "Diretório não encontrado: $TARGET_DIR"
fi

cd "$TARGET_DIR"
log "Analisando ambiente em: $(pwd)"

# Lista de ações a executar
ACTIONS=()

# --- Detecção de Manifestos ---

# Node.js / TypeScript
if [ -f "package.json" ]; then
    if command -v yarn >/dev/null 2>&1 && [ -f "yarn.lock" ]; then
        ACTIONS+=("yarn install")
    else
        ACTIONS+=("npm install")
    fi
fi

# Python
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    # Sugere VENV se não estiver ativa
    if [ -z "$VIRTUAL_ENV" ]; then
        warn "Ambiente virtual não detectado. Sugerido: python3 -m venv .venv && source .venv/bin/activate"
    fi
    ACTIONS+=("pip install -r requirements.txt" "pip install .") # Tenta ambos se existirem
fi

# Rust
if [ -f "Cargo.toml" ]; then
    ACTIONS+=("cargo build")
fi

# Java / Kotlin
if [ -f "pom.xml" ]; then
    ACTIONS+=("mvn install")
elif [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
    ACTIONS+=("./gradlew build")
fi

# PHP
if [ -f "composer.json" ]; then
    ACTIONS+=("composer install")
fi

# Ruby
if [ -f "Gemfile" ]; then
    ACTIONS+=("bundle install")
fi

# MacOS/Linux Brew
if [ -f "Brewfile" ]; then
    ACTIONS+=("brew bundle")
fi

# Apt (Debian/Ubuntu)
if [ -f "packages.list" ] || [ -f "apt-requirements.txt" ]; then
    FILE=$( [ -f "packages.list" ] && echo "packages.list" || echo "apt-requirements.txt" )
    ACTIONS+=("sudo apt-get update && sudo apt-get install -y \$(cat $FILE)")
fi

# --- Processamento ---

if [ ${#ACTIONS[@]} -eq 0 ]; then
    log "Nenhum manifesto de dependências conhecido encontrado."
    exit 0
fi

echo -e "\n${BOLD}Plano de Setup detectado:${RESET}"
for i in "${!ACTIONS[@]}"; do
    echo -e "  $((i+1))) ${ACTIONS[$i]}"
done

echo -e "\n${CYAN}O que deseja fazer?${RESET}"
echo "  a) Executar TUDO"
echo "  s) Selecionar scripts específicos (separados por vírgula, ex: 1,3)"
echo "  n) Sair"
read -p "Opção: " USER_CHOICE

case "$USER_CHOICE" in
    a|A)
        for cmd in "${ACTIONS[@]}"; do
            log "Executando: $cmd"
            if eval "$cmd"; then success "Concluído!"; else error "Falhou!"; fi
        done
        ;;
    s|S)
        read -p "Digite os números: " indices
        IFS=',' read -ra ADDR <<< "$indices"
        for i in "${ADDR[@]}"; do
            idx=$((i-1))
            if [[ "$idx" -ge 0 && "$idx" -lt "${#ACTIONS[@]}" ]]; then
                log "Executando: ${ACTIONS[$idx]}"
                if eval "${ACTIONS[$idx]}"; then success "Concluído!"; else error "Falhou!"; fi
            fi
        done
        ;;
    *)
        log "Saindo sem alterações."
        exit 0
        ;;
esac

success "Processo de gerenciamento de ambiente finalizado!"
