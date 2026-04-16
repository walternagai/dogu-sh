#!/bin/bash
# docker-image-slimmer.sh — Analisa camadas de imagens e sugere reducoes (Linux)
# Uso: ./docker-image-slimmer.sh [opcoes]
# Opcoes:
#   --image IMG     Analisa uma imagem especifica
#   --all           Analisa todas as imagens locais
#   --history       Mostra historico detalhado de camadas
#   --tips          Apenas dicas gerais (sem analise)
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
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

TARGET_IMAGE=""
ANALYZE_ALL=false
SHOW_HISTORY=false
TIPS_ONLY=false

while [ $# -gt 0 ]; do
    case "$1" in
        --image|-i) TARGET_IMAGE="$2"; shift 2 ;;
        --all|-a) ANALYZE_ALL=true; shift ;;
        --history|-H) SHOW_HISTORY=true; shift ;;
        --tips|-t) TIPS_ONLY=true; shift ;;
        --help|-h)
            echo ""
            echo "  docker-image-slimmer.sh — Analisa camadas e sugere reducoes"
            echo ""
            echo "  Uso: ./docker-image-slimmer.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --image IMG     Analisa uma imagem especifica"
            echo "    --all           Analisa todas as imagens locais"
            echo "    --history       Mostra historico detalhado de camadas"
            echo "    --tips          Apenas dicas gerais (sem analise)"
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-image-slimmer.sh --image nginx:latest"
            echo "    ./docker-image-slimmer.sh --all --history"
            echo "    ./docker-image-slimmer.sh --tips"
            echo ""
            exit 0
            ;;
        --version) echo "docker-image-slimmer.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "  ${RED}Erro: Docker nao disponivel ou daemon parado.${RESET}" >&2
    exit 1
fi

if ! $TIPS_ONLY && [ -z "$TARGET_IMAGE" ] && ! $ANALYZE_ALL; then
    ANALYZE_ALL=true
fi

show_tips() {
    echo ""
    echo -e "  ${BOLD}── Dicas para Reduzir Imagens Docker ──${RESET}"
    echo ""
    echo -e "  ${CYAN}1. Multi-stage Build${RESET}"
    echo -e "     Use FROM ... AS builder para compilar e FROM para o runtime"
    echo -e "     Copie apenas os artefatos com COPY --from=builder"
    echo ""
    echo -e "  ${CYAN}2. Imagens Base Menores${RESET}"
    echo -e "     Preferencia: ${GREEN}distroless > alpine > slim > full${RESET}"
    echo -e "     Ex: node:20-alpine ao inves de node:20"
    echo ""
    echo -e "  ${CYAN}3. apt-get Otimizado${RESET}"
    echo -e "     apt-get install --no-install-recommends"
    echo -e "     rm -rf /var/lib/apt/lists/* apos install"
    echo ""
    echo -e "  ${CYAN}4. Camadas Minimas${RESET}"
    echo -e "     Combine RUN com && para reduzir camadas"
    echo -e "     Limpe caches na mesma camada que instala"
    echo ""
    echo -e "  ${CYAN}5. .dockerignore${RESET}"
    echo -e "     Crie .dockerignore para excluir arquivos desnecessarios"
    echo -e "     Ex: .git, node_modules, __pycache__, *.md"
    echo ""
    echo -e "  ${CYAN}6. COPY Especifico${RESET}"
    echo -e "     COPY package.json ./ ao inves de COPY . /"
    echo -e "     Instale deps antes de copiar codigo (cache de camadas)"
    echo ""
}

format_bytes() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then echo "0 B"; return; fi
    if [ "$bytes" -ge 1073741824 ]; then echo "$(echo "scale=1; $bytes / 1073741824" | bc)GB"
    elif [ "$bytes" -ge 1048576 ]; then echo "$(echo "scale=1; $bytes / 1048576" | bc)MB"
    elif [ "$bytes" -ge 1024 ]; then echo "$((bytes / 1024))KB"
    else echo "${bytes}B"
    fi
}

analyze_image() {
    local img="$1"
    local img_id
    img_id=$(docker inspect --format '{{.Id}}' "$img" 2>/dev/null | head -1)
    if [ -z "$img_id" ]; then
        echo -e "  ${RED}Imagem '$img' nao encontrada.${RESET}"
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}── $img ──${RESET}"
    echo ""

    local virtual_size
    virtual_size=$(docker inspect --format '{{.Size}}' "$img" 2>/dev/null | tr -d '[:space:]')
    if ! [[ "$virtual_size" =~ ^[0-9]+$ ]]; then virtual_size=0; fi
    local size_str
    size_str=$(format_bytes "$virtual_size")

    local repo_tag
    repo_tag=$(docker inspect --format '{{if .RepoTags}}{{index .RepoTags 0}}{{end}}' "$img" 2>/dev/null)

    local created
    created=$(docker inspect --format '{{.Created}}' "$img" 2>/dev/null | cut -dT -f1)

    echo -e "  Tamanho virtual: ${RED}${BOLD}$size_str${RESET}"
    echo -e "  Tag:             ${CYAN}${repo_tag:-<none>}${RESET}"
    echo -e "  Criada em:       ${DIM}$created${RESET}"

    local layer_count
    layer_count=$(docker history --no-trunc "$img" 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
    echo -e "  Camadas:         ${BOLD}$layer_count${RESET}"

    echo ""

    local suggestions=0

    local base_image
    base_image=$(docker inspect --format '{{.Config.Image}}' "$img" 2>/dev/null)

    if [ -n "$base_image" ]; then
        local base_lower
        base_lower=$(echo "$base_image" | tr '[:upper:]' '[:lower:]')

        local has_alpine=false
        local has_slim=false
        local has_distroless=false

        case "$base_lower" in
            *alpine*) has_alpine=true ;;
            *slim*) has_slim=true ;;
            *distroless*) has_distroless=true ;;
        esac

        if ! $has_alpine && ! $has_slim && ! $has_distroless; then
            echo -e "  ${YELLOW}⚠${RESET} Base: ${BOLD}$base_image${RESET} — considere versao alpine/slim/distroless"
            suggestions=$((suggestions + 1))

            local alt_suggestions=""
            case "$base_lower" in
                *node*) alt_suggestions="node:<version>-alpine ou node:<version>-slim" ;;
                *python*) alt_suggestions="python:<version>-alpine ou python:<version>-slim" ;;
                *ruby*) alt_suggestions="ruby:<version>-alpine ou ruby:<version>-slim" ;;
                *golang*) alt_suggestions="golang:<version>-alpine" ;;
                *nginx*) alt_suggestions="nginx:<version>-alpine" ;;
                *postgres*) alt_suggestions="postgres:<version>-alpine" ;;
                *mysql*) alt_suggestions="mysql:<version>-oracle ou mysql:<version>-debian" ;;
                *ubuntu*|*debian*) alt_suggestions="<image>:<version>-slim" ;;
                *) alt_suggestions="Verifique se existe variante alpine ou slim" ;;
            esac
            if [ -n "$alt_suggestions" ]; then
                echo -e "    ${DIM}→ $alt_suggestions${RESET}"
            fi
        fi
    fi

    local history_output
    history_output=$(docker history --no-trunc --format '{{.CreatedBy}}|{{.Size}}|{{.CreatedBy}}' "$img" 2>/dev/null | tail -n +2)

    local has_apt_without_noinstallrec=false
    local has_rm_separate=false
    local last_cmd=""

    while IFS='|' read -r created_by size _; do
        local cmd_lower
        cmd_lower=$(echo "$created_by" | tr '[:upper:]' '[:lower:]')

        if echo "$cmd_lower" | grep -qi 'apt-get install' && ! echo "$cmd_lower" | grep -qi 'no-install-recommends'; then
            has_apt_without_noinstallrec=true
        fi

        if echo "$last_cmd" | grep -qi 'apt-get install' && echo "$cmd_lower" | grep -qi 'rm -rf'; then
            has_rm_separate=true
        fi

        last_cmd="$cmd_lower"
    done <<< "$history_output"

    if $has_apt_without_noinstallrec; then
        echo -e "  ${YELLOW}⚠${RESET} apt-get install sem --no-install-recommends detectado"
        echo -e "    ${DIM}→ Use: apt-get install --no-install-recommends <pkg>${RESET}"
        suggestions=$((suggestions + 1))
    fi

    if $has_rm_separate; then
        echo -e "  ${YELLOW}⚠${RESET} rm de cache em camada separada do apt-get install"
        echo -e "    ${DIM}→ Combine: RUN apt-get install ... && rm -rf /var/lib/apt/lists/*${RESET}"
        suggestions=$((suggestions + 1))
    fi

    local large_layers=0
    while IFS='|' read -r created_by size _; do
        local size_bytes
        size_bytes=$(echo "$size" | grep -oE '[0-9]+' | head -1 || echo 0)
        if [[ "$size_bytes" =~ ^[0-9]+$ ]] && [ "$size_bytes" -gt 52428800 ]; then
            large_layers=$((large_layers + 1))
        fi
    done <<< "$history_output"

    if [ "$large_layers" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠${RESET} $large_layers camada(s) grande(s) (>50MB) — considere multi-stage build"
        suggestions=$((suggestions + 1))
    fi

    local env_lines
    env_lines=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$img" 2>/dev/null | grep -ci 'PATH' || true)
    local total_env
    total_env=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$img" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$total_env" -gt 10 ]; then
        echo -e "  ${YELLOW}⚠${RESET} $total_env variaveis de ambiente — considere agrupar em .env"
        suggestions=$((suggestions + 1))
    fi

    local exposed_ports
    exposed_ports=$(docker inspect --format '{{range $k, $v := .Config.ExposedPorts}}{{$k}} {{end}}' "$img" 2>/dev/null)
    if [ -n "$exposed_ports" ]; then
        echo -e "  ${DIM}Portas expostas: $exposed_ports${RESET}"
    fi

    entrypoint=$(docker inspect --format '{{.Config.Entrypoint}}' "$img" 2>/dev/null)
    cmd=$(docker inspect --format '{{.Config.Cmd}}' "$img" 2>/dev/null)
    if [ -n "$entrypoint" ] && [ "$entrypoint" != "[]" ]; then
        echo -e "  ${DIM}Entrypoint: $entrypoint${RESET}"
    fi
    if [ -n "$cmd" ] && [ "$cmd" != "[]" ]; then
        echo -e "  ${DIM}Cmd: $cmd${RESET}"
    fi

    if $SHOW_HISTORY; then
        echo ""
        echo -e "  ${BOLD}── Historico de Camadas ──${RESET}"
        echo ""
        printf "  %-10s %-12s %s\n" "TAMANHO" "CRIADO POR" ""
        printf "  %-10s %-12s %s\n" "──────────" "────────────────────────────────────────────────────────────" ""

        local idx=1
        docker history --no-trunc "$img" 2>/dev/null | tail -n +2 | while IFS= read -r line; do
            local sz=$(echo "$line" | awk '{print $1}')
            local by=$(echo "$line" | cut -c13- | cut -c1-60)
            local sz_color="${DIM}"
            if echo "$sz" | grep -qE '^[0-9]+(MB|GB)$'; then
                sz_color="${YELLOW}"
            fi
            printf "  ${sz_color}%-10s${RESET} %s\n" "$sz" "$by"
            idx=$((idx + 1))
        done
    fi

    echo ""
    if [ "$suggestions" -eq 0 ]; then
        echo -e "  ${GREEN}✓${RESET} Nenhuma sugestao de otimizacao obvia para esta imagem"
    else
        echo -e "  ${YELLOW}⚡ $suggestions sugestao(oes) de otimizacao${RESET}"
    fi
}

if $TIPS_ONLY; then
    show_tips
    exit 0
fi

echo ""
echo -e "  ${BOLD}Docker Image Slimmer${RESET}  ${DIM}v$VERSION${RESET}"

if [ -n "$TARGET_IMAGE" ]; then
    analyze_image "$TARGET_IMAGE"
elif $ANALYZE_ALL; then
    images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -v '<none>' | sort)
    if [ -z "$images" ]; then
        echo -e "  ${DIM}Nenhuma imagem encontrada.${RESET}"
        exit 0
    fi

    total=$(echo "$images" | wc -l | tr -d ' ')
    echo -e "  Analisando ${BOLD}$total${RESET} imagem(ns)..."
    echo ""

    while IFS= read -r img; do
        analyze_image "$img"
    done <<< "$images"
fi

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Analise concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""