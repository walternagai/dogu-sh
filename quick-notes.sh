#!/bin/bash
# quick-notes.sh — Bloco de notas rapido com busca e tags
# Uso: ./quick-notes.sh [opcoes]
# Opcoes:
#   -a, --add NOTA      Adiciona nota (suporta #tags)
#   -s, --search TERM   Busca notas por termo
#   -t, --tag TAG       Lista notas por tag
#   -d, --delete ID     Remove nota por ID
#   -l, --list          Lista todas as notas (padrao)
#   -e, --edit ID       Edita nota no editor
#   --export FILE       Exporta notas para arquivo texto
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DATA_DIR="$HOME/.config/quick-notes"
mkdir -p "$DATA_DIR"
NOTES_FILE="$DATA_DIR/notes.csv"

ACTION="list"
ARG1=""
ARG2=""

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--add) ACTION="add"; ARG1="$2"; shift 2 ;;
        -s|--search) ACTION="search"; ARG1="$2"; shift 2 ;;
        -t|--tag) ACTION="tag"; ARG1="$2"; shift 2 ;;
        -d|--delete) ACTION="delete"; ARG1="$2"; shift 2 ;;
        -l|--list) ACTION="list"; shift ;;
        -e|--edit) ACTION="edit"; ARG1="$2"; shift 2 ;;
        --export) ACTION="export"; ARG1="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  quick-notes.sh — Bloco de notas rapido com busca e tags"
            echo ""
            echo "  Uso: ./quick-notes.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -a, --add NOTA      Adiciona nota (use #tags)"
            echo "    -s, --search TERM   Busca notas por termo"
            echo "    -t, --tag TAG       Lista notas por tag"
            echo "    -d, --delete ID     Remove nota por ID"
            echo "    -l, --list          Lista todas as notas"
            echo "    -e, --edit ID       Edita nota no editor"
            echo "    --export FILE       Exporta notas para arquivo"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./quick-notes.sh -a 'Reuniao as 14h #trabalho'"
            echo "    ./quick-notes.sh -s 'reuniao'"
            echo "    ./quick-notes.sh -t trabalho"
            echo ""
            exit 0
            ;;
        --version|-v) echo "quick-notes.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

[ ! -f "$NOTES_FILE" ] && echo "id|timestamp|nota" > "$NOTES_FILE"

next_id() {
    local max_id=0
    while IFS='|' read -r id rest; do
        [ "$id" -gt "$max_id" ] 2>/dev/null && max_id=$id
    done < "$NOTES_FILE" 2>/dev/null || true
    echo $((max_id + 1))
}

extract_tags() {
    echo "$1" | grep -oE '#[a-zA-Z0-9_]+' | tr '\n' ' ' | xargs
}

case "$ACTION" in
    add)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique a nota.${RESET}"
            exit 1
        fi
        id=$(next_id)
        now=$(date '+%Y-%m-%d %H:%M')
        tags=$(extract_tags "$ARG1")
        echo "${id}|${now}|${ARG1}" >> "$NOTES_FILE"
        echo -e "  ${GREEN}✓${RESET} Nota #${id} adicionada"
        if [ -n "$tags" ]; then
            echo -e "  ${DIM}Tags: ${tags}${RESET}"
        fi
        ;;

    search)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o termo de busca.${RESET}"
            exit 1
        fi
        echo ""
        echo -e "  ${BOLD}── Busca: '${ARG1}' ──${RESET}"
        echo ""
        found=false
        while IFS='|' read -r id timestamp nota; do
            [ "$id" = "id" ] && continue
            if echo "$nota" | grep -qi "$ARG1"; then
                found=true
                tags=$(extract_tags "$nota")
                printf "  ${CYAN}#%-4s${RESET} ${DIM}%s${RESET}  %s\n" "$id" "$timestamp" "$nota"
            fi
        done < "$NOTES_FILE" 2>/dev/null || true
        if ! $found; then
            echo -e "  ${DIM}Nenhum resultado.${RESET}"
        fi
        echo ""
        ;;

    tag)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique a tag.${RESET}"
            exit 1
        fi
        tag="#${ARG1#\#}"
        echo ""
        echo -e "  ${BOLD}── Tag: ${tag} ──${RESET}"
        echo ""
        found=false
        while IFS='|' read -r id timestamp nota; do
            [ "$id" = "id" ] && continue
            if echo "$nota" | grep -q "$tag"; then
                found=true
                printf "  ${CYAN}#%-4s${RESET} ${DIM}%s${RESET}  %s\n" "$id" "$timestamp" "$nota"
            fi
        done < "$NOTES_FILE" 2>/dev/null || true
        if ! $found; then
            echo -e "  ${DIM}Nenhuma nota com essa tag.${RESET}"
        fi
        echo ""
        ;;

    delete)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o ID.${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id timestamp nota; do
            if [ "$id" = "$ARG1" ]; then
                found=true
            else
                echo "${id}|${timestamp}|${nota}" >> "$tmp"
            fi
        done < "$NOTES_FILE"
        mv "$tmp" "$NOTES_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Nota #${ARG1} removida"
        else
            echo -e "  ${RED}Nota #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    edit)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o ID.${RESET}"
            exit 1
        fi
        old_note=""
        while IFS='|' read -r id timestamp nota; do
            if [ "$id" = "$ARG1" ]; then
                old_note="$nota"
                break
            fi
        done < "$NOTES_FILE" 2>/dev/null || true

        if [ -z "$old_note" ]; then
            echo -e "  ${RED}Nota #${ARG1} nao encontrada.${RESET}"
            exit 1
        fi

        tmp_file=$(mktemp)
        echo "$old_note" > "$tmp_file"
        ${EDITOR:-nano} "$tmp_file"
        new_note=$(cat "$tmp_file" | head -1)
        rm -f "$tmp_file"

        tmp=$(mktemp)
        while IFS='|' read -r id timestamp nota; do
            if [ "$id" = "$ARG1" ]; then
                echo "${id}|${timestamp}|${new_note}"
            else
                echo "${id}|${timestamp}|${nota}"
            fi
        done < "$NOTES_FILE" > "$tmp"
        mv "$tmp" "$NOTES_FILE"
        echo -e "  ${GREEN}✓${RESET} Nota #${ARG1} editada"
        ;;

    export)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o arquivo de destino.${RESET}"
            exit 1
        fi
        {
            echo "=== Quick Notes Export ==="
            echo "Exportado em: $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""
            while IFS='|' read -r id timestamp nota; do
                [ "$id" = "id" ] && continue
                echo "#${id} [${timestamp}] ${nota}"
            done < "$NOTES_FILE" 2>/dev/null || true
        } > "$ARG1"
        echo -e "  ${GREEN}✓${RESET} Notas exportadas para ${ARG1}"
        ;;

    list)
        echo ""
        echo -e "  ${BOLD}── Quick Notes ──${RESET}"
        echo ""
        total=0
        while IFS='|' read -r id timestamp nota; do
            [ "$id" = "id" ] && continue
            total=$((total + 1))
            tags=$(extract_tags "$nota")
            printf "  ${CYAN}#%-4s${RESET} ${DIM}%s${RESET}  %s\n" "$id" "$timestamp" "$nota"
        done < "$NOTES_FILE" 2>/dev/null || true
        if [ "$total" -eq 0 ]; then
            echo -e "  ${DIM}Nenhuma nota. Use -a para adicionar.${RESET}"
        fi
        echo ""
        ;;
esac