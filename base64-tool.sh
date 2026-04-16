#!/bin/bash
# base64-tool.sh — Codifica/decodifica Base64, URL encode, hex
# Uso: ./base64-tool.sh [opcoes]
# Opcoes:
#   -e, --encode TEXT   Codifica em Base64
#   -d, --decode TEXT   Decodifica de Base64
#   --url-encode TEXT   Codifica para URL
#   --url-decode TEXT   Decodifica de URL
#   --hex-encode TEXT   Codifica para hexadecimal
#   --hex-decode HEX    Decodifica de hexadecimal
#   --file FILE         Usa conteudo de arquivo como input
#   --help              Mostra esta ajuda
#   --version           Mostra versao

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

ACTION=""
INPUT_TEXT=""
FILE_INPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -e|--encode) ACTION="encode"; INPUT_TEXT="$2"; shift 2 ;;
        -d|--decode) ACTION="decode"; INPUT_TEXT="$2"; shift 2 ;;
        --url-encode) ACTION="url-encode"; INPUT_TEXT="$2"; shift 2 ;;
        --url-decode) ACTION="url-decode"; INPUT_TEXT="$2"; shift 2 ;;
        --hex-encode) ACTION="hex-encode"; INPUT_TEXT="$2"; shift 2 ;;
        --hex-decode) ACTION="hex-decode"; INPUT_TEXT="$2"; shift 2 ;;
        --file|-f) FILE_INPUT="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  base64-tool.sh — Codifica/decodifica Base64, URL e Hex"
            echo ""
            echo "  Uso: ./base64-tool.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -e, --encode TEXT     Codifica em Base64"
            echo "    -d, --decode TEXT     Decodifica de Base64"
            echo "    --url-encode TEXT     Codifica para URL"
            echo "    --url-decode TEXT     Decodifica de URL"
            echo "    --hex-encode TEXT     Codifica para hexadecimal"
            echo "    --hex-decode HEX      Decodifica de hexadecimal"
            echo "    --file FILE           Usa arquivo como input"
            echo "    --help                Mostra esta ajuda"
            echo "    --version             Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./base64-tool.sh -e 'Hello World'"
            echo "    ./base64-tool.sh -d 'SGVsbG8gV29ybGQ='"
            echo "    ./base64-tool.sh --url-encode 'Olá mundo'"
            echo "    ./base64-tool.sh --hex-encode 'ABC'"
            echo "    ./base64-tool.sh --file dados.bin -e"
            echo ""
            exit 0
            ;;
        --version|-v) echo "base64-tool.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

get_input() {
    if [ -n "$FILE_INPUT" ]; then
        if [ ! -f "$FILE_INPUT" ]; then
            echo -e "  ${RED}Arquivo nao encontrado: $FILE_INPUT${RESET}" >&2
            exit 1
        fi
        cat "$FILE_INPUT"
    elif [ -n "$INPUT_TEXT" ]; then
        echo -n "$INPUT_TEXT"
    else
        echo -e "  ${RED}Erro: especifique o texto ou use --file.${RESET}" >&2
        exit 1
    fi
}

case "$ACTION" in
    encode)
        result=$(get_input | base64 -w0 2>/dev/null || get_input | base64)
        echo ""
        echo -e "  ${BOLD}── Base64 Encode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    decode)
        result=$(get_input | base64 -d 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo -e "  ${RED}Erro: string Base64 invalida.${RESET}"
            exit 1
        fi
        echo ""
        echo -e "  ${BOLD}── Base64 Decode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    url-encode)
        input=$(get_input)
        result=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$input', safe=''))" 2>/dev/null || \
                 php -r "echo urlencode('$input');" 2>/dev/null || \
                 echo -n "$input" | sed 's/%/%25/g; s/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/\&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s/</%3C/g; s/=/%3D/g; s/>/%3E/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\\/%5C/g; s/\]/%5D/g; s/{/%7B/g; s/|/%7C/g; s/}/%7D/g')
        echo ""
        echo -e "  ${BOLD}── URL Encode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    url-decode)
        input=$(get_input)
        result=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$input'))" 2>/dev/null || \
                 php -r "echo urldecode('$input');" 2>/dev/null || \
                 echo -n "$input" | sed 's/+/ /g; s/%\([0-9A-Fa-f][0-9A-Fa-f]\)/\\x\1/g' | xargs -0 printf '%b')
        echo ""
        echo -e "  ${BOLD}── URL Decode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    hex-encode)
        result=$(get_input | xxd -p | tr -d '\n')
        echo ""
        echo -e "  ${BOLD}── Hex Encode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    hex-decode)
        input=$(get_input)
        input=$(echo "$input" | tr -d ' ')
        result=$(echo "$input" | xxd -r -p 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo -e "  ${RED}Erro: string hexadecimal invalida.${RESET}"
            exit 1
        fi
        echo ""
        echo -e "  ${BOLD}── Hex Decode ──${RESET}"
        echo ""
        echo -e "  ${GREEN}${result}${RESET}"
        echo ""
        ;;

    *)
        echo ""
        echo -e "  ${BOLD}Base64 Tool${RESET}  ${DIM}v$VERSION${RESET}"
        echo ""
        echo -e "  ${CYAN}Selecione a operacao:${RESET}"
        echo "    1) Base64 Encode     2) Base64 Decode"
        echo "    3) URL Encode        4) URL Decode"
        echo "    5) Hex Encode        6) Hex Decode"
        echo ""
        printf "  Opcao: "
        read -r choice < /dev/tty
        printf "  Texto: "
        read -r text < /dev/tty

        case "$choice" in
            1) ACTION="encode"; INPUT_TEXT="$text" ;;
            2) ACTION="decode"; INPUT_TEXT="$text" ;;
            3) ACTION="url-encode"; INPUT_TEXT="$text" ;;
            4) ACTION="url-decode"; INPUT_TEXT="$text" ;;
            5) ACTION="hex-encode"; INPUT_TEXT="$text" ;;
            6) ACTION="hex-decode"; INPUT_TEXT="$text" ;;
            *) echo -e "  ${RED}Opcao invalida.${RESET}"; exit 1 ;;
        esac

        exec "$0" $(echo "-$ACTION" | sed 's/url-encode/--url-encode/; s/url-decode/--url-decode/; s/hex-encode/--hex-encode/; s/hex-decode/--hex-decode/; s/encode/-e/; s/decode/-d/') "$text"
        ;;
esac