# AGENTS.md — dōgu-sh

Guia para agentes de IA trabalhando neste repositório.

## Visão Geral

dōgu-sh (道具 — "ferramentas") é uma coleção de **104 ferramentas Bash precisas** para artesãos do terminal. Docker, sistema, rede, produtividade, criptografia, conversão e muito mais para Linux/macOS.

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Linguagem | Bash |
| Dependências | curl, jq, ffmpeg, pdftoppm, e outros CLI comuns |
| Manifesto | `dogu.json` — metadados estruturados de todos os scripts |
| Dispatcher | `dogu` — CLI unificado para acesso a todas as ferramentas |
| Instalação | `install-scripts.sh` → `~/.local/bin` |

## Uso

```bash
# Dispatcher unificado (recomendado)
./dogu list                          # Lista todas as ferramentas
./dogu search docker                 # Busca por descrição
./dogu info docker-status.sh         # Metadados completos
./dogu docker-status                 # Executa diretamente
./dogu docker-status --json          # Saída JSON (para automação)

# Instalar todas as ferramentas
./install-scripts.sh

# Menu interativo
./menu-launcher.sh

# Ferramentas individuais
./docker-status.sh
./disk-health.sh
./pdf-to-jpg.sh arquivo.pdf
```

## Estrutura

```
dogu-sh/
├── dogu                  # Dispatcher unificado (sem extensão .sh)
├── dogu.json             # Manifesto estruturado (metadados de todos os scripts)
├── dogu-make-skill.sh    # Gerador de SKILL.md para agentes de IA
├── SKILL.md              # Skill gerado para Claude Code/OpenCode
├── *.sh                  # 104 scripts (cada um auto-contido)
├── install-scripts.sh    # Instalador
├── menu-launcher.sh      # Menu interativo
├── dependency-helper.sh  # Lib compartilhada de dependências
├── SCRIPTING_GUIDE.md    # Guia para contribuir com scripts
└── README.md
```

## Regras

- Cada script é auto-contido (uma ferramenta por script)
- Shebang `#!/usr/bin/env bash`
- `set -euo pipefail` em todos os scripts
- Suporte a `NO_COLOR` em todos os scripts (padrão [no-color.org](https://no-color.org/))
- Nomes em kebab-case
- Suporte a `--help` em todos os scripts
- Scripts de diagnóstico devem suportar `--json` para saída estruturada
- Todo script novo deve ser registrado no `dogu.json`
- Commits em inglês (Conventional Commits)

## Integração com Agentes de IA

### dogu.json (Manifesto)

O manifesto contém metadados estruturados de todos os scripts:

```json
{
  "docker-status.sh": {
    "description": "Painel resumido do Docker",
    "category": "docker",
    "risk": "read-only",
    "has_json": true,
    "has_dry_run": false,
    "interactive": false,
    "deps": ["docker"],
    "args": [...]
  }
}
```

**Classificação de risco:**
- `read-only`: Seguro para rodar sem confirmação
- `dry-run-ok`: Modifica mas suporta `--dry-run`
- `destructive`: Requer confirmação do usuário

### dogu (Dispatcher)

```bash
./dogu list --json                    # JSON com todos os scripts
./dogu list --category docker         # Filtra por categoria
./dogu search "limpeza"               # Busca por descrição
./dogu info docker-status.sh          # Metadados completos
```

### --json (Saída Estruturada)

25 scripts suportam `--json` para saída parseável:

- **Análise de Código & Agentes:** `codebase-summary.sh`, `context-gather.sh`, `stack-detector.sh`, `impact-analyzer.sh`, `dependency-tree.sh`, `test-coverage.sh`, `git-pr-checklist.sh`
- **Docker:** `docker-status.sh`, `docker-healthcheck.sh`, `docker-audit.sh`, `docker-bottleneck-detect.sh`, `docker-cis-benchmark.sh`, `docker-secret-scanner.sh`, `docker-resource-alert.sh`
- **Sistema & Disco:** `disk-space.sh`, `disk-health.sh`, `partitions-list.sh`, `hunt-duplicates.sh`, `clean-cache.sh`, `clean-system.sh`
- **DevOps, Rede & Segurança:** `env-validator.sh`, `git-stale.sh`, `secret-scanner.sh`, `ip-info.sh`, `lab-manager.sh`

### NO_COLOR

Todos os scripts respeitam `export NO_COLOR=1` para desabilitar cores ANSI.

### Gerador de SKILL.md

Para regenerar o `SKILL.md` após alterações no `dogu.json`:

```bash
./dogu-make-skill.sh                    # Gera SKILL.md na raiz
./dogu-make-skill.sh --dry-run          # Preview sem escrever
./dogu-make-skill.sh --output /tmp/skill.md  # Saída customizada
```
