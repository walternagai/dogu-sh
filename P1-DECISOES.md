# Decisões P1 — consolidação, descoberta e doutor

**Resultado:** os oito itens P1 foram executados. Três viraram código (`archive-manager` delega `--unpack`, `dogu doctor`, `dogu completion`), quatro terminaram em decisão documentada com evidência (backup Docker, sync/backup, duplicados, contexto de projeto) e um foi avaliado e descartado como abstração prematura (biblioteca de conversão). A cobertura manifesto/menu/README/SKILL está em 105/105.

Task: `.kata/p1-consolidacao-e-doutor.yaml`.

---

## 1. O que foi implementado

### P1-02 — `archive-manager --unpack` delega para `unarchive`

O `archive-manager` mantém `--pack` (compactação de subdiretórios em `.zip`) e passa a delegar toda extração ao `unarchive.sh`:

```bash
./archive-manager.sh --unpack ./diretorio
# → unarchive.sh ./diretorio
```

**Por quê:** o `unarchive` é superset de formatos e já cria uma subpasta por arquivo, que era exatamente a semântica do `archive-manager`. A duplicação de extração era a principal fonte de divergência entre os dois.

**Verificação:** `./archive-manager.sh --unpack --dry-run` e extração real de um `.zip` em `/tmp` produziram a mesma árvore que `unarchive.sh` produziria.

### P1-07 — `dogu doctor` e `dogu completion`

`dogu doctor` verifica, sem alterar nada:

- versão do Python;
- validade do manifesto e contagem de scripts;
- presença de todos os arquivos manifestados;
- cobertura de menu e README;
- existência do `SKILL.md`;
- consistência de `has_json`/`has_dry_run` com as flags reais;
- contadores de `total_scripts`, categorias, riscos e features.

Saída humana com ✅/⚠️/❌ e `--json` para automação. Exit code 0 quando não há erros; 1 quando há.

`dogu completion bash|zsh` gera completion dinâmico a partir do manifesto:

```bash
source <(./dogu completion bash)
./dogu completion zsh > ~/.zfunc/_dogu
```

**Verificação:** `./dogu doctor` → 8 checks, todos OK; `./dogu doctor --json | jq` válido; `bash -n` e `zsh -n` no completion gerado.

### P1-08 — cobertura manifesto/menu/README/SKILL

O `doctor` agora falha ou avisa se um script do manifesto não estiver no menu ou no README, ou se houver `.sh` fora do manifesto. Estado atual: **105/105** nos quatro artefatos.

O README ganhou a seção de `doctor` e `completion`; o menu já tinha os 105 scripts desde o P0.

---

## 2. O que foi decidido com evidência

### P1-01 — backup Docker: manter separados

| Script | Modelo | Saída |
|---|---|---|
| `docker-backup.sh` / `docker-restore.sh` | snapshot completo de volumes **e** configs de containers | diretório com timestamp |
| `docker-volume-mgr.sh` | ciclo de vida de volume + backup/restore **pontual** | `.tar.gz` por volume |

**Decisão:** não unir. São modelos de saída diferentes; forçar um único comando exigiria flags de modo e quebraria dois fluxos válidos. A ação executada foi documentar a fronteira e adicionar "Veja também" nos três `--help`.

**Critério para revisitar:** se `docker-volume-mgr` passar a oferecer snapshot de configs ou se `docker-backup` passar a gerar `.tar.gz` por volume.

### P1-03 — `quick-backup` × `folder-sync`: manter separados por enquanto

**Evidência:** Jaccard de flags 0,64; ambos usam `rsync` e compartilham `--all`, `--compress`, `--dry-run`, `--exclude-from`, `--stats`. Mas os diferenciais são de modelo mental:

- `quick-backup`: retenção (`--keep`), `--delete-excluded`, foco em backup incremental.
- `folder-sync`: `--mirror`, `--watch`, `--format`, foco em sincronização contínua.

**Decisão:** não unir agora. Um `rsync-tool` com `--mode backup|sync|mirror|watch` é viável, mas é uma nova UX, não um rename. O primeiro passo seguro é compartilhar um parser comum; isso só se paga quando houver um terceiro consumidor de `rsync`.

**Critério para revisitar:** terceiro script ou pedido recorrente de um único ponto de entrada para `rsync`.

### P1-04 — `hunt-duplicates` × `dedup-files`: manter ambos

**Evidência:** 937 vs 358 linhas. O `hunt` tem lixeira (`--trash`), restore, `--soft-link`, `--watch`, cache de hashes e modos de seleção; o `dedup-files` tem algoritmo em estágios, `--keep`, `--min-size` e dry-run padrão. O `dedup-files` é o preset seguro; o `hunt` é a ferramenta avançada.

**Decisão:** manter os dois, com "Veja também" cruzado. Unir agora exigiria migrar duas interfaces e testar dois perfis de segurança; o ganho seria cosmético.

**Critério para revisitar:** se o `dedup-files` ganhar lixeira/restore/watch, ou se o uso do `hunt` cair a ponto de valer deprecá-lo.

### P1-05 — `codebase-summary` × `context-gather`: manter separados

**Evidência:** ambos varrem o projeto e emitem JSON, mas `codebase-summary` responde "o que é este projeto?" e `context-gather` responde "o que preciso saber para mexer neste arquivo/tarefa?". Flags e saídas refletem intenções diferentes (`--deep` vs `--file/--include-deps/--include-tests`).

**Decisão:** manter. Adicionar "Veja também" nos dois `--help`. Uma biblioteca comum de detecção de projeto pode ser extraída quando os dois precisarem da mesma heurística nova.

### P1-06 — biblioteca compartilhada de conversão: não extrair agora

**Evidência:** os conversores compartilham descoberta de arquivos, nome de saída, `--dry-run` e `--overwrite`, mas os toolchains divergem (`pandoc`, `pdftotext`+OCR, `pdftoppm`, `openpyxl`, `awk` para RIS). A parte realmente comum é pequena e já está duplicada de forma legível.

**Decisão:** não criar `convert-helper.sh` nesta rodada. A regra do AGENTS.md ("um script por ferramenta") e o SIMPLIFY do kata desaconselham uma abstração com cinco implementações divergentes. Documentar a convenção no `SCRIPTING_GUIDE.md` é suficiente por enquanto.

**Critério para revisitar:** um sexto conversor ou uma correção que precise ser aplicada em três conversores ao mesmo tempo.

---

## 3. Verificação

```bash
./dogu doctor
# ✅ Python, Manifesto, Arquivos, Menu, README, SKILL.md, Metadados, Contadores
# ✅ 105/105

./dogu doctor --json | jq '.ok'
# true

./dogu completion bash > /tmp/dogu.bash && bash -n /tmp/dogu.bash
./dogu completion zsh  > /tmp/_dogu   && zsh -n  /tmp/_dogu

./archive-manager.sh --unpack --dry-run /tmp/exemplo
# delega para unarchive.sh

python -m kata --check-only
# shellcheck, bash -n e coverage 100%
```

---

## 4. O que ficou para depois

- Unificação real de `quick-backup`/`folder-sync` e `hunt-duplicates`/`dedup-files` — só com um plano de compatibilidade e aliases.
- Biblioteca de conversão — só com um sexto consumidor ou correção triplicada.
- Um agregador `docker-doctor` (P2) para status + healthcheck + audit + CIS + bottleneck.
- Os scripts novos de P2 (`video-to-text`, `pdf-split`/`pdf-merge`, `image-optimizer`, `ssl-cert-check` etc.).
