#!/bin/bash
# password-gen.sh — Gerador de senhas configuravel
# Uso: ./password-gen.sh [opcoes]
# Opcoes:
#   -l, --length N      Comprimento da senha (padrao: 16)
#   -n, --count N       Quantidade de senhas (padrao: 1)
#   --no-upper          Remove letras maiusculas
#   --no-lower          Remove letras minusculas
#   --no-digits         Remove digitos
#   --no-symbols        Remove simbolos
#   --only-hex          Apenas caracteres hexadecimais
#   --passphrase        Gera passphrase (palavras separadas)
#   --check SNEHA       Verifica forca de senha
#   --help              Mostra esta ajuda
#   --version           Mostra versao

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

LENGTH=16
COUNT=1
USE_UPPER=true
USE_LOWER=true
USE_DIGITS=true
USE_SYMBOLS=true
ONLY_HEX=false
PASSPHRASE=false
CHECK_PASS=""

while [ $# -gt 0 ]; do
    case "$1" in
        -l|--length) LENGTH="$2"; shift 2 ;;
        -n|--count) COUNT="$2"; shift 2 ;;
        --no-upper) USE_UPPER=false; shift ;;
        --no-lower) USE_LOWER=false; shift ;;
        --no-digits) USE_DIGITS=false; shift ;;
        --no-symbols) USE_SYMBOLS=false; shift ;;
        --only-hex) ONLY_HEX=true; shift ;;
        --passphrase) PASSPHRASE=true; shift ;;
        --check) CHECK_PASS="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  password-gen.sh — Gerador de senhas configuravel"
            echo ""
            echo "  Uso: ./password-gen.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -l, --length N      Comprimento (padrao: 16)"
            echo "    -n, --count N       Quantidade (padrao: 1)"
            echo "    --no-upper          Sem maiusculas"
            echo "    --no-lower          Sem minusculas"
            echo "    --no-digits         Sem digitos"
            echo "    --no-symbols        Sem simbolos"
            echo "    --only-hex          Apenas hex"
            echo "    --passphrase        Gera passphrase"
            echo "    --check SENHA       Verifica forca"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./password-gen.sh -l 20 -n 5"
            echo "    ./password-gen.sh --passphrase -l 4"
            echo "    ./password-gen.sh --check 'minhasenha123'"
            echo ""
            exit 0
            ;;
        --version|-v) echo "password-gen.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

if [ -n "$CHECK_PASS" ]; then
    echo ""
    echo -e "  ${BOLD}── Verificacao de Forca ──${RESET}"
    echo ""
    pass="$CHECK_PASS"
    len=${#pass}

    score=0
    [ $len -ge 8 ]  && score=$((score + 1))
    [ $len -ge 12 ] && score=$((score + 1))
    [ $len -ge 16 ] && score=$((score + 1))
    [ $len -ge 20 ] && score=$((score + 1))

    echo "$pass" | grep -q '[a-z]' && score=$((score + 1)) && has_lower=true || has_lower=false
    echo "$pass" | grep -q '[A-Z]' && score=$((score + 1)) && has_upper=true || has_upper=false
    echo "$pass" | grep -q '[0-9]' && score=$((score + 1)) && has_digits=true || has_digits=false
    echo "$pass" | grep -q '[^a-zA-Z0-9]' && score=$((score + 1)) && has_symbols=true || has_symbols=false

    echo -e "  Comprimento: ${len} caracteres"
    echo -e "  Minusculas:  $( $has_lower && echo "${GREEN}sim${RESET}" || echo "${RED}nao${RESET}" )"
    echo -e "  Maiusculas:  $( $has_upper && echo "${GREEN}sim${RESET}" || echo "${RED}nao${RESET}" )"
    echo -e "  Digitos:     $( $has_digits && echo "${GREEN}sim${RESET}" || echo "${RED}nao${RESET}" )"
    echo -e "  Simbolos:    $( $has_symbols && echo "${GREEN}sim${RESET}" || echo "${RED}nao${RESET}" )"
    echo ""

    max_score=9
    pct=$((score * 100 / max_score))

    if [ $pct -ge 80 ]; then
        strength="${GREEN}${BOLD}FORTE${RESET}"
    elif [ $pct -ge 50 ]; then
        strength="${YELLOW}${BOLD}MEDIA${RESET}"
    else
        strength="${RED}${BOLD}FRACA${RESET}"
    fi

    echo -e "  Forca: ${strength} (${score}/${max_score})"
    echo ""
    exit 0
fi

if $ONLY_HEX; then
    CHARSET="0123456789abcdef"
elif $PASSPHRASE; then
    WORDLIST=(
        acertar ajustes alameda alfaces algumar andares bananal barulho bolsos borracha
        cachaça caderno calçada caminho cancelas cartões cidade coelho comidas
        dançar descansar deduzir defeitos desktop diagramas digitos
        eclipses editor elegante embutido energia escrever esperto estrela
        fabrica faminto fantasia favorito feitiço festival figuras formatar
        galinheiro girassois gostoso granola gregos guardana
        harvest harpa healer herança homens hortalica
        injected insertar inocente inspirar installar integer
        jardim janela jantar jazidas joaninha jornais justifica
        lambida lanternas latidos liderar limonada logical lousa luneta
        maciço madrugada magnetizar maltratar manobras marciano medianas
        navegar neblina negrito nenhumas noturno novelo numerica
        objetos obscuro ocupado oficial orbitas origami orgão
    )
else
    CHARSET=""
    $USE_LOWER  && CHARSET="${CHARSET}abcdefghijklmnopqrstuvwxyz"
    $USE_UPPER  && CHARSET="${CHARSET}ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $USE_DIGITS && CHARSET="${CHARSET}0123456789"
    $USE_SYMBOLS && CHARSET="${CHARSET}!@#$%^&*()-_=+[]{}|;:,.<>?"
fi

generate_password() {
    local len=$1
    local charset=$2
    local cset_len=${#charset}
    local password=""

    if [ -r /dev/urandom ]; then
        for ((i=0; i<len; i++)); do
            idx=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
            idx=$((idx % cset_len))
            password="${password}${charset:$idx:1}"
        done
    else
        for ((i=0; i<len; i++)); do
            idx=$((RANDOM % cset_len))
            password="${password}${charset:$idx:1}"
        done
    fi
    echo "$password"
}

generate_passphrase() {
    local word_count=$1
    local num_words=${#WORDLIST[@]}
    local phrase=""

    for ((i=0; i<word_count; i++)); do
        if [ -r /dev/urandom ]; then
            idx=$(od -An -N2 -tu2 /dev/urandom | tr -d ' ')
            idx=$((idx % num_words))
        else
            idx=$((RANDOM % num_words))
        fi
        word="${WORDLIST[$idx]}"
        word=$(echo "$word" | sed 's/./\U&/')
        if [ -n "$phrase" ]; then
            phrase="${phrase}-${word}"
        else
            phrase="$word"
        fi
    done
    echo "$phrase"
}

echo ""
echo -e "  ${BOLD}── Password Generator ──${RESET}"
echo ""

for ((n=0; n<COUNT; n++)); do
    if $PASSPHRASE; then
        result=$(generate_passphrase "$LENGTH")
    else
        result=$(generate_password "$LENGTH" "$CHARSET")
    fi

    if [ "$COUNT" -gt 1 ]; then
        printf "  %2d) ${GREEN}${BOLD}%s${RESET}\n" "$((n + 1))" "$result"
    else
        echo -e "  ${GREEN}${BOLD}${result}${RESET}"
    fi
done

echo ""

entropy=0
if $ONLY_HEX; then
    entropy=$(echo "scale=1; $LENGTH * 4" | bc)
elif $PASSPHRASE; then
    entropy=$(echo "scale=1; $LENGTH * 13" | bc)
else
    pool_size=${#CHARSET}
    [ "$pool_size" -gt 0 ] && entropy=$(echo "scale=1; $LENGTH * (l($pool_size) / l(2))" | bc -l 2>/dev/null || echo "0")
fi
echo -e "  ${DIM}Entropia: ~${entropy} bits${RESET}"
echo ""