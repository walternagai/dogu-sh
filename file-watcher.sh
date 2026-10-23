#!/bin/bash
# file-watcher.sh — Observa arquivos e reporta criacoes, alteracoes e remocoes
# Uso: ./file-watcher.sh [opcoes]
# Opcoes:
#   -p, --path DIR       Diretorio a observar (padrao: .)
#   -g, --glob PADRAO    Filtro de nome (padrao: *)
#   -i, --interval N     Intervalo em segundos (padrao: 2)
#       --once           Tira um snapshot e sai
#       --json           Saida JSON (snapshot ou JSON Lines)
#   -h, --help           Mostra esta ajuda
#   -V, --version        Mostra versao

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

WATCH_PATH="."
GLOB="*"
INTERVAL=2
ONCE=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--path)
            [[ -z "${2-}" ]] && { echo "Flag --path requer um valor" >&2; exit 2; }
            WATCH_PATH="$2"; shift 2 ;;
        -g|--glob)
            [[ -z "${2-}" ]] && { echo "Flag --glob requer um valor" >&2; exit 2; }
            GLOB="$2"; shift 2 ;;
        -i|--interval)
            [[ -z "${2-}" ]] && { echo "Flag --interval requer um valor" >&2; exit 2; }
            INTERVAL="$2"; shift 2 ;;
        --once) ONCE=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  file-watcher.sh — Observa arquivos e reporta mudancas"
            echo ""
            echo "  Uso: ./file-watcher.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -p, --path DIR       Diretorio a observar (padrao: .)"
            echo "    -g, --glob PADRAO    Filtro de nome (padrao: *)"
            echo "    -i, --interval N     Intervalo em segundos (padrao: 2)"
            echo "        --once           Tira um snapshot e sai"
            echo "        --json           Saida JSON"
            echo "    -h, --help           Mostra esta ajuda"
            echo "    -V, --version        Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./file-watcher.sh -p ./src -g '*.py'"
            echo "    ./file-watcher.sh --once --json -p ./src"
            echo ""
            exit 0
            ;;
        -V|--version) echo "file-watcher.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

[[ -d "$WATCH_PATH" ]] || error "Diretorio nao encontrado: $WATCH_PATH"
[[ "$INTERVAL" =~ ^[0-9]+$ ]] && [ "$INTERVAL" -ge 1 ] || error "Intervalo invalido: $INTERVAL"
command -v python3 &>/dev/null || error "python3 nao encontrado."

snapshot() {
    find "$WATCH_PATH" -type f -name "$GLOB" -print0 2>/dev/null | while IFS= read -r -d '' f; do
        local tab=$'\t'
        if stat -c "%n${tab}%Y${tab}%s" "$f" 2>/dev/null; then
            :
        else
            stat -f "%N${tab}%m${tab}%z" "$f" 2>/dev/null || true
        fi
    done | sort
}

print_snapshot() {
    local data="$1"
    if $JSON_MODE; then
        printf '{"path":"%s","glob":"%s","files":[' "$(json_escape "$WATCH_PATH")" "$(json_escape "$GLOB")"
        first=true
        while IFS=$'\t' read -r path mtime size; do
            [ -z "$path" ] && continue
            $first || printf ','
            first=false
            printf '{"path":"%s","mtime":%s,"size":%s}' "$(json_escape "$path")" "${mtime:-0}" "${size:-0}"
        done <<< "$data"
        printf ']}\n'
    else
        printf '%s\n' "$data"
    fi
}

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

if $ONCE; then
    print_snapshot "$(snapshot)"
    exit 0
fi

snapshot > "$TMPDIR_WORK/old"
$JSON_MODE || log "Observando $WATCH_PATH (glob: $GLOB, intervalo: ${INTERVAL}s)"

while true; do
    sleep "$INTERVAL"
    snapshot > "$TMPDIR_WORK/new"
    python3 - "$TMPDIR_WORK/old" "$TMPDIR_WORK/new" "$JSON_MODE" <<'PY'
import json, sys

def load(path):
    out = {}
    with open(path) as f:
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 3:
                out[parts[0]] = (parts[1], parts[2])
    return out

old = load(sys.argv[1])
new = load(sys.argv[2])
as_json = sys.argv[3] == "true"
events = []
for path in sorted(set(new) - set(old)):
    events.append(("added", path))
for path in sorted(set(old) - set(new)):
    events.append(("removed", path))
for path in sorted(set(old) & set(new)):
    if old[path] != new[path]:
        events.append(("modified", path))

for event, path in events:
    if as_json:
        print(json.dumps({"event": event, "path": path}, ensure_ascii=False), flush=True)
    else:
        print(f"[{event}] {path}", flush=True)
PY
    mv "$TMPDIR_WORK/new" "$TMPDIR_WORK/old"
done
