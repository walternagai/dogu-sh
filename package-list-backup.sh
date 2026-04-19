#!/bin/bash
# package-list-backup.sh — Exporta/importa lista de pacotes instalados para replicar maquina
# Uso: ./package-list-backup.sh [opcoes]
# Opcoes:
#   --export FILE   Exporta lista de pacotes para arquivo
#   --import FILE   Instala pacotes a partir de arquivo
#   --diff FILE     Compara pacotes atuais com arquivo
#   --format FMT    Formato de saida: txt (padrao) ou json
#   --scope SCOPE   Escopo: all (padrao), system, snap, flatpak, npm, pip, cargo
#   --dry-run       Preview sem executar
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
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


ACTION=""
BACKUP_FILE=""
FORMAT="txt"
SCOPE="all"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export|-e)
            [[ -z "${2-}" ]] && { echo "Flag --export requer um valor" >&2; exit 1; }
            ACTION="export"; BACKUP_FILE="$2"; shift 2 ;;
        --import|-i)
            [[ -z "${2-}" ]] && { echo "Flag --import requer um valor" >&2; exit 1; }
            ACTION="import"; BACKUP_FILE="$2"; shift 2 ;;
        --diff|-d)
            [[ -z "${2-}" ]] && { echo "Flag --diff requer um valor" >&2; exit 1; }
            ACTION="diff"; BACKUP_FILE="$2"; shift 2 ;;
        --format|-f)
            [[ -z "${2-}" ]] && { echo "Flag --format requer um valor" >&2; exit 1; }
            FORMAT="$2"; shift 2 ;;
        --scope|-s)
            [[ -z "${2-}" ]] && { echo "Flag --scope requer um valor" >&2; exit 1; }
            SCOPE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  package-list-backup.sh — Exporta/importa lista de pacotes"
            echo ""
            echo "  Uso: ./package-list-backup.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --export FILE   Exporta lista de pacotes para arquivo"
            echo "    --import FILE   Instala pacotes a partir de arquivo"
            echo "    --diff FILE     Compara pacotes atuais com arquivo"
            echo "    --format FMT    Formato: txt (padrao) ou json"
            echo "    --scope SCOPE   Escopo: all, system, snap, flatpak, npm, pip, cargo"
            echo "    --dry-run       Preview sem executar"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./package-list-backup.sh --export pacotes.txt"
            echo "    ./package-list-backup.sh --export pacotes.json --format json"
            echo "    ./package-list-backup.sh --import pacotes.txt --dry-run"
            echo "    ./package-list-backup.sh --diff pacotes.txt"
            echo "    ./package-list-backup.sh --export pkg.txt --scope system"
            echo ""
            exit 0
            ;;
        --version|-V) echo "package-list-backup.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if [ -z "$ACTION" ]; then
    ACTION="export"
    BACKUP_FILE="${BACKUP_FILE:-package-list-$(date +%Y%m%d).txt}"
fi

if [ -z "$BACKUP_FILE" ]; then
    echo -e "  ${RED}Erro: especifique o arquivo.${RESET}" >&2
    exit 1
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

detect_installer_for() {
    local pkg_type="$1"
    case "$pkg_type" in
        apt) echo "sudo apt-get install -y" ;;
        pacman) echo "sudo pacman -S --noconfirm" ;;
        dnf) echo "sudo dnf install -y" ;;
        snap) echo "sudo snap install" ;;
        flatpak) echo "flatpak install -y" ;;
        npm) echo "npm install -g" ;;
        pip) echo "pip install" ;;
        cargo) echo "cargo install" ;;
        brew) echo "brew install" ;;
        *) echo "echo" ;;
    esac
}

DISTRO=$(detect_distro)

echo ""
echo -e "  ${BOLD}Package List Backup${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo -e "  Distro: ${CYAN}$DISTRO${RESET}"
echo ""

should_collect() {
    local scope_name="$1"
    if [ "$SCOPE" = "all" ] || [ "$SCOPE" = "$scope_name" ]; then
        return 0
    fi
    return 1
}

collect_system() {
    case "$DISTRO" in
        debian|ubuntu|linuxmint|pop*|elementary|kali)
            dpkg --get-selections 2>/dev/null | grep -v deinstall | awk '{print $1}' | sort
            ;;
        fedora|rhel|centos|rocky|alma*)
            rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort
            ;;
        arch|manjaro|endeavouros|garuda*)
            pacman -Qe 2>/dev/null | awk '{print $1}' | sort
            ;;
        *)
            echo "# distro nao suportada" >&2
            ;;
    esac
}

collect_snap() {
    if command -v snap &>/dev/null; then
        snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | sort
    fi
}

collect_flatpak() {
    if command -v flatpak &>/dev/null; then
        flatpak list --app --columns=application 2>/dev/null | tail -n +1 | sort
    fi
}

collect_npm() {
    if command -v npm &>/dev/null; then
        npm ls -g --depth=0 --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    deps = data.get('dependencies', {})
    for name in sorted(deps.keys()):
        print(name)
except:
    pass
" 2>/dev/null
    fi
}

collect_pip() {
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        local cmd="pip3"
        command -v pip3 &>/dev/null || cmd="pip"
        $cmd list --format=json 2>/dev/null | python3 -c "
import sys, json
try:
    pkgs = json.load(sys.stdin)
    for p in sorted(pkgs, key=lambda x: x['name']):
        print(p['name'])
except:
    pass
" 2>/dev/null
    fi
}

collect_cargo() {
    if command -v cargo &>/dev/null; then
        cargo install --list 2>/dev/null | grep -E '^[a-z]' | awk '{print $1}' | sort
    fi
}

# =============================================
# EXPORT
# =============================================

if [ "$ACTION" = "export" ]; then
    echo -e "  ${BOLD}── Exportando para ${BACKUP_FILE} ──${RESET}"
    echo ""

    if [ "$FORMAT" = "json" ]; then
        echo "{" > "$BACKUP_FILE"
        echo "  \"timestamp\": \"$(date -Iseconds)\"," >> "$BACKUP_FILE"
        echo "  \"distro\": \"$DISTRO\"," >> "$BACKUP_FILE"

        first_section=true

        if should_collect "system"; then
            system_pkgs=$(collect_system 2>/dev/null)
            if [ -n "$system_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "  \"system\": [" >> "$BACKUP_FILE"
                echo "$system_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        if should_collect "snap"; then
            snap_pkgs=$(collect_snap 2>/dev/null)
            if [ -n "$snap_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "" >> "$BACKUP_FILE"
                echo "  \"snap\": [" >> "$BACKUP_FILE"
                echo "$snap_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        if should_collect "flatpak"; then
            flatpak_pkgs=$(collect_flatpak 2>/dev/null)
            if [ -n "$flatpak_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "" >> "$BACKUP_FILE"
                echo "  \"flatpak\": [" >> "$BACKUP_FILE"
                echo "$flatpak_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        if should_collect "npm"; then
            npm_pkgs=$(collect_npm 2>/dev/null)
            if [ -n "$npm_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "" >> "$BACKUP_FILE"
                echo "  \"npm\": [" >> "$BACKUP_FILE"
                echo "$npm_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        if should_collect "pip"; then
            pip_pkgs=$(collect_pip 2>/dev/null)
            if [ -n "$pip_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "" >> "$BACKUP_FILE"
                echo "  \"pip\": [" >> "$BACKUP_FILE"
                echo "$pip_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        if should_collect "cargo"; then
            cargo_pkgs=$(collect_cargo 2>/dev/null)
            if [ -n "$cargo_pkgs" ]; then
                $first_section || echo "," >> "$BACKUP_FILE"
                first_section=false
                echo "" >> "$BACKUP_FILE"
                echo "  \"cargo\": [" >> "$BACKUP_FILE"
                echo "$cargo_pkgs" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo "    \"$pkg\"," >> "$BACKUP_FILE"
                done
                printf '  ]' >> "$BACKUP_FILE"
            fi
        fi

        echo "" >> "$BACKUP_FILE"
        echo "}" >> "$BACKUP_FILE"

        sed -i 's/,\(\s*\]\)/\1/g' "$BACKUP_FILE" 2>/dev/null || true

    else
        echo "# Package List Backup — $(date -Iseconds)" > "$BACKUP_FILE"
        echo "# Distro: $DISTRO" >> "$BACKUP_FILE"
        echo "" >> "$BACKUP_FILE"

        if should_collect "system"; then
            echo "[system]" >> "$BACKUP_FILE"
            collect_system 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi

        if should_collect "snap"; then
            echo "[snap]" >> "$BACKUP_FILE"
            collect_snap 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi

        if should_collect "flatpak"; then
            echo "[flatpak]" >> "$BACKUP_FILE"
            collect_flatpak 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi

        if should_collect "npm"; then
            echo "[npm]" >> "$BACKUP_FILE"
            collect_npm 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi

        if should_collect "pip"; then
            echo "[pip]" >> "$BACKUP_FILE"
            collect_pip 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi

        if should_collect "cargo"; then
            echo "[cargo]" >> "$BACKUP_FILE"
            collect_cargo 2>/dev/null | while IFS= read -r pkg; do
                [ -z "$pkg" ] && continue
                echo "$pkg" >> "$BACKUP_FILE"
            done
            echo "" >> "$BACKUP_FILE"
        fi
    fi

    file_lines=$(wc -l < "$BACKUP_FILE" | tr -d ' ')
    file_size=$(du -h "$BACKUP_FILE" 2>/dev/null | awk '{print $1}')
    echo -e "  ${GREEN}✓${RESET} Exportado: ${BOLD}$BACKUP_FILE${RESET} ($file_lines linhas, $file_size)"
fi

# =============================================
# IMPORT
# =============================================

if [ "$ACTION" = "import" ]; then
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "  ${RED}Arquivo '${BACKUP_FILE}' nao encontrado.${RESET}"
        exit 1
    fi

    echo -e "  ${BOLD}── Importando de ${BACKUP_FILE} ──${RESET}"
    echo ""

    install_system_pkg() {
        local pkg="$1"
        case "$DISTRO" in
            debian|ubuntu|linuxmint|pop*|elementary|kali)
                sudo apt-get install -y "$pkg" 2>/dev/null
                ;;
            fedora|rhel|centos|rocky|alma*)
                sudo dnf install -y "$pkg" 2>/dev/null
                ;;
            arch|manjaro|endeavouros|garuda*)
                sudo pacman -S --noconfirm "$pkg" 2>/dev/null
                ;;
        esac
    }

    current_section=""
    installed=0
    failed=0

    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '[:space:]')

        [[ "$line" =~ ^# ]] && continue
        [ -z "$line" ] && continue

        if [[ "$line" =~ ^\[.*\]$ ]]; then
            current_section=$(echo "$line" | tr -d '[]')
            echo -e "  ${BOLD}── Seção: $current_section ──${RESET}"
            continue
        fi

        if $DRY_RUN; then
            printf "  ${DIM}[dry-run]${RESET} %-20s %s\n" "[$current_section]" "$line"
            continue
        fi

        case "$current_section" in
            system)
                if install_system_pkg "$line"; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[system]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[system]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            snap)
                if sudo snap install "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[snap]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[snap]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            flatpak)
                if flatpak install -y "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[flatpak]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[flatpak]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            npm)
                if npm install -g "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[npm]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[npm]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            pip)
                if pip3 install "$line" 2>/dev/null || pip install "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[pip]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[pip]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            cargo)
                if cargo install "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[cargo]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[cargo]" "$line"
                    failed=$((failed + 1))
                fi
                ;;
            *)
                printf "  ${DIM}?${RESET} %-20s %s ${DIM}(secao desconhecida)${RESET}\n" "[$current_section]" "$line"
                ;;
        esac
    done < "$BACKUP_FILE"

    echo ""
    echo "  ─────────────────────────────────"
    echo -e "  ${GREEN}✓${RESET} Importados: ${GREEN}${BOLD}$installed${RESET}  |  Falhas: ${RED}${BOLD}$failed${RESET}"
    echo "  ─────────────────────────────────"
fi

# =============================================
# DIFF
# =============================================

if [ "$ACTION" = "diff" ]; then
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "  ${RED}Arquivo '${BACKUP_FILE}' nao encontrado.${RESET}"
        exit 1
    fi

    echo -e "  ${BOLD}── Diferencas com ${BACKUP_FILE} ──${RESET}"
    echo ""

    TMPWORK=$(mktemp -d)
    trap 'rm -rf "$TMPWORK"' EXIT

    current_system=$(collect_system 2>/dev/null)
    echo "$current_system" > "$TMPWORK/current_system.txt"

    backup_system=$(grep -A9999 '^\[system\]' "$BACKUP_FILE" 2>/dev/null | grep -v '^\[' | grep -v '^#' | grep -v '^$' | sort)
    echo "$backup_system" > "$TMPWORK/backup_system.txt"

    only_in_backup=$(comm -23 "$TMPWORK/backup_system.txt" "$TMPWORK/current_system.txt" 2>/dev/null)
    only_in_current=$(comm -13 "$TMPWORK/backup_system.txt" "$TMPWORK/current_system.txt" 2>/dev/null)

    missing_count=0
    new_count=0

    if [ -n "$only_in_backup" ]; then
        missing_count=$(echo "$only_in_backup" | grep -c '.' 2>/dev/null || echo 0)
        missing_count=$(echo "$missing_count" | tr -d '[:space:]')
    fi
    if [ -n "$only_in_current" ]; then
        new_count=$(echo "$only_in_current" | grep -c '.' 2>/dev/null || echo 0)
        new_count=$(echo "$new_count" | tr -d '[:space:]')
    fi

    [[ "$missing_count" =~ ^[0-9]+$ ]] || missing_count=0
    [[ "$new_count" =~ ^[0-9]+$ ]] || new_count=0

    if [ "$missing_count" -gt 0 ]; then
        echo -e "  ${YELLOW}No backup mas nao instalados ($missing_count):${RESET}"
        echo "$only_in_backup" | while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            echo -e "    ${RED}- $pkg${RESET}"
        done
        echo ""
    fi

    if [ "$new_count" -gt 0 ]; then
        echo -e "  ${CYAN}Instalados mas nao no backup ($new_count):${RESET}"
        echo "$only_in_current" | while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            echo -e "    ${GREEN}+ $pkg${RESET}"
        done
        echo ""
    fi

    if [ "$missing_count" -eq 0 ] && [ "$new_count" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} Nenhuma diferenca encontrada no escopo system"
    fi
fi

echo ""