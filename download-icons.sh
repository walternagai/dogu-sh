#!/bin/bash
# download-icons.sh — Baixa icones Material Design Icons (MDI) oficiais,
#   converte para PNG em multiplos tamanhos e organiza em pastas
# Uso: ./download-icons.sh [opcoes]
# Opcoes:
#   -c, --category CATS  Categorias separadas por virgula (padrao: educacao)
#   -o, --output DIR     Diretorio de saida (padrao: ./mdi-icons)
#   -s, --sizes N1,N2    Tamanhos PNG separados por virgula (padrao: 24,48,512)
#   -n, --dry-run        Simula execucao sem baixar/converter
#   --list               Lista os icones disponiveis no mapeamento
#   --list-categories    Lista as categorias disponiveis
#   --help               Mostra esta ajuda
#   --version            Mostra versao

# shellcheck disable=SC2034
# (CAT_* arrays are accessed dynamically via eval in resolve_icon_map and print_categories)
set -euo pipefail

readonly SCRIPT_VERSION="2.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ] && [[ "${1-}" != "--help" && "${1-}" != "-h" && "${1-}" != "--version" && "${1-}" != "-V" ]]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "rsvg-convert" "$INSTALLER" "librsvg2-bin"
    check_and_install "npm" "$INSTALLER" "npm"
fi

readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[1;31m'
readonly CYAN='\033[1;36m'
# shellcheck disable=SC2034
readonly BLUE='\033[1;34m'
readonly BOLD='\033[1m'
readonly DIM='\033[0;90m'
readonly RESET='\033[0m'

log()     { echo -e "${CYAN}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $1" >&2; }
error()   { echo -e "${RED}[ERROR]${RESET} $1" >&2; exit 1; }

OUTPUT_DIR=""
SIZES_STR="24,48,512"
DRY_RUN=false
LIST_ONLY=false
LIST_CATEGORIES=false
CATEGORIES_STR="educacao"

declare -A CATEGORY_NAMES=(
    [educacao]="Educacao (padrao)"
    [navegacao]="Navegacao"
    [acoes]="Acoes"
    [comunicacao]="Comunicacao"
    [conteudo]="Conteudo"
    [pessoas]="Pessoas"
    [status]="Status"
    [arquivos]="Arquivos"
    [tempo]="Tempo/Data"
    [midia]="Midia"
    [acessibilidade]="Acessibilidade"
    [transporte]="Transporte"
    [saude]="Saude/Medicina"
    [financeiro]="Financeiro"
    [seguranca]="Seguranca"
    [clima]="Clima/Natureza"
    [fotografia]="Fotografia/Imagem"
    [gaming]="Gaming"
    [rede]="Rede/Servidor"
    [setas]="Setas/Direcao"
    [audio]="Audio/Musica"
    [alimentacao]="Alimentacao"
    [casa]="Casa/Construcao"
)

declare -A CAT_EDUCACAO=(
    [anotacao]="note-edit"
    [batalha]="sword-cross"
    [cronometro]="timer"
    [estacao_A]="circle"
    [estacao_B]="adjust"
    [estacao_C]="circle-double"
    [foguete]="rocket"
    [mapa]="map"
    [relogio]="clock-outline"
    [escola]="school"
    [livro]="book-open-page-variant"
    [historias]="book-open-variant"
    [tarefa]="clipboard-text"
    [questionario]="head-question"
    [nota]="star"
    [calcular]="calculator"
    [ciencia]="flask"
    [mente]="head-lightbulb-outline"
    [ideia]="lightbulb-on"
)

declare -A CAT_NAVEGACAO=(
    [inicio]="home"
    [voltar]="arrow-left"
    [avancar]="arrow-right"
    [buscar]="magnify"
    [menu]="menu"
    [fechar]="close"
)

declare -A CAT_ACOES=(
    [adicionar]="plus"
    [editar]="pencil"
    [excluir]="delete"
    [salvar]="content-save"
    [baixar]="download"
    [enviar]="upload"
    [imprimir]="printer"
    [compartilhar]="share-variant"
    [copiar]="content-copy"
    [atualizar]="refresh"
)

declare -A CAT_COMUNICACAO=(
    [email]="email"
    [chat]="chat"
    [notificacao]="bell"
    [comunicado]="bullhorn"
    [forum]="forum"
)

declare -A CAT_CONTEUDO=(
    [texto]="format-text"
    [lista]="format-list-bulleted"
    [lista_numerada]="format-list-numbered"
    [link]="link-variant"
    [tabela]="table"
    [grafico_barra]="chart-bar"
    [grafico_pizza]="chart-pie"
    [imagem]="image"
    [video]="video"
)

declare -A CAT_PESSOAS=(
    [pessoa]="account"
    [grupo]="account-group"
    [rosto]="face-man"
    [responsavel]="account-supervisor"
)

declare -A CAT_STATUS=(
    [sucesso]="check-circle"
    [cancelar]="cancel"
    [erro]="alert-circle"
    [alerta]="alert"
    [informacao]="information"
    [ajuda]="help-circle"
    [estrela]="star"
    [curtir]="thumb-up"
    [descurtir]="thumb-down"
    [favorito]="heart"
)

declare -A CAT_ARQUIVOS=(
    [pasta]="folder"
    [documento]="file-document"
    [arquivo]="file"
    [anexo]="paperclip"
    [nuvem_enviar]="cloud-upload"
    [nuvem_baixar]="cloud-download"
)

declare -A CAT_TEMPO=(
    [evento]="calendar"
    [calendario]="calendar-month"
    [ampulheta]="timer-sand"
)

declare -A CAT_MIDIA=(
    [play]="play"
    [pausa]="pause"
    [parar]="stop"
    [proximo]="skip-next"
    [anterior]="skip-previous"
    [volume]="volume-high"
    [microfone]="microphone"
)

declare -A CAT_ACESSIBILIDADE=(
    [cadeirante]="wheelchair-accessibility"
    [olho_desligado]="eye-off"
    [maos_levantadas]="human-handsup"
    [acessibilidade]="wheelchair-accessibility"
    [texto_maior]="format-font-size-increase"
    [alto_contraste]="contrast-circle"
    [audiodescricao]="audio-video"
    [libras]="sign-language"
    [interrogacao]="help-network"
)

declare -A CAT_TRANSPORTE=(
    [carro]="car"
    [onibus]="bus"
    [trem]="train"
    [aviao]="airplane"
    [bicicleta]="bicycle"
    [moto]="motorbike"
    [barco]="ferry"
    [taxi]="taxi"
    [caminhao]="truck"
    [estacionamento]="parking"
    [gasolina]="gas-station"
    [mapa_rotas]="map-marker-path"
)

declare -A CAT_SAUDE=(
    [hospital]="hospital-box"
    [medico]="doctor"
    [remedio]="pill"
    [coracao_batendo]="heart-pulse"
    [estetoscopio]="stethoscope"
    [termometro]="thermometer"
    [sangue]="blood-bag"
    [ambulancia]="ambulance"
    [dente]="tooth"
    [idoso]="human-cane"
)

declare -A CAT_FINANCEIRO=(
    [dinheiro]="cash"
    [cartao]="credit-card"
    [banco]="bank"
    [moeda_dolar]="currency-usd"
    [grafico_linha]="chart-line"
    [receita]="cash-plus"
    [despesa]="cash-minus"
    [boleto]="receipt-text"
    [porcentagem]="percent"
    [saldo]="wallet"
)

declare -A CAT_SEGURANCA=(
    [escudo]="shield-check"
    [impressao_digital]="fingerprint"
    [cadeado]="lock"
    [chave_seg]="key"
    [camera_seg]="cctv"
    [firewall]="fire"
    [senha_seg]="form-textbox-password"
    [verificado]="check-decagram"
    [antivirus]="bug"
    [vpn]="vpn"
)

declare -A CAT_CLIMA=(
    [sol]="weather-sunny"
    [chuva]="weather-rainy"
    [arvore]="tree"
    [folha]="leaf"
    [agua]="water"
    [neve]="weather-snowy"
    [vento]="weather-windy"
    [nuvem]="cloud"
    [tempestade]="weather-lightning"
    [arcoiris]="weather-pouring"
)

declare -A CAT_FOTOGRAFIA=(
    [camera]="camera"
    [filtro]="image-filter-center-focus"
    [panorama]="panorama"
    [recorte]="crop"
    [flash]="flash"
    [galeria]="image-multiple"
    [webcam]="webcam"
    [escala_cinza]="gradient-horizontal"
    [rotacao]="rotate-right"
    [contraste]="contrast-box"
)

declare -A CAT_GAMING=(
    [controle]="controller"
    [gamepad]="gamepad-variant"
    [espada]="sword"
    [trofeu]="trophy"
    [dado]="dice-multiple"
    [quebra_cabeca]="puzzle"
    [alvo]="target"
    [vida]="heart"
    [moeda_game]="gold"
    [rank]="podium"
)

declare -A CAT_REDE=(
    [servidor]="server"
    [dns]="dns"
    [rota]="router-wireless"
    [vpn_rede]="lan"
    [nuvem_server]="cloud-sync"
    [banco_dados]="database"
    [codigo]="code-tags"
    [terminal]="console"
    [api]="api"
    [seguranca_rede]="shield-lock"
)

declare -A CAT_SETAS=(
    [seta_cima]="arrow-up"
    [seta_baixo]="arrow-down"
    [seta_direita]="arrow-right"
    [seta_esquerda]="arrow-left"
    [chevron_dir]="chevron-right"
    [chevron_esq]="chevron-left"
    [expandir]="unfold-more-horizontal"
    [recolher]="unfold-less-horizontal"
    [atualizar_set]="autorenew"
    [trocar]="swap-horizontal"
)

declare -A CAT_AUDIO=(
    [musica]="music"
    [volume_medio]="volume-medium"
    [sem_som]="volume-off"
    [fone]="headphones"
    [alto_falante]="speaker"
    [playlist]="playlist-music"
    [radio]="radio"
    [microfone_grav]="microphone"
    [nota_musical]="music-note"
    [equalizador]="equalizer"
)

declare -A CAT_ALIMENTACAO=(
    [comida]="food"
    [cafe]="coffee"
    [cerveja]="beer"
    [fruta]="fruit-cherries"
    [garfo_faca]="silverware-fork-knife"
    [bolo]="cake"
    [pimenta]="chili-mild"
    [copo]="cup"
    [garrafa]="bottle-soda"
    [restaurante]="store"
)

declare -A CAT_CASA=(
    [casa]="home-city"
    [martelo]="hammer"
    [cano]="pipe"
    [parede]="wall"
    [chave_fenda]="screwdriver"
    [balanca]="scale"
    [escada]="stairs"
    [porta]="door-open"
    [janela]="window-open"
    [ferramentas]="tools"
)

resolve_icon_map() {
    local cats_str="$1"
    declare -gA FILTERED_MAP=()

    if [[ "$cats_str" == "todos" ]]; then
        cats_str="educacao,navegacao,acoes,comunicacao,conteudo,pessoas,status,arquivos,tempo,midia,acessibilidade,transporte,saude,financeiro,seguranca,clima,fotografia,gaming,rede,setas,audio,alimentacao,casa"
    fi

    local saved_ifs="$IFS"
    IFS=',' read -ra CAT_LIST <<< "$cats_str"
    IFS="$saved_ifs"

    for cat_key in "${CAT_LIST[@]}"; do
        local normalized_key
        normalized_key=$(echo "$cat_key" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

        if [[ -z "${CATEGORY_NAMES[$normalized_key]+_}" ]]; then
            error "Categoria desconhecida: '${cat_key}'. Use --list-categories para ver as disponiveis."
        fi

        local var_name="CAT_${normalized_key^^}"

        for entry in $(eval "echo \${!${var_name}[@]}"); do
            local mdi_name
            mdi_name="$(eval "echo \${${var_name}[$entry]}")"
            FILTERED_MAP["$entry"]="$mdi_name"
        done
    done
}

print_categories() {
    echo ""
    echo -e "  ${BOLD}── Categorias disponiveis ──${RESET}"
    echo ""

    local all_cats="educacao navegacao acoes comunicacao conteudo pessoas status arquivos tempo midia acessibilidade transporte saude financeiro seguranca clima fotografia gaming rede setas audio alimentacao casa"

    for cat_key in $all_cats; do
        local cat_name="${CATEGORY_NAMES[$cat_key]}"
        local var_name="CAT_${cat_key^^}"
        local count
        count=$(eval "echo \${#${var_name}[@]}")
        local is_default=""
        if [[ "$cat_key" == "educacao" ]]; then
            is_default=" ${DIM}(padrao)${RESET}"
        fi
        printf "  ${CYAN}%-16s${RESET} ${BOLD}%2d${RESET} icones  %s\n" "$cat_key" "$count" "${cat_name}${is_default}"
    done

    echo ""
    echo -e "  ${DIM}Use --category <categoria> ou --category cat1,cat2,cat3${RESET}"
    echo -e "  ${DIM}Use --category todos para baixar todas as categorias${RESET}"
    echo ""
}

print_icons_list() {
    echo ""
    echo -e "  ${BOLD}── Icones disponiveis por categoria ──${RESET}"
    echo ""

    local cats_expand="$CATEGORIES_STR"
    if [[ "$cats_expand" == "todos" ]]; then
        cats_expand="educacao,navegacao,acoes,comunicacao,conteudo,pessoas,status,arquivos,tempo,midia,acessibilidade,transporte,saude,financeiro,seguranca,clima,fotografia,gaming,rede,setas,audio,alimentacao,casa"
    fi

    local saved_ifs="$IFS"
    IFS=',' read -ra CAT_LIST <<< "$cats_expand"
    IFS="$saved_ifs"

    local total=0
    local cat_count=${#CAT_LIST[@]}

    for cat_key in "${CAT_LIST[@]}"; do
        local normalized_key
        normalized_key=$(echo "$cat_key" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')

        if [[ -z "${CATEGORY_NAMES[$normalized_key]+_}" ]]; then
            continue
        fi

        local cat_name="${CATEGORY_NAMES[$normalized_key]}"
        echo -e "  ${CYAN}━━━ ${cat_name} (${normalized_key}) ━━━${RESET}"

        local var_name="CAT_${normalized_key^^}"
        local i=1
        for entry in $(eval "echo \${!${var_name}[@]}" | tr ' ' '\n' | sort); do
            local mdi_name
            mdi_name="$(eval "echo \${${var_name}[$entry]}")"
            printf "  ${DIM}%2d${RESET}  ${BOLD}%-24s${RESET} ${DIM}->${RESET} %s\n" "$i" "$entry" "$mdi_name"
            i=$((i + 1))
            total=$((total + 1))
        done
        echo ""
    done

    echo -e "  ${DIM}Total: ${total} icones em ${cat_count} categoria(s)${RESET}"
    echo ""
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--category)
            [[ -z "${2-}" ]] && error "Flag --category requer um valor"
            CATEGORIES_STR="$2"; shift 2 ;;
        -o|--output)
            [[ -z "${2-}" ]] && error "Flag --output requer um valor"
            OUTPUT_DIR="$2"; shift 2 ;;
        -s|--sizes)
            [[ -z "${2-}" ]] && error "Flag --sizes requer um valor"
            SIZES_STR="$2"; shift 2 ;;
        -n|--dry-run) DRY_RUN=true; shift ;;
        --list) LIST_ONLY=true; shift ;;
        --list-categories) LIST_CATEGORIES=true; shift ;;
        --help|-h)
            echo ""
            echo -e "  ${BOLD}download-icons.sh${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
            echo ""
            echo "  Baixa icones Material Design Icons (MDI) e converte para PNG."
            echo ""
            echo "  Uso: ./download-icons.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    -c, --category CATS  Categorias separadas por virgula (padrao: educacao)"
            echo "    -o, --output DIR     Diretorio de saida (padrao: ./mdi-icons)"
            echo "    -s, --sizes N1,N2    Tamanhos PNG separados por virgula (padrao: 24,48,512)"
            echo "    -n, --dry-run        Simula execucao sem baixar/converter"
            echo "    --list               Lista os icones disponiveis no mapeamento"
            echo "    --list-categories    Lista as categorias disponiveis"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Categorias disponiveis:"
            echo "    educacao, navegacao, acoes, comunicacao, conteudo, pessoas,"
            echo "    status, arquivos, tempo, midia, acessibilidade, transporte,"
            echo "    saude, financeiro, seguranca, clima, fotografia, gaming,"
            echo "    rede, setas, audio, alimentacao, casa, todos"
            echo ""
            echo "  Exemplos:"
            echo "    ./download-icons.sh                           # categoria padrao (educacao)"
            echo "    ./download-icons.sh -c navegacao,acoes        # multiplas categorias"
            echo "    ./download-icons.sh -c todos                   # todas as categorias"
            echo "    ./download-icons.sh --list                      # lista icones da categoria padrao"
            echo "    ./download-icons.sh -c todos --list             # lista todos os icones"
            echo "    ./download-icons.sh --list-categories           # lista categorias"
            echo "    ./download-icons.sh -c saude -o ./icones-saude"
            echo ""
            exit 0
            ;;
        --version|-V) echo "download-icons.sh $SCRIPT_VERSION"; exit 0 ;;
        --) shift; break ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 2 ;;
    esac
done

if $LIST_CATEGORIES; then
    print_categories
    exit 0
fi

if $LIST_ONLY; then
    print_icons_list
    exit 0
fi

OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/mdi-icons}"

IFS=',' read -ra SIZES <<< "$SIZES_STR"

resolve_icon_map "$CATEGORIES_STR"

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

create_dirs() {
    log "Criando estrutura de diretorios em ${CYAN}${OUTPUT_DIR}${RESET}..."
    mkdir -p "${OUTPUT_DIR}/SVG"
    for size in "${SIZES[@]}"; do
        mkdir -p "${OUTPUT_DIR}/PNG/${size}x${size}"
    done
}

install_mdi() {
    log "Instalando ${CYAN}@mdi/svg${RESET} (repositorio oficial Google)..."
    npm init -y --prefix "${TMPDIR_WORK}" > /dev/null 2>&1
    npm install --prefix "${TMPDIR_WORK}" @mdi/svg > /dev/null 2>&1
    MDI_REPO="${TMPDIR_WORK}/node_modules/@mdi/svg/svg"
    local total_icons
    total_icons=$(find "${MDI_REPO}" -maxdepth 1 -name '*.svg' | wc -l)
    success "Repositorio MDI carregado: ${total_icons} icones disponiveis"
}

download_and_convert() {
    echo ""
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Download e conversao de icones MDI${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    local found=0
    local missing=0
    local missing_list=""

    for name_pt in "${!FILTERED_MAP[@]}"; do
        local mdi_name="${FILTERED_MAP[$name_pt]}"
        local svg_path="${MDI_REPO}/${mdi_name}.svg"

        if [[ ! -f "${svg_path}" ]]; then
            warn "NAO ENCONTRADO: ${mdi_name}.svg (nome pt-BR: ${name_pt})"
            missing=$((missing + 1))
            missing_list="${missing_list}\n  ${RED}✗${RESET} ${name_pt} -> ${mdi_name}"
            continue
        fi

        local dest_svg="${OUTPUT_DIR}/SVG/${name_pt}.svg"

        if $DRY_RUN; then
            echo -e "  ${DIM}[Dry-run] cp ${mdi_name}.svg -> ${dest_svg}${RESET}"
        else
            cp "${svg_path}" "${dest_svg}"
        fi

        for size in "${SIZES[@]}"; do
            local dest_png="${OUTPUT_DIR}/PNG/${size}x${size}/${name_pt}.png"
            if $DRY_RUN; then
                echo -e "  ${DIM}[Dry-run] rsvg-convert ${size}x${size} -> ${dest_png}${RESET}"
            else
                rsvg-convert -w "${size}" -h "${size}" "${dest_svg}" \
                    -o "${dest_png}" 2>/dev/null
            fi
        done

        found=$((found + 1))
    done

    echo ""
    echo -e "  ${DIM}────────────────────────────────────────────${RESET}"
    echo ""
    success "Icones baixados e convertidos: ${found}"
    if [[ "${missing}" -gt 0 ]]; then
        warn "Icones NAO encontrados no MDI: ${missing}"
        echo -e "${missing_list}"
        echo ""
        echo -e "  ${DIM}Dica: busque nomes alternativos em https://pictogrammers.com/library/mdi/${RESET}"
    fi
    echo ""
}

print_summary() {
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "  ${BOLD}Estrutura de diretorios${RESET}"
    echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""
    echo -e "  ${CYAN}mdi-icons/${RESET}"
    echo -e "  ${CYAN}├──${RESET} SVG/"
    echo -e "  ${CYAN}│   ├──${RESET} anotacao.svg"
    echo -e "  ${CYAN}│   └──${RESET} ..."
    for size in "${SIZES[@]}"; do
        echo -e "  ${CYAN}├──${RESET} PNG/${size}x${size}/"
        echo -e "  ${CYAN}│   ├──${RESET} anotacao.png"
        echo -e "  ${CYAN}│   └──${RESET} ..."
    done
    echo ""

    local total_svgs
    total_svgs=$(find "${OUTPUT_DIR}/SVG" -maxdepth 1 -name '*.svg' 2>/dev/null | wc -l)
    echo -e "  Total de SVGs:  ${BOLD}${total_svgs}${RESET}"
    for size in "${SIZES[@]}"; do
        local total_pngs
        total_pngs=$(find "${OUTPUT_DIR}/PNG/${size}x${size}" -maxdepth 1 -name '*.png' 2>/dev/null | wc -l)
        echo -e "  Total de PNGs (${size}x${size}): ${BOLD}${total_pngs}${RESET}"
    done

    echo ""
    echo -e "  ${DIM}Categorias: ${CATEGORIES_STR}${RESET}"
    echo ""
}

main() {
    echo ""
    echo -e "  ${BOLD}Download de Icones MDI${RESET}  ${DIM}v$SCRIPT_VERSION${RESET}"
    echo -e "  ${DIM}Categoria(s): ${CATEGORIES_STR}${RESET}"
    echo ""

    create_dirs
    install_mdi
    download_and_convert
    print_summary

    echo -e "  ${GREEN}✓${RESET} Concluido com sucesso!"
    echo ""
}

main "$@"