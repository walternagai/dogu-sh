#!/bin/bash
# ssh-key-manager.sh — Gerencia chaves SSH (gerar, listar, rotacionar, distribuir)
# Uso: ./ssh-key-manager.sh [opcoes]
# Opcoes:
#   --generate           Gera nova chave SSH
#   --list               Lista chaves existentes (padrao)
#   --rotate             Rotaciona chave (renomeia antiga, gera nova)
#   --deploy HOST        Distribui chave publica para host via ssh-copy-id
#   --type TYPE          Tipo de chave: ed25519 (padrao) ou rsa
#   --bits N             Bits para RSA (padrao: 4096)
#   --comment COMMENT    Comentario da chave
#   --key-path PATH      Caminho customizado da chave (padrao: ~/.ssh/id_TYPE)
#   --dry-run            Preview sem executar
#   --help               Mostra esta ajuda
#   --version            Mostra versao

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then source "$DEP_HELPER"; INSTALLER=$(detect_installer); check_and_install "ssh-keygen" "$INSTALLER openssh-client"; fi

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

ACTION="list"
KEY_TYPE="ed25519"
KEY_BITS=4096
KEY_COMMENT=""
KEY_PATH=""
DEPLOY_HOST=""
DRY_RUN=false
SSH_DIR="$HOME/.ssh"

while [ $# -gt 0 ]; do
    case "$1" in
        --generate|-g) ACTION="generate"; shift ;;
        --list|-l) ACTION="list"; shift ;;
        --rotate|-r) ACTION="rotate"; shift ;;
        --deploy|-d) ACTION="deploy"; DEPLOY_HOST="$2"; shift 2 ;;
        --type|-t) KEY_TYPE="$2"; shift 2 ;;
        --bits|-b) KEY_BITS="$2"; shift 2 ;;
        --comment|-C) KEY_COMMENT="$2"; shift 2 ;;
        --key-path|-k) KEY_PATH="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo ""
            echo "  ssh-key-manager.sh — Gerencia chaves SSH"
            echo ""
            echo "  Uso: ./ssh-key-manager.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --generate           Gera nova chave SSH"
            echo "    --list               Lista chaves existentes (padrao)"
            echo "    --rotate             Rotaciona chave (renomeia antiga, gera nova)"
            echo "    --deploy HOST        Distribui chave via ssh-copy-id"
            echo "    --type TYPE          Tipo: ed25519 (padrao) ou rsa"
            echo "    --bits N             Bits para RSA (padrao: 4096)"
            echo "    --comment COMMENT    Comentario da chave"
            echo "    --key-path PATH      Caminho customizado da chave"
            echo "    --dry-run            Preview sem executar"
            echo "    --help               Mostra esta ajuda"
            echo "    --version            Mostra versao"
            echo ""
            echo "  Exemplos:"
            echo "    ./ssh-key-manager.sh --list"
            echo "    ./ssh-key-manager.sh --generate --type ed25519"
            echo "    ./ssh-key-manager.sh --generate --type rsa --bits 4096"
            echo "    ./ssh-key-manager.sh --rotate"
            echo "    ./ssh-key-manager.sh --deploy user@host"
            echo "    ./ssh-key-manager.sh --deploy user@host --key-path ~/.ssh/id_rsa"
            echo ""
            exit 0
            ;;
        --version|-v) echo "ssh-key-manager.sh $VERSION"; exit 0 ;;
        *) echo -e "${RED}Opcao desconhecida: $1${RESET}" >&2; exit 1 ;;
    esac
done

if ! command -v ssh-keygen &>/dev/null; then
    echo -e "  ${RED}Erro: ssh-keygen nao encontrado.${RESET}" >&2
    exit 1
fi

if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
fi

if [ -z "$KEY_PATH" ]; then
    KEY_PATH="${SSH_DIR}/id_${KEY_TYPE}"
fi

if [ -z "$KEY_COMMENT" ]; then
    KEY_COMMENT="${USER}@$(hostname)-$(date +%Y%m%d)"
fi

get_fingerprint() {
    local key_file="$1"
    if [ -f "$key_file" ]; then
        ssh-keygen -lf "$key_file" 2>/dev/null
    fi
}

echo ""
echo -e "  ${BOLD}SSH Key Manager${RESET}  ${DIM}v$VERSION${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem executar"
fi

echo ""

case "$ACTION" in
    list)
        echo -e "  ${BOLD}── Chaves SSH em ${SSH_DIR} ──${RESET}"
        echo ""

        key_files=$(find "$SSH_DIR" -maxdepth 1 -name 'id_*' -not -name '*.pub' -type f 2>/dev/null | sort)
        total_keys=$(echo "$key_files" | grep -c '.' || echo 0)
        total_keys=$(echo "$total_keys" | tr -d ' ')

        if [ -z "$key_files" ] || [ "$total_keys" -eq 0 ]; then
            echo -e "  ${DIM}Nenhuma chave SSH encontrada em ${SSH_DIR}${RESET}"
            echo ""
            echo -e "  ${DIM}Use --generate para criar uma nova chave${RESET}"
        else
            printf "  %-25s %-10s %-8s %-40s %s\n" "ARQUIVO" "TIPO" "BITS" "FINGERPRINT" "COMENTARIO"
            printf "  %-25s %-10s %-8s %-40s %s\n" "───────────────────────" "────────" "──────" "────────────────────────────────────────" "──────────────"

            while IFS= read -r key_file; do
                [ -z "$key_file" ] && continue

                key_name=$(basename "$key_file")
                key_type_local="?"
                bits="?"

                fp=$(get_fingerprint "$key_file" 2>/dev/null)

                if [ -n "$fp" ]; then
                    key_type_local=$(echo "$fp" | awk '{print $2}' | tr -d '()')
                    bits=$(echo "$fp" | awk '{print $1}')
                    fingerprint=$(echo "$fp" | awk '{print $2}')
                    comment=$(echo "$fp" | cut -d' ' -f3- | cut -c1-38)
                else
                    fingerprint="—"
                    comment="—"
                fi

                has_pub=false
                if [ -f "${key_file}.pub" ]; then
                    has_pub=true
                fi

                pub_indicator="${DIM}(sem .pub)${RESET}"
                if $has_pub; then
                    pub_indicator="${GREEN}.pub${RESET}"
                fi

                printf "  %-25s %-10s %-8s %-40s %s\n" "$key_name" "$key_type_local" "$bits" "$comment" "$pub_indicator"
            done <<< "$key_files"
        fi

        echo ""

        authorized_keys="${SSH_DIR}/authorized_keys"
        if [ -f "$authorized_keys" ]; then
            ak_count=$(grep -c '^' "$authorized_keys" 2>/dev/null || echo 0)
            ak_count=$(echo "$ak_count" | tr -d ' ')
            echo -e "  ${DIM}authorized_keys: ${BOLD}$ak_count${RESET} ${DIM}chave(s) autorizada(s)${RESET}"
        fi

        known_hosts="${SSH_DIR}/known_hosts"
        if [ -f "$known_hosts" ]; then
            kh_count=$(grep -c '^' "$known_hosts" 2>/dev/null || echo 0)
            kh_count=$(echo "$kh_count" | tr -d ' ')
            echo -e "  ${DIM}known_hosts:     ${BOLD}$kh_count${RESET} ${DIM}host(s) conhecido(s)${RESET}"
        fi

        config_file="${SSH_DIR}/config"
        if [ -f "$config_file" ]; then
            host_entries=$(grep -c '^Host ' "$config_file" 2>/dev/null || echo 0)
            host_entries=$(echo "$host_entries" | tr -d ' ')
            echo -e "  ${DIM}ssh config:      ${BOLD}$host_entries${RESET} ${DIM}host(s) configurado(s)${RESET}"
        fi
        ;;

    generate)
        if [ -f "$KEY_PATH" ]; then
            echo -e "  ${YELLOW}Chave '${KEY_PATH}' ja existe.${RESET}"
            echo -e "  ${DIM}Use --rotate para rotacionar ou --key-path para outro caminho${RESET}"
            exit 1
        fi

        echo -e "  Gerando chave ${CYAN}${KEY_TYPE}${RESET} em ${BOLD}${KEY_PATH}${RESET}"
        echo -e "  Comentario: ${DIM}${KEY_COMMENT}${RESET}"
        echo ""

        gen_cmd="ssh-keygen -t $KEY_TYPE -C \"$KEY_COMMENT\" -f \"$KEY_PATH\" -N \"\""

        if [ "$KEY_TYPE" = "rsa" ]; then
            gen_cmd="ssh-keygen -t $KEY_TYPE -b $KEY_BITS -C \"$KEY_COMMENT\" -f \"$KEY_PATH\" -N \"\""
        fi

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] $gen_cmd${RESET}"
        else
            if [ "$KEY_TYPE" = "rsa" ]; then
                gen_ok=false
                ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null && gen_ok=true
            else
                gen_ok=false
                ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null && gen_ok=true
            fi

            if $gen_ok; then
                echo -e "  ${GREEN}✓${RESET} Chave gerada com sucesso"
                echo ""
                echo -e "  Privada: ${BOLD}${KEY_PATH}${RESET}"
                echo -e "  Publica: ${BOLD}${KEY_PATH}.pub${RESET}"
                echo ""
                echo -e "  Fingerprint:"
                get_fingerprint "$KEY_PATH" | while IFS= read -r line; do
                    echo -e "    ${DIM}$line${RESET}"
                done
                echo ""
                echo -e "  Chave publica:"
                cat "${KEY_PATH}.pub" 2>/dev/null | while IFS= read -r line; do
                    echo -e "    ${CYAN}$line${RESET}"
                done
            else
                echo -e "  ${RED}✗${RESET} Falha ao gerar chave"
                exit 1
            fi
        fi
        ;;

    rotate)
        printf "  Confirmar rotacao da chave ${CYAN}${KEY_PATH}${RESET}? [s/N]: "
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS])
                ;;
            *)
                echo -e "  ${DIM}Rotacao cancelada.${RESET}"
                ;;
        esac

        if [ ! -f "$KEY_PATH" ]; then
            echo -e "  ${YELLOW}Chave '${KEY_PATH}' nao encontrada. Criando nova...${RESET}"
            echo ""
            ACTION="generate"
            case "$ACTION" in
                generate)
                    if $DRY_RUN; then
                        echo -e "  ${DIM}[dry-run] Geraria nova chave ${KEY_PATH}${RESET}"
                    else
                        if [ "$KEY_TYPE" = "rsa" ]; then
                            ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null
                        else
                            ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null
                        fi
                        if [ $? -eq 0 ]; then
                            echo -e "  ${GREEN}✓${RESET} Chave gerada com sucesso"
                        fi
                    fi
                    ;;
            esac
        else
            backup_ts=$(date +%Y%m%d%H%M%S)
            backup_path="${KEY_PATH}_old_${backup_ts}"
            backup_pub_path="${KEY_PATH}.pub_old_${backup_ts}"

            echo -e "  Rotacionando chave ${CYAN}${KEY_PATH}${RESET}"
            echo ""

            if $DRY_RUN; then
                echo -e "  ${DIM}[dry-run] mv ${KEY_PATH} -> ${backup_path}${RESET}"
                echo -e "  ${DIM}[dry-run] mv ${KEY_PATH}.pub -> ${backup_pub_path}${RESET}"
                echo -e "  ${DIM}[dry-run] Geraria nova chave${RESET}"
            else
                mv "$KEY_PATH" "$backup_path" 2>/dev/null
                if [ -f "${KEY_PATH}.pub" ]; then
                    mv "${KEY_PATH}.pub" "$backup_pub_path" 2>/dev/null
                fi

                echo -e "  ${YELLOW}Chave antiga salva em: ${backup_path}${RESET}"

                if [ "$KEY_TYPE" = "rsa" ]; then
                    gen_ok=false
                    ssh-keygen -t "$KEY_TYPE" -b "$KEY_BITS" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null && gen_ok=true
                else
                    gen_ok=false
                    ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_PATH" -N "" &>/dev/null && gen_ok=true
                fi

                if $gen_ok; then
                    echo -e "  ${GREEN}✓${RESET} Nova chave gerada com sucesso"
                    echo ""
                    echo -e "  Nova fingerprint:"
                    get_fingerprint "$KEY_PATH" | while IFS= read -r line; do
                        echo -e "    ${DIM}$line${RESET}"
                    done
                    echo ""
                    echo -e "  ${DIM}Dica: use --deploy HOST para distribuir a nova chave${RESET}"
                else
                    echo -e "  ${RED}✗${RESET} Falha ao gerar nova chave. Chave antiga preservada em ${backup_path}"
                    exit 1
                fi
            fi
        fi
        ;;

    deploy)
        if [ -z "$DEPLOY_HOST" ]; then
            echo -e "  ${RED}Erro: especifique o host destino.${RESET}"
            echo -e "  ${DIM}Uso: ./ssh-key-manager.sh --deploy user@host${RESET}"
            exit 1
        fi

        pub_key="${KEY_PATH}.pub"
        if [ ! -f "$pub_key" ]; then
            echo -e "  ${RED}Chave publica nao encontrada: ${pub_key}${RESET}"
            echo -e "  ${DIM}Use --generate para criar uma chave primeiro${RESET}"
            exit 1
        fi

        echo -e "  Distribuindo chave para ${CYAN}${DEPLOY_HOST}${RESET}"
        echo -e "  Chave: ${BOLD}${pub_key}${RESET}"
        echo ""

        printf "  Confirmar deploy da chave para ${CYAN}${DEPLOY_HOST}${RESET}? [s/N]: "
        read -r confirm < /dev/tty 2>/dev/null || confirm="n"
        case "$confirm" in
            [sS])
                ;;
            *)
                echo -e "  ${DIM}Deploy cancelado.${RESET}"
                ;;
        esac

        if $DRY_RUN; then
            echo -e "  ${DIM}[dry-run] ssh-copy-id -i ${pub_key} ${DEPLOY_HOST}${RESET}"
        else
            if command -v ssh-copy-id &>/dev/null; then
                if ssh-copy-id -i "$pub_key" "$DEPLOY_HOST" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${RESET} Chave distribuida com sucesso para ${CYAN}${DEPLOY_HOST}${RESET}"
                else
                    echo -e "  ${RED}✗${RESET} Falha ao distribuir chave para ${DEPLOY_HOST}"
                    echo -e "  ${DIM}Verifique: conectividade, senha, permissões${RESET}"
                    exit 1
                fi
            else
                echo -e "  ${YELLOW}ssh-copy-id nao encontrado. Tentando metodo manual...${RESET}"
                if cat "$pub_key" | ssh "$DEPLOY_HOST" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${RESET} Chave adicionada manualmente a ${CYAN}${DEPLOY_HOST}${RESET}"
                else
                    echo -e "  ${RED}✗${RESET} Falha ao distribuir chave"
                    exit 1
                fi
            fi
        fi
        ;;
esac

echo ""
echo "  ─────────────────────────────────"
echo -e "  ${GREEN}✓ Operacao concluida${RESET}"
echo "  ─────────────────────────────────"
echo ""