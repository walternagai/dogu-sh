#!/bin/bash
# clean-cache.sh — Delete temp files and app caches (Linux)
# Uso: ./clean-cache.sh
# Opcoes:
#   --dry-run       Preview sem apagar nada
#   --all           Limpa todos os caches sem confirmacao
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "bc" "$INSTALLER bc"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
CLEAN_ALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --all|-a)
            CLEAN_ALL=true
            shift
            ;;
        --help|-h)
            echo ""
            echo "  clean-cache.sh — Apaga arquivos temporarios e cache de aplicativos"
            echo ""
            echo "  Uso: ./clean-cache.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem apagar nada"
            echo "    --all         Limpa tudo sem pedir confirmacao"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Areas limpas:"
            echo "    Cache de usuario (~/.cache)"
            echo "    Arquivos temporarios (/tmp, ~/.local/share/Trash)"
            echo "    Cache de pacotes (apt, pip, npm, yarn, cargo, go, mvn, gradle)"
            echo "    Cache de navegadores (Chrome, Firefox)"
            echo "    Cache de thumbnails"
            echo "    Cache de apps comuns (Spotify, Discord, Slack, Obsidian, VS Code)"
            echo ""
            echo "  Exemplos:"
            echo "    ./clean-cache.sh --dry-run"
            echo "    ./clean-cache.sh --all"
            echo ""
            exit 0
            ;;
        --version|-v)
            echo "clean-cache.sh $VERSION"
            exit 0
            ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 1
            ;;
    esac
done

TMPWORK=$(mktemp -d)
trap 'rm -rf "$TMPWORK"' EXIT

total_freed=0

human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} B"
    fi
}

get_dir_size() {
    local dir="$1"
    if [ -d "$dir" ]; then
        du -sb "$dir" 2>/dev/null | tail -1 | awk '{print $1}' | tr -d '[:space:]' || echo 0
    else
        echo 0
    fi
}

clean_dir() {
    local label="$1"
    local dir="$2"
    local description="${3:-}"
    local only_owner="${4:-false}"

    if [ ! -d "$dir" ]; then
        return
    fi

    local size
    size=$(get_dir_size "$dir")
    size=$(echo "$size" | tr -d '[:space:]')

    if ! [[ "$size" =~ ^[0-9]+$ ]]; then
        return
    fi

    if [ "$size" -eq 0 ]; then
        return
    fi

    local size_str
    size_str=$(human_size "$size")

    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-36s ${RED}%s${RESET}\n" "$label" "$size_str"
        if [ -n "$description" ]; then
            echo -e "             ${DIM}$description${RESET}"
        fi
        total_freed=$((total_freed + size))
        return
    fi

    if ! $CLEAN_ALL; then
        printf "  Limpar ${CYAN}%s${RESET} (${RED}%s${RESET})? [s/N]: " "$label" "$size_str"
        local confirm
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS]) ;;
            *) return ;;
        esac
    fi

    if $only_owner; then
        find "$dir" -maxdepth 1 -user "$(id -u)" -not -name 'systemd-private-*' -exec rm -rf {} + 2>/dev/null || true
    else
        rm -rf "${dir:?}"/* 2>/dev/null || true
    fi
    printf "  ${GREEN}✓${RESET} %-36s ${GREEN}%s liberados${RESET}\n" "$label" "$size_str"
    total_freed=$((total_freed + size))
}

clean_files_pattern() {
    local label="$1"
    local dir="$2"
    local pattern="${3:-*}"
    local description="${4:-}"

    if [ ! -d "$dir" ]; then
        return
    fi

    local size=0
    while IFS= read -r -d '' f; do
        local fsize
        fsize=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        fsize=$(echo "$fsize" | tr -d '[:space:]')
        [[ "$fsize" =~ ^[0-9]+$ ]] && size=$((size + fsize))
    done < <(find "$dir" -maxdepth 1 -name "$pattern" -type f -print0 2>/dev/null)

    if [ "$size" -eq 0 ]; then
        return
    fi

    local size_str
    size_str=$(human_size "$size")

    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-36s ${RED}%s${RESET}\n" "$label" "$size_str"
        if [ -n "$description" ]; then
            echo -e "             ${DIM}$description${RESET}"
        fi
        total_freed=$((total_freed + size))
        return
    fi

    if ! $CLEAN_ALL; then
        printf "  Limpar ${CYAN}%s${RESET} (${RED}%s${RESET})? [s/N]: " "$label" "$size_str"
        local confirm
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS]) ;;
            *) return ;;
        esac
    fi

    find "$dir" -maxdepth 1 -name "$pattern" -type f -delete 2>/dev/null || true
    printf "  ${GREEN}✓${RESET} %-36s ${GREEN}%s liberados${RESET}\n" "$label" "$size_str"
    total_freed=$((total_freed + size))
}

echo ""
echo -e "  ${BOLD}Limpeza de cache e temporarios${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Nada sera apagado"
fi

echo ""

# =============================================
# Cache de usuario
# =============================================

echo -e "  ${BOLD}── Cache de Usuario ──${RESET}"
echo ""

clean_dir "Cache geral (~/.cache)" "$HOME/.cache" "Cache recriado automaticamente pelos apps"

# =============================================
# Thumbnails
# =============================================

echo ""
echo -e "  ${BOLD}── Thumbnails ──${RESET}"
echo ""

for thumb_dir in "$HOME/.cache/thumbnails/large" "$HOME/.cache/thumbnails/normal" "$HOME/.cache/thumbnails/huge" "$HOME/.thumbnails/large" "$HOME/.thumbnails/normal"; do
    if [ -d "$thumb_dir" ]; then
        base=$(basename "$(dirname "$thumb_dir")")
        sub=$(basename "$thumb_dir")
        clean_dir "Thumbnails ($sub)" "$thumb_dir" "Preview de imagens, recriado ao abrir pastas"
    fi
done

# =============================================
# Lixeira
# =============================================

echo ""
echo -e "  ${BOLD}── Lixeira ──${RESET}"
echo ""

clean_dir "Lixeira (Trash/files)" "$HOME/.local/share/Trash/files" "Arquivos deletados, restaure antes de limpar"
clean_dir "Lixeira (Trash/info)" "$HOME/.local/share/Trash/info" "Metadados da lixeira"

# =============================================
# /tmp do usuario
# =============================================

echo ""
echo -e "  ${BOLD}── Temporarios ──${RESET}"
echo ""

for user_tmp in /tmp/user-*; do
    if [ -d "$user_tmp" ] && [ -O "$user_tmp" ]; then
        uid=$(basename "$user_tmp" | sed 's/user-//')
        clean_dir "Sessao temp ($uid)" "$user_tmp" "Arquivos temporarios da sessao — alguns podem estar em uso"
    fi
done

tmp_user_files=0
tmp_user_size=0
while IFS= read -r -d '' f; do
    if [ -O "$f" ]; then
        fsize=$(stat -c '%s' "$f" 2>/dev/null || echo 0)
        fsize=$(echo "$fsize" | tr -d '[:space:]')
        [[ "$fsize" =~ ^[0-9]+$ ]] && tmp_user_size=$((tmp_user_size + fsize))
        tmp_user_files=$((tmp_user_files + 1))
    fi
done < <(find /tmp -maxdepth 1 -type f -print0 2>/dev/null)

if [ "$tmp_user_files" -gt 0 ] && [ "$tmp_user_size" -gt 0 ]; then
    tmp_size_str=$(human_size "$tmp_user_size")

    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-36s ${RED}%s${RESET}\n" "Arquivos soltos em /tmp ($tmp_user_files)" "$tmp_size_str"
        echo -e "             ${DIM}Apenas arquivos do usuario atual${RESET}"
        total_freed=$((total_freed + tmp_user_size))
    else
        if ! $CLEAN_ALL; then
            printf "  Limpar ${CYAN}Arquivos soltos em /tmp${RESET} (${RED}%s${RESET})? [s/N]: " "$tmp_size_str"
            read -r confirm < /dev/tty 2>/dev/null || confirm="n"
            case "$confirm" in
                [sS]) ;;
                *) tmp_user_size=0 ;;
            esac
        fi
        if [ "$tmp_user_size" -gt 0 ]; then
            find /tmp -maxdepth 1 -type f -user "$(id -u)" -delete 2>/dev/null || true
            printf "  ${GREEN}✓${RESET} %-36s ${GREEN}%s liberados${RESET}\n" "Arquivos soltos em /tmp" "$tmp_size_str"
            total_freed=$((total_freed + tmp_user_size))
        fi
    fi
fi

# =============================================
# Navegadores
# =============================================

echo ""
echo -e "  ${BOLD}── Navegadores ──${RESET}"
echo ""

for profile_dir in "$HOME/.cache/google-chrome" "$HOME/.cache/chromium" "$HOME/.cache/google-chrome-unstable"; do
    if [ -d "$profile_dir" ]; then
        browser_name=$(basename "$profile_dir" | sed 's/-unstable//')
        for cache_sub in "$profile_dir"/Default/Cache "$profile_dir"/Default/Code\ Cache "$profile_dir"/Default/GPUCache "$profile_dir"/Default/Service\ Worker/CacheStorage; do
            if [ -d "$cache_sub" ]; then
                sub_name=$(echo "$cache_sub" | sed "s|$profile_dir/||" | sed 's|Default/||')
                clean_dir "$browser_name ($sub_name)" "$cache_sub" "Cache de pagina, recriado ao navegar"
            fi
        done
    fi
done

for profile_dir in "$HOME/.cache/mozilla/firefox"; do
    if [ -d "$profile_dir" ]; then
        for cache_sub in "$profile_dir"/*/cache2; do
            if [ -d "$cache_sub" ]; then
                profile_hash=$(basename "$(dirname "$cache_sub")")
                clean_dir "Firefox ($profile_hash)" "$cache_sub" "Cache de pagina, recriado ao navegar"
            fi
        done
    fi
done

# =============================================
# Gerenciadores de pacotes
# =============================================

echo ""
echo -e "  ${BOLD}── Gerenciadores de Pacotes ──${RESET}"
echo ""

if command -v apt-get &>/dev/null; then
    apt_cache_size=$(get_dir_size "/var/cache/apt/archives")
    apt_cache_size=$(echo "$apt_cache_size" | tr -d '[:space:]')
    if [[ "$apt_cache_size" =~ ^[0-9]+$ ]] && [ "$apt_cache_size" -gt 0 ]; then
        size_str=$(human_size "$apt_cache_size")
        if $DRY_RUN; then
            printf "  ${DIM}[dry-run]${RESET} %-36s ${RED}%s${RESET}\n" "APT cache" "$size_str"
            echo -e "             ${DIM}Requer sudo: sudo apt clean${RESET}"
        else
            if $CLEAN_ALL; then
                sudo apt-get clean -y 2>/dev/null && \
                    printf "  ${GREEN}✓${RESET} %-36s ${GREEN}%s liberados${RESET}\n" "APT cache" "$size_str" || \
                    echo -e "  ${DIM}Sem permissao para limpar APT cache${RESET}"
            else
                printf "  Limpar ${CYAN}APT cache${RESET} (${RED}%s${RESET})? [s/N]: " "$size_str"
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS])
                        sudo apt-get clean -y 2>/dev/null && \
                            printf "  ${GREEN}✓${RESET} %-36s ${GREEN}%s liberados${RESET}\n" "APT cache" "$size_str" || \
                            echo -e "  ${RED}Falha ao limpar APT cache${RESET}"
                        ;;
                esac
            fi
        fi
        total_freed=$((total_freed + apt_cache_size))
    fi
fi

clean_dir "Pip cache (~/.cache/pip)" "$HOME/.cache/pip" "Cache de downloads Python"
clean_dir "npm cache (~/.npm)" "$HOME/.npm" "Cache de pacotes Node.js"
clean_dir "yarn cache (~/.cache/yarn)" "$HOME/.cache/yarn" "Cache de pacotes Yarn"
clean_dir "Cargo cache (~/.cargo/registry)" "$HOME/.cargo/registry" "Cache de crates Rust — re-downloaded ao compilar"
clean_dir "Go module cache (~/.cache/go-build)" "$HOME/.cache/go-build" "Cache de build Go"
clean_dir "Go module cache (~/.go/pkg/mod)" "$HOME/.go/pkg/mod" "Modulos Go baixados"
clean_dir "Maven cache (~/.m2/repository)" "$HOME/.m2/repository" "Dependencias Java Maven — re-downloaded ao buildar"
clean_dir "Gradle cache (~/.gradle/caches)" "$HOME/.gradle/caches" "Cache de builds Gradle"
clean_dir "pnpm store (~/.local/share/pnpm)" "$HOME/.local/share/pnpm" "Cache de pacotes pnpm"
clean_dir "Bun cache (~/.bun)" "$HOME/.bun" "Cache de pacotes Bun"

# =============================================
# Aplicativos comuns
# =============================================

echo ""
echo -e "  ${BOLD}── Aplicativos ──${RESET}"
echo ""

clean_dir "Spotify cache (~/.cache/spotify)" "$HOME/.cache/spotify" "Cache de streaming, re-criado ao ouvir"
clean_dir "Discord cache (~/.cache/discord)" "$HOME/.cache/discord" "Cache de midia e assets"
clean_dir "Discord cache (~/.config/discord/Cache)" "$HOME/.config/discord/Cache" "Cache de midia do Discord"
clean_dir "Slack cache (~/.cache/slack)" "$HOME/.cache/slack" "Cache de midia e assets"
clean_dir "Obsidian cache (~/.cache/obsidian)" "$HOME/.cache/obsidian" "Cache do Obsidian"
clean_dir "VS Code cache (~/.cache/vscode)" "$HOME/.cache/vscode" "Cache de extensions e data"
clean_dir "VS Code server (~/.vscode-server)" "$HOME/.vscode-server" "Cache de Remote SSH — re-downloaded ao conectar"
clean_dir "Codeium cache (~/.cache/codeium)" "$HOME/.cache/codeium" "Cache de AI assistant"
clean_dir "Codium cache (~/.cache/codium)" "$HOME/.cache/codium" "Cache do VSCodium"
clean_dir "Steam cache (~/.cache/steam)" "$HOME/.cache/steam" "Cache de assets e HTML"
clean_dir "Steam compatdata (~/.steam/steam/steamapps/compatdata)" "$HOME/.steam/steam/steamapps/compatdata" "Dados de Proton — cuidado, pode afetar jogos"
clean_dir "Lutris cache (~/.cache/lutris)" "$HOME/.cache/lutris" "Cache de assets de jogos"
clean_dir "Flatpak cache (~/.local/share/flatpak/repo)" "$HOME/.local/share/flatpak/repo" "Cache de downloads Flatpak"
clean_dir "Snap cache (~/.snap)" "$HOME/.snap" "Cache de pacotes Snap"
clean_dir "Docker build cache (~/.cache/docker)" "$HOME/.cache/docker" "Cache de builds Docker — requer docker system prune"
clean_dir "Electron apps cache (~/.config/Electron)" "$HOME/.config/Electron" "Cache de apps Electron"

# =============================================
# Systemd journal
# =============================================

echo ""
echo -e "  ${BOLD}── Logs do Sistema ──${RESET}"
echo ""

if command -v journalctl &>/dev/null; then
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGT]' | tail -1)
    if [ -n "$journal_size" ]; then
        if $DRY_RUN; then
            printf "  ${DIM}[dry-run]${RESET} %-36s ${RED}%s${RESET}\n" "Systemd journal" "$journal_size"
            echo -e "             ${DIM}Requer sudo: sudo journalctl --vacuum-time=7d${RESET}"
        else
            if $CLEAN_ALL; then
                sudo journalctl --vacuum-time=7d 2>/dev/null || \
                    echo -e "  ${DIM}Sem permissao para limpar journal${RESET}"
            else
                printf "  Limpar ${CYAN}journal logs${RESET} (manter 7 dias)? [s/N]: "
                read -r confirm < /dev/tty 2>/dev/null || confirm="n"
                case "$confirm" in
                    [sS])
                        sudo journalctl --vacuum-time=7d 2>/dev/null || \
                            echo -e "  ${RED}Falha ao limpar journal${RESET}"
                        ;;
                esac
            fi
        fi
    fi
fi

# =============================================
# Resumo
# =============================================

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo:${RESET}"

total_str=$(human_size "$total_freed")

if $DRY_RUN; then
    echo -e "  Espaco que seria liberado:  ${RED}${BOLD}$total_str${RESET}"
    echo -e "  ${DIM}Execute sem --dry-run para limpar.${RESET}"
else
    echo -e "  Espaco liberado:            ${GREEN}${BOLD}$total_str${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""
echo -e "  ${DIM}Dica: caches sao recriados automaticamente conforme os apps forem usados.${RESET}"
echo -e "  ${DIM}Alguns apps podem ficar mais lentos temporariamente apos a limpeza.${RESET}"
echo ""