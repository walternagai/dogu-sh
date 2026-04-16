#!/bin/bash
# update-all.sh — Atualiza pacotes do sistema e linguagens em um comando
# Uso: ./update-all.sh [opcoes]
# Opcoes:
#   --system       Atualiza pacotes do sistema (OS)
#   --npm          Atualiza pacotes globais npm
#   --pip          Atualiza pacotes pip globais
#   --cargo        Atualiza pacotes cargo (rustup + cargo install)
#   --brew          Atualiza Homebrew (macOS/Linux)
#   --all          Atualiza tudo (padrao)
#   --dry-run      Preview sem executar
#   --help         Mostra esta ajuda
#   --version      Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

UPDATE_SYSTEM=false
UPDATE_NPM=false
UPDATE_PIP=false
UPDATE_CARGO=false
UPDATE_BREW=false
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --system|-s) UPDATE_SYSTEM=true; shift ;;
        --npm|-n) UPDATE_NPM=true; shift ;;
        --pip|-p) UPDATE_PIP=true; shift ;;
        --cargo|-c) UPDATE_CARGO=true; shift ;;
        --brew|-b) UPDATE_BREW=true; shift ;;
        --all|-a) UPDATE_SYSTEM=true; UPDATE_NPM=true; UPDATE_PIP=true; UPDATE_CARGO=true; UPDATE_BREW=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  update-all.sh — Atualiza pacotes do sistema e linguagens"
            echo ""
            echo "  Uso: ./update-all.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --system       Atualiza pacotes do sistema (OS)"
            echo "    --npm          Atualiza pacotes globais npm"
            echo "    --pip          Atualiza pacotes pip globais"
            echo "    --cargo        Atualiza rustup + cargo install"
            echo "    --brew         Atualiza Homebrew (macOS/Linux)"
            echo "    --all          Atualiza tudo (padrao se nenhum flag)"
            echo "    --dry-run      Preview sem executar"
            echo "    --help         Mostra esta ajuda"
            echo "    --version      Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./update-all.sh --all"
            echo "    ./update-all.sh --system"
            echo "    ./update-all.sh --system --npm --pip"
            echo "    ./update-all.sh --all --dry-run"
            echo ""
            exit 0
            ;;
        --version|-v) echo "update-all.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if ! $UPDATE_SYSTEM && ! $UPDATE_NPM && ! $UPDATE_PIP && ! $UPDATE_CARGO && ! $UPDATE_BREW; then
    UPDATE_SYSTEM=true
    UPDATE_NPM=true
    UPDATE_PIP=true
    UPDATE_CARGO=true
    UPDATE_BREW=true
fi

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null || true
        echo "${ID:-unknown}"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

run_or_dry() {
    local label="$1"
    shift
    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-50s\n" "$label"
        return 0
    fi
    local errout
    errout=$(mktemp)
    if "$@" 2>"$errout"; then
        printf "  ${GREEN}✓${RESET} %-50s\n" "$label"
        rm -f "$errout"
    else
        printf "  ${RED}✗${RESET} %-50s ${DIM}(falha)${RESET}\n" "$label"
        if [ -s "$errout" ]; then
            head -3 "$errout" | while IFS= read -r line; do
                echo -e "    ${DIM}$line${RESET}"
            done
        fi
        rm -f "$errout"
    fi
}

DISTRO=$(detect_distro)

echo ""
echo -e "  ${BOLD}Update All${RESET}  ${DIM}v$VERSION${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo -e "  Distro: ${CYAN}$DISTRO${RESET}"
echo ""

updated_count=0
skipped_count=0

# =============================================
# Sistema
# =============================================

if $UPDATE_SYSTEM; then
    echo -e "  ${BOLD}── Sistema (OS) ──${RESET}"
    echo ""

    case "$DISTRO" in
        debian|ubuntu|linuxmint|pop*|elementary|kali)
            run_or_dry "apt update" sudo apt-get update -y
            run_or_dry "apt upgrade" sudo apt-get upgrade -y
            run_or_dry "apt autoremove" sudo apt-get autoremove -y
            run_or_dry "apt clean" sudo apt-get clean -y
            updated_count=$((updated_count + 4))
            ;;
        fedora|rhel|centos|rocky|alma*)
            run_or_dry "dnf upgrade" sudo dnf upgrade -y
            run_or_dry "dnf autoremove" sudo dnf autoremove -y
            run_or_dry "dnf clean" sudo dnf clean all
            updated_count=$((updated_count + 3))
            ;;
        arch|manjaro|endeavouros|garuda*)
            run_or_dry "pacman -Syu" sudo pacman -Syu --noconfirm
            run_or_dry "pacman -Sc" sudo pacman -Sc --noconfirm
            updated_count=$((updated_count + 2))
            ;;
        *)
            echo -e "  ${DIM}Distro '$DISTRO' nao suportada para atualizacao automatica.${RESET}"
            skipped_count=$((skipped_count + 1))
            ;;
    esac

    echo ""
fi

# =============================================
# npm
# =============================================

if $UPDATE_NPM; then
    echo -e "  ${BOLD}── npm (Node.js) ──${RESET}"
    echo ""

    if command -v npm &>/dev/null; then
        run_or_dry "npm update -g" npm update -g
        updated_count=$((updated_count + 1))

        npm_list=$(npm ls -g --depth=0 2>/dev/null | grep -c '^[├└]' || echo 0)
        echo -e "  ${DIM}$npm_list pacote(s) global(is) instalado(s)${RESET}"
    else
        echo -e "  ${DIM}npm nao encontrado. Pulando...${RESET}"
        skipped_count=$((skipped_count + 1))
    fi

    echo ""
fi

# =============================================
# pip
# =============================================

if $UPDATE_PIP; then
    echo -e "  ${BOLD}── pip (Python) ──${RESET}"
    echo ""

    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        PIP_CMD="pip3"
        command -v pip3 &>/dev/null || PIP_CMD="pip"

        run_or_dry "pip upgrade self" $PIP_CMD install --upgrade pip 2>/dev/null || true

        if ! $DRY_RUN; then
            outdated=$($PIP_CMD list --outdated --format=json 2>/dev/null | python3 -c "import sys,json; pkgs=json.load(sys.stdin); print(' '.join(p['name'] for p in pkgs))" 2>/dev/null || echo "")
            if [ -n "$outdated" ]; then
                count=$(echo "$outdated" | wc -w | tr -d ' ')
                echo -e "  ${YELLOW}$count${RESET} pacote(s) desatualizado(s)"
                run_or_dry "pip upgrade packages ($count)" $PIP_CMD install --upgrade $outdated 2>/dev/null
                updated_count=$((updated_count + 2))
            else
                echo -e "  ${GREEN}✓${RESET} Todos os pacotes pip estao atualizados"
                updated_count=$((updated_count + 1))
            fi
        else
            echo -e "  ${DIM}[dry-run] Verificaria pacotes pip desatualizados${RESET}"
            updated_count=$((updated_count + 1))
        fi
    else
        echo -e "  ${DIM}pip/pip3 nao encontrado. Pulando...${RESET}"
        skipped_count=$((skipped_count + 1))
    fi

    echo ""
fi

# =============================================
# cargo
# =============================================

if $UPDATE_CARGO; then
    echo -e "  ${BOLD}── cargo (Rust) ──${RESET}"
    echo ""

    if command -v rustup &>/dev/null; then
        run_or_dry "rustup update" rustup update -y
        updated_count=$((updated_count + 1))
    else
        echo -e "  ${DIM}rustup nao encontrado. Pulando Rust toolchain...${RESET}"
        skipped_count=$((skipped_count + 1))
    fi

    if command -v cargo &>/dev/null; then
        if command -v cargo-install-update &>/dev/null || cargo install cargo-update &>/dev/null; then
            run_or_dry "cargo install-update -a" cargo install-update -a 2>/dev/null
            updated_count=$((updated_count + 1))
        else
            echo -e "  ${DIM}cargo-install-update nao disponivel. Pulando cargo updates...${RESET}"
        fi
    else
        echo -e "  ${DIM}cargo nao encontrado. Pulando...${RESET}"
        skipped_count=$((skipped_count + 1))
    fi

    echo ""
fi

# =============================================
# brew
# =============================================

if $UPDATE_BREW; then
    echo -e "  ${BOLD}── Homebrew ──${RESET}"
    echo ""

    if command -v brew &>/dev/null; then
        run_or_dry "brew update" brew update
        run_or_dry "brew upgrade" brew upgrade
        run_or_dry "brew cleanup" brew cleanup
        updated_count=$((updated_count + 3))
    else
        echo -e "  ${DIM}brew nao encontrado. Pulando...${RESET}"
        skipped_count=$((skipped_count + 1))
    fi

    echo ""
fi

# =============================================
# Resumo
# =============================================

echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓${RESET} ${BOLD}Atualizacao concluida${RESET}"

if $DRY_RUN; then
    echo -e "  ${DIM}Execute sem --dry-run para aplicar as atualizacoes.${RESET}"
fi

if [ "$skipped_count" -gt 0 ]; then
    echo -e "  ${DIM}$skipped_count gerenciador(es) pulado(s) (nao instalado(s))${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""