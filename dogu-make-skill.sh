#!/usr/bin/env bash
# dogu-make-skill.sh — Gerador do pacote de skill (SKILL.md + reference/) a partir de dogu.json
# Produz um artefato enxuto para harnesses de agentes (Claude Code, OpenCode):
# o SKILL.md carrega o protocolo de uso e o índice; os detalhes ficam em reference/.

set -euo pipefail

# ─── Cores ───────────────────────────────────────────────────────────
if [[ -n "${NO_COLOR:-}" ]] || [[ ! -t 1 ]]; then
  GREEN='' YELLOW='' RED='' CYAN='' DIM='' RESET=''
else
  GREEN='\033[1;32m' YELLOW='\033[1;33m' RED='\033[1;31m'
  CYAN='\033[1;36m'
  DIM='\033[0;90m'  RESET='\033[0m'
fi

# ─── Helpers ──────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}::${RESET} $1"; }
success() { echo -e "${GREEN}✓${RESET} $1"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $1" >&2; }
error()   { echo -e "${RED}✗${RESET} $1" >&2; exit 1; }

# ─── Resolve paths ──────────────────────────────────────────────────
readonly VERSION="2.0.0"
readonly MAX_SKILL_LINES=250
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MANIFEST="${SCRIPT_DIR}/dogu.json"

if [[ ! -f "$MANIFEST" ]]; then
  error "Manifesto dogu.json não encontrado em ${SCRIPT_DIR}"
fi

# ─── Python com fallback ────────────────────────────────────────────
PYTHON=""
for candidate in python3 python; do
  if command -v "$candidate" &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done
[[ -z "$PYTHON" ]] && error "Python não encontrado. Necessário para parsear dogu.json"

if ! "$PYTHON" -c "import json" 2>/dev/null; then
  error "Módulo json do Python não disponível"
fi

# ─── CLI ─────────────────────────────────────────────────────────────
OUTPUT="${SCRIPT_DIR}/SKILL.md"
MODE="write"
VERBOSE=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Gera o pacote de skill do dogu-sh a partir de dogu.json:
  SKILL.md           protocolo de uso + índice de categorias (carregado pelo harness)
  reference/*.md     flags, dependências e exemplos por script (lido sob demanda)

Opções:
  --output CAMINHO   Caminho do SKILL.md (padrão: ./SKILL.md); reference/ vai ao lado
  --dry-run          Gera um preview em \${TMPDIR:-/tmp}/dogu-skill-preview/ sem tocar no repo
  --check            Não escreve: falha se SKILL.md/reference/ estiverem fora de sincronia (CI)
  --verbose          Mostra detalhes (inclui diff no --check)
  --version          Mostra versão
  --help             Mostra esta ajuda

Exemplos:
  $(basename "$0")                            # Regenera SKILL.md + reference/
  $(basename "$0") --check                    # Gate de CI: falha em caso de drift
  $(basename "$0") --dry-run                  # Inspeciona a saída sem escrever
  $(basename "$0") --output /tmp/SKILL.md     # Pacote em outro diretório
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ -z "${2:-}" ]] && error "Falta valor para --output"
      OUTPUT="$2"; shift 2 ;;
    --dry-run)
      MODE="preview"; shift ;;
    --check)
      MODE="check"; shift ;;
    --verbose)
      VERBOSE=true; shift ;;
    --version|-V)
      echo "dogu-make-skill.sh $VERSION"; exit 0 ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      error "Opção desconhecida: $1 (use --help)" ;;
  esac
done

if [[ "$MODE" == "preview" ]]; then
  PREVIEW_DIR="${TMPDIR:-/tmp}/dogu-skill-preview"
  OUTPUT="${PREVIEW_DIR}/SKILL.md"
fi

# ─── Validação prévia ───────────────────────────────────────────────
DOGU_MANIFEST="$MANIFEST" "$PYTHON" -c \
  "import json, os; json.load(open(os.environ['DOGU_MANIFEST'], encoding='utf-8'))" \
  2>/dev/null || error "dogu.json é JSON inválido"

TOTAL=$(DOGU_MANIFEST="$MANIFEST" "$PYTHON" -c \
  "import json, os; print(len(json.load(open(os.environ['DOGU_MANIFEST'], encoding='utf-8')).get('scripts', {})))")
[[ -z "$TOTAL" || "$TOTAL" -eq 0 ]] && error "dogu.json não contém scripts"
$VERBOSE && log "Manifesto carregado: ${TOTAL} scripts"

# ─── Geração ────────────────────────────────────────────────────────
generate_skill() {
  local manifest="$1"
  local output="$2"
  local mode="$3"

  "$PYTHON" - "$manifest" "$output" "$mode" "$VERBOSE" <<'PYTHON_SCRIPT'
import difflib
import json
import os
import sys
from collections import OrderedDict

manifest_path, out_path, mode = sys.argv[1], sys.argv[2], sys.argv[3]
verbose = sys.argv[4].lower() == "true"

with open(manifest_path, encoding="utf-8") as fh:
    data = json.load(fh)

scripts = data.get("scripts", {})
if not scripts:
    sys.exit("manifesto sem scripts")

total = len(scripts)
out_path = os.path.abspath(out_path)
out_dir = os.path.dirname(out_path)
ref_dir = os.path.join(out_dir, "reference")

# Ordem, nome e finalidade de cada categoria. Categorias novas no manifesto
# entram no fim, em ordem alfabética, sem edição deste script.
CATEGORY_INFO = OrderedDict([
    ("docker", ("Docker", "containers, imagens, volumes, redes, backups e CIS benchmark")),
    ("system", ("Sistema", "disco, memória, processos, energia, pacotes e arquivos locais")),
    ("devops", ("DevOps", "git, cron, systemd, dotfiles, backups e diagnóstico de projeto")),
    ("network", ("Rede", "DNS, HTTP, portas, SSL, Wi-Fi, SSH, speedtest e túneis")),
    ("security", ("Segurança", "senhas, chaves SSH, segredos e certificados")),
    ("productivity", ("Produtividade", "notas, TODOs, alarmes, calendário, timers e clipboard")),
    ("conversion", ("Conversão", "PDF, DOCX, XLSX, Markdown, imagem, áudio e vídeo")),
    ("media", ("Mídia", "imagem, áudio, vídeo, screenshots e transcrições")),
    ("code-analysis", ("Análise de Código", "resumo, contexto, stack, impacto, dependências e cobertura")),
    ("other", ("Outros", "utilitários e bibliotecas compartilhadas")),
])

# Flags de protocolo já documentadas no SKILL.md; repeti-las em cada script só
# gastaria contexto no harness.
BOILERPLATE_FLAGS = {"--help", "--version", "--json", "--dry-run", "--yes", "--no-color"}

# ── Agrupamento ─────────────────────────────────────────────────────
categories = {}
for name, meta in scripts.items():
    categories.setdefault(meta.get("category", "other"), []).append((name, meta))

for cat in sorted(categories):
    CATEGORY_INFO.setdefault(cat, (cat.replace("-", " ").title(), f"scripts da categoria {cat}"))

ordered_cats = [c for c in CATEGORY_INFO if c in categories]


def clean(text):
    """Normaliza texto para caber em uma linha de Markdown."""
    return " ".join(str(text).replace("|", "\\|").split())


def cmd_name(script):
    return script[:-3] if script.endswith(".sh") else script


def example_for(script, meta):
    """Converte o exemplo do manifesto para a invocação via dispatcher."""
    example = clean(meta.get("example", ""))
    if not example:
        return None
    parts = example.split()
    first = parts[0]
    if first in (script, cmd_name(script), f"./{script}", f"./{cmd_name(script)}"):
        rest = " ".join(parts[1:])
        return f"dogu {cmd_name(script)}" + (f" {rest}" if rest else "")
    return example


def flag_label(arg):
    flag = arg.get("flag", "")
    short = arg.get("short")
    label = f"{flag}, {short}" if short else flag
    kind = arg.get("type")
    return f"{label} ({kind})" if kind else label


def real_flags(meta):
    return [a for a in meta.get("args", []) if a.get("flag") not in BOILERPLATE_FLAGS]


def deps_line(meta):
    parts = []
    if meta.get("deps"):
        parts.append(" + ".join(f"`{d}`" for d in meta["deps"]))
    if meta.get("deps_python"):
        parts.append("Python: " + " + ".join(f"`{d}`" for d in meta["deps_python"]))
    if meta.get("deps_optional"):
        parts.append("opcional: " + " + ".join(f"`{d}`" for d in meta["deps_optional"]))
    for group in meta.get("deps_any", []):
        parts.append("ou ".join(f"`{d}`" for d in group))
    return " · ".join(parts)


def wrap_joined(items, width=100, sep=" · "):
    """Junta itens com `sep` quebrando linhas; a continuação é indentada."""
    lines, current = [], ""
    for item in items:
        candidate = f"{current}{sep}{item}" if current else item
        if len(candidate) > width and current:
            lines.append(current + sep.rstrip())
            current = item
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


def flags_lines(meta):
    flags = real_flags(meta)
    if not flags:
        return []
    rendered = []
    for arg in flags:
        desc = clean(arg.get("desc", ""))
        rendered.append(f"`{flag_label(arg)}`" + (f" {desc}" if desc else ""))
    parts = wrap_joined(rendered)
    lines = [f"- Flags: {parts[0]}"]
    lines.extend(f"  {part}" for part in parts[1:])
    return lines


# ── Contadores ──────────────────────────────────────────────────────
json_scripts = sorted(n for n, m in scripts.items() if m.get("has_json"))
dry_scripts = sorted(n for n, m in scripts.items() if m.get("has_dry_run"))
destructive = sorted(n for n, m in scripts.items() if m.get("risk") == "destructive")
interactive = sorted(n for n, m in scripts.items() if m.get("interactive"))
risk_count = {
    "read-only": sum(1 for m in scripts.values() if m.get("risk") == "read-only"),
    "dry-run-ok": sum(1 for m in scripts.values() if m.get("risk") == "dry-run-ok"),
    "destructive": len(destructive),
}


def wrapped_refs(names, width=96):
    """Lista nomes em linhas de até `width` colunas (legível no harness)."""
    lines, current = [], ""
    for item in (f"`{cmd_name(n)}`" for n in names):
        candidate = f"{current}, {item}" if current else item
        if len(candidate) > width and current:
            lines.append(f"{current},")
            current = item
        else:
            current = candidate
    if current:
        lines.append(current)
    return lines


# ── SKILL.md ────────────────────────────────────────────────────────
L = []
L.append("---")
L.append("name: dogu-sh")
L.append("description: >-")
L.append(f"  Coleção de {total} ferramentas Bash de terminal para Docker, sistema, DevOps,")
L.append("  rede, segurança, produtividade, conversão, mídia e análise de código. Use")
L.append("  quando a tarefa envolver diagnosticar Docker/containers, investigar disco,")
L.append("  memória ou processos, limpar caches, converter ou inspecionar arquivos (PDF,")
L.append("  DOCX, XLSX, imagem, áudio, vídeo), checar DNS/HTTP/SSL/portas, ou automatizar")
L.append(f"  rotinas de terminal. Invoque como `dogu <script> [flags]`; {len(dry_scripts)} scripts")
L.append("  aceitam `--dry-run` e os detalhes (flags, dependências e exemplos) ficam em")
L.append("  reference/.")
L.append("---")
L.append("")
L.append("# dogu-sh — ferramentas de terminal")
L.append("")
L.append(f"Uma coleção de {total} scripts Bash autocontidos, expostos por um dispatcher")
L.append("único (`dogu`). O `SKILL.md` é o contrato geral; `reference/<categoria>.md`")
L.append("traz flags, dependências e exemplos de cada script.")
L.append("")
L.append("## Invocação")
L.append("")
L.append("- `dogu <script> [flags...]` — o sufixo `.sh` é opcional")
L.append("  (`dogu docker-status` e `dogu docker-status.sh` são equivalentes).")
L.append("- `dogu <script> --help` é a fonte de verdade das flags; `dogu info <script>`")
L.append("  mostra risco, dependências, exemplo e flags sem executar nada.")
L.append("- Sem `dogu` no `PATH`? Use `./dogu <script>` na raiz do repositório ou")
L.append("  `./<script>.sh`; `./install-scripts.sh` instala tudo em `~/.local/bin`.")
L.append("- Os scripts operam no diretório atual do chamador. Prefira caminhos absolutos")
L.append("  quando o CWD não for o alvo.")
L.append("- `NO_COLOR=1` desliga cor/ANSI: use ao capturar saída para parsear.")
L.append("- Stdout carrega o resultado; stderr carrega avisos e erros. Verifique o código")
L.append("  de saída (0 = sucesso) antes de assumir que a operação funcionou.")
L.append(f"- {len(json_scripts)} scripts aceitam `--json` (JSON válido em stdout);")
L.append("  prefira essa saída a parsear texto.")
L.append("")
L.append("## Fluxo recomendado")
L.append("")
L.append("1. Descobrir: `dogu search \"<termo>\"` ou `dogu list [--category <cat>] [--json]`.")
L.append("2. Consultar o contrato: `dogu info <script>` ou `dogu <script> --help`.")
L.append("3. Ler `reference/<categoria>.md` quando precisar de flags, dependências e")
L.append("   exemplos de toda a categoria.")
L.append("4. Classificar o risco (tabela abaixo) e escolher a execução segura.")
L.append("5. Executar com `--json` quando existir e validar código de saída e conteúdo.")
L.append("")
L.append("## Política de risco")
L.append("")
L.append("| Risco | Scripts | Conduta no harness |")
L.append("|-------|---------|--------------------|")
L.append(f"| `read-only` | {risk_count['read-only']} | Executar direto; não altera estado. |")
L.append(f"| `dry-run-ok` | {risk_count['dry-run-ok']} | Rodar `--dry-run` primeiro e revisar o plano antes de aplicar. |")
L.append(f"| `destructive` | {risk_count['destructive']} | Só com confirmação explícita do usuário: `--dry-run`, aprovação, execução; `--yes` apenas com aprovação. |")
L.append("")
if interactive:
    L.append(f"## Scripts interativos ({len(interactive)})")
    L.append("")
    L.append("Pedem entrada no stdin e podem bloquear um harness não interativo:")
    L.append("")
    L.extend(wrapped_refs(interactive))
    L.append("")
    L.append("Passe as flags equivalentes ou evite-os em execução automatizada.")
    L.append("")
L.append("## Índice de categorias")
L.append("")
L.append("| Categoria | Scripts | Quando usar | Referência |")
L.append("|-----------|---------|-------------|------------|")
for cat in ordered_cats:
    cat_name, blurb = CATEGORY_INFO[cat]
    L.append(f"| {cat_name} (`{cat}`) | {len(categories[cat])} | {blurb} | `reference/{cat}.md` |")
L.append("")
L.append(f"## Saída JSON ({len(json_scripts)})")
L.append("")
L.append("Use `--json` para obter JSON válido em stdout:")
L.append("")
L.extend(wrapped_refs(json_scripts))
L.append("")
L.append(f"## Scripts destrutivos ({len(destructive)})")
L.append("")
L.append("Exigem confirmação explícita — leia a política de risco antes de executar:")
L.append("")
L.extend(wrapped_refs(destructive))
L.append("")
L.append("## Manutenção")
L.append("")
L.append("- `./dogu-make-skill.sh` regenera `SKILL.md` + `reference/` a partir de")
L.append("  `dogu.json`; não edite os arquivos gerados à mão.")
L.append("- `./dogu-make-skill.sh --check` falha em caso de drift (usado no CI).")
L.append("- `dogu doctor` valida manifesto, arquivos, menu, README e SKILL.md.")
L.append("")

skill_content = "\n".join(L)


# ── Referências por categoria ───────────────────────────────────────
def plural(n, singular, plural_word):
    return f"{n} {singular if n == 1 else plural_word}"


def render_reference(cat):
    cat_name, blurb = CATEGORY_INFO[cat]
    entries = sorted(categories[cat])
    cat_json = sum(1 for _, m in entries if m.get("has_json"))
    cat_dry = sum(1 for _, m in entries if m.get("has_dry_run"))
    lines = [
        f"# {cat_name} — referência",
        "",
        f"Categoria `{cat}` · {plural(len(entries), 'script', 'scripts')} · "
        f"{cat_json} com `--json` · {cat_dry} com `--dry-run`.",
        "",
        f"{blurb[0].upper() + blurb[1:]}.",
        "",
        "Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de",
        "flags: `dogu <script> --help`.",
        "",
    ]
    for name, meta in entries:
        desc = clean(meta.get("description", "Sem descrição"))
        lines.append(f"## {name} — {desc}")
        lines.append("")
        lines.append(
            f"- Risco: `{meta.get('risk', 'unknown')}`"
            f" · JSON: {'sim' if meta.get('has_json') else 'não'}"
            f" · Dry-run: {'sim' if meta.get('has_dry_run') else 'não'}"
            f" · Interativo: {'sim' if meta.get('interactive') else 'não'}"
        )
        deps = deps_line(meta)
        if deps:
            lines.append(f"- Dependências: {deps}")
        example = example_for(name, meta)
        if example:
            lines.append(f"- Exemplo: `{example}`")
        lines.extend(flags_lines(meta))
        lines.append("")
    return "\n".join(lines)


expected = {os.path.join(ref_dir, f"{cat}.md"): render_reference(cat) for cat in ordered_cats}


# ── Escrita / verificação ───────────────────────────────────────────
def write_atomic(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(content)
    os.replace(tmp, path)


def stale_refs():
    if not os.path.isdir(ref_dir):
        return []
    return sorted(
        os.path.join(ref_dir, f)
        for f in os.listdir(ref_dir)
        if f.endswith(".md") and os.path.join(ref_dir, f) not in expected
    )


if mode == "check":
    expected_all = {out_path: skill_content}
    expected_all.update(expected)

    problems = []
    for path, content in expected_all.items():
        if not os.path.exists(path):
            problems.append(("faltando", path))
            continue
        with open(path, encoding="utf-8") as fh:
            if fh.read() != content:
                problems.append(("desatualizado", path))
    problems += [("sobrando", p) for p in stale_refs()]

    if problems:
        print(f"fora de sincronia: {len(problems)} arquivo(s)", file=sys.stderr)
        for kind, path in problems:
            print(f"  {kind}: {os.path.relpath(path, out_dir)}", file=sys.stderr)
        if verbose:
            for kind, path in problems:
                if kind != "desatualizado":
                    continue
                rel = os.path.relpath(path, out_dir)
                with open(path, encoding="utf-8") as fh:
                    current = fh.read()
                diff = difflib.unified_diff(
                    current.splitlines(), expected_all[path].splitlines(),
                    fromfile=f"{rel} (atual)", tofile=f"{rel} (esperado)",
                    lineterm="", n=2,
                )
                print("\n".join(list(diff)[:120]), file=sys.stderr)
        sys.exit(1)

    print(f"em sincronia: SKILL.md + {len(expected)} referências, {total} scripts")
    sys.exit(0)

write_atomic(out_path, skill_content)
for path, content in expected.items():
    write_atomic(path, content)

removed = stale_refs()
for path in removed:
    os.remove(path)

print(
    f"{skill_content.count(chr(10))} linhas, {total} scripts, "
    f"{len(ordered_cats)} categorias, {len(expected)} referências"
    + (f", {len(removed)} referência(s) removida(s)" if removed else "")
)
PYTHON_SCRIPT
}

# ─── Executar ───────────────────────────────────────────────────────
if [[ "$MODE" == "check" ]]; then
  log "Verificando sincronia do pacote de skill"
  if RESULT=$(generate_skill "$MANIFEST" "$OUTPUT" "check"); then
    success "$RESULT"
  else
    error "Skill fora de sincronia — rode ./dogu-make-skill.sh (use --verbose para ver o diff)"
  fi
  exit 0
fi

if [[ "$MODE" == "preview" ]]; then
  log "Modo dry-run — escrevendo preview em ${PREVIEW_DIR}"
  RESULT=$(generate_skill "$MANIFEST" "$OUTPUT" "write")
  success "Preview gerado: ${OUTPUT} (${RESULT})"
  echo ""
  head -40 "$OUTPUT"
  echo -e "\n${DIM}... (preview cortado)${RESET}"
  echo ""
  LINES=$(wc -l < "$OUTPUT")
  REFS=$(find "${PREVIEW_DIR}/reference" -name '*.md' -type f | wc -l)
  log "Estatísticas: ${LINES} linhas no SKILL.md, ${REFS} referências"
  exit 0
fi

log "Gerando pacote de skill → ${OUTPUT}"
RESULT=$(generate_skill "$MANIFEST" "$OUTPUT" "write")
success "Gerado: ${OUTPUT} (${RESULT})"

# ─── Validação pós-geração ──────────────────────────────────────────
[[ -f "$OUTPUT" ]] || error "Arquivo não foi criado: ${OUTPUT}"
[[ "$(head -1 "$OUTPUT")" == "---" ]] || error "Frontmatter ausente: arquivo não começa com ---"

SECTIONS=$(grep -c '^## ' "$OUTPUT" || true)
[[ "$SECTIONS" -eq 0 ]] && error "Nenhuma seção (##) encontrada no SKILL.md"

REF_DIR="$(dirname "$OUTPUT")/reference"
[[ -d "$REF_DIR" ]] || error "Diretório de referências não foi criado: ${REF_DIR}"
REFS=$(find "$REF_DIR" -maxdepth 1 -name '*.md' -type f | wc -l)
[[ "$REFS" -eq 0 ]] && error "Nenhuma referência gerada em ${REF_DIR}"

LINES=$(wc -l < "$OUTPUT")
if [[ "$LINES" -gt "$MAX_SKILL_LINES" ]]; then
  warn "SKILL.md com ${LINES} linhas (limite recomendado: ${MAX_SKILL_LINES}) — detalhes deveriam ir para reference/"
fi

success "Validação OK: ${LINES} linhas, ${SECTIONS} seções, ${REFS} referências"
