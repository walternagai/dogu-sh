# Análise de Código — referência

Categoria `code-analysis` · 6 scripts · 6 com `--json` · 0 com `--dry-run`.

Resumo, contexto, stack, impacto, dependências e cobertura.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## codebase-summary.sh — Resumo completo do projeto para agentes de IA entenderem o codebase

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu codebase-summary --json --path /meu/projeto`
- Flags: `--path, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--deep, -d (bool)` Analise profunda (inclui complexidade)

## context-gather.sh — Coleta contexto do projeto para agentes de IA antes de modificar codigo

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu context-gather --json --file src/auth.py`
- Flags: `--project, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--file, -f (string)` Arquivo especifico para analisar ·
  `--include-deps (bool)` Inclui analise de dependencias ·
  `--include-tests (bool)` Inclui testes relacionados

## dependency-tree.sh — Mostra arvore de dependencias internas do projeto

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu dependency-tree --json --project /meu/projeto`
- Flags: `--file, -f (string)` Arquivo especifico para analisar ·
  `--project, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--max-depth, -d (int)` Profundidade maxima (padrao: 3)

## impact-analyzer.sh — Analisa o impacto de alteracoes em arquivos especificos

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu impact-analyzer --json --file src/auth.py`
- Flags: `--file, -f (string)` Arquivo a analisar (obrigatorio) ·
  `--project, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--depth, -d (int)` Profundidade da analise de dependencias (padrao: 2)

## stack-detector.sh — Detecta automaticamente a stack tecnologica do projeto

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu stack-detector --json --path /meu/projeto`
- Flags: `--path, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--verbose, -v (bool)` Mostra detalhes da deteccao

## test-coverage.sh — Analise de cobertura de testes por modulo

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu test-coverage --json --project /meu/projeto`
- Flags: `--project, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--source, -s (string)` Diretorio fonte para analise (padrao: src/) ·
  `--tests, -t (string)` Diretorio de testes (padrao: tests/)
