#!/bin/bash
# archive-manager.sh — Compacta pastas individualmente ou descompacta arquivos em massa (Linux)
# Uso: ./archive-manager.sh [opcoes] [diretorio]
# Opcoes:
#   --pack            Compacta cada subdiretorio do alvo em um arquivo .zip individual
#   --unpack          Descompacta cada arquivo compactado do alvo em sua propria pasta
#   --dry-run         Preview das operacoes sem alterar o disco
#   --help            Mostra esta ajuda
#   --version         Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "zip" "$INSTALLER" "zip"
    check_and_install "unzip" "$INSTALLER" "unzip"
    check_and_install "tar" "$INSTALLER" "tar"
fi

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

pack_dirs() {
    local target_dir="$1"
    local dry_run="$2"

    log "Iniciando compactacao individual em: $target_dir"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"

    # Iterar apenas sobre diretórios (excluindo o próprio target_dir)
    find "$target_dir" -maxdepth 1 -mindepth 1 -type d | while read -r dir; do
        local dir_name=$(basename "$dir")
        local zip_name="${dir_name}.zip"
        
        if [[ "$dry_run" == true ]]; then
            echo -e "  ${DIM}[Dry-run]${RESET} zip -r \"$zip_name\" \"$dir\""
        else
            echo -n "  ▶ Compactando $dir_name... "
            if zip -rq "$zip_name" "$dir"; then
                echo -e "${GREEN}✓${RESET}"
            else
                echo -e "${RED}✗${RESET}"
                warn "Falha ao compactar $dir_name"
            fi
        fi
    done
}

unpack_files() {
    local target_dir="$1"
    local dry_run="$2"

    log "Iniciando descompactacao em massa em: $target_dir"
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"

    # Procurar arquivos compactados comuns
    find "$target_dir" -maxdepth 1 -mindepth 1 -type f \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.tgz" -o -name "*.rar" \) | while read -r file; do
        local filename=$(basename "$file")
        local extension="${filename##*.}"
        local folder_name="${filename%.*}"
        
        # Tratar extensões duplas como .tar.gz
        if [[ "$filename" == *.tar.gz ]]; then
            folder_name="${filename%.tar.gz}"
        fi

        if [[ "$dry_run" == true ]]; then
            echo -e "  ${DIM}[Dry-run] mkdir -p \"$folder_name\" && unzip/tar \"$file\" -d \"$folder_name\""
        else
            echo -n "  ▶ Extraindo $filename... "
            mkdir -p "$folder_name"
            
            local status=1
            case "$filename" in
                *.zip) unzip -q "$file" -d "$folder_name" && status=0 ;;
                *.tar.gz|*.tgz) tar -xzf "$file" -C "$folder_name" && status=0 ;;
                *.rar) unrar x "$file" "$folder_name/" >/dev/null 2>&1 && status=0 || warn "unrar nao instalado" ;;
                *) warn "Formato nao suportado: $filename" ;;
            esac

            if [[ $status -eq 0 ]]; then
                echo -e "${GREEN}✓${RESET}"
            else
                echo -e "${RED}✗${RESET}"
            fi
        fi
    done
}

# --- Parsing de Argumentos ---

PACK=false
UNPACK=false
DRY_RUN=false
TARGET_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --pack|-p) PACK=true; shift ;;
        --unpack|-u) UNPACK=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  archive-manager.sh — Compacta pastas individualmente ou descompacta arquivos em massa"
            echo ""
            echo "  Uso: ./archive-manager.sh [opcoes] [diretorio]"
            echo ""
            echo "  Opcoes:"
            echo "    --pack|-p       Compacta subdiretorios em .zip individuais"
            echo "    --unpack|-u     Descompacta arquivos em pastas separadas"
            echo "    --dry-run       Simula as operacoes"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "archive-manager.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) 
            if [[ -z "$TARGET_DIR" ]]; then
                TARGET_DIR="$1"
                shift
            else
                echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
                exit 2
            fi
            ;;
    esac
done

# Validações
if [[ "$PACK" == false && "$UNPACK" == false ]]; then
    error "Voce deve especificar ao menos uma acao: --pack ou --unpack"
fi

if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="."
fi

if [[ ! -d "$TARGET_DIR" ]]; then
    error "O diretorio '$TARGET_DIR' nao existe."
fi

# Confirmação Interativa
if [[ "$DRY_RUN" == false ]]; then
    if [ -t 0 ]; then
        read -r -p "Confirmar operacao em $TARGET_DIR? [s/N] " CONFIRM < /dev/tty 2>/dev/null || CONFIRM="n"
        if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
            echo -e "${DIM}Operacao cancelada.${RESET}"
            exit 0
        fi
    else
        error "Execucao nao interativa detectada. Rode em terminal interativo (TTY) para confirmar."
    fi
fi

# Execução
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}Archive Manager${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

if [[ "$PACK" == true ]]; then
    pack_dirs "$TARGET_DIR" "$DRY_RUN"
fi

if [[ "$UNPACK" == true ]]; then
    unpack_files "$TARGET_DIR" "$DRY_RUN"
fi

success "Processo concluido."
