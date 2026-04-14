# my_util_scripts

Uma coleção de scripts utilitários em Bash para automação, manutenção do sistema e gerenciamento de Docker em ambiente Linux.

## 🚀 Funcionalidades

### 📦 Instalação e Execução
- `install-scripts.sh`: Instala todos os scripts em `~/.local/bin` e configura o PATH automaticamente.
- `menu-launcher.sh`: Menu interativo (com suporte a `fzf`) para executar qualquer script do repositório.
- `env-manager.sh`: Orquestrador de ambientes que detecta e instala dependências de projetos (npm, pip, cargo, maven, gradle, composer, bundler, brew, apt).
- `dependency-helper.sh`: Biblioteca compartilhada de verificação e auto-instalação de dependências usada por todos os scripts.

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

### Instalação rápida (recomendado)

```bash
git clone <url-do-repo>
cd my_util_scripts
chmod +x install-scripts.sh
./install-scripts.sh
```

Isso copia todos os scripts para `~/.local/bin`, configura o PATH no seu shell (`~/.bashrc`, `~/.zshrc` ou `config.fish`) e garante permissões de execução. Reinicie o terminal ou execute `source ~/.bashrc` (ou equivalente).

### Instalação com preview

```bash
./install-scripts.sh --dry-run
```

### Execução manual

```bash
chmod +x *.sh
./nome-do-script.sh --help
```

### Menu interativo

```bash
./menu-launcher.sh
```

Se `fzf` estiver instalado, o menu usa busca interativa; caso contrário, usa menu numérico.

### Setup de ambiente de projeto

```bash
cd /meu/projeto
env-manager.sh
```

O `env-manager` detecta automaticamente manifestos como `package.json`, `requirements.txt`, `Cargo.toml`, `pom.xml`, `build.gradle`, `composer.json`, `Gemfile`, `Brewfile` e arquivos de pacotes apt, e oferece instalação seletiva.

## 🔧 Auto-instalação de Dependências

Todos os scripts que dependem de softwares externos (Docker, rsync, smartctl, etc.) verificam automaticamente se as dependências estão instaladas. Se uma dependência estiver ausente, o script:

1. Informa o usuário qual pacote está faltando.
2. Pergunta se deseja instalar automaticamente.
3. Detecta o gerenciador de pacotes do sistema (apt, pacman, dnf, brew).
4. Instala a dependência com privilégios de `sudo` quando necessário.

**Dependências por script:**

| Script | Dependências |
|--------|-------------|
| `docker-*.sh` | `docker` (e `docker-compose` para compose-manager) |
| `disk-health.sh` | `smartmontools` (smartctl) |
| `folder-sync.sh`, `quick-backup.sh` | `rsync` |
| `setup-workspace.sh` | `wmctrl`, `xdotool`, `xrandr` |
| `speedtest-log.sh` | `speedtest-cli` |
| `wifi-scanner.sh` | `nmcli` (NetworkManager) / `iwlist` (wireless-tools) |
| `git-sync.sh` | `git` |

## 📝 Notas
- A maioria dos scripts suporta a flag `--dry-run` para visualização das alterações antes de aplicá-las.
- Execute qualquer script com `--help` para ver todas as opções disponíveis.