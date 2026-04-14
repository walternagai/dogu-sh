#!/bin/bash
# docker-clean.sh — Limpa recursos nao utilizados do Docker (Linux)
# Uso: ./docker-clean.sh
# Opcoes:
#   --dry-run       Preview sem remover
#   --all           Remove tudo (inclui imagens paradas, volumes, networks)
#   --deep          Limpeza profunda (system prune + builder prune)
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "docker" "$INSTALLER docker.io"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
CLEAN_ALL=false
DEEP=false

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --all|-a) CLEAN_ALL=true; shift ;;
        --deep|-d) DEEP=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-clean.sh — Limpa recursos nao utilizados do Docker"
            echo ""
            echo "  Uso: ./docker-clean.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem remover"
            echo "    --all         Remove tudo sem confirmacao"
            echo "    --deep        Limpeza profunda (system prune + builder prune)"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Recursos limpos:"
            echo "    Containers parados"
            echo "    Imagens dangling (sem tag)"
            echo "    Volumes nao utilizados (--all)"
            echo "    Networks nao utilizadas"
            echo "    Build cache (--deep)"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-clean.sh --dry-run"
            echo "    ./docker-clean.sh --all"
            echo "    ./docker-clean.sh --deep --all"
            echo ""
            exit 0
            ;;
        --version|-v) echo "docker-clean.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null; then
    echo -e "  ${RED}Erro: docker nao encontrado.${RESET}" >&2
    echo -e "  ${DIM}Instale: https://docs.docker.com/engine/install/${RESET}" >&2
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: daemon do Docker nao esta rodando.${RESET}" >&2
    echo -e "  ${DIM}Inicie com: sudo systemctl start docker${RESET}" >&2
    exit 1
fi

human_size() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0 B"
        return
    fi
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

docker_size_bytes() {
    local raw
    raw=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1)
    echo "$raw"
}

confirm_action() {
    local label="$1"
    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} $label"
        return 0
    fi
    if $CLEAN_ALL; then
        return 0
    fi
    printf "  %s? [s/N]: " "$label"
    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    case "$confirm" in
        [sS]|[yY]*) return 0 ;;
        *) return 1 ;;
    esac
}

echo ""
echo -e "  ${BOLD}Docker Clean${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem remover"
fi

echo ""

# -- Disco antes --
before_disk=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1)

# -- Status atual --
echo -e "  ${BOLD}Uso atual do Docker:${RESET}"
echo ""
docker system df 2>/dev/null | while IFS= read -r line; do
    echo -e "  $line"
done
echo ""

# -- Containers parados --
echo -e "  ${BOLD}── Containers Parados ──${RESET}"
echo ""

stopped_count=$(docker ps -a -f status=exited -q 2>/dev/null | wc -l | tr -d ' ')

if [ "$stopped_count" -eq 0 ]; then
    echo -e "  ${DIM}Nenhum container parado.${RESET}"
else
    echo -e "  ${YELLOW}$stopped_count${RESET} container(s) parado(s):"
    docker ps -a -f status=exited --format "    {{.ID}}  {{.Names}}  {{.Image}}  {{.Status}}" 2>/dev/null
    echo ""

    if confirm_action "Remover $stopped_count container(s) parado(s)"; then
        if $DRY_RUN; then
            : 
        else
            docker container prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} Containers parados removidos"
        fi
    fi
fi

echo ""

# -- Imagens dangling --
echo -e "  ${BOLD}── Imagens Dangling ──${RESET}"
echo ""

dangling_count=$(docker images -f dangling=true -q 2>/dev/null | sort -u | wc -l | tr -d ' ')

if [ "$dangling_count" -eq 0 ]; then
    echo -e "  ${DIM}Nenhuma imagem dangling.${RESET}"
else
    echo -e "  ${YELLOW}$dangling_count${RESET} imagem(ns) dangling (sem tag):"
    docker images -f dangling=true --format "    {{.Repository}}:{{.Tag}}  {{.ID}}  {{.Size}}" 2>/dev/null
    echo ""

    if confirm_action "Remover $dangling_count imagem(ns) dangling"; then
        if $DRY_RUN; then
            : 
        else
            docker image prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} Imagens dangling removidas"
        fi
    fi
fi

echo ""

# -- Imagens nao usadas --
if $CLEAN_ALL || $DEEP; then
    echo -e "  ${BOLD}── Imagens Nao Utilizadas ──${RESET}"
    echo ""

    unused_count=$(docker images -f dangling=false -q 2>/dev/null | sort -u | wc -l | tr -d ' ')

    if [ "$unused_count" -eq 0 ]; then
        echo -e "  ${DIM}Nenhuma imagem nao utilizada.${RESET}"
    else
        echo -e "  ${YELLOW}$unused_count${RESET} imagem(ns) no total"
        echo ""

        if confirm_action "Remover imagens nao utilizadas por containers"; then
            if $DRY_RUN; then
                : 
            else
                docker image prune -a -f &>/dev/null
                echo -e "  ${GREEN}✓${RESET} Imagens nao utilizadas removidas"
            fi
        fi
    fi

    echo ""
fi

# -- Volumes --
echo -e "  ${BOLD}── Volumes Nao Utilizados ──${RESET}"
echo ""

volume_count=$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l | tr -d ' ')

if [ "$volume_count" -eq 0 ]; then
    echo -e "  ${DIM}Nenhum volume nao utilizado.${RESET}"
else
    echo -e "  ${YELLOW}$volume_count${RESET} volume(s) nao utilizado(s):"
    docker volume ls -f dangling=true --format "    {{.Name}}" 2>/dev/null
    echo ""

    if confirm_action "Remover $volume_count volume(s)"; then
        if $DRY_RUN; then
            : 
        else
            docker volume prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} Volumes removidos"
        fi
    fi
fi

echo ""

# -- Networks --
echo -e "  ${BOLD}── Networks Nao Utilizadas ──${RESET}"
echo ""

network_count=$(docker network ls -f type=custom -q 2>/dev/null | wc -l | tr -d ' ')

if [ "$network_count" -eq 0 ]; then
    echo -e "  ${DIM}Nenhuma network customizada nao utilizada.${RESET}"
else
    echo -e "  ${YELLOW}$network_count${RESET} network(s) customizada(s):"
    docker network ls -f type=custom --format "    {{.Name}}  {{.Driver}}  {{.Scope}}" 2>/dev/null
    echo ""

    if confirm_action "Remover networks nao utilizadas"; then
        if $DRY_RUN; then
            : 
        else
            docker network prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} Networks removidas"
        fi
    fi
fi

echo ""

# -- Build cache --
if $DEEP; then
    echo -e "  ${BOLD}── Build Cache ──${RESET}"
    echo ""

    if confirm_action "Remover build cache do Docker"; then
        if $DRY_RUN; then
            : 
        else
            docker builder prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} Build cache removido"
        fi
    fi

    echo ""
fi

# -- System prune --
if $DEEP; then
    echo -e "  ${BOLD}── System Prune ──${RESET}"
    echo ""

    echo -e "  ${RED}ATENCAO: Isso remove TUDO nao utilizado (containers, imagens, networks, build cache)${RESET}"
    echo ""

    if confirm_action "Executar docker system prune"; then
        if $DRY_RUN; then
            : 
        else
            docker system prune -f &>/dev/null
            echo -e "  ${GREEN}✓${RESET} System prune concluido"
        fi
    fi

    echo ""
fi

# -- Disco depois --
echo -e "  ${BOLD}Uso apos limpeza:${RESET}"
echo ""
docker system df 2>/dev/null | while IFS= read -r line; do
    echo -e "  $line"
done

echo ""
echo "  ─────────────────────────────────"

if $DRY_RUN; then
    echo -e "  ${DIM}Execute sem --dry-run para remover.${RESET}"
else
    echo -e "  ${GREEN}✓ Limpeza do Docker concluida${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""