#!/bin/bash
# package-list-backup.sh — Exporta/importa lista de pacotes instalados para replicar maquina
# Uso: ./package-list-backup.sh [opcoes]
# Opcoes:
#   --export FILE   Exporta lista de pacotes para arquivo
#   --import FILE   Instala pacotes a partir de arquivo
#   --diff FILE     Compara pacotes atuais com arquivo
#   --format FMT    Formato de saida: txt (padrao) ou json
#   --scope SCOPE   Escopo: all (padrao), system, snap, flatpak, npm, pip, cargo, brew
#   --versions      Inclui versoes dos pacotes (afeta apenas --export)
#   --exclude PAT   Exclui pacotes que casam com o padrao (ex: --exclude linux-*)
#   --include PAT   Inclui apenas pacotes que casam com o padrao
#   --dry-run       Preview sem executar
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="2.0.0"
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

ACTION=""
BACKUP_FILE=""
FORMAT="txt"
SCOPE="all"
DRY_RUN=false
VERSIONS=false
EXCLUDE_PATTERN=""
INCLUDE_PATTERN=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export|-e|--backup)
            [[ -z "${2-}" ]] && { echo "Flag $1 requer um valor" >&2; exit 1; }
            ACTION="export"; BACKUP_FILE="$2"; shift 2 ;;
        --import|-i|--restore)
            [[ -z "${2-}" ]] && { echo "Flag $1 requer um valor" >&2; exit 1; }
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
        --exclude)
            [[ -z "${2-}" ]] && { echo "Flag --exclude requer um valor" >&2; exit 1; }
            EXCLUDE_PATTERN="$2"; shift 2 ;;
        --include)
            [[ -z "${2-}" ]] && { echo "Flag --include requer um valor" >&2; exit 1; }
            INCLUDE_PATTERN="$2"; shift 2 ;;
        --versions|-V) VERSIONS=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  package-list-backup.sh — Exporta/importa lista de pacotes"
            echo ""
            echo "  Uso: ./package-list-backup.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --export FILE    Exporta lista de pacotes para arquivo"
            echo "    --import FILE    Instala pacotes a partir de arquivo"
            echo "    --diff FILE      Compara pacotes atuais com arquivo"
            echo "    --backup FILE    Alias para --export"
            echo "    --restore FILE   Alias para --import"
            echo "    --format FMT     Formato: txt (padrao) ou json"
            echo "    --scope SCOPE    Escopo: all, system, snap, flatpak, npm, pip, cargo, brew"
            echo "    --versions       Inclui versoes dos pacotes (so export)"
            echo "    --exclude PAD    Exclui pacotes que casam com padrao glob"
            echo "    --include PAD    Inclui apenas pacotes que casam com padrao glob"
            echo "    --dry-run        Preview sem executar"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./package-list-backup.sh --export pacotes.txt"
            echo "    ./package-list-backup.sh --export pacotes.json --format json"
            echo "    ./package-list-backup.sh --export pkg.txt --scope system --versions"
            echo "    ./package-list-backup.sh --import pacotes.txt --dry-run"
            echo "    ./package-list-backup.sh --diff pacotes.txt"
            echo "    ./package-list-backup.sh --export pkg.txt --exclude 'linux-*'"
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
    local id="unknown"
    if [ -f /etc/os-release ]; then
        id=$(. /etc/os-release 2>/dev/null && echo "${ID:-unknown}" || echo "unknown")
    elif [ -f /etc/debian_version ]; then
        id="debian"
    elif [ -f /etc/fedora-release ]; then
        id="fedora"
    elif [ -f /etc/arch-release ]; then
        id="arch"
    fi
    echo "$id"
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
    [ "$SCOPE" = "all" ] || [ "$SCOPE" = "$scope_name" ]
}

matches_filter() {
    local pkg="$1"
    if [ -n "$INCLUDE_PATTERN" ]; then
        case "$pkg" in
            $INCLUDE_PATTERN) return 0 ;;
            *) return 1 ;;
        esac
    fi
    if [ -n "$EXCLUDE_PATTERN" ]; then
        case "$pkg" in
            $EXCLUDE_PATTERN) return 1 ;;
        esac
    fi
    return 0
}

collect_system() {
    local pkgs=""
    case "$DISTRO" in
        debian|ubuntu|linuxmint|pop*|elementary|kali)
            if $VERSIONS; then
                pkgs=$(apt-mark showmanual 2>/dev/null | while IFS= read -r pkg; do
                    ver=$(apt-cache policy "$pkg" 2>/dev/null | grep 'Candidate:' | head -1 | awk '{print $2}')
                    [ -z "$pkg" ] && continue
                    if [ -n "$ver" ]; then
                        echo "${pkg}=${ver}"
                    else
                        echo "$pkg"
                    fi
                done || true)
            else
                pkgs=$(apt-mark showmanual 2>/dev/null || true)
            fi
            ;;
        fedora|rhel|centos|rocky|alma*)
            if $VERSIONS; then
                pkgs=$(rpm -qa --qf '%{NAME}-%{VERSION}\n' 2>/dev/null | sort || true)
            else
                pkgs=$(rpm -qa --qf '%{NAME}\n' 2>/dev/null | sort || true)
            fi
            ;;
        arch|manjaro|endeavouros|garuda*)
            if $VERSIONS; then
                pkgs=$(pacman -Qe 2>/dev/null | awk '{print $1"="$2}' || true)
            else
                pkgs=$(pacman -Qe 2>/dev/null | awk '{print $1}' || true)
            fi
            ;;
    esac
    echo "$pkgs"
}

collect_repos() {
    local repos=""
    case "$DISTRO" in
        debian|ubuntu|linuxmint|pop*|elementary|kali)
            if [ -d /etc/apt/sources.list.d ]; then
                repos=$(find /etc/apt/sources.list.d -name '*.list' -o -name '*.sources' 2>/dev/null | sort || true)
            fi
            ;;
    esac
    echo "$repos"
}

collect_snap() {
    if command -v snap &>/dev/null; then
        if $VERSIONS; then
            snap list 2>/dev/null | tail -n +2 | awk '{print $1"="$2}' | sort || true
        else
            snap list 2>/dev/null | tail -n +2 | awk '{print $1}' | sort || true
        fi
    fi
}

collect_flatpak() {
    if command -v flatpak &>/dev/null; then
        if $VERSIONS; then
            flatpak list --app --columns=application,version 2>/dev/null | awk -F$'\t' '{print $1"="$2}' | sort || true
        else
            flatpak list --app --columns=application 2>/dev/null | sort || true
        fi
    fi
}

collect_npm() {
    if command -v npm &>/dev/null; then
        if $VERSIONS; then
            npm ls -g --depth=0 --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    deps = data.get('dependencies', {})
    for name in sorted(deps.keys()):
        ver = deps[name].get('version', '')
        print(f'{name}={ver}' if ver else name)
except:
    pass
" 2>/dev/null || true
        else
            npm ls -g --depth=0 --json 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    deps = data.get('dependencies', {})
    for name in sorted(deps.keys()):
        print(name)
except:
    pass
" 2>/dev/null || true
        fi
    fi
}

collect_pip() {
    if command -v pip &>/dev/null || command -v pip3 &>/dev/null; then
        local cmd="pip3"
        command -v pip3 &>/dev/null || cmd="pip"
        if $VERSIONS; then
            $cmd list --format=json 2>/dev/null | python3 -c "
import sys, json
try:
    pkgs = json.load(sys.stdin)
    for p in sorted(pkgs, key=lambda x: x['name']):
        print(f'{p[\"name\"]}={p[\"version\"]}')
except:
    pass
" 2>/dev/null || true
        else
            $cmd list --format=json 2>/dev/null | python3 -c "
import sys, json
try:
    pkgs = json.load(sys.stdin)
    for p in sorted(pkgs, key=lambda x: x['name']):
        print(p['name'])
except:
    pass
" 2>/dev/null || true
        fi
    fi
}

collect_cargo() {
    if command -v cargo &>/dev/null; then
        if $VERSIONS; then
            cargo install --list 2>/dev/null | grep -E '^[a-z]' | awk '{print $1"="$2}' | sort || true
        else
            cargo install --list 2>/dev/null | grep -E '^[a-z]' | awk '{print $1}' | sort || true
        fi
    fi
}

collect_brew() {
    if command -v brew &>/dev/null; then
        if $VERSIONS; then
            brew list --formula --versions 2>/dev/null | sort || true
        else
            brew list --formula 2>/dev/null | sort || true
        fi
    fi
}

escape_json_string() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
}

write_json_array() {
    local section="$1"
    local data="$2"
    local first_ref="$3"
    local count=0

    if [ -z "$data" ]; then
        return
    fi

    local pkg_array=()
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        matches_filter "$pkg" || continue
        pkg_array+=("$pkg")
    done <<< "$data"

    [ ${#pkg_array[@]} -eq 0 ] && return

    if [ "$first_ref" = "false" ]; then
        printf ',\n' >> "$BACKUP_FILE"
    fi

    printf '  "%s": [\n' "$section" >> "$BACKUP_FILE"
    local i
    for i in "${!pkg_array[@]}"; do
        local escaped
        escaped=$(escape_json_string "${pkg_array[$i]}")
        if [ "$i" -lt $((${#pkg_array[@]} - 1)) ]; then
            printf '    "%s",\n' "$escaped" >> "$BACKUP_FILE"
        else
            printf '    "%s"\n' "$escaped" >> "$BACKUP_FILE"
        fi
    done
    printf '  ]' >> "$BACKUP_FILE"
}

write_txt_section() {
    local section="$1"
    local data="$2"

    if [ -z "$data" ]; then
        return
    fi

    local pkg_count=0
    echo "[$section]" >> "$BACKUP_FILE"
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        matches_filter "$pkg" || continue
        echo "$pkg" >> "$BACKUP_FILE"
        pkg_count=$((pkg_count + 1))
    done <<< "$data"
    echo "" >> "$BACKUP_FILE"
}

collect_section() {
    local scope="$1"
    case "$scope" in
        system)  collect_system 2>/dev/null || true ;;
        snap)    collect_snap 2>/dev/null || true ;;
        flatpak) collect_flatpak 2>/dev/null || true ;;
        npm)     collect_npm 2>/dev/null || true ;;
        pip)     collect_pip 2>/dev/null || true ;;
        cargo)   collect_cargo 2>/dev/null || true ;;
        brew)    collect_brew 2>/dev/null || true ;;
        repos)   collect_repos 2>/dev/null || true ;;
    esac
}

# =============================================
# EXPORT
# =============================================

if [ "$ACTION" = "export" ]; then
    echo -e "  ${BOLD}── Exportando para ${BACKUP_FILE} ──${RESET}"
    echo ""

    if [ "$FORMAT" = "json" ]; then
        echo "{" > "$BACKUP_FILE"
        printf '  "timestamp": "%s",\n' "$(date -Iseconds)" >> "$BACKUP_FILE"
        printf '  "distro": "%s",\n' "$DISTRO" >> "$BACKUP_FILE"

        first_section=true

        for section in system snap flatpak npm pip cargo brew; do
            if should_collect "$section"; then
                section_data=$(collect_section "$section")
                if [ -n "$section_data" ]; then
                    write_json_array "$section" "$section_data" "$first_section"
                    first_section=false
                fi
            fi
        done

        if should_collect "system" && [ "$DISTRO" = "ubuntu" ] || should_collect "system" && [[ "$DISTRO" =~ ^(linuxmint|pop|elementary)$ ]]; then
            repos_data=$(collect_repos)
            if [ -n "$repos_data" ]; then
                write_json_array "repos" "$repos_data" "$first_section"
                first_section=false
            fi
        fi

        echo "" >> "$BACKUP_FILE"
        echo "}" >> "$BACKUP_FILE"

    else
        echo "# Package List Backup — $(date -Iseconds)" > "$BACKUP_FILE"
        echo "# Distro: $DISTRO" >> "$BACKUP_FILE"
        echo "" >> "$BACKUP_FILE"

        total_pkgs=0
        for section in system snap flatpak npm pip cargo brew; do
            if should_collect "$section"; then
                section_data=$(collect_section "$section")
                if [ -n "$section_data" ]; then
                    write_txt_section "$section" "$section_data"
                    section_count=$(echo "$section_data" | grep -c '.' || echo 0)
                    total_pkgs=$((total_pkgs + section_count))
                fi
            fi
        done
    fi

    file_lines=$(wc -l < "$BACKUP_FILE" | tr -d ' ')
    file_size=$(du -h "$BACKUP_FILE" 2>/dev/null | awk '{print $1}')

    total_pkgs=0
    for section in system snap flatpak npm pip cargo brew; do
        if should_collect "$section"; then
            section_data=$(collect_section "$section")
            if [ -n "$section_data" ]; then
                section_count=$(echo "$section_data" | grep -c '.' || echo 0)
                total_pkgs=$((total_pkgs + section_count))
            fi
        fi
    done

    echo -e "  ${GREEN}✓${RESET} Exportado: ${BOLD}$BACKUP_FILE${RESET} ($total_pkgs pacotes, $file_lines linhas, $file_size)"
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
        local pkg_name="${pkg%%=*}"
        case "$DISTRO" in
            debian|ubuntu|linuxmint|pop*|elementary|kali)
                sudo apt-get install -y "$pkg_name" 2>/dev/null
                ;;
            fedora|rhel|centos|rocky|alma*)
                sudo dnf install -y "$pkg_name" 2>/dev/null
                ;;
            arch|manjaro|endeavouros|garuda*)
                sudo pacman -S --noconfirm "$pkg_name" 2>/dev/null
                ;;
        esac
    }

    install_pip_pkg() {
        local pkg="$1"
        local pkg_name="${pkg%%=*}"
        local pip_cmd="pip3"
        command -v pip3 &>/dev/null || pip_cmd="pip"

        if [ -f /usr/lib/python3/EXTERNALLY-MANAGED ]; then
            $pip_cmd install --break-system-packages "$pkg_name" 2>/dev/null
        else
            $pip_cmd install "$pkg_name" 2>/dev/null
        fi
    }

    current_section=""
    installed=0
    failed=0

    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '[:space:]')

        [[ "$line" =~ ^# ]] && continue
        [ -z "$line" ] && continue

        if [[ "$line" =~ ^\{ ]]; then
            if ! command -v jq &>/dev/null; then
                echo -e "  ${RED}Formato JSON detectado mas 'jq' nao encontrado.${RESET}"
                echo -e "  ${YELLOW}Instale jq ou use formato txt para importacao.${RESET}"
                exit 1
            fi
            current_section=""
            installed=0
            failed=0

            for section in system snap flatpak npm pip cargo brew; do
                pkgs=$(jq -r --arg s "$section" '.[$s] // [] | .[]' "$BACKUP_FILE" 2>/dev/null || true)
                if [ -n "$pkgs" ]; then
                    echo -e "  ${BOLD}── Secao: $section ──${RESET}"
                    while IFS= read -r pkg; do
                        [ -z "$pkg" ] && continue
                        if $DRY_RUN; then
                            printf "  ${DIM}[dry-run]${RESET} %-20s %s\n" "[$section]" "$pkg"
                            continue
                        fi
                        case "$section" in
                            system)
                                if install_system_pkg "$pkg"; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[system]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[system]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            snap)
                                if sudo snap install "$pkg" 2>/dev/null; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[snap]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[snap]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            flatpak)
                                if flatpak install -y "$pkg" 2>/dev/null; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[flatpak]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[flatpak]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            npm)
                                if npm install -g "$pkg" 2>/dev/null; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[npm]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[npm]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            pip)
                                if install_pip_pkg "$pkg"; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[pip]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[pip]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            cargo)
                                if cargo install "$pkg" 2>/dev/null; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[cargo]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[cargo]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                            brew)
                                if brew install "$pkg" 2>/dev/null; then
                                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[brew]" "$pkg"
                                    installed=$((installed + 1))
                                else
                                    printf "  ${RED}✗${RESET} %-20s %s\n" "[brew]" "$pkg"
                                    failed=$((failed + 1))
                                fi
                                ;;
                        esac
                    done <<< "$pkgs"
                fi
            done

            echo ""
            echo "  ─────────────────────────────────"
            echo -e "  ${GREEN}✓${RESET} Importados: ${GREEN}${BOLD}$installed${RESET}  |  Falhas: ${RED}${BOLD}$failed${RESET}"
            echo "  ─────────────────────────────────"
            exit 0
        fi

        if [[ "$line" =~ ^\[.*\]$ ]]; then
            current_section=$(echo "$line" | tr -d '[]')
            echo -e "  ${BOLD}── Secao: $current_section ──${RESET}"
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
                if install_pip_pkg "$line"; then
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
            brew)
                if brew install "$line" 2>/dev/null; then
                    printf "  ${GREEN}✓${RESET} %-20s %s\n" "[brew]" "$line"
                    installed=$((installed + 1))
                else
                    printf "  ${RED}✗${RESET} %-20s %s\n" "[brew]" "$line"
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
    trap 'exit 130' INT TERM

    is_json=false
    first_char=$(head -c1 "$BACKUP_FILE" | tr -d '[:space:]')
    [ "$first_char" = "{" ] && is_json=true

    diff_section() {
        local section="$1"
        local current_pkgs="$2"
        local backup_pkgs=""

        if $is_json; then
            if command -v jq &>/dev/null; then
                backup_pkgs=$(jq -r --arg s "$section" '.[$s] // [] | .[]' "$BACKUP_FILE" 2>/dev/null | sed 's/=.*//' || true)
            fi
        else
            backup_pkgs=$(awk -v sec="$section" '
                /^\[/ { in_sec = ($0 == "[" sec "]") }
                in_sec && !/^\[/ && !/^#/ && NF { print }
            ' "$BACKUP_FILE" 2>/dev/null | sed 's/=.*//' || true)
        fi

        if [ -z "$backup_pkgs" ] && [ -z "$current_pkgs" ]; then
            return
        fi

        echo "$current_pkgs" | sort > "$TMPWORK/current_${section}.txt" 2>/dev/null || true
        echo "$backup_pkgs" | sort > "$TMPWORK/backup_${section}.txt" 2>/dev/null || true

        local only_backup only_current missing_count new_count
        only_backup=$(comm -23 "$TMPWORK/backup_${section}.txt" "$TMPWORK/current_${section}.txt" 2>/dev/null || true)
        only_current=$(comm -13 "$TMPWORK/backup_${section}.txt" "$TMPWORK/current_${section}.txt" 2>/dev/null || true)

        missing_count=0
        new_count=0

        if [ -n "$only_backup" ]; then
            missing_count=$(echo "$only_backup" | grep -c '.' 2>/dev/null || echo 0)
            missing_count=$(echo "$missing_count" | tr -d '[:space:]')
        fi
        if [ -n "$only_current" ]; then
            new_count=$(echo "$only_current" | grep -c '.' 2>/dev/null || echo 0)
            new_count=$(echo "$new_count" | tr -d '[:space:]')
        fi

        [[ "$missing_count" =~ ^[0-9]+$ ]] || missing_count=0
        [[ "$new_count" =~ ^[0-9]+$ ]] || new_count=0

        if [ "$missing_count" -gt 0 ] || [ "$new_count" -gt 0 ]; then
            echo -e "  ${BOLD}── $section ──${RESET}"

            if [ "$missing_count" -gt 0 ]; then
                echo -e "    ${YELLOW}No backup mas nao instalados ($missing_count):${RESET}"
                echo "$only_backup" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo -e "      ${RED}- $pkg${RESET}"
                done
            fi

            if [ "$new_count" -gt 0 ]; then
                echo -e "    ${CYAN}Instalados mas nao no backup ($new_count):${RESET}"
                echo "$only_current" | while IFS= read -r pkg; do
                    [ -z "$pkg" ] && continue
                    echo -e "      ${GREEN}+ $pkg${RESET}"
                done
            fi
            echo ""
        fi
    }

    total_missing=0
    total_new=0

    for section in system snap flatpak npm pip cargo brew; do
        if should_collect "$section"; then
            current_pkgs=$(collect_section "$section")
            diff_section "$section" "$current_pkgs"
        fi
    done

    has_diff=false
    for f in "$TMPWORK"/current_*.txt; do
        [ -f "$f" ] || continue
        sec=$(basename "$f" | sed 's/current_//;s/\.txt//')
        backup_file="$TMPWORK/backup_${sec}.txt"
        [ -f "$backup_file" ] || continue
        if ! comm -23 "$backup_file" "$f" | grep -q '.' 2>/dev/null && \
           ! comm -13 "$backup_file" "$f" | grep -q '.' 2>/dev/null; then
            continue
        fi
        has_diff=true
    done

    if [ "$has_diff" = false ]; then
        echo -e "  ${GREEN}✓${RESET} Nenhuma diferenca encontrada"
    fi
fi

echo ""
exit 0
