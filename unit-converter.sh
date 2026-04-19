#!/bin/bash
# unit-converter.sh — Conversao entre unidades de medida
# Uso: ./unit-converter.sh [opcoes]
# Opcoes:
#   -t, --type TYPE    Tipo de conversao (temp, length, weight, volume, speed, area, time)
#   -f, --from UNIT    Unidade de origem
#   -i, --input VAL    Valor a converter
#   --list             Lista unidades disponiveis
#   --help             Mostra esta ajuda
#   --version          Mostra versao

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
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }
DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "bc" "$INSTALLER" "bc"; fi




CONV_TYPE=""
FROM_UNIT=""
INPUT_VAL=""
LIST_UNITS=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--type)
            [[ -z "${2-}" ]] && { echo "Flag --type requer um valor" >&2; exit 1; }
            CONV_TYPE="$2"; shift 2 ;;
        -f|--from)
            [[ -z "${2-}" ]] && { echo "Flag --from requer um valor" >&2; exit 1; }
            FROM_UNIT="$2"; shift 2 ;;
        -i|--input)
            [[ -z "${2-}" ]] && { echo "Flag --input requer um valor" >&2; exit 1; }
            INPUT_VAL="$2"; shift 2 ;;
        --list|-l) LIST_UNITS=true; shift ;;
        --help|-h)
            echo ""
            echo "  unit-converter.sh — Conversao entre unidades de medida"
            echo ""
            echo "  Uso: ./unit-converter.sh -t TIPO -f UNIDADE -i VALOR"
            echo ""
            echo "  Tipos: temp, length, weight, volume, speed, area, time"
            echo ""
            echo "  Opcoes:"
            echo "    -t, --type TYPE    Tipo de conversao"
            echo "    -f, --from UNIT    Unidade de origem"
            echo "    -i, --input VAL    Valor a converter"
            echo "    --list             Lista unidades disponiveis"
            echo "    --help             Mostra esta ajuda"
            echo "    --version          Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./unit-converter.sh -t temp -f c -i 100"
            echo "    ./unit-converter.sh -t length -f km -i 5"
            echo ""
            exit 0
            ;;
        --version|-V) echo "unit-converter.sh $VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

convert_temp() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local celsius
    case "$from" in
        c|cel|celsius)
            celsius="$val"
            echo -e "  ${CYAN}${val}°C${RESET} = ${GREEN}$(echo "scale=2; $val * 9 / 5 + 32" | bc)°F${RESET} (Fahrenheit)"
            echo -e "  ${CYAN}${val}°C${RESET} = ${GREEN}$(echo "scale=2; $val + 273.15" | bc)°K${RESET} (Kelvin)"
            ;;
        f|fah|fahrenheit)
            celsius=$(echo "scale=2; ($val - 32) * 5 / 9" | bc)
            echo -e "  ${CYAN}${val}°F${RESET} = ${GREEN}${celsius}°C${RESET} (Celsius)"
            echo -e "  ${CYAN}${val}°F${RESET} = ${GREEN}$(echo "scale=2; $celsius + 273.15" | bc)°K${RESET} (Kelvin)"
            ;;
        k|kel|kelvin)
            celsius=$(echo "scale=2; $val - 273.15" | bc)
            echo -e "  ${CYAN}${val}°K${RESET} = ${GREEN}${celsius}°C${RESET} (Celsius)"
            echo -e "  ${CYAN}${val}°K${RESET} = ${GREEN}$(echo "scale=2; $celsius * 9 / 5 + 32" | bc)°F${RESET} (Fahrenheit)"
            ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}" ;;
    esac
}

convert_length() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local meters
    case "$from" in
        mm|milimetro|milimetros) meters=$(echo "scale=6; $val / 1000" | bc) ;;
        cm|centimetro|centimetros) meters=$(echo "scale=6; $val / 100" | bc) ;;
        m|metro|metros) meters="$val" ;;
        km|quilometro|quilometros) meters=$(echo "scale=6; $val * 1000" | bc) ;;
        in|inch|inches) meters=$(echo "scale=6; $val * 0.0254" | bc) ;;
        ft|feet|pes) meters=$(echo "scale=6; $val * 0.3048" | bc) ;;
        yd|yard|jardas) meters=$(echo "scale=6; $val * 0.9144" | bc) ;;
        mi|mile|milhas) meters=$(echo "scale=6; $val * 1609.344" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters * 1000" | bc) mm${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters * 100" | bc) cm${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters" | bc) m${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=6; $meters / 1000" | bc) km${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters / 0.0254" | bc) in${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters / 0.3048" | bc) ft${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $meters / 0.9144" | bc) yd${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=6; $meters / 1609.344" | bc) mi${RESET}"
}

convert_weight() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local grams
    case "$from" in
        mg|miligrama) grams=$(echo "scale=6; $val / 1000" | bc) ;;
        g|grama|gramas) grams="$val" ;;
        kg|quilo|quilos|quilograma) grams=$(echo "scale=6; $val * 1000" | bc) ;;
        lb|libra|libras) grams=$(echo "scale=6; $val * 453.592" | bc) ;;
        oz|onca|oncas) grams=$(echo "scale=6; $val * 28.3495" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $grams * 1000" | bc) mg${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $grams" | bc) g${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=6; $grams / 1000" | bc) kg${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $grams / 453.592" | bc) lb${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $grams / 28.3495" | bc) oz${RESET}"
}

convert_volume() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local liters
    case "$from" in
        ml|mililitro) liters=$(echo "scale=6; $val / 1000" | bc) ;;
        l|litro|litros) liters="$val" ;;
        gal|galaogallon) liters=$(echo "scale=6; $val * 3.78541" | bc) ;;
        qt|quart) liters=$(echo "scale=6; $val * 0.946353" | bc) ;;
        pt|pint) liters=$(echo "scale=6; $val * 0.473176" | bc) ;;
        cup|xicara) liters=$(echo "scale=6; $val * 0.236588" | bc) ;;
        floz|oncaliquida) liters=$(echo "scale=6; $val * 0.0295735" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $liters * 1000" | bc) ml${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $liters" | bc) L${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=6; $liters / 3.78541" | bc) gal${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $liters / 0.946353" | bc) qt${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $liters / 0.473176" | bc) pt${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=6; $liters / 0.0295735" | bc) fl oz${RESET}"
}

convert_speed() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local mps
    case "$from" in
        ms|kmhms) mps="$val" ;;
        kmh|km/h) mps=$(echo "scale=6; $val / 3.6" | bc) ;;
        mph|mi/h) mps=$(echo "scale=6; $val * 0.44704" | bc) ;;
        kn|nos) mps=$(echo "scale=6; $val * 0.514444" | bc) ;;
        mach) mps=$(echo "scale=6; $val * 343" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $mps" | bc) m/s${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $mps * 3.6" | bc) km/h${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $mps / 0.44704" | bc) mph${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $mps / 0.514444" | bc) kn${RESET}"
}

convert_area() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local sqm
    case "$from" in
        cm2) sqm=$(echo "scale=6; $val / 10000" | bc) ;;
        m2) sqm="$val" ;;
        km2) sqm=$(echo "scale=6; $val * 1000000" | bc) ;;
        ha|hectare) sqm=$(echo "scale=6; $val * 10000" | bc) ;;
        acre|acres) sqm=$(echo "scale=6; $val * 4046.86" | bc) ;;
        ft2|sqft) sqm=$(echo "scale=6; $val * 0.092903" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $sqm * 10000" | bc) cm²${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $sqm" | bc) m²${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=8; $sqm / 1000000" | bc) km²${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $sqm / 10000" | bc) ha${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $sqm / 4046.86" | bc) acres${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $sqm / 0.092903" | bc) ft²${RESET}"
}

convert_time() {
    local val="$1"
    local from="$2"
    from=$(echo "$from" | tr '[:upper:]' '[:lower:]')
    local seconds
    case "$from" in
        ms|milissegundo) seconds=$(echo "scale=6; $val / 1000" | bc) ;;
        s|segundo|seg) seconds="$val" ;;
        min|minuto) seconds=$(echo "scale=6; $val * 60" | bc) ;;
        h|hora|hr) seconds=$(echo "scale=6; $val * 3600" | bc) ;;
        d|dia) seconds=$(echo "scale=6; $val * 86400" | bc) ;;
        w|semana) seconds=$(echo "scale=6; $val * 604800" | bc) ;;
        mo|mes) seconds=$(echo "scale=6; $val * 2592000" | bc) ;;
        y|ano) seconds=$(echo "scale=6; $val * 31536000" | bc) ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Unidade desconhecida: $from${RESET}"; return ;;
    esac
    echo -e "  ${CYAN}${val} ${from}${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $seconds * 1000" | bc) ms${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=2; $seconds" | bc) s${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $seconds / 60" | bc) min${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $seconds / 3600" | bc) h${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $seconds / 86400" | bc) d${RESET}"
    echo -e "    = ${GREEN}$(echo "scale=4; $seconds / 604800" | bc) sem${RESET}"
}

show_units() {
    echo ""
    echo -e "  ${BOLD}── Unidades Disponiveis ──${RESET}"
    echo ""
    echo -e "  ${CYAN}Temperatura:${RESET}  c (Celsius), f (Fahrenheit), k (Kelvin)"
    echo -e "  ${CYAN}Comprimento:${RESET} mm, cm, m, km, in, ft, yd, mi"
    echo -e "  ${CYAN}Peso:${RESET}       mg, g, kg, lb, oz"
    echo -e "  ${CYAN}Volume:${RESET}     ml, l, gal, qt, pt, cup, fl oz"
    echo -e "  ${CYAN}Velocidade:${RESET} ms, kmh, mph, kn, mach"
    echo -e "  ${CYAN}Area:${RESET}       cm2, m2, km2, ha, acre, ft2"
    echo -e "  ${CYAN}Tempo:${RESET}      ms, s, min, h, d, w, mo, y"
    echo ""
}

if $LIST_UNITS; then
    show_units
    exit 0
fi

echo ""
echo -e "  ${BOLD}Unit Converter${RESET}  ${DIM}v$VERSION${RESET}"
echo ""

if [ -z "$CONV_TYPE" ]; then
    echo -e "  ${CYAN}Tipos disponiveis:${RESET}"
    echo -e "    1) Temperatura    2) Comprimento    3) Peso"
    echo -e "    4) Volume         5) Velocidade     6) Area"
    echo -e "    7) Tempo"
    echo ""
    printf "  Tipo: "; read -r CONV_TYPE < /dev/tty

    case "$CONV_TYPE" in
        1|temp) CONV_TYPE="temp" ;;
        2|length|comp) CONV_TYPE="length" ;;
        3|weight|peso) CONV_TYPE="weight" ;;
        4|volume|vol) CONV_TYPE="volume" ;;
        5|speed|vel) CONV_TYPE="speed" ;;
        6|area) CONV_TYPE="area" ;;
        7|time|tempo) CONV_TYPE="time" ;;
        --) shift; break ;;
        *) echo -e "  ${RED}Tipo invalido${RESET}"; exit 1 ;;
    esac
fi

if [ -z "$INPUT_VAL" ]; then
    printf "  Valor: "; read -r INPUT_VAL < /dev/tty
fi

if [ -z "$FROM_UNIT" ]; then
    printf "  Unidade de origem: "; read -r FROM_UNIT < /dev/tty
fi

echo ""

case "$CONV_TYPE" in
    temp) convert_temp "$INPUT_VAL" "$FROM_UNIT" ;;
    length) convert_length "$INPUT_VAL" "$FROM_UNIT" ;;
    weight) convert_weight "$INPUT_VAL" "$FROM_UNIT" ;;
    volume) convert_volume "$INPUT_VAL" "$FROM_UNIT" ;;
    speed) convert_speed "$INPUT_VAL" "$FROM_UNIT" ;;
    area) convert_area "$INPUT_VAL" "$FROM_UNIT" ;;
    time) convert_time "$INPUT_VAL" "$FROM_UNIT" ;;
        --) shift; break ;;
    *) echo -e "  ${RED}Tipo de conversao desconhecido: $CONV_TYPE${RESET}" ;;
esac

echo ""