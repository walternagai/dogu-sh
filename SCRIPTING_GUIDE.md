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

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "dep" "$INSTALLER pacote"; fi

# ... variáveis de cor, constantes, lógica ...
```

### Regras do boilerplate

| Elemento | Regra |
|---|---|
| **Shebang** | Sempre `#!/bin/bash` |
| **Header** | Descrição, uso e opções nas primeiras linhas (comentário) |
| **set** | Sempre `set -eo pipefail` — aborta em erro e falha de pipe |
| **VERSION** | Variável obrigatória: `VERSION="1.0.0"` |
| **DEP_HELPER** | Sempre importar `dependency-helper.sh` quando o script depende de ferramentas externas |

---

## 2. Dependency Helper

Scripts que dependem de ferramentas externas (Docker, curl, jq, fzf, etc.) **devem** usar o `dependency-helper.sh`:

```bash
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "tool" "$INSTALLER pacote"; fi
```

- O fallback para `$HOME/.local/bin` garante funcionamento após instalação.
- A chamada `check_and_install` verifica se a ferramenta existe e oferece instalação automática.
- Para scripts com múltiplas dependências, encadear as chamadas:

```bash
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "docker" "$INSTALLER docker.io"
    check_and_install "jq" "$INSTALLER jq"
fi
```

---

## 3. Paleta de Cores e Formatação

Usar **sempre** estas variáveis para qualquer saída colorida:

```bash
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'
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

```bash
log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
```

---

## 4. Ícones e Separadores Visuais

Para manter a identidade visual consistente entre os scripts:

| Ícone | Uso |
|---|---|
| `✓` | Operação bem-sucedida |
| `✗` | Operação falhou |
| `▶` | Iniciando execução / rodando |
| `────` | Separador de seções (usar `${DIM}`) |
| `━━━` | Separador de cabeçalho principal (usar `${CYAN}`) |
| `▲` / `▼` | Indicadores de scroll em menus |

Exemplo de separador:

```bash
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
```

---

## 5. Tratamento de Argumentos

Usar **sempre** loop `while` com `case` para parsing de flags:

```bash
while [ $# -gt 0 ]; do
    case "$1" in
        --flag|-f) VARIAVEL="$2"; shift 2 ;;
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
            echo "    --help          Mostra esta ajuda"
            echo "    --version       Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-v) echo "nome-do-script.sh $VERSION"; exit 0 ;;
        *)
            echo -e "${RED}Opcao desconhecida: $1${RESET}"
            exit 1
            ;;
    esac
done
```

### Regras

- Toda flag longa deve ter uma versão curta quando fizer sentido (`--help|-h`, `--version|-v`).
- `--help` imprime o bloco formatado com espaçamento consistente (linha em branco antes/depois).
- `--version` imprime no formato `nome-do-script.sh $VERSION`.
- Flags desconhecidas geram erro com `${RED}` e `exit 1`.

---

## 6. Interatividade e Prompts

### Confirmações

Sempre usar formato `[s/N]` (padrão = não):

```bash
read -p "Confirmar operacao? [s/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo -e "${DIM}Operacao cancelada.${RESET}"
    exit 0
fi
```

### Seleção com fzf

Para scripts que listam itens selecionáveis, usar `fzf` com fallback:

```bash
if ! command -v fzf &>/dev/null; then
    echo -e "${RED}Erro: fzf e necessario.${RESET}"
    exit 1
fi

SELECTED=$(comando_que_lista | fzf --prompt="Selecionar > ")
```

- Quando `fzf` for essencial, exigir e abortar se ausente.
- Quando `fzf` for opcional, oferecer menu numérico como fallback (ver `menu-launcher.sh`).

---

## 7. Sinais de Processo

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

## 8. Idioma e Nomenclatura

| Elemento | Idioma |
|---|---|
| Mensagens ao usuário | **Português** |
| Nomes de variáveis | **Inglês** (snake_case) |
| Nomes de funções | **Inglês** (snake_case) |
| Nomes de arquivos | **Inglês** com sufixo `.sh` (ex: `docker-status.sh`) |
| Comentários no código | **Português** quando explicam lógica; omisso quando o código é autoexplicativo |
| Header do script | **Português** (descrição, uso, opções) |

---

## 9. Portabilidade e Caminhos

- Nunca usar caminhos absolutos fixos (exceto `/var/log`, `/etc` quando necessário).
- Preferir `$HOME` em vez de `/home/usuario`.
- Detectar gerenciador de pacotes via `detect_installer` do `dependency-helper.sh`.
- Não assumir que um diretório existe — sempre verificar com `[ -d ]` ou criar com `mkdir -p`.

---

## 10. Backup e Segurança

- Antes de edit arquivos de configuração (`.bashrc`, `.zshrc`, etc.), **sempre** criar backup:

```bash
cp "$SHELL_RC" "${SHELL_RC}.bak"
```

- Nunca commitar segredos, tokens ou credenciais nos scripts.
- Scripts que lidam com senhas/chaves devem usar `read -s` para entrada oculta:

```bash
read -s -p "Senha: " PASSWORD
```

---

## 11. --dry-run

Scripts que fazem alterações no sistema (remover, mover, instalar) **devem** suportar `--dry-run`:

```bash
DRY_RUN=false
# no parsing de args:
--dry-run) DRY_RUN=true; shift ;;

# na execução:
if [ "$DRY_RUN" = false ]; then
    rm "$file"
    log "  ✓ Removido: $file"
else
    echo "  [Dry-run] rm $file"
fi
```

---

## 12. Checklist para Novos Scripts

Antes de considerar um script pronto, verificar:

- [ ] Header com descrição, uso e opções
- [ ] `set -eo pipefail`
- [ ] `VERSION` definida
- [ ] `dependency-helper.sh` importado quando necessário
- [ ] Paleta de cores padronizada
- [ ] `--help` e `--version` implementados
- [ ] Argumentos via `while/case`
- [ ] Confirmações no formato `[s/N]`
- [ ] SIGTERM antes de SIGKILL
- [ ] `--dry-run` quando aplicável
- [ ] Backup de config antes de edição
- [ ] Mensagens em português
- [ ] Registrado no `menu-launcher.sh` (SCRIPT_DESC e SCRIPT_CATEGORY)
- [ ] Permissão de execução (`chmod +x`)
- [ ] listado na tabela de dependências do `README.md`