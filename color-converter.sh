#!/bin/bash
# color-converter.sh — Conversao entre HEX, RGB, HSL e nome de cor + preview
# Uso: ./color-converter.sh [opcoes]
# Opcoes:
#   -c, --color COLOR    Cor a converter (HEX, RGB, HSL ou nome)
#   --preview            Mostra preview da cor no terminal
#   --list               Lista nomes de cores conhecidos
#   --help               Mostra esta ajuda
#   --version            Mostra versao

set -euo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "bc" "$INSTALLER" "bc"; fi

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
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }


COLOR_INPUT=""
SHOW_PREVIEW=false
LIST_COLORS=false

declare -A NAMED_COLORS
NAMED_COLORS=(
    [black]="0,0,0" [white]="255,255,255" [red]="255,0,0" [green]="0,128,0"
    [blue]="0,0,255" [yellow]="255,255,0" [cyan]="0,255,255" [magenta]="255,0,255"
    [orange]="255,165,0" [purple]="128,0,128" [pink]="255,192,203" [brown]="139,69,19"
    [gray]="128,128,128" [grey]="128,128,128" [navy]="0,0,128" [teal]="0,128,128"
    [maroon]="128,0,0" [olive]="128,128,0" [lime]="0,255,0" [aqua]="0,255,255"
    [silver]="192,192,192" [gold]="255,215,0" [coral]="255,127,80" [salmon]="250,128,114"
    [khaki]="240,230,140" [violet]="238,130,238" [indigo]="75,0,130" [beige]="245,245,220"
    [ivory]="255,255,240" [turquoise]="64,224,208" [crimson]="220,20,60" [chocolate]="210,105,30"
)

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--color)
            [[ -z "${2-}" ]] && { echo "Flag --color requer um valor" >&2; exit 1; }
            COLOR_INPUT="$2"; shift 2 ;;
        --preview|-p) SHOW_PREVIEW=true; shift ;;
        --list|-l) LIST_COLORS=true; shift ;;
        --help|-h)
            echo ""
            echo "  color-converter.sh — Conversao entre formatos de cor"
            echo ""
            echo "  Uso: ./color-converter.sh -c COR [--preview]"
            echo ""
            echo "  Formatos aceitos:"
            echo "    HEX:     #ff0000 ou ff0000"
            echo "    RGB:     rgb(255,0,0) ou 255,0,0"
            echo "    HSL:     hsl(0,100%,50%) ou 0,100,50"
            echo "    Nome:    red, blue, green, etc."
            echo ""
            echo "  Opcoes:"
            echo "    -c, --color COLOR  Cor a converter"
            echo "    --preview          Mostra preview da cor no terminal"
            echo "    --list             Lista nomes de cores conhecidos"
            echo "    --help             Mostra esta ajuda"
            echo "    --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./color-converter.sh -c '#ff6600'"
            echo "    ./color-converter.sh -c 'rgb(255,100,0)' --preview"
            echo "    ./color-converter.sh -c red"
            echo ""
            exit 0
            ;;
        --version|-V) echo "color-converter.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if $LIST_COLORS; then
    echo ""
    echo -e "  ${BOLD}── Cores Nomeadas ──${RESET}"
    echo ""
    for name in $(echo "${!NAMED_COLORS[@]}" | tr ' ' '\n' | sort); do
        rgb="${NAMED_COLORS[$name]}"
        r=$(echo "$rgb" | cut -d',' -f1)
        g=$(echo "$rgb" | cut -d',' -f2)
        b=$(echo "$rgb" | cut -d',' -f3)
        hex=$(printf '#%02x%02x%02x' "$r" "$g" "$b")
        if [ -t 1 ]; then
            printf "  \033[48;2;%s;%s;%sm      \033[0m " "$r" "$g" "$b"
        else
            printf "  "
        fi
        printf "${CYAN}%-10s${RESET} ${DIM}%s${RESET}\n" "$name" "$hex"
    done
    echo ""
    exit 0
fi

if [ -z "$COLOR_INPUT" ]; then
    echo ""
    echo -e "  ${BOLD}Color Converter${RESET}  ${DIM}v$VERSION${RESET}"
    echo ""
    printf "  Cor (HEX, RGB, HSL ou nome): "
    read -r COLOR_INPUT < /dev/tty
fi

hex_to_rgb() {
    local hex="$1"
    hex="${hex#\#}"
    hex=$(echo "$hex" | tr '[:lower:]' '[:upper:]')
    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))
    echo "$r,$g,$b"
}

rgb_to_hsl() {
    local r="$1" g="$2" b="$3"
    local ri=$(echo "$r" | cut -d'.' -f1)
    local gi=$(echo "$g" | cut -d'.' -f1)
    local bi=$(echo "$b" | cut -d'.' -f1)
    r=$(echo "scale=4; $ri / 255" | bc)
    g=$(echo "scale=4; $gi / 255" | bc)
    b=$(echo "scale=4; $bi / 255" | bc)

    local vals=$(printf '%s\n%s\n%s' "$r" "$g" "$b" | sort -g)
    local maxmin=$(echo "$vals" | tail -1)
    local mn=$(echo "$vals" | head -1)
    local l=$(echo "scale=4; ($maxmin + $mn) / 2" | bc)
    local delta=$(echo "scale=4; $maxmin - $mn" | bc)

    local h=0 s=0
    local delta_zero=$(echo "$delta == 0" | bc)
    if [ "$delta_zero" -eq 0 ]; then
        local l_low=$(echo "scale=4; $l < 0.5" | bc)
        if [ "$l_low" -eq 1 ]; then
            s=$(echo "scale=2; $delta / ($maxmin + $mn) * 100" | bc)
        else
            s=$(echo "scale=2; $delta / (2 - $maxmin - $mn) * 100" | bc)
        fi

        local max_r=$(echo "$maxmin == $r" | bc)
        local max_g=$(echo "$maxmin == $g" | bc)
        if [ "$max_r" -eq 1 ]; then
            h=$(echo "scale=2; ($g - $b) / $delta * 60" | bc)
        elif [ "$max_g" -eq 1 ]; then
            h=$(echo "scale=2; ($b - $r) / $delta * 60 + 120" | bc)
        else
            h=$(echo "scale=2; ($r - $g) / $delta * 60 + 240" | bc)
        fi
        local h_neg=$(echo "$h < 0" | bc)
        if [ "$h_neg" -eq 1 ]; then
            h=$(echo "scale=2; $h + 360" | bc)
        fi
    fi

    h=$(echo "$h" | cut -c1-5 | sed 's/\.$//' | sed 's/^-$//' | sed 's/^$/0/')
    h=$(echo "scale=0; $h / 1" | bc 2>/dev/null || echo 0)
    s=$(echo "$s" | cut -c1-5 | sed 's/\.$//' | sed 's/^-$//' | sed 's/^$/0/')
    s=$(echo "scale=0; $s / 1" | bc 2>/dev/null || echo 0)
    local l_pct=$(echo "scale=0; $l * 100 / 1" | bc 2>/dev/null || echo 50)
    echo "$h,$s,$l_pct"
}

rgb_to_hex() {
    local r="$1" g="$2" b="$3"
    printf '#%02x%02x%02x' "$r" "$g" "$b"
}

find_color_name() {
    local r="$1" g="$2" b="$3"
    local best_name="" best_dist=999999
    for name in "${!NAMED_COLORS[@]}"; do
        local rgb="${NAMED_COLORS[$name]}"
        local nr=$(echo "$rgb" | cut -d',' -f1)
        local ng=$(echo "$rgb" | cut -d',' -f2)
        local nb=$(echo "$rgb" | cut -d',' -f3)
        local dist=$(( (r - nr) ** 2 + (g - ng) ** 2 + (b - nb) ** 2 ))
        if [ "$dist" -lt "$best_dist" ]; then
            best_dist=$dist
            best_name="$name"
        fi
    done
    echo "$best_name"
}

COLOR_INPUT=$(echo "$COLOR_INPUT" | xargs)
COLOR_INPUT_LOWER=$(echo "$COLOR_INPUT" | tr '[:upper:]' '[:lower:]')

R="" G="" B=""

if [[ "$COLOR_INPUT_LOWER" =~ ^#?[0-9a-f]{6}$ ]]; then
    RGB_STR=$(hex_to_rgb "$COLOR_INPUT")
    R=$(echo "$RGB_STR" | cut -d',' -f1)
    G=$(echo "$RGB_STR" | cut -d',' -f2)
    B=$(echo "$RGB_STR" | cut -d',' -f3)
elif [[ "$COLOR_INPUT" =~ ^rgb\([0-9]+,[0-9]+,[0-9]+\)$ ]]; then
    RGB_STR=$(echo "$COLOR_INPUT" | sed 's/rgb(//;s/)//')
    R=$(echo "$RGB_STR" | cut -d',' -f1)
    G=$(echo "$RGB_STR" | cut -d',' -f2)
    B=$(echo "$RGB_STR" | cut -d',' -f3)
elif [[ "$COLOR_INPUT" =~ ^[0-9]+,[0-9]+,[0-9]+$ ]]; then
    R=$(echo "$COLOR_INPUT" | cut -d',' -f1)
    G=$(echo "$COLOR_INPUT" | cut -d',' -f2)
    B=$(echo "$COLOR_INPUT" | cut -d',' -f3)
elif [[ "$COLOR_INPUT" =~ ^hsl\([0-9]+,[0-9]+%,?[0-9]+%?\)$ ]]; then
    HSL_STR=$(echo "$COLOR_INPUT" | sed 's/hsl(//;s/)//;s/%//g')
    H=$(echo "$HSL_STR" | cut -d',' -f1)
    SAT=$(echo "$HSL_STR" | cut -d',' -f2)
    L=$(echo "$HSL_STR" | cut -d',' -f3)
    SAT_D=$(echo "scale=4; $SAT / 100" | bc)
    L_D=$(echo "scale=4; $L / 100" | bc)
    if [ "$SAT" -eq 0 ]; then
        R=$(echo "$L * 255 / 1" | bc)
        G=$R; B=$R
    else
        C=$(echo "scale=4; (1 - (2 * $L_D - 1)) * $SAT_D" | bc)
        X=$(echo "scale=4; $C * (1 - ($H / 60 % 2 - 1))" | bc 2>/dev/null || echo "0")
        X=$(echo "scale=4; ($H / 60) % 2" | bc 2>/dev/null)
        if [ -z "$X" ]; then X=0; fi
        X=$(echo "scale=4; 1 - (${X} - 1)" | bc 2>/dev/null || echo "0")
        X=$(echo "scale=4; $C * $X" | bc 2>/dev/null || echo "0")
        m=$(echo "scale=4; $L_D - $C / 2" | bc)
        h_div=$(echo "scale=0; $H / 60" | bc)
        case "$h_div" in
            0) r1=$C; g1=$X; b1=0 ;;
            1) r1=$X; g1=$C; b1=0 ;;
            2) r1=0; g1=$C; b1=$X ;;
            3) r1=0; g1=$X; b1=$C ;;
            4) r1=$X; g1=0; b1=$C ;;
        --) shift; break ;;
            *) r1=$C; g1=0; b1=$X ;;
        esac
        R=$(echo "scale=0; ($r1 + $m) * 255" | bc)
        G=$(echo "scale=0; ($g1 + $m) * 255" | bc)
        B=$(echo "scale=0; ($b1 + $m) * 255" | bc)
        R=${R%.*}; G=${G%.*}; B=${B%.*}
        [ -z "$R" ] && R=0; [ -z "$G" ] && G=0; [ -z "$B" ] && B=0
        [ "$R" -lt 0 ] 2>/dev/null && R=0; [ "$G" -lt 0 ] 2>/dev/null && G=0; [ "$B" -lt 0 ] 2>/dev/null && B=0
    fi
elif [ -n "${NAMED_COLORS[$COLOR_INPUT_LOWER]}" ]; then
    RGB_STR="${NAMED_COLORS[$COLOR_INPUT_LOWER]}"
    R=$(echo "$RGB_STR" | cut -d',' -f1)
    G=$(echo "$RGB_STR" | cut -d',' -f2)
    B=$(echo "$RGB_STR" | cut -d',' -f3)
else
    echo ""
    echo -e "  ${RED}Formato de cor nao reconhecido: $COLOR_INPUT${RESET}"
    echo -e "  ${DIM}Use: #hex, rgb(r,g,b), hsl(h,s%,l%) ou nome de cor${RESET}"
    echo ""
    exit 1
fi

HEX=$(rgb_to_hex "$R" "$G" "$B")
HSL=$(rgb_to_hsl "$R" "$G" "$B")
H=$(echo "$HSL" | cut -d',' -f1)
S=$(echo "$HSL" | cut -d',' -f2)
L_V=$(echo "$HSL" | cut -d',' -f3)
CLOSEST_NAME=$(find_color_name "$R" "$G" "$B")

echo ""
echo -e "  ${BOLD}── Color Converter ──${RESET}"
echo ""
echo -e "  HEX:    ${GREEN}${BOLD}${HEX}${RESET}"
echo -e "  RGB:    ${GREEN}${R}, ${G}, ${B}${RESET}  ${DIM}rgb(${R},${G},${B})${RESET}"
echo -e "  HSL:    ${GREEN}${H}°, ${S}%, ${L_V}%${RESET}  ${DIM}hsl(${H},${S}%,${L_V}%)${RESET}"
echo -e "  Nome:   ${GREEN}${CLOSEST_NAME}${RESET} ${DIM}(mais proximo)${RESET}"
echo ""

if $SHOW_PREVIEW && [ -t 1 ]; then
    for i in $(seq 1 3); do
        echo -e "  \033[48;2;${R};${G};${B}m                                                    \033[0m"
    done
    echo ""
fi