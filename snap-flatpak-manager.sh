#!/bin/bash
# snap-flatpak-manager.sh — Lista, atualiza e limpa snaps e flatpaks
# Uso: ./snap-flatpak-manager.sh [opcoes]
# Opcoes:
#   --list           Lista pacotes snap e flatpak instalados
#   --update         Atualiza pacotes snap e flatpak
#   --clean          Remove runtimes e pacotes nao utilizados
#   --snap-only      Opera apenas no snap
#   --flatpak-only   Opera apenas no flatpak
#   --dry-run        Preview sem executar
#   --help           Mostra esta ajuda
#   --version        Mostra versao

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

ACTION="list"
SNAP_ONLY=false
FLATPAK_ONLY=false
DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --list|-l) ACTION="list"; shift ;;
        --update|-u) ACTION="update"; shift ;;
        --clean|-c) ACTION="clean"; shift ;;
        --snap-only) SNAP_ONLY=true; shift ;;
        --flatpak-only) FLATPAK_ONLY=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  snap-flatpak-manager.sh — Gerencia snaps e flatpaks"
            echo ""
            echo "  Uso: ./snap-flatpak-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --list           Lista pacotes instalados (padrao)"
            echo "    --update         Atualiza pacotes snap e flatpak"
            echo "    --clean          Remove runtimes e pacotes nao utilizados"
            echo "    --snap-only      Opera apenas no snap"
            echo "    --flatpak-only   Opera apenas no flatpak"
            echo "    --dry-run        Preview sem executar"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./snap-flatpak-manager.sh --list"
            echo "    ./snap-flatpak-manager.sh --update"
            echo "    ./snap-flatpak-manager.sh --clean --snap-only"
            echo "    ./snap-flatpak-manager.sh --update --dry-run"
            echo ""
            exit 0
            ;;
        --version|-v) echo "snap-flatpak-manager.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if ! $SNAP_ONLY && ! $FLATPAK_ONLY; then
    SNAP_ONLY=true
    FLATPAK_ONLY=true
fi

run_or_dry() {
    local label="$1"
    shift
    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-50s\n" "$label"
        return 0
    fi
    "$@" 2>/dev/null
    local rc=$?
    if [ $rc -eq 0 ]; then
        printf "  ${GREEN}✓${RESET} %-50s\n" "$label"
    else
        printf "  ${RED}✗${RESET} %-50s ${DIM}(falha)${RESET}\n" "$label"
    fi
    return $rc
}

echo ""
echo -e "  ${BOLD}Snap/Flatpak Manager${RESET}  ${DIM}v$VERSION${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo ""

# =============================================
# SNAP
# =============================================

if $SNAP_ONLY; then
    if command -v snap &>/dev/null; then
        case "$ACTION" in
            list)
                echo -e "  ${BOLD}── Snap ──${RESET}"
                echo ""

                snap_list=$(snap list 2>/dev/null | tail -n +2)
                snap_count=$(echo "$snap_list" | grep -c '.' || echo 0)
                snap_count=$(echo "$snap_count" | tr -d '[:space:]')
                [[ "$snap_count" =~ ^[0-9]+$ ]] || snap_count=0

                echo -e "  ${BOLD}$snap_count${RESET} snap(s) instalado(s)"
                echo ""

                if [ "$snap_count" -gt 0 ]; then
                    printf "  %-25s %-12s %-12s %-12s %s\n" "NOME" "VERSAO" "REVISAO" "TAMANHO" "CANAL"
                    printf "  %-25s %-12s %-12s %-12s %s\n" "──────────────────────" "──────────" "──────────" "──────────" "──────────"

                    echo "$snap_list" | while IFS= read -r line; do
                        name=$(echo "$line" | awk '{print $1}')
                        ver=$(echo "$line" | awk '{print $2}')
                        rev=$(echo "$line" | awk '{print $3}')
                        size=$(echo "$line" | awk '{print $4}')
                        channel=$(echo "$line" | awk '{print $5}')

                        short_name=$(echo "$name" | cut -c1-23)
                        short_ver=$(echo "$ver" | cut -c1-10)
                        short_rev=$(echo "$rev" | cut -c1-10)
                        short_size=$(echo "$size" | cut -c1-10)
                        short_channel=$(echo "$channel" | cut -c1-10)

                        printf "  %-25s %-12s %-12s %-12s %s\n" "$short_name" "$short_ver" "$short_rev" "$short_size" "$short_channel"
                    done
                fi

                echo ""

                disabled_snaps=$(snap list --all 2>/dev/null | grep 'disabled' | wc -l | tr -d ' ')
                [[ "$disabled_snaps" =~ ^[0-9]+$ ]] || disabled_snaps=0
                if [ "$disabled_snaps" -gt 0 ]; then
                    echo -e "  ${YELLOW}$disabled_snaps${RESET} snap(s) desabilitado(s) (versoes antigas)"
                fi
                ;;

            update)
                echo -e "  ${BOLD}── Atualizando Snaps ──${RESET}"
                echo ""
                run_or_dry "snap refresh (todos)" sudo snap refresh
                echo ""
                ;;

            clean)
                echo -e "  ${BOLD}── Limpando Snaps ──${RESET}"
                echo ""

                disabled_snaps=$(snap list --all 2>/dev/null | grep 'disabled' | wc -l | tr -d ' ')
                [[ "$disabled_snaps" =~ ^[0-9]+$ ]] || disabled_snaps=0

                if [ "$disabled_snaps" -gt 0 ]; then
                    echo -e "  ${YELLOW}$disabled_snaps${RESET} snap(s) desabilitado(s):"
                    snap list --all 2>/dev/null | grep 'disabled' | awk '{print "    " $1 " " $2 " (disabled)"}'
                    echo ""

                    if ! $DRY_RUN; then
                        snap list --all 2>/dev/null | grep 'disabled' | awk '{print $1, $2}' | while read -r name rev; do
                            run_or_dry "snap remove $name $rev" sudo snap remove "$name" --revision="$rev"
                        done
                    else
                        echo -e "  ${DIM}[dry-run] Removeria $disabled_snaps snap(s) desabilitado(s)${RESET}"
                    fi
                else
                    echo -e "  ${GREEN}✓${RESET} Nenhum snap desabilitado para limpar"
                fi
                echo ""
                ;;
        esac
    else
        echo -e "  ${BOLD}── Snap ──${RESET}"
        echo -e "  ${DIM}snap nao instalado. Pulando...${RESET}"
        echo ""
    fi
fi

# =============================================
# FLATPAK
# =============================================

if $FLATPAK_ONLY; then
    if command -v flatpak &>/dev/null; then
        case "$ACTION" in
            list)
                echo -e "  ${BOLD}── Flatpak ──${RESET}"
                echo ""

                flatpak_apps=$(flatpak list --app --columns=name,version,branch,size,origin 2>/dev/null | tail -n +1)
                flatpak_count=$(flatpak list --app 2>/dev/null | tail -n +1 | grep -c '.' || echo 0)
                flatpak_count=$(echo "$flatpak_count" | tr -d '[:space:]')
                [[ "$flatpak_count" =~ ^[0-9]+$ ]] || flatpak_count=0

                echo -e "  ${BOLD}$flatpak_count${RESET} app(s) flatpak instalado(s)"
                echo ""

                if [ "$flatpak_count" -gt 0 ]; then
                    printf "  %-30s %-12s %-10s %-10s %s\n" "NOME" "VERSAO" "BRANCH" "TAMANHO" "ORIGEM"
                    printf "  %-30s %-12s %-10s %-10s %s\n" "────────────────────────────" "──────────" "────────" "──────────" "──────────"

                    flatpak list --app --columns=name,version,branch,size,origin 2>/dev/null | tail -n +1 | while IFS=$'\t' read -r name ver branch size origin; do
                        short_name=$(echo "$name" | cut -c1-28)
                        short_ver=$(echo "$ver" | cut -c1-10)
                        short_branch=$(echo "$branch" | cut -c1-8)
                        short_size=$(echo "$size" | cut -c1-10)
                        short_origin=$(echo "$origin" | cut -c1-10)
                        printf "  %-30s %-12s %-10s %-10s %s\n" "$short_name" "$short_ver" "$short_branch" "$short_size" "$short_origin"
                    done
                fi

                echo ""

                runtime_count=$(flatpak list --runtime 2>/dev/null | tail -n +1 | grep -c '.' || echo 0)
                runtime_count=$(echo "$runtime_count" | tr -d '[:space:]')
                [[ "$runtime_count" =~ ^[0-9]+$ ]] || runtime_count=0
                echo -e "  ${DIM}$runtime_count runtime(s) instalado(s)${RESET}"
                ;;

            update)
                echo -e "  ${BOLD}── Atualizando Flatpaks ──${RESET}"
                echo ""
                run_or_dry "flatpak update (todos)" flatpak update -y
                echo ""
                ;;

            clean)
                echo -e "  ${BOLD}── Limpando Flatpaks ──${RESET}"
                echo ""

                unused_count=$(flatpak uninstall --unused 2>/dev/null | grep -c '.' || echo 0)
                [[ "$unused_count" =~ ^[0-9]+$ ]] || unused_count=0

                if [ "$unused_count" -gt 0 ]; then
                    echo -e "  ${YELLOW}$unused_count${RESET} runtime(s)/app(s) nao utilizada(s)"
                    run_or_dry "flatpak uninstall --unused -y" flatpak uninstall --unused -y
                else
                    echo -e "  ${GREEN}✓${RESET} Nenhum flatpak nao utilizado para limpar"
                fi
                echo ""
                ;;
        esac
    else
        echo -e "  ${BOLD}── Flatpak ──${RESET}"
        echo -e "  ${DIM}flatpak nao instalado. Pulando...${RESET}"
        echo ""
    fi
fi

echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Operacao concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""