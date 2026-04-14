#!/bin/bash
# clipboard-manager.sh — Historico do clipboard com busca e persistencia
# Uso: ./clipboard-manager.sh [opcoes]
# Opcoes:
#   --watch          Monitora clipboard e salva historico (modo continuo)
#   --list           Lista historico salvo (padrao)
#   --search TERM    Busca no historico por termo
#   --restore N      Restaura item N do historico para o clipboard
#   --clear          Limpa historico salvo
#   --count N        Numero de itens a listar (padrao: 20)
#   --help           Mostra esta ajuda
#   --version        Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

HISTORY_DIR="$HOME/.local/share/dogu"
HISTORY_FILE="$HISTORY_DIR/clipboard-history.txt"
MAX_HISTORY=1000
LIST_COUNT=20

ACTION="list"
SEARCH_TERM=""
RESTORE_INDEX=""

detect_clipboard_tool() {
    if [ -n "$WAYLAND_DISPLAY" ] && command -v wl-copy &>/dev/null; then
        echo "wl-copy"
    elif command -v xclip &>/dev/null; then
        echo "xclip"
    elif command -v xsel &>/dev/null; then
        echo "xsel"
    elif [ -n "$WAYLAND_DISPLAY" ] && command -v wl-clipboard &>/dev/null; then
        echo "wl-copy"
    else
        echo "none"
    fi
}

get_clipboard() {
    local tool=$(detect_clipboard_tool)
    case "$tool" in
        wl-copy) wl-paste 2>/dev/null || true ;;
        xclip) xclip -selection clipboard -o 2>/dev/null || true ;;
        xsel) xsel --clipboard --output 2>/dev/null || true ;;
        *) echo "" ;;
    esac
}

set_clipboard() {
    local content="$1"
    local tool=$(detect_clipboard_tool)
    case "$tool" in
        wl-copy) echo -n "$content" | wl-copy 2>/dev/null ;;
        xclip) echo -n "$content" | xclip -selection clipboard 2>/dev/null ;;
        xsel) echo -n "$content" | xsel --clipboard --input 2>/dev/null ;;
    esac
}

while [ $# -gt 0 ]; do
    case "$1" in
        --watch|-w) ACTION="watch"; shift ;;
        --list|-l) ACTION="list"; shift ;;
        --search|-s) ACTION="search"; SEARCH_TERM="$2"; shift 2 ;;
        --restore|-r) ACTION="restore"; RESTORE_INDEX="$2"; shift 2 ;;
        --clear|-c) ACTION="clear"; shift ;;
        --count|-n) LIST_COUNT="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  clipboard-manager.sh — Historico do clipboard com busca e persistencia"
            echo ""
            echo "  Uso: ./clipboard-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --watch          Monitora clipboard e salva historico (modo continuo)"
            echo "    --list           Lista historico salvo (padrao)"
            echo "    --search TERM    Busca no historico por termo"
            echo "    --restore N      Restaura item N do historico"
            echo "    --clear          Limpa historico salvo"
            echo "    --count N        Numero de itens a listar (padrao: 20)"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Deteccao automatica:"
            echo "    Wayland: wl-copy / wl-paste"
            echo "    X11:     xclip ou xsel"
            echo ""
            echo "  Exemplos:"
            echo "    ./clipboard-manager.sh --watch &"
            echo "    ./clipboard-manager.sh --list"
            echo "    ./clipboard-manager.sh --search 'import'"
            echo "    ./clipboard-manager.sh --restore 3"
            echo "    ./clipboard-manager.sh --clear"
            echo ""
            exit 0
            ;;
        --version) echo "clipboard-manager.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "$HISTORY_DIR" 2>/dev/null || true
touch "$HISTORY_FILE" 2>/dev/null || true

CLIPBOARD_TOOL=$(detect_clipboard_tool)

echo ""
echo -e "  ${BOLD}Clipboard Manager${RESET}  ${DIM}v$VERSION${RESET}"
echo -e "  Clipboard: ${CYAN}${CLIPBOARD_TOOL}${RESET}"
echo ""

case "$ACTION" in
    watch)
        if [ "$CLIPBOARD_TOOL" = "none" ]; then
            echo -e "  ${RED}Erro: nenhuma ferramenta de clipboard encontrada.${RESET}"
            echo -e "  ${DIM}Instale: xclip (X11) ou wl-clipboard (Wayland)${RESET}"
            exit 1
        fi

        echo -e "  ${BOLD}Monitorando clipboard...${RESET}  ${DIM}Ctrl+C para sair${RESET}"
        echo ""

        last_content=""
        watch_count=0

        while true; do
            current_content=$(get_clipboard)

            if [ -n "$current_content" ] && [ "$current_content" != "$last_content" ]; then
                last_content="$current_content"

                content_lines=$(echo "$current_content" | wc -l | tr -d ' ')
                if [ "$content_lines" -gt 1 ]; then
                    preview=$(echo "$current_content" | head -1 | cut -c1-50)
                    preview="${preview}... (${content_lines} linhas)"
                else
                    preview=$(echo "$current_content" | cut -c1-60)
                fi

                timestamp=$(date '+%Y-%m-%dT%H:%M:%S')
                content_hash=$(echo -n "$current_content" | sha256sum | awk '{print $1}')

                existing=$(grep -c "^${content_hash}|" "$HISTORY_FILE" 2>/dev/null || echo 0)
                existing=$(echo "$existing" | tr -d '[:space:]')
                [[ "$existing" =~ ^[0-9]+$ ]] || existing=0

                if [ "$existing" -eq 0 ]; then
                    b64_content=$(echo -n "$current_content" | base64 -w0 2>/dev/null || echo -n "$current_content" | base64)
                    echo "${content_hash}|${timestamp}|${preview}|${b64_content}" >> "$HISTORY_FILE"
                    watch_count=$((watch_count + 1))
                    echo -e "  ${GREEN}#${watch_count}${RESET} ${DIM}${timestamp}${RESET} ${CYAN}${preview}${RESET}"

                    line_count=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
                    [[ "$line_count" =~ ^[0-9]+$ ]] || line_count=0
                    if [ "$line_count" -gt "$MAX_HISTORY" ]; then
                        tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null
                        mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
                    fi
                fi
            fi

            sleep 1
        done
        ;;

    list)
        if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
            echo -e "  ${DIM}Historico vazio.${RESET}"
            echo -e "  ${DIM}Use --watch para monitorar o clipboard.${RESET}"
            exit 0
        fi

        echo -e "  ${BOLD}── Historico do Clipboard ──${RESET}"
        echo ""

        total=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
        show_count=$LIST_COUNT

        if [ "$show_count" -gt "$total" ]; then
            show_count=$total
        fi

        echo -e "  Mostrando ${BOLD}$show_count${RESET} de ${BOLD}$total${RESET} item(ns)"
        echo ""

        printf "  %-5s %-20s %s\n" "#" "HORA" "CONTEUDO"
        printf "  %-5s %-20s %s\n" "─────" "────────────────────" "──────────────────────────────────────────"

        idx=$total
        tail -n "$show_count" "$HISTORY_FILE" | while IFS='|' read -r hash timestamp preview; do
            short_preview=$(echo "$preview" | cut -c1-42)
            short_time=$(echo "$timestamp" | sed 's/T/ /' | cut -c6-21)
            printf "  ${CYAN}%-5s${RESET} %-20s %s\n" "#$idx" "$short_time" "$short_preview"
            idx=$((idx - 1))
        done | tac

        echo ""
        echo -e "  ${DIM}Use --restore N para copiar um item de volta ao clipboard${RESET}"
        echo -e "  ${DIM}Use --search TERM para buscar no historico${RESET}"
        ;;

    search)
        if [ -z "$SEARCH_TERM" ]; then
            echo -e "  ${RED}Erro: especifique o termo de busca.${RESET}"
            echo -e "  ${DIM}Uso: ./clipboard-manager.sh --search TERMO${RESET}"
            exit 1
        fi

        if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
            echo -e "  ${DIM}Historico vazio.${RESET}"
            exit 0
        fi

        echo -e "  ${BOLD}── Busca: '${SEARCH_TERM}' ──${RESET}"
        echo ""

        results=$(grep -i "$SEARCH_TERM" "$HISTORY_FILE" 2>/dev/null || true)

        if [ -z "$results" ]; then
            echo -e "  ${DIM}Nenhum resultado encontrado.${RESET}"
        else
            match_count=$(echo "$results" | grep -c '.' || echo 0)
            match_count=$(echo "$match_count" | tr -d '[:space:]')
            [[ "$match_count" =~ ^[0-9]+$ ]] || match_count=0
            echo -e "  ${BOLD}$match_count${RESET} resultado(s)"
            echo ""

            printf "  %-5s %-20s %s\n" "#" "HORA" "CONTEUDO"
            printf "  %-5s %-20s %s\n" "─────" "────────────────────" "──────────────────────────────────────────"

            total=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
            idx=1
            grep -n -i "$SEARCH_TERM" "$HISTORY_FILE" 2>/dev/null | while IFS=':' read -r linenum content; do
                IFS='|' read -r hash timestamp preview <<< "$content"
                short_preview=$(echo "$preview" | cut -c1-42)
                short_time=$(echo "$timestamp" | sed 's/T/ /' | cut -c6-21)
                printf "  ${CYAN}%-5s${RESET} %-20s %s\n" "#${linenum}" "$short_time" "$short_preview"
            done
        fi

        echo ""
        ;;

    restore)
        if [ -z "$RESTORE_INDEX" ]; then
            echo -e "  ${RED}Erro: especifique o numero do item.${RESET}"
            echo -e "  ${DIM}Uso: ./clipboard-manager.sh --restore N${RESET}"
            exit 1
        fi

        if [ ! -f "$HISTORY_FILE" ] || [ ! -s "$HISTORY_FILE" ]; then
            echo -e "  ${DIM}Historico vazio.${RESET}"
            exit 1
        fi

        if [ "$CLIPBOARD_TOOL" = "none" ]; then
            echo -e "  ${RED}Erro: nenhuma ferramenta de clipboard encontrada.${RESET}"
            exit 1
        fi

        if ! [[ "$RESTORE_INDEX" =~ ^[0-9]+$ ]]; then
            echo -e "  ${RED}Erro: indice invalido '${RESTORE_INDEX}'. Use um numero.${RESET}"
            exit 1
        fi

        total=$(wc -l < "$HISTORY_FILE" | tr -d ' ')
        line_num=$((total - RESTORE_INDEX + 1))

        if [ "$line_num" -lt 1 ] || [ "$line_num" -gt "$total" ]; then
            echo -e "  ${RED}Erro: indice ${RESTORE_INDEX} fora do intervalo (1-$total).${RESET}"
            exit 1
        fi

        line_content=$(sed -n "${line_num}p" "$HISTORY_FILE")
        timestamp=$(echo "$line_content" | cut -d'|' -f2)
        preview=$(echo "$line_content" | cut -d'|' -f3)
        b64_content=$(echo "$line_content" | cut -d'|' -f4-)

        echo -e "  Restaurando item ${CYAN}#$RESTORE_INDEX${RESET} (${DIM}$timestamp${RESET})"
        echo -e "  ${DIM}Preview: $preview${RESET}"

        if [ -n "$b64_content" ]; then
            restored_content=$(echo "$b64_content" | base64 -d 2>/dev/null)
            if [ -n "$restored_content" ]; then
                set_clipboard "$restored_content"
                echo -e "  ${GREEN}✓${RESET} Item restaurado para o clipboard"
            else
                echo -e "  ${RED}✗${RESET} Falha ao decodificar conteudo — item muito antigo (sem base64)"
            fi
        else
            echo -e "  ${RED}✗${RESET} Conteudo nao disponivel para restauracao (formato antigo)"
        fi
        ;;

    clear)
        if [ -f "$HISTORY_FILE" ]; then
            echo "" > "$HISTORY_FILE"
            echo -e "  ${GREEN}✓${RESET} Historico do clipboard limpo"
        else
            echo -e "  ${DIM}Historico ja esta vazio.${RESET}"
        fi
        ;;
esac

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Operacao concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""