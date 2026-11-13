# Mídia — referência

Categoria `media` · 7 scripts · 1 com `--json` · 4 com `--dry-run`.

Imagem, áudio, vídeo, screenshots e transcrições.

Invocação: `dogu <script> [flags]` (o `.sh` é opcional). Contrato completo de
flags: `dogu <script> --help`.

## audio-to-text.sh — Transcreve arquivos de audio locais via Whisper

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `ffmpeg` · Python: `faster-whisper` · opcional: `openai-whisper`
- Exemplo: `dogu audio-to-text -m base audio.mp3`
- Flags: `--model, -m (string)` Modelo Whisper: tiny, base, small, medium, large ·
  `--language, -l (string)` Idioma: auto, en, pt · `--output, -o (string)` Arquivo de saida ·
  `--format, -f (string)` Formato: txt, srt, vtt ·
  `--backend (string)` Backend: auto, faster-whisper, openai-whisper ·
  `--verbose (bool)` Mostra segmentos e progresso

## media-control.sh — Controla players MPRIS e mostra now playing

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `playerctl`
- Exemplo: `dogu media-control --toggle`
- Flags: `--play (bool)` Retoma reproducao · `--pause (bool)` Pausa reproducao ·
  `--toggle, -t (bool)` Alterna play/pause · `--next, -n (bool)` Proxima faixa ·
  `--prev, -p (bool)` Faixa anterior · `--stop (bool)` Para reproducao ·
  `--status (bool)` Mostra status atual · `--volume (int)` Define volume do player (0-100)

## screenshot.sh — Captura de tela com salvamento automatico

- Risco: `read-only` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `scrot` + `maim` + `gnome-screenshot`
- Exemplo: `dogu screenshot -m area -d 3`
- Flags: `--mode, -m (string)` Modo: full, area, window · `--output, -o (string)` Diretorio de saida ·
  `--delay, -d (int)` Atraso em segundos · `--clipboard (bool)` Copia para clipboard

## video-catalog-organizer.sh — Organiza catalogo de videos por estrategia

- Risco: `dry-run-ok` · JSON: não · Dry-run: não · Interativo: não
- Dependências: `ffprobe`
- Exemplo: `dogu video-catalog-organizer --by year ~/Videos`
- Flags: `--by (string)` Estrategia: content, year, quality · `--apply (bool)` Efetiva os mv ·
  `--probe-quality (bool)` Usa ffprobe para resolucao real ·
  `--recursive, -r (bool)` Processa subpastas

## video-to-audio.sh — Extrai a trilha de audio de arquivos de video

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `ffmpeg`
- Exemplo: `dogu video-to-audio -f mp3 video.mp4`
- Flags: `--output, -o (string)` Arquivo de saida ·
  `--format, -f (string)` Formato: mp3, m4a, ogg, wav, flac, opus ·
  `--copy (bool)` Copia stream sem re-encodar

## video-to-text.sh — Converte video em texto via extracao de audio e Whisper

- Risco: `dry-run-ok` · JSON: sim · Dry-run: sim · Interativo: não
- Dependências: `ffmpeg` · Python: `faster-whisper`
- Exemplo: `dogu video-to-text -f srt -l pt aula.mp4`
- Flags: `--output, -o (string)` Arquivo de saida · `--format, -f (string)` Formato: txt, srt ou vtt ·
  `--language, -l (string)` Idioma: auto, en ou pt ·
  `--model, -m (string)` Modelo Whisper: tiny, base, small, medium, large ·
  `--keep-audio (bool)` Mantem o audio extraido

## yt-transcript.sh — Baixa transcricoes de videos do YouTube (EN e PT-BR)

- Risco: `dry-run-ok` · JSON: não · Dry-run: sim · Interativo: não
- Dependências: `curl` + `yt-dlp`
- Exemplo: `dogu yt-transcript -l both https://youtube.com/watch?v=...`
- Flags: `--lang, -l (string)` Idioma: en, pt, both · `--output, -o (string)` Diretorio de saida ·
  `--format, -f (string)` Formato: txt, srt, vtt · `--no-auto (bool)` Nao incluir legendas automaticas
