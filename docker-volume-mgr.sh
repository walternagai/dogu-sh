#!/bin/bash
# docker-volume-mgr.sh — Lista, identifica orfaos, faz backup e restaura volumes Docker
# Uso: ./docker-volume-mgr.sh [opcoes]
# Opcoes:
#   --list              Lista todos os volumes (padrao)
#   --orphans           Mostra volumes sem container associado
#   --size              Mostra tamanho de cada volume
#   --remove VOLUME     Remove um volume especifico
#   --remove-orphans    Remove todos os volumes orfaos
#   --backup VOLUME     Faz backup de um volume para tar.gz
#   --restore VOLUME FILE Restaura volume a partir de tar.gz
#   --output DIR        Diretorio de destino para backup (padrao: .)
#   --dry-run           Preview sem executar
#   --help              Mostra esta ajuda
#   --version           Mostra versao

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

ACTION="list"
VOLUME_NAME=""
RESTORE_FILE=""
OUTPUT_DIR="."
DRY_RUN=false
SHOW_SIZE=false

while [ $# -gt 0 ]; do
    case "$1" in
        --list|-l) ACTION="list"; shift ;;
        --orphans|-o) ACTION="orphans"; shift ;;
        --size|-s) SHOW_SIZE=true; shift ;;
        --remove|-r) ACTION="remove"; VOLUME_NAME="$2"; shift 2 ;;
        --remove-orphans) ACTION="remove-orphans"; shift ;;
        --backup|-b) ACTION="backup"; VOLUME_NAME="$2"; shift 2 ;;
        --restore) ACTION="restore"; VOLUME_NAME="$2"; RESTORE_FILE="$3"; shift 3 ;;
        --output|-O) OUTPUT_DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-volume-mgr.sh — Gerencia volumes Docker"
            echo ""
            echo "  Uso: ./docker-volume-mgr.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --list              Lista todos os volumes (padrao)"
            echo "    --orphans           Mostra volumes sem container associado"
            echo "    --size              Mostra tamanho de cada volume"
            echo "    --remove VOLUME     Remove um volume especifico"
            echo "    --remove-orphans    Remove volumes orfaos"
            echo "    --backup VOLUME     Backup de volume para tar.gz"
            echo "    --restore VOLUME FILE Restaura volume de tar.gz"
            echo "    --output DIR        Diretorio de destino (padrao: .)"
            echo "    --dry-run           Preview sem executar"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-volume-mgr.sh --list --size"
            echo "    ./docker-volume-mgr.sh --orphans"
            echo "    ./docker-volume-mgr.sh --backup meu_volume --output /tmp"
            echo "    ./docker-volume-mgr.sh --restore meu_volume /tmp/meu_volume.tar.gz"
            echo "    ./docker-volume-mgr.sh --remove-orphans --dry-run"
            echo ""
            exit 0
            ;;
        --version) echo "docker-volume-mgr.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

format_bytes() {
    bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "0 B"; return; fi
    if [ "$bytes" -ge 1073741824 ]; then echo "$(echo "scale=1; $bytes / 1073741824" | bc)GB"
    elif [ "$bytes" -ge 1048576 ]; then echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
    elif [ "$bytes" -ge 1024 ]; then echo "$((bytes / 1024))KB"
    else echo "${bytes}B"
    fi
}

get_volume_size() {
    vname="$1"
    mountpoint
    mountpoint=$(docker volume inspect --format '{{.Mountpoint}}' "$vname" 2>/dev/null)
    if [ -d "$mountpoint" ] 2>/dev/null; then
        sz
        sz=$(sudo du -sb "$mountpoint" 2>/dev/null | awk '{print $1}')
        if [ -n "$sz" ] && [[ "$sz" =~ ^[0-9]+$ ]]; then
            echo "$sz"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

is_orphan() {
    vname="$1"
    count
    count=$(docker ps -a --filter "volume=$vname" -q 2>/dev/null | wc -l | tr -d ' ')
    [[ "$count" =~ ^[0-9]+$ ]] || count=0
    [ "$count" -eq 0 ]
}

echo ""
echo -e "  ${BOLD}Docker Volume Manager${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo ""

case "$ACTION" in
    list)
        echo -e "  ${BOLD}── Volumes Docker ──${RESET}"
        echo ""

        volumes=$(docker volume ls -q 2>/dev/null)
        total=$(echo "$volumes" | grep -c '.' || echo 0)
        total=$(echo "$total" | tr -d ' ')

        if [ "$total" -eq 0 ] || [ -z "$volumes" ]; then
            echo -e "  ${DIM}Nenhum volume encontrado.${RESET}"
        else
            if $SHOW_SIZE; then
                printf "  %-30s %-12s %-10s %-12s %s\n" "NOME" "DRIVER" "TAMANHO" "ORFAO" "MOUNTPOINT"
                printf "  %-30s %-12s %-10s %-12s %s\n" "──────────────────────────" "──────────" "────────" "──────────" "──────────────"
            else
                printf "  %-30s %-12s %-10s %s\n" "NOME" "DRIVER" "ORFAO" "MOUNTPOINT"
                printf "  %-30s %-12s %-10s %s\n" "──────────────────────────" "──────────" "────────" "──────────────"
            fi

            while IFS= read -r vname; do
                [ -z "$vname" ] && continue
                driver
                driver=$(docker volume inspect --format '{{.Driver}}' "$vname" 2>/dev/null)
                mountpoint
                mountpoint=$(docker volume inspect --format '{{.Mountpoint}}' "$vname" 2>/dev/null)
                short_name=$(echo "$vname" | cut -c1-28)
                short_mount=$(echo "$mountpoint" | cut -c1-28)
                orphan_label="nao"
                orphan_style="${DIM}"
                if is_orphan "$vname"; then
                    orphan_label="sim"
                    orphan_style="${YELLOW}"
                fi

                if $SHOW_SIZE; then
                    sz=$(get_volume_size "$vname")
                    size_str=$(format_bytes "$sz")
                    printf "  %-30s %-12s %-10s ${orphan_style}%-12s${RESET} %s\n" "$short_name" "$driver" "$size_str" "$orphan_label" "$short_mount"
                else
                    printf "  %-30s %-12s ${orphan_style}%-10s${RESET} %s\n" "$short_name" "$driver" "$orphan_label" "$short_mount"
                fi
            done <<< "$volumes"
        fi

        echo ""

        orphan_count=0
        while IFS= read -r vname; do
            [ -z "$vname" ] && continue
            if is_orphan "$vname"; then
                orphan_count=$((orphan_count + 1))
            fi
        done <<< "$volumes"

        echo -e "  Total: ${BOLD}$total${RESET} volume(s)  |  Orfaos: ${YELLOW}${BOLD}$orphan_count${RESET}"
        ;;

    orphans)
        echo -e "  ${BOLD}── Volumes Orfaos ──${RESET}"
        echo ""

        orphan_list=""
        orphan_count=0
        while IFS= read -r vname; do
            [ -z "$vname" ] && continue
            if is_orphan "$vname"; then
                orphan_list="${orphan_list}${vname}\n"
                orphan_count=$((orphan_count + 1))
            fi
        done <<< "$(docker volume ls -q 2>/dev/null)"

        if [ "$orphan_count" -eq 0 ]; then
            echo -e "  ${GREEN}✓${RESET} Nenhum volume orfao encontrado"
        else
            echo -e "  ${YELLOW}$orphan_count${RESET} volume(s) orfao(s):"
            echo ""
            printf "  %-30s %-12s %-10s\n" "NOME" "DRIVER" "TAMANHO"
            printf "  %-30s %-12s %-10s\n" "──────────────────────────" "──────────" "────────"

            echo -ne "$orphan_list" | while IFS= read -r vname; do
                [ -z "$vname" ] && continue
                driver
                driver=$(docker volume inspect --format '{{.Driver}}' "$vname" 2>/dev/null)
                short_name=$(echo "$vname" | cut -c1-28)
                sz="?"
                if $SHOW_SIZE; then
                    sz=$(format_bytes "$(get_volume_size "$vname")")
                fi
                printf "  %-30s %-12s %-10s\n" "$short_name" "$driver" "$sz"
            done
        fi

        echo ""
        ;;

    remove)
        if [ -z "$VOLUME_NAME" ]; then
            echo -e "  ${RED}Erro: especifique o nome do volume.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-volume-mgr.sh --remove NOME${RESET}"
            exit 1
        fi

        if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
            echo -e "  ${RED}Volume '${VOLUME_NAME}' nao encontrado.${RESET}"
            exit 1
        fi

        echo -e "  Removendo volume ${CYAN}${VOLUME_NAME}${RESET}"

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker volume rm $VOLUME_NAME${RESET}"
        else
            if docker volume rm "$VOLUME_NAME" &>/dev/null; then
                echo -e "  ${GREEN}✓${RESET} Volume ${CYAN}${VOLUME_NAME}${RESET} removido"
            else
                echo -e "  ${RED}✗${RESET} Falha ao remover volume (pode estar em uso)"
                exit 1
            fi
        fi
        ;;

    remove-orphans)
        echo -e "  ${BOLD}── Removendo Volumes Orfaos ──${RESET}"
        echo ""

        orphan_count=0
        while IFS= read -r vname; do
            [ -z "$vname" ] && continue
            if is_orphan "$vname"; then
                orphan_count=$((orphan_count + 1))
            fi
        done <<< "$(docker volume ls -q 2>/dev/null)"

        if [ "$orphan_count" -eq 0 ]; then
            echo -e "  ${GREEN}✓${RESET} Nenhum volume orfao para remover"
        else
            echo -e "  ${YELLOW}$orphan_count${RESET} volume(s) orfao(s) serao removidos:"

            while IFS= read -r vname; do
                [ -z "$vname" ] && continue
                if is_orphan "$vname"; then
                    if $DRY_RUN; then
                        echo -e "  ${DIM}[dry-run] docker volume rm $vname${RESET}"
                    else
                        if docker volume rm "$vname" &>/dev/null; then
                            echo -e "  ${GREEN}✓${RESET} $vname removido"
                        else
                            echo -e "  ${RED}✗${RESET} Falha ao remover $vname"
                        fi
                    fi
                fi
            done <<< "$(docker volume ls -q 2>/dev/null)"
        fi
        ;;

    backup)
        if [ -z "$VOLUME_NAME" ]; then
            echo -e "  ${RED}Erro: especifique o nome do volume.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-volume-mgr.sh --backup NOME [--output DIR]${RESET}"
            exit 1
        fi

        if ! docker volume inspect "$VOLUME_NAME" &>/dev/null; then
            echo -e "  ${RED}Volume '${VOLUME_NAME}' nao encontrado.${RESET}"
            exit 1
        fi

        mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

        output_file="${OUTPUT_DIR}/${VOLUME_NAME}_$(date +%Y%m%d_%H%M%S).tar.gz"

        echo -e "  Backup de ${CYAN}${VOLUME_NAME}${RESET}"
        echo -e "  Destino: ${BOLD}$output_file${RESET}"
        echo ""

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker run --rm -v ${VOLUME_NAME}:/volume -v $(pwd):/backup alpine tar czf /backup/${output_file} -C /volume .${RESET}"
        else
            backup_ok=false
            docker run --rm \
                -v "${VOLUME_NAME}:/volume:ro" \
                -v "$(cd "$OUTPUT_DIR" && pwd):/backup" \
                alpine tar czf "/backup/$(basename "$output_file")" -C /volume . 2>/dev/null && backup_ok=true

            if $backup_ok; then
                file_size=$(du -h "$output_file" 2>/dev/null | awk '{print $1}')
                echo -e "  ${GREEN}✓${RESET} Backup criado: ${BOLD}$output_file${RESET} ($file_size)"
            else
                echo -e "  ${RED}✗${RESET} Falha ao criar backup"
                exit 1
            fi
        fi
        ;;

    restore)
        if [ -z "$VOLUME_NAME" ] || [ -z "$RESTORE_FILE" ]; then
            echo -e "  ${RED}Erro: especifique VOLUME e ARQUIVO.${RESET}"
            echo -e "  ${DIM}Uso: ./docker-volume-mgr.sh --restore VOLUME ARQUIVO.tar.gz${RESET}"
            exit 1
        fi

        if [ ! -f "$RESTORE_FILE" ]; then
            echo -e "  ${RED}Arquivo '${RESTORE_FILE}' nao encontrado.${RESET}"
            exit 1
        fi

        vol_exists
        vol_exists=$(docker volume ls -q -f name="^${VOLUME_NAME}$" 2>/dev/null | wc -l | tr -d ' ')

        if [ "$vol_exists" -eq 0 ]; then
            echo -e "  Criando volume ${CYAN}${VOLUME_NAME}${RESET}..."
            docker volume create "$VOLUME_NAME" &>/dev/null
        else
            echo -e "  ${YELLOW}Volume '${VOLUME_NAME}' ja existe — dados serao sobrescritos.${RESET}"
        fi

        echo -e "  Restaurando ${CYAN}${VOLUME_NAME}${RESET} de ${BOLD}$RESTORE_FILE${RESET}"
        echo ""

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] docker run --rm -v ${VOLUME_NAME}:/volume -v ${RESTORE_FILE}:/backup.tar.gz alpine tar xzf /backup.tar.gz -C /volume${RESET}"
        else
            abs_restore=$(readlink -f "$RESTORE_FILE")
            restore_ok=false
            docker run --rm \
                -v "${VOLUME_NAME}:/volume" \
                -v "${abs_restore}:/backup.tar.gz:ro" \
                alpine tar xzf /backup.tar.gz -C /volume 2>/dev/null && restore_ok=true

            if $restore_ok; then
                echo -e "  ${GREEN}✓${RESET} Volume ${CYAN}${VOLUME_NAME}${RESET} restaurado com sucesso"
            else
                echo -e "  ${RED}✗${RESET} Falha ao restaurar volume"
                exit 1
            fi
        fi
        ;;
esac

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Operacao concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""