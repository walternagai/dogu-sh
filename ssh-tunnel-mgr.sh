#!/bin/bash
# ssh-tunnel-mgr.sh — Gerenciador de tuneis SSH (Linux)
# Uso: ./ssh-tunnel-mgr.sh [opcoes]
# Opcoes:
#   --create|-l [porta_local] [host_destino] [porta_remota] [usuario@host_ssh]
#                     Cria tunel local (local forward)
#   --remote|-r [porta_remota] [host_destino] [porta_local] [usuario@host_ssh]
#                     Cria tunel reverso (remote forward)
#   --daemon|-d       Executa o tunel em segundo plano
#   --list            Lista tuneis SSH ativos
#   --stop [porta]    Encerra tunel na porta especificada
#   --help            Mostra esta ajuda
#   --version         Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "ssh" "$INSTALLER openssh-client"; fi

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

VERSION="1.0.0"

DAEMON=false

usage() {
    echo ""
    echo -e "  ${CYAN}${BOLD}ssh-tunnel-mgr.sh${RESET} — Gerenciador de tuneis SSH"
    echo ""
    echo "  Uso: ./ssh-tunnel-mgr.sh [opcoes]"
    echo ""
    echo "  Opcoes:"
    echo "    --create|-l PORTA_LOCAL HOST_DESTINO PORTA_REMOTA [USER@HOST_SSH]"
    echo "                      Cria tunel local (local forward)"
    echo "    --remote|-r PORTA_REMOTA HOST_DESTINO PORTA_LOCAL [USER@HOST_SSH]"
    echo "                      Cria tunel reverso (remote forward)"
    echo "    --daemon|-d      Executa o tunel em segundo plano"
    echo "    --list            Lista tuneis SSH ativos"
    echo "    --stop PORTA      Encerra tunel na porta especificada"
    echo "    --help            Mostra esta ajuda"
    echo "    --version         Mostra versao"
    echo ""
    echo "  Exemplos:"
    echo "    ./ssh-tunnel-mgr.sh --create 8080 localhost 80 user@servidor"
    echo "    ./ssh-tunnel-mgr.sh --remote 9090 localhost 8080 user@servidor"
    echo "    ./ssh-tunnel-mgr.sh --create 3306 db.internal 3306 user@bastion --daemon"
    echo "    ./ssh-tunnel-mgr.sh --list"
    echo "    ./ssh-tunnel-mgr.sh --stop 8080"
    echo ""
    exit 0
}

cmd_list() {
    echo -e "\n${CYAN}${BOLD}Tuneis SSH ativos:${RESET}"
    echo -e "${DIM}──────────────────────────────────────────────${RESET}"

    local found=0
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            local pid cmd
            pid=$(echo "$line" | awk '{print $2}')
            cmd=$(echo "$line" | awk '{print $1}')
            printf "  %-8s %s\n" "PID $pid" "$cmd"
            found=$((found + 1))
        fi
    done < <(ps aux | grep 'ssh.*-[LR]' | grep -v grep)

    if [ "$found" -eq 0 ]; then
        echo -e "  ${DIM}Nenhum tunel SSH ativo encontrado.${RESET}"
    else
        echo -e "\n  ${GREEN}$found tunel(is) ativo(s)${RESET}"
    fi
    echo ""
}

cmd_stop() {
    local port="$1"
    if [ -z "$port" ]; then
        echo -e "${RED}Erro: Porta obrigatoria para --stop${RESET}"
        exit 1
    fi

    local pids
    pids=$(lsof -t -i :"$port" 2>/dev/null || true)

    if [ -z "$pids" ]; then
        echo -e "${RED}Nenhum processo encontrado na porta $port.${RESET}"
        exit 1
    fi

    echo -e "${YELLOW}Encerrando processo(s) na porta $port...${RESET}"
    for pid in $pids; do
        if kill -TERM "$pid" 2>/dev/null; then
            echo -e "  ${GREEN}✓${RESET} PID $pid — SIGTERM enviado"
        else
            echo -e "  ${RED}✗${RESET} PID $pid — falha ao enviar sinal (tente sudo)"
        fi
    done
}

cmd_create() {
    local lport="$1"
    local dest="$2"
    local rport="$3"
    local ssh_host="${4:-$dest}"

    if [ -z "$rport" ]; then
        echo -e "${RED}Erro: Parametros insuficientes.${RESET}"
        echo -e "Use: --create PORTA_LOCAL HOST_DESTINO PORTA_REMOTA [USER@HOST_SSH]"
        exit 1
    fi

    echo -e "${CYAN}${BOLD}Tunel local:${RESET} localhost:$lport -> $dest:$rport (via $ssh_host)"

    if [ "$DAEMON" = true ]; then
        ssh -f -N -L "$lport:$dest:$rport" "$ssh_host"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Tunel em segundo plano criado na porta $lport${RESET}"
        else
            echo -e "${RED}✗ Falha ao criar tunel.${RESET}"
            exit 1
        fi
    else
        echo -e "${DIM}Pressione Ctrl+C para encerrar${RESET}\n"
        ssh -L "$lport:$dest:$rport" -N "$ssh_host"
    fi
}

cmd_remote() {
    local rport="$1"
    local dest="$2"
    local lport="$3"
    local ssh_host="${4:-$dest}"

    if [ -z "$lport" ]; then
        echo -e "${RED}Erro: Parametros insuficientes.${RESET}"
        echo -e "Use: --remote PORTA_REMOTA HOST_DESTINO PORTA_LOCAL [USER@HOST_SSH]"
        exit 1
    fi

    echo -e "${CYAN}${BOLD}Tunel reverso:${RESET} $ssh_host:$rport -> $dest:$lport"

    if [ "$DAEMON" = true ]; then
        ssh -f -N -R "$rport:$dest:$lport" "$ssh_host"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Tunel reverso em segundo plano criado na porta $rport${RESET}"
        else
            echo -e "${RED}✗ Falha ao criar tunel reverso.${RESET}"
            exit 1
        fi
    else
        echo -e "${DIM}Pressione Ctrl+C para encerrar${RESET}\n"
        ssh -R "$rport:$dest:$lport" -N "$ssh_host"
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --create|-l) shift; cmd_create "$1" "$2" "$3" "$4"; exit 0 ;;
        --remote|-r) shift; cmd_remote "$1" "$2" "$3" "$4"; exit 0 ;;
        --daemon|-d) DAEMON=true; shift ;;
        --list) cmd_list; exit 0 ;;
        --stop) shift; cmd_stop "$1"; exit 0 ;;
        --help|-h) usage ;;
        --version|-v) echo "ssh-tunnel-mgr.sh $VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}"
            exit 1
            ;;
    esac
done

usage