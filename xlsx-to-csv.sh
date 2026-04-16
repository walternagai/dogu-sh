#!/bin/bash
# xlsx-to-csv.sh — Converte arquivos .xlsx para CSV, extraindo cada aba em arquivo separado (Linux)
# Uso: ./xlsx-to-csv.sh [opcoes] ARQUIVO.xlsx [ARQUIVO2.xlsx ...]
# Opcoes:
#   -o, --output DIR        Diretorio de saida (padrao: mesmo diretorio do arquivo)
#   -r, --recursive         Converte todos os .xlsx em um diretorio recursivamente
#   -d, --delimiter CHAR    Separador dos campos CSV (padrao: ,)
#   -S, --sheet NOME        Extrai apenas a aba com este nome
#       --always-suffix     Usa sufixo de aba mesmo em arquivos com uma unica aba
#       --overwrite         Sobrescreve arquivos .csv existentes sem perguntar
#       --dry-run           Exibe o que seria feito sem converter
#   -h, --help              Mostra esta ajuda
#   -v, --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1"; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

show_help() {
    echo ""
    echo "  xlsx-to-csv.sh — Converte arquivos .xlsx para CSV"
    echo ""
    echo "  Uso: ./xlsx-to-csv.sh [opcoes] ARQUIVO.xlsx [ARQUIVO2.xlsx ...]"
    echo "       ./xlsx-to-csv.sh -r [opcoes] DIRETORIO"
    echo ""
    echo "  Opcoes:"
    echo "    -o, --output DIR       Diretorio de saida (padrao: mesmo diretorio do .xlsx)"
    echo "    -r, --recursive        Converte todos os .xlsx em um diretorio"
    echo "    -d, --delimiter CHAR   Separador CSV (padrao: , )"
    echo "    -S, --sheet NOME       Extrai apenas a aba especificada"
    echo "        --always-suffix    Usa sufixo _-aba.csv mesmo com uma unica aba"
    echo "        --overwrite        Sobrescreve .csv existentes sem perguntar"
    echo "        --dry-run          Simula conversao sem gravar arquivos"
    echo "    -h, --help             Mostra esta ajuda"
    echo "    -v, --version          Mostra versao"
    echo ""
    echo "  Nomeacao dos arquivos de saida:"
    echo "    - 1 aba:       nome_arquivo.csv"
    echo "    - Multiplas:   nome_arquivo_-NomeDaAba.csv"
    echo "    - --always-suffix: sempre nome_arquivo_-NomeDaAba.csv"
    echo ""
    echo "  Exemplos:"
    echo "    ./xlsx-to-csv.sh planilha.xlsx"
    echo "    ./xlsx-to-csv.sh -o ~/saida relatorio.xlsx orcamento.xlsx"
    echo "    ./xlsx-to-csv.sh -r ./pasta-planilhas"
    echo "    ./xlsx-to-csv.sh -d ';' planilha.xlsx"
    echo "    ./xlsx-to-csv.sh -S 'Vendas' relatorio.xlsx"
    echo "    ./xlsx-to-csv.sh --dry-run -r ."
    echo ""
}

# --- flags rapidas (antes da checagem de dependencias) ---
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "xlsx-to-csv.sh $VERSION"; exit 0 ;;
    esac
done

# --- verificacao de python3 ---
if ! command -v python3 &>/dev/null; then
    echo -e "${RED}[ERROR]${RESET} python3 nao encontrado." >&2
    echo -e "  ${DIM}Instale com: sudo apt install python3${RESET}" >&2
    exit 1
fi

# --- verificacao de openpyxl ---
if ! python3 -c "import openpyxl" 2>/dev/null; then
    echo -e "${YELLOW}[WARN]${RESET} Modulo Python 'openpyxl' nao encontrado."
    read -p "  Deseja instalar agora via pip? [s/N] " _choice < /dev/tty
    if [[ "$_choice" =~ ^[Ss]$ ]]; then
        echo -e "${CYAN}[INFO]${RESET} Instalando openpyxl..."
        if python3 -m pip install --quiet openpyxl; then
            success "openpyxl instalado com sucesso."
        else
            echo -e "${RED}[ERROR]${RESET} Falha ao instalar openpyxl." >&2
            echo -e "  ${DIM}Tente manualmente: pip install openpyxl${RESET}" >&2
            exit 1
        fi
    else
        echo -e "${RED}[ERROR]${RESET} O script requer 'openpyxl' para funcionar." >&2
        exit 1
    fi
fi

# --- variaveis ---
OUTPUT_DIR=""
RECURSIVE=false
DRY_RUN=false
OVERWRITE=false
ALWAYS_SUFFIX=false
DELIMITER=","
SHEET_FILTER=""
INPUT_FILES=()

# --- parsing de argumentos ---
while [ $# -gt 0 ]; do
    case "$1" in
        -o|--output)
            [ -z "$2" ] && error "Flag --output requer um diretorio como argumento."
            OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive)
            RECURSIVE=true; shift ;;
        -d|--delimiter)
            [ -z "$2" ] && error "Flag --delimiter requer um caractere como argumento."
            DELIMITER="$2"; shift 2 ;;
        -S|--sheet)
            [ -z "$2" ] && error "Flag --sheet requer o nome da aba como argumento."
            SHEET_FILTER="$2"; shift 2 ;;
        --always-suffix)
            ALWAYS_SUFFIX=true; shift ;;
        --overwrite)
            OVERWRITE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        -v|--version) echo "xlsx-to-csv.sh $VERSION"; exit 0 ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 1
            ;;
        *)
            INPUT_FILES+=("$1"); shift ;;
    esac
done

# --- coleta arquivos em modo recursivo ---
if [ "$RECURSIVE" = true ]; then
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        SEARCH_DIR="."
    else
        SEARCH_DIR="${INPUT_FILES[0]}"
        INPUT_FILES=()
    fi
    [ ! -d "$SEARCH_DIR" ] && error "Diretorio nao encontrado: $SEARCH_DIR"
    while IFS= read -r -d '' f; do
        INPUT_FILES+=("$f")
    done < <(find "$SEARCH_DIR" -type f -iname "*.xlsx" -print0)
    if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
        warn "Nenhum arquivo .xlsx encontrado em: $SEARCH_DIR"
        exit 0
    fi
fi

# --- validacao de entrada ---
if [ "${#INPUT_FILES[@]}" -eq 0 ]; then
    echo -e "${RED}Erro: nenhum arquivo .xlsx informado.${RESET}" >&2
    echo -e "  ${DIM}Use --help para ver o uso.${RESET}" >&2
    exit 1
fi

# --- validacao do diretorio de saida ---
if [ -n "$OUTPUT_DIR" ]; then
    if [ ! -d "$OUTPUT_DIR" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$OUTPUT_DIR"
            log "Diretorio de saida criado: $OUTPUT_DIR"
        else
            log "[Dry-run] Criaria diretorio: $OUTPUT_DIR"
        fi
    fi
fi

# --- contadores ---
CONVERTED=0
SKIPPED=0
ERRORS=0

# --- cabecalho ---
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}  xlsx-to-csv.sh${RESET}  ${DIM}v$VERSION${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
[ "$DRY_RUN"      = true ] && echo -e "  ${YELLOW}[Dry-run ativado — nenhum arquivo sera gravado]${RESET}"
[ -n "$SHEET_FILTER"     ] && echo -e "  ${DIM}Filtro de aba: ${BOLD}$SHEET_FILTER${RESET}"
[ "$DELIMITER"   != ","  ] && echo -e "  ${DIM}Delimitador: ${BOLD}$DELIMITER${RESET}"
echo -e "  ${DIM}Arquivos encontrados: ${#INPUT_FILES[@]}${RESET}"
echo ""

# --- funcao: sanitiza nome de aba para uso em nome de arquivo ---
sanitize_sheet_name() {
    local name="$1"
    # substitui espacos e barras por underscore, remove caracteres especiais
    echo "$name" \
        | tr ' /\\:*?"<>|' '_____________' \
        | sed 's/__\+/_/g; s/^_//; s/_$//'
}

# --- funcao principal de conversao ---
convert_file() {
    local input="$1"

    if [ ! -f "$input" ]; then
        warn "Arquivo nao encontrado, ignorando: $input"
        (( ERRORS++ )) || true
        return
    fi

    local ext="${input##*.}"
    if [[ "${ext,,}" != "xlsx" ]]; then
        warn "Arquivo ignorado (nao e .xlsx): $input"
        (( SKIPPED++ )) || true
        return
    fi

    local base_name
    base_name=$(basename "$input")
    base_name="${base_name%.[xX][lL][sS][xX]}"

    local dest_dir
    if [ -n "$OUTPUT_DIR" ]; then
        dest_dir="$OUTPUT_DIR"
    else
        dest_dir=$(dirname "$input")
    fi

    # usa python3 para inspecionar abas e converter
    local py_output
    py_output=$(python3 - "$input" "$dest_dir" "$base_name" "$DELIMITER" \
                          "$SHEET_FILTER" "$ALWAYS_SUFFIX" "$DRY_RUN" "$OVERWRITE" <<'PYEOF'
import sys
import os
import csv
import re

xlsx_path    = sys.argv[1]
dest_dir     = sys.argv[2]
base_name    = sys.argv[3]
delimiter    = sys.argv[4]
sheet_filter = sys.argv[5]   # "" = todas as abas
always_sfx   = sys.argv[6] == "true"
dry_run      = sys.argv[7] == "true"
overwrite    = sys.argv[8] == "true"

try:
    import openpyxl
except ImportError:
    print("ERR:openpyxl nao encontrado")
    sys.exit(1)

try:
    wb = openpyxl.load_workbook(xlsx_path, read_only=True, data_only=True)
except Exception as e:
    print(f"ERR:{e}")
    sys.exit(1)

sheet_names = wb.sheetnames
multi_sheet = (len(sheet_names) > 1) or always_sfx

# filtra aba especifica, se solicitado
if sheet_filter:
    if sheet_filter not in sheet_names:
        available = ", ".join(sheet_names)
        print(f"ERR:Aba '{sheet_filter}' nao encontrada. Abas disponiveis: {available}")
        sys.exit(1)
    sheets_to_export = [sheet_filter]
    multi_sheet = False   # com filtro, sempre saida simples
else:
    sheets_to_export = sheet_names

results = []

for sheet_name in sheets_to_export:
    ws = wb[sheet_name]

    # sanitiza nome da aba para o nome de arquivo
    safe_sheet = re.sub(r'[ /\\:*?"<>|]+', '_', sheet_name)
    safe_sheet = re.sub(r'_+', '_', safe_sheet).strip('_')

    if multi_sheet:
        out_filename = f"{base_name}_-{safe_sheet}.csv"
    else:
        out_filename = f"{base_name}.csv"

    out_path = os.path.join(dest_dir, out_filename)

    if os.path.exists(out_path) and not overwrite and not dry_run:
        results.append(f"SKIP:{sheet_name}:{out_path}")
        continue

    if dry_run:
        results.append(f"DRY:{sheet_name}:{out_path}")
        continue

    try:
        with open(out_path, "w", newline="", encoding="utf-8") as fh:
            writer = csv.writer(fh, delimiter=delimiter)
            for row in ws.iter_rows(values_only=True):
                # converte None para string vazia
                writer.writerow(["" if v is None else str(v) for v in row])
        results.append(f"OK:{sheet_name}:{out_path}")
    except Exception as e:
        results.append(f"ERR:{sheet_name}:{e}")

wb.close()
print("\n".join(results))
PYEOF
    ) || true

    # processa saida do python
    if [ -z "$py_output" ]; then
        echo -e "  ${RED}✗${RESET} Falha inesperada ao processar: $(basename "$input")"
        (( ERRORS++ )) || true
        return
    fi

    while IFS= read -r line; do
        local status="${line%%:*}"
        local rest="${line#*:}"
        local sheet_name="${rest%%:*}"
        local out_path="${rest#*:}"

        case "$status" in
            OK)
                echo -e "  ${GREEN}✓${RESET} ${DIM}$(basename "$input")${RESET}  ${DIM}[${sheet_name}]${RESET}  →  ${BOLD}$(basename "$out_path")${RESET}"
                (( CONVERTED++ )) || true
                ;;
            DRY)
                echo -e "  ${BLUE}▶${RESET} [Dry-run] ${DIM}$(basename "$input")${RESET}  ${DIM}[${sheet_name}]${RESET}  →  ${BOLD}$(basename "$out_path")${RESET}"
                (( CONVERTED++ )) || true
                ;;
            SKIP)
                warn "Ja existe, pulando (use --overwrite): $(basename "$out_path")"
                (( SKIPPED++ )) || true
                ;;
            ERR)
                if [[ "$sheet_name" == openpyxl* ]] || [[ "$out_path" == *"nao encontrada"* ]]; then
                    echo -e "  ${RED}✗${RESET} Erro em $(basename "$input"): $rest"
                else
                    echo -e "  ${RED}✗${RESET} Erro na aba '${sheet_name}' de $(basename "$input"): $out_path"
                fi
                (( ERRORS++ )) || true
                ;;
        esac
    done <<< "$py_output"
}

# --- loop principal ---
for file in "${INPUT_FILES[@]}"; do
    convert_file "$file"
done

# --- resumo ---
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
if [ "$DRY_RUN" = true ]; then
    echo -e "  ${YELLOW}[Dry-run]${RESET} Seriam gerados: ${BOLD}$CONVERTED${RESET} arquivo(s) CSV"
else
    echo -e "  ${GREEN}✓ Gerados:${RESET}   ${BOLD}$CONVERTED${RESET} arquivo(s) CSV"
fi
[ "$SKIPPED" -gt 0 ] && echo -e "  ${YELLOW}▶ Ignorados:${RESET} ${BOLD}$SKIPPED${RESET}"
[ "$ERRORS"  -gt 0 ] && echo -e "  ${RED}✗ Erros:${RESET}     ${BOLD}$ERRORS${RESET}"
echo ""

[ "$ERRORS" -gt 0 ] && exit 1
exit 0
