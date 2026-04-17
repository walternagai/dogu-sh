# Guia de Boas Práticas — dogu-sh

Referência para criação e manutenção de scripts do kit dogu-sh.

---

## 1. Estrutura Obrigatória (Boilerplate)

Todo script deve seguir este esquema na ordem abaixo:

```bash
#!/bin/bash
# nome-do-script.sh — Descrição curta em português (Linux)
# Uso: ./nome-do-script.sh [opcoes]
# Opcoes:
#   --flag          Descricao da flag
#   --help          Mostra esta ajuda
#   --version       Mostra versao

set -euo pipefail

readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "dep" "$INSTALLER" "pacote"
fi

# ... variáveis de cor, constantes, lógica ...
```

### Regras do boilerplate

| Elemento | Regra |
|---|---|
| **Shebang** | Sempre `#!/bin/bash` |
| **Header** | Descrição, uso e opções nas primeiras linhas (comentário) |
| **set** | Sempre `set -euo pipefail` — aborta em erro, pipe e variável indefinida |
| **VERSION** | Variável obrigatória: `readonly VERSION="1.0.0"` |
| **SCRIPT_DIR** | Sempre definir para permitir referências a arquivos relativos ao script |
| **DEP_HELPER** | Sempre importar `dependency-helper.sh` quando o script depende de ferramentas externas |

---

## 2. Dependency Helper

Scripts que dependem de ferramentas externas (Docker, curl, jq, fzf, etc.) **devem** usar o `dependency-helper.sh`.

A assinatura de `check_and_install` é: `check_and_install "nome-binário" "instalador" "pacote"`.

```bash
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "tool" "$INSTALLER" "pacote"
fi
```

- O fallback para `$HOME/.local/bin` garante funcionamento após instalação.
- A chamada `check_and_install` verifica se a ferramenta existe e oferece instalação automática.
- Para scripts com múltiplas dependências, encadear as chamadas:

```bash
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "docker" "$INSTALLER" "docker.io"
    check_and_install "jq"     "$INSTALLER" "jq"
fi
```

---

## 3. Paleta de Cores e Formatação

Usar **sempre** estas variáveis para qualquer saída colorida. Declará-las como `readonly`:

```bash
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'
```

### Uso semântico

| Cor | Uso |
|---|---|
| `GREEN` | Sucesso, confirmação, status OK |
| `YELLOW` | Avisos, alertas não críticos, prompts |
| `RED` | Erros, falhas, condições críticas |
| `CYAN` | Títulos, cabeçalhos, informações neutras |
| `BLUE` | Destaque secundário (ex: níveis DEBUG) |
| `BOLD` | Ênfase em texto importante |
| `DIM` | Texto secundário, dicas, metadados |
| `RESET` | **Sempre** fechar qualquer sequência de cor |

### Funções de log recomendadas

`warn` e `error` escrevem em `stderr` (`>&2`) para não poluir pipes e redirecionamentos.

```bash
log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
```

---

## 4. Ícones e Separadores Visuais

Para manter a identidade visual consistente entre os scripts:

| Ícone | Uso |
|---|---|
| `✓` | Operação bem-sucedida |
| `✗` | Operação falhou |
| `▶` | Iniciando execução / rodando |
| `────` | Separador interno de seções (usar `${DIM}`) |
| `━━━` | Separador de cabeçalho principal (usar `${CYAN}`) |
| `▲` / `▼` | Indicadores de scroll em menus |

Exemplos:

```bash
# Cabeçalho principal
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"

# Separador interno de seções
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
```

---

## 5. Tratamento de Argumentos

Usar **sempre** loop `while` com `case` para parsing de flags. Preferir `[[ ]]` a `[ ]` em condicionais bash.

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --flag|-f)
            [[ -z "${2-}" ]] && error "Flag --flag requer um valor"
            VARIAVEL="$2"; shift 2 ;;
        --bool|-b) BOOLEAN=true; shift ;;
        --help|-h)
            echo ""
            echo "  nome-do-script.sh — Descrição curta"
            echo ""
            echo "  Uso: ./nome-do-script.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --flag|-f VAL   Descricao da flag"
            echo "    --bool|-b       Descricao da flag booleana"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "nome-do-script.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
    esac
done
```

### Regras

- Toda flag longa deve ter uma versão curta quando fizer sentido (`--help|-h`).
- Usar `-V` (maiúsculo) para `--version` — reserva `-v` para `--verbose` quando necessário.
- `--help` imprime o bloco formatado com espaçamento consistente (linha em branco antes/depois).
- `--version` imprime no formato `nome-do-script.sh $VERSION`.
- `--` encerra o parsing; argumentos seguintes são tratados como posicionais.
- Flags com valor obrigatório devem validar que `$2` existe antes de fazer `shift 2`.
- Flags desconhecidas geram erro com `${RED}`, saída para `stderr`, e `exit 2`.

---

## 6. Interatividade e Prompts

### Confirmações

Sempre usar formato `[s/N]` (padrão = não). Usar `read -r` para não interpretar backslashes:

```bash
read -r -p "Confirmar operacao? [s/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo -e "${DIM}Operacao cancelada.${RESET}"
    exit 0
fi
```

### Seleção com fzf

Para scripts que listam itens selecionáveis, usar `fzf` com fallback:

```bash
if ! command -v fzf &>/dev/null; then
    echo -e "${RED}Erro: fzf e necessario.${RESET}" >&2
    exit 1
fi

SELECTED=$(comando_que_lista | fzf --prompt="Selecionar > ")
```

- Quando `fzf` for essencial, exigir e abortar se ausente.
- Quando `fzf` for opcional, oferecer menu numérico como fallback (ver `menu-launcher.sh`).

---

## 7. Arquivos Temporários e Limpeza

Scripts que criam arquivos temporários **devem** usar `mktemp` e garantir limpeza via `trap`:

```bash
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

# a partir daqui, $TMPFILE é removido automaticamente ao sair (sucesso, erro ou SIGINT)
```

Para múltiplos temporários ou diretório temporário:

```bash
TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT
```

- `trap ... EXIT` cobre saída normal, `exit N`, e sinais que terminam o processo.
- Nunca criar arquivos temporários em caminhos fixos como `/tmp/meu-script.tmp` — há risco de colisão entre execuções paralelas.

---

## 8. Sinais de Processo

Para terminação de processos, **sempre** preferir `SIGTERM` antes de `SIGKILL`:

```bash
# Correto: terminação gracosa
kill -TERM "$PID" 2>/dev/null

# Evitar: terminação forçada (apenas como último recurso)
kill -9 "$PID" 2>/dev/null
```

- O script pode aceitar `--signal` para permitir que o usuário escolha.
- Ao lidar com múltiplos PIDs (ex: saída de `lsof -t`), iterar sobre cada um.

---

## 9. Funções — Boas Práticas

- Sempre declarar variáveis internas com `local` para evitar vazamento de escopo:

```bash
my_function() {
    local input="$1"
    local result
    result=$(some_command "$input")
    echo "$result"
}
```

- Preferir `$()` a backticks `` ` ` `` para substituição de comando — mais legível e aninhável.
- Usar `[[ ]]` em vez de `[ ]` para condicionais — evita word-splitting e não exige aspas em comparações simples.

---

## 10. Exit Codes

Usar códigos de saída padronizados:

| Código | Significado |
|---|---|
| `0` | Sucesso |
| `1` | Erro geral / falha de execução |
| `2` | Uso incorreto de flags ou argumentos |
| `127` | Dependência não encontrada |
| `130` | Interrompido pelo usuário (`Ctrl+C` / SIGINT) |

---

## 11. Idioma e Nomenclatura

| Elemento | Idioma |
|---|---|
| Mensagens ao usuário | **Português** |
| Nomes de variáveis | **Inglês** (snake_case) |
| Nomes de funções | **Inglês** (snake_case) |
| Nomes de arquivos | **Inglês** com sufixo `.sh` (ex: `docker-status.sh`) |
| Comentários no código | **Português** quando explicam lógica; omisso quando o código é autoexplicativo |
| Header do script | **Português** (descrição, uso, opções) |

---

## 12. Portabilidade e Caminhos

- Nunca usar caminhos absolutos fixos (exceto `/var/log`, `/etc` quando necessário).
- Preferir `$HOME` em vez de `/home/usuario`.
- Usar `$SCRIPT_DIR` para referenciar arquivos no mesmo diretório do script.
- Detectar gerenciador de pacotes via `detect_installer` do `dependency-helper.sh`.
- Não assumir que um diretório existe — sempre verificar com `[ -d ]` ou criar com `mkdir -p`.

---

## 13. Backup e Segurança

- Antes de editar arquivos de configuração (`.bashrc`, `.zshrc`, etc.), **sempre** criar backup:

```bash
cp "$SHELL_RC" "${SHELL_RC}.bak"
```

- Nunca commitar segredos, tokens ou credenciais nos scripts.
- Scripts que lidam com senhas/chaves devem usar `read -r -s` para entrada oculta:

```bash
read -r -s -p "Senha: " PASSWORD
echo ""
```

---

## 14. --dry-run

Scripts que fazem alterações no sistema (remover, mover, instalar) **devem** suportar `--dry-run`:

```bash
DRY_RUN=false
# no parsing de args:
--dry-run) DRY_RUN=true; shift ;;

# na execução:
if [[ "$DRY_RUN" == false ]]; then
    rm "$file"
    log "  ✓ Removido: $file"
else
    echo "  [Dry-run] rm $file"
fi
```

---

## 15. Checklist para Novos Scripts

Antes de considerar um script pronto, verificar:

- [ ] Header com descrição, uso e opções
- [ ] `set -euo pipefail`
- [ ] `readonly VERSION` definida
- [ ] `SCRIPT_DIR` definido
- [ ] `dependency-helper.sh` importado quando necessário
- [ ] Paleta de cores padronizada com `readonly`
- [ ] Funções `log`, `warn`, `error`, `success` definidas (`warn`/`error` escrevem em stderr)
- [ ] `--help` e `--version` implementados (`-V` para version)
- [ ] Argumentos via `while/case` com validação de valor obrigatório e tratamento de `--`
- [ ] Confirmações no formato `[s/N]` com `read -r`
- [ ] `trap` + `mktemp` para arquivos temporários
- [ ] SIGTERM antes de SIGKILL
- [ ] Exit codes padronizados (0/1/2/127/130)
- [ ] `--dry-run` quando aplicável
- [ ] Backup de config antes de edição
- [ ] Mensagens em português
- [ ] Registrado no `menu-launcher.sh` (SCRIPT_DESC e SCRIPT_CATEGORY)
- [ ] Permissão de execução (`chmod +x`)
- [ ] Listado na tabela de dependências do `README.md`
