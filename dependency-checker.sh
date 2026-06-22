#!/bin/bash
# dependency-checker.sh — Verifica dependencias externas do projeto dogu-sh (Linux)
# Uso: ./dependency-checker.sh [opcoes]
# Opcoes:
#   --fix|-f         Tenta instalar dependencias faltantes
#   --all|-a         Inclui dependencias escaneadas dos scripts
#   --help|-h        Mostra esta ajuda
#   --version|-V     Mostra versao

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

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
fi

FIX_MODE=false
ALL_MODE=false

declare -A DEPS
DEPS["curl"]="curl"
DEPS["jq"]="jq"
DEPS["bc"]="bc"
DEPS["whois"]="whois"
DEPS["fzf"]="fzf"
DEPS["rsync"]="rsync"
DEPS["pandoc"]="pandoc"
DEPS["ffmpeg"]="ffmpeg"
DEPS["tesseract"]="tesseract-ocr"
DEPS["docker"]="docker.io"
DEPS["convert"]="imagemagick"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix|-f) FIX_MODE=true; shift ;;
        --all|-a) ALL_MODE=true; shift ;;
        --help|-h)
            echo ""
            echo "  dependency-checker.sh — Verifica dependencias externas do projeto dogu-sh"
            echo ""
            echo "  Uso: ./dependency-checker.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --fix|-f         Tenta instalar dependencias faltantes"
            echo "    --all|-a         Inclui dependencias escaneadas dos scripts"
            echo "    --help|-h        Mostra esta ajuda"
            echo "    --version|-V     Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./dependency-checker.sh"
            echo "    ./dependency-checker.sh --fix"
            echo "    ./dependency-checker.sh --all --fix"
            echo ""
            exit 0
            ;;
        --version|-V) echo "dependency-checker.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if $ALL_MODE; then
    while IFS= read -r tool; do
        [ -n "$tool" ] && DEPS["$tool"]="$tool"
    done < <(grep -rhoP 'check_and_install\s+"?\K[a-zA-Z0-9_.-]+' "$SCRIPT_DIR"/*.sh 2>/dev/null | sort -u || true)
fi

echo ""
echo -e "  ${BOLD}── Verificacao de Dependencias ──${RESET}"
echo ""

missing=()
for tool in "${!DEPS[@]}"; do
    pkg="${DEPS[$tool]}"
    printf "  %-20s" "$tool..."
    if command -v "$tool" &>/dev/null; then
        echo -e " ${GREEN}✓${RESET}"
    else
        echo -e " ${RED}✗${RESET}"
        missing+=("$tool:$pkg")
    fi
done

echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
total=${#DEPS[@]}
found=$((total - ${#missing[@]}))
echo -e "  ${BOLD}Total:${RESET} ${total}  ${GREEN}Instalados:${RESET} ${found}  ${RED}Ausentes:${RESET} ${#missing[@]}"
echo ""

if [ ${#missing[@]} -eq 0 ]; then
    success "Todas as dependencias estao instaladas."
    echo ""
    exit 0
fi

if $FIX_MODE; then
    echo -e "  ${YELLOW}Deseja instalar as ${#missing[@]} dependencias faltantes?${RESET}"
    read -r -p "  Confirmar? [s/N] " CONFIRM
    echo ""
    if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
        for entry in "${missing[@]}"; do
            tool="${entry%%:*}"
            pkg="${entry#*:}"
            echo -e "  ${CYAN}▶ Instalando ${tool} (${pkg})...${RESET}"
            if [ -n "${INSTALLER:-}" ]; then
                if $INSTALLER "$pkg" 2>/dev/null; then
                    echo -e "  ${GREEN}  ✓ ${tool} instalado${RESET}"
                else
                    warn "  Falha ao instalar ${tool}. Tente manualmente."
                fi
            else
                warn "  Instalador nao disponivel. Instale '${pkg}' manualmente."
            fi
        done
        echo ""
        success "Processo de instalacao concluido."
    else
        echo -e "  ${DIM}Instalacao cancelada.${RESET}"
    fi
    echo ""
else
    echo -e "  ${YELLOW}Dica: Use --fix para tentar instalar automaticamente.${RESET}"
    echo ""
fi
