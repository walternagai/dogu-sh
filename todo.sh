#!/bin/bash
# todo.sh — Lista de tarefas com prioridades, categorias e persistencia
# Uso: ./todo.sh [opcoes]
# Opcoes:
#   -a, --add TAREFA    Adiciona tarefa (suporta @ctx e +proj)
#   -d, --done ID       Marca tarefa como concluida
#   -u, --undo ID       Desmarca tarefa concluida
#   -r, --remove ID     Remove tarefa
#   -l, --list FILTRO   Lista tarefas (all, done, pending, @ctx, +proj)
#   -e, --edit ID TXT   Edita texto da tarefa
#   -p, --pri ID PRI    Define prioridade (A-Z)
#   --clean             Remove tarefas concluidas
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

DATA_DIR="$HOME/.config/todo"
mkdir -p "$DATA_DIR"
TODO_FILE="$DATA_DIR/todo.txt"

ACTION="list"
ARG1=""
ARG2=""

while [ $# -gt 0 ]; do
    case "$1" in
        -a|--add) ACTION="add"; ARG1="$2"; shift 2 ;;
        -d|--done) ACTION="done"; ARG1="$2"; shift 2 ;;
        -u|--undo) ACTION="undo"; ARG1="$2"; shift 2 ;;
        -r|--remove) ACTION="remove"; ARG1="$2"; shift 2 ;;
        -l|--list) ACTION="list"; ARG1="${2:-pending}"; shift 2 ;;
        -e|--edit) ACTION="edit"; ARG1="$2"; ARG2="$3"; shift 3 ;;
        -p|--pri) ACTION="pri"; ARG1="$2"; ARG2="$3"; shift 3 ;;
        --clean) ACTION="clean"; shift ;;
        --help|-h)
            echo ""
            echo "  todo.sh — Lista de tarefas com prioridades e categorias"
            echo ""
            echo "  Uso: ./todo.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -a, --add TAREFA    Adiciona tarefa (use @ctx +proj)"
            echo "    -d, --done ID       Marca como concluida"
            echo "    -u, --undo ID       Desmarca conclusao"
            echo "    -r, --remove ID     Remove tarefa"
            echo "    -l, --list FILTRO   Lista: all, done, pending, @ctx, +proj"
            echo "    -e, --edit ID TXT   Edita tarefa"
            echo "    -p, --pri ID PRI    Define prioridade (A-Z)"
            echo "    --clean             Remove tarefas concluidas"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./todo.sh -a 'Comprar leite @compras +dom'"
            echo "    ./todo.sh -d 3"
            echo "    ./todo.sh -l @compras"
            echo "    ./todo.sh -p 1 A"
            echo ""
            exit 0
            ;;
        --version|-v) echo "todo.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

[ ! -f "$TODO_FILE" ] && touch "$TODO_FILE"

next_id() {
    local max_id=0
    while IFS='|' read -r id rest; do
        [ "$id" -gt "$max_id" ] 2>/dev/null && max_id=$id
    done < "$TODO_FILE" 2>/dev/null || true
    echo $((max_id + 1))
}

rewrite_file() {
    local tmp
    tmp=$(mktemp)
    while IFS= read -r line; do
        echo "$line"
    done > "$tmp"
    mv "$tmp" "$TODO_FILE"
}

case "$ACTION" in
    add)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique a tarefa.${RESET}"
            exit 1
        fi
        id=$(next_id)
        pri=""
        [[ "$ARG1" =~ ^\(([A-Z])\) ]] && pri="${BASH_REMATCH[1]}"
        now=$(date '+%Y-%m-%d')
        echo "${id}|${pri}|${ARG1}|${now}|pending" >> "$TODO_FILE"
        echo -e "  ${GREEN}✓${RESET} Tarefa #${id} adicionada"
        ;;

    done)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o ID.${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$id" = "$ARG1" ]; then
                found=true
                echo "${id}|${pri}|${text}|${date}|done" >> "$tmp"
            else
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Tarefa #${ARG1} concluida"
        else
            echo -e "  ${RED}Tarefa #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    undo)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o ID.${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$id" = "$ARG1" ]; then
                found=true
                echo "${id}|${pri}|${text}|${date}|pending" >> "$tmp"
            else
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Tarefa #${ARG1} reaberta"
        else
            echo -e "  ${RED}Tarefa #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    remove)
        if [ -z "$ARG1" ]; then
            echo -e "  ${RED}Erro: especifique o ID.${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$id" = "$ARG1" ]; then
                found=true
            else
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Tarefa #${ARG1} removida"
        else
            echo -e "  ${RED}Tarefa #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    edit)
        if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
            echo -e "  ${RED}Erro: especifique ID e novo texto.${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$id" = "$ARG1" ]; then
                found=true
                echo "${id}|${pri}|${ARG2}|${date}|${status}" >> "$tmp"
            else
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Tarefa #${ARG1} editada"
        else
            echo -e "  ${RED}Tarefa #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    pri)
        if [ -z "$ARG1" ] || [ -z "$ARG2" ]; then
            echo -e "  ${RED}Erro: especifique ID e prioridade (A-Z).${RESET}"
            exit 1
        fi
        found=false
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$id" = "$ARG1" ]; then
                found=true
                echo "${id}|${ARG2}|${text}|${date}|${status}" >> "$tmp"
            else
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        if $found; then
            echo -e "  ${GREEN}✓${RESET} Tarefa #${ARG1} prioridade: ${ARG2}"
        else
            echo -e "  ${RED}Tarefa #${ARG1} nao encontrada.${RESET}"
        fi
        ;;

    clean)
        tmp=$(mktemp)
        while IFS='|' read -r id pri text date status; do
            if [ "$status" != "done" ]; then
                echo "${id}|${pri}|${text}|${date}|${status}" >> "$tmp"
            fi
        done < "$TODO_FILE"
        mv "$tmp" "$TODO_FILE"
        echo -e "  ${GREEN}✓${RESET} Tarefas concluidas removidas"
        ;;

    list)
        filter="${ARG1:-pending}"
        echo ""
        echo -e "  ${BOLD}── Tarefas (${filter}) ──${RESET}"
        echo ""

        total=0
        pending=0
        done_count=0

        while IFS='|' read -r id pri text date status; do
            total=$((total + 1))
            if [ "$status" = "done" ]; then
                done_count=$((done_count + 1))
            else
                pending=$((pending + 1))
            fi

            show=true
            case "$filter" in
                all) show=true ;;
                done) [ "$status" = "done" ] || show=false ;;
                pending) [ "$status" = "pending" ] || show=false ;;
                @*) echo "$text" | grep -q "$filter" || show=false ;;
                +*) echo "$text" | grep -q "$filter" || show=false ;;
            esac

            if $show; then
                pri_str=""
                if [ -n "$pri" ]; then
                    case "$pri" in
                        A) pri_str="${RED}${BOLD}(${pri})${RESET}" ;;
                        B) pri_str="${YELLOW}${BOLD}(${pri})${RESET}" ;;
                        C) pri_str="${CYAN}${BOLD}(${pri})${RESET}" ;;
                        *) pri_str="${DIM}(${pri})${RESET}" ;;
                    esac
                fi

                if [ "$status" = "done" ]; then
                    echo -e "  ${DIM}#${id}  ${pri_str}  ${text}  ${date}  ✗${RESET}"
                else
                    echo -e "  #${id}  ${pri_str}  ${text}  ${DIM}${date}${RESET}"
                fi
            fi
        done < "$TODO_FILE" 2>/dev/null || true

        echo ""
        echo -e "  ${DIM}Total: ${total} | Pendentes: ${pending} | Concluidas: ${done_count}${RESET}"
        echo ""
        ;;
esac