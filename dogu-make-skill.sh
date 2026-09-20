#!/usr/bin/env bash
# dogu-make-skill.sh — Gerador de SKILL.md a partir de dogu.json
# Cria um documento estruturado para integração com agentes de IA.

set -euo pipefail

# ─── Cores ───────────────────────────────────────────────────────────
if [[ -n "${NO_COLOR:-}" ]]; then
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
DRY_RUN=false
VERBOSE=false

usage() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÕES]

Gerador de SKILL.md a partir de dogu.json para integração com agentes de IA.

Opções:
  --output CAMINHO   Caminho de saída do SKILL.md (padrão: ./SKILL.md)
  --dry-run          Mostra preview sem escrever arquivo
  --verbose          Mostra detalhes durante geração
  --help             Mostra esta ajuda

Exemplos:
  $(basename "$0")                        # Gera SKILL.md na raiz do projeto
  $(basename "$0") --output /tmp/SKILL.md # Saída customizada
  $(basename "$0") --dry-run              # Preview sem escrever
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output)
      [[ -z "${2:-}" ]] && error "Falta valor para --output"
      OUTPUT="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --verbose)
      VERBOSE=true; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      error "Opção desconhecida: $1 (use --help)" ;;
  esac
done

# ─── Validação prévia ───────────────────────────────────────────────
if ! "$PYTHON" -c "import json; json.load(open('${MANIFEST}'))" 2>/dev/null; then
  error "dogu.json é JSON inválido"
fi

TOTAL=$("$PYTHON" -c "import json; print(json.load(open('${MANIFEST}'))['total_scripts'])")
$VERBOSE && log "Manifesto carregado: ${TOTAL} scripts"

# ─── Geração ────────────────────────────────────────────────────────
generate_skill() {
  local manifest="$1"
  local output="$2"

  "$PYTHON" - "$manifest" "$output" <<'PYTHON_SCRIPT'
import json
import sys

manifest_path = sys.argv[1]
output_path = sys.argv[2]

with open(manifest_path) as f:
    data = json.load(f)

scripts = data.get('scripts', {})
version = data.get('version', '1.0.0')
total = data.get('total_scripts', len(scripts))

# ── Agrupar por categoria ──────────────────────────────────────────
categories = {}
for name, meta in scripts.items():
    cat = meta.get('category', 'other')
    categories.setdefault(cat, []).append((name, meta))

# Ordem de exibição das categorias
cat_order = ['docker', 'system', 'devops', 'network', 'security',
             'productivity', 'conversion', 'media', 'code-analysis', 'other']
cat_names = {
    'docker': 'Docker',
    'system': 'Sistema',
    'devops': 'DevOps',
    'network': 'Rede',
    'security': 'Segurança',
    'productivity': 'Produtividade',
    'conversion': 'Conversão',
    'media': 'Mídia',
    'code-analysis': 'Análise de Código',
    'other': 'Outros',
}
# Garante que categorias novas no manifesto também apareçam
for cat in sorted(categories):
    if cat not in cat_order:
        cat_order.append(cat)

# ── Listas derivadas ───────────────────────────────────────────────
json_scripts = sorted(
    [(n, m) for n, m in scripts.items() if m.get('has_json')],
    key=lambda x: x[0]
)
destructive = sorted(
    [(n, m) for n, m in scripts.items() if m.get('risk') == 'destructive'],
    key=lambda x: x[0]
)

# ── Coletar dependências ──────────────────────────────────────────
all_deps = {}
for name, meta in scripts.items():
    for dep in meta.get('deps', []):
        all_deps.setdefault(dep, []).append(name)

# ── Gerar markdown ─────────────────────────────────────────────────
lines = []

# Frontmatter
lines.append('---')
lines.append('name: dogu-sh')
lines.append('description: >')
lines.append(f'  Coleção de {total} ferramentas Bash para terminal. Use quando precisar de')
lines.append('  diagnóstico Docker, limpeza de sistema, conversão de arquivos, rede,')
lines.append(f'  ou produtividade. Execute via `dogu <comando>`. Use `--json` quando')
lines.append('  disponível para saída parseável. Use `--dry-run` antes de operações')
lines.append('  destrutivas.')
lines.append('---')
lines.append('')
lines.append(f'# dogu-sh — Ferramentas de Terminal')
lines.append('')
lines.append('## Como Usar')
lines.append('')
lines.append('- Sempre tente `./dogu <comando>` primeiro (dispatcher unificado)')
lines.append('- Para saída parseável, use `--json`')
lines.append('- Para operações destrutivas, use `--dry-run` antes de aplicar')
lines.append('- Para bypass de confirmação, use `--yes` (quando disponível)')
lines.append('- Todos os scripts respeitam `NO_COLOR=1`')
lines.append('')

# ── Comandos por categoria ─────────────────────────────────────────
lines.append('## Comandos Disponíveis')
lines.append('')

for cat in cat_order:
    if cat not in categories:
        continue
    scripts_list = sorted(categories[cat])
    cat_name = cat_names.get(cat, cat.title())
    lines.append(f'### {cat_name} ({len(scripts_list)} scripts)')
    lines.append('')
    lines.append('| Script | Risco | Descrição | JSON |')
    lines.append('|--------|-------|-----------|------|')
    for name, meta in scripts_list:
        risk = meta.get('risk', 'unknown')
        desc = meta.get('description', 'Sem descrição')
        has_json = '✅' if meta.get('has_json') else '❌'
        lines.append(f'| `{name}` | {risk} | {desc} | {has_json} |')
    lines.append('')

# ── Scripts com JSON ───────────────────────────────────────────────
if json_scripts:
    lines.append('## Scripts com Saída JSON')
    lines.append('')
    lines.append('Estes scripts produzem JSON válido quando chamados com `--json`:')
    lines.append('')
    lines.append('| Script | Categoria | Descrição |')
    lines.append('|--------|-----------|-----------|')
    for name, meta in json_scripts:
        cat = meta.get('category', 'other')
        desc = meta.get('description', '')
        lines.append(f'| `{name}` | {cat} | {desc} |')
    lines.append('')

# ── Scripts destrutivos ───────────────────────────────────────────
if destructive:
    lines.append('## Scripts Destrutivos')
    lines.append('')
    lines.append('⚠️ Estes scripts modificam/deletam dados. Use `--dry-run` primeiro.')
    lines.append('')
    lines.append('| Script | Categoria | Descrição |')
    lines.append('|--------|-----------|-----------|')
    for name, meta in destructive:
        cat = meta.get('category', 'other')
        desc = meta.get('description', '')
        lines.append(f'| `{name}` | {cat} | {desc} |')
    lines.append('')

# ── Dependências ──────────────────────────────────────────────────
if all_deps:
    lines.append('## Dependências Comuns')
    lines.append('')
    lines.append('| Dependência | Scripts que usam |')
    lines.append('|-------------|------------------|')
    for dep in sorted(all_deps.keys(), key=lambda d: -len(all_deps[d])):
        count = len(all_deps[dep])
        if count <= 3:
            script_list = ', '.join(sorted(all_deps[dep]))
        else:
            top = ', '.join(sorted(all_deps[dep])[:3])
            script_list = f'{top}, ... (+{count - 3})'
        lines.append(f'| `{dep}` | {script_list} |')
    lines.append('')

# ── Escrever saída ────────────────────────────────────────────────
content = '\n'.join(lines) + '\n'
with open(output_path, 'w') as f:
    f.write(content)

line_count = content.count('\n')
print(f'{line_count} lines, {total} scripts, {len(categories)} categories')
PYTHON_SCRIPT
}

# ─── Executar ───────────────────────────────────────────────────────
if $DRY_RUN; then
  log "Modo dry-run — escrevendo em /tmp/dogu-skill-preview.md"
  PREVIEW="/tmp/dogu-skill-preview.md"
  generate_skill "$MANIFEST" "$PREVIEW"
  success "Preview gerado: ${PREVIEW}"
  echo ""
  head -30 "$PREVIEW"
  echo -e "\n${DIM}... (preview cortado)${RESET}"
  echo ""
  LINES=$(wc -l < "$PREVIEW")
  SECTIONS=$(grep -c "^###" "$PREVIEW" || true)
  TABLE_ROWS=$(grep -c "^|" "$PREVIEW" || true)
  log "Estatísticas: ${LINES} linhas, ${SECTIONS} seções, ${TABLE_ROWS} linhas de tabela"
else
  log "Gerando SKILL.md → ${OUTPUT}"
  RESULT=$(generate_skill "$MANIFEST" "$OUTPUT")
  success "Gerado: ${OUTPUT} (${RESULT})"
fi

# ─── Validação pós-geração ──────────────────────────────────────────
if ! $DRY_RUN; then
  if [[ ! -f "$OUTPUT" ]]; then
    error "Arquivo não foi criado: ${OUTPUT}"
  fi

  # Verificar frontmatter
  if ! head -1 "$OUTPUT" | grep -q "^---"; then
    error "Frontmatter ausente: arquivo não começa com ---"
  fi

  # Verificar seções
  SECTIONS=$(grep -c "^###" "$OUTPUT" || true)
  if [[ "$SECTIONS" -eq 0 ]]; then
    error "Nenhuma seção (###) encontrada"
  fi

  # Verificar tabelas
  TABLE_ROWS=$(grep -c "^|" "$OUTPUT" || true)
  if [[ "$TABLE_ROWS" -lt 10 ]]; then
    warn "Poucas linhas de tabela: ${TABLE_ROWS}"
  fi

  LINES=$(wc -l < "$OUTPUT")
  success "Validação OK: ${LINES} linhas, ${SECTIONS} seções, ${TABLE_ROWS} linhas de tabela"
fi
