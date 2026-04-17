# dōgu-sh · 道具

> **dōgu** (道具) — *substantivo japonês*: ferramenta, instrumento, utensílio.

Uma coleção de ferramentas precisas para artesãos do terminal. Não é um sistema, não é uma plataforma — é o seu kit de ferramentas Bash para automação, manutenção e Docker em Linux.

## 🚀 Funcionalidades

### 📦 Instalação e Execução
- `install-scripts.sh`: Instala todos os scripts em `~/.local/bin` e configura o PATH automaticamente.
- `menu-launcher.sh`: Menu interativo (com suporte a `fzf`) para executar qualquer ferramenta do kit.
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
- `docker-image-slimmer.sh`: Análise de camadas de imagens e sugestões de otimização.
- `docker-network-manager.sh`: Criação, remoção, conexão e inspeção de redes Docker.
- `docker-volume-mgr.sh`: Listagem, identificação de órfãos, backup e restauração de volumes.
- `docker-stats-history.sh`: Registro histórico de CPU/RAM dos containers em CSV.
- `docker-dependency-map.sh`: Mapeamento de dependências entre containers (redes, volumes, depends_on).
- `docker-cis-benchmark.sh`: Verificação de conformidade com CIS Docker Benchmark.
- `docker-secret-scanner.sh`: Detecção de segredos expostos em variáveis de ambiente e labels.
- `docker-bottleneck-detect.sh`: Detecção de gargalos e desperdício de recursos comparando limites vs uso real.

### 🛡️ Segurança
- `ssh-key-manager.sh`: Geração, listagem, rotação e distribuição de chaves SSH entre hosts.

### 🛠️ Sistema e Manutenção
- `clean-cache.sh`: Limpeza de arquivos temporários e caches de apps.
- `clean-system.sh`: Limpeza profunda do sistema baseada na distro.
- `disk-health.sh`: Monitoramento de saúde SMART do disco.
- `disk-scanner.sh`: Identificação de arquivos e pastas volumosas.
- `disk-space.sh`: Espaço disponível nos discos com identificação de tipo (SSD/NVMe/HDD).
- `hunt-duplicates.sh`: Busca de arquivos duplicados via SHA-256.
- `organize-downloads.sh`: Organização automática de arquivos por extensão.

### 📦 Pacotes e Atualizações
- `update-all.sh`: Atualiza pacotes do sistema + linguagens (npm, pip, cargo, brew) em um comando.
- `package-list-backup.sh`: Exporta/importa lista de pacotes instalados para replicar máquina.
- `snap-flatpak-manager.sh`: Lista, atualiza e limpa snaps e flatpaks.

### 📂 Sincronização e Backup
- `quick-backup.sh`: Backup incremental via rsync.
- `folder-sync.sh`: Sincronização de diretórios.
- `git-sync.sh`: Sincronização em massa de múltiplos repositórios Git, com commit via Ollama e resolução interativa de conflitos.

### ⚙️ Produtividade e Utilidades
- `setup-workspace.sh`: Gerenciador de layouts de multi-monitores.
- `pomodor.sh`: Timer Pomodoro com notificações.
- `speedtest-log.sh`: Histórico de testes de velocidade de internet em CSV.
- `wifi-scanner.sh`: Escaneamento de redes Wi-Fi e sugestão de canais.
- `clipboard-manager.sh`: Histórico do clipboard com busca e persistência.

### 🔢 Calculadoras e Conversores
- `calculator.sh`: Calculadora interativa com histórico e suporte a expressões (bc).
- `unit-converter.sh`: Conversão entre unidades (temperatura, comprimento, peso, volume, velocidade, área, tempo).
- `currency-converter.sh`: Cotação de moedas em tempo real via API.
- `subnet-calc.sh`: Calculadora de sub-redes IPv4/CIDR.
- `color-converter.sh`: Conversão entre HEX, RGB, HSL e nome de cor com preview.

### 🕐 Tempo e Relógio
- `weather.sh`: Previsão do tempo via wttr.in com localização automática.
- `world-clock.sh`: Relógio com múltiplos fusos horários configuráveis.
- `alarm.sh`: Alarme/cronômetro com notificações no tempo alvo.
- `stopwatch.sh`: Cronômetro com voltas (laps).
- `calendar.sh`: Calendário mensal com marcação de eventos.

### 📝 Produtividade e Notas
- `todo.sh`: Lista de tarefas com prioridades, categorias e persistência.
- `quick-notes.sh`: Bloco de notas rápido com busca e tags.
- `password-gen.sh`: Gerador de senhas configurável (tamanho, chars, quantidade, passphrase).
- `qr-gen.sh`: Gera QR Code no terminal ou salva como PNG.
- `base64-tool.sh`: Codifica/decodifica Base64, URL encode, hex.
- `env-keygen.sh`: Gera chaves secretas seguras para arquivos .env (hex, base64, uuid, django, fernet, rails, alnum, ascii, numeric, password).
- `docx-to-md.sh`: Converte arquivos `.docx` para Markdown (`.md`) via pandoc — suporte a lote e modo recursivo.
- `pdf-to-md.sh`: Converte arquivos `.pdf` para Markdown (`.md`) extraindo texto via `pdftotext`, com OCR opcional para PDFs escaneados.
- `xlsx-to-csv.sh`: Converte arquivos `.xlsx` para CSV via openpyxl — cada aba vira um `.csv` separado.

### 🖥️ Sistema e Monitoramento
- `battery-monitor.sh`: Status da bateria, alerta de nível baixo/crítico.
- `nvidia-gpu-monitor.sh`: Monitoramento de atividade e temperatura de GPUs NVIDIA.
- `brightness.sh`: Controle de brilho do monitor (up/down/set).
- `screenshot.sh`: Captura de tela (full, area, window) com salvamento automático.
- `volume.sh`: Controle de volume e mute via PulseAudio/PipeWire.
- `media-control.sh`: Controla players MPRIS (play/pause/next/prev) + now playing.
- `dark-mode.sh`: Alterna tema claro/escuro em GTK e terminais.

### 🌐 Rede e Lookup
- `ip-info.sh`: Info do IP público, ISP, localização geográfica.
- `dns-lookup.sh`: Lookup DNS (A, AAAA, MX, NS, TXT, CNAME).
- `port-check.sh`: Verifica se portas estão abertas em um host.
- `whois.sh`: Consulta WHOIS de domínios.

## 🛠️ Instalação e Uso

### Instalação rápida (recomendado)

```bash
git clone https://github.com/walternagai/dogu-sh.git
cd dogu-sh
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
| `disk-space.sh` | `lsblk` (util-linux, presente por padrão) |
| `folder-sync.sh`, `quick-backup.sh` | `rsync` |
| `setup-workspace.sh` | `wmctrl`, `xdotool`, `xrandr` |
| `speedtest-log.sh` | `speedtest-cli` |
| `wifi-scanner.sh` | `nmcli` (NetworkManager) / `iwlist` (wireless-tools) |
| `git-sync.sh` | `git`, `ollama` (opcional, para commits com IA) |
| `ssh-key-manager.sh` | `ssh-keygen`, `ssh-copy-id` |
| `clipboard-manager.sh` | `xclip` (X11) / `wl-clipboard` (Wayland) |
| `package-list-backup.sh` | gerenciador de pacotes da distro |
| `calculator.sh` | `bc` |
| `currency-converter.sh` | `curl`, `jq` |
| `qr-gen.sh` | `qrencode` |
| `screenshot.sh` | `scrot` ou `maim` (+ `slop` para área) |
| `media-control.sh` | `playerctl` |
| `whois.sh` | `whois` |
| `dns-lookup.sh` | `dig` (dnsutils/bind-utils) ou `nslookup` |
| `ip-info.sh` | `curl` |
| `docx-to-md.sh` | `pandoc` |
| `pdf-to-md.sh` | `pdftotext` (`poppler-utils`/`poppler`), `tesseract` (opcional para `--ocr`) |
| `xlsx-to-csv.sh` | `python3`, `openpyxl` (pip) |

## 📝 Notas
- A maioria dos scripts suporta a flag `--dry-run` para visualização das alterações antes de aplicá-las.
- Execute qualquer script com `--help` para ver todas as opções disponíveis.

## 📖 git-sync.sh — Detalhes

Sincroniza múltiplos repositórios Git com suporte a commit com IA e resolução interativa de conflitos.

### Uso

```bash
./git-sync.sh [opcoes] [diretorio-base]
```

### Opções

| Flag | Descrição |
|------|-----------|
| `--dry-run` | Preview sem fazer fetch/pull/push |
| `--push` / `-p` | Faz push após pull (apenas se sem conflito) |
| `--fetch` / `-f` | Apenas fetch, sem pull/push |
| `--commit` / `-C` | Oferece commit para repos modificados |
| `--all` / `-a` | Executa sem confirmação |
| `--depth N` | Profundidade máxima de busca (padrão: 5) |

### Commits com IA (Ollama)

Quando `--commit` está ativo e o [Ollama](https://ollama.com) está instalado e em execução:

1. O script gera mensagens de commit automaticamente usando o formato **Conventional Commits** (`feat:`, `fix:`, `docs:`, etc.).
2. O diff do repositório é enviado ao modelo, que sugere uma mensagem.
3. O usuário pode **aceitar (S)**, **recusar (n)** e digitar manualmente, ou **editar (e)** a mensagem sugerida.
4. Se o Ollama não estiver disponível, o script exibe as tags disponíveis e pede a mensagem manualmente.

A variável de ambiente `OLLAMA_DEFAULT_MODEL` define o modelo padrão. Se não estiver definida, o script lista os modelos disponíveis e pergunta qual usar.

```bash
export OLLAMA_DEFAULT_MODEL=llama3
./git-sync.sh --commit --all ~/Projects
```

### Resolução de Conflitos

O script oferece resolução interativa em três cenários:

#### 1. Repositório divergido (ahead + behind)

Quando um repositório tem commits locais e remotos divergentes, o menu oferece:

| Opção | Ação |
|-------|------|
| **1 — Rebase** | `git pull --rebase` — reaplica commits locais sobre o remoto |
| **2 — Merge** | `git pull --no-rebase` — cria merge commit |
| **3 — Reset** | `git reset --hard @{upstream}` — descarta commits locais (com confirmação) |
| **0 — Pular** | Ignora o repositório e continua |

No modo `--all`, tenta rebase automático. Se houver conflitos de arquivo, orienta a usar modo interativo.

#### 2. Conflitos de merge/rebase (arquivos)

Se houver conflitos em arquivos durante merge ou rebase:

| Opção | Ação |
|-------|------|
| **1 — Ours** | Aceita a versão local de todos os arquivos |
| **2 — Theirs** | Aceita a versão remota de todos os arquivos |
| **3 — Editor** | Abre `$EDITOR` (ou `nano`) para editar cada arquivo |
| **4 — Por arquivo** | Escolhe ours/theirs/editor/pular para cada arquivo individualmente |
| **0 — Abortar** | Cancela a operação (`rebase --abort` / `merge --abort`) |

#### 3. Push rejeitado

Quando `git push` é rejeitado (remoto tem novos commits), o script:

1. Tenta `git pull --rebase` automaticamente.
2. Se houver conflitos, abre o menu de resolução de conflitos de arquivo.
3. Após resolução, tenta `git push` novamente.

### Exemplos

```bash
# Preview do estado dos repos
./git-sync.sh --dry-run ~/Projects

# Sincronizar tudo automaticamente com push
./git-sync.sh --push --all ~/Projects

# Commits com IA em repos modificados
./git-sync.sh --commit ~/Projects

# Commit automático + push + sincronização
./git-sync.sh --commit --push --all ~/Projects

# Apenas fetch
./git-sync.sh --fetch ~/Projects
```

## 🙏 Agradecimentos

Agradecimento especial a **Victor Kav** pelo repositório [5-scripts](https://github.com/viktorkav/5-scripts), que serviu de inspiração para criar e melhorar vários scripts deste projeto, direcionando-os para uso exclusivo em Linux.

Os scripts abaixo foram originalmente inspirados em `5-scripts` e depois reescritos e aprimorados:

| Script original (5-scripts) | Script reescrito | O que faz |
|---|---|---|
| `organizar-downloads` | `organize-downloads.sh` | Organiza arquivos soltos em subpastas por tipo (Imagens, Documentos, Vídeos, Áudio, etc.) |
| `scanner-espaco` | `disk-scanner.sh` | Mostra os maiores arquivos e pastas do disco com resumo de uso |
| `cacar-duplicatas` | `hunt-duplicates.sh` | Encontra arquivos duplicados por hash SHA-256 sem deletar nada |
| `scanner-wifi` | `wifi-scanner.sh` | Escaneia redes Wi-Fi próximas e recomenda o melhor canal |
| `setup-workspace` | `setup-workspace.sh` | Posiciona janelas em múltiplos monitores com perfis salvos |
