#!/bin/bash
# clean-system.sh — Deep system cleanup (complemento ao limpar-cache)
# Uso: ./clean-system.sh
# Opcoes:
#   --dry-run       Preview sem alterar nada
#   --all           Executa tudo sem confirmacao
#   --help          Mostra esta ajuda
#   --version       Mostra versao
#
# Detecta a distro automaticamente e usa o gerenciador de pacotes correto.
# Complementar ao clean-cache.sh (que limpa caches de usuario/aplicativos).

set -eo pipefail

VERSION="1.0.0"

GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
CYAN='\033[1;36m'
BOLD='\033[1m'
DIM='\033[0;90m'
RESET='\033[0m'

DRY_RUN=false
CLEAN_ALL=false

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --all|-a) CLEAN_ALL=true; shift ;;
        --help|-h)
            echo ""
            echo "  clean-system.sh — Limpeza profunda do sistema"
            echo "  (complemento ao clean-cache.sh)"
            echo ""
            echo "  Uso: ./clean-system.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --dry-run     Preview sem alterar nada"
            echo "    --all         Executa tudo sem confirmacao"
            echo "    --help        Mostra esta ajuda"
            echo "    --version     Mostra versao"
            echo ""
            echo "  Areas limpas:"
            echo "    Pacotes orfãos (autoremove)"
            echo "    Cache de pacotes"
            echo "    Kernels antigos"
            echo "    Flatpak/Snap nao utilizados"
            echo "    Journal antigo"
            echo "    Configuracoes residuais de pacotes removidos"
            echo ""
            echo "  Suporta: Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro"
            echo ""
            echo "  Exemplos:"
            echo "    ./clean-system.sh --dry-run"
            echo "    ./clean-system.sh --all"
            echo ""
            exit 0
            ;;
        --version|-v) echo "clean-system.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

human_size() {
    local bytes=$1
    bytes=$(echo "$bytes" | tr -d '[:space:]')
    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0 B"
        return
    fi
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=1; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$((bytes / 1024)) KB"
    else
        echo "${bytes} B"
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release 2>/dev/null || true
        echo "${ID:-unknown}"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

confirm_action() {
    local label="$1"
    local detail="${2:-}"

    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-40s\n" "$label"
        if [ -n "$detail" ]; then
            echo -e "             ${DIM}$detail${RESET}"
        fi
        return 0
    fi

    if $CLEAN_ALL; then
        return 0
    fi

    if [ -n "$detail" ]; then
        printf "  %s (${DIM}%s${RESET})? [s/N]: " "$label" "$detail"
    else
        printf "  %s? [s/N]: " "$label"
    fi

    read -r confirm < /dev/tty 2>/dev/null || confirm="n"
    case "$confirm" in
        [sS]|[yY]*) return 0 ;;
        *) return 1 ;;
    esac
}

run_action() {
    local label="$1"
    shift

    if $DRY_RUN; then
        printf "  ${DIM}[dry-run]${RESET} %-40s\n" "$label"
        return 0
    fi

    "$@" 2>/dev/null
    local rc=$?

    if [ $rc -eq 0 ]; then
        printf "  ${GREEN}✓${RESET} %-40s\n" "$label"
    else
        printf "  ${RED}✗${RESET} %-40s ${DIM}(falha)${RESET}\n" "$label"
    fi

    return $rc
}

DISTRO=$(detect_distro)

echo ""
echo -e "  ${BOLD}Limpeza do Sistema${RESET}"

if $DRY_RUN; then
    echo -e "  ${YELLOW}[DRY-RUN]${RESET} Preview sem alterar nada"
fi

echo -e "  Distro detectada: ${CYAN}$DISTRO${RESET}"
echo ""

# =============================================
# Pacotes orfaos
# =============================================

echo -e "  ${BOLD}── Pacotes Orfaos ──${RESET}"
echo ""

case "$DISTRO" in
    debian|ubuntu|linuxmint|pop*|elementary|kali)
        orphans=$(apt list --installed 2>/dev/null | wc -l | tr -d ' ')

        if command -v apt-get &>/dev/null; then
            autoremove_count=$(apt-get -s autoremove 2>/dev/null | grep -c '^Remv' || echo 0)
            autoremove_count=$(echo "$autoremove_count" | tr -d '[:space:]')
            [[ "$autoremove_count" =~ ^[0-9]+$ ]] || autoremove_count=0

            if [ "$autoremove_count" -gt 0 ]; then
                echo -e "  ${YELLOW}$autoremove_count${RESET} pacote(s) orfao(s) encontrado(s)"
                apt-get -s autoremove 2>/dev/null | grep '^Remv' | while read -r line; do
                    echo -e "    ${DIM}$line${RESET}"
                done
                echo ""

                if confirm_action "Remover pacotes orfaos (apt autoremove)" "$autoremove_count pacotes"; then
                    run_action "apt autoremove" sudo apt-get autoremove -y
                fi
            else
                echo -e "  ${GREEN}✓${RESET} Nenhum pacote orfao encontrado"
            fi
        fi

        # Configuracoes residuais
        residual=$(dpkg -l 2>/dev/null | grep -c '^rc' || echo 0)
        residual=$(echo "$residual" | tr -d '[:space:]')
        [[ "$residual" =~ ^[0-9]+$ ]] || residual=0

        if [ "$residual" -gt 0 ]; then
            echo ""
            echo -e "  ${YELLOW}$residual${RESET} pacote(s) com config residual (nao removido completamente)"
            echo ""

            if confirm_action "Purgar configs residuais" "$residual pacotes"; then
                run_action "dpkg --purge residual" sudo dpkg --purge $(dpkg -l 2>/dev/null | grep '^rc' | awk '{print $2}')
            fi
        fi
        ;;

    fedora|rhel|centos|rocky|alma*)
        if command -v dnf &>/dev/null; then
            autoremove_count=$(dnf repoquery --extras 2>/dev/null | wc -l | tr -d ' ')
            [[ "$autoremove_count" =~ ^[0-9]+$ ]] || autoremove_count=0

            if [ "$autoremove_count" -gt 0 ]; then
                echo -e "  ${YELLOW}$autoremove_count${RESET} pacote(s) orfao(s)"
                echo ""

                if confirm_action "Remover pacotes orfaos (dnf autoremove)" "$autoremove_count pacotes"; then
                    run_action "dnf autoremove" sudo dnf autoremove -y
                fi
            else
                echo -e "  ${GREEN}✓${RESET} Nenhum pacote orfao"
            fi
        fi
        ;;

    arch|manjaro|endeavouros|garuda*)
        if command -v pacman &>/dev/null; then
            orphans=$(pacman -Qdtq 2>/dev/null | wc -l | tr -d ' ')
            [[ "$orphans" =~ ^[0-9]+$ ]] || orphans=0

            if [ "$orphans" -gt 0 ]; then
                echo -e "  ${YELLOW}$orphans${RESET} pacote(s) orfao(s):"
                pacman -Qdtq 2>/dev/null | while read -r pkg; do
                    echo -e "    ${DIM}$pkg${RESET}"
                done
                echo ""

                if confirm_action "Remover pacotes orfaos (pacman -Rns)" "$orphans pacotes"; then
                    run_action "pacman -Rns orphans" sudo pacman -Rns $(pacman -Qdtq) --noconfirm
                fi
            else
                echo -e "  ${GREEN}✓${RESET} Nenhum pacote orfao"
            fi
        fi
        ;;

    *)
        echo -e "  ${DIM}Distro nao suportada para autoremove automatico.${RESET}"
        ;;
esac

echo ""

# =============================================
# Cache de pacotes
# =============================================

echo -e "  ${BOLD}── Cache de Pacotes ──${RESET}"
echo ""

case "$DISTRO" in
    debian|ubuntu|linuxmint|pop*|elementary|kali)
        apt_cache_size=$(du -sb /var/cache/apt/archives 2>/dev/null | tail -1 | awk '{print $1}' | tr -d '[:space:]')
        [[ "$apt_cache_size" =~ ^[0-9]+$ ]] || apt_cache_size=0

        if [ "$apt_cache_size" -gt 0 ]; then
            cache_str=$(human_size "$apt_cache_size")
            echo -e "  Cache APT: ${RED}$cache_str${RESET}"
            echo ""

            if confirm_action "Limpar cache APT (apt clean)" "$cache_str"; then
                run_action "apt clean" sudo apt-get clean -y
            fi
        else
            echo -e "  ${GREEN}✓${RESET} Cache APT vazio"
        fi
        ;;

    fedora|rhel|centos|rocky|alma*)
        dnf_cache_size=$(du -sb /var/cache/dnf 2>/dev/null | tail -1 | awk '{print $1}' | tr -d '[:space:]')
        [[ "$dnf_cache_size" =~ ^[0-9]+$ ]] || dnf_cache_size=0

        if [ "$dnf_cache_size" -gt 0 ]; then
            cache_str=$(human_size "$dnf_cache_size")
            echo -e "  Cache DNF: ${RED}$cache_str${RESET}"
            echo ""

            if confirm_action "Limpar cache DNF" "$cache_str"; then
                run_action "dnf clean all" sudo dnf clean all
            fi
        else
            echo -e "  ${GREEN}✓${RESET} Cache DNF vazio"
        fi
        ;;

    arch|manjaro|endeavouros|garuda*)
        pacman_cache_size=$(du -sb /var/cache/pacman/pkg 2>/dev/null | tail -1 | awk '{print $1}' | tr -d '[:space:]')
        [[ "$pacman_cache_size" =~ ^[0-9]+$ ]] || pacman_cache_size=0

        if [ "$pacman_cache_size" -gt 0 ]; then
            cache_str=$(human_size "$pacman_cache_size")
            installed_versions=$(pacman -Q 2>/dev/null | wc -l | tr -d ' ')
            cached_versions=$(ls /var/cache/pacman/pkg/*.pkg.tar* 2>/dev/null | wc -l | tr -d ' ')

            echo -e "  Cache Pacman: ${RED}$cache_str${RESET} ($cached_versions versoes em cache, $installed_versions instaladas)"
            echo ""

            if command -v paccache &>/dev/null; then
                if confirm_action "Limpar cache antigo (paccache -rk1)" "mantem 1 versao antiga"; then
                    run_action "paccache -rk1" sudo paccache -rk1
                fi
            else
                if confirm_action "Limpar cache Pacman (pacman -Sc)" "$cache_str"; then
                    run_action "pacman -Sc" sudo pacman -Sc --noconfirm
                fi
            fi
        else
            echo -e "  ${GREEN}✓${RESET} Cache Pacman vazio"
        fi
        ;;
esac

echo ""

# =============================================
# Kernels antigos
# =============================================

echo -e "  ${BOLD}── Kernels Antigos ──${RESET}"
echo ""

CURRENT_KERNEL=$(uname -r)

case "$DISTRO" in
    debian|ubuntu|linuxmint|pop*|elementary|kali)
        old_kernels=$(dpkg -l 2>/dev/null | grep -E 'linux-image-[0-9]' | grep -v "$CURRENT_KERNEL" | grep -v 'linux-image-generic' | awk '{print $2}' | head -20)
        old_count=$(echo "$old_kernels" | grep -c '^linux-image' || echo 0)
        old_count=$(echo "$old_count" | tr -d '[:space:]')
        [[ "$old_count" =~ ^[0-9]+$ ]] || old_count=0

        if [ "$old_count" -gt 0 ]; then
            echo -e "  Kernel atual: ${GREEN}$CURRENT_KERNEL${RESET}"
            echo -e "  ${YELLOW}$old_count${RESET} kernel(s) antigo(s):"
            echo "$old_kernels" | while read -r k; do
                echo -e "    ${DIM}$k${RESET}"
            done
            echo ""

            if confirm_action "Remover kernels antigos" "$old_count kernels; atual: $CURRENT_KERNEL"; then
                run_action "Remover kernels antigos" sudo apt-get purge -y $old_kernels
                run_action "apt autoremove (pos-kernel)" sudo apt-get autoremove -y
            fi
        else
            echo -e "  ${GREEN}✓${RESET} Nenhum kernel antigo (atual: $CURRENT_KERNEL)"
        fi
        ;;

    fedora|rhel|centos|rocky|alma*)
        if command -v dnf &>/dev/null; then
            installed_kernels=$(rpm -qa 2>/dev/null | grep '^kernel-[0-9]' | sort)
            kernel_count=$(echo "$installed_kernels" | wc -l | tr -d ' ')
            [[ "$kernel_count" =~ ^[0-9]+$ ]] || kernel_count=0

            if [ "$kernel_count" -gt 2 ]; then
                echo -e "  Kernel atual: ${GREEN}$CURRENT_KERNEL${RESET}"
                echo -e "  ${YELLOW}$kernel_count${RESET} kernels instalados"
                echo ""

                if confirm_action "Manter apenas 2 kernels mais recentes"; then
                    run_action "dnf remove old kernels" sudo dnf remove -y $(echo "$installed_kernels" | head -n -2) --noconfirm
                fi
            else
                echo -e "  ${GREEN}✓${RESET} Apenas $kernel_count kernel(s) instalado(s) (atual: $CURRENT_KERNEL)"
            fi
        fi
        ;;

    arch|manjaro|endeavouros|garuda*)
        echo -e "  Kernel atual: ${GREEN}$CURRENT_KERNEL${RESET}"
        echo -e "  ${DIM}Arch mantem o kernel atual automaticamente.${RESET}"
        ;;

    *)
        echo -e "  Kernel atual: ${GREEN}$CURRENT_KERNEL${RESET}"
        echo -e "  ${DIM}Remocao de kernels nao suportada para esta distro.${RESET}"
        ;;
esac

echo ""

# =============================================
# Flatpak
# =============================================

echo -e "  ${BOLD}── Flatpak ──${RESET}"
echo ""

if command -v flatpak &>/dev/null; then
    unused_flatpaks=$(flatpak uninstall --unused 2>/dev/null | grep -c '^$' || true)
    flatpak_count=$(flatpak list --app 2>/dev/null | wc -l | tr -d ' ')
    [[ "$flatpak_count" =~ ^[0-9]+$ ]] || flatpak_count=0

    if [ "$flatpak_count" -gt 0 ]; then
        echo -e "  ${flatpak_count} apps Flatpak instalados"
        echo ""

        if confirm_action "Remover runtimes nao utilizados (flatpak --unused)" "libs nao usadas por apps"; then
            run_action "flatpak uninstall --unused" flatpak uninstall --unused -y
        fi
    else
        echo -e "  ${DIM}Flatpak instalado mas sem apps.${RESET}"
    fi
else
    echo -e "  ${DIM}Flatpak nao instalado.${RESET}"
fi

echo ""

# =============================================
# Snap
# =============================================

echo -e "  ${BOLD}── Snap ──${RESET}"
echo ""

if command -v snap &>/dev/null; then
    snap_count=$(snap list 2>/dev/null | wc -l | tr -d ' ')
    snap_count=$((snap_count - 1))
    [[ "$snap_count" =~ ^[0-9]+$ ]] || snap_count=0

    if [ "$snap_count" -gt 0 ]; then
        echo -e "  $snap_count snaps instalados"
        echo ""

        disabled_snaps=$(snap list --all 2>/dev/null | grep -c 'disabled' || echo 0)
        disabled_snaps=$(echo "$disabled_snaps" | tr -d '[:space:]')
        [[ "$disabled_snaps" =~ ^[0-9]+$ ]] || disabled_snaps=0

        if [ "$disabled_snaps" -gt 0 ]; then
            echo -e "  ${YELLOW}$disabled_snaps${RESET} snap(s) desabilitado(s) (versoes antigas):"
            snap list --all 2>/dev/null | grep 'disabled' | awk '{print "    " $1 " " $2 " (disabled)"}'
            echo ""

            if confirm_action "Remover snaps desabilitados" "$disabled_snaps versoes antigas"; then
                snap list --all 2>/dev/null | grep 'disabled' | awk '{print $1, $2}' | while read -r name rev; do
                    run_action "snap remove $name $rev" sudo snap remove "$name" --revision="$rev"
                done
            fi
        else
            echo -e "  ${GREEN}✓${RESET} Nenhum snap desabilitado"
        fi
    else
        echo -e "  ${DIM}Snap instalado mas sem pacotes.${RESET}"
    fi
else
    echo -e "  ${DIM}Snap nao instalado.${RESET}"
fi

echo ""

# =============================================
# Journal
# =============================================

echo -e "  ${BOLD}── Systemd Journal ──${RESET}"
echo ""

if command -v journalctl &>/dev/null; then
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?[KMGT]' | tail -1)

    if [ -n "$journal_size" ]; then
        echo -e "  Journal: ${RED}$journal_size${RESET}"
        echo ""

        if confirm_action "Limpar journal (manter 7 dias)" "vacuum-time=7d"; then
            run_action "journal vacuum" sudo journalctl --vacuum-time=7d
        fi
    else
        echo -e "  ${DIM}Nao foi possivel obter tamanho do journal.${RESET}"
    fi
else
    echo -e "  ${DIM}journalctl nao encontrado.${RESET}"
fi

echo ""

# =============================================
# Resumo
# =============================================

echo "  ─────────────────────────────────"
echo -e "  ${BOLD}Limpeza do sistema concluida${RESET}"

if $DRY_RUN; then
    echo -e "  ${DIM}Execute sem --dry-run para aplicar as limpezas.${RESET}"
fi

echo "  ─────────────────────────────────"
echo ""
echo -e "  ${DIM}Dica: rode clean-cache.sh para limpar caches de usuario/aplicativos tambem.${RESET}"
echo ""