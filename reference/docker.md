# Docker — referência

Categoria `docker` · 18 scripts · 12 com `--json` · 8 com `--dry-run`.

Containers, imagens, volumes, redes, backups e CIS benchmark.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## docker-audit.sh — Auditoria de seguranca de containers Docker

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-audit --json`
- Flags: `--verbose (bool)` Mostra detalhes de cada verificacao

## docker-backup.sh — Backup de volumes e configuracoes de containers

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-backup --all --compress`
- Flags: `--all (bool)` Backup de todos os volumes · `--volume (string)` Backup de volume especifico ·
  `--container (string)` Backup de config do container · `--output (string)` Diretorio de saida ·
  `--compress (bool)` Comprimir com gzip · `--keep (int)` Manter N ultimos backups

## docker-bottleneck-detect.sh — Detecta gargalos comparando limites config vs uso real

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-bottleneck-detect --json`
- Flags: `--all, -a (bool)` Analisa todos os containers rodando ·
  `--container, -c (string)` Analisa container especifico ·
  `--threshold (int)` Percentual de uso para alerta · `--waste (int)` Percentual para desperdicio ·
  `--watch (int)` Atualiza a cada N segundos

## docker-cis-benchmark.sh — Verifica conformidade com CIS Docker Benchmark

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-cis-benchmark --json`
- Flags: `--all, -a (bool)` Verifica todos os containers ·
  `--container, -c (string)` Verifica container especifico ·
  `--host (bool)` Verifica apenas configuracoes do host ·
  `--severity (string)` Filtra por severidade: info, warn, fail

## docker-clean.sh — Limpa recursos nao utilizados do Docker

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-clean --dry-run`
- Flags: `--all (bool)` Remove tudo · `--deep (bool)` Limpeza profunda

## docker-compose-manager.sh — Gerencia multiplos docker-compose.yml

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `docker` · opcional: `docker-compose`
- Exemplo: `dogu docker-compose-manager --status`
- Flags: `--status, -s (bool)` Lista compose files e seus status ·
  `--up, -u (bool)` Inicia todos os compose encontrados ·
  `--down, -d (bool)` Para todos os compose encontrados ·
  `--restart (bool)` Restart de todos os compose · `--pull (bool)` Pull + recreate de todos ·
  `--depth (int)` Profundidade de busca

## docker-dependency-map.sh — Mapeia relacoes de dependencia entre containers

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-dependency-map --tree`
- Flags: `--map, -m (bool)` Mapeia todas as dependencias · `--network, -n (string)` Filtra por rede ·
  `--container, -c (string)` Filtra por container ·
  `--tree (bool)` Exibe dependencias em formato arvore · `--dot (bool)` Gera saida Graphviz DOT

## docker-doctor.sh — Diagnostico agregado de Docker (status, saude e auditoria)

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker` + `jq`
- Exemplo: `dogu docker-doctor --full`
- Flags: `--full (bool)` Inclui CIS Benchmark e gargalos

## docker-healthcheck.sh — Verifica saude dos containers e reinicia unhealthy

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-healthcheck --json`
- Flags: `--restart, -r (bool)` Reinicia containers unhealthy automaticamente ·
  `--notify, -n (bool)` Notificacoes desktop em problemas ·
  `--watch, -w (int)` Verifica a cada N segundos

## docker-image-slimmer.sh — Analisa camadas de imagens e sugere reducoes

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-image-slimmer --image nginx`
- Flags: `--image, -i (string)` Analisa uma imagem especifica ·
  `--all, -a (bool)` Analisa todas as imagens locais ·
  `--history, -H (bool)` Mostra historico detalhado de camadas ·
  `--tips, -t (bool)` Apenas dicas gerais

## docker-logs-watcher.sh — Monitora logs de containers com filtros

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-logs-watcher --error --since 1h`
- Flags: `--container, -c (string)` Container para monitorar ·
  `--filter, -f (string)` Filtra linhas contendo TEXTO · `--error (bool)` Filtra apenas erros ·
  `--since (string)` Logs a partir de (ex: 5m, 1h) ·
  `--notify (bool)` Envia notificacao desktop ao detectar erro

## docker-network-manager.sh — Gerencia redes Docker (criar, remover, conectar, desconectar)

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-network-manager --list`
- Flags: `--list (bool)` Lista todas as redes · `--create (string)` Cria uma rede bridge ·
  `--remove (string)` Remove uma rede · `--connect (string)` Conecta container a rede ·
  `--disconnect (string)` Desconecta container de rede ·
  `--inspect (string)` Inspeciona detalhes de uma rede · `--prune (bool)` Remove redes nao utilizadas

## docker-resource-alert.sh — Alerta quando container ultrapassa limites de CPU/RAM

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-resource-alert --json --cpu 80 --notify`
- Flags: `--cpu (int)` Limite de CPU em % · `--mem (int)` Limite de RAM em % ·
  `--disk (int)` Limite de disco em bytes · `--watch (int)` Verifica a cada N segundos ·
  `--notify (bool)` Notificacoes desktop · `--kill (bool)` Mata container que ultrapassar CPU

## docker-restore.sh — Restaura volumes e configuracoes de containers

- Risco: `destructive` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-restore --input ~/docker-backups/latest --all`
- Flags: `--input, -i (string)` Diretorio de backup · `--volume, -V (string)` Restaura volume especifico ·
  `--all (bool)` Restaura todos os volumes do backup

## docker-secret-scanner.sh — Escaneia containers em busca de segredos expostos

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-secret-scanner --json`
- Flags: `--all (bool)` Escaneia todos os containers rodando ·
  `--container (string)` Escaneia container especifico ·
  `--env-only (bool)` Escaneia apenas variaveis de ambiente ·
  `--labels-only (bool)` Escaneia apenas labels · `--severity (string)` Filtra por severidade

## docker-stats-history.sh — Registra historico de CPU/RAM dos containers em CSV

- Risco: `read-only` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-stats-history --watch 30`
- Flags: `--output, -o (string)` Arquivo CSV destino · `--watch, -w (int)` Intervalo em segundos ·
  `--container, -c (string)` Filtrar por nome do container ·
  `--no-header (bool)` Nao escrever header CSV

## docker-status.sh — Painel resumido do Docker

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-status --json`
- Flags: `--watch, -w (int)` Atualiza a cada N segundos · `--containers, -c (bool)` Mostra apenas containers ·
  `--images, -i (bool)` Mostra apenas imagens · `--volumes, -v (bool)` Mostra apenas volumes

## docker-volume-mgr.sh — Lista, identifica orfaos, faz backup e restaura volumes Docker

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `docker`
- Exemplo: `dogu docker-volume-mgr --orphans`
- Flags: `--list (bool)` Lista todos os volumes · `--orphans (bool)` Mostra volumes sem container associado ·
  `--size (bool)` Mostra tamanho de cada volume · `--remove (string)` Remove um volume especifico ·
  `--remove-orphans (bool)` Remove todos os volumes orfaos ·
  `--backup (string)` Faz backup de um volume ·
  `--restore (string)` Restaura volume a partir de tar.gz
