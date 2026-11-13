# Sistema — referência

Categoria `system` · 25 scripts · 6 com `--json` · 13 com `--dry-run`.

Disco, memória, processos, energia, pacotes e arquivos locais.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## archive-manager.sh — Compacta pastas individualmente ou descompacta arquivos em massa

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `zip` + `unzip` + `tar`
- Exemplo: `dogu archive-manager --pack ~/projetos`
- Flags: `--pack (bool)` Compacta cada subdiretorio em um arquivo .zip individual ·
  `--unpack (bool)` Descompacta cada arquivo compactado em sua propria pasta

## batch-rename.sh — Renomeia arquivos em lote por padrao de busca/substituicao

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `sed` + `mv`
- Exemplo: `dogu batch-rename --find=foto --replace=photo *.jpg`
- Flags: `--find (string)` Texto a procurar no nome · `--replace (string)` Substituicao do padrao ·
  `--prefix (string)` Adiciona texto no inicio do nome ·
  `--suffix (string)` Adiciona texto antes da extensao · `--ext (string)` Troca a extensao ·
  `--lower (bool)` Converte nome para minusculas · `--upper (bool)` Converte nome para maiusculas ·
  `--seq (bool)` Adiciona numeracao sequencial · `--force (bool)` Nao pedir confirmacao

## battery-monitor.sh — Status da bateria com alerta de nivel baixo/critico

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu battery-monitor --watch`
- Flags: `--status, -s (bool)` Mostra status atual · `--watch, -w (bool)` Monitora continuamente com alertas ·
  `--low (int)` Percentual de alerta baixo · `--critical (int)` Percentual de alerta critico

## brightness.sh — Controle de brilho do monitor

- Risco: `read-only` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `light`ou `brightnessctl`ou `xrandr`
- Exemplo: `dogu brightness --up 10`
- Flags: `--up, -u (int)` Aumenta brilho em N% · `--down, -d (int)` Diminui brilho em N% ·
  `--set, -s (int)` Define brilho para N% · `--get (bool)` Mostra brilho atual

## clean-cache.sh — Limpa arquivos temporarios e caches de aplicacoes

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu clean-cache --json`
- Flags: `--all, -a (bool)` Limpa todos os caches sem confirmacao

## clean-system.sh — Limpeza profunda do sistema (complemento ao clean-cache)

- Risco: `destructive` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `bc`
- Exemplo: `dogu clean-system --json`
- Flags: `--all, -a (bool)` Executa tudo sem confirmacao

## dark-mode.sh — Alterna tema claro/escuro em GTK e terminais

- Risco: `read-only` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu dark-mode --toggle`
- Flags: `--dark, -d (bool)` Ativa tema escuro · `--light, -l (bool)` Ativa tema claro ·
  `--toggle, -t (bool)` Alterna entre claro/escuro · `--status, -s (bool)` Mostra tema atual

## dedup-files.sh — Compara varios arquivos e remove duplicados

- Risco: `destructive` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `find` + `sha256sum` + `cmp`
- Exemplo: `dogu dedup-files --delete ~/Documents`
- Flags: `--delete (bool)` Remove duplicados ·
  `--keep (string)` Estrategia de selecao: first, oldest, newest, largestpath ·
  `--min-size (int)` Tamanho minimo em bytes · `--exclude-dir (string)` Diretorios extras a ignorar ·
  `--include-hidden (bool)` Incluir arquivos ocultos

## dependency-checker.sh — Verifica dependencias externas do projeto dogu-sh

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu dependency-checker`
- Flags: `--fix, -f (bool)` Tenta instalar dependencias faltantes ·
  `--all, -a (bool)` Inclui dependencias escaneadas dos scripts

## dir-summary.sh — Resumo de diretorio: conta arquivos, tipos e tamanho

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu dir-summary ~/Documents --top 5`
- Flags: `--all, -a (bool)` Inclui arquivos ocultos · `--sort, -s (string)` Ordena por: size, count, name ·
  `--top, -t (int)` Mostra apenas os N maiores tipos · `--deep, -d (int)` Mostra os N maiores arquivos ·
  `--depth, -D (int)` Profundidade de subdiretorios · `--age, -A (bool)` Mostra distribuicao por idade

## disk-health.sh — Verifica saude SMART do disco e alerta problemas

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `smartctl`
- Exemplo: `dogu disk-health --json`
- Flags: `--all, -a (bool)` Mostra todos os atributos SMART ·
  `--watch, -w (int)` Re-verificar a cada N segundos ·
  `--notify (bool)` Notificacao desktop em problemas criticos

## disk-scanner.sh — Identifica os maiores arquivos e pastas no disco

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu disk-scanner /var 10`

## disk-space.sh — Mostra espaco disponivel nos discos com identificacao de tipo (SSD/NVMe/HDD)

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `lsblk`
- Exemplo: `dogu disk-space --json`
- Flags: `--all, -a (bool)` Inclui pseudo-filesystems e loop devices

## file-watcher.sh — Observa arquivos e reporta criacoes, alteracoes e remocoes

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `python3`
- Exemplo: `dogu file-watcher -p ./src -g "*.py" --json`
- Flags: `--path, -p (string)` Diretorio a observar · `--glob, -g (string)` Filtro de nome ·
  `--interval, -i (int)` Intervalo em segundos · `--once (bool)` Snapshot unico

## fix-exec-bit.sh — Remove bit de execucao de arquivos de dados (util apos copiar de NTFS/exFAT)

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu fix-exec-bit --dry-run ~/Downloads`
- Flags: `--ext (string)` Substitui a lista de extensoes seguras ·
  `--add-ext (string)` Adiciona extensoes a lista padrao ·
  `--list-ext (bool)` Imprime a lista padrao e sai · `--include-hidden (bool)` Inclui arquivos ocultos ·
  `--exclude-dir (string)` Diretorios extras para ignorar ·
  `--max-depth (int)` Limitar profundidade da busca · `--quiet (bool)` Modo silencioso ·
  `--force (bool)` Nao pedir confirmacao

## hunt-duplicates.sh — Encontra arquivos duplicados por hash SHA-256

- Risco: `destructive` · JSON: não · Dry-run: sim · Interativo: sim
- Dependências: `sha256sum`
- Exemplo: `dogu hunt-duplicates --dry-run ~/Documents`
- Flags: `--trash (bool)` Move duplicatas para lixeira · `--delete (bool)` Deleta duplicatas permanentemente ·
  `--soft-link (bool)` Substitui duplicatas por symlink ·
  `--mode (string)` Estrategia de selecao: oldest, newest, smallest-path, first ·
  `--interactive (bool)` Modo interativo · `--output (string)` Exporta resultados em JSON ou CSV ·
  `--ext (string)` Filtrar por extensoes · `--type (string)` Filtrar por tipo MIME ·
  `--max-depth (int)` Limitar profundidade da busca ·
  `--exclude-dir (string)` Diretorios extras para ignorar ·
  `--include-hidden (bool)` Incluir arquivos ocultos ·
  `--threshold (int)` Exibir apenas grupos com N ou mais duplicatas · `--quiet (bool)` Modo silencioso ·
  `--force (bool)` Nao pedir confirmacao · `--use-cache (bool)` Usar cache de hashes

## log-analyzer.sh — Analisador de logs com coloracao e filtros

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `grep`
- Exemplo: `dogu log-analyzer /var/log/syslog --stats`
- Flags: `--follow, -f (bool)` Acompanha o log em tempo real · `--lines, -n (int)` Numero de linhas a exibir ·
  `--stats, -s (bool)` Exibe estatisticas por nivel

## nvidia-gpu-monitor.sh — Monitora atividade da GPU NVIDIA em segundo plano

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `nvidia-smi`
- Exemplo: `dogu nvidia-gpu-monitor --once`
- Flags: `--interval (int)` Intervalo de amostragem em segundos ·
  `--output (string)` Caminho do arquivo de log · `--temp (int)` Limiar de alerta de temperatura ·
  `--retention (int)` Retencao do log em dias · `--once (bool)` Coleta uma vez e sai ·
  `--notify (bool)` Notificacao de desktop em alertas

## organize-downloads.sh — Organiza arquivos por tipo de extensao

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu organize-downloads --dry-run ~/Downloads`
- Flags: `--recursive, -r (bool)` Processa subpastas tambem

## partitions-list.sh — Lista todas as particoes (montadas ou nao) com tipo de disco

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `lsblk`
- Exemplo: `dogu partitions-list --json`
- Flags: `--all, -a (bool)` Inclui loop devices, zram, crypt e swap · `--uuid, -u (bool)` Mostra coluna UUID ·
  `--label, -l (bool)` Mostra coluna LABEL

## process-killer.sh — Seletor interativo de processos para termino

- Risco: `destructive` · JSON: não · Dry-run: não · Interativo: sim
- Dependências: `fzf`
- Exemplo: `dogu process-killer`
- Flags: `--signal, -s (string)` Sinal a enviar · `--user, -u (string)` Filtra processos por usuario

## setup-workspace.sh — Multi-monitor workspace manager para Linux

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: sim
- Dependências: `wmctrl` + `xdotool` + `xrandr`
- Exemplo: `dogu setup-workspace --detect`
- Flags: `--save (string)` Grava o layout atual como perfil · `--detect (bool)` Mostra monitores conectados ·
  `--init (bool)` Cria config editavel · `--list (bool)` Lista perfis salvos

## unarchive.sh — Descompacta arquivos compactados (zip, rar, 7z, tar, etc.)

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `unzip` + `7z` + `tar` + `unrar`
- Exemplo: `dogu unarchive --dry-run arquivo.zip`
- Flags: `--output, -o (string)` Diretorio base de saida ·
  `--recursive, -r (bool)` Varre diretorios recursivamente ·
  `--force, -f (bool)` Sobrescreve arquivos existentes · `--flat, -F (bool)` Extrai direto no destino

## update-all.sh — Atualiza pacotes do sistema e linguagens em um comando

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu update-all --all --dry-run`
- Flags: `--system, -s (bool)` Atualiza pacotes do sistema · `--npm (bool)` Atualiza pacotes globais npm ·
  `--pip (bool)` Atualiza pacotes pip globais · `--cargo (bool)` Atualiza pacotes cargo ·
  `--brew (bool)` Atualiza Homebrew · `--all (bool)` Atualiza tudo

## volume.sh — Controle de volume e mute via PulseAudio/PipeWire

- Risco: `read-only` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `wpctl` + `pactl` + `amixer` + `bc`
- Exemplo: `dogu volume --up 10`
- Flags: `--up, -u (int)` Aumenta volume em N% · `--down, -d (int)` Diminui volume em N% ·
  `--set, -s (int)` Define volume para N% · `--mute (bool)` Alterna mute ·
  `--get (bool)` Mostra volume atual · `--source (bool)` Opera no microfone ·
  `--list (bool)` Lista dispositivos de audio
