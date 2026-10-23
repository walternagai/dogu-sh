#!/bin/bash
# dotfiles-manager.sh — Gerencia dotfiles com symlinks e um repositorio local
# Uso: ./dotfiles-manager.sh [opcoes]
# Opcoes:
#   --init                 Cria o repositorio e o manifesto
#   --add ARQUIVO          Move para o repo e cria symlink em ~/ARQUIVO
#   --remove ARQUIVO       Remove o symlink e a copia do repo
#   --list                 Lista entradas e status
#   --status               Mostra apenas o status dos symlinks
#   --apply                Recria symlinks a partir do manifesto
#   --repo DIR             Repositorio (padrao: ~/.dotfiles)
#       --force            Sobrescreve arquivos existentes
#       --dry-run          Mostra o que seria feito
#       --json             Saida em formato JSON
#   -h, --help             Mostra esta ajuda
#   -V, --version          Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

# NO_COLOR support (https://no-color.org/)
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' BLUE='' BOLD='' DIM='' RESET=''
fi

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

json_escape() {
    local s="$1"
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    printf '%s' "$s"
}

ACTION=""
TARGET=""
REPO="$HOME/.dotfiles"
FORCE=false
DRY_RUN=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --init) ACTION="init"; shift ;;
        --add)
            [[ -z "${2-}" ]] && { echo "Flag --add requer um valor" >&2; exit 2; }
            ACTION="add"; TARGET="$2"; shift 2 ;;
        --remove)
            [[ -z "${2-}" ]] && { echo "Flag --remove requer um valor" >&2; exit 2; }
            ACTION="remove"; TARGET="$2"; shift 2 ;;
        --list) ACTION="list"; shift ;;
        --status) ACTION="status"; shift ;;
        --apply) ACTION="apply"; shift ;;
        --repo)
            [[ -z "${2-}" ]] && { echo "Flag --repo requer um valor" >&2; exit 2; }
            REPO="$2"; shift 2 ;;
        --force) FORCE=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  dotfiles-manager.sh — Gerencia dotfiles com symlinks"
            echo ""
            echo "  Uso: ./dotfiles-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --init                 Cria o repositorio e o manifesto"
            echo "    --add ARQUIVO          Move para o repo e cria symlink em ~/ARQUIVO"
            echo "    --remove ARQUIVO       Remove symlink e copia do repo"
            echo "    --list                 Lista entradas e status"
            echo "    --status               Mostra apenas o status"
            echo "    --apply                Recria symlinks do manifesto"
            echo "    --repo DIR             Repositorio (padrao: ~/.dotfiles)"
            echo "        --force            Sobrescreve arquivos existentes"
            echo "        --dry-run          Mostra o que seria feito"
            echo "        --json             Saida em formato JSON"
            echo "    -h, --help             Mostra esta ajuda"
            echo "    -V, --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./dotfiles-manager.sh --init"
            echo "    ./dotfiles-manager.sh --add .bashrc"
            echo "    ./dotfiles-manager.sh --list"
            echo "    ./dotfiles-manager.sh --apply --dry-run"
            echo ""
            exit 0
            ;;
        -V|--version) echo "dotfiles-manager.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

[ -n "$ACTION" ] || ACTION="list"
MANIFEST="$REPO/.dogu-dotfiles"

normalize_rel() {
    local p="$1"
    p="${p#./}"
    p="${p#"$HOME"/}"
    [[ "$p" == "$HOME"* ]] && p="${p#"$HOME"/}"
    printf '%s' "$p"
}

entry_status() {
    local rel="$1"
    local src="$HOME/$rel"
    local repo_file="$REPO/$rel"
    if [ -L "$src" ] && [ "$(readlink "$src")" = "$repo_file" ]; then
        echo "ok"
    elif [ -e "$src" ]; then
        echo "conflict"
    elif [ -e "$repo_file" ]; then
        echo "missing"
    else
        echo "broken"
    fi
}

confirm() {
    local msg="$1"
    if $FORCE || [ "${DOGU_CONFIRMED:-}" = "1" ]; then
        return 0
    fi
    if [ -t 0 ]; then
        read -r -p "$msg [s/N] " c
        [[ "$c" =~ ^[Ss]$ ]]
    else
        error "Execucao nao interativa. Use --force ou rode via 'dogu ... --yes'."
    fi
}

case "$ACTION" in
    init)
        if $DRY_RUN; then
            echo "mkdir -p $REPO && touch $MANIFEST"
            exit 0
        fi
        mkdir -p "$REPO"
        touch "$MANIFEST"
        success "Repositorio: $REPO"
        success "Manifesto:   $MANIFEST"
        ;;

    add)
        rel=$(normalize_rel "$TARGET")
        [[ -n "$rel" ]] || error "Informe um caminho relativo a HOME."
        src="$HOME/$rel"
        repo_file="$REPO/$rel"
        [[ -e "$src" ]] || error "Nao encontrado: $src"
        [[ -f "$src" ]] || error "Apenas arquivos sao suportados nesta versao."
        [[ -e "$repo_file" ]] && ! $FORCE && error "Ja existe no repo (use --force): $repo_file"

        if $DRY_RUN; then
            echo "mkdir -p $(dirname "$repo_file") && cp \"$src\" \"$repo_file\" && ln -sfn \"$repo_file\" \"$src\""
            exit 0
        fi
        confirm "Substituir $src por symlink para $repo_file?" || { log "Cancelado."; exit 0; }

        mkdir -p "$(dirname "$repo_file")"
        cp "$src" "$repo_file"
        if [ ! -L "$src" ]; then
            cp "$src" "${src}.bak.$(date '+%Y%m%d_%H%M%S')"
        fi
        ln -sfn "$repo_file" "$src"
        grep -qxF "$rel" "$MANIFEST" 2>/dev/null || printf '%s\n' "$rel" >> "$MANIFEST"
        success "Adicionado: $rel"
        ;;

    remove)
        rel=$(normalize_rel "$TARGET")
        src="$HOME/$rel"
        repo_file="$REPO/$rel"
        confirm "Remover $rel do gerenciamento?" || { log "Cancelado."; exit 0; }
        if $DRY_RUN; then
            echo "rm -f \"$src\" \"$repo_file\"; sed -i '/^$rel$/d' \"$MANIFEST\""
            exit 0
        fi
        if [ -L "$src" ] && [ "$(readlink "$src")" = "$repo_file" ]; then
            rm -f "$src"
        fi
        rm -f "$repo_file"
        if [ -f "$MANIFEST" ]; then
            tmp=$(mktemp)
            grep -vxF "$rel" "$MANIFEST" > "$tmp" || true
            mv "$tmp" "$MANIFEST"
        fi
        success "Removido: $rel"
        ;;

    list|status)
        if [ ! -f "$MANIFEST" ]; then
            $JSON_MODE && printf '{"repo":"%s","entries":[],"count":0}\n' "$(json_escape "$REPO")"
            $JSON_MODE || { echo -e "  ${DIM}Manifesto nao encontrado. Rode --init.${RESET}"; }
            exit 0
        fi
        json_entries=""
        json_first=true
        count=0
        while IFS= read -r rel; do
            [ -z "$rel" ] && continue
            count=$((count + 1))
            state=$(entry_status "$rel")
            if ! $JSON_MODE; then
                case "$state" in
                    ok)       icon="${GREEN}✓${RESET}" ;;
                    missing)  icon="${YELLOW}!${RESET}" ;;
                    conflict) icon="${RED}✗${RESET}" ;;
                    *)        icon="${RED}?${RESET}" ;;
                esac
                printf "  %b %-30s %s\n" "$icon" "$rel" "$state"
            fi
            $json_first || json_entries+=","
            json_first=false
            json_entries+=$(printf '{"path":"%s","source":"%s","target":"%s","status":"%s"}' \
                "$(json_escape "$rel")" "$(json_escape "$REPO/$rel")" "$(json_escape "$HOME/$rel")" "$state")
        done < "$MANIFEST"
        if $JSON_MODE; then
            printf '{"repo":"%s","entries":[%s],"count":%s}\n' \
                "$(json_escape "$REPO")" "$json_entries" "$count"
        fi
        ;;

    apply)
        [ -f "$MANIFEST" ] || error "Manifesto nao encontrado. Rode --init e --add."
        while IFS= read -r rel; do
            [ -z "$rel" ] && continue
            src="$HOME/$rel"
            repo_file="$REPO/$rel"
            if [ ! -e "$repo_file" ]; then
                warn "Copia ausente no repo: $rel"
                continue
            fi
            if [ -L "$src" ] && [ "$(readlink "$src")" = "$repo_file" ]; then
                continue
            fi
            if [ -e "$src" ] && ! $FORCE; then
                warn "Conflito (use --force): $src"
                continue
            fi
            if $DRY_RUN; then
                echo "ln -sfn \"$repo_file\" \"$src\""
                continue
            fi
            confirm "Substituir $src por symlink?" || { log "Cancelado."; exit 0; }
            [ -e "$src" ] && [ ! -L "$src" ] && cp "$src" "${src}.bak.$(date '+%Y%m%d_%H%M%S')"
            ln -sfn "$repo_file" "$src"
            success "Aplicado: $rel"
        done < "$MANIFEST"
        ;;
esac
