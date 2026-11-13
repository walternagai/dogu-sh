# DevOps — referência

Categoria `devops` · 17 scripts · 8 com `--json` · 12 com `--dry-run`.

Git, cron, systemd, dotfiles, backups e diagnóstico de projeto.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## cron-manager.sh — Lista, adiciona e remove tarefas do crontab

- Risco: `destructive` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `crontab`
- Exemplo: `dogu cron-manager --add "0 3 * * * /path/backup.sh"`
- Flags: `--list (bool)` Lista tarefas · `--add (string)` Adiciona tarefa ·
  `--remove (string)` Remove por ID ou linha · `--force (bool)` Nao pede confirmacao

## dogu-make-skill.sh — Gera SKILL.md a partir de dogu.json para agentes de IA

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu dogu-make-skill --dry-run`
- Flags: `--output, -o (string)` Caminho de saida do SKILL.md ·
  `--verbose (bool)` Mostra detalhes durante a geracao

## dotfiles-manager.sh — Gerencia dotfiles com symlinks e repositorio local

- Risco: `destructive` · JSON: sim · Dry-run: sim · Interativo: não
- Exemplo: `dogu dotfiles-manager --add .bashrc`
- Flags: `--init (bool)` Cria repositorio e manifesto · `--add (string)` Adiciona arquivo ·
  `--remove (string)` Remove arquivo · `--list (bool)` Lista entradas ·
  `--status (bool)` Mostra status · `--apply (bool)` Recria symlinks ·
  `--repo (string)` Diretorio do repositorio · `--force (bool)` Sobrescreve arquivos

## env-manager.sh — Orquestrador de ambientes e dependencias multiplataforma

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu env-manager ~/meu-projeto`

## env-validator.sh — Valida variaveis de ambiente obrigatorias para o projeto

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu env-validator --json --strict`
- Flags: `--project, -p (string)` Caminho do projeto (padrao: diretorio atual) ·
  `--env-file, -e (string)` Arquivo .env para validar (padrao: .env) ·
  `--strict, -s (bool)` Falha se variaveis obrigatorias estiverem faltando

## folder-sync.sh — Sincroniza diretorios com rsync

- Risco: `destructive` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `rsync`
- Exemplo: `dogu folder-sync --dry-run ~/Documents /mnt/backup`
- Flags: `--all, -a (bool)` Executa sem confirmacao · `--mirror, -m (bool)` Espelha origem no destino ·
  `--watch (bool)` Monitora mudancas continuamente ·
  `--compress (bool)` Comprime durante transferencia

## git-pr-checklist.sh — Checklist automatico de qualidade e conformidade antes de abrir Pull Request

- Risco: `read-only` · JSON: sim · Dry-run: não · Interativo: não
- Dependências: `git`
- Exemplo: `dogu git-pr-checklist --json`
- Flags: `--project, -p (string)` Caminho do repositorio (padrao: diretorio atual) ·
  `--branch, -b (string)` Branch a verificar (padrao: branch atual) ·
  `--fix, -f (bool)` Tenta corrigir problemas automaticamente

## git-stale.sh — Lista branches antigas sem merge que podem ser limpas

- Risco: `destructive` · JSON: sim · Dry-run: sim · Interativo: sim
- Dependências: `git`
- Exemplo: `dogu git-stale --json --days 60`
- Flags: `--project, -p (string)` Caminho do repositorio (padrao: diretorio atual) ·
  `--days, -d (int)` Dias sem commit para considerar stale (padrao: 30) ·
  `--merged (bool)` Mostra apenas branches ja merged ·
  `--no-merged (bool)` Mostra apenas branches nao merged ·
  `--delete (bool)` Deleta branches stale (requer confirmacao) ·
  `--force (bool)` Deleta sem confirmacao

## git-sync.sh — Sincroniza multiplos repositorios git

- Risco: `destructive` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `git`
- Exemplo: `dogu git-sync ~/repos --push`
- Flags: `--push (bool)` Faz push apos pull · `--fetch (bool)` Apenas fetch, sem pull/push ·
  `--commit, -C (bool)` Oferece commit para repositorios modificados ·
  `--all, -a (bool)` Executa sem confirmacao (aceita a mensagem de commit sugerida) ·
  `--depth (int)` Profundidade maxima de busca

## install-scripts.sh — Instala scripts no ~/.local/bin e configura o PATH

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu install-scripts --dry-run`
- Flags: `--uninstall (bool)` Remove scripts e limpa PATH

## lab-manager.sh — Gerenciador unificado de ambiente de desenvolvimento

- Risco: `dry-run-ok` · JSON: sim · Dry-run: não · Interativo: não
- Exemplo: `dogu lab-manager install docker jupyter`
- Flags: `--safe (bool)` Uninstall seguro · `--force (bool)` Pular confirmacoes

## menu-launcher.sh — Menu interativo com barra luminosa para selecao de scripts

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: sim
- Dependências: `fzf`
- Exemplo: `dogu menu-launcher --fzf`
- Flags: `--fzf (bool)` Usa fzf para selecao rapida

## nerd-font-install.sh — Baixa e instala fontes Nerd Fonts

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `curl` + `unzip` + `fc-cache`
- Exemplo: `dogu nerd-font-install -f FiraCode`
- Flags: `--list (bool)` Lista familias de fontes disponiveis ·
  `--font, -f (string)` Instala fonte(s) especifica(s) · `--all (bool)` Instala todas as fontes ·
  `--install-dir, -o (string)` Diretorio de instalacao ·
  `--system (bool)` Instala em /usr/local/share/fonts

## package-list-backup.sh — Exporta/importa lista de pacotes instalados para replicar maquina

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Exemplo: `dogu package-list-backup --export ~/pkgs.txt --scope all`
- Flags: `--export (string)` Exporta lista de pacotes para arquivo ·
  `--import (string)` Instala pacotes a partir de arquivo ·
  `--diff (string)` Compara pacotes atuais com arquivo ·
  `--format (string)` Formato de saida: txt ou json ·
  `--scope (string)` Escopo: all, system, snap, flatpak, npm, pip, cargo, brew ·
  `--versions (bool)` Inclui versoes dos pacotes ·
  `--exclude (string)` Exclui pacotes que casam com o padrao ·
  `--include (string)` Inclui apenas pacotes que casam com o padrao

## quick-backup.sh — Backup incremental com rsync

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `rsync`
- Exemplo: `dogu quick-backup ~/Documents /mnt/backup --dry-run`
- Flags: `--all, -a (bool)` Executa sem confirmacao · `--compress (bool)` Comprime durante transferencia ·
  `--keep (int)` Manter N ultimos backups

## snap-flatpak-manager.sh — Lista, atualiza e limpa snaps e flatpaks

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `snap` + `flatpak`
- Exemplo: `dogu snap-flatpak-manager --list`
- Flags: `--list (bool)` Lista pacotes instalados · `--update (bool)` Atualiza pacotes ·
  `--clean (bool)` Remove runtimes nao utilizados · `--snap-only (bool)` Opera apenas no snap ·
  `--flatpak-only (bool)` Opera apenas no flatpak

## systemd-timer.sh — Gerencia timers systemd --user (adicionar, listar, remover)

- Risco: `destructive` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `systemctl`
- Exemplo: `dogu systemd-timer --add "*-*-* 03:00:00" --command /home/user/backup.sh`
- Flags: `--list (bool)` Lista timers · `--add (string)` Expressao OnCalendar ·
  `--command (string)` Comando executado pelo timer · `--remove (string)` Remove timer por ID ·
  `--force (bool)` Nao pede confirmacao
