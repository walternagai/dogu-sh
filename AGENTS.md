# AGENTS.md — dōgu-sh

Guia para agentes de IA trabalhando neste repositório.

## Visão Geral

dōgu-sh (道具 — "ferramentas") é uma coleção de **87 ferramentas Bash precisas** para artesãos do terminal. Docker, sistema, rede, produtividade, criptografia, conversão e muito mais para Linux/macOS.

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Linguagem | Bash |
| Dependências | curl, jq, ffmpeg, pdftoppm, e outros CLI comuns |
| Instalação | `install-scripts.sh` → `~/.local/bin` |

## Uso

```bash
# Instalar todas as ferramentas
./install-scripts.sh

# Menu interativo
./menu-launcher.sh

# Ferramentas individuais
./docker-status.sh
./disk-health.sh
./network-info.sh
./pdf-to-jpg.sh arquivo.pdf
```

## Estrutura

```
dogu-sh/
├── *.sh              # 87 scripts (cada um auto-contido)
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
- Nomes em kebab-case
- Suporte a `--help` em todos os scripts
- Commits em inglês (Conventional Commits)
