---
name: dogu-sh
description: >
  Coleção de 104 ferramentas Bash para terminal. Use quando precisar de
  diagnóstico Docker, limpeza de sistema, conversão de arquivos, rede,
  ou produtividade. Execute via `dogu <comando>`. Use `--json` quando
  disponível para saída parseável. Use `--dry-run` antes de operações
  destrutivas.
---

# dogu-sh — Ferramentas de Terminal

## Como Usar

- Sempre tente `./dogu <comando>` primeiro (dispatcher unificado)
- Para saída parseável, use `--json`
- Para operações destrutivas, use `--dry-run` antes de aplicar
- Para bypass de confirmação, use `--yes` (quando disponível)
- Todos os scripts respeitam `NO_COLOR=1`

## Comandos Disponíveis

### Docker (17 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `docker-audit.sh` | read-only | Auditoria de seguranca de containers Docker | ✅ |
| `docker-backup.sh` | dry-run-ok | Backup de volumes e configuracoes de containers | ❌ |
| `docker-bottleneck-detect.sh` | read-only | Detecta gargalos comparando limites config vs uso real | ✅ |
| `docker-cis-benchmark.sh` | read-only | Verifica conformidade com CIS Docker Benchmark | ✅ |
| `docker-clean.sh` | dry-run-ok | Limpa recursos nao utilizados do Docker | ❌ |
| `docker-compose-manager.sh` | dry-run-ok | Gerencia multiplos docker-compose.yml | ❌ |
| `docker-dependency-map.sh` | read-only | Mapeia relacoes de dependencia entre containers | ❌ |
| `docker-healthcheck.sh` | dry-run-ok | Verifica saude dos containers e reinicia unhealthy | ✅ |
| `docker-image-slimmer.sh` | read-only | Analisa camadas de imagens e sugere reducoes | ❌ |
| `docker-logs-watcher.sh` | read-only | Monitora logs de containers com filtros | ❌ |
| `docker-network-manager.sh` | dry-run-ok | Gerencia redes Docker (criar, remover, conectar, desconectar) | ❌ |
| `docker-resource-alert.sh` | read-only | Alerta quando container ultrapassa limites de CPU/RAM | ✅ |
| `docker-restore.sh` | destructive | Restaura volumes e configuracoes de containers | ❌ |
| `docker-secret-scanner.sh` | read-only | Escaneia containers em busca de segredos expostos | ✅ |
| `docker-stats-history.sh` | read-only | Registra historico de CPU/RAM dos containers em CSV | ❌ |
| `docker-status.sh` | read-only | Painel resumido do Docker | ✅ |
| `docker-volume-mgr.sh` | dry-run-ok | Lista, identifica orfaos, faz backup e restaura volumes Docker | ❌ |

### Sistema (24 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `archive-manager.sh` | dry-run-ok | Compacta pastas individualmente ou descompacta arquivos em massa | ❌ |
| `batch-rename.sh` | dry-run-ok | Renomeia arquivos em lote por padrao de busca/substituicao | ❌ |
| `battery-monitor.sh` | read-only | Status da bateria com alerta de nivel baixo/critico | ❌ |
| `brightness.sh` | read-only | Controle de brilho do monitor | ❌ |
| `clean-cache.sh` | dry-run-ok | Limpa arquivos temporarios e caches de aplicacoes | ✅ |
| `clean-system.sh` | destructive | Limpeza profunda do sistema (complemento ao clean-cache) | ✅ |
| `dark-mode.sh` | read-only | Alterna tema claro/escuro em GTK e terminais | ❌ |
| `dedup-files.sh` | destructive | Compara varios arquivos e remove duplicados | ❌ |
| `dependency-checker.sh` | read-only | Verifica dependencias externas do projeto dogu-sh | ❌ |
| `dir-summary.sh` | read-only | Resumo de diretorio: conta arquivos, tipos e tamanho | ❌ |
| `disk-health.sh` | read-only | Verifica saude SMART do disco e alerta problemas | ✅ |
| `disk-scanner.sh` | read-only | Identifica os maiores arquivos e pastas no disco | ❌ |
| `disk-space.sh` | read-only | Mostra espaco disponivel nos discos com identificacao de tipo (SSD/NVMe/HDD) | ✅ |
| `fix-exec-bit.sh` | dry-run-ok | Remove bit de execucao de arquivos de dados (util apos copiar de NTFS/exFAT) | ❌ |
| `hunt-duplicates.sh` | destructive | Encontra arquivos duplicados por hash SHA-256 | ✅ |
| `log-analyzer.sh` | read-only | Analisador de logs com coloracao e filtros | ❌ |
| `nvidia-gpu-monitor.sh` | read-only | Monitora atividade da GPU NVIDIA em segundo plano | ❌ |
| `organize-downloads.sh` | dry-run-ok | Organiza arquivos por tipo de extensao | ❌ |
| `partitions-list.sh` | read-only | Lista todas as particoes (montadas ou nao) com tipo de disco | ✅ |
| `process-killer.sh` | destructive | Seletor interativo de processos para termino | ❌ |
| `setup-workspace.sh` | dry-run-ok | Multi-monitor workspace manager para Linux | ❌ |
| `unarchive.sh` | dry-run-ok | Descompacta arquivos compactados (zip, rar, 7z, tar, etc.) | ❌ |
| `update-all.sh` | dry-run-ok | Atualiza pacotes do sistema e linguagens em um comando | ❌ |
| `volume.sh` | read-only | Controle de volume e mute via PulseAudio/PipeWire | ❌ |

### DevOps (13 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `env-manager.sh` | read-only | Orquestrador de ambientes e dependencias multiplataforma | ❌ |
| `env-validator.sh` | read-only | Valida variaveis de ambiente obrigatorias para o projeto | ✅ |
| `folder-sync.sh` | destructive | Sincroniza diretorios com rsync | ❌ |
| `git-pr-checklist.sh` | read-only | Checklist automatico de qualidade e conformidade antes de abrir Pull Request | ✅ |
| `git-stale.sh` | destructive | Lista branches antigas sem merge que podem ser limpas | ✅ |
| `git-sync.sh` | destructive | Sincroniza multiplos repositorios git | ❌ |
| `install-scripts.sh` | dry-run-ok | Instala scripts no ~/.local/bin e configura o PATH | ❌ |
| `lab-manager.sh` | dry-run-ok | Gerenciador unificado de ambiente de desenvolvimento | ✅ |
| `menu-launcher.sh` | read-only | Menu interativo com barra luminosa para selecao de scripts | ❌ |
| `nerd-font-install.sh` | dry-run-ok | Baixa e instala fontes Nerd Fonts | ❌ |
| `package-list-backup.sh` | dry-run-ok | Exporta/importa lista de pacotes instalados para replicar maquina | ❌ |
| `quick-backup.sh` | dry-run-ok | Backup incremental com rsync | ❌ |
| `snap-flatpak-manager.sh` | dry-run-ok | Lista, atualiza e limpa snaps e flatpaks | ❌ |

### Rede (9 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `api-tester.sh` | read-only | Teste rapido de APIs REST com formatacao JSON | ❌ |
| `dns-lookup.sh` | read-only | Lookup DNS (A, AAAA, MX, NS, TXT, CNAME) | ❌ |
| `ip-info.sh` | read-only | Info do IP publico, ISP e localizacao geografica | ✅ |
| `port-check.sh` | read-only | Verifica se portas estao abertas em um host | ❌ |
| `speedtest-log.sh` | read-only | Executa testes de velocidade e mantem historico em CSV | ❌ |
| `ssh-tunnel-mgr.sh` | read-only | Gerenciador de tuneis SSH | ❌ |
| `subnet-calc.sh` | read-only | Calculadora de sub-redes IPv4/CIDR | ❌ |
| `whois.sh` | read-only | Consulta WHOIS de dominios | ❌ |
| `wifi-scanner.sh` | read-only | Escaneia redes Wi-Fi e sugere o melhor canal | ❌ |

### Segurança (4 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `env-keygen.sh` | dry-run-ok | Gera chaves secretas seguras para uso em arquivos .env | ❌ |
| `password-gen.sh` | read-only | Gerador de senhas configuravel | ❌ |
| `secret-scanner.sh` | read-only | Busca segredos expostos em codigo e configuracao (API keys, tokens, senhas) | ✅ |
| `ssh-key-manager.sh` | dry-run-ok | Gerencia chaves SSH (gerar, listar, rotacionar, distribuir) | ❌ |

### Produtividade (13 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `alarm.sh` | read-only | Alarme e cronometro com notificacoes | ❌ |
| `calculator.sh` | read-only | Calculadora interativa com historico e suporte a expressoes | ❌ |
| `calendar.sh` | read-only | Calendario mensal com marcacao de eventos | ❌ |
| `clipboard-manager.sh` | read-only | Historico do clipboard com busca e persistencia | ❌ |
| `download-icons.sh` | dry-run-ok | Baixa icones Material Design Icons (MDI) e converte para PNG | ❌ |
| `pomodoro-timer.sh` | read-only | Timer Pomodoro com notificacoes | ❌ |
| `qr-gen.sh` | read-only | Gera QR Code no terminal ou salva como PNG | ❌ |
| `quick-notes.sh` | read-only | Bloco de notas rapido com busca e tags | ❌ |
| `stopwatch.sh` | read-only | Cronometro com voltas (laps) | ❌ |
| `todo.sh` | read-only | Lista de tarefas com prioridades, categorias e persistencia | ❌ |
| `url-shortener.sh` | read-only | Encurta URLs usando is.gd | ❌ |
| `weather.sh` | read-only | Previsao do tempo via wttr.in com localizacao automatica | ❌ |
| `world-clock.sh` | read-only | Relogio com multiplos fusos horarios configuraveis | ❌ |

### Conversão (11 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `base64-tool.sh` | read-only | Codifica/decodifica Base64, URL encode, hex | ❌ |
| `color-converter.sh` | read-only | Conversao entre HEX, RGB, HSL e nome de cor + preview | ❌ |
| `currency-converter.sh` | read-only | Cotacao de moedas em tempo real via API | ❌ |
| `docx-to-md.sh` | dry-run-ok | Converte arquivos .docx para Markdown via pandoc | ❌ |
| `jpg-to-text.sh` | dry-run-ok | Extrai texto de imagens JPG via OCR | ❌ |
| `md-to-pdf.sh` | read-only | Converte Markdown para PDF usando pandoc + XeLaTeX | ❌ |
| `pdf-to-jpg.sh` | dry-run-ok | Converte arquivos .pdf em imagens JPG | ❌ |
| `pdf-to-md.sh` | dry-run-ok | Converte arquivos .pdf para Markdown extraindo o texto | ❌ |
| `ris-to-csv.sh` | dry-run-ok | Converte arquivos .ris (citacoes bibliograficas) para CSV | ❌ |
| `unit-converter.sh` | read-only | Conversao entre unidades de medida | ❌ |
| `xlsx-to-csv.sh` | dry-run-ok | Converte arquivos .xlsx para CSV, extraindo cada aba em arquivo separado | ❌ |

### Mídia (6 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `audio-to-text.sh` | dry-run-ok | Transcreve arquivos de audio locais via Whisper | ❌ |
| `media-control.sh` | read-only | Controla players MPRIS e mostra now playing | ❌ |
| `screenshot.sh` | read-only | Captura de tela com salvamento automatico | ❌ |
| `video-catalog-organizer.sh` | dry-run-ok | Organiza catalogo de videos por estrategia | ❌ |
| `video-to-audio.sh` | dry-run-ok | Extrai a trilha de audio de arquivos de video | ❌ |
| `yt-transcript.sh` | dry-run-ok | Baixa transcricoes de videos do YouTube (EN e PT-BR) | ❌ |

### Outros (1 scripts)

| Script | Risco | Descrição | JSON |
|--------|-------|-----------|------|
| `dependency-helper.sh` | read-only | Biblioteca interna para verificacao e instalacao de dependencias | ❌ |

## Scripts com Saída JSON

Estes scripts produzem JSON válido quando chamados com `--json`:

| Script | Categoria | Descrição |
|--------|-----------|-----------|
| `clean-cache.sh` | system | Limpa arquivos temporarios e caches de aplicacoes |
| `clean-system.sh` | system | Limpeza profunda do sistema (complemento ao clean-cache) |
| `codebase-summary.sh` | code-analysis | Resumo completo do projeto para agentes de IA entenderem o codebase |
| `context-gather.sh` | code-analysis | Coleta contexto do projeto para agentes de IA antes de modificar codigo |
| `dependency-tree.sh` | code-analysis | Mostra arvore de dependencias internas do projeto |
| `disk-health.sh` | system | Verifica saude SMART do disco e alerta problemas |
| `disk-space.sh` | system | Mostra espaco disponivel nos discos com identificacao de tipo (SSD/NVMe/HDD) |
| `docker-audit.sh` | docker | Auditoria de seguranca de containers Docker |
| `docker-bottleneck-detect.sh` | docker | Detecta gargalos comparando limites config vs uso real |
| `docker-cis-benchmark.sh` | docker | Verifica conformidade com CIS Docker Benchmark |
| `docker-healthcheck.sh` | docker | Verifica saude dos containers e reinicia unhealthy |
| `docker-resource-alert.sh` | docker | Alerta quando container ultrapassa limites de CPU/RAM |
| `docker-secret-scanner.sh` | docker | Escaneia containers em busca de segredos expostos |
| `docker-status.sh` | docker | Painel resumido do Docker |
| `env-validator.sh` | devops | Valida variaveis de ambiente obrigatorias para o projeto |
| `git-pr-checklist.sh` | devops | Checklist automatico de qualidade e conformidade antes de abrir Pull Request |
| `git-stale.sh` | devops | Lista branches antigas sem merge que podem ser limpas |
| `hunt-duplicates.sh` | system | Encontra arquivos duplicados por hash SHA-256 |
| `impact-analyzer.sh` | code-analysis | Analisa o impacto de alteracoes em arquivos especificos |
| `ip-info.sh` | network | Info do IP publico, ISP e localizacao geografica |
| `lab-manager.sh` | devops | Gerenciador unificado de ambiente de desenvolvimento |
| `partitions-list.sh` | system | Lista todas as particoes (montadas ou nao) com tipo de disco |
| `secret-scanner.sh` | security | Busca segredos expostos em codigo e configuracao (API keys, tokens, senhas) |
| `stack-detector.sh` | code-analysis | Detecta automaticamente a stack tecnologica do projeto |
| `test-coverage.sh` | code-analysis | Analise de cobertura de testes por modulo |

## Scripts Destrutivos

⚠️ Estes scripts modificam/deletam dados. Use `--dry-run` primeiro.

| Script | Categoria | Descrição |
|--------|-----------|-----------|
| `clean-system.sh` | system | Limpeza profunda do sistema (complemento ao clean-cache) |
| `dedup-files.sh` | system | Compara varios arquivos e remove duplicados |
| `docker-restore.sh` | docker | Restaura volumes e configuracoes de containers |
| `folder-sync.sh` | devops | Sincroniza diretorios com rsync |
| `git-stale.sh` | devops | Lista branches antigas sem merge que podem ser limpas |
| `git-sync.sh` | devops | Sincroniza multiplos repositorios git |
| `hunt-duplicates.sh` | system | Encontra arquivos duplicados por hash SHA-256 |
| `process-killer.sh` | system | Seletor interativo de processos para termino |

## Dependências Comuns

| Dependência | Scripts que usam |
|-------------|------------------|
| `docker` | docker-audit.sh, docker-backup.sh, docker-bottleneck-detect.sh, ... (+14) |
| `bc` | calculator.sh, clean-cache.sh, clean-system.sh, ... (+6) |
| `curl` | api-tester.sh, currency-converter.sh, ip-info.sh, ... (+4) |
| `unzip` | archive-manager.sh, nerd-font-install.sh, unarchive.sh |
| `git` | git-pr-checklist.sh, git-stale.sh, git-sync.sh |
| `tar` | archive-manager.sh, unarchive.sh |
| `ffmpeg` | audio-to-text.sh, video-to-audio.sh |
| `python3` | base64-tool.sh, xlsx-to-csv.sh |
| `xrandr` | brightness.sh, setup-workspace.sh |
| `sha256sum` | dedup-files.sh, hunt-duplicates.sh |
| `lsblk` | disk-space.sh, partitions-list.sh |
| `pandoc` | docx-to-md.sh, md-to-pdf.sh |
| `rsvg-convert` | download-icons.sh, md-to-pdf.sh |
| `rsync` | folder-sync.sh, quick-backup.sh |
| `tesseract` | jpg-to-text.sh, pdf-to-md.sh |
| `grep` | log-analyzer.sh, secret-scanner.sh |
| `fzf` | menu-launcher.sh, process-killer.sh |
| `pdftoppm` | pdf-to-jpg.sh, pdf-to-md.sh |
| `zip` | archive-manager.sh |
| `xxd` | base64-tool.sh |
| `sed` | batch-rename.sh |
| `mv` | batch-rename.sh |
| `light` | brightness.sh |
| `brightnessctl` | brightness.sh |
| `wl-copy` | clipboard-manager.sh |
| `xclip` | clipboard-manager.sh |
| `find` | dedup-files.sh |
| `cmp` | dedup-files.sh |
| `smartctl` | disk-health.sh |
| `docker-compose` | docker-compose-manager.sh |
| `npm` | download-icons.sh |
| `dig` | dns-lookup.sh |
| `nslookup` | dns-lookup.sh |
| `jq` | ip-info.sh |
| `xelatex` | md-to-pdf.sh |
| `dbus-send` | media-control.sh |
| `fc-cache` | nerd-font-install.sh |
| `pdfinfo` | pdf-to-jpg.sh |
| `nc` | port-check.sh |
| `qrencode` | qr-gen.sh |
| `scrot` | screenshot.sh |
| `maim` | screenshot.sh |
| `gnome-screenshot` | screenshot.sh |
| `wmctrl` | setup-workspace.sh |
| `xdotool` | setup-workspace.sh |
| `snap` | snap-flatpak-manager.sh |
| `flatpak` | snap-flatpak-manager.sh |
| `speedtest-cli` | speedtest-log.sh |
| `ssh-keygen` | ssh-key-manager.sh |
| `ssh-copy-id` | ssh-key-manager.sh |
| `ssh` | ssh-tunnel-mgr.sh |
| `7z` | unarchive.sh |
| `unrar` | unarchive.sh |
| `ffprobe` | video-catalog-organizer.sh |
| `wpctl` | volume.sh |
| `pactl` | volume.sh |
| `amixer` | volume.sh |
| `whois` | whois.sh |
| `nmcli` | wifi-scanner.sh |
| `iwlist` | wifi-scanner.sh |
| `ssconvert` | xlsx-to-csv.sh |
| `yt-dlp` | yt-transcript.sh |
| `nvidia-smi` | nvidia-gpu-monitor.sh |
