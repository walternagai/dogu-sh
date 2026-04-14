#!/bin/bash
# install-scripts.sh — Instala scripts no ~/.local/bin e configura o PATH (Linux/macOS)
# Uso: ./install-scripts.sh [--dry-run]

set -eo pipefail

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=false

if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

log() { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

# 1. Criar diretório se não existir
if [ ! -d "$BIN_DIR" ]; then
    log "Criando diretório $BIN_DIR..."
    $DRY_RUN || mkdir -p "$BIN_DIR"
fi

# 2. Copiar scripts
log "Copiando scripts de $SCRIPT_DIR para $BIN_DIR..."
shopt -s nullglob
scripts=("$SCRIPT_DIR"/*.sh)
shopt -u nullglob

if [ ${#scripts[@]} -eq 0 ]; then
    error "Nenhum script .sh encontrado em $SCRIPT_DIR"
fi

for script_path in "${scripts[@]}"; do
    script="$(basename "$script_path")"
    if [ "$DRY_RUN" = false ]; then
        cp "$script_path" "$BIN_DIR/"
        chmod +x "$BIN_DIR/$script"
        log "  ✓ $script"
    else
        echo "  [Dry-run] cp $script_path -> $BIN_DIR/$script"
    fi
done

# 3. Configurar PATH
log "Verificando configuração do PATH..."
SHELL_RC=""
case "$SHELL" in
    */zsh) SHELL_RC="$HOME/.zshrc" ;;
    */bash) SHELL_RC="$HOME/.bashrc" ;;
    */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    *) 
        warn "Shell não reconhecido ou não suportado automaticamente: $SHELL"
        warn "Tente adicionar export PATH=\"\$HOME/.local/bin:\$PATH\" ao seu arquivo de config."
        ;;
esac

if [ -n "$SHELL_RC" ]; then
    if [ ! -f "$SHELL_RC" ]; then
        touch "$SHELL_RC"
    fi

    if grep -q "$BIN_DIR" "$SHELL_RC"; then
        log "PATH já configurado em $SHELL_RC."
    else
        log "Adicionando $BIN_DIR ao PATH em $SHELL_RC..."
        if [ "$DRY_RUN" = false ]; then
            if [[ "$SHELL" == *"fish"* ]]; then
                echo "fish_add_path $BIN_DIR" >> "$SHELL_RC"
            else
                echo -e "\n# Added by install-scripts.sh\nexport PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            fi
            success "PATH atualizado. Reinicie o terminal ou execute: source $SHELL_RC"
        else
            echo "  [Dry-run] Adicionaria PATH a $SHELL_RC"
        fi
    fi
fi

success "Instalação concluída com sucesso!"
echo -e "Versão: $VERSION"
