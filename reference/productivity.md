# Produtividade — referência

Categoria `productivity` · 13 scripts · 0 com `--json` · 1 com `--dry-run`.

Notas, TODOs, alarmes, calendário, timers e clipboard.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## alarm.sh — Alarme e cronometro com notificacoes

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu alarm -t 14:30 -m 'Reuniao'`
- Flags: `--time, -t (string)` Hora do alarme (HH:MM) ou duracao (Nm, Nh, Ns) ·
  `--message, -m (string)` Mensagem do alarme · `--list, -l (bool)` Lista alarmes ativos ·
  `--cancel (int)` Cancela alarme N

## calculator.sh — Calculadora interativa com historico e suporte a expressoes

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: sim
- Dependências: `bc`
- Exemplo: `dogu calculator -e '2+2'`
- Flags: `--eval, -e (string)` Avalia expressao e sai · `--history (bool)` Mostra historico de calculos ·
  `--clear, -c (bool)` Limpa historico

## calendar.sh — Calendario mensal com marcacao de eventos

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu calendar -m 9 -y 2026`
- Flags: `--month, -m (int)` Mes (1-12) · `--year, -y (int)` Ano ·
  `--add, -a (string)` Adiciona evento (YYYY-MM-DD MSG) · `--remove, -r (int)` Remove evento por ID ·
  `--events (bool)` Lista eventos do mes

## clipboard-manager.sh — Historico do clipboard com busca e persistencia

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `wl-copy` + `xclip`
- Exemplo: `dogu clipboard-manager --list`
- Flags: `--watch (bool)` Monitora clipboard e salva historico · `--list (bool)` Lista historico salvo ·
  `--search (string)` Busca no historico por termo · `--restore (int)` Restaura item N do historico ·
  `--clear (bool)` Limpa historico salvo · `--count (int)` Numero de itens a listar

## download-icons.sh — Baixa icones Material Design Icons (MDI) e converte para PNG

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `rsvg-convert` + `npm`
- Exemplo: `dogu download-icons -c educacao -s 24,48`
- Flags: `--category, -c (string)` Categorias separadas por virgula ·
  `--output, -o (string)` Diretorio de saida ·
  `--sizes, -s (string)` Tamanhos PNG separados por virgula · `--list (bool)` Lista icones disponiveis ·
  `--list-categories (bool)` Lista categorias disponiveis

## pomodoro-timer.sh — Timer Pomodoro com notificacoes

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu pomodoro-timer -w 25 -b 5`
- Flags: `--work, -w (int)` Minutos de trabalho · `--break, -b (int)` Minutos de pausa ·
  `--long-break, -l (int)` Minutos de pausa longa · `--cycles, -c (int)` Sessoes antes de pausa longa ·
  `--status (bool)` Mostra sessoes de hoje · `--reset (bool)` Reseta contagem do dia ·
  `--no-sound (bool)` Desativa som

## qr-gen.sh — Gera QR Code no terminal ou salva como PNG

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `qrencode`
- Exemplo: `dogu qr-gen -t 'https://example.com'`
- Flags: `--text, -t (string)` Texto/URL para gerar QR Code · `--output, -o (string)` Salva como PNG ·
  `--size, -s (int)` Tamanho do modulo

## quick-notes.sh — Bloco de notas rapido com busca e tags

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu quick-notes -a 'Revisar PR #123 #trabalho'`
- Flags: `--add, -a (string)` Adiciona nota · `--search, -s (string)` Busca notas por termo ·
  `--tag, -t (string)` Lista notas por tag · `--delete, -d (int)` Remove nota por ID ·
  `--list, -l (bool)` Lista todas as notas · `--edit, -e (int)` Edita nota no editor ·
  `--export (string)` Exporta notas para arquivo

## stopwatch.sh — Cronometro com voltas (laps)

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: sim
- Exemplo: `dogu stopwatch`
- Flags: `--laps, -l (bool)` Mostra voltas da ultima sessao

## todo.sh — Lista de tarefas com prioridades, categorias e persistencia

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu todo -a 'Implementar feature X @backend +projeto'`
- Flags: `--add, -a (string)` Adiciona tarefa · `--done, -d (int)` Marca tarefa como concluida ·
  `--undo, -u (int)` Desmarca tarefa concluida · `--remove, -r (int)` Remove tarefa ·
  `--list, -l (string)` Lista tarefas · `--edit, -e (string)` Edita texto da tarefa ·
  `--pri, -p (string)` Define prioridade (A-Z) · `--clean (bool)` Remove tarefas concluidas

## url-shortener.sh — Encurta URLs usando is.gd

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `curl`
- Exemplo: `dogu url-shortener -u https://example.com/long/path`
- Flags: `--url, -u (string)` URL para encurtar · `--custom, -c (string)` Alias personalizado

## weather.sh — Previsao do tempo via wttr.in com localizacao automatica

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `curl`
- Exemplo: `dogu weather -l Sao Paulo -f full`
- Flags: `--location, -l (string)` Cidade ou localizacao ·
  `--format, -f (string)` Formato: full, compact, simple · `--forecast (bool)` Previsao de 3 dias

## world-clock.sh — Relogio com multiplos fusos horarios configuraveis

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Exemplo: `dogu world-clock -z 'America/Sao_Paulo,Europe/London'`
- Flags: `--zones, -z (string)` Lista de fusos separados por virgula · `--add (string)` Adiciona fuso horario ·
  `--remove (string)` Remove fuso horario · `--list (bool)` Lista fusos disponiveis ·
  `--live (bool)` Modo continuo
