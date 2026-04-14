# my_util_scripts

Uma coleção de scripts utilitários em Bash para automação, manutenção do sistema e gerenciamento de Docker em ambiente Linux.

## 🚀 Funcionalidades

### 🐳 Docker Management
- `docker-status.sh`: Painel resumido do estado do Docker.
- `docker-clean.sh`: Limpeza de recursos não utilizados.
- `docker-backup.sh` & `docker-restore.sh`: Backup e restauração de volumes e configurações.
- `docker-healthcheck.sh`: Verificação de saúde e reinicialização de containers.
- `docker-logs-watcher.sh`: Monitoramento de logs com filtros.
- `docker-resource-alert.sh`: Alertas de consumo de CPU/RAM.
- `docker-audit.sh`: Auditoria de segurança de containers.
- `docker-compose-manager.sh`: Gestão de múltiplos arquivos docker-compose.

### 🛠️ Sistema e Manutenção
- `clean-cache.sh`: Limpeza de arquivos temporários e caches de apps.
- `clean-system.sh`: Limpeza profunda do sistema baseada na distro.
- `disk-health.sh`: Monitoramento de saúde SMART do disco.
- `disk-scanner.sh`: Identificação de arquivos e pastas volumosas.
- `hunt-duplicates.sh`: Busca de arquivos duplicados via SHA-256.
- `organize-downloads.sh`: Organização automática de arquivos por extensão.

### 📂 Sincronização e Backup
- `quick-backup.sh`: Backup incremental via rsync.
- `folder-sync.sh`: Sincronização de diretórios.
- `git-sync.sh`: Sincronização em massa de múltiplos repositórios Git.

### ⚙️ Produtividade e Utilidades
- `setup-workspace.sh`: Gerenciador de layouts de multi-monitores.
- `pomodor.sh`: Timer Pomodoro com notificações.
- `speedtest-log.sh`: Histórico de testes de velocidade de internet em CSV.
- `wifi-scanner.sh`: Escaneamento de redes Wi-Fi e sugestão de canais.

## 🛠️ Instalação e Uso

1. Clone o repositório:
   ```bash
   git clone <url-do-repo>
   cd my_util_scripts
   ```

2. Dê permissão de execução aos scripts:
   ```bash
   chmod +x *.sh
   ```

3. Execute qualquer script:
   ```bash
   ./nome-do-script.sh --help
   ```

## 📝 Notas
- A maioria dos scripts suporta a flag `--dry-run` para visualização das alterações antes de aplicá-las.
- Dependências comuns: `rsync`, `nmcli`, `wmctrl`, `xdotool`, `xrandr`, `docker`.
