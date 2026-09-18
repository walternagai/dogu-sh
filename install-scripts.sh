#!/bin/bash
# install-scripts.sh — Instala scripts no ~/.local/bin e configura o PATH (Linux/macOS)
# Uso: ./install-scripts.sh [--dry-run | --uninstall]

set -euo pipefail

# Cores
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

readonly VERSION="1.3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=false
UNINSTALL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --help|-h)
            echo ""
            echo "  install-scripts.sh — Instala scripts no ~/.local/bin e configura o PATH"
            echo ""
            echo "  Uso: ./install-scripts.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run       Simula a instalacao sem alterar arquivos"
            echo "    --uninstall     Remove scripts e limpa PATH"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "install-scripts.sh $VERSION"; exit 0 ;;
        --dry-run) DRY_RUN=true ;;
        --uninstall) UNINSTALL=true ;;
        -*)
            echo -e "${RED}[ERROR]${RESET} Unknown option: $arg" >&2; exit 2
            ;;
    esac
done

log() { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
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
        if [ -f "$target" ] || [ -L "$target" ]; then
            if [ "$DRY_RUN" = false ]; then
                rm -f "$target"
                log "  ✓ Removido: $script"
            else
                echo "  [Dry-run] rm $target"
            fi
        fi
    done

    # Remover dispatcher 'dogu' e manifesto
    for extra in dogu dogu.json; do
        target="$BIN_DIR/$extra"
        if [ -f "$target" ] || [ -L "$target" ]; then
            if [ "$DRY_RUN" = false ]; then
                rm -f "$target"
                log "  ✓ Removido: $extra"
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

# 3. Instalar dispatcher 'dogu' (sem extensão .sh)
DOGU_DISPATCHER="$SCRIPT_DIR/dogu"
if [ -f "$DOGU_DISPATCHER" ]; then
    log "Instalando dispatcher 'dogu'..."
    if [ "$DRY_RUN" = false ]; then
        chmod +x "$DOGU_DISPATCHER"
        rm -f "$BIN_DIR/dogu"
        ln -s "$DOGU_DISPATCHER" "$BIN_DIR/dogu"
        log "  ✓ dogu"
    else
        echo "  [Dry-run] ln -s $DOGU_DISPATCHER -> $BIN_DIR/dogu"
    fi
fi

# 4. Copiar dogu.json para ~/.local/bin (manifesto)
DOGU_MANIFEST="$SCRIPT_DIR/dogu.json"
if [ -f "$DOGU_MANIFEST" ]; then
    log "Copiando manifesto dogu.json..."
    if [ "$DRY_RUN" = false ]; then
        cp "$DOGU_MANIFEST" "$BIN_DIR/dogu.json"
        log "  ✓ dogu.json"
    else
        echo "  [Dry-run] cp $DOGU_MANIFEST -> $BIN_DIR/dogu.json"
    fi
fi

# 5. Configurar PATH
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
