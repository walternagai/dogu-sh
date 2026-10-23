#!/bin/bash
# docker-doctor.sh — Diagnostico agregado do Docker (status + saude + auditoria)
# Uso: ./docker-doctor.sh [opcoes]
# Opcoes:
#   --full        Inclui CIS Benchmark e deteccao de gargalos
#   --json        Saida em formato JSON
#   -h, --help    Mostra esta ajuda
#   -V, --version Mostra versao
#
# Este script nao substitui os diagnosticos detalhados: ele agrega os
# resultados de docker-status, docker-healthcheck e docker-audit (e,
# opcionalmente, docker-cis-benchmark e docker-bottleneck-detect).

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

FULL=false
JSON_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --full) FULL=true; shift ;;
        --json) JSON_MODE=true; shift ;;
        -h|--help)
            echo ""
            echo "  docker-doctor.sh — Diagnostico agregado do Docker"
            echo ""
            echo "  Uso: ./docker-doctor.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --full        Inclui CIS Benchmark e gargalos"
            echo "    --json        Saida em formato JSON"
            echo "    -h, --help    Mostra esta ajuda"
            echo "    -V, --version Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./docker-doctor.sh"
            echo "    ./docker-doctor.sh --full"
            echo "    ./docker-doctor.sh --json"
            echo ""
            exit 0
            ;;
        -V|--version) echo "docker-doctor.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) error "Opcao desconhecida: $1" ;;
    esac
done

command -v docker &>/dev/null || error "docker nao encontrado."
docker info &>/dev/null || error "Docker indisponivel ou daemon parado."
command -v jq &>/dev/null || error "jq nao encontrado. Instale jq."

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

run_json_script() {
    local name="$1"; shift
    local out="$TMPDIR_WORK/${name}.json"
    local script="$SCRIPT_DIR/${name}.sh"
    if [ ! -x "$script" ]; then
        printf '{"error":"script ausente: %s"}\n' "$name" > "$out"
        return 0
    fi
    "$script" "$@" > "$out" 2>/dev/null || true
}

run_json_script "docker-status" --json
run_json_script "docker-healthcheck" --json
run_json_script "docker-audit" --json
if $FULL; then
    run_json_script "docker-cis-benchmark" --json --severity fail
    run_json_script "docker-bottleneck-detect" --json
fi

DANGLING_VOLUMES=$(docker volume ls -qf dangling=true 2>/dev/null | wc -l | tr -d ' ')
DANGLING_IMAGES=$(docker images -f dangling=true -q 2>/dev/null | sort -u | wc -l | tr -d ' ')
STOPPED_CONTAINERS=$(docker ps -aq -f status=exited 2>/dev/null | wc -l | tr -d ' ')

REPORT=$(python3 - "$TMPDIR_WORK" "$FULL" "$DANGLING_VOLUMES" "$DANGLING_IMAGES" "$STOPPED_CONTAINERS" <<'PY'
import json, os, sys

tmp, full, dangling_vol, dangling_img, stopped = sys.argv[1], sys.argv[2] == "true", int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])

def load(name):
    path = os.path.join(tmp, name + ".json")
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {"error": "saida invalida ou ausente"}

status = load("docker-status")
health = load("docker-healthcheck")
audit = load("docker-audit")
cis = load("docker-cis-benchmark") if full else {}
bottleneck = load("docker-bottleneck-detect") if full else {}

checks = []
errors = []
warnings = []

def add(label, state, detail):
    checks.append({"label": label, "status": state, "detail": detail})
    if state == "error":
        errors.append(f"{label}: {detail}")
    elif state == "warn":
        warnings.append(f"{label}: {detail}")

if "error" in status:
    add("Status", "error", status["error"])
else:
    c = status.get("containers", {})
    add("Status", "ok", f"{c.get('running', 0)} rodando, {c.get('stopped', 0)} parado(s), {c.get('total', 0)} total")

if "error" in health:
    add("Saude", "error", health["error"])
else:
    s = health.get("summary", {})
    unhealthy = s.get("unhealthy", 0)
    restarted = s.get("restarted", 0)
    if unhealthy or restarted:
        add("Saude", "error", f"{unhealthy} unhealthy, {restarted} reiniciado(s)")
    else:
        add("Saude", "ok", "nenhum container unhealthy")

if "error" in audit:
    add("Auditoria", "warn", audit["error"])
else:
    crit = audit.get("critical", 0)
    warnc = audit.get("warning", 0)
    info = audit.get("info", 0)
    if crit:
        add("Auditoria", "error", f"{crit} critico(s), {warnc} aviso(s), {info} info")
    elif warnc:
        add("Auditoria", "warn", f"{warnc} aviso(s), {info} info")
    else:
        add("Auditoria", "ok", f"nenhum critico ({info} info)")

if stopped:
    add("Containers parados", "warn", f"{stopped} container(s) exited")
else:
    add("Containers parados", "ok", "nenhum container exited")

if dangling_vol or dangling_img:
    add("Objetos dangling", "warn", f"{dangling_img} imagem(ns), {dangling_vol} volume(s)")
else:
    add("Objetos dangling", "ok", "nenhum dangling")

if full:
    if "error" in cis:
        add("CIS Benchmark", "warn", cis["error"])
    else:
        fail = cis.get("fail", 0)
        warnc = cis.get("warn", 0)
        if fail:
            add("CIS Benchmark", "error", f"{fail} fail, {warnc} warn")
        elif warnc:
            add("CIS Benchmark", "warn", f"{warnc} warn")
        else:
            add("CIS Benchmark", "ok", "sem falhas")
    if "error" in bottleneck:
        add("Gargalos", "warn", bottleneck["error"])
    else:
        b = bottleneck.get("bottlenecks", 0)
        w = bottleneck.get("waste", 0)
        if b or w:
            add("Gargalos", "warn", f"{b} gargalo(s), {w} desperdicio(s)")
        else:
            add("Gargalos", "ok", "nenhum gargalo")

overall = "ok"
if errors:
    overall = "critical"
elif warnings:
    overall = "warning"

print(json.dumps({
    "timestamp": __import__("datetime").datetime.now().astimezone().isoformat(timespec="seconds"),
    "status": overall,
    "checks": checks,
    "errors": errors,
    "warnings": warnings,
    "details": {
        "status": status,
        "health": health,
        "audit": audit,
        "cis": cis,
        "bottleneck": bottleneck,
    },
}, ensure_ascii=False))
PY
)

if $JSON_MODE; then
    printf '%s\n' "$REPORT"
else
    echo ""
    echo -e "  ${BOLD}Docker Doctor${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
    echo ""
    printf '%s' "$REPORT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
icons = {"ok": "✅", "warn": "⚠️ ", "error": "❌"}
for c in d["checks"]:
    print("  %s %s: %s" % (icons.get(c["status"], "•"), c["label"], c["detail"]))
'
    echo ""
    case "$(printf '%s' "$REPORT" | jq -r '.status')" in
        ok)       success "Docker saudavel." ;;
        warning)  warn "Docker com avisos; revise os itens acima." ;;
        critical) error "Docker com problemas criticos; revise os itens acima." ;;
    esac
fi

STATE=$(printf '%s' "$REPORT" | jq -r '.status')
[[ "$STATE" == "ok" ]] && exit 0 || exit 1
