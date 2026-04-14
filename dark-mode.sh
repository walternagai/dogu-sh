#!/bin/bash
# dark-mode.sh — Alterna tema claro/escuro em GTK e terminais
# Uso: ./dark-mode.sh [opcoes]
# Opcoes:
#   --dark              Ativa tema escuro
#   --light             Ativa tema claro
#   --toggle            Alterna entre claro/escuro (padrao)
#   --status            Mostra tema atual
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

ACTION="toggle"

while [ $# -gt 0 ]; do
    case "$1" in
        --dark|-d) ACTION="dark"; shift ;;
        --light|-l) ACTION="light"; shift ;;
        --toggle|-t) ACTION="toggle"; shift ;;
        --status|-s) ACTION="status"; shift ;;
        --help|-h)
            echo ""
            echo "  dark-mode.sh — Alterna tema claro/escuro"
            echo ""
            echo "  Uso: ./dark-mode.sh [opcoes]"
            echo ""
            echo "  Opcoes:"
            echo "    --dark     Ativa tema escuro"
            echo "    --light    Ativa tema claro"
            echo "    --toggle   Alterna entre claro/escuro (padrao)"
            echo "    --status   Mostra tema atual"
            echo "    --help     Mostra esta ajuda"
            echo "    --version  Mostra versao"
            echo ""
            echo "  Suporta: GTK3/4 (gsettings), GNOME, Plasma, xfconf"
            echo ""
            echo "  Exemplos:"
            echo "    ./dark-mode.sh --toggle"
            echo "    ./dark-mode.sh --dark"
            echo "    ./dark-mode.sh --status"
            echo ""
            exit 0
            ;;
        --version|-v) echo "dark-mode.sh $VERSION"; exit 0 ;;
        *) echo "Opcao desconhecida: $1" >&2; exit 1 ;;
    esac
done

detect_desktop() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]'
    elif command -v gnome-shell &>/dev/null; then
        echo "gnome"
    else
        echo "unknown"
    fi
}

get_current_theme() {
    local desktop=$(detect_desktop)
    case "$desktop" in
        *gnome*|*ubuntu*|*pop*)
            if command -v gsettings &>/dev/null; then
                local pref=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")
                if echo "$pref" | grep -q "dark"; then
                    echo "dark"
                else
                    echo "light"
                fi
            else
                local theme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null || echo "")
                echo "$theme" | grep -qi "dark" && echo "dark" || echo "light"
            fi
            ;;
        *plasma*|*kde*)
            if command -v kreadconfig5 &>/dev/null; then
                local theme=$(kreadconfig5 --group KDE --key PlasmaTheme 2>/dev/null || echo "")
                echo "$theme" | grep -qi "dark" && echo "dark" || echo "light"
            else
                local theme=$(kreadconfig6 --group KDE --key PlasmaTheme 2>/dev/null || echo "")
                echo "$theme" | grep -qi "dark" && echo "dark" || echo "light"
            fi
            ;;
        *xfce*)
            if command -v xfconf-query &>/dev/null; then
                local theme=$(xfconf-query -c xsettings -p /Net/ThemeName 2>/dev/null || echo "")
                echo "$theme" | grep -qi "dark" && echo "dark" || echo "light"
            else
                echo "unknown"
            fi
            ;;
        *)
            if command -v gsettings &>/dev/null; then
                local pref=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")
                if echo "$pref" | grep -q "dark"; then
                    echo "dark"
                else
                    echo "light"
                fi
            else
                echo "unknown"
            fi
            ;;
    esac
}

set_theme() {
    local mode="$1"
    local desktop=$(detect_desktop)

    case "$desktop" in
        *gnome*|*ubuntu*|*pop*)
            if command -v gsettings &>/dev/null; then
                if [ "$mode" = "dark" ]; then
                    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
                    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
                else
                    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null
                    gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita' 2>/dev/null || true
                fi
            fi
            ;;
        *plasma*|*kde*)
            if [ "$mode" = "dark" ]; then
                command -v kwriteconfig5 &>/dev/null && kwriteconfig5 --group KDE --key PlasmaTheme "breeze-dark" 2>/dev/null
                command -v kwriteconfig6 &>/dev/null && kwriteconfig6 --group KDE --key PlasmaTheme "breeze-dark" 2>/dev/null
                command -v kwriteconfig5 &>/dev/null && kwriteconfig5 --group KDE --key ColorScheme "BreezeDark" 2>/dev/null
                command -v kwriteconfig6 &>/dev/null && kwriteconfig6 --group KDE --key ColorScheme "BreezeDark" 2>/dev/null
            else
                command -v kwriteconfig5 &>/dev/null && kwriteconfig5 --group KDE --key PlasmaTheme "breeze-light" 2>/dev/null
                command -v kwriteconfig6 &>/dev/null && kwriteconfig6 --group KDE --key PlasmaTheme "breeze-light" 2>/dev/null
                command -v kwriteconfig5 &>/dev/null && kwriteconfig5 --group KDE --key ColorScheme "BreezeLight" 2>/dev/null
                command -v kwriteconfig6 &>/dev/null && kwriteconfig6 --group KDE --key ColorScheme "BreezeLight" 2>/dev/null
            fi
            command -v qdbus &>/dev/null && qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
            ;;
        *xfce*)
            if command -v xfconf-query &>/dev/null; then
                if [ "$mode" = "dark" ]; then
                    xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird-dark" 2>/dev/null || true
                else
                    xfconf-query -c xsettings -p /Net/ThemeName -s "Greybird" 2>/dev/null || true
                fi
            fi
            ;;
        *)
            if command -v gsettings &>/dev/null; then
                if [ "$mode" = "dark" ]; then
                    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
                else
                    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
                fi
            fi
            ;;
    esac
}

case "$ACTION" in
    status)
        current=$(get_current_theme)
        desktop=$(detect_desktop)
        echo ""
        echo -e "  ${BOLD}── Theme Status ──${RESET}"
        echo ""
        if [ "$current" = "dark" ]; then
            echo -e "  Modo: ${CYAN}${BOLD}Escuro${RESET} 🌙"
        elif [ "$current" = "light" ]; then
            echo -e "  Modo: ${YELLOW}${BOLD}Claro${RESET} ☀"
        else
            echo -e "  Modo: ${DIM}Desconhecido${RESET}"
        fi
        echo -e "  Desktop: ${DIM}${desktop}${RESET}"
        echo ""
        ;;

    dark)
        set_theme "dark"
        echo -e "  ${CYAN}🌙 Tema escuro ativado${RESET}"
        ;;

    light)
        set_theme "light"
        echo -e "  ${YELLOW}☀ Tema claro ativado${RESET}"
        ;;

    toggle)
        current=$(get_current_theme)
        if [ "$current" = "dark" ]; then
            set_theme "light"
            echo -e "  ${YELLOW}☀ Tema claro ativado${RESET}"
        else
            set_theme "dark"
            echo -e "  ${CYAN}🌙 Tema escuro ativado${RESET}"
        fi
        ;;
esac