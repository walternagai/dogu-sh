#!/bin/bash
# setup-workspace.sh — Multi-monitor workspace manager para Linux
# Dependencias: wmctrl, xdotool, xrandr
# Uso:
#   setup-workspace                  Menu interativo (carregar ou gravar)
#   setup-workspace <perfil>         Executa um perfil
#   setup-workspace --save <nome>    Grava o layout atual como perfil
#   setup-workspace --detect         Mostra monitores conectados
#   setup-workspace --init           Cria config editavel
#   setup-workspace --list           Lista perfis salvos
#   setup-workspace --dry-run <p>    Preview do perfil sem aplicar
#   setup-workspace --help           Mostra esta ajuda
#
# Config: ~/.config/workspace-profiles.conf
#
# Formato do config:
#   # Mapeamento de monitores (rode --detect pra ver os disponiveis)
#   monitor.1=Nome do Display
#   monitor.2=Nome do Display
#
#   # Perfis: perfil|App Name|monitor|posicao
#   # Posicoes nomeadas: left, right, full, top, bottom,
#   #   top-left, top-right, bottom-left, bottom-right
#   # Posicoes customizadas: x%,y%,w%,h%  (porcentagem da area visivel)

set -eo pipefail

DEP_HELPER="./dependency-helper.sh"
[ ! -f "$DEP_HELPER" ] && DEP_HELPER="$HOME/.local/bin/dependency-helper.sh"
if [ -f "$DEP_HELPER" ]; then
    source "$DEP_HELPER"
    INSTALLER=$(detect_installer)
    check_and_install "wmctrl" "$INSTALLER wmctrl"
    check_and_install "xdotool" "$INSTALLER xdotool"
    check_and_install "xrandr" "$INSTALLER x11-xserver-utils"
fi

VERSION="1.2.0"

GREEN='\033[1;32m'
CYAN='\033[1;36m'
DIM='\033[0;90m'
BOLD='\033[1m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

CONFIG_FILE="${WORKSPACE_CONFIG:-$HOME/.config/workspace-profiles.conf}"

TMPWORK=$(mktemp -d)
trap 'rm -rf "$TMPWORK"' EXIT

DRY_RUN=false

check_dependencies() {
    :

SKIP_PROCS="Desktop|xfce4-panel|gnome-shell|plasmashell|mate-panel|cinnamon|budgie-panel|lxpanel|tint2|polybar|i3bar|waybar|xfdesktop|nautilus-desktop|nemo-desktop|pcmanfm-desktop"

# =============================================
# Deteccao de monitores via xrandr
# =============================================

detect_displays() {
    xrandr --query 2>/dev/null | awk '
    / connected/ {
        name = $1
        for (i=1; i<=NF; i++) {
            if ($i ~ /^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/) {
                split($i, a, /[x+]/)
                w = a[1]; h = a[2]; x = a[3]; y = a[4]
                print name "|" x "|" y "|" w "|" h "|" x "|" y "|" w "|" h
                break
            }
        }
    }
    ' > "$TMPWORK/displays.txt"
}

show_displays() {
    detect_displays

    if [ ! -s "$TMPWORK/displays.txt" ]; then
        echo -e "  ${RED}Nenhum display detectado.${RESET}"
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}Monitores conectados:${RESET}"
    echo ""
    printf "  %-4s %-22s %-14s %-12s %s\n" "#" "Nome" "Resolucao" "Orientacao" "Origem"
    printf "  %-4s %-22s %-14s %-12s %s\n" "--" "--------------------" "------------" "----------" "----------"

    local idx=0
    while IFS='|' read -r name fx fy fw fh vx vy vw vh; do
        idx=$((idx + 1))
        local orient="paisagem"
        if [ "$fh" -gt "$fw" ]; then
            orient="retrato"
        fi
        printf "  %-4s %-22s %dx%-10d %-12s (%d, %d)\n" "$idx" "$name" "$fw" "$fh" "$orient" "$fx" "$fy"
    done < "$TMPWORK/displays.txt"

    echo ""
    echo -e "  ${BOLD}Para usar no config, adicione o mapeamento:${RESET}"
    echo ""

    idx=0
    while IFS='|' read -r name _ _ _ _ _ _ _ _; do
        idx=$((idx + 1))
        echo -e "  ${CYAN}monitor.${idx}=${name}${RESET}"
    done < "$TMPWORK/displays.txt"

    echo ""
    echo -e "  ${DIM}Salve em: $CONFIG_FILE${RESET}"
    echo ""
}

# =============================================
# Resolucao de display
# =============================================

resolve_display() {
    local monitor_num="$1"
    local display_name=""

    if [ -f "$CONFIG_FILE" ]; then
        display_name=$(grep "^monitor\.${monitor_num}=" "$CONFIG_FILE" 2>/dev/null | head -1 | sed 's/^monitor\.[0-9]*=//')
    fi

    local line=""

    if [ -n "$display_name" ]; then
        line=$(grep -F "$display_name" "$TMPWORK/displays.txt" 2>/dev/null | head -1)
    fi

    if [ -z "$line" ]; then
        line=$(sed -n "${monitor_num}p" "$TMPWORK/displays.txt" 2>/dev/null)
    fi

    if [ -z "$line" ]; then
        line=$(head -1 "$TMPWORK/displays.txt")
    fi

    echo "$line"
}

get_display_bounds() {
    resolve_display "$1" | awk -F'|' '{print $6, $7, $8, $9}'
}

get_display_name() {
    resolve_display "$1" | awk -F'|' '{print $1}'
}

display_name_to_config_num() {
    local target_name="$1"

    if [ -f "$CONFIG_FILE" ]; then
        while IFS= read -r line; do
            case "$line" in
                monitor.*=*)
                    local num="${line#monitor.}"
                    num="${num%%=*}"
                    local pattern="${line#*=}"
                    if echo "$target_name" | grep -qF "$pattern" 2>/dev/null; then
                        echo "$num"
                        return
                    fi
                    ;;
            esac
        done < "$CONFIG_FILE"
    fi

    local idx=0
    while IFS='|' read -r name _rest; do
        idx=$((idx + 1))
        if [ "$name" = "$target_name" ]; then
            echo "$idx"
            return
        fi
    done < "$TMPWORK/displays.txt"
    echo "1"
}

# =============================================
# Calculo de posicao
# =============================================

calculate_bounds() {
    local position="$1"
    local vx="$2" vy="$3" vw="$4" vh="$5"

    if echo "$position" | grep -qE '^[0-9]+,[0-9]+,[0-9]+,[0-9]+$'; then
        local px py pw ph
        px=$(echo "$position" | cut -d, -f1)
        py=$(echo "$position" | cut -d, -f2)
        pw=$(echo "$position" | cut -d, -f3)
        ph=$(echo "$position" | cut -d, -f4)
        awk "BEGIN {
            printf \"%d %d %d %d\",
                $vx + $vw * $px / 100,
                $vy + $vh * $py / 100,
                $vw * $pw / 100,
                $vh * $ph / 100
        }"
        return
    fi

    local half_w=$((vw / 2))
    local half_h=$((vh / 2))

    case "$position" in
        left)         echo "$vx $vy $half_w $vh" ;;
        right)        echo "$((vx + half_w)) $vy $half_w $vh" ;;
        full)         echo "$vx $vy $vw $vh" ;;
        top)          echo "$vx $vy $vw $half_h" ;;
        bottom)       echo "$vx $((vy + half_h)) $vw $half_h" ;;
        top-left)     echo "$vx $vy $half_w $half_h" ;;
        top-right)    echo "$((vx + half_w)) $vy $half_w $half_h" ;;
        bottom-left)  echo "$vx $((vy + half_h)) $half_w $half_h" ;;
        bottom-right) echo "$((vx + half_w)) $((vy + half_h)) $half_w $half_h" ;;
        *)            echo "$vx $vy $vw $vh" ;;
    esac
}

detect_position_name() {
    awk -v px="$1" -v py="$2" -v pw="$3" -v ph="$4" '
    function abs(x) { return x < 0 ? -x : x }
    BEGIN {
        t = 5
        if (abs(px)<=t && abs(py)<=t && abs(pw-100)<=t && abs(ph-100)<=t) { print "full"; exit }
        if (abs(px)<=t && abs(py)<=t && abs(pw-50)<=t  && abs(ph-100)<=t) { print "left"; exit }
        if (abs(px-50)<=t && abs(py)<=t && abs(pw-50)<=t && abs(ph-100)<=t) { print "right"; exit }
        if (abs(px)<=t && abs(py)<=t && abs(pw-100)<=t && abs(ph-50)<=t) { print "top"; exit }
        if (abs(px)<=t && abs(py-50)<=t && abs(pw-100)<=t && abs(ph-50)<=t) { print "bottom"; exit }
        if (abs(px)<=t && abs(py)<=t && abs(pw-50)<=t && abs(ph-50)<=t) { print "top-left"; exit }
        if (abs(px-50)<=t && abs(py)<=t && abs(pw-50)<=t && abs(ph-50)<=t) { print "top-right"; exit }
        if (abs(px)<=t && abs(py-50)<=t && abs(pw-50)<=t && abs(ph-50)<=t) { print "bottom-left"; exit }
        if (abs(px-50)<=t && abs(py-50)<=t && abs(pw-50)<=t && abs(ph-50)<=t) { print "bottom-right"; exit }
        printf "%d,%d,%d,%d", px, py, pw, ph
    }'
}

# =============================================
# Gestao de apps e janelas
# =============================================

app_to_command() {
    local app="$1"
    local app_lower
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    case "$app_lower" in
        "google chrome"|"chrome")   echo "google-chrome" ;;
        "firefox")                  echo "firefox" ;;
        "code"|"visual studio code") echo "code" ;;
        "obsidian")                 echo "obsidian" ;;
        "discord")                  echo "discord" ;;
        "slack")                    echo "slack" ;;
        "spotify")                  echo "spotify" ;;
        "telegram"|"telegram desktop") echo "telegram-desktop" ;;
        "thunderbird")              echo "thunderbird" ;;
        "nautilus"|"files")         echo "nautilus" ;;
        "nemo")                     echo "nemo" ;;
        "thunar")                   echo "thunar" ;;
        "terminal"|"gnome-terminal") echo "gnome-terminal" ;;
        "konsole")                  echo "konsole" ;;
        "alacritty")                echo "alacritty" ;;
        "kitty")                    echo "kitty" ;;
        "wezterm")                  echo "wezterm" ;;
        "libreoffice")              echo "libreoffice" ;;
        "gimp")                     echo "gimp" ;;
        "vlc")                      echo "vlc" ;;
        *)                          echo "$app" ;;
    esac
}

process_to_app_name() {
    local proc_class="$1"
    local proc_lower
    proc_lower=$(echo "$proc_class" | tr '[:upper:]' '[:lower:]')

    case "$proc_lower" in
        google-chrome|google-chrome-stable|chromium|chromium-browser)
            echo "Google Chrome" ;;
        firefox|firefox-esr)
            echo "Firefox" ;;
        code|vscode|codium|code-url-handler)
            echo "Code" ;;
        obsidian)
            echo "Obsidian" ;;
        discord|discordcanary|discordptb)
            echo "Discord" ;;
        slack)
            echo "Slack" ;;
        spotify)
            echo "Spotify" ;;
        telegram-desktop|telegramdesktop)
            echo "Telegram" ;;
        thunderbird)
            echo "Thunderbird" ;;
        nautilus|org.gnome.nautilus)
            echo "Nautilus" ;;
        nemo)
            echo "Nemo" ;;
        thunar|thunar-volman)
            echo "Thunar" ;;
        gnome-terminal|gnome-terminal-server|org.gnome.terminal)
            echo "Terminal" ;;
        konsole)
            echo "Konsole" ;;
        alacritty)
            echo "Alacritty" ;;
        kitty)
            echo "Kitty" ;;
        org.wezfurlong.wezterm)
            echo "WezTerm" ;;
        libreoffice*|soffice|lobase|localc|lodraw|loimpress|lowriter|lomath)
            echo "LibreOffice" ;;
        gimp|gimp-2.10)
            echo "GIMP" ;;
        vlc)
            echo "VLC" ;;
        *)
            echo "$proc_class" ;;
    esac
}

command_exists() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null
}

open_app() {
    local app="$1"
    local cmd
    cmd=$(app_to_command "$app")

    if ! command_exists "$cmd"; then
        echo -e "  ${RED}✗${RESET} $app  ${DIM}(comando '$cmd' nao encontrado)${RESET}"
        return 1
    fi

    local app_lower
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    local already_running=false
    if wmctrl -l 2>/dev/null | grep -qi "$app_lower"; then
        already_running=true
    elif pgrep -fi "$cmd" &>/dev/null; then
        already_running=true
    fi

    if $DRY_RUN; then
        if $already_running; then
            echo -e "  ${DIM}[dry-run]${RESET} $app  ${DIM}(ja rodando)${RESET}"
        else
            echo -e "  ${DIM}[dry-run]${RESET} $app  ${DIM}(seria aberto: $cmd)${RESET}"
        fi
        return 0
    fi

    if ! $already_running; then
        nohup "$cmd" &>/dev/null &
        disown
        local waited=0
        while ! wmctrl -l 2>/dev/null | grep -qi "$app_lower" && [ $waited -lt 20 ]; do
            sleep 0.5
            waited=$((waited + 1))
        done
    fi

    local pid
    pid=$(pgrep -f "$cmd" 2>/dev/null | head -1 || echo "?")
    echo -e "  ${GREEN}✓${RESET} $app  ${DIM}(pid $pid)${RESET}"
    return 0
}

get_window_count() {
    local app="$1"
    local app_lower
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')
    wmctrl -l 2>/dev/null | grep -ci "$app_lower" || echo "0"
}

create_window() {
    local app="$1"
    local cmd
    cmd=$(app_to_command "$app")
    local app_lower
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')

    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${RESET} Criar janela extra de $app"
        return 0
    fi

    case "$app_lower" in
        "google chrome"|"chrome")
            google-chrome --new-window &>/dev/null &
            disown
            ;;
        "firefox")
            firefox --new-window &>/dev/null &
            disown
            ;;
        "gnome-terminal"|"terminal")
            gnome-terminal &>/dev/null &
            disown
            ;;
        "konsole")
            konsole &>/dev/null &
            disown
            ;;
        "nautilus"|"files")
            nautilus --new-window &>/dev/null &
            disown
            ;;
        "nemo")
            nemo --new-window &>/dev/null &
            disown
            ;;
        "thunar")
            thunar --new-window &>/dev/null &
            disown
            ;;
        *)
            if command -v xdotool &>/dev/null; then
                local wid
                wid=$(xdotool search --name "$app_lower" 2>/dev/null | head -1)
                if [ -n "$wid" ]; then
                    xdotool windowactivate "$wid" 2>/dev/null
                    sleep 0.2
                    xdotool key ctrl+n 2>/dev/null
                else
                    if command_exists "$cmd"; then
                        nohup "$cmd" &>/dev/null &
                        disown
                    fi
                fi
            else
                if command_exists "$cmd"; then
                    nohup "$cmd" &>/dev/null &
                    disown
                fi
            fi
            ;;
    esac
    sleep 0.5
}

position_window() {
    local app="$1"
    local win_idx="$2"
    local x="$3" y="$4" w="$5" h="$6"

    local app_lower
    app_lower=$(echo "$app" | tr '[:upper:]' '[:lower:]')

    local wids
    wids=$(wmctrl -l 2>/dev/null | grep -i "$app_lower" | awk '{print $1}')

    local target_wid
    target_wid=$(echo "$wids" | sed -n "${win_idx}p")

    if [ -z "$target_wid" ]; then
        target_wid=$(echo "$wids" | head -1)
    fi

    if $DRY_RUN; then
        return 0
    fi

    if [ -n "$target_wid" ]; then
        wmctrl -i -r "$target_wid" -b remove,maximized_vert,maximized_horz 2>/dev/null || true
        sleep 0.1
        wmctrl -i -r "$target_wid" -e "0,$x,$y,$w,$h" 2>/dev/null
    fi
}

# =============================================
# Captura de layout
# =============================================

capture_windows() {
    wmctrl -l -G 2>/dev/null | while IFS= read -r line; do
        local wid desktop wx wy ww wh host title
        wid=$(echo "$line" | awk '{print $1}')
        desktop=$(echo "$line" | awk '{print $2}')
        wx=$(echo "$line" | awk '{print $3}')
        wy=$(echo "$line" | awk '{print $4}')
        ww=$(echo "$line" | awk '{print $5}')
        wh=$(echo "$line" | awk '{print $6}')
        host=$(echo "$line" | awk '{print $7}')
        title=$(echo "$line" | awk '{for(i=8;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

        if [ "$ww" -gt 80 ] 2>/dev/null && [ "$wh" -gt 80 ] 2>/dev/null; then
            local wm_class=""
            if command -v xprop &>/dev/null; then
                wm_class=$(xprop -id "$wid" WM_CLASS 2>/dev/null | sed 's/.*= //' | tr -d '"' | cut -d, -f2 | tr -d ' ')
            fi

            local app_name
            if [ -n "$wm_class" ]; then
                app_name=$(process_to_app_name "$wm_class")
            else
                app_name="$title"
            fi

            local skip=false
            local skip_lower
            for skip_proc in Desktop xfce4-panel gnome-shell plasmashell mate-panel cinnamon budgie-panel lxpanel tint2 polybar i3bar waybar xfdesktop nautilus-desktop nemo-desktop pcmanfm-desktop; do
                if echo "$wm_class" | grep -qi "$skip_proc" 2>/dev/null; then
                    skip=true
                    break
                fi
            done

            if ! $skip; then
                echo "$app_name|$wx|$wy|$ww|$wh" >> "$TMPWORK/all_windows.txt"
            fi
        fi
    done

    if [ -f "$TMPWORK/all_windows.txt" ]; then
        cp "$TMPWORK/all_windows.txt" "$TMPWORK/windows.txt"
    fi
}

find_display_for_point() {
    local wx="$1" wy="$2"

    local best_idx=1
    local best_name=""
    local best_dist=999999999

    local idx=0
    while IFS='|' read -r name fx fy fw fh vx vy vw vh; do
        idx=$((idx + 1))
        if [ "$wx" -ge "$fx" ] && [ "$wx" -lt "$((fx + fw))" ] && \
           [ "$wy" -ge "$fy" ] && [ "$wy" -lt "$((fy + fh))" ]; then
            echo "$idx|$name|$vx|$vy|$vw|$vh"
            return
        fi
        local cx=$((fx + fw / 2))
        local cy=$((fy + fh / 2))
        local dx=$((wx - cx))
        local dy=$((wy - cy))
        local dist=$((dx > 0 ? dx : -dx))
        dist=$((dist + (dy > 0 ? dy : -dy)))
        if [ "$dist" -lt "$best_dist" ]; then
            best_dist=$dist
            best_idx=$idx
            best_name="$name"
        fi
    done < "$TMPWORK/displays.txt"

    local vline
    vline=$(sed -n "${best_idx}p" "$TMPWORK/displays.txt")
    local vx vy vw vh
    vx=$(echo "$vline" | awk -F'|' '{print $6}')
    vy=$(echo "$vline" | awk -F'|' '{print $7}')
    vw=$(echo "$vline" | awk -F'|' '{print $8}')
    vh=$(echo "$vline" | awk -F'|' '{print $9}')
    echo "$best_idx|$best_name|$vx|$vy|$vw|$vh"
}

save_profile() {
    local profile_name="$1"

    echo ""
    echo -e "  ${DIM}Detectando monitores...${RESET}"
    detect_displays

    if [ ! -s "$TMPWORK/displays.txt" ]; then
        echo -e "  ${RED}Falha ao detectar monitores.${RESET}"
        return 1
    fi

    echo -e "  ${DIM}Capturando janelas...${RESET}"
    > "$TMPWORK/all_windows.txt"
    capture_windows

    if [ ! -s "$TMPWORK/windows.txt" ]; then
        echo -e "  ${RED}Nenhuma janela encontrada.${RESET}"
        return 1
    fi

    > "$TMPWORK/profile_lines.txt"

    echo ""
    echo -e "  ${BOLD}Layout capturado:${RESET}"
    echo ""

    while IFS='|' read -r app wx wy ww wh; do
        [ -z "$app" ] && continue

        local display_info
        display_info=$(find_display_for_point "$wx" "$wy")
        local didx dname dvx dvy dvw dvh
        IFS='|' read -r didx dname dvx dvy dvw dvh <<< "$display_info"

        local px py pw ph
        px=$(awk "BEGIN {printf \"%d\", ($wx - $dvx) * 100 / $dvw}")
        py=$(awk "BEGIN {printf \"%d\", ($wy - $dvy) * 100 / $dvh}")
        pw=$(awk "BEGIN {printf \"%d\", $ww * 100 / $dvw}")
        ph=$(awk "BEGIN {printf \"%d\", $wh * 100 / $dvh}")

        local position
        position=$(detect_position_name "$px" "$py" "$pw" "$ph")

        local config_num
        config_num=$(display_name_to_config_num "$dname")

        echo "$profile_name|$app|$config_num|$position" >> "$TMPWORK/profile_lines.txt"

        printf "  ${GREEN}✓${RESET} %-20s → ${BOLD}%-20s${RESET}  ${CYAN}%s${RESET}\n" "$app" "$dname" "$position"
    done < "$TMPWORK/windows.txt"

    local total
    total=$(wc -l < "$TMPWORK/profile_lines.txt" | tr -d ' ')
    echo ""
    echo -e "  ${BOLD}$total janelas${RESET} em ${BOLD}$(awk -F'|' '{print $3}' "$TMPWORK/profile_lines.txt" | sort -u | wc -l | tr -d ' ')${RESET} monitores"

    echo ""
    if [ -t 0 ] || [ -e /dev/tty ]; then
        printf "  Salvar perfil ${CYAN}\"$profile_name\"${RESET}? [S/n]: "
        local confirm
        read -r confirm < /dev/tty 2>/dev/null || confirm="s"
        case "$confirm" in
            [nN]*) echo -e "  ${DIM}Cancelado.${RESET}"; echo ""; return 0 ;;
        esac
    fi

    mkdir -p "$(dirname "$CONFIG_FILE")"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "# workspace-profiles.conf" > "$CONFIG_FILE"
        echo "# Formato: perfil|App Name|monitor|posicao" >> "$CONFIG_FILE"
        echo "" >> "$CONFIG_FILE"
        echo "# -- Mapeamento de monitores --" >> "$CONFIG_FILE"
        local idx=0
        while IFS='|' read -r name _ _ _ _ _ _ _ _; do
            idx=$((idx + 1))
            echo "monitor.${idx}=${name}" >> "$CONFIG_FILE"
        done < "$TMPWORK/displays.txt"
        echo "" >> "$CONFIG_FILE"
    fi

    local escaped_profile
    escaped_profile=$(printf '%s' "$profile_name" | sed 's/[.[\*^$()+?{|\\]/\\&/g')
    if grep -q "^${escaped_profile}|" "$CONFIG_FILE" 2>/dev/null; then
        local tmp_conf
        tmp_conf=$(mktemp)
        grep -v "^${escaped_profile}|" "$CONFIG_FILE" > "$tmp_conf"
        mv "$tmp_conf" "$CONFIG_FILE"
    fi

    echo "" >> "$CONFIG_FILE"
    echo "# -- $profile_name (gravado em $(date '+%Y-%m-%d %H:%M')) --" >> "$CONFIG_FILE"
    cat "$TMPWORK/profile_lines.txt" >> "$CONFIG_FILE"

    echo ""
    echo -e "  ${GREEN}✓ Perfil \"$profile_name\" salvo em $CONFIG_FILE${RESET}"
    echo -e "  ${DIM}Para restaurar: setup-workspace $profile_name${RESET}"
    echo ""
}

# =============================================
# Config e perfis
# =============================================

get_profile_lines() {
    if [ -f "$CONFIG_FILE" ]; then
        grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | grep -v '^monitor\.' | grep '|' || true
    fi
}

list_profiles_inline() {
    local profiles
    profiles=$(get_profile_lines)
    if [ -z "$profiles" ]; then
        echo ""
        return
    fi
    echo "$profiles" | awk -F'|' '{print $1}' | sort -u | paste -sd', ' -
}

list_profiles() {
    local profiles
    profiles=$(get_profile_lines)

    if [ -z "$profiles" ]; then
        return 1
    fi

    local profile_names
    profile_names=$(echo "$profiles" | awk -F'|' '{print $1}' | sort -u)

    while read -r pname; do
        [ -z "$pname" ] && continue
        apps=$(echo "$profiles" | awk -F'|' -v p="$pname" '$1 == p {print $2}' | sort -u | paste -sd', ' -)
        printf "     ${CYAN}%-12s${RESET} %s\n" "$pname" "$apps"
    done <<< "$profile_names"
    return 0
}

list_profiles_cmd() {
    local profiles
    profiles=$(get_profile_lines)

    if [ -z "$profiles" ]; then
        echo ""
        echo -e "  ${DIM}Nenhum perfil salvo.${RESET}"
        echo ""
        return 0
    fi

    echo ""
    echo -e "  ${BOLD}Perfis salvos:${RESET}"
    echo ""
    list_profiles
    echo ""
}

# =============================================
# Execucao do perfil
# =============================================

dry_run_profile() {
    local target_profile="$1"
    local all_lines
    all_lines=$(get_profile_lines)

    local profile_lines
    profile_lines=$(echo "$all_lines" | awk -F'|' -v p="$target_profile" '$1 == p')

    if [ -z "$profile_lines" ]; then
        echo ""
        echo -e "  Perfil '${RED}$target_profile${RESET}' nao encontrado."
        echo ""
        list_profiles
        return 1
    fi

    echo ""
    echo -e "  ${DIM}[DRY-RUN]${RESET} Preview do perfil: ${CYAN}$target_profile${RESET}"
    echo ""

    detect_displays

    if [ ! -s "$TMPWORK/displays.txt" ]; then
        echo -e "  ${RED}Falha ao detectar monitores.${RESET}"
        return 1
    fi

    local display_count
    display_count=$(wc -l < "$TMPWORK/displays.txt" | tr -d ' ')
    echo -e "  ${DIM}$display_count monitores detectados${RESET}"
    echo ""

    echo -e "  ${BOLD}Acoes que seriam executadas:${RESET}"
    echo ""

    while IFS='|' read -r _ app monitor position; do
        local bounds
        bounds=$(get_display_bounds "$monitor")
        local vx vy vw vh
        read -r vx vy vw vh <<< "$bounds"

        local wx wy ww wh
        read -r wx wy ww wh <<< "$(calculate_bounds "$position" "$vx" "$vy" "$vw" "$vh")"

        local display_name
        display_name=$(get_display_name "$monitor")

        echo -e "  ${DIM}[dry-run]${RESET} $app → ${BOLD}$display_name${RESET}  ${DIM}$position (${wx},${wy} ${ww}x${wh})${RESET}"
    done <<< "$profile_lines"

    echo ""
    echo -e "  ${DIM}Use '${BOLD}setup-workspace $target_profile${RESET}${DIM}' para executar.${RESET}"
    echo ""
}

run_profile() {
    local target_profile="$1"
    local all_lines
    all_lines=$(get_profile_lines)

    local profile_lines
    profile_lines=$(echo "$all_lines" | awk -F'|' -v p="$target_profile" '$1 == p')

    if [ -z "$profile_lines" ]; then
        echo ""
        echo -e "  Perfil '${RED}$target_profile${RESET}' nao encontrado."
        echo ""
        list_profiles
        exit 1
    fi

    echo ""
    echo -e "  Carregando perfil: ${CYAN}$target_profile${RESET}"

    echo -e "  ${DIM}Detectando monitores...${RESET}"
    detect_displays

    if [ ! -s "$TMPWORK/displays.txt" ]; then
        echo -e "  ${RED}Falha ao detectar monitores.${RESET}"
        exit 1
    fi

    local display_count
    display_count=$(wc -l < "$TMPWORK/displays.txt" | tr -d ' ')
    echo -e "  ${DIM}$display_count monitores detectados${RESET}"

    echo ""
    echo "  Abrindo apps..."

    local unique_apps
    unique_apps=$(echo "$profile_lines" | awk -F'|' '{print $2}' | sort -u)

    while read -r app; do
        [ -z "$app" ] && continue
        open_app "$app" || true
    done <<< "$unique_apps"

    sleep 1

    echo ""
    echo "  Preparando janelas..."

    while read -r app; do
        [ -z "$app" ] && continue
        local needed
        needed=$(echo "$profile_lines" | awk -F'|' -v a="$app" '$2 == a' | wc -l | tr -d ' ')
        local current
        current=$(get_window_count "$app")

        if [ "$current" -lt "$needed" ]; then
            local to_create=$((needed - current))
            echo -e "  ${DIM}Criando $to_create janela(s) extra de $app${RESET}"
            local i=0
            while [ $i -lt "$to_create" ]; do
                create_window "$app"
                i=$((i + 1))
            done
        fi
    done <<< "$unique_apps"

    sleep 0.5

    echo ""
    echo "  Posicionando janelas..."

    while read -r app; do
        [ -z "$app" ] && continue

        local app_entries
        app_entries=$(echo "$profile_lines" | awk -F'|' -v a="$app" '$2 == a')

        local win_idx=1
        while IFS='|' read -r _ _ monitor position; do
            local bounds
            bounds=$(get_display_bounds "$monitor")
            local vx vy vw vh
            read -r vx vy vw vh <<< "$bounds"

            local wx wy ww wh
            read -r wx wy ww wh <<< "$(calculate_bounds "$position" "$vx" "$vy" "$vw" "$vh")"

            position_window "$app" "$win_idx" "$wx" "$wy" "$ww" "$wh"

            local display_name
            display_name=$(get_display_name "$monitor")

            echo -e "  ${GREEN}✓${RESET} $app [${win_idx}] → ${BOLD}$display_name${RESET}  ${DIM}$position (${wx},${wy} ${ww}x${wh})${RESET}"

            win_idx=$((win_idx + 1))
        done <<< "$app_entries"

    done <<< "$unique_apps"

    echo ""
    echo -e "  ${GREEN}✓ Workspace \"$target_profile\" pronto.${RESET}"
    echo ""
}

# =============================================
# Gerar config
# =============================================

generate_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"

    detect_displays

    local mapping=""
    if [ -s "$TMPWORK/displays.txt" ]; then
        local idx=0
        while IFS='|' read -r name _ _ _ _ _ _ _ _; do
            idx=$((idx + 1))
            mapping="${mapping}monitor.${idx}=${name}
"
        done < "$TMPWORK/displays.txt"
    fi

    cat > "$CONFIG_FILE" <<CONF
# workspace-profiles.conf
# Formato: perfil|App Name|monitor|posicao
#
# Posicoes nomeadas:
#   left, right, full, top, bottom
#   top-left, top-right, bottom-left, bottom-right
#
# Posicoes customizadas (porcentagem da area visivel):
#   x%,y%,largura%,altura%
#   Exemplo: 0,0,100,45 = topo com 45% da altura

# -- Mapeamento de monitores --
# (rode setup-workspace --detect pra atualizar)
${mapping}
CONF

    echo ""
    echo -e "  ${GREEN}✓${RESET} Config criada em ${BOLD}$CONFIG_FILE${RESET}"

    if [ -s "$TMPWORK/displays.txt" ]; then
        echo ""
        echo -e "  Monitores detectados e mapeados:"
        local idx=0
        while IFS='|' read -r name _ _ fw fh _ _ _ _; do
            idx=$((idx + 1))
            echo -e "    ${CYAN}monitor.$idx${RESET} = $name (${fw}x${fh})"
        done < "$TMPWORK/displays.txt"
    fi

    echo ""
    echo -e "  ${DIM}Rode ${BOLD}setup-workspace${RESET}${DIM} pra gravar seu primeiro perfil.${RESET}"
    echo ""
}

# =============================================
# Menu interativo
# =============================================

interactive_menu() {
    echo ""

    local has_profiles=false
    local profile_list
    profile_list=$(list_profiles_inline)
    if [ -n "$profile_list" ]; then
        has_profiles=true
    fi

    echo -e "  ${BOLD}Setup Workspace${RESET}"
    echo ""

    if $has_profiles; then
        echo -e "  ${CYAN}1)${RESET} Carregar perfil"
        list_profiles
        echo ""
    fi

    echo -e "  ${CYAN}2)${RESET} Gravar layout atual como perfil"
    echo ""

    if $has_profiles; then
        printf "  Escolha [1/2]: "
    else
        echo -e "  ${DIM}Nenhum perfil salvo ainda.${RESET}"
        echo ""
        printf "  Pressione ENTER pra gravar o layout atual: "
    fi

    local choice
    read -r choice < /dev/tty

    case "$choice" in
        1)
            if ! $has_profiles; then
                echo -e "  ${RED}Nenhum perfil disponivel.${RESET}"
                return 1
            fi
            echo ""
            printf "  Nome do perfil: "
            local profile
            read -r profile < /dev/tty
            if [ -z "$profile" ]; then
                echo -e "  ${DIM}Cancelado.${RESET}"
                return 0
            fi
            run_profile "$profile"
            ;;
        2|"")
            echo ""
            printf "  Nome pro novo perfil: "
            local name
            read -r name < /dev/tty
            if [ -z "$name" ]; then
                echo -e "  ${DIM}Cancelado.${RESET}"
                return 0
            fi
            name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
            save_profile "$name"
            ;;
        *)
            if $has_profiles && echo "$profile_list" | grep -qw "$choice"; then
                run_profile "$choice"
            else
                echo -e "  ${RED}Opcao invalida.${RESET}"
                return 1
            fi
            ;;
    esac
}

# =============================================
# Main
# =============================================

show_help() {
    echo ""
    echo "  setup-workspace.sh — Multi-monitor workspace manager"
    echo ""
    echo "  Uso: setup-workspace [comando]"
    echo ""
    echo "  Comandos:"
    echo "    (sem args)          Menu interativo (carregar ou gravar)"
    echo "    <perfil>            Abre e posiciona apps do perfil"
    echo "    --save <nome>       Grava o layout atual como perfil"
    echo "    --detect            Mostra monitores conectados"
    echo "    --init              Cria arquivo de configuracao"
    echo "    --list              Lista perfis salvos"
    echo "    --dry-run <perfil>  Preview do perfil sem aplicar"
    echo "    --help              Mostra esta ajuda"
    echo "    --version           Mostra versao"
    echo ""
    echo "  Dependencias: wmctrl, xdotool, xrandr"
    echo ""
    echo "  Config: $CONFIG_FILE"
    echo ""
}

case "${1:-}" in
    "")
        check_dependencies
        interactive_menu
        ;;
    --detect)
        check_dependencies
        show_displays
        ;;
    --save)
        check_dependencies
        if [ -z "${2:-}" ]; then
            echo "Uso: setup-workspace --save <nome-do-perfil>"
            exit 1
        fi
        save_profile "$2"
        ;;
    --init)
        generate_config
        ;;
    --list|-l)
        list_profiles_cmd
        ;;
    --dry-run)
        check_dependencies
        if [ -z "${2:-}" ]; then
            echo "Uso: setup-workspace --dry-run <nome-do-perfil>"
            exit 1
        fi
        DRY_RUN=true
        dry_run_profile "$2"
        ;;
    --help|-h)
        show_help
        ;;
    --version|-v)
        echo "setup-workspace.sh $VERSION"
        ;;
    *)
        check_dependencies
        run_profile "$1"
        ;;
esac