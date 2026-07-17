#!/bin/bash
# nerd-font-install.sh — Baixa e instala fontes Nerd Fonts (Linux/macOS)
# Uso: ./nerd-font-install.sh [opcoes]
# Opcoes:
#   --list                    Lista familias de fontes disponiveis
#   -f, --font FONT           Instala fonte(s) especifica(s) (ex: --font FiraCode)
#   --all                     Instala todas as fontes disponiveis
#   -o, --install-dir DIR     Diretorio de instalacao (padrao: ~/.local/share/fonts)
#   --system                  Instala em /usr/local/share/fonts (requer sudo)
#   -n, --dry-run             Simula sem baixar ou instalar
#   --help                    Mostra esta ajuda
#   --version                 Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "curl"     "$INSTALLER" "curl"
    check_and_install "unzip"    "$INSTALLER" "unzip"
    check_and_install "fc-cache" "$INSTALLER" "fontconfig"
fi

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

# ─── Lista de fontes ─────────────────────────────────────────────────────────

readonly ALL_FONTS=(
    "3270" "Agave" "AnonymousPro" "Arimo" "AurulentSansMono"
    "BigBlueTerminal" "CascadiaCode" "CodeNewRoman" "ComicShannsMono"
    "CommitMono" "Cousine" "D2Coding" "DaddyTimeMono" "DejaVuSansMono"
    "FantasqueSansMono" "FiraCode" "FiraMono" "GeistMono" "Go-Mono"
    "Gohu" "Hack" "Hasklig" "HeavyData" "Hermit" "iA-Writer"
    "IBMPlexMono" "Inconsolata" "InconsolataGo" "InconsolataLGC"
    "IntelOneMono" "Iosevka" "IosevkaTerm" "IosevkaTermSlab"
    "JetBrainsMono" "KodeMono" "Lekton" "LiberationMono" "Lilex"
    "MartianMono" "Meslo" "Monaspace" "Monofur" "Mononoki" "MPlus"
    "NerdFontsSymbolsOnly" "Noto" "OpenDyslexic" "Overpass"
    "ProFont" "ProggyClean" "Recursive" "RobotoMono" "ShareTechMono"
    "SourceCodePro" "SpaceMono" "Terminus" "Tinos" "UbuntuMono"
    "UbuntuSans" "VictorMono" "ZedMono"
)

readonly NERD_FONTS_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download"

# ─── Variaveis globais ──────────────────────────────────────────────────────

INSTALL_DIR=""
SYSTEM_INSTALL=false
DRY_RUN=false
DO_LIST=false
DO_ALL=false
declare -a SELECTED_FONTS=()

# ─── Temporario global ──────────────────────────────────────────────────────

TMPDIR_WORK=""
# shellcheck disable=SC2317 # chamada via trap EXIT
trap_cleanup() {
    [[ -n "$TMPDIR_WORK" && -d "$TMPDIR_WORK" ]] && rm -rf "$TMPDIR_WORK"
}

# ─── Utilitarios ────────────────────────────────────────────────────────────

get_default_install_dir() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "${HOME}/Library/Fonts"
    else
        echo "${HOME}/.local/share/fonts"
    fi
}

normalize_font_name() {
    local name="$1"
    name=$(echo "$name" | xargs)           # trim
    echo "$name"
}

is_font_installed() {
    local font_name="$1"
    local dir="${2:-$INSTALL_DIR}"
    local font_dir="${dir}/${font_name}"

    [[ ! -d "$font_dir" ]] && return 1

    # Checa se ha pelo menos um .ttf ou .otf
    local file_count
    file_count=$(find "$font_dir" -maxdepth 1 \( -name '*.ttf' -o -name '*.otf' \) 2>/dev/null | head -5 | wc -l)
    [[ "$file_count" -gt 0 ]]
}

# ─── Listagem ───────────────────────────────────────────────────────────────

print_fonts() {
    echo ""
    echo -e "  ${BOLD}Familias Nerd Fonts disponiveis:${RESET}"
    echo ""

    local cols=4
    local term_width
    term_width=$(tput cols 2>/dev/null || echo 80)
    [[ $term_width -lt 80 ]] && cols=3
    [[ $term_width -lt 60 ]] && cols=2
    [[ $term_width -lt 40 ]] && cols=1

    local total=${#ALL_FONTS[@]}
    local rows=$(( (total + cols - 1) / cols ))

    for ((r=0; r<rows; r++)); do
        for ((c=0; c<cols; c++)); do
            local idx=$(( r + c * rows ))
            [[ $idx -ge $total ]] && break

            local font="${ALL_FONTS[$idx]}"
            local mark=" "
            if is_font_installed "$font"; then
                mark="${GREEN}✓${RESET}"
            fi

            if [[ $c -lt $((cols - 1)) ]]; then
                printf "  ${mark}  ${BOLD}%-22s${RESET}" "${font}"
            else
                printf "  ${mark}  ${BOLD}%s${RESET}" "${font}"
            fi
        done
        echo ""
    done

    echo ""
    echo -e "  ${DIM}Legenda: ${GREEN}✓${RESET}${DIM} instalada  |  ${total} familias disponiveis${RESET}"
    echo ""
    echo -e "  ${DIM}Use --font <nome> para instalar ou --all para todas${RESET}"
    echo ""
}

# ─── Validacao ──────────────────────────────────────────────────────────────

validate_font() {
    local font_name
    font_name=$(normalize_font_name "$1")
    for f in "${ALL_FONTS[@]}"; do
        if [[ "$f" == "$font_name" ]]; then
            echo "$font_name"
            return 0
        fi
    done
    return 1
}

# ─── Instalacao ─────────────────────────────────────────────────────────────

install_font() {
    local font_name="$1"
    local dest_dir="${INSTALL_DIR}/${font_name}"

    if is_font_installed "$font_name"; then
        log "Fonte ${CYAN}${font_name}${RESET} ja instalada em ${DIM}${dest_dir}${RESET}"
        return 0
    fi

    local font_url="${NERD_FONTS_URL}/${font_name}.zip"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${DIM}[Dry-run] curl -L -o \"${font_name}.zip\" ${font_url}${RESET}"
        echo -e "  ${DIM}[Dry-run] unzip -q -> ${dest_dir}/${RESET}"
        return 0
    fi

    log "Baixando ${CYAN}${font_name}${RESET}..."
    echo -e "  ${DIM}Fonte: ${font_url}${RESET}"

    local zip_path="${TMPDIR_WORK}/${font_name}.zip"

    if ! curl -sL -o "$zip_path" "$font_url"; then
        warn "Falha ao baixar ${font_name}. Verifique o nome ou conexao."
        return 1
    fi

    # Checa se o zip e valido (curl pode baixar pagina 404)
    if ! unzip -tq "$zip_path" &>/dev/null; then
        warn "Arquivo invalido para ${font_name}. Nome talvez nao corresponda ao release."
        return 1
    fi

    log "Extraindo ${CYAN}${font_name}${RESET} para ${DIM}${dest_dir}${RESET}..."
    mkdir -p "$dest_dir"

    if ! unzip -qo "$zip_path" -d "$dest_dir"; then
        warn "Falha ao extrair ${font_name}."
        rm -rf "$dest_dir"
        return 1
    fi

    # Remove lixos que vem no zip (README, LICENSE, etc)
    rm -f "${dest_dir}"/*.md "${dest_dir}"/LICENSE "${dest_dir}"/readme* 2>/dev/null || true

    local count
    count=$(find "$dest_dir" -maxdepth 1 \( -name '*.ttf' -o -name '*.otf' \) 2>/dev/null | wc -l)
    success "${font_name}: ${count} fontes instaladas em ${DIM}${dest_dir}${RESET}"

    return 0
}

# ─── Ajuda ──────────────────────────────────────────────────────────────────

print_help() {
    echo ""
    echo -e "  ${BOLD}nerd-font-install.sh${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
    echo ""
    echo "  Baixa e instala fontes Nerd Fonts com icons de programacao."
    echo "  Origem: github.com/ryanoasis/nerd-fonts"
    echo ""
    echo "  Uso: ./nerd-font-install.sh [opcoes]"
    echo ""
    echo "  Opcoes:"
    echo "    --list                    Lista familias de fontes disponiveis"
    echo "    -f, --font FONT           Instala fonte(s) especifica(s)"
    echo "    -f, --font F1,F2          Multiplas fontes separadas por virgula"
    echo "    --all                     Instala todas as fontes disponiveis"
    echo "    -o, --install-dir DIR     Diretorio de instalacao"
    echo "                              (padrao: ~/.local/share/fonts)"
    echo "    --system                  Instala em /usr/local/share/fonts"
    echo "                              (requer sudo na execucao)"
    echo "    -n, --dry-run             Simula sem baixar ou instalar"
    echo "    --help|-h                 Mostra esta ajuda"
    echo "    --version|-V              Mostra versao"
    echo ""
    echo "  Exemplos:"
    echo "    ./nerd-font-install.sh --list"
    echo "    ./nerd-font-install.sh -f FiraCode"
    echo "    ./nerd-font-install.sh -f FiraCode,JetBrainsMono"
    echo "    ./nerd-font-install.sh -f FiraCode -f Meslo"
    echo "    ./nerd-font-install.sh --all"
    echo "    ./nerd-font-install.sh -f Hack --dry-run"
    echo "    sudo ./nerd-font-install.sh -f CascadiaCode --system"
    echo ""
    exit 0
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
    # ── Parsing de argumentos ──
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list)
                DO_LIST=true; shift ;;
            --all)
                DO_ALL=true; shift ;;
            -f|--font)
                [[ -z "${2-}" ]] && error "Flag --font requer um nome de fonte"
                # Suporta multiplas fontes separadas por virgula
                local raw="${2// /}"
                IFS=',' read -ra parts <<< "$raw"
                for part in "${parts[@]}"; do
                    part=$(normalize_font_name "$part")
                    [[ -n "$part" ]] && SELECTED_FONTS+=("$part")
                done
                shift 2 ;;
            -o|--install-dir)
                [[ -z "${2-}" ]] && error "Flag --install-dir requer um diretorio"
                INSTALL_DIR="$2"; shift 2 ;;
            --system)
                SYSTEM_INSTALL=true; shift ;;
            -n|--dry-run)
                DRY_RUN=true; shift ;;
            --help|-h)
                print_help ;;
            --version|-V)
                echo "nerd-font-install.sh $SCRIPT_VERSION"; exit 0 ;;
            --)
                shift; break ;;
            -*)
                echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
                echo -e "${DIM}Use --help para ver as opcoes disponiveis.${RESET}" >&2
                exit 2 ;;
            *)
                # Trata argumento posicional como nome de fonte
                SELECTED_FONTS+=("$(normalize_font_name "$1")"); shift ;;
        esac
    done

    # ── Diretorio de instalacao ──
    if [[ -z "$INSTALL_DIR" ]]; then
        if [[ "$SYSTEM_INSTALL" == true ]]; then
            INSTALL_DIR="/usr/local/share/fonts"
        else
            INSTALL_DIR=$(get_default_install_dir)
        fi
    fi

    # ── Listagem ──
    if [[ "$DO_LIST" == true ]]; then
        print_fonts
        exit 0
    fi

    # ── Se nada selecionado, mostrar ajuda ──
    if [[ "$DO_ALL" == false && ${#SELECTED_FONTS[@]} -eq 0 ]]; then
        print_help
    fi

    # ── Montar lista de fontes a instalar ──
    local fonts_to_install=()
    if [[ "$DO_ALL" == true ]]; then
        fonts_to_install=("${ALL_FONTS[@]}")
    else
        local invalid=()
        for font in "${SELECTED_FONTS[@]}"; do
            local validated
            if validated=$(validate_font "$font"); then
                fonts_to_install+=("$validated")
            else
                invalid+=("$font")
            fi
        done
        if [[ ${#invalid[@]} -gt 0 ]]; then
            echo -e "  ${YELLOW}Aviso: fonte(s) nao reconhecida(s):${RESET}" >&2
            for f in "${invalid[@]}"; do
                echo -e "  ${DIM}  - $f${RESET}" >&2
            done
            echo -e "  ${DIM}Use --list para ver as fontes disponiveis.${RESET}" >&2
            [[ ${#fonts_to_install[@]} -eq 0 ]] && exit 1
        fi
    fi

    # ── Cabeçalho ──
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Nerd Fonts Installer${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    local total=${#fonts_to_install[@]}
    if [[ "$DO_ALL" == true ]]; then
        log "Modo: todas as fontes (${total})"
    else
        log "Modo: ${total} fonte(s) selecionada(s)"
    fi
    echo -e "  ${DIM}Destino: ${INSTALL_DIR}${RESET}"
    [[ "$DRY_RUN" == true ]] && echo -e "  ${DIM}Modo: DRY-RUN (nenhuma alteracao real)${RESET}"
    echo ""

    # ── Verificar permissao para --system ──
    if [[ "$SYSTEM_INSTALL" == true ]] && [[ "$DRY_RUN" == false ]]; then
        if [[ ! -w "$INSTALL_DIR" ]] && [[ ! -w "$(dirname "$INSTALL_DIR")" ]]; then
            error "Sem permissao de escrita em ${INSTALL_DIR}. Execute com sudo."
        fi
    fi

    # ── Criar temp dir global ──
    TMPDIR_WORK=$(mktemp -d)
    trap 'trap_cleanup' EXIT

    # ── Instalar ──
    local installed=0
    local failed=0
    local skipped=0

    for font in "${fonts_to_install[@]}"; do
        echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
        if install_font "$font"; then
            installed=$((installed + 1))
        else
            if is_font_installed "$font"; then
                skipped=$((skipped + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done

    # ── fc-cache ──
    if [[ "$DRY_RUN" == false ]] && [[ "$installed" -gt 0 ]]; then
        echo ""
        echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
        log "Atualizando cache de fontes..."
        if fc-cache -f "$INSTALL_DIR" 2>/dev/null; then
            success "Cache de fontes atualizado"
        else
            warn "Falha ao atualizar cache de fontes (fc-cache)"
        fi
    fi

    # ── Rodapé ──
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Resumo${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${GREEN}✓${RESET} Instaladas:  ${BOLD}${installed}${RESET}"
    echo -e "  ${DIM}−${RESET} Ja existiam: ${BOLD}${skipped}${RESET}"
    if [[ "$failed" -gt 0 ]]; then
        echo -e "  ${RED}✗${RESET} Falhas:      ${BOLD}${failed}${RESET}"
    fi
    echo ""
    echo -e "  ${DIM}Destino: ${INSTALL_DIR}${RESET}"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${YELLOW}Modo dry-run ativo — nenhuma alteracao foi feita.${RESET}"
        echo ""
    fi

    [[ "$failed" -gt 0 ]] && exit 1
    exit 0
}

main "$@"
