#!/bin/bash
# md-to-pdf.sh — Converte arquivo Markdown (.md) para PDF usando pandoc + XeLaTeX
# Suporta inclusao de imagens PNG e SVG no documento
# Uso: ./md-to-pdf.sh [opcoes] <entrada.md> [saida.pdf]
# Opcoes:
#   --help|-h       Mostra esta ajuda
#   --version|-V    Mostra versao

set -euo pipefail

readonly SCRIPT_VERSION="1.1.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "pandoc" "$INSTALLER" "pandoc"
    check_and_install "xelatex" "$INSTALLER" "texlive-xetex"
    check_and_install "rsvg-convert" "$INSTALLER" "librsvg2-bin"
fi

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

INPUT=""
OUTPUT=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            echo ""
            echo "  ${CYAN}md-to-pdf.sh — Converte Markdown para PDF${RESET}"
            echo ""
            echo "  Uso: ./md-to-pdf.sh [opcoes] <entrada.md> [saida.pdf]"
            echo ""
            echo "  Opcoes:"
            echo "    --help|-h       Mostra esta ajuda"
            echo "    --version|-V    Mostra versao"
            echo ""
            exit 0
            ;;
        --version|-V) echo "md-to-pdf.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        -*)
            echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2
            exit 2
            ;;
        *)
            if [[ -z "$INPUT" ]]; then
                INPUT="$1"
            elif [[ -z "$OUTPUT" ]]; then
                OUTPUT="$1"
            else
                error "Argumentos demais. Uso: ./md-to-pdf.sh <entrada.md> [saida.pdf]"
            fi
            shift
            ;;
    esac
done

if [[ -z "$INPUT" ]]; then
    echo -e "${RED}Erro: arquivo de entrada nao informado.${RESET}" >&2
    echo "  Uso: ./md-to-pdf.sh <entrada.md> [saida.pdf]" >&2
    exit 2
fi

if [[ -z "$OUTPUT" ]]; then
    OUTPUT="${INPUT%.md}.pdf"
fi

if [[ ! -f "$INPUT" ]]; then
    error "Arquivo nao encontrado: $INPUT"
fi

MAIN_FONT="DejaVu Sans"
SANS_FONT="DejaVu Sans"
MONO_FONT="DejaVu Sans Mono"

DEJAVU_AVAILABLE=false
if command -v fc-list &>/dev/null; then
    FONT_CHECK=$(fc-list :family 2>/dev/null | grep -c "DejaVu Sans" || true)
    if [[ "$FONT_CHECK" -gt 0 ]] 2>/dev/null; then
        DEJAVU_AVAILABLE=true
    fi
fi

if [[ "$DEJAVU_AVAILABLE" == false ]]; then
    warn "Fonte 'DejaVu Sans' nao encontrada. Instale com: sudo apt install fonts-dejavu"
    warn "Usando fontes fallback: Liberation Sans / Liberation Mono"
    MAIN_FONT="Liberation Sans"
    SANS_FONT="Liberation Sans"
    MONO_FONT="Liberation Mono"
fi

HEADER_TEX=$(mktemp /tmp/pandoc_header.XXXXXX.tex)
MEDIA_DIR=$(mktemp -d /tmp/pandoc_media.XXXXXX)
trap 'rm -f "$HEADER_TEX"; rm -rf "$MEDIA_DIR"' EXIT

cat > "$HEADER_TEX" <<LATEX
% --- Fonte sans-serif via fontspec (requer XeLaTeX ou LuaLaTeX) ---
\usepackage{fontspec}
\setmainfont{$MAIN_FONT}
\setsansfont{$SANS_FONT}
\setmonofont{$MONO_FONT}

% --- Redefine comando \familydefault para sans-serif ---
\renewcommand{\familydefault}{\sfdefault}

% --- Suporte a imagens PNG e SVG ---
\usepackage{graphicx}
\graphicspath{{./}{./images/}{./figuras/}{./img/}}
\usepackage{float}
\usepackage{svg}

% Configuracoes de posicionamento de imagens
\setkeys{Gin}{width=\maxwidth,height=0.85\textheight,keepaspectratio}

% --- Cabecalho e rodape via fancyhdr ---
\usepackage{fancyhdr}
\usepackage{etoolbox}

\pagestyle{fancy}
\fancyhf{}
\fancyhead[C]{\nouppercase{\leftmark}}
\fancyfoot[C]{\thepage}
\renewcommand{\headrulewidth}{0.4pt}
\renewcommand{\footrulewidth}{0.4pt}

% --- Primeira pagina (capa) sem cabecalho/rodape ---
\AtBeginDocument{\thispagestyle{empty}}

% --- Demais paginas usam o estilo fancy definido acima ---
\pretocmd{\clearpage}{\thispagestyle{fancy}}{}{}
LATEX

echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
log "Convertendo: ${BOLD}$INPUT${RESET} → ${BOLD}$OUTPUT${RESET}"
echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
echo -e "  ${DIM}Fonte principal : $MAIN_FONT (sans-serif)${RESET}"
echo -e "  ${DIM}Fonte mono      : $MONO_FONT${RESET}"

if pandoc "$INPUT" \
    -f markdown+yaml_metadata_block \
    -t pdf \
    --pdf-engine=xelatex \
    --lua-filter="$SCRIPT_DIR/strip-emoji.lua" \
    --include-in-header="$HEADER_TEX" \
    --extract-media="$MEDIA_DIR" \
    -V "geometry:a4paper" \
    -V "geometry:left=2cm,right=2cm" \
    -V "geometry:top=2.5cm,bottom=2.5cm" \
    -V "mainfont=$MAIN_FONT" \
    -V "sansfont=$SANS_FONT" \
    -V "monofont=$MONO_FONT" \
    -V "colorlinks=true" \
    -V "linkcolor=blue" \
    -V "urlcolor=blue" \
    -V "toccolor=black" \
    -o "$OUTPUT"; then
    success "✓ PDF gerado: $OUTPUT"
else
    error "✗ Falha na conversao para PDF."
fi

exit 0