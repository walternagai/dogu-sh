#!/bin/bash
# uuid-gen.sh — Gera UUIDs v4 (um ou em lote)
# Uso: ./uuid-gen.sh [opcoes]
# Opcoes:
#   -n, --count N       Quantidade de UUIDs (padrao: 1)
#   --upper             Gera em maiusculas
#   --no-hyphen         Sem hifens
#   --format FMT        Formato: standard, urn, braced (padrao: standard)
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

COUNT=1
UPPER=false
NO_HYPHEN=false
FORMAT="standard"

while [ $# -gt 0 ]; do
    case "$1" in
        -n|--count) COUNT="$2"; shift 2 ;;
        --upper|-u) UPPER=true; shift ;;
        --no-hyphen) NO_HYPHEN=true; shift ;;
        --format|-f) FORMAT="$2"; shift 2 ;;
        --help|-h)
            echo ""
            echo "  uuid-gen.sh — Gerador de UUIDs v4"
            echo ""
            echo "  Uso: ./uuid-gen.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -n, --count N       Quantidade (padrao: 1)"
            echo "    --upper             Maiusculas"
            echo "    --no-hyphen         Sem hifens"
            echo "    --format FMT       Formato: standard, urn, braced"
            echo "    --help              Mostra esta ajuda"
            echo "    --version           Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./uuid-gen.sh"
            echo "    ./uuid-gen.sh -n 10"
            echo "    ./uuid-gen.sh -n 5 --upper --no-hyphen"
            echo "    ./uuid-gen.sh --format urn"
            echo ""
            exit 0
            ;;
        --version|-v) echo "uuid-gen.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen
    elif [ -r /dev/urandom ]; then
        local hex
        hex=$(od -N16 -tx1 -An /dev/urandom | tr -d ' \n')
        local time_low="${hex:0:8}"
        local time_mid="${hex:8:4}"
        local time_hi_and_ver="${hex:12:4}"
        local clock_seq_hi="${hex:16:2}"
        local clock_seq_lo="${hex:18:2}"
        local node="${hex:20:12}"
        time_hi_and_ver="4${time_hi_and_ver:1:3}"
        local csh_dec=$((16#$clock_seq_hi))
        csh_dec=$((csh_dec & 0x3 | 0x8))
        clock_seq_hi=$(printf '%02x' "$csh_dec")
        echo "${time_low}-${time_mid}-${time_hi_and_ver}-${clock_seq_hi}${clock_seq_lo}-${node}"
    elif command -v python3 &>/dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    else
        echo -e "${RED}Erro: uuidgen, python3 ou /dev/urandom necessarios.${RESET}" >&2
        exit 1
    fi
}

echo ""
echo -e "  ${BOLD}── UUID Generator ──${RESET}"
echo ""

for ((i=0; i<COUNT; i++)); do
    uuid=$(generate_uuid)

    if $UPPER; then
        uuid=$(echo "$uuid" | tr '[:lower:]' '[:upper:]')
    fi

    if $NO_HYPHEN; then
        uuid=$(echo "$uuid" | tr -d '-')
    fi

    case "$FORMAT" in
        urn)
            uuid="urn:uuid:${uuid}"
            ;;
        braced)
            uuid="{${uuid}}"
            ;;
    esac

    if [ "$COUNT" -gt 1 ]; then
        printf "  %3d) ${GREEN}${uuid}${RESET}\n" "$((i + 1))"
    else
        echo -e "  ${GREEN}${uuid}${RESET}"
    fi
done

echo ""