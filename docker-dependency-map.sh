#!/bin/bash
# docker-dependency-map.sh — Mapeia relacoes de dependencia entre containers
# Uso: ./docker-dependency-map.sh [opcoes]
# Opcoes:
#   --map           Mapeia todas as dependencias (padrao)
#   --network N     Filtra por rede
#   --container C   Filtra por container
#   --tree          Exibe dependencias em formato arvore
#   --dot           Gera saida Graphviz DOT
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi

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


ACTION="map"
FILTER_NETWORK=""
FILTER_CONTAINER=""
SHOW_TREE=false
SHOW_DOT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --map|-m) ACTION="map"; shift ;;
        --network|-n)
            [[ -z "${2-}" ]] && { echo "Flag --network requer um valor" >&2; exit 1; }
            FILTER_NETWORK="$2"; shift 2 ;;
        --container|-c)
            [[ -z "${2-}" ]] && { echo "Flag --container requer um valor" >&2; exit 1; }
            FILTER_CONTAINER="$2"; shift 2 ;;
        --tree|-t) SHOW_TREE=true; shift ;;
        --dot|-d) SHOW_DOT=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-dependency-map.sh — Mapeia dependencias entre containers"
            echo ""
            echo "  Uso: ./docker-dependency-map.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --map           Mapeia todas as dependencias (padrao)"
            echo "    --network N     Filtra por rede"
            echo "    --container C   Filtra por container"
            echo "    --tree          Exibe em formato arvore"
            echo "    --dot           Gera saida Graphviz DOT"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-dependency-map.sh"
            echo "    ./docker-dependency-map.sh --network minha-rede"
            echo "    ./docker-dependency-map.sh --container nginx --tree"
            echo "    ./docker-dependency-map.sh --dot > deps.dot"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-dependency-map.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

containers=$(docker ps -a --format '{{.ID}}|{{.Names}}|{{.Status}}|{{.Image}}' 2>/dev/null)
total_containers=$(echo "$containers" | grep -c '|' || echo 0)
total_containers=$(echo "$total_containers" | tr -d '[:space:]')
[[ "$total_containers" =~ ^[0-9]+$ ]] || total_containers=0

if [ "$total_containers" -eq 0 ]; then
    echo ""
    echo -e "  ${DIM}Nenhum container encontrado.${RESET}"
    exit 0
fi

if [ -n "$FILTER_CONTAINER" ]; then
    containers=$(echo "$containers" | grep "$FILTER_CONTAINER")
fi

TMPWORK=$(mktemp -d)
trap 'rm -rf "$TMPWORK"' EXIT

while IFS='|' read -r cid cname cstatus cimage; do
    [ -z "$cid" ] && continue

    networks=$(docker inspect --format '{{range $net, $conf := .NetworkSettings.Networks}}{{$net}}|{{end}}' "$cid" 2>/dev/null)
    volumes=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}|{{end}}{{end}}' "$cid" 2>/dev/null)
    depends=$(docker inspect --format '{{.Config.Labels}}' "$cid" 2>/dev/null | grep -oE 'com\.docker\.compose\.depends_on:[^ ]+' | sed 's/com.docker.compose.depends_on://' || true)

    for net in $(echo "$networks" | tr '|' '\n' | grep -v '^$'); do
        if [ -z "$FILTER_NETWORK" ] || [ "$net" = "$FILTER_NETWORK" ]; then
            echo "${cname}|network|${net}" >> "$TMPWORK/deps.txt"
        fi
    done

    for vol in $(echo "$volumes" | tr '|' '\n' | grep -v '^$'); do
        echo "${cname}|volume|${vol}" >> "$TMPWORK/deps.txt"
    done

    if [ -n "$depends" ]; then
        for dep in $(echo "$depends" | tr ',' '\n'); do
            dep=$(echo "$dep" | tr -d '[:space:]')
            [ -n "$dep" ] && echo "${cname}|depends_on|${dep}" >> "$TMPWORK/deps.txt"
        done
    fi

    echo "${cname}|image|${cimage}" >> "$TMPWORK/deps.txt"
    echo "${cname}|status|${cstatus}" >> "$TMPWORK/cstatus.txt"

done <<< "$containers"

if $SHOW_DOT; then
    echo "digraph docker_deps {"
    echo "  rankdir=LR;"
    echo "  node [shape=box, style=filled, fillcolor=lightgrey, fontname=\"sans\"];"
    echo ""

    while IFS='|' read -r cid cname cstatus cimage; do
        [ -z "$cid" ] && continue
        running=false
        case "$cstatus" in
            Up*) running=true ;;
        esac
        if $running; then
            echo "  \"$cname\" [fillcolor=lightgreen];"
        else
            echo "  \"$cname\" [fillcolor=lightcoral];"
        fi
    done <<< "$containers"

    echo ""

    if [ -f "$TMPWORK/deps.txt" ]; then
        while IFS='|' read -r cname dtype dtarget; do
            [ -z "$cname" ] && continue
            case "$dtype" in
                network) echo "  \"$cname\" -> \"$dtarget\" [color=blue, label=\"network\", style=dashed];" ;;
                volume) echo "  \"$cname\" -> \"$dtarget\" [color=orange, label=\"volume\", style=dotted];" ;;
                depends_on) echo "  \"$cname\" -> \"$dtarget\" [color=red, label=\"depends_on\"];" ;;
            esac
        done < "$TMPWORK/deps.txt" | sort -u
    fi

    echo "}"
    exit 0
fi

echo ""
echo -e "  ${BOLD}Docker Dependency Map${RESET}  ${DIM}v$VERSION${RESET}"

if [ -n "$FILTER_NETWORK" ]; then
    echo -e "  Filtro rede: ${CYAN}${FILTER_NETWORK}${RESET}"
fi
if [ -n "$FILTER_CONTAINER" ]; then
    echo -e "  Filtro container: ${CYAN}${FILTER_CONTAINER}${RESET}"
fi

echo ""

if $SHOW_TREE; then
    echo -e "  ${BOLD}── Arvore de Dependencias ──${RESET}"
    echo ""

    processed=""
    print_tree() {
        local name="$1"
        local indent="$2"

        if echo "$processed" | grep -q "\<${name}\>"; then
            echo -e "${indent}${DIM}${name} (ja listado)${RESET}"
            return
        fi
        processed="${processed} ${name}"

        local has_deps=false

        if [ -f "$TMPWORK/deps.txt" ]; then
            while IFS='|' read -r cname dtype dtarget; do
                [ -z "$cname" ] && continue
                if [ "$cname" = "$name" ]; then
                    has_deps=true
                    case "$dtype" in
                        network) echo -e "${indent}${CYAN}├─ net:${RESET} ${dtarget}" ;;
                        volume) echo -e "${indent}${YELLOW}├─ vol:${RESET} ${dtarget}" ;;
                        depends_on) echo -e "${indent}${RED}├─ dep:${RESET} ${dtarget}"; print_tree "$dtarget" "${indent}│  " ;;
                    esac
                fi
            done < "$TMPWORK/deps.txt"
        fi

        if ! $has_deps; then
            echo -e "${indent}${DIM}└─ (sem deps)${RESET}"
        fi
    }

    while IFS='|' read -r cid cname cstatus cimage; do
        [ -z "$cid" ] && continue
        is_running=false
        case "$cstatus" in
            Up*) is_running=true ;;
        esac
        if $is_running; then
            echo -e "  ${GREEN}●${RESET} ${BOLD}${cname}${RESET}"
        else
            echo -e "  ${RED}○${RESET} ${BOLD}${cname}${RESET}"
        fi
        print_tree "$cname" "    "
        echo ""
    done <<< "$containers"

else
    echo -e "  ${BOLD}── Dependencias por Container ──${RESET}"
    echo ""

    while IFS='|' read -r cid cname cstatus cimage; do
        [ -z "$cid" ] && continue

        is_running=false
        case "$cstatus" in
            Up*) is_running=true ;;
        esac

        status_icon="${GREEN}●${RESET}"
        if ! $is_running; then
            status_icon="${RED}○${RESET}"
        fi

        echo -e "  ${status_icon} ${BOLD}${cname}${RESET}  ${DIM}(${cimage})${RESET}"

        if [ -f "$TMPWORK/deps.txt" ]; then
            net_count=$(grep "^${cname}|network|" "$TMPWORK/deps.txt" 2>/dev/null | wc -l | tr -d ' ')
            vol_count=$(grep "^${cname}|volume|" "$TMPWORK/deps.txt" 2>/dev/null | wc -l | tr -d ' ')
            dep_count=$(grep "^${cname}|depends_on|" "$TMPWORK/deps.txt" 2>/dev/null | wc -l | tr -d ' ')
            [[ "$net_count" =~ ^[0-9]+$ ]] || net_count=0
            [[ "$vol_count" =~ ^[0-9]+$ ]] || vol_count=0
            [[ "$dep_count" =~ ^[0-9]+$ ]] || dep_count=0

            echo -e "    ${CYAN}Redes:${RESET} $net_count  ${YELLOW}Volumes:${RESET} $vol_count  ${RED}Depends_on:${RESET} $dep_count"
        fi

        echo ""
    done <<< "$containers"

    echo -e "  ${BOLD}── Dependencias por Rede ──${RESET}"
    echo ""

    if [ -f "$TMPWORK/deps.txt" ]; then
        grep '|network|' "$TMPWORK/deps.txt" 2>/dev/null | sort -t'|' -k3 | awk -F'|' '{print $3}' | sort -u | while read -r net; do
            [ -z "$net" ] && continue
            members=$(grep "|network|${net}" "$TMPWORK/deps.txt" 2>/dev/null | cut -d'|' -f1 | sort -u)
            member_count=$(echo "$members" | grep -c '.' || echo 0)
            member_count=$(echo "$member_count" | tr -d '[:space:]')
            echo -e "  ${CYAN}${net}${RESET} (${BOLD}$member_count${RESET} container(s))"
            echo "$members" | while IFS= read -r m; do
                [ -z "$m" ] && continue
                echo -e "    └─ ${m}"
            done
            echo ""
        done
    fi

    echo -e "  ${BOLD}── Volumes Compartilhados ──${RESET}"
    echo ""

    if [ -f "$TMPWORK/deps.txt" ]; then
        shared_volumes=$(grep '|volume|' "$TMPWORK/deps.txt" 2>/dev/null | sort -t'|' -k3 | awk -F'|' '{print $3}' | sort | uniq -d)
        if [ -n "$shared_volumes" ]; then
            echo "$shared_volumes" | while IFS= read -r vol; do
                [ -z "$vol" ] && continue
                members=$(grep "|volume|${vol}$" "$TMPWORK/deps.txt" 2>/dev/null | cut -d'|' -f1 | sort -u)
                echo -e "  ${YELLOW}${vol}${RESET}"
                echo "$members" | while IFS= read -r m; do
                    [ -z "$m" ] && continue
                    echo -e "    └─ ${m}"
                done
                echo ""
            done
        else
            echo -e "  ${DIM}Nenhum volume compartilhado entre containers.${RESET}"
            echo ""
        fi
    fi
fi

echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Analise concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""