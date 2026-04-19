#!/bin/bash
# docker-network-manager.sh — Gerencia redes Docker (criar, remover, conectar, desconectar)
# Uso: ./docker-network-manager.sh [opcoes]
# Opcoes:
#   --list                  Lista todas as redes (padrao)
#   --create NOME           Cria uma rede bridge
#   --create NOME --driver DRIVER  Cria rede com driver especifico
#   --remove NOME           Remove uma rede
#   --connect REDE CONTAINER  Conecta container a rede
#   --disconnect REDE CONTAINER Desconecta container de rede
#   --inspect REDE          Inspeciona detalhes de uma rede
#   --prune                 Remove redes nao utilizadas
#   --dry-run               Preview sem executar
#   --help                  Mostra esta ajuda
#   --version               Mostra versao

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
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER" "docker.io"; fi




ACTION="list"
NETWORK_NAME=""
CONTAINER_NAME=""
DRIVER="bridge"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --list|-l) ACTION="list"; shift ;;
        --create|-c)
            [[ -z "${2-}" ]] && { echo "Flag --create requer um valor" >&2; exit 1; }
            ACTION="create"; NETWORK_NAME="$2"; shift 2 ;;
        --remove|-r)
            [[ -z "${2-}" ]] && { echo "Flag --remove requer um valor" >&2; exit 1; }
            ACTION="remove"; NETWORK_NAME="$2"; shift 2 ;;
        --connect) ACTION="connect"; NETWORK_NAME="$2"; CONTAINER_NAME="$3"; shift 3 ;;
        --disconnect) ACTION="disconnect"; NETWORK_NAME="$2"; CONTAINER_NAME="$3"; shift 3 ;;
        --inspect|-i)
            [[ -z "${2-}" ]] && { echo "Flag --inspect requer um valor" >&2; exit 1; }
            ACTION="inspect"; NETWORK_NAME="$2"; shift 2 ;;
        --prune|-p) ACTION="prune"; shift ;;
        --driver|-d)
            [[ -z "${2-}" ]] && { echo "Flag --driver requer um valor" >&2; exit 1; }
            DRIVER="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-network-manager.sh — Gerencia redes Docker"
            echo ""
            echo "  Uso: ./docker-network-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --list                   Lista todas as redes (padrao)"
            echo "    --create NOME            Cria uma rede bridge"
            echo "    --create NOME --driver D Cria rede com driver especifico"
            echo "    --remove NOME            Remove uma rede"
            echo "    --connect REDE CONTAINER Conecta container a rede"
            echo "    --disconnect REDE CONTAINER Desconecta container de rede"
            echo "    --inspect REDE           Inspeciona detalhes de uma rede"
            echo "    --prune                  Remove redes nao utilizadas"
            echo "    --dry-run                Preview sem executar"
            echo "    --help                   Mostra esta ajuda"
            echo "    --version                Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-network-manager.sh --list"
            echo "    ./docker-network-manager.sh --create minha-rede"
            echo "    ./docker-network-manager.sh --create minha-rede --driver overlay"
            echo "    ./docker-network-manager.sh --connect minha-rede meu-container"
            echo "    ./docker-network-manager.sh --inspect bridge"
            echo "    ./docker-network-manager.sh --prune"
            echo ""
            exit 0
            ;;
        --version|-V) echo "docker-network-manager.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

echo ""
echo -e "  ${BOLD}Docker Network Manager${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo ""

case "$ACTION" in
    list)
        echo -e "  ${BOLD}── Redes Docker ──${RESET}"
        echo ""

        total_networks=$(docker network ls -q 2>/dev/null | wc -l | tr -d ' ')
        custom_networks=$(docker network ls -f type=custom -q 2>/dev/null | wc -l | tr -d ' ')

        echo -e "  Total: ${BOLD}$total_networks${RESET} rede(s)  |  Customizadas: ${BOLD}$custom_networks${RESET}"
        echo ""

        printf "  %-20s %-12s %-10s %-12s %s\n" "NOME" "DRIVER" "ESCOPO" "SUBNET" "CONTAINERS"
        printf "  %-20s %-12s %-10s %-12s %s\n" "────────────────────" "──────────" "────────" "────────────" "──────────"

        for net_id in $(docker network ls -q 2>/dev/null); do
            net_name=$(docker network inspect --format '{{.Name}}' "$net_id" 2>/dev/null)
            net_driver=$(docker network inspect --format '{{.Driver}}' "$net_id" 2>/dev/null)
            net_scope=$(docker network inspect --format '{{.Scope}}' "$net_id" 2>/dev/null)

            subnet=$(docker network inspect --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$net_id" 2>/dev/null | head -1)
            if [ -z "$subnet" ]; then
                subnet=$(docker network inspect --format '{{range .Containers}}{{.IPv4Address}}{{end}}' "$net_id" 2>/dev/null | head -1)
                subnet="${subnet:-—}"
            fi

            container_count=$(docker network inspect --format '{{len .Containers}}' "$net_id" 2>/dev/null)

            short_name=$(echo "$net_name" | cut -c1-18)
            short_subnet=$(echo "$subnet" | cut -c1-18)

            case "$net_driver" in
                bridge) name_style="${DIM}" ;;
                host) name_style="${DIM}" ;;
                null) name_style="${DIM}" ;;
        --) shift; break ;;
                *) name_style="${CYAN}" ;;
            esac

            printf "  ${name_style}%-20s${RESET} %-12s %-10s %-12s %s\n" "$short_name" "$net_driver" "$net_scope" "$short_subnet" "$container_count"
        done

        echo ""
        ;;

    create)
        if [ -z "$NETWORK_NAME" ]; then
            echo -e "  ${RED}Erro: especifique o nome da rede.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-network-manager.sh --create NOME${RESET}"
            exit 1
        fi

        existing=$(docker network ls -q -f name="^${NETWORK_NAME}$" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$existing" -gt 0 ]; then
            echo -e "  ${YELLOW}Rede '${NETWORK_NAME}' ja existe.${RESET}"
            exit 0
        fi

        echo -e "  Criando rede ${CYAN}${NETWORK_NAME}${RESET} (driver: ${BOLD}$DRIVER${RESET})"
        echo ""

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker network create --driver $DRIVER $NETWORK_NAME${RESET}"
        else
            if docker network create --driver "$DRIVER" "$NETWORK_NAME" &>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} Rede ${CYAN}${NETWORK_NAME}${RESET} criada com sucesso"
            else
                echo -e "  ${RED}✗${RESET} Falha ao criar rede ${NETWORK_NAME}"
                exit 1
            fi
        fi
        ;;

    remove)
        if [ -z "$NETWORK_NAME" ]; then
            echo -e "  ${RED}Erro: especifique o nome da rede.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-network-manager.sh --remove NOME${RESET}"
            exit 1
        fi

        if [ "$NETWORK_NAME" = "bridge" ] || [ "$NETWORK_NAME" = "host" ] || [ "$NETWORK_NAME" = "none" ]; then
            echo -e "  ${RED}Erro: nao e possivel remover redes pre-definidas do Docker.${RESET}"
            exit 1
        fi

        echo -e "  Removendo rede ${CYAN}${NETWORK_NAME}${RESET}"
        echo ""

        printf "  Confirmar remocao da rede ${CYAN}${NETWORK_NAME}${RESET}? [s/N]: "
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS])
                ;;
        --) shift; break ;;
            *)
                echo -e "  ${DIM}Remocao cancelada.${RESET}"
                ;;
        esac

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker network rm $NETWORK_NAME${RESET}"
        else
            if docker network rm "$NETWORK_NAME" &>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} Rede ${CYAN}${NETWORK_NAME}${RESET} removida"
            else
                echo -e "  ${RED}✗${RESET} Falha ao remover rede ${NETWORK_NAME}"
                exit 1
            fi
        fi
        ;;

    connect)
        if [ -z "$NETWORK_NAME" ] || [ -z "$CONTAINER_NAME" ]; then
            echo -e "  ${RED}Erro: especifique REDE e CONTAINER.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-network-manager.sh --connect REDE CONTAINER${RESET}"
            exit 1
        fi

        echo -e "  Conectando ${CYAN}${CONTAINER_NAME}${RESET} a rede ${CYAN}${NETWORK_NAME}${RESET}"

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker network connect $NETWORK_NAME $CONTAINER_NAME${RESET}"
        else
            if docker network connect "$NETWORK_NAME" "$CONTAINER_NAME" &>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} ${CONTAINER_NAME} conectado a ${NETWORK_NAME}"
            else
                echo -e "  ${RED}✗${RESET} Falha ao conectar ${CONTAINER_NAME} a ${NETWORK_NAME}"
                exit 1
            fi
        fi
        ;;

    disconnect)
        if [ -z "$NETWORK_NAME" ] || [ -z "$CONTAINER_NAME" ]; then
            echo -e "  ${RED}Erro: especifique REDE e CONTAINER.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-network-manager.sh --disconnect REDE CONTAINER${RESET}"
            exit 1
        fi

        echo -e "  Desconectando ${CYAN}${CONTAINER_NAME}${RESET} da rede ${CYAN}${NETWORK_NAME}${RESET}"

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker network disconnect $NETWORK_NAME $CONTAINER_NAME${RESET}"
        else
            if docker network disconnect "$NETWORK_NAME" "$CONTAINER_NAME" &>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} ${CONTAINER_NAME} desconectado de ${NETWORK_NAME}"
            else
                echo -e "  ${RED}✗${RESET} Falha ao desconectar ${CONTAINER_NAME} de ${NETWORK_NAME}"
                exit 1
            fi
        fi
        ;;

    inspect)
        if [ -z "$NETWORK_NAME" ]; then
            echo -e "  ${RED}Erro: especifique o nome da rede.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-network-manager.sh --inspect NOME${RESET}"
            exit 1
        fi

        echo -e "  ${BOLD}── Inspecao: ${NETWORK_NAME} ──${RESET}"
        echo ""

        inspect_ok=false
        docker network inspect "$NETWORK_NAME" 2>/dev/null && inspect_ok=true
        if ! $inspect_ok; then
            echo -e "  ${RED}Rede '${NETWORK_NAME}' nao encontrada.${RESET}"
            exit 1
        fi

        docker network inspect "$NETWORK_NAME" 2>/dev/null | while IFS= read -r line; do
            echo -e "  $line"
        done
        ;;

    prune)
        custom_count=$(docker network ls -f type=custom -q 2>/dev/null | wc -l | tr -d ' ')
        unused_count=$(docker network ls -q 2>/dev/null | while read -r nid; do
            cnt=$(docker network inspect --format '{{len .Containers}}' "$nid" 2>/dev/null)
            if [ "${cnt:-0}" = "0" ]; then echo "$nid"; fi
        done | wc -l | tr -d ' ')

        echo -e "  ${BOLD}── Remover redes nao utilizadas ──${RESET}"
        echo ""
        echo -e "  Redes customizadas: ${BOLD}$custom_count${RESET}"
        echo -e "  Redes sem containers: ${BOLD}$unused_count${RESET}"
        echo ""

        printf "  Confirmar remocao de redes nao utilizadas? [s/N]: "
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS])
                ;;
        --) shift; break ;;
            *)
                echo -e "  ${DIM}Prune cancelado.${RESET}"
                ;;
        esac

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker network prune${RESET}"
        else
            docker network prune -f 2>/dev/null
            echo -e "  ${GREEN}✓${RESET} Redes nao utilizadas removidas"
        fi
        ;;
esac

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Operacao concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""