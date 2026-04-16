#!/bin/bash
# install-scripts.sh — Instala scripts no ~/.local/bin e configura o PATH (Linux/macOS)
# Uso: ./install-scripts.sh [--dry-run | --uninstall]

set -eo pipefail

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
RESET='\033[0m'

VERSION="1.2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=false
UNINSTALL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --uninstall) UNINSTALL=true ;;
    esac
done

log() { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

# --- Uninstall Logic ---
if [ "$UNINSTALL" = true ]; then
    log "Iniciando desinstalação..."
    shopt -s nullglob
    scripts=("$SCRIPT_DIR"/*.sh)
    shopt -u nullglob

    for script_path in "${scripts[@]}"; do
        script="$(basename "$script_path")"
        target="$BIN_DIR/$script"
        if [ -f "$target" ]; then
            if [ "$DRY_RUN" = false ]; then
                rm "$target"
                log "  ✓ Removido: $script"
            else
                echo "  [Dry-run] rm $target"
            fi
        fi
    done

    # Remove PATH entry from RC files
    SHELL_RC=""
    case "$SHELL" in
        */zsh) SHELL_RC="$HOME/.zshrc" ;;
        */bash) SHELL_RC="$HOME/.bashrc" ;;
        */fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    esac

    if [ -n "$SHELL_RC" ] && [ -f "$SHELL_RC" ]; then
        log "Limpando PATH de $SHELL_RC..."
        if [ "$DRY_RUN" = false ]; then
            # Simple removal of the line containing BIN_DIR
            sed -i "/$BIN_DIR/d" "$SHELL_RC"
        else
            echo "  [Dry-run] Removeria linha $BIN_DIR de $SHELL_RC"
        fi
    fi
    success "Desinstalação concluída!"
    exit 0
fi

# --- Installation Logic ---

# 1. Criar diretório se não existir
if [ ! -d "$BIN_DIR" ]; then
    log "Criando diretório $BIN_DIR..."
    $DRY_RUN || mkdir -p "$BIN_DIR"
fi

# 2. Copiar scripts (using symlinks for better UX)
log "Instalando scripts (Links Simbólicos) de $SCRIPT_DIR para $BIN_DIR..."
shopt -s nullglob
scripts=("$SCRIPT_DIR"/*.sh)
shopt -u nullglob

if [ ${#scripts[@]} -eq 0 ]; then
    error "Nenhum script .sh encontrado em $SCRIPT_DIR"
fi

for script_path in "${scripts[@]}"; do
    script="$(basename "$script_path")"
    if [ "$DRY_RUN" = false ]; then
        # Ensure script is executable in source
        chmod +x "$script_path"
        # Remove existing file/link first
        rm -f "$BIN_DIR/$script"
        ln -s "$script_path" "$BIN_DIR/$script"
        log "  ✓ $script"
    else
        echo "  [Dry-run] ln -s $script_path -> $BIN_DIR/$script"
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
        warn "Shell não reconhecido: $SHELL"
        warn "Adicione manually: export PATH=\"$BIN_DIR:\$PATH\""
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
            # Backup before editing
            cp "$SHELL_RC" "${SHELL_RC}.bak"
            if [[ "$SHELL" == *"fish"* ]]; then
                echo "fish_add_path $BIN_DIR" >> "$SHELL_RC"
            else
                echo -e "\n# Added by install-scripts.sh\nexport PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            fi
            success "PATH atualizado. Backup criado em ${SHELL_RC}.bak"
        else
            echo "  [Dry-run] Adicionaria PATH a $SHELL_RC após backup"
        fi
    fi
fi

success "Instalação concluída com sucesso!"
echo -e "Versão: $VERSION"
