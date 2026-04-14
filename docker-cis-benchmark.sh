#!/bin/bash
# docker-cis-benchmark.sh — Verifica conformidade com CIS Docker Benchmark
# Uso: ./docker-cis-benchmark.sh [opcoes]
# Opcoes:
#   --all           Verifica todos os containers (padrao)
#   --container C   Verifica apenas container especifico
#   --host           Verifica apenas configuracoes do host/daemon
#   --severity LEVEL Filtra por severidade: info, warn, fail (padrao: todas)
#   --json           Saida em formato JSON
#   --help           Mostra esta ajuda
#   --version        Mostra versao

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

FILTER_CONTAINER=""
CHECK_HOST=false
CHECK_CONTAINERS=true
SEVERITY_FILTER=""
JSON_OUTPUT=false

while [ $# -gt 0 ]; do
    case "$1" in
        --all|-a) CHECK_HOST=true; CHECK_CONTAINERS=true; shift ;;
        --container|-c) FILTER_CONTAINER="$2"; shift 2 ;;
        --host|-H) CHECK_HOST=true; CHECK_CONTAINERS=false; shift ;;
        --severity|-s) SEVERITY_FILTER="$2"; shift 2 ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-cis-benchmark.sh — Verifica conformidade CIS Docker Benchmark"
            echo ""
            echo "  Uso: ./docker-cis-benchmark.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --all           Verifica host + containers (padrao)"
            echo "    --container C   Verifica apenas container especifico"
            echo "    --host           Verifica apenas configuracoes do host/daemon"
            echo "    --severity LEVEL Filtra: info, warn, fail"
            echo "    --json           Saida em formato JSON"
            echo "    --help           Mostra esta ajuda"
            echo "    --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-cis-benchmark.sh"
            echo "    ./docker-cis-benchmark.sh --container nginx"
            echo "    ./docker-cis-benchmark.sh --host"
            echo "    ./docker-cis-benchmark.sh --severity fail --json"
            echo ""
            exit 0
            ;;
        --version) echo "docker-cis-benchmark.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

total_pass=0
total_warn=0
total_fail=0
total_info=0
json_results=""

add_result() {
    local id="$1"
    local desc="$2"
    local severity="$3"
    local detail="$4"
    local target="$5"

    if [ -n "$SEVERITY_FILTER" ] && [ "$severity" != "$SEVERITY_FILTER" ]; then
        return
    fi

    case "$severity" in
        pass) total_pass=$((total_pass + 1)); icon="${GREEN}PASS${RESET}" ;;
        warn) total_warn=$((total_warn + 1)); icon="${YELLOW}WARN${RESET}" ;;
        fail) total_fail=$((total_fail + 1)); icon="${RED}FAIL${RESET}" ;;
        info) total_info=$((total_info + 1)); icon="${CYAN}INFO${RESET}" ;;
    esac

    if ! $JSON_OUTPUT; then
        echo -e "  ${icon} [$id]  $(echo "$desc" | cut -c1-43)  $(echo "$detail" | cut -c1-35)"
    else
        json_results="${json_results}{\"id\":\"$id\",\"severity\":\"$severity\",\"desc\":\"$desc\",\"detail\":\"$detail\",\"target\":\"$target\"},"
    fi
}

if ! $JSON_OUTPUT; then
    echo ""
    echo -e "  ${BOLD}CIS Docker Benchmark${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
fi

# =============================================
# HOST / Daemon checks
# =============================================

if $CHECK_HOST; then
    if ! $JSON_OUTPUT; then
        echo -e "  ${BOLD}── Configuracoes do Host/Daemon ──${RESET}"
        echo ""
    fi

    if [ -f /etc/docker/daemon.json ]; then
        add_result "1.1" "daemon.json existe" "pass" "/etc/docker/daemon.json" "host"
    else
        add_result "1.1" "daemon.json existe" "warn" "Arquivo nao encontrado — usar defaults" "host"
    fi

    if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -qi 'apparmor'; then
        add_result "1.2" "AppArmor habilitado" "pass" "Perfil AppArmor ativo" "host"
    else
        add_result "1.2" "AppArmor habilitado" "warn" "AppArmor nao detectado" "host"
    fi

    if docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -qi 'seccomp'; then
        add_result "1.3" "Seccomp habilitado" "pass" "Seccomp profile ativo" "host"
    else
        add_result "1.3" "Seccomp habilitado" "fail" "Seccomp desabilitado" "host"
    fi

    if docker info --format '{{.LoggingDriver}}' 2>/dev/null | grep -qi 'json-file'; then
        add_result "1.4" "Log driver json-file" "pass" "$(docker info --format '{{.LoggingDriver}}' 2>/dev/null)" "host"
    else
        add_result "1.4" "Log driver json-file" "warn" "Driver: $(docker info --format '{{.LoggingDriver}}' 2>/dev/null)" "host"
    fi

    if docker info 2>/dev/null | grep -qi 'live-restore'; then
        add_result "1.5" "Live restore habilitado" "pass" "Containers sobrevivem restart do daemon" "host"
    else
        add_result "1.5" "Live restore habilitado" "warn" "Containers param ao reiniciar daemon" "host"
    fi

    tls_verify=$(docker info --format '{{.TLSVerify}}' 2>/dev/null)
    if [ "$tls_verify" = "true" ]; then
        add_result "1.6" "TLS para daemon" "pass" "TLSVerify ativo" "host"
    else
        add_result "1.6" "TLS para daemon" "info" "TLSVerify desativado (local)" "host"
    fi

    user_ns=$(docker info --format '{{.SecurityOptions}}' 2>/dev/null | grep -ci 'userns' || echo 0)
    if [ "$user_ns" -gt 0 ]; then
        add_result "1.7" "User namespaces" "pass" "User namespace remap ativo" "host"
    else
        add_result "1.7" "User namespaces" "info" "User namespace remap desabilitado" "host"
    fi

    if stat -c '%a' /var/run/docker.sock 2>/dev/null | grep -qE '^[0-6][0-6]0$'; then
        add_result "1.8" "Permissao docker.sock" "pass" "$(stat -c '%a' /var/run/docker.sock 2>/dev/null)" "host"
    else
        add_result "1.8" "Permissao docker.sock" "fail" "$(stat -c '%a' /var/run/docker.sock 2>/dev/null) — permissivo" "host"
    fi

    if [ -f /etc/docker/daemon.json ]; then
        if grep -qi 'storage-driver' /etc/docker/daemon.json 2>/dev/null; then
            add_result "1.9" "Storage driver explicito" "pass" "Definido em daemon.json" "host"
        else
            add_result "1.9" "Storage driver explicito" "warn" "Usando default: $(docker info --format '{{.Driver}}' 2>/dev/null)" "host"
        fi
    fi

    iptables_enabled=$(docker info --format '{{.IPTables}}' 2>/dev/null)
    if [ "$iptables_enabled" = "true" ]; then
        add_result "1.10" "iptables gerenciado pelo Docker" "info" "Docker gerencia regras iptables" "host"
    else
        add_result "1.10" "iptables gerenciado pelo Docker" "warn" "iptables manual — riscos de seguranca" "host"
    fi

    if ! $JSON_OUTPUT; then echo ""; fi
fi

# =============================================
# Container checks
# =============================================

if $CHECK_CONTAINERS; then
    container_list=""
    if [ -n "$FILTER_CONTAINER" ]; then
        container_list=$(docker ps -a --filter "name=$FILTER_CONTAINER" --format '{{.ID}}|{{.Names}}' 2>/dev/null)
    else
        container_list=$(docker ps -a --format '{{.ID}}|{{.Names}}' 2>/dev/null)
    fi

    total_checked=$(echo "$container_list" | grep -c '|' || echo 0)
    total_checked=$(echo "$total_checked" | tr -d '[:space:]')
    [[ "$total_checked" =~ ^[0-9]+$ ]] || total_checked=0

    if [ "$total_checked" -eq 0 ]; then
        if ! $JSON_OUTPUT; then
            echo -e "  ${DIM}Nenhum container para verificar.${RESET}"
        fi
    else
        while IFS='|' read -r cid cname; do
            [ -z "$cid" ] && continue

            if ! $JSON_OUTPUT; then
                echo -e "  ${BOLD}── Container: ${cname} ──${RESET}"
                echo ""
            fi

            privileged=$(docker inspect --format '{{.HostConfig.Privileged}}' "$cid" 2>/dev/null)
            if [ "$privileged" = "true" ]; then
                add_result "2.1" "Privileged mode" "fail" "Container rodando em modo privilegiado" "$cname"
            else
                add_result "2.1" "Privileged mode" "pass" "Nao privilegiado" "$cname"
            fi

            capabilities=$(docker inspect --format '{{.HostConfig.CapAdd}}' "$cid" 2>/dev/null)
            if [ "$capabilities" = "[]" ] || [ -z "$capabilities" ]; then
                add_result "2.2" "Capabilities adicionadas" "pass" "Nenhuma capability extra" "$cname"
            else
                dangerous_caps="SYS_ADMIN NET_ADMIN SYS_PTRACE DAC_OVERRIDE NET_RAW"
                cap_str=$(echo "$capabilities" | tr -d '[]')
                has_danger=false
                for cap in $dangerous_caps; do
                    if echo "$cap_str" | grep -qi "$cap"; then
                        has_danger=true
                        add_result "2.2" "Capability perigosa: $cap" "fail" "$capabilities" "$cname"
                    fi
                done
                if ! $has_danger; then
                    add_result "2.2" "Capabilities adicionadas" "warn" "$capabilities" "$cname"
                fi
            fi

            readonly_fs=$(docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' "$cid" 2>/dev/null)
            if [ "$readonly_fs" = "true" ]; then
                add_result "2.3" "Read-only root filesystem" "pass" "Filesystem somente leitura" "$cname"
            else
                add_result "2.3" "Read-only root filesystem" "warn" "Filesystem gravavel — considere --read-only" "$cname"
            fi

            run_user=$(docker inspect --format '{{.Config.User}}' "$cid" 2>/dev/null)
            if [ -z "$run_user" ] || [ "$run_user" = "" ] || [ "$run_user" = "root" ] || [ "$run_user" = "0" ]; then
                add_result "2.4" "Rodando como root" "fail" "User: ${run_user:-root}" "$cname"
            else
                add_result "2.4" "Rodando como root" "pass" "User: $run_user" "$cname"
            fi

            docker_sock_mount=$(docker inspect --format '{{range .Mounts}}{{if eq .Source "/var/run/docker.sock"}}true{{end}}{{end}}' "$cid" 2>/dev/null)
            if [ "$docker_sock_mount" = "true" ]; then
                add_result "2.5" "docker.sock montado" "fail" "docker.sock exposto — acesso total ao daemon" "$cname"
            else
                add_result "2.5" "docker.sock montado" "pass" "docker.sock nao montado" "$cname"
            fi

            pid_mode=$(docker inspect --format '{{.HostConfig.PidMode}}' "$cid" 2>/dev/null)
            if [ "$pid_mode" = "host" ]; then
                add_result "2.6" "PID mode host" "fail" "Compartilhando namespace PID com host" "$cname"
            else
                add_result "2.6" "PID mode host" "pass" "PID namespace isolado" "$cname"
            fi

            ipc_mode=$(docker inspect --format '{{.HostConfig.IpcMode}}' "$cid" 2>/dev/null)
            if [ "$ipc_mode" = "host" ]; then
                add_result "2.7" "IPC mode host" "fail" "Compartilhando namespace IPC com host" "$cname"
            else
                add_result "2.7" "IPC mode host" "pass" "IPC namespace isolado" "$cname"
            fi

            net_mode=$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$cid" 2>/dev/null)
            if [ "$net_mode" = "host" ]; then
                add_result "2.8" "Network mode host" "fail" "Compartilhando network stack com host" "$cname"
            else
                add_result "2.8" "Network mode host" "pass" "Network: $net_mode" "$cname"
            fi

            restart_policy=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$cid" 2>/dev/null)
            if [ -z "$restart_policy" ] || [ "$restart_policy" = "no" ]; then
                add_result "2.9" "Restart policy" "warn" "Sem restart policy — container para ao falhar" "$cname"
            else
                add_result "2.9" "Restart policy" "pass" "Policy: $restart_policy" "$cname"
            fi

            healthcheck=$(docker inspect --format '{{.Config.Healthcheck}}' "$cid" 2>/dev/null)
            if [ -z "$healthcheck" ] || [ "$healthcheck" = "<nil>" ] || [ "$healthcheck" = "null" ]; then
                add_result "2.10" "Healthcheck definido" "warn" "Nenhum healthcheck configurado" "$cname"
            else
                add_result "2.10" "Healthcheck definido" "pass" "Healthcheck ativo" "$cname"
            fi

            port_bindings=$(docker inspect --format '{{range $p, $conf := .HostConfig.PortBindings}}{{$p}} {{end}}' "$cid" 2>/dev/null)
            if [ -n "$port_bindings" ]; then
                add_result "2.11" "Portas expostas no host" "info" "$port_bindings" "$cname"
            else
                add_result "2.11" "Portas expostas no host" "pass" "Nenhuma porta no host" "$cname"
            fi

            image_tag=$(docker inspect --format '{{.RepoTags}}' "$cid" 2>/dev/null | grep -c '<none>' || echo 0)
            if [ "$image_tag" -gt 0 ]; then
                add_result "2.12" "Imagem com tag valida" "warn" "Imagem sem tag (<none>)" "$cname"
            else
                add_result "2.12" "Imagem com tag valida" "pass" "$(docker inspect --format '{{.Config.Image}}' "$cid" 2>/dev/null)" "$cname"
            fi

            if ! $JSON_OUTPUT; then echo ""; fi
        done <<< "$container_list"
    fi
fi

# =============================================
# Resumo
# =============================================

if $JSON_OUTPUT; then
    json_results="${json_results%,}"
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"pass\":$total_pass,\"warn\":$total_warn,\"fail\":$total_fail,\"info\":$total_info,\"results\":[$json_results]}"
    exit 0
fi

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Resumo CIS Benchmark${RESET}"
echo ""
echo -e "  ${GREEN}PASS${RESET}:   ${GREEN}${BOLD}$total_pass${RESET}"
echo -e "  ${YELLOW}WARN${RESET}:   ${YELLOW}${BOLD}$total_warn${RESET}"
echo -e "  ${RED}FAIL${RESET}:   ${RED}${BOLD}$total_fail${RESET}"
echo -e "  ${CYAN}INFO${RESET}:   ${CYAN}${BOLD}$total_info${RESET}"
echo ""

if [ "$total_fail" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}Atencao: $total_fail verificacao(oes) com falha critica${RESET}"
fi

if [ "$total_warn" -gt 0 ]; then
    echo -e "  ${YELLOW}${total_warn} aviso(s) — revise e considere corrigir${RESET}"
fi

if [ "$total_fail" -eq 0 ] && [ "$total_warn" -eq 0 ]; then
    echo -e "  ${GREEN}✓ Todas as verificacoes passaram${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""