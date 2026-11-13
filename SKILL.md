---
name: dogu-sh
description: >-
  Coleção de 117 ferramentas Bash de terminal para Docker, sistema, DevOps,
  rede, segurança, produtividade, conversão, mídia e análise de código. Use
  quando a tarefa envolver diagnosticar Docker/containers, investigar disco,
  memória ou processos, limpar caches, converter ou inspecionar arquivos (PDF,
  DOCX, XLSX, imagem, áudio, vídeo), checar DNS/HTTP/SSL/portas, ou automatizar
  rotinas de terminal. Invoque como `dogu <script> [flags]`; 51 scripts
  aceitam `--dry-run` e os detalhes (flags, dependências e exemplos) ficam em
  reference/.
---

# dogu-sh — ferramentas de terminal

Uma coleção de 117 scripts Bash autocontidos, expostos por um dispatcher
único (`dogu`). O `SKILL.md` é o contrato geral; `reference/<categoria>.md`
traz flags, dependências e exemplos de cada script.

## Invocação

- `dogu <script> [flags...]` — o sufixo `.sh` é opcional
  (`dogu docker-status` e `dogu docker-status.sh` são equivalentes).
- `dogu <script> --help` é a fonte de verdade das flags; `dogu info <script>`
  mostra risco, dependências, exemplo e flags sem executar nada.
- Sem `dogu` no `PATH`? Use `./dogu <script>` na raiz do repositório ou
  `./<script>.sh`; `./install-scripts.sh` instala tudo em `~/.local/bin`.
- Os scripts operam no diretório atual do chamador. Prefira caminhos absolutos
  quando o CWD não for o alvo.
- `NO_COLOR=1` desliga cor/ANSI: use ao capturar saída para parsear.
- Stdout carrega o resultado; stderr carrega avisos e erros. Verifique o código
  de saída (0 = sucesso) antes de assumir que a operação funcionou.
- 43 scripts aceitam `--json` (JSON válido em stdout);
  prefira essa saída a parsear texto.

## Fluxo recomendado

1. Descobrir: `dogu search "<termo>"` ou `dogu list [--category <cat>] [--json]`.
2. Consultar o contrato: `dogu info <script>` ou `dogu <script> --help`.
3. Ler `reference/<categoria>.md` quando precisar de flags, dependências e
   exemplos de toda a categoria.
4. Classificar o risco (tabela abaixo) e escolher a execução segura.
5. Executar com `--json` quando existir e validar código de saída e conteúdo.

## Política de risco

| Risco | Scripts | Conduta no harness |
|-------|---------|--------------------|
| `read-only` | 68 | Executar direto; não altera estado. |
| `dry-run-ok` | 38 | Rodar `--dry-run` primeiro e revisar o plano antes de aplicar. |
| `destructive` | 11 | Só com confirmação explícita do usuário: `--dry-run`, aprovação, execução; `--yes` apenas com aprovação. |

## Scripts interativos (8)

Pedem entrada no stdin e podem bloquear um harness não interativo:

`calculator`, `dependency-helper`, `git-stale`, `hunt-duplicates`, `menu-launcher`,
`process-killer`, `setup-workspace`, `stopwatch`

Passe as flags equivalentes ou evite-os em execução automatizada.

## Índice de categorias

| Categoria | Scripts | Quando usar | Referência |
|-----------|---------|-------------|------------|
| Docker (`docker`) | 18 | containers, imagens, volumes, redes, backups e CIS benchmark | `reference/docker.md` |
| Sistema (`system`) | 25 | disco, memória, processos, energia, pacotes e arquivos locais | `reference/system.md` |
| DevOps (`devops`) | 17 | git, cron, systemd, dotfiles, backups e diagnóstico de projeto | `reference/devops.md` |
| Rede (`network`) | 10 | DNS, HTTP, portas, SSL, Wi-Fi, SSH, speedtest e túneis | `reference/network.md` |
| Segurança (`security`) | 5 | senhas, chaves SSH, segredos e certificados | `reference/security.md` |
| Produtividade (`productivity`) | 13 | notas, TODOs, alarmes, calendário, timers e clipboard | `reference/productivity.md` |
| Conversão (`conversion`) | 15 | PDF, DOCX, XLSX, Markdown, imagem, áudio e vídeo | `reference/conversion.md` |
| Mídia (`media`) | 7 | imagem, áudio, vídeo, screenshots e transcrições | `reference/media.md` |
| Análise de Código (`code-analysis`) | 6 | resumo, contexto, stack, impacto, dependências e cobertura | `reference/code-analysis.md` |
| Outros (`other`) | 1 | utilitários e bibliotecas compartilhadas | `reference/other.md` |

## Saída JSON (43)

Use `--json` para obter JSON válido em stdout:

`clean-cache`, `clean-system`, `codebase-summary`, `context-gather`, `cron-manager`,
`dependency-tree`, `disk-health`, `disk-space`, `docker-audit`, `docker-bottleneck-detect`,
`docker-cis-benchmark`, `docker-doctor`, `docker-healthcheck`, `docker-image-slimmer`,
`docker-logs-watcher`, `docker-resource-alert`, `docker-secret-scanner`, `docker-stats-history`,
`docker-status`, `docker-volume-mgr`, `dotfiles-manager`, `env-validator`, `file-watcher`,
`git-pr-checklist`, `git-stale`, `image-optimizer`, `impact-analyzer`, `ip-info`, `lab-manager`,
`partitions-list`, `pdf-merge`, `pdf-split`, `port-check`, `secret-scanner`,
`snap-flatpak-manager`, `speedtest-log`, `ssh-key-manager`, `ssl-cert-check`, `stack-detector`,
`systemd-timer`, `test-coverage`, `video-to-text`, `wifi-scanner`

## Scripts destrutivos (11)

Exigem confirmação explícita — leia a política de risco antes de executar:

`clean-system`, `cron-manager`, `dedup-files`, `docker-restore`, `dotfiles-manager`,
`folder-sync`, `git-stale`, `git-sync`, `hunt-duplicates`, `process-killer`, `systemd-timer`

## Manutenção

- `./dogu-make-skill.sh` regenera `SKILL.md` + `reference/` a partir de
  `dogu.json`; não edite os arquivos gerados à mão.
- `./dogu-make-skill.sh --check` falha em caso de drift (usado no CI).
- `dogu doctor` valida manifesto, arquivos, menu, README e SKILL.md.
