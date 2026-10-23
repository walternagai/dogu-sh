# Revisão de usabilidade e portfólio — dōgu-sh

**Resultado:** revisão concluída em 2026-10-23. Os 105 scripts foram triados, 11 clusters de sobreposição foram avaliados (7 com recomendação de mudança e 4 de manutenção) e 10 scripts novos foram propostos. Nenhum arquivo de produção foi alterado. O portfólio tem higiene de CLI alta (100/105 scripts com 9–10 de 10), mas carrega 8 achados P0 de contrato/metadados, 7 recomendações P1 de união/divisão/consolidação e 10 lacunas P2 de funcionalidade.

Task correspondente: `.kata/revisao-usabilidade-scripts.yaml`.

> **Atualização 2026-10-23:** os oito achados P0 foram implementados na task `p0-usabilidade-e-contrato`. O Anexo A é o retrato anterior à implementação; as notas de status abaixo refletem o código atual.

### Status dos P0

| Achado | Status | Observação |
|---|---|---|
| P0-01 SIGPIPE | ✅ Implementado | Sem traceback; exit 141 com `pipefail` é o comportamento Unix esperado |
| P0-02 Python no instalador | ✅ Implementado | Aviso acionável no `install-scripts.sh`; README declara o requisito |
| P0-03 `dogu-make-skill`/`SKILL.md` | ✅ Implementado | Registrado no manifesto e menu, `--version`, `SKILL.md` versionado |
| P0-04 metadados | ✅ Implementado | 8 divergências corrigidas; `dry_run_default` separado de `has_dry_run` |
| P0-05 dependências | ✅ Implementado | `deps_any`, `deps_python`, `deps_optional`; `brightness` instala uma alternativa; checker lê os campos |
| P0-06 guards de TTY | ✅ Implementado | `env-manager`, `lab-manager` e `menu-launcher` falham com mensagem acionável |
| P0-07 cores em pipes | ✅ Implementado com ressalva | Detecção de TTY nos 104 scripts + `NO_COLOR` + `dogu --no-color`; flag `--no-color` por script não foi adicionada (use `NO_COLOR=1`) |
| P0-08 `--json` | ✅ Implementado | 9 scripts; 9 smoke tests em `jq` passaram |

### Status dos P1

| Item | Status | Resultado |
|---|---|---|
| P1-01 backup Docker | ✅ Decidido | Manter separados; fronteiras e "Veja também" documentados |
| P1-02 `archive-manager` × `unarchive` | ✅ Implementado | `--unpack` delega a `unarchive` |
| P1-03 `quick-backup` × `folder-sync` | ✅ Decidido | Manter separados; referências cruzadas |
| P1-04 `hunt-duplicates` × `dedup-files` | ✅ Decidido | Manter ambos; preset seguro vs avançado |
| P1-05 `codebase-summary` × `context-gather` | ✅ Decidido | Manter separados; referências cruzadas |
| P1-06 biblioteca de conversão | ✅ Avaliado | Não extrair agora; convenção no SCRIPTING_GUIDE |
| P1-07 `doctor` + `completion` | ✅ Implementado | 8 checks e completion bash/zsh |
| P1-08 README/menu × manifesto | ✅ Implementado | `doctor` verifica 105/105 |

Detalhes em `P1-DECISOES.md`.

---

## 1. Escopo e método

**Escopo:** os 105 arquivos `*.sh`, o dispatcher `dogu`, o manifesto `dogu.json`, o menu, o README e o `SKILL.md`.

**Método:**

1. Triagem automatizada de 105/105 scripts com 10 verificações observáveis: manifesto, menu, README, `--help`, exemplos no help, `--version`, `set -euo pipefail`, `NO_COLOR`, metadados corretos e segurança de operação destrutiva/prompt.
2. Smoke tests de dispatcher, ajuda, JSON, dry-run, pipes e execução não interativa.
3. Deep dive nos clusters com sobreposição funcional: timers, duplicados, arquivamento, backup/sync, Docker, disco, ambiente/dependências, análise de código, conversão e scripts monolíticos.
4. Análise de lacunas para scripts novos, exigindo composição explícita com ferramentas existentes.

**Caveats honestos:**

- A triagem não leu linha a linha os 35.372 LOC. O deep dive cobriu os clusters e os scripts com maior risco de sobreposição; scripts triviais ou isolados receberam apenas a triagem.
- Não houve teste end-to-end de cada ferramenta em todas as plataformas. Comportamento específico de macOS, PipeWire, Docker rootless e ambientes sem TTY não foi exaustivamente validado.
- A nota de higiene mede presença e consistência de contratos de CLI, não a qualidade intrínseca da ferramenta. Há efeito-teto: 100/105 scripts ficam em 9–10 (a nota é saturada), então a ação está nas lacunas, não na nota.
- Não houve estudo com usuários; as recomendações de usabilidade vêm de evidência de código e de comportamento observável.

---

## 2. Diagnóstico em números

| Métrica | Valor |
|---|---:|
| Scripts `.sh` no disco | 105 |
| Entradas no `dogu.json` | 104 |
| Entradas no menu | 104 |
| Scripts citados no README | 105 |
| LOC totais em `.sh` | 35.372 |
| Scripts com `--json` | 26 |
| Scripts com `--dry-run` | 43 |
| Scripts com `--quiet` | 4 |
| Scripts com `--verbose` | 6 |
| Scripts com `NO_COLOR` | 104 |
| Scripts com `set -euo pipefail` | 104 |
| Scripts com guard de TTY | 42 |
| Scripts que usam `check_and_install` | 72 |
| Scripts sem exemplos no `--help` | 21 |
| Scripts sem `--version` | 1 |
| Scripts fora do manifesto/menu | 1 |
| Divergências de metadados | 8 |
| Candidatos a `--json` sem `--json` | 9 |
| Divergências de dependências | 7 |
| Prompts interativos sem guard | 3 |
| Interativos não declarados no manifesto | 2 |

Distribuição da nota de higiene: **100 scripts em 9–10/10**, **4 em 7–8/10** (`env-manager`, `lab-manager`, `menu-launcher`, `dependency-helper`), **1 em 6/10** (`dogu-make-skill.sh`).

O portfólio é disciplinado: shebang, strict mode, `NO_COLOR`, `--help` e `--version` estão quase universalmente presentes. As lacunas concentram-se em **metadados que mentem**, **dependências mal modeladas**, **automação/JSON** e **sobreposição funcional** — não em ausência de padrões básicos.

---

## 3. Achados P0 — contrato, segurança e automação

### P0-01 — `dogu --json` quebra com SIGPIPE

**Evidência:**

```bash
./dogu list --json | head -c 120
# Traceback (most recent call last):
#   File "<string>", line 21, in <module>
# BrokenPipeError: [Errno 32] Broken pipe
```

O erro aparece quando o consumidor fecha o pipe antes de o Python terminar de escrever (por exemplo, `head -c 120`, `jq` com `first`, ou um agente que interrompe a leitura). `head -2` não reproduz porque o buffer já foi drenado.

**Impacto:** qualquer pipeline de agente ou shell que limite a saída do dispatcher recebe traceback e exit code sujo.

**Recomendação:** nos snippets Python do `dogu`, restaurar o comportamento padrão de SIGPIPE (`signal.signal(signal.SIGPIPE, signal.SIG_DFL)`) ou capturar `BrokenPipeError` e sair com 0; nunca imprimir traceback.

**Teste de aceite:** `./dogu list --json | head -c 120` termina sem traceback; com `set -o pipefail`, o exit 141 é o SIGPIPE esperado do produtor.

---

### P0-02 — o dispatcher exige Python, mas o instalador não verifica

**Evidência:**

```bash
PATH=/tmp/kata-revisao/bin ./dogu version
# ✗ Python não encontrado. Necessário para parsear dogu.json
```

O `install-scripts.sh` copia `dogu` e `dogu.json`, mas não verifica nem instala Python. Todo o restante do kit é Bash; o único ponto que exige Python é o dispatcher.

**Impacto:** instalação "bem-sucedida" que falha no primeiro comando; quebra em sistemas mínimos e em imagens de container sem Python.

**Recomendação:** escolher explicitamente uma das rotas: (a) declarar Python como dependência obrigatória no instalador e no README, com checagem em `install-scripts.sh`; (b) criar fallback em `jq`/`awk` para as consultas do manifesto; ou (c) adicionar `dogu doctor` que diagnostica Python, manifesto e scripts ausentes. A rota (a) é a menor e mais honesta; a (b) é a mais portátil, mas JSON em Bash é frágil.

**Teste de aceite:** `./install-scripts.sh --dry-run` informa o status de Python; `dogu doctor` existe e retorna diagnóstico claro; README lista a dependência.

---

### P0-03 — `dogu-make-skill.sh` está fora do manifesto/menu e o `SKILL.md` não existe

**Evidência:**

- `dogu-make-skill.sh` não aparece em `dogu.json` nem em `menu-launcher.sh`.
- Não tem `--version`.
- `SKILL.md` não existe na raiz, apesar de AGENTS.md e README o citarem.

**Impacto:** o gerador de skill é invisível para agentes e para o menu; a documentação promete um artefato que não está no repositório.

**Recomendação:** registrar no manifesto (categoria `devops` ou `other`), adicionar ao menu ou documentar a exclusão, adicionar `--version` e gerar `SKILL.md` como artefato versionado. Incluir verificação de que `dogu-make-skill.sh --dry-run` é idêntico ao `SKILL.md`.

**Teste de aceite:**

```bash
jq -e '.scripts["dogu-make-skill.sh"]' dogu.json
./dogu-make-skill.sh --version
test -f SKILL.md
diff <(./dogu-make-skill.sh --dry-run) SKILL.md
```

---

### P0-04 — oito divergências entre manifesto e comportamento real

**Evidência:**

| Script | Campo | Manifesto | Real |
|---|---|---|---|
| `brightness.sh` | `has_dry_run` | `false` | tem `--dry-run` |
| `dark-mode.sh` | `has_dry_run` | `false` | tem `--dry-run` |
| `docker-stats-history.sh` | `has_dry_run` | `false` | tem `--dry-run` |
| `hunt-duplicates.sh` | `has_json` | `true` | não tem `--json` |
| `package-list-backup.sh` | `has_json` | `false` | tem `--json` |
| `ssh-tunnel-mgr.sh` | `has_dry_run` | `false` | tem `--dry-run` |
| `video-catalog-organizer.sh` | `has_dry_run` | `true` | dry-run é o padrão; não existe flag `--dry-run` |
| `volume.sh` | `has_dry_run` | `false` | tem `--dry-run` |

O caso de `video-catalog-organizer` revela a causa raiz: o campo `has_dry_run` não distingue **"suporta a flag `--dry-run`"** de **"o modo padrão é dry-run e `--apply` efetiva"**.

**Impacto:** agentes e usuários que confiam no manifesto tomam decisões erradas sobre automação e segurança.

**Recomendação:** corrigir os sete campos objetivos e definir a semântica:

- `has_dry_run`: suporta a flag `--dry-run`.
- `dry_run_default`: o modo padrão não altera nada.
- `has_json`: suporta `--json` com schema estável.

**Teste de aceite:** um verificador (`dogu doctor` ou script de CI) compara manifesto × flags reais e retorna zero divergências.

---

### P0-05 — dependências misturam binário, pacote, alternativa e dependência Python

**Evidência:**

| Script | Manifesto declara | Código realmente usa | Problema |
|---|---|---|---|
| `brightness.sh` | `light`, `brightnessctl`, `xrandr` | um dos três, em fallback | instala os três alternativas |
| `audio-to-text.sh` | `ffmpeg` | `ffmpeg` + `faster-whisper`/`whisper` | dependência Python omitida |
| `media-control.sh` | `dbus-send` | `playerctl` | dependência errada |
| `xlsx-to-csv.sh` | `ssconvert`, `python3` | `python3` + `openpyxl` | `ssconvert` não é usado |
| `pdf-to-md.sh` | `pdftoppm`, `tesseract` | `pdftotext` + OCR opcional | falta a dependência primária |
| `env-keygen.sh` | `[]` | `openssl` | dependência omitida |
| `docker-compose-manager.sh` | `docker`, `docker-compose` | `docker compose` (plugin) e fallback v1 | modelo não expressa plugin |

**Impacto:** instalações desnecessárias, falhas em tempo de execução e `dependency-checker` com resultados enganosos.

**Recomendação:** evoluir o schema sem quebrar compatibilidade:

```json
"deps": ["ffmpeg"],
"deps_any": [["light", "brightnessctl", "xrandr"]],
"deps_python": ["faster-whisper"],
"deps_optional": ["tesseract"]
```

`deps` continua sendo "binários obrigatórios"; `deps_any` expressa alternativas; `deps_python` expressa pacotes Python; `deps_optional` expressa o que melhora a experiência mas não bloqueia. Atualizar `dependency-checker.sh` para entender os quatro campos.

**Teste de aceite:** `dependency-checker.sh --all` não tenta instalar `light`, `brightnessctl` e `xrandr` ao mesmo tempo; cada script declara a dependência que realmente bloqueia.

---

### P0-06 — três entrypoints têm prompt interativo sem guard de TTY

**Evidência:**

- `env-manager.sh:137` e `:147` usam `read -p` sem `[ -t 0 ]`.
- `lab-manager.sh` tem 67 chamadas de `read -p` sem guard.
- `menu-launcher.sh:507` e `:523` usam `read -p` sem guard.

Execução com `</dev/null` retorna erro ou segue com entrada vazia, mas não há detecção explícita de "não interativo". Em um pipe que permanece aberto, o script pode bloquear.

**Impacto:** agentes e CI podem travar ou tomar caminhos inesperados; a mensagem de erro não diz como resolver.

**Recomendação:** aplicar o padrão já usado em `dedup-files.sh`, `docker-restore.sh` e `folder-sync.sh`:

```bash
if [ -t 0 ]; then
  read -r -p "..." var < /dev/tty
else
  error "Execução não interativa detectada. Use --yes ou rode em terminal interativo."
fi
```

Para `menu-launcher.sh`, declarar `interactive: true` já está correto no manifesto; ainda assim, falhar de forma limpa é melhor que abrir o menu em pipe.

**Teste de aceite:** `timeout 3 ./env-manager.sh </dev/null` retorna erro explicativo sem bloquear; idem para `lab-manager` e `menu-launcher`.

---

### P0-07 — cores ANSI vazam para pipes e logs

**Evidência:**

```bash
./disk-space.sh | cat -v | head -3
# ^[[1;36m━━━━━━...
```

`NO_COLOR=1` funciona, mas a detecção automática de TTY não existe: o padrão é colorir sempre. O `dogu --help` também emite ANSI quando redirecionado.

**Impacto:** logs de CI, arquivos e saída consumida por agentes ficam poluídos com escapes; aumenta tokens e quebra parsing.

**Recomendação:** inicializar cores apenas quando `[ -t 1 ]` e `NO_COLOR` estiver ausente; adicionar `--no-color` como override explícito no dispatcher (por script, `NO_COLOR=1` continua sendo o contrato). Aplicar em todos os scripts que definem cores, começando pelos mais usados.

**Teste de aceite:** `./disk-space.sh | grep -c $'\033'` retorna 0; `NO_COLOR=1` continua funcionando; `dogu --no-color` funciona em TTY.

---

### P0-08 — `--json` cobre 26/105 scripts e falta nos analíticos

**Evidência:** 26 scripts suportam `--json`. Nove scripts analíticos produzem dados tabulares/estruturados sem saída JSON:

`docker-image-slimmer.sh`, `docker-logs-watcher.sh`, `docker-stats-history.sh`, `docker-volume-mgr.sh`, `port-check.sh`, `snap-flatpak-manager.sh`, `speedtest-log.sh`, `ssh-key-manager.sh`, `wifi-scanner.sh`.

**Impacto:** agentes precisam parsear tabelas coloridas; automação fica frágil.

**Recomendação:** priorizar os nove candidatos, começando por `port-check`, `docker-volume-mgr` e `ssh-key-manager`. Definir um schema mínimo comum (`{"status": ..., "items": [...], "errors": [...]}`) no SCRIPTING_GUIDE.

**Teste de aceite:** cada script candidato tem `--json`, a saída passa em `jq .` e o manifesto marca `has_json: true`.

---

## 4. Decisões de união e divisão (P1)

Critérios usados: mesmo modelo mental? mesmas dependências? sobreposição de flags? custo de compatibilidade? o resultado continua sendo **uma ferramenta coerente** (princípio "um script por ferramenta" do AGENTS.md)?

| Cluster | Evidência | Decisão | Ação recomendada |
|---|---|---|---|
| `quick-backup.sh` × `folder-sync.sh` | Jaccard de flags 0,64; ambos wrappers de `rsync`; `--all`, `--compress`, `--dry-run`, `--exclude-from`, `--stats` duplicados | **Unir** | Criar `rsync-tool` com `--mode backup,sync,mirror,watch`; manter os nomes antigos como aliases deprecados |
| `docker-backup.sh` × `docker-restore.sh` × `docker-volume-mgr.sh` | `volume-mgr` já tem `--backup` e `--restore`; `backup`/`restore` operam volumes e containers | **Consolidar** | `docker-volume-mgr` delega backup/restore a `docker-backup`/`docker-restore`; remover duplicação ou transformar em aliases |
| `hunt-duplicates.sh` × `dedup-files.sh` | Mesmo domínio e mesma ação final; 935 vs 357 linhas; `hunt` tem lixeira/restore/watch/cache, `dedup` tem algoritmo em estágios e `--keep` | **Unir a médio prazo** | Spike de consolidação: `dedup-files` como preset seguro (dry-run padrão) e `hunt-duplicates` como engine avançada, ou um `dedup` com `--mode fast,deep`; não unir sem plano de compatibilidade |
| `archive-manager.sh` × `unarchive.sh` | `archive-manager --unpack` e `unarchive` extraem os mesmos formatos com implementações distintas | **Dividir responsabilidade** | `archive-manager` só compacta; `--unpack` delega a `unarchive` ou é removido com aviso de depreciação |
| `codebase-summary.sh` × `context-gather.sh` | Ambos varrem o projeto e emitem JSON para agentes; flags `--path`/`--project`, `--json`; `codebase-summary` é resumo, `context-gather` é contexto por arquivo | **Avaliar união parcial** | Testar `context-gather --summary` como substituto de `codebase-summary`; se a saída for equivalente, unir; senão, compartilhar biblioteca de detecção e output |
| `env-manager.sh` × `env-validator.sh` | Nomes vizinhos, funções distintas: manager orquestra ambiente; validator valida `.env` | **Manter separados** | Renomear/documentar a fronteira; adicionar flags reais ao `env-manager` (`--check`, `--install`, `--json`) |
| `alarm.sh` × `stopwatch.sh` × `pomodoro-timer.sh` | Modelos distintos: alarme por horário/duração, cronômetro crescente com voltas, ciclos Pomodoro | **Manter** | Extrair biblioteca de notificação e som; adicionar grupo `dogu timer` no dispatcher |
| Disco: `disk-space`, `disk-scanner`, `partitions-list`, `disk-health`, `dir-summary` | Funções complementares, não sobrepostas | **Manter** | Adicionar grupo `dogu disk`; padronizar `--json` e unidades |
| `docker-status`, `docker-healthcheck`, `docker-audit`, `docker-cis-benchmark`, `docker-bottleneck-detect` | Diagnósticos complementares, mas com cinco pontos de entrada | **Manter + agregador** | Novo `docker-doctor` que executa os cinco e resume; não duplicar lógica |
| `docx-to-md` × `pdf-to-md` × `pdf-to-jpg` × `jpg-to-text` | Pipeline de documentos; flags comuns de lote/recursivo | **Manter** | Compartilhar biblioteca de conversão/lote; novo `pdf-split`/`pdf-merge` |
| Monolíticos: `lab-manager` (2.017 LOC), `setup-workspace` (1.118), `hunt-duplicates` (935), `git-sync` (900), `package-list-backup` (818) | Tamanho alto e múltiplas responsabilidades | **Dividir só por responsabilidade** | `lab-manager`: separar instaladores da UI; `git-sync`: extrair `git-commit-ai`; `package-list-backup`: separar export/import se os fluxos divergirem. Tamanho sozinho não justifica divisão |

### Leitura das decisões

- **Unir agora (baixo risco):** `docker-volume-mgr` × `docker-backup`/`docker-restore`; `archive-manager --unpack` × `unarchive`.
- **Unir com spike:** `quick-backup` × `folder-sync`; `hunt-duplicates` × `dedup-files`.
- **Não unir:** timers, disco, conversão de documentos, diagnósticos Docker — são ferramentas distintas que compartilham infraestrutura, não identidade.
- **Dividir:** apenas onde há duas responsabilidades testáveis separadamente, não por contagem de linhas.

---

## 5. Scripts novos propostos (P2)

Cada proposta declara a lacuna e com o que compõe. Nenhuma duplica uma ferramenta existente.

| Prioridade | Script | Lacuna | Compõe com | Por que não é flag/alias |
|---|---|---|---|---|
| 1 | `video-to-text` | não existe pipeline vídeo → transcrição | `video-to-audio` + `audio-to-text` | duas etapas com dependências distintas (ffmpeg + Whisper); um alias não resolve o encadeamento, limpeza e formato |
| 2 | `pdf-split` / `pdf-merge` | não há divisão/junção de PDF | `pdf-to-jpg`, `pdf-to-md` | operações de página, não de conversão; `pdftk`/`qpdf` não estão expostos |
| 3 | `image-optimizer` | não há compressão/redimensionamento de imagens | `screenshot`, `download-icons` | complementa a captura/baixa com pós-processamento em lote |
| 4 | `ssl-cert-check` | não há verificação de validade/cadeia TLS | `dns-lookup`, `port-check`, `whois` | diagnóstico de certificado, não de DNS/porta |
| 5 | `docker-doctor` | cinco comandos de diagnóstico sem visão agregada | `docker-status`, `docker-healthcheck`, `docker-audit`, `docker-cis-benchmark`, `docker-bottleneck-detect` | agrega e prioriza; não substitui os detalhes |
| 6 | `json-yaml-tool` | não há validação/formatação/consulta de JSON/YAML | `base64-tool`, conversores | ferramenta de dados, não de codificação |
| 7 | `cron-manager` / `systemd-timer` | não há agendamento persistente | `alarm`, `pomodoro-timer` | alarme é sessão; cron/systemd é persistência |
| 8 | `http-server` | não há servidor local de diretório | `port-check`, `api-tester` | serving não é teste de API |
| 9 | `dotfiles-manager` | não há gestão de dotfiles | `setup-workspace`, `package-list-backup` | backup de pacotes não versiona configurações |
| 10 | `file-watcher` | observação de arquivos só existe dentro de `folder-sync --watch` | `folder-sync`, `quick-backup` | watcher genérico serve a múltiplos fluxos, não só rsync |

### Recomendação de sequência

1. **Onda 1:** `video-to-text`, `pdf-split`/`pdf-merge`, `image-optimizer`.
2. **Onda 2:** `ssl-cert-check`, `docker-doctor`.
3. **Onda 3:** `json-yaml-tool`, `cron-manager`, `http-server`, `dotfiles-manager`, `file-watcher`.

Cada script novo deve nascer com `--help`, `--version`, `--json` quando analítico, `NO_COLOR`, guard de TTY e entrada no manifesto/menu/README — o custo de fazer isso depois é maior.

---

## 6. Backlog priorizado

### P0 — quick wins (contrato e segurança)

| ID | Ação | Esforço |
|---|---|---|
| P0-01 | Corrigir SIGPIPE no `dogu` | Baixo |
| P0-02 | Declarar/checar Python no instalador ou criar fallback | Baixo–médio |
| P0-03 | Registrar `dogu-make-skill`, adicionar `--version`, gerar `SKILL.md` | Baixo |
| P0-04 | Corrigir os 8 metadados e definir semântica de `has_dry_run` | Baixo |
| P0-05 | Introduzir `deps_any`/`deps_python` e corrigir 7 scripts | Médio |
| P0-06 | Guards de TTY em `env-manager`, `lab-manager`, `menu-launcher` | Baixo |
| P0-07 | Detecção de TTY para cores + `--no-color` | Médio (muitos arquivos) |
| P0-08 | `--json` nos 9 analíticos candidatos | Médio |

### P1 — estrutura

| ID | Ação | Esforço |
|---|---|---|
| P1-01 | Consolidar backup/restore Docker | Médio |
| P1-02 | Dividir `archive-manager` × `unarchive` | Baixo |
| P1-03 | Spike `quick-backup` × `folder-sync` | Médio |
| P1-04 | Spike `hunt-duplicates` × `dedup-files` | Alto |
| P1-05 | Avaliar `codebase-summary` × `context-gather` | Médio |
| P1-06 | Biblioteca compartilhada de conversão/lote | Médio |
| P1-07 | `dogu doctor` + `dogu completion` | Médio |
| P1-08 | Alinhar README/menu ao manifesto (ou gerar seções) | Baixo–médio |

### P2 — expansão

Os 10 scripts da seção 5, em três ondas.

### Próximas tasks sugeridas

| Task | Escopo | Depende de |
|---|---|---|
| `quick-wins-manifesto-e-cli` | P0-01 a P0-08 | nada |
| `schema-deps-e-dogu-doctor` | P0-05, P1-07 | `quick-wins-manifesto-e-cli` |
| `consolidacao-backup-arquivamento` | P1-01, P1-02, P1-03 | P0-04 |
| `consolidacao-duplicados` | P1-04 | P1-01 |
| `pipeline-midia-pdf` | Onda 1 de scripts novos | `quick-wins-manifesto-e-cli` |

Separar as tasks evita que uma correção de manifesto e uma união de scripts concorram pelo mesmo diff, e permite reverter cada mudança isoladamente.

---

## 7. Verificação executada

```text
$ python -m kata --check-only
▶ bash -c shellcheck --severity=error dogu *.sh   ✅ limpo
▶ bash -c bash -n dogu *.sh                       ✅ passou
▶ coverage (gate ≥ 70%)                           ✅ 100.0%
✅ KATA CYCLE — APROVADO
```

Também foram executados:

- `jq empty dogu.json` — JSON válido.
- Smoke tests de `dogu version`, `dogu list`, `dogu search`, `dogu info`, `dogu categories`, `dogu risks`.
- Smoke tests de `--help`/`--version` em amostras de cada categoria.
- Reprodução dos achados P0-01, P0-02, P0-04, P0-05, P0-06 e P0-07.

**Nenhum arquivo de produção foi alterado.** Os únicos artefatos criados são este relatório e o registro da task em `.kata/`.

**JUDGE:** `VERIFIED` — baseline ancorado em `refs/kata/base/2b4a4277…`; lint, testes e coverage re-executados; a única claim aceita sem re-execução é o critério de sucesso, que é qualitativo.

**PENDING:** P0 e P1 implementados; implementar os scripts novos e o agregador `docker-doctor` do P2 — aguardando autorização e priorização.

---

## Anexo A — Matriz de triagem (105 scripts)

Legenda das lacunas:

- **M** — fora do manifesto/menu
- **V** — sem `--version`
- **E** — sem exemplos no `--help`
- **D** — metadado divergente do comportamento real
- **J** — candidato a `--json` (analítico, sem `--json`)
- **P** — prompt interativo sem guard de TTY
- **I** — interativo não declarado no manifesto
- **X** — dependência divergente/incompleta

A coluna **Higiene** é a soma de 10 verificações (manifesto, menu, README, help, exemplos, versão, strict, `NO_COLOR`, metadado correto, segurança). Ela mede contrato de CLI, não qualidade da ferramenta. A categoria `?` indica script fora do manifesto (`dogu-make-skill.sh`).

| Script | Categoria | LOC | Higiene | JSON | Risco | Lacunas |
|---|---|---:|---:|---|---|---|
| `dogu-make-skill.sh` | ? | 297 | 6/10 | sim |  | M,V |
| `codebase-summary.sh` | code-analysis | 373 | 9/10 | sim | read-only | E |
| `context-gather.sh` | code-analysis | 297 | 9/10 | sim | read-only | E |
| `dependency-tree.sh` | code-analysis | 352 | 9/10 | sim | read-only | E |
| `impact-analyzer.sh` | code-analysis | 361 | 9/10 | sim | read-only | E |
| `stack-detector.sh` | code-analysis | 438 | 9/10 | sim | read-only | E |
| `test-coverage.sh` | code-analysis | 289 | 9/10 | sim | read-only | E |
| `base64-tool.sh` | conversion | 229 | 10/10 | nao | read-only | — |
| `color-converter.sh` | conversion | 293 | 10/10 | nao | read-only | — |
| `currency-converter.sh` | conversion | 176 | 10/10 | nao | read-only | — |
| `docx-to-md.sh` | conversion | 264 | 10/10 | nao | dry-run-ok | — |
| `jpg-to-text.sh` | conversion | 195 | 10/10 | nao | dry-run-ok | — |
| `md-to-pdf.sh` | conversion | 184 | 9/10 | nao | read-only | E |
| `pdf-to-jpg.sh` | conversion | 245 | 10/10 | nao | dry-run-ok | — |
| `pdf-to-md.sh` | conversion | 369 | 10/10 | nao | dry-run-ok | X |
| `ris-to-csv.sh` | conversion | 562 | 10/10 | nao | dry-run-ok | — |
| `unit-converter.sh` | conversion | 317 | 10/10 | nao | read-only | — |
| `xlsx-to-csv.sh` | conversion | 383 | 10/10 | nao | dry-run-ok | X |
| `env-manager.sh` | devops | 163 | 8/10 | nao | read-only | E,P,I |
| `env-validator.sh` | devops | 286 | 9/10 | sim | read-only | E |
| `folder-sync.sh` | devops | 237 | 10/10 | nao | destructive | — |
| `git-pr-checklist.sh` | devops | 422 | 10/10 | sim | read-only | — |
| `git-stale.sh` | devops | 336 | 10/10 | sim | destructive | — |
| `git-sync.sh` | devops | 901 | 10/10 | nao | destructive | — |
| `install-scripts.sh` | devops | 209 | 9/10 | nao | dry-run-ok | E |
| `lab-manager.sh` | devops | 2018 | 8/10 | sim | dry-run-ok | E,P,I |
| `menu-launcher.sh` | devops | 602 | 8/10 | nao | read-only | E,P |
| `nerd-font-install.sh` | devops | 430 | 10/10 | nao | dry-run-ok | — |
| `package-list-backup.sh` | devops | 818 | 9/10 | sim | dry-run-ok | D |
| `quick-backup.sh` | devops | 199 | 10/10 | nao | dry-run-ok | — |
| `snap-flatpak-manager.sh` | devops | 355 | 10/10 | nao | dry-run-ok | J |
| `docker-audit.sh` | docker | 334 | 9/10 | sim | read-only | E |
| `docker-backup.sh` | docker | 302 | 10/10 | nao | dry-run-ok | — |
| `docker-bottleneck-detect.sh` | docker | 311 | 10/10 | sim | read-only | — |
| `docker-cis-benchmark.sh` | docker | 371 | 10/10 | sim | read-only | — |
| `docker-clean.sh` | docker | 332 | 10/10 | nao | dry-run-ok | — |
| `docker-compose-manager.sh` | docker | 288 | 10/10 | nao | dry-run-ok | X |
| `docker-dependency-map.sh` | docker | 318 | 10/10 | nao | read-only | — |
| `docker-healthcheck.sh` | docker | 265 | 10/10 | sim | dry-run-ok | — |
| `docker-image-slimmer.sh` | docker | 340 | 10/10 | nao | read-only | J |
| `docker-logs-watcher.sh` | docker | 193 | 10/10 | nao | read-only | J |
| `docker-network-manager.sh` | docker | 339 | 10/10 | nao | dry-run-ok | — |
| `docker-resource-alert.sh` | docker | 309 | 10/10 | sim | read-only | — |
| `docker-restore.sh` | docker | 235 | 10/10 | nao | destructive | — |
| `docker-secret-scanner.sh` | docker | 302 | 10/10 | sim | read-only | — |
| `docker-stats-history.sh` | docker | 169 | 9/10 | nao | read-only | D,J |
| `docker-status.sh` | docker | 281 | 9/10 | sim | read-only | E |
| `docker-volume-mgr.sh` | docker | 421 | 10/10 | nao | dry-run-ok | J |
| `audio-to-text.sh` | media | 323 | 10/10 | nao | dry-run-ok | X |
| `media-control.sh` | media | 204 | 10/10 | nao | read-only | X |
| `screenshot.sh` | media | 190 | 10/10 | nao | read-only | — |
| `video-catalog-organizer.sh` | media | 353 | 9/10 | nao | dry-run-ok | D |
| `video-to-audio.sh` | media | 171 | 10/10 | nao | dry-run-ok | — |
| `yt-transcript.sh` | media | 337 | 10/10 | nao | dry-run-ok | — |
| `api-tester.sh` | network | 197 | 10/10 | nao | read-only | — |
| `dns-lookup.sh` | network | 165 | 10/10 | nao | read-only | — |
| `ip-info.sh` | network | 201 | 10/10 | sim | read-only | — |
| `port-check.sh` | network | 186 | 10/10 | nao | read-only | J |
| `speedtest-log.sh` | network | 359 | 10/10 | nao | read-only | J |
| `ssh-tunnel-mgr.sh` | network | 221 | 9/10 | nao | read-only | D |
| `subnet-calc.sh` | network | 177 | 10/10 | nao | read-only | — |
| `whois.sh` | network | 165 | 10/10 | nao | read-only | — |
| `wifi-scanner.sh` | network | 377 | 9/10 | nao | read-only | E,J |
| `dependency-helper.sh` | other | 71 | 7/10 | nao | read-only | E |
| `alarm.sh` | productivity | 216 | 10/10 | nao | read-only | — |
| `calculator.sh` | productivity | 200 | 10/10 | nao | read-only | — |
| `calendar.sh` | productivity | 259 | 10/10 | nao | read-only | — |
| `clipboard-manager.sh` | productivity | 357 | 10/10 | nao | read-only | — |
| `download-icons.sh` | productivity | 655 | 10/10 | nao | dry-run-ok | — |
| `pomodoro-timer.sh` | productivity | 307 | 10/10 | nao | read-only | — |
| `qr-gen.sh` | productivity | 120 | 10/10 | nao | read-only | — |
| `quick-notes.sh` | productivity | 267 | 10/10 | nao | read-only | — |
| `stopwatch.sh` | productivity | 171 | 9/10 | nao | read-only | E |
| `todo.sh` | productivity | 316 | 10/10 | nao | read-only | — |
| `url-shortener.sh` | productivity | 134 | 10/10 | nao | read-only | — |
| `weather.sh` | productivity | 128 | 10/10 | nao | read-only | — |
| `world-clock.sh` | productivity | 199 | 10/10 | nao | read-only | — |
| `env-keygen.sh` | security | 373 | 10/10 | nao | dry-run-ok | X |
| `password-gen.sh` | security | 251 | 10/10 | nao | read-only | — |
| `secret-scanner.sh` | security | 347 | 9/10 | sim | read-only | E |
| `ssh-key-manager.sh` | security | 411 | 10/10 | nao | dry-run-ok | J |
| `archive-manager.sh` | system | 193 | 9/10 | nao | dry-run-ok | E |
| `batch-rename.sh` | system | 327 | 10/10 | nao | dry-run-ok | — |
| `battery-monitor.sh` | system | 222 | 10/10 | nao | read-only | — |
| `brightness.sh` | system | 213 | 9/10 | nao | read-only | D,X |
| `clean-cache.sh` | system | 518 | 10/10 | sim | dry-run-ok | — |
| `clean-system.sh` | system | 546 | 10/10 | sim | destructive | — |
| `dark-mode.sh` | system | 242 | 9/10 | nao | read-only | D |
| `dedup-files.sh` | system | 358 | 9/10 | nao | destructive | E |
| `dependency-checker.sh` | system | 154 | 10/10 | nao | read-only | — |
| `dir-summary.sh` | system | 449 | 10/10 | nao | read-only | — |
| `disk-health.sh` | system | 461 | 10/10 | sim | read-only | — |
| `disk-scanner.sh` | system | 169 | 10/10 | nao | read-only | — |
| `disk-space.sh` | system | 423 | 10/10 | sim | read-only | — |
| `fix-exec-bit.sh` | system | 379 | 10/10 | nao | dry-run-ok | — |
| `hunt-duplicates.sh` | system | 936 | 9/10 | nao | destructive | D |
| `log-analyzer.sh` | system | 160 | 10/10 | nao | read-only | — |
| `nvidia-gpu-monitor.sh` | system | 470 | 9/10 | nao | read-only | E |
| `organize-downloads.sh` | system | 255 | 10/10 | nao | dry-run-ok | — |
| `partitions-list.sh` | system | 482 | 10/10 | sim | read-only | — |
| `process-killer.sh` | system | 133 | 10/10 | nao | destructive | — |
| `setup-workspace.sh` | system | 1119 | 10/10 | nao | dry-run-ok | — |
| `unarchive.sh` | system | 416 | 10/10 | nao | dry-run-ok | — |
| `update-all.sh` | system | 323 | 10/10 | nao | dry-run-ok | — |
| `volume.sh` | system | 378 | 9/10 | nao | read-only | D |

<!-- 105 scripts; E=21 D=8 J=9 P=3 X=7 -->
