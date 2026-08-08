#!/bin/bash
# ris-to-csv.sh — Converte arquivos .ris (citacoes bibliograficas) para CSV (Linux)
# Uso: ./ris-to-csv.sh [opcoes] ARQUIVO.ris [ARQUIVO2.ris ...]
# Opcoes:
#   -o, --output DIR       Diretorio de saida (padrao: mesmo diretorio do arquivo)
#   -r, --recursive        Converte todos os .ris em um diretorio recursivamente
#   -m, --merge            Combina todos os arquivos num unico CSV (com -r ou varios arquivos)
#   -d, --delimiter CHAR   Separador dos campos CSV (padrao: ,)
#   -f, --fields LISTA     Campos (tags RIS) a exportar, separados por virgula
#                          (ex: TY,AU,TI,PY,DO) — usa nomes das tags como colunas
#   -a, --all-fields       Exporta todas as tags encontradas (colunas dinamicas)
#   -j, --join SEP         Separador para valores multiplas (padrao: "; ")
#       --no-header        Nao escreve a linha de cabecalho
#       --overwrite        Sobrescreve arquivos .csv existentes sem perguntar
#       --dry-run          Exibe o que seria feito sem converter
#   -h, --help             Mostra esta ajuda
#   -V, --version          Mostra versao

set -euo pipefail

readonly VERSION="1.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }

show_help() {
    echo ""
    echo "  ris-to-csv.sh — Converte arquivos .ris para CSV"
    echo ""
    echo "  Uso: ./ris-to-csv.sh [opcoes] ARQUIVO.ris [ARQUIVO2.ris ...]"
    echo "       ./ris-to-csv.sh -r [opcoes] DIRETORIO"
    echo ""
    echo "  Opcoes:"
    echo "    -o, --output DIR      Diretorio de saida (padrao: mesmo diretorio do .ris)"
    echo "    -r, --recursive       Converte todos os .ris em um diretorio"
    echo "    -m, --merge           Combina todos os arquivos num unico CSV"
    echo "                          (use com -r ou com varios arquivos)"
    echo "    -d, --delimiter CHAR  Separador CSV (padrao: , )"
    echo "    -f, --fields LISTA    Tags RIS a exportar, separadas por virgula"
    echo "                          (ex: TY,AU,TI,PY,DO,UR)"
    echo "    -a, --all-fields      Exporta todas as tags encontradas (colunas dinamicas)"
    echo "    -j, --join SEP        Separador para campos com varios valores (padrao: \"; \")"
    echo "        --no-header       Suprime a linha de cabecalho do CSV"
    echo "        --overwrite      Sobrescreve .csv existentes sem perguntar"
    echo "        --dry-run         Simula conversao sem gravar arquivos"
    echo "    -h, --help            Mostra esta ajuda"
    echo "    -V, --version         Mostra versao"
    echo ""
    echo "  Modo --merge:"
    echo "    Combina todos os registros de todos os arquivos .ris num unico CSV,"
    echo "    com um unico cabecalho. Combinavel com -r, --all-fields e --fields."
    echo "    Saida padrao: merged.csv no diretorio atual."
    echo "    Use -o ARQUIVO.csv para nomear a saida, ou -o DIR para merged.csv em DIR."
    echo ""
    echo "  Colunas padrao (modo default):"
    echo "    Type, Authors, Title, SecondaryTitle, Year, Date, Journal,"
    echo "    JournalFull, Volume, Issue, StartPage, EndPage, Abstract,"
    echo "    Keywords, DOI, URL, Publisher, City, ISSN, Language,"
    echo "    Edition, Notes, SecondaryAuthors"
    echo ""
    echo "  Notas:"
    echo "    - Tags multiplas (AU, KW, etc.) sao unidas com o separador --join."
    echo "    - Use --all-fields para descobrir todas as tags presentes no arquivo."
    echo "    - Use --fields para selecionar colunas especificas por tag RIS."
    echo "    - Valores que contem o separador, aspas ou quebras de linha sao"
    echo "      cercados por aspas duplas (padrao RFC 4180)."
    echo ""
    echo "  Exemplos:"
    echo "    ./ris-to-csv.sh referencias.ris"
    echo "    ./ris-to-csv.sh -o ~/saida refs1.ris refs2.ris"
    echo "    ./ris-to-csv.sh -r ./pasta-refs"
    echo "    ./ris-to-csv.sh -m -r ./pasta-refs -o todas_referencias.csv"
    echo "    ./ris-to-csv.sh -m -r ./pasta-refs --all-fields"
    echo "    ./ris-to-csv.sh -m refs1.ris refs2.ris refs3.ris"
    echo "    ./ris-to-csv.sh -d ';' -j ' | ' referencias.ris"
    echo "    ./ris-to-csv.sh -f TY,AU,TI,PY,DO referencias.ris"
    echo "    ./ris-to-csv.sh --all-fields --dry-run -r ."
    echo ""
}

# --- flags rapidas (antes da checagem de dependencias) ---
for _arg in "$@"; do
    case "$_arg" in
        -h|--help)    show_help; exit 0 ;;
        -V|--version) echo "ris-to-csv.sh $VERSION"; exit 0 ;;
    esac
done

# --- verificacao de awk (ferramenta core, sem dep-helper) ---
if ! command -v awk &>/dev/null; then
    error "awk nao encontrado. Instale com: sudo apt install gawk"
fi

# --- arquivos temporarios ---
TMP_CSV=$(mktemp)
TMP_ERR=$(mktemp)
trap 'rm -f "$TMP_CSV" "$TMP_ERR"' EXIT

# --- variaveis ---
OUTPUT_DIR=""
RECURSIVE=false
MERGE=false
DRY_RUN=false
OVERWRITE=false
ALL_FIELDS=false
NO_HEADER=false
DELIMITER=","
JOIN_SEP="; "
FIELDS_OPT=""
INPUT_FILES=()

# --- parsing de argumentos ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output)
            [[ -z "${2-}" ]] && error "Flag --output requer um diretorio como argumento."
            OUTPUT_DIR="$2"; shift 2 ;;
        -r|--recursive)
            RECURSIVE=true; shift ;;
        -m|--merge)
            MERGE=true; shift ;;
        -d|--delimiter)
            [[ -z "${2-}" ]] && error "Flag --delimiter requer um caractere como argumento."
            DELIMITER="$2"; shift 2 ;;
        -f|--fields)
            [[ -z "${2-}" ]] && error "Flag --fields requer uma lista de tags como argumento."
            FIELDS_OPT="$2"; shift 2 ;;
        -a|--all-fields)
            ALL_FIELDS=true; shift ;;
        -j|--join)
            [[ -z "${2-}" ]] && error "Flag --join requer um separador como argumento."
            JOIN_SEP="$2"; shift 2 ;;
        --no-header)
            NO_HEADER=true; shift ;;
        --overwrite)
            OVERWRITE=true; shift ;;
        --dry-run)
            DRY_RUN=true; shift ;;
        -h|--help)    show_help; exit 0 ;;
        -V|--version) echo "ris-to-csv.sh $VERSION"; exit 0 ;;
        --) shift; INPUT_FILES+=("$@"); break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            INPUT_FILES+=("$1"); shift ;;
    esac
done

# --- normaliza delimitador tab ---
[[ "$DELIMITER" == '\t' ]] && DELIMITER=$'\t'

# --- normaliza lista de campos (uppercase, espacos -> virgula -> espaco) ---
FIELDS_NORM=""
if [[ -n "$FIELDS_OPT" ]]; then
    FIELDS_NORM=$(echo "$FIELDS_OPT" | tr '[:lower:]' '[:upper:]' | tr ', ' '  ' | tr -s ' ' | sed 's/^ //; s/ $//')
fi

# --- conflito: --fields e --all-fields ---
if [[ "$ALL_FIELDS" == true && -n "$FIELDS_NORM" ]]; then
    error "Opcoes --fields e --all-fields sao mutuamente exclusivas."
fi

# --- coleta arquivos em modo recursivo ---
if [[ "$RECURSIVE" == true ]]; then
    if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
        SEARCH_DIR="."
    else
        SEARCH_DIR="${INPUT_FILES[0]}"
        INPUT_FILES=()
    fi
    [[ ! -d "$SEARCH_DIR" ]] && error "Diretorio nao encontrado: $SEARCH_DIR"
    while IFS= read -r -d '' f; do
        INPUT_FILES+=("$f")
    done < <(find "$SEARCH_DIR" -type f -iname "*.ris" -print0)
    if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
        warn "Nenhum arquivo .ris encontrado em: $SEARCH_DIR"
        exit 0
    fi
fi

# --- validacao de entrada ---
if [[ "${#INPUT_FILES[@]}" -eq 0 ]]; then
    echo -e "${RED}Erro: nenhum arquivo .ris informado.${RESET}" >&2
    echo -e "  ${DIM}Use --help para ver o uso.${RESET}" >&2
    exit 1
fi

# --- validacao do diretorio/arquivo de saida ---
if [[ -n "$OUTPUT_DIR" ]]; then
    if [[ "$MERGE" == true && "$OUTPUT_DIR" == *.csv ]]; then
        # modo merge: -o pode apontar para arquivo .csv
        parent=$(dirname "$OUTPUT_DIR")
        if [[ ! -d "$parent" ]]; then
            if [[ "$DRY_RUN" == false ]]; then
                mkdir -p "$parent"
                log "Diretorio criado: $parent"
            else
                log "[Dry-run] Criaria diretorio: $parent"
            fi
        fi
    elif [[ ! -d "$OUTPUT_DIR" ]]; then
        # diretorio normal
        if [[ "$DRY_RUN" == false ]]; then
            mkdir -p "$OUTPUT_DIR"
            log "Diretorio de saida criado: $OUTPUT_DIR"
        else
            log "[Dry-run] Criaria diretorio: $OUTPUT_DIR"
        fi
    fi
fi

# --- determina arquivo de saida do merge ---
MERGE_OUTPUT=""
if [[ "$MERGE" == true ]]; then
    if [[ -n "$OUTPUT_DIR" && "$OUTPUT_DIR" == *.csv ]]; then
        MERGE_OUTPUT="$OUTPUT_DIR"
    elif [[ -n "$OUTPUT_DIR" ]]; then
        MERGE_OUTPUT="${OUTPUT_DIR}/merged.csv"
    else
        MERGE_OUTPUT="merged.csv"
    fi
fi

# --- contadores ---
CONVERTED=0
TOTAL_RECORDS=0
SKIPPED=0
ERRORS=0

# --- cabecalho ---
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "  ${BOLD}  ris-to-csv.sh${RESET}  ${DIM}v$VERSION${RESET}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
[[ "$DRY_RUN" == true ]] && echo -e "  ${YELLOW}[Dry-run ativado — nenhum arquivo sera gravado]${RESET}"
[[ "$MERGE" == true ]] && echo -e "  ${DIM}Modo: ${BOLD}merge → ${MERGE_OUTPUT}${RESET}"
[[ "$ALL_FIELDS" == true ]] && echo -e "  ${DIM}Modo: ${BOLD}all-fields (colunas dinamicas)${RESET}"
[[ -n "$FIELDS_NORM" ]] && echo -e "  ${DIM}Campos: ${BOLD}$FIELDS_NORM${RESET}"
[[ "$DELIMITER" != "," ]] && echo -e "  ${DIM}Delimitador: ${BOLD}$(printf '%q' "$DELIMITER")${RESET}"
[[ "$JOIN_SEP" != "; " ]] && echo -e "  ${DIM}Join: ${BOLD}$JOIN_SEP${RESET}"
[[ "$NO_HEADER" == true ]] && echo -e "  ${DIM}Sem cabecalho${RESET}"
echo -e "  ${DIM}Arquivos encontrados: ${#INPUT_FILES[@]}${RESET}"
echo ""

# --- funcao de execucao do awk (compartilhada entre modos) ---
# $1 = arquivo de saida, $2.. = arquivos de entrada
LAST_RECS=0
run_awk_conversion() {
    local out="$1"; shift

    local all_flag="0"
    [[ "$ALL_FIELDS" == true ]] && all_flag="1"
    local noheader_flag="0"
    [[ "$NO_HEADER" == true ]] && noheader_flag="1"

    if awk -v FIELDS="$FIELDS_NORM" \
            -v ALL="$all_flag" \
            -v JOIN="$JOIN_SEP" \
            -v DELIM="$DELIMITER" \
            -v NOHEADER="$noheader_flag" \
            -f - "$@" > "$TMP_CSV" 2> "$TMP_ERR" <<'AWK_PROGRAM'
        # ---- nomes amigaveis para tags RIS comuns ----
        BEGIN {
            NAMES["TY"]="Type";   NAMES["AU"]="Authors";  NAMES["A1"]="Authors"
            NAMES["A2"]="SecondaryAuthors"; NAMES["A3"]="TertiaryAuthors"
            NAMES["A4"]="QuaternaryAuthors"; NAMES["AB"]="Abstract"
            NAMES["AD"]="AuthorAddress";     NAMES["AN"]="AccessionNumber"
            NAMES["AV"]="Location";           NAMES["BT"]="BasedOnTitle"
            NAMES["C1"]="Custom1"; NAMES["C2"]="Custom2"; NAMES["C3"]="Custom3"
            NAMES["CA"]="Caption";            NAMES["CN"]="CallNumber"
            NAMES["CT"]="ChapterTitle";       NAMES["CY"]="City"
            NAMES["DA"]="Date";               NAMES["DB"]="Database"
            NAMES["DO"]="DOI";                NAMES["DOI"]="DOI"
            NAMES["DP"]="DatabaseProvider";   NAMES["ED"]="Editor"
            NAMES["EP"]="EndPage";            NAMES["ET"]="Edition"
            NAMES["ID"]="ReferenceID";        NAMES["IS"]="Issue"
            NAMES["J1"]="JournalAbbrev";      NAMES["J2"]="AlternateJournal"
            NAMES["JA"]="JournalAbbrev";      NAMES["JO"]="Journal"
            NAMES["JF"]="JournalFull";        NAMES["KW"]="Keywords"
            NAMES["L1"]="LinkToPDF";          NAMES["L2"]="LinkToFulltext"
            NAMES["L3"]="RelatedRecords";     NAMES["L4"]="Image"
            NAMES["LA"]="Language";           NAMES["LB"]="Label"
            NAMES["M1"]="Number";             NAMES["M2"]="Misc2"
            NAMES["M3"]="Misc3";              NAMES["N1"]="Notes"
            NAMES["N2"]="Abstract";           NAMES["NV"]="NumberOfVolumes"
            NAMES["OP"]="OriginalPublication"; NAMES["PB"]="Publisher"
            NAMES["PP"]="Pages";              NAMES["PY"]="Year"
            NAMES["RI"]="ReviewedItem";       NAMES["RN"]="ResearchNotes"
            NAMES["RP"]="ReprintStatus";      NAMES["SE"]="Section"
            NAMES["SN"]="ISSN";               NAMES["SP"]="StartPage"
            NAMES["ST"]="ShortTitle";         NAMES["T1"]="PrimaryTitle"
            NAMES["T2"]="SecondaryTitle";     NAMES["T3"]="TertiaryTitle"
            NAMES["TA"]="TranslatedAuthor";   NAMES["TI"]="Title"
            NAMES["TT"]="TranslatedTitle";    NAMES["U1"]="User1"
            NAMES["U2"]="User2"; NAMES["U3"]="User3"; NAMES["U4"]="User4"
            NAMES["U5"]="User5";               NAMES["UR"]="URL"
            NAMES["VL"]="Volume";             NAMES["Y1"]="PrimaryDate"
            NAMES["Y2"]="AccessDate";         NAMES["ER"]="EndOfRecord"
            nrecs=0; record_open=0; lasttag=""; alltags=""
        }

        # ---- funcoes auxiliares ----
        function name_of(tag) { return (tag in NAMES) ? NAMES[tag] : tag }

        function csv_escape(s) {
            gsub(/\x1F/, JOIN, s)
            if (s == "") return ""
            if (index(s, DELIM) || index(s, "\"") || index(s, "\n") \
                || index(s, "\r") || s ~ /^[ \t]/ || s ~ /[ \t]$/) {
                gsub(/"/, "\"\"", s)
                return "\"" s "\""
            }
            return s
        }

        function add_tag(tag) {
            if (!((nrecs, tag) in seen)) {
                seen[nrecs, tag] = 1
                rectags[nrecs] = (rectags[nrecs] == "" ? tag : rectags[nrecs] " " tag)
            }
            if (!(tag in gseen)) {
                gseen[tag] = 1
                alltags = (alltags == "" ? tag : alltags " " tag)
            }
        }

        function add_value(tag, val) {
            if ((nrecs, tag) in recval)
                recval[nrecs, tag] = recval[nrecs, tag] "\x1F" val
            else
                recval[nrecs, tag] = val
        }

        # ---- regra 1: strip de CR (arquivos CRLF do Windows) ----
        { sub(/\r$/, "") }

        # ---- regra 2: linhas em branco separam/se pulam ----
        /^[ \t]*$/ { next }

        # ---- regra 3: deteccao de linha de tag + continuacao ----
        {
            c1 = substr($0, 1, 1); c2 = substr($0, 2, 1)
            if (c1 ~ /[A-Za-z0-9]/ && c2 ~ /[A-Za-z0-9]/) {
                p = 3
                while (substr($0, p, 1) == " " || substr($0, p, 1) == "\t") p++
                if (substr($0, p, 1) == "-") {
                    p++
                    while (substr($0, p, 1) == " " || substr($0, p, 1) == "\t") p++
                    value = substr($0, p)
                    tag = toupper(c1 c2)
                    if (tag == "ER") { record_open = 0; next }
                    if (tag == "TY") { nrecs++; record_open = 1 }
                    else if (!record_open) { nrecs++; record_open = 1 }
                    add_tag(tag); add_value(tag, value); lasttag = tag
                    next
                }
            }
            # linha de continuacao: anexa ao ultimo campo do registro aberto
            if (record_open && lasttag != "" && (nrecs, lasttag) in recval) {
                recval[nrecs, lasttag] = recval[nrecs, lasttag] " " $0
            }
            next
        }

        # ---- finalizacao: emite o CSV ----
        END {
            ncols = 0
            if (FIELDS != "") {
                n = split(FIELDS, fa, /[ ,]+/)
                for (i = 1; i <= n; i++) if (fa[i] != "") cols[++ncols] = toupper(fa[i])
            } else if (ALL == "1") {
                n = split(alltags, fa, " ")
                for (i = 1; i <= n; i++) if (fa[i] != "") cols[++ncols] = fa[i]
            } else {
                n = split("TY AU TI T2 PY DA JO JF VL IS SP EP AB KW DO UR PB CY SN LA ET N1 A2", fa, " ")
                for (i = 1; i <= n; i++) cols[++ncols] = fa[i]
            }

            if (NOHEADER != "1") {
                line = ""
                for (i = 1; i <= ncols; i++)
                    line = (i == 1 ? csv_escape(name_of(cols[i])) : line DELIM csv_escape(name_of(cols[i])))
                print line
            }

            for (r = 1; r <= nrecs; r++) {
                line = ""
                for (i = 1; i <= ncols; i++) {
                    tag = cols[i]
                    v = ((r, tag) in recval) ? recval[r, tag] : ""
                    v = csv_escape(v)
                    line = (i == 1 ? v : line DELIM v)
                }
                print line
            }

            print "RECORDS " nrecs > "/dev/stderr"
        }
AWK_PROGRAM
    then
        LAST_RECS=$(awk '/^RECORDS /{print $2}' "$TMP_ERR" 2>/dev/null)
        LAST_RECS=${LAST_RECS:-0}
        mv "$TMP_CSV" "$out"
        return 0
    else
        return 1
    fi
}

# --- funcao de merge (combina varios arquivos num unico CSV) ---
merge_files() {
    local valid=()
    local skipped_count=0
    for f in "$@"; do
        if [[ ! -f "$f" ]]; then
            warn "Arquivo nao encontrado, ignorando: $f"
            (( skipped_count++ )) || true
            continue
        fi
        local ext="${f##*.}"
        if [[ "${ext,,}" != "ris" ]]; then
            warn "Arquivo ignorado (nao e .ris): $f"
            (( skipped_count++ )) || true
            continue
        fi
        valid+=("$f")
    done
    (( SKIPPED += skipped_count )) || true

    if [[ ${#valid[@]} -eq 0 ]]; then
        error "Nenhum arquivo .ris valido para merge."
    fi

    # verifica sobrescrita
    if [[ -f "$MERGE_OUTPUT" && "$OVERWRITE" == false && "$DRY_RUN" == false ]]; then
        warn "Arquivo ja existe, pulando (use --overwrite): $MERGE_OUTPUT"
        (( SKIPPED++ )) || true
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${BLUE}▶${RESET} [Dry-run] ${BOLD}${#valid[@]}${RESET} ${DIM}arquivo(s) →${RESET} ${BOLD}$MERGE_OUTPUT${RESET}"
        (( CONVERTED++ )) || true
        return
    fi

    echo -e "  ${DIM}Mesclando ${#valid[@]} arquivo(s)...${RESET}"

    if run_awk_conversion "$MERGE_OUTPUT" "${valid[@]}"; then
        echo -e "  ${GREEN}✓${RESET} ${BOLD}${#valid[@]}${RESET} ${DIM}arquivo(s) →${RESET} ${BOLD}$MERGE_OUTPUT${RESET} ${DIM}(${LAST_RECS} registro(s))${RESET}"
        (( CONVERTED++ )) || true
        (( TOTAL_RECORDS += LAST_RECS )) || true
    else
        echo -e "  ${RED}✗${RESET} Falha no merge de ${#valid[@]} arquivo(s)"
        local err_msg
        err_msg=$(head -1 "$TMP_ERR" 2>/dev/null)
        [[ -n "$err_msg" ]] && echo -e "    ${DIM}$err_msg${RESET}"
        (( ERRORS++ )) || true
    fi
}

# --- funcao principal de conversao (1 arquivo por CSV) ---
convert_file() {
    local input="$1"

    if [[ ! -f "$input" ]]; then
        warn "Arquivo nao encontrado, ignorando: $input"
        (( ERRORS++ )) || true
        return
    fi

    local ext="${input##*.}"
    if [[ "${ext,,}" != "ris" ]]; then
        warn "Arquivo ignorado (nao e .ris): $input"
        (( SKIPPED++ )) || true
        return
    fi

    local base_name
    base_name=$(basename "$input")
    base_name="${base_name%.[rR][iI][sS]}"

    local dest_dir
    if [[ -n "$OUTPUT_DIR" ]]; then
        dest_dir="$OUTPUT_DIR"
    else
        dest_dir=$(dirname "$input")
    fi

    local output="${dest_dir}/${base_name}.csv"

    # verifica sobrescrita
    if [[ -f "$output" && "$OVERWRITE" == false && "$DRY_RUN" == false ]]; then
        warn "Arquivo ja existe, pulando (use --overwrite para forcar): $(basename "$output")"
        (( SKIPPED++ )) || true
        return
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "  ${BLUE}▶${RESET} [Dry-run] ${DIM}$(basename "$input")${RESET} ${DIM}→${RESET} ${BOLD}$(basename "$output")${RESET}"
        (( CONVERTED++ )) || true
        return
    fi

    # executa conversao via awk (funcao compartilhada)
    if run_awk_conversion "$output" "$input"; then
        echo -e "  ${GREEN}✓${RESET} ${DIM}$(basename "$input")${RESET} ${DIM}→${RESET} ${BOLD}$(basename "$output")${RESET} ${DIM}(${LAST_RECS} registro(s))${RESET}"
        (( CONVERTED++ )) || true
        (( TOTAL_RECORDS += LAST_RECS )) || true
    else
        echo -e "  ${RED}✗${RESET} Falha ao converter: $(basename "$input")"
        local err_msg
        err_msg=$(head -1 "$TMP_ERR" 2>/dev/null)
        [[ -n "$err_msg" ]] && echo -e "    ${DIM}$err_msg${RESET}"
        (( ERRORS++ )) || true
    fi
}

# --- loop principal ---
if [[ "$MERGE" == true ]]; then
    merge_files "${INPUT_FILES[@]}"
else
    for file in "${INPUT_FILES[@]}"; do
        convert_file "$file"
    done
fi

# --- resumo ---
echo ""
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo ""
if [[ "$DRY_RUN" == true ]]; then
    echo -e "  ${YELLOW}[Dry-run]${RESET} Seriam gerados: ${BOLD}$CONVERTED${RESET} arquivo(s) CSV"
else
    echo -e "  ${GREEN}✓ Gerados:${RESET}     ${BOLD}$CONVERTED${RESET} arquivo(s) CSV  ${DIM}(${TOTAL_RECORDS} registro(s))${RESET}"
fi
[[ "$SKIPPED" -gt 0 ]] && echo -e "  ${YELLOW}▶ Ignorados:${RESET}   ${BOLD}$SKIPPED${RESET}"
[[ "$ERRORS"  -gt 0 ]] && echo -e "  ${RED}✗ Erros:${RESET}      ${BOLD}$ERRORS${RESET}"
echo ""

[[ "$ERRORS" -gt 0 ]] && exit 1
exit 0
