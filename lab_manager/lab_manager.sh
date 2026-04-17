#!/bin/bash
# ==============================================================================
# Lab Manager - Unified Development Environment Setup
# ==============================================================================
# Manages install, configure, test, validate, and uninstall of development
# toolchains on Ubuntu and derivatives (Linux Mint, Zorin OS, Pop!_OS, etc.)
# ==============================================================================

set -uo pipefail

# ==============================================================================
# GLOBALS
# ==============================================================================

SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="$(basename "$0")"

STATE_DIR="$HOME/.lab_manager"
MANIFEST_FILE="$STATE_DIR/manifest.json"
BACKUP_DIR="$STATE_DIR/backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$STATE_DIR/lab_manager_$(date +%Y%m%d_%H%M%S).log"
VENV_BASE="$HOME/venvs"
JUPYTER_VENV="$VENV_BASE/jupyter"
AI_VENV="$VENV_BASE/ai-tools"

DOTNET_VERSION="8.0"
OPENWEBUI_PORT=3000

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNINGS=0

COMPONENTS_ALL=(base shell cpp python java dotnet nodejs rust ides browsers devtools ai docker)

# ==============================================================================
# LOGGING
# ==============================================================================

setup_logging() {
    mkdir -p "$STATE_DIR"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[FAIL]${NC}  $1"; }
log_step()    { echo -e "${CYAN}${BOLD}==>${NC} $1"; }

print_header() {
    echo ""
    echo -e "${BOLD}================================================================${NC}"
    echo -e "${BOLD} $1${NC}"
    echo -e "${BOLD}================================================================${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}--- $1 ---${NC}"
}

# ==============================================================================
# OS DETECTION
# ==============================================================================

detect_os() {
    if [ ! -f /etc/os-release ]; then
        log_error "/etc/os-release not found"
        return 1
    fi

    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${NAME:-Unknown}"
    OS_VERSION="${VERSION:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
    OS_CODENAME="${VERSION_CODENAME:-}"
    OS_UBUNTU_CODENAME="${UBUNTU_CODENAME:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_ARCH="$(dpkg --print-architecture 2>/dev/null || echo 'amd64')"

    local ubuntu_base=""
    if [ -n "$OS_UBUNTU_CODENAME" ]; then
        ubuntu_base="$OS_UBUNTU_CODENAME"
    fi

    case "$OS_ID" in
        linuxmint)
            if [[ "$OS_VERSION_ID" == "22" || "$OS_VERSION_ID" =~ ^22\. ]]; then
                ubuntu_base="noble"
            fi
            ;;
        zorin)
            if [[ "$OS_VERSION_ID" == "17" || "$OS_VERSION_ID" =~ ^17\. ]]; then
                ubuntu_base="noble"
            fi
            ;;
        pop)
            if [ -f /etc/upstream-release/lsb-release ]; then
                source /etc/upstream-release/lsb-release
                ubuntu_base="${DISTRIB_CODENAME:-}"
            fi
            ;;
    esac

    OS_UBUNTU_BASE="$ubuntu_base"

    local compatible=false
    if [[ "$OS_ID" == "ubuntu" && "$OS_VERSION_ID" == "24.04" ]]; then
        compatible=true
    elif [[ "$OS_ID_LIKE" == *"ubuntu"* && "$OS_VERSION_ID" == "24.04" ]]; then
        compatible=true
    elif [ -n "$OS_UBUNTU_BASE" ] && [[ "$OS_UBUNTU_BASE" == "noble" ]]; then
        compatible=true
    elif [[ "$OS_ID" == "linuxmint" ]] && [[ "$OS_VERSION_ID" == "22" || "$OS_VERSION_ID" =~ ^22\. ]]; then
        compatible=true
    elif [[ "$OS_ID_LIKE" == *"debian"* || "$OS_ID_LIKE" == *"ubuntu"* ]]; then
        compatible=true
    fi

    OS_COMPATIBLE="$compatible"
}

is_compatible_os() {
    detect_os
    if [ "$OS_COMPATIBLE" != "true" ]; then
        log_warn "Script optimized for Ubuntu 24.04+ and derivatives"
        log_warn "Detected: $OS_NAME $OS_VERSION_ID"
        if [ -n "$OS_UBUNTU_BASE" ]; then
            log_info "Ubuntu base: $OS_UBUNTU_BASE"
        fi
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || return 1
    fi
    log_success "System: $OS_NAME $OS_VERSION_ID"
    return 0
}

# ==============================================================================
# PREFLIGHT CHECKS
# ==============================================================================

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run as root. Use: ./$SCRIPT_NAME"
        return 1
    fi
}

check_internet() {
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        log_error "No internet connection"
        return 1
    fi
    log_success "Internet connection OK"
}

check_disk_space() {
    local avail
    avail=$(df -BG / | awk 'NR==2{print $4}' | tr -d 'G')
    if [ "${avail:-0}" -lt 10 ]; then
        log_error "Insufficient disk space (${avail}GB). Need at least 10GB."
        return 1
    fi
    log_success "Disk space: ${avail}GB available"
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log_info "Sudo password will be requested when needed"
    fi
}

run_preflight() {
    check_root || return 1
    is_compatible_os || return 1
    check_internet || return 1
    check_disk_space || return 1
    check_sudo
    log_success "All preflight checks passed"
}

# ==============================================================================
# MANIFEST STATE
# ==============================================================================

manifest_init() {
    mkdir -p "$STATE_DIR"
    if [ ! -f "$MANIFEST_FILE" ]; then
        cat > "$MANIFEST_FILE" << MANIFEST_EOF
{
  "script_version": "$SCRIPT_VERSION",
  "created": "$(date -Iseconds)",
  "updated": "$(date -Iseconds)",
  "system": {
    "id": "$OS_ID",
    "name": "$OS_NAME",
    "version_id": "$OS_VERSION_ID",
    "ubuntu_base": "$OS_UBUNTU_BASE",
    "arch": "$OS_ARCH"
  },
  "backups": [],
  "installed_components": [],
  "apt_packages": [],
  "flatpak_apps": [],
  "repos_added": [],
  "keyrings_added": [],
  "shell_config": {
    "bashrc_managed": false,
    "zshrc_managed": false,
    "zsh_installed": false,
    "oh_my_zsh_installed": false,
    "shell_default_changed": false
  },
  "venvs_created": [],
  "containers_managed": [],
  "docker_group_added": false
}
MANIFEST_EOF
        log_info "Manifest initialized: $MANIFEST_FILE"
    else
        log_info "Manifest already exists: $MANIFEST_FILE"
    fi
}

manifest_update_field() {
    local key="$1"
    local value="$2"
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg v "$value" "$key = \$v" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
    fi
}

manifest_add_to_array() {
    local key="$1"
    local value="$2"
    local is_json=false
    if [[ "$value" == "{"* || "$value" == "["* ]]; then
        is_json=true
    fi
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        if $is_json; then
            jq --argjson v "$value" "$key += [\$v]" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
        else
            jq --arg v "$value" "$key += [\$v]" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
        fi
    fi
}

manifest_remove_from_array() {
    local key="$1"
    local value="$2"
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg v "$value" "$key -= [\$v]" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
    fi
}

manifest_set_component() {
    local comp="$1"
    local status="${2:-installed}"
    if command -v jq &>/dev/null; then
        if jq -e ".installed_components[] | select(.name == \"$comp\")" "$MANIFEST_FILE" &>/dev/null; then
            return
        fi
        manifest_add_to_array "installed_components" "{\"name\":\"$comp\",\"status\":\"$status\",\"date\":\"$(date -Iseconds)\"}"
    else
        log_warn "jq not available; manifest updates limited"
    fi
}

manifest_remove_component() {
    local comp="$1"
    if command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq "del(.installed_components[] | select(.name == \"$comp\"))" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
    fi
}

manifest_is_component() {
    local comp="$1"
    if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null; then
        jq -e ".installed_components[] | select(.name == \"$comp\" and .status == \"installed\")" "$MANIFEST_FILE" &>/dev/null
    else
        return 1
    fi
}

manifest_has_oh_my_zsh() {
    if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null; then
        jq -e '.shell_config.oh_my_zsh_installed == true' "$MANIFEST_FILE" &>/dev/null
    else
        return 1
    fi
}

manifest_set_shell_field() {
    local key="$1"
    local val="$2"
    if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null; then
        local tmp
        tmp=$(mktemp)
        jq --arg v "$val" ".shell_config.$key = (\$v)" "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
    fi
}

# ==============================================================================
# BACKUP / RESTORE
# ==============================================================================

create_backup() {
    mkdir -p "$BACKUP_DIR"
    local files=("$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_aliases" "$HOME/.zshrc")
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            cp "$f" "$BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    if command -v jq &>/dev/null; then
        manifest_add_to_array "backups" "$BACKUP_DIR"
    fi
    log_success "Backup created: $BACKUP_DIR"
}

restore_config() {
    local config_file="$1"
    local target="$HOME/$config_file"
    local backup_dir
    backup_dir=$(ls -d "$STATE_DIR/backups/"* 2>/dev/null | sort -r | head -1)

    if [ -z "$backup_dir" ] || [ ! -f "$backup_dir/$config_file" ]; then
        log_warn "No backup found for $config_file"
        return 1
    fi

    cp "$backup_dir/$config_file" "$target"
    log_success "Restored $config_file from $backup_dir"
}

# ==============================================================================
# SHELL MANAGEMENT
# ==============================================================================

MANAGED_BLOCK_START="# >>> lab-manager-managed >>>"
MANAGED_BLOCK_END="# <<< lab-manager-managed <<<"

add_to_shell_rc() {
    local rc_file="$1"
    local line="$2"

    if [ ! -f "$rc_file" ]; then
        touch "$rc_file"
    fi

    if ! grep -qF "$line" "$rc_file"; then
        if ! grep -qF "$MANAGED_BLOCK_START" "$rc_file"; then
            {
                echo ""
                echo "$MANAGED_BLOCK_START"
                echo "$MANAGED_BLOCK_END"
            } >> "$rc_file"
        fi
        sed -i "/^$MANAGED_BLOCK_END$/i\\$line" "$rc_file"
    fi
}

remove_managed_block() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        sed -i "/^$MANAGED_BLOCK_START$/,/^$MANAGED_BLOCK_END$/d" "$rc_file"
        sed -i '/^$/N;/^\n$/d' "$rc_file"
    fi
}

install_zsh() {
    print_header "Installing Zsh"

    if command -v zsh &>/dev/null; then
        log_info "Zsh already installed: $(zsh --version)"
        return 0
    fi

    sudo apt install -y zsh || { log_error "Failed to install zsh"; return 1; }
    manifest_add_to_array "apt_packages" "zsh"
    manifest_set_shell_field "zsh_installed" "true"
    log_success "Zsh installed: $(zsh --version)"
}

install_oh_my_zsh() {
    print_header "Installing Oh My Zsh"

    if [ -d "$HOME/.oh-my-zsh" ]; then
        log_info "Oh My Zsh already installed"
        return 0
    fi

    if ! command -v zsh &>/dev/null; then
        log_error "Zsh must be installed first"
        return 1
    fi

    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || {
        log_error "Failed to install Oh My Zsh"
        return 1
    }

    manifest_set_shell_field "oh_my_zsh_installed" "true"
    log_success "Oh My Zsh installed"
}

configure_oh_my_zsh() {
    local zshrc="$HOME/.zshrc"
    local plugins="git docker python pip node npm rust"

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        log_warn "Oh My Zsh not installed; skipping config"
        return 1
    fi

    if [ -f "$zshrc" ]; then
        if command -v sed &>/dev/null; then
            sed -i "s/^plugins=.*/plugins=($plugins)/" "$zshrc"
        fi
        if ! grep -q "ZSH_THEME=\"robbyrussell\"" "$zshrc" && ! grep -q "^ZSH_THEME=" "$zshrc"; then
            sed -i 's/^ZSH_THEME=.*/ZSH_THEME="robbyrussell"/' "$zshrc"
        fi
    fi

    log_success "Oh My Zsh plugins configured: $plugins"
}

offer_change_shell() {
    if ! command -v zsh &>/dev/null; then
        log_warn "Zsh not installed; cannot set as default shell"
        return
    fi

    read -p "Set zsh as your default shell? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        chsh -s "$(command -v zsh)"
        if [ $? -eq 0 ]; then
            manifest_set_shell_field "shell_default_changed" "true"
            log_success "Default shell changed to zsh (effective on next login)"
        else
            log_error "Failed to change default shell"
        fi
    else
        log_info "Default shell not changed"
    fi
}

configure_shell() {
    local rc
    for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
        if [ -f "$rc" ] || [[ "$rc" == *zshrc && "$(basename "$rc")" == ".zshrc" && -d "$HOME/.oh-my-zsh" ]]; then
            touch "$rc"
            add_to_shell_rc "$rc" "alias jupyter-lab='$JUPYTER_VENV/bin/jupyter-lab'"
            add_to_shell_rc "$rc" "alias jupyter-notebook='$JUPYTER_VENV/bin/jupyter-notebook'"
        fi
    done

    if command -v zsh &>/dev/null; then
        add_to_shell_rc "$HOME/.zshrc" 'alias jupyter-lab='"'$JUPYTER_VENV/bin/jupyter-lab'"''
        add_to_shell_rc "$HOME/.zshrc" 'alias jupyter-notebook='"'$JUPYTER_VENV/bin/jupyter-notebook'"''
    fi

    manifest_set_shell_field "bashrc_managed" "true"
    if [ -f "$HOME/.zshrc" ]; then
        manifest_set_shell_field "zshrc_managed" "true"
    fi

    log_success "Shell configuration applied"
}

do_install_shell() {
    log_step "Shell & Terminal"
    install_zsh || return

    read -p "Install Oh My Zsh? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_oh_my_zsh || return
        configure_oh_my_zsh
    fi

    configure_shell
    offer_change_shell

    manifest_set_component "shell"
    log_success "Shell component installed"
}

# ==============================================================================
# HELPERS
# ==============================================================================

is_installed() { command -v "$1" &>/dev/null; }

add_apt_repo_key() {
    local url="$1"
    local dest="$2"
    curl -fsSL "$url" | sudo gpg --dearmor -o "$dest" 2>/dev/null || {
        log_warn "Failed to add repo key from $url"
        return 1
    }
    manifest_add_to_array "keyrings_added" "$dest"
}

apt_install_to_manifest() {
    local -a pkgs=("$@")
    sudo apt install -y "${pkgs[@]}" || { log_warn "Some packages may not have installed: ${pkgs[*]}"; return 0; }
    for p in "${pkgs[@]}"; do
        manifest_add_to_array "apt_packages" "$p"
    done
}

flatpak_install_to_manifest() {
    local app_id="$1"
    flatpak install flathub "$app_id" -y 2>/dev/null || { log_warn "Flatpak $app_id may not have installed"; return 0; }
    manifest_add_to_array "flatpak_apps" "$app_id"
}

add_to_all_rcs() {
    local line="$1"
    [ -f "$HOME/.bashrc" ] && add_to_shell_rc "$HOME/.bashrc" "$line"
    [ -f "$HOME/.zshrc" ] && add_to_shell_rc "$HOME/.zshrc" "$line"
}

execute_with_retry() {
    local max=3 attempt=1 rc=0
    while [ $attempt -le $max ]; do
        if "$@"; then return 0; fi
        rc=$?
        log_warn "Attempt $attempt/$max failed"
        attempt=$((attempt + 1))
        [ $attempt -le $max ] && sleep 2
    done
    log_error "Failed after $max attempts: $*"
    return $rc
}

# ==============================================================================
# INSTALL - BASE
# ==============================================================================

do_install_base() {
    print_header "Installing Base System"

    log_info "Updating package lists..."
    execute_with_retry sudo apt update

    local packages=(
        wget curl git apt-transport-https software-properties-common
        ca-certificates gnupg lsb-release build-essential
        flatpak unzip zip tar gzip vim nano htop tree jq
    )

    log_info "Installing essential packages..."
    apt_install_to_manifest "${packages[@]}"

    log_info "Configuring Flathub..."
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

    manifest_set_component "base"
    log_success "Base system installed"
}

# ==============================================================================
# INSTALL - C/C++/HPC
# ==============================================================================

do_install_cpp() {
    print_header "Installing C/C++ & HPC"

    local packages=(
        gcc g++ gdb make cmake ninja-build
        clang clang-format clang-tidy lldb valgrind
        libgomp1 libomp-dev mpich libmpich-dev openmpi-bin libopenmpi-dev
    )

    apt_install_to_manifest "${packages[@]}"

    if is_installed gcc; then log_success "GCC $(gcc -dumpversion)"; fi
    if is_installed g++; then log_success "G++ $(g++ -dumpversion)"; fi
    if is_installed clang; then log_success "Clang $(clang --version | head -1 | awk '{print $NF}')"; fi

    manifest_set_component "cpp"
    log_success "C/C++ & HPC installed"
}

# ==============================================================================
# INSTALL - PYTHON
# ==============================================================================

do_install_python() {
    print_header "Installing Python"

    local packages=(
        python3 python3-pip python3-venv python3-dev
        python3-setuptools python3-wheel
        python3-tk ipython3 python-is-python3
    )

    apt_install_to_manifest "${packages[@]}"

    if python3 -c "import tkinter" 2>/dev/null; then
        log_success "Tkinter OK"
    else
        log_warn "Tkinter may not be working"
    fi

    mkdir -p "$VENV_BASE"

    log_info "Creating Jupyter venv..."
    if [ -d "$JUPYTER_VENV" ]; then
        log_warn "Jupyter venv exists; reusing (won't overwrite)"
    else
        python3 -m venv "$JUPYTER_VENV"
        source "$JUPYTER_VENV/bin/activate"
        pip install --upgrade pip setuptools wheel
        pip install notebook jupyterlab ipython ipywidgets
        pip install numpy pandas matplotlib seaborn scipy scikit-learn
        pip install black pylint autopep8 mypy pytest
        deactivate
        manifest_add_to_array "venvs_created" "$JUPYTER_VENV"
    fi

    add_to_all_rcs "alias jupyter-lab='$JUPYTER_VENV/bin/jupyter-lab'"
    add_to_all_rcs "alias jupyter-notebook='$JUPYTER_VENV/bin/jupyter-notebook'"

    manifest_set_component "python"
    log_success "Python installed"
}

# ==============================================================================
# INSTALL - JAVA
# ==============================================================================

do_install_java() {
    print_header "Installing Java (OpenJDK 21)"

    apt_install_to_manifest "openjdk-21-jdk"

    if command -v java &>/dev/null; then
        local java_home
        java_home="$(dirname "$(dirname "$(readlink -f "$(which java)")")")"

        add_to_all_rcs "# Java Configuration"
        add_to_all_rcs "export JAVA_HOME=$java_home"
        add_to_all_rcs 'export PATH=$JAVA_HOME/bin:$PATH'

        log_success "Java $(java -version 2>&1 | head -1)"
        log_info "JAVA_HOME=$java_home"
    else
        log_warn "Java may not be installed correctly"
    fi

    manifest_set_component "java"
    log_success "Java installed"
}

# ==============================================================================
# INSTALL - .NET
# ==============================================================================

do_install_dotnet() {
    print_header "Installing .NET SDK $DOTNET_VERSION"

    sudo rm -f /etc/apt/sources.list.d/microsoft-prod.list 2>/dev/null || true

    wget -q "https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb 2>/dev/null || {
        log_warn "Failed to download Microsoft repo package"
        return 0
    }
    sudo dpkg -i /tmp/packages-microsoft-prod.deb 2>/dev/null || {
        log_warn "Failed to install Microsoft repo package"
        return 0
    }
    rm -f /tmp/packages-microsoft-prod.deb

    sudo apt update 2>/dev/null || true
    apt_install_to_manifest "dotnet-sdk-$DOTNET_VERSION"

    if is_installed dotnet; then
        log_success ".NET SDK $(dotnet --version)"
    else
        log_warn ".NET SDK not installed correctly"
    fi

    manifest_add_to_array "repos_added" "/etc/apt/sources.list.d/microsoft-prod.list"
    manifest_set_component "dotnet"
    log_success ".NET installed"
}

# ==============================================================================
# INSTALL - NODE.JS
# ==============================================================================

do_install_nodejs() {
    print_header "Installing Node.js"

    log_info "Adding NodeSource repository..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null || {
        log_warn "Failed to add NodeSource repository"
        return 0
    }

    apt_install_to_manifest "nodejs"

    if is_installed node; then
        log_success "Node.js $(node --version)"
        log_success "npm $(npm --version)"

        log_info "Installing global tools..."
        sudo npm install -g yarn pnpm typescript ts-node eslint prettier 2>/dev/null || true
    else
        log_warn "Node.js not installed correctly"
        return 0
    fi

    manifest_add_to_array "repos_added" "/etc/apt/sources.list.d/nodesource.list"
    manifest_set_component "nodejs"
    log_success "Node.js installed"
}

# ==============================================================================
# INSTALL - RUST
# ==============================================================================

do_install_rust() {
    print_header "Installing Rust"

    if is_installed rustc; then
        log_info "Rust already installed: $(rustc --version)"
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null || {
        log_warn "Rust installation may have failed"
        return 0
    }

    source "$HOME/.cargo/env" 2>/dev/null

    if is_installed rustc; then
        log_success "Rust $(rustc --version)"
        log_success "Cargo $(cargo --version)"
    else
        log_warn "Rust not installed correctly"
        return 0
    fi

    add_to_all_rcs "# Rust environment"
    add_to_all_rcs 'source "$HOME/.cargo/env"'

    manifest_set_component "rust"
    log_success "Rust installed"
}

# ==============================================================================
# INSTALL - IDEs
# ==============================================================================

do_install_ides() {
    print_header "Installing IDEs & Editors"

    apt_install_to_manifest "gedit" "geany" "mousepad" "spyder" "codeblocks"

    if ! is_installed code; then
        log_info "Installing VS Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/keyrings/microsoft-vscode.gpg 2>/dev/null
        echo "deb [arch=$OS_ARCH signed-by=/etc/apt/keyrings/microsoft-vscode.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        sudo apt update 2>/dev/null || true
        apt_install_to_manifest "code"

        if is_installed code; then
            code --install-extension ms-python.python 2>/dev/null || true
            code --install-extension ms-dotnettools.csharp 2>/dev/null || true
            code --install-extension rust-lang.rust-analyzer 2>/dev/null || true
            code --install-extension ms-vscode.cpptools 2>/dev/null || true
            code --install-extension vscjava.vscode-java-pack 2>/dev/null || true
        fi

        manifest_add_to_array "repos_added" "/etc/apt/sources.list.d/vscode.list"
        manifest_add_to_array "keyrings_added" "/etc/apt/keyrings/microsoft-vscode.gpg"
    else
        log_info "VS Code already installed"
    fi

    read -p "Install NetBeans? [y/N]: " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && flatpak_install_to_manifest "org.apache.netbeans"

    read -p "Install Eclipse? [y/N]: " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && flatpak_install_to_manifest "org.eclipse.Java"

    read -p "Install IntelliJ IDEA Community? [y/N]: " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && flatpak_install_to_manifest "com.jetbrains.IntelliJ-IDEA-Community"

    read -p "Install PyCharm Community? [y/N]: " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && flatpak_install_to_manifest "com.jetbrains.PyCharm-Community"

    manifest_set_component "ides"
    log_success "IDEs & Editors installed"
}

# ==============================================================================
# INSTALL - BROWSERS
# ==============================================================================

do_install_browsers() {
    print_header "Installing Browsers"

    if ! is_installed firefox; then
        log_info "Installing Firefox via Mozilla repo..."
        sudo install -d -m 0755 /etc/apt/keyrings 2>/dev/null || true
        wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- 2>/dev/null | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc >/dev/null 2>/dev/null || true
        echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee /etc/apt/sources.list.d/mozilla.list >/dev/null 2>/dev/null || true
        echo -e "Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000" | sudo tee /etc/apt/preferences.d/mozilla >/dev/null 2>/dev/null || true
        sudo apt update 2>/dev/null || true
        apt_install_to_manifest "firefox"

        manifest_add_to_array "repos_added" "/etc/apt/sources.list.d/mozilla.list"
        manifest_add_to_array "keyrings_added" "/etc/apt/keyrings/packages.mozilla.org.asc"
    else
        log_info "Firefox already installed"
    fi

    read -p "Install Chromium (Flatpak)? [y/N]: " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && flatpak_install_to_manifest "org.chromium.Chromium"

    read -p "Install Google Chrome? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]] && ! is_installed google-chrome; then
        wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_${OS_ARCH}.deb" -O /tmp/chrome.deb
        sudo dpkg -i /tmp/chrome.deb 2>/dev/null || sudo apt install -f -y 2>/dev/null || true
        rm -f /tmp/chrome.deb
        manifest_add_to_array "apt_packages" "google-chrome-stable"
    fi

    manifest_set_component "browsers"
    log_success "Browsers installed"
}

# ==============================================================================
# INSTALL - DEV TOOLS
# ==============================================================================

do_install_devtools() {
    print_header "Installing Dev Tools"

    local packages=(
        ripgrep fd-find bat fzf xclip shellcheck sqlite3
        httpie pipx postgresql-client redis-tools
    )
    apt_install_to_manifest "${packages[@]}"

    if ! is_installed uv; then
        curl -LsSf https://astral.sh/uv/install.sh | sh 2>/dev/null || log_warn "uv may not have installed"
        add_to_all_rcs 'export PATH="$HOME/.local/bin:$PATH"'
    fi

    if ! is_installed shfmt; then
        sudo snap install shfmt 2>/dev/null || log_warn "shfmt not available (snap not present)"
    fi

    if is_installed pipx; then
        pipx ensurepath 2>/dev/null || true
    fi

    manifest_set_component "devtools"
    log_success "Dev Tools installed"
}

# ==============================================================================
# INSTALL - AI
# ==============================================================================

do_install_ai() {
    print_header "Installing AI Tools"

    log_info "Creating AI venv..."
    if [ -d "$AI_VENV" ]; then
        log_warn "AI venv exists; reusing"
    else
        python3 -m venv "$AI_VENV"
        source "$AI_VENV/bin/activate"
        pip install --upgrade pip setuptools wheel
        pip install jupyterlab notebook ipykernel ipywidgets
        pip install numpy pandas matplotlib seaborn scipy scikit-learn
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu 2>/dev/null || pip install torch 2>/dev/null || log_warn "PyTorch may not have installed"
        pip install transformers datasets accelerate sentence-transformers
        pip install jupyterlab-lsp python-lsp-server 2>/dev/null || true
        deactivate
        manifest_add_to_array "venvs_created" "$AI_VENV"
    fi

    if is_installed pipx; then
        pipx install aider-chat 2>/dev/null || log_warn "aider-chat may not have installed"
        pipx install pre-commit 2>/dev/null || log_warn "pre-commit may not have installed"
    else
        log_warn "pipx not available; skipping aider-chat and pre-commit"
    fi

    log_info "Installing Ollama..."
    if ! is_installed ollama; then
        curl -fsSL https://ollama.com/install.sh | sh 2>/dev/null || log_warn "Ollama may not have installed"
        if is_installed ollama; then
            manifest_add_to_array "apt_packages" "ollama"
            log_success "Ollama installed"
        else
            log_warn "Ollama installation may have failed"
        fi
    else
        log_info "Ollama already installed"
    fi

    read -p "Install Open WebUI (requires Docker, port $OPENWEBUI_PORT)? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! is_installed docker; then
            log_error "Docker is required for Open WebUI. Install docker component first."
        else
            install_open_webui
        fi
    fi

    manifest_set_component "ai"
    log_success "AI Tools installed"
}

install_open_webui() {
    log_info "Deploying Open WebUI container..."
    docker run -d \
        --name open-webui \
        --restart unless-stopped \
        -p "$OPENWEBUI_PORT:8080" \
        -v open-webui-data:/app/backend/data \
        --add-host=host.docker.internal:host-gateway \
        ghcr.io/open-webui/open-webui:main 2>/dev/null || {
        log_warn "Open WebUI container may not have started"
        return 0
    }
    manifest_add_to_array "containers_managed" "open-webui"
    log_success "Open WebUI running at http://localhost:$OPENWEBUI_PORT"
}

# ==============================================================================
# INSTALL - DOCKER
# ==============================================================================

do_install_docker() {
    print_header "Installing Docker"

    if is_installed docker; then
        log_info "Docker already installed"
        manifest_set_component "docker"
        return 0
    fi

    read -p "Install Docker Engine? [y/N]: " -n 1 -r; echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then return 0; fi

    sudo install -m 0755 -d /etc/apt/keyrings 2>/dev/null || true
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null 2>/dev/null || true
    sudo chmod a+r /etc/apt/keyrings/docker.asc 2>/dev/null || true

    local codename
    if [ -n "$OS_UBUNTU_BASE" ]; then
        codename="$OS_UBUNTU_BASE"
    elif [ -n "$OS_CODENAME" ]; then
        codename="$OS_CODENAME"
    else
        codename="noble"
    fi

    echo "deb [arch=$OS_ARCH signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null 2>/dev/null || true
    sudo apt update 2>/dev/null || true
    apt_install_to_manifest "docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin"

    sudo usermod -aG docker "$USER" 2>/dev/null || true
    log_warn "Logout/login required for docker group to take effect"

    manifest_add_to_array "repos_added" "/etc/apt/sources.list.d/docker.list"
    manifest_add_to_array "keyrings_added" "/etc/apt/keyrings/docker.asc"
    manifest_update_field ".docker_group_added" "true"
    manifest_set_component "docker"
    log_success "Docker installed"
}

# ==============================================================================
# CONFIGURE GIT
# ==============================================================================

configure_git() {
    print_header "Configuring Git"

    if ! git config --global user.name &>/dev/null; then
        read -p "Git user.name: " git_name
        git config --global user.name "$git_name"
    else
        log_info "Git user.name already set: $(git config --global user.name)"
    fi

    if ! git config --global user.email &>/dev/null; then
        read -p "Git user.email: " git_email
        git config --global user.email "$git_email"
    else
        log_info "Git user.email already set: $(git config --global user.email)"
    fi

    read -p "Set git init.defaultBranch=main and core.editor=nano? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git config --global init.defaultBranch main
        git config --global core.editor nano
        log_success "Git defaults configured"
    fi
}

# ==============================================================================
# TESTS
# ==============================================================================

test_command() {
    local cmd="$1" name="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if command -v "$cmd" &>/dev/null; then
        local ver
        ver=$("$cmd" --version 2>&1 | head -1 || echo "installed")
        echo -e "  ${GREEN}[PASS]${NC} $name: $ver"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} $name: NOT INSTALLED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

test_flatpak_app() {
    local app_id="$1" name="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if flatpak list --app 2>/dev/null | grep -q "$app_id"; then
        echo -e "  ${GREEN}[PASS]${NC} Flatpak: $name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} Flatpak: $name NOT INSTALLED"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        return 1
    fi
}

test_python_import() {
    local venv="$1" module="$2" name="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ -d "$venv" ] && "$venv/bin/python" -c "import $module" &>/dev/null; then
        local ver
        ver=$("$venv/bin/python" -c "import $module; print(getattr($module, '__version__', 'installed'))" 2>/dev/null || echo "installed")
        echo -e "  ${GREEN}[PASS]${NC} Python ($name): $ver"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${YELLOW}[WARN]${NC} Python ($name): not found in $venv"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

test_service() {
    local svc="$1" name="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "  ${GREEN}[PASS]${NC} Service $name: active"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${YELLOW}[WARN]${NC} Service $name: inactive"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

test_container() {
    local cname="$1"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if command -v docker &>/dev/null && docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${cname}$"; then
        echo -e "  ${GREEN}[PASS]${NC} Container $cname: running"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${YELLOW}[WARN]${NC} Container $cname: not running"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

test_shell_config() {
    local rc="$1" name="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ -f "$rc" ] && grep -q "$MANAGED_BLOCK_START" "$rc"; then
        echo -e "  ${GREEN}[PASS]${NC} $name: managed block present"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "  ${YELLOW}[WARN]${NC} $name: no managed block"
        WARNINGS=$((WARNINGS + 1))
        return 1
    fi
}

do_test() {
    local -a comps=("$@")
    [ ${#comps[@]} -eq 0 ] && comps=("${COMPONENTS_ALL[@]}")

    TOTAL_TESTS=0; PASSED_TESTS=0; FAILED_TESTS=0; WARNINGS=0

    for comp in "${comps[@]}"; do
        case "$comp" in
            base)
                print_section "Base Tools"
                test_command "wget" "wget"
                test_command "curl" "curl"
                test_command "git" "git"
                test_command "jq" "jq"
                test_command "flatpak" "flatpak"
                ;;
            shell)
                print_section "Shell & Terminal"
                test_command "zsh" "zsh"
                if [ -d "$HOME/.oh-my-zsh" ]; then
                    TOTAL_TESTS=$((TOTAL_TESTS + 1))
                    echo -e "  ${GREEN}[PASS]${NC} Oh My Zsh: installed"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                else
                    TOTAL_TESTS=$((TOTAL_TESTS + 1))
                    echo -e "  ${YELLOW}[WARN]${NC} Oh My Zsh: not installed"
                    WARNINGS=$((WARNINGS + 1))
                fi
                test_shell_config "$HOME/.bashrc" ".bashrc"
                test_shell_config "$HOME/.zshrc" ".zshrc"
                ;;
            cpp)
                print_section "C/C++ & HPC"
                test_command "gcc" "GCC"
                test_command "g++" "G++"
                test_command "clang" "Clang"
                test_command "cmake" "CMake"
                test_command "gdb" "GDB"
                test_command "valgrind" "Valgrind"
                test_command "mpirun" "MPI"
                ;;
            python)
                print_section "Python"
                test_command "python3" "Python3"
                test_command "pip3" "pip3"
                test_python_import "$JUPYTER_VENV" "numpy" "NumPy"
                test_python_import "$JUPYTER_VENV" "pandas" "Pandas"
                test_python_import "$JUPYTER_VENV" "matplotlib" "Matplotlib"
                if [ -f "$JUPYTER_VENV/bin/jupyter-lab" ]; then
                    TOTAL_TESTS=$((TOTAL_TESTS + 1))
                    echo -e "  ${GREEN}[PASS]${NC} Jupyter Lab: installed in venv"
                    PASSED_TESTS=$((PASSED_TESTS + 1))
                else
                    TOTAL_TESTS=$((TOTAL_TESTS + 1))
                    echo -e "  ${YELLOW}[WARN]${NC} Jupyter Lab: not found in venv"
                    WARNINGS=$((WARNINGS + 1))
                fi
                ;;
            java)
                print_section "Java"
                test_command "java" "Java"
                test_command "javac" "javac"
                ;;
            dotnet)
                print_section ".NET"
                test_command "dotnet" ".NET SDK"
                ;;
            nodejs)
                print_section "Node.js"
                test_command "node" "Node.js"
                test_command "npm" "npm"
                ;;
            rust)
                print_section "Rust"
                test_command "rustc" "rustc"
                test_command "cargo" "cargo"
                test_command "rustup" "rustup"
                ;;
            ides)
                print_section "IDEs & Editors"
                test_command "code" "VS Code"
                test_command "geany" "Geany"
                ;;
            browsers)
                print_section "Browsers"
                test_command "firefox" "Firefox"
                ;;
            devtools)
                print_section "Dev Tools"
                test_command "rg" "ripgrep"
                test_command "fzf" "fzf"
                test_command "batcat" "bat" || test_command "bat" "bat"
                test_command "shellcheck" "shellcheck"
                test_command "pipx" "pipx"
                ;;
            ai)
                print_section "AI Tools"
                test_command "ollama" "Ollama"
                test_python_import "$AI_VENV" "torch" "PyTorch"
                test_python_import "$AI_VENV" "transformers" "Transformers"
                test_python_import "$AI_VENV" "sklearn" "scikit-learn"
                test_container "open-webui"
                ;;
            docker)
                print_section "Docker"
                test_command "docker" "Docker"
                test_service "docker" "Docker"
                ;;
        esac
    done

    echo ""
    echo -e "${BOLD}Test Summary: total=$TOTAL_TESTS passed=$PASSED_TESTS failed=$FAILED_TESTS warnings=$WARNINGS${NC}"
}

# ==============================================================================
# VALIDATION & JSON REPORT
# ==============================================================================

do_validate() {
    local -a comps=("$@")
    [ ${#comps[@]} -eq 0 ] && comps=("${COMPONENTS_ALL[@]}")

    do_test "${comps[@]}"

    local report_file="$STATE_DIR/validation_$(date +%Y%m%d_%H%M%S).json"
    local rate
    rate=$(awk "BEGIN {if ($TOTAL_TESTS>0) printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100; else print \"0.0\"}")

    cat > "$report_file" << JSONEOF
{
  "script_version": "$SCRIPT_VERSION",
  "timestamp": "$(date -Iseconds)",
  "system": {
    "id": "$OS_ID",
    "name": "$OS_NAME",
    "version_id": "$OS_VERSION_ID",
    "ubuntu_base": "$OS_UBUNTU_BASE",
    "arch": "$OS_ARCH"
  },
  "summary": {
    "total": $TOTAL_TESTS,
    "passed": $PASSED_TESTS,
    "failed": $FAILED_TESTS,
    "warnings": $WARNINGS,
    "success_rate": $rate
  },
  "components_tested": [$(printf '"%s",' "${comps[@]}" | sed 's/,$//')]
}
JSONEOF

    log_success "JSON report: $report_file"
    echo ""
    echo -e "${BOLD}Success rate: ${rate}%${NC}"
    if [ "$FAILED_TESTS" -gt 0 ]; then
        log_warn "$FAILED_TESTS test(s) failed"
    fi
}

# ==============================================================================
# UNINSTALL
# ==============================================================================

uninstall_component() {
    local comp="$1"

    if ! manifest_is_component "$comp"; then
        log_warn "Component '$comp' not found in manifest (not installed by this script)"
        return 1
    fi

    case "$comp" in
        shell)  do_uninstall_shell ;;
        base)   do_uninstall_base ;;
        cpp)    do_uninstall_cpp ;;
        python) do_uninstall_python ;;
        java)   do_uninstall_java ;;
        dotnet) do_uninstall_dotnet ;;
        nodejs) do_uninstall_nodejs ;;
        rust)   do_uninstall_rust ;;
        ides)   do_uninstall_ides ;;
        browsers) do_uninstall_browsers ;;
        devtools) do_uninstall_devtools ;;
        ai)     do_uninstall_ai ;;
        docker) do_uninstall_docker ;;
        *)      log_warn "Unknown component: $comp"; return 1 ;;
    esac

    manifest_remove_component "$comp"
    log_success "Component '$comp' uninstalled"
}

do_uninstall_shell() {
    print_header "Uninstalling Shell Config"

    remove_managed_block "$HOME/.bashrc"
    remove_managed_block "$HOME/.zshrc"

    if manifest_has_oh_my_zsh; then
        read -p "Remove Oh My Zsh (~/.oh-my-zsh)? [y/N]: " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$HOME/.oh-my-zsh"
            manifest_set_shell_field "oh_my_zsh_installed" "false"
            log_success "Oh My Zsh removed"
        fi
    fi

    if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null && jq -e '.shell_config.shell_default_changed == true' "$MANIFEST_FILE" &>/dev/null; then
        read -p "Revert default shell to bash? [y/N]: " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            chsh -s /bin/bash
            manifest_set_shell_field "shell_default_changed" "false"
            log_success "Default shell reverted to bash"
        fi
    fi

    read -p "Uninstall zsh? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt remove --purge -y zsh 2>/dev/null || true
        manifest_set_shell_field "zsh_installed" "false"
    fi

    manifest_set_shell_field "bashrc_managed" "false"
    manifest_set_shell_field "zshrc_managed" "false"
}

do_uninstall_base() {
    log_warn "Base packages (curl, git, build-essential, etc.) are shared system packages"
    log_warn "Removing them may break your system. Skipping automatic removal."
    read -p "Force-remove base packages? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local pkgs
        if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null; then
            pkgs=$(jq -r '.apt_packages[] | select(. == "wget" or . == "curl" or . == "tree" or . == "htop" or . == "jq" or . == "flatpak")' "$MANIFEST_FILE" 2>/dev/null | tr '\n' ' ')
            [ -n "$pkgs" ] && sudo apt remove --purge -y $pkgs 2>/dev/null || true
        fi
    fi
}

do_uninstall_cpp() {
    local packages=(gcc g++ clang clang-format clang-tidy lldb gdb make cmake ninja-build valgrind libgomp1 libomp-dev mpich libmpich-dev openmpi-bin libopenmpi-dev)
    sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
    log_success "C/C++ & HPC packages removed"
}

do_uninstall_python() {
    log_info "Removing Python extras (keeping python3 base)..."
    sudo apt remove --purge -y ipython3 python3-dev python3-tk python3-pygame python-is-python3 2>/dev/null || true

    read -p "Remove Jupyter venv ($JUPYTER_VENV)? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "$JUPYTER_VENV" ]; then
        rm -rf "$JUPYTER_VENV"
        log_success "Jupyter venv removed"
    fi
}

do_uninstall_java() {
    sudo apt remove --purge -y 'openjdk-21-*' 2>/dev/null || true
    remove_managed_block "$HOME/.bashrc"
    remove_managed_block "$HOME/.zshrc"
    rm -rf "$HOME/.java"
    log_success "Java removed"
}

do_uninstall_dotnet() {
    sudo apt remove --purge -y 'dotnet-*' 'aspnetcore-*' 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/microsoft-prod.list 2>/dev/null
    sudo rm -f /etc/apt/keyrings/microsoft-prod.gpg 2>/dev/null
    rm -rf "$HOME/.dotnet" "$HOME/.nuget"
    log_success ".NET removed"
}

do_uninstall_nodejs() {
    sudo npm uninstall -g yarn pnpm typescript ts-node eslint prettier 2>/dev/null || true
    sudo apt remove --purge -y nodejs 2>/dev/null || true
    sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null
    rm -rf "$HOME/.npm" "$HOME/.node-gyp"
    log_success "Node.js removed"
}

do_uninstall_rust() {
    if command -v rustup &>/dev/null; then
        rustup self uninstall -y 2>/dev/null || true
    fi
    remove_managed_block "$HOME/.bashrc"
    remove_managed_block "$HOME/.zshrc"
    rm -rf "$HOME/.cargo" "$HOME/.rustup"
    manifest_set_shell_field "bashrc_managed" "false"
    log_success "Rust removed"
}

do_uninstall_ides() {
    if is_installed code; then
        sudo apt remove --purge -y code 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/vscode.list /etc/apt/keyrings/microsoft-vscode.gpg 2>/dev/null
    fi

    if command -v flatpak &>/dev/null; then
        for app in org.apache.netbeans org.eclipse.Java com.jetbrains.IntelliJ-IDEA-Community com.jetbrains.PyCharm-Community; do
            if flatpak list --app 2>/dev/null | grep -q "$app"; then
                flatpak uninstall --noninteractive "$app" 2>/dev/null || true
            fi
        done
    fi

    sudo apt remove --purge -y spyder codeblocks geany gedit mousepad 2>/dev/null || true
    rm -rf "$HOME/.config/Code" "$HOME/.vscode"
    log_success "IDEs removed"
}

do_uninstall_browsers() {
    read -p "Remove Firefox? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo apt remove --purge -y firefox 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/mozilla.list /etc/apt/keyrings/packages.mozilla.org.asc /etc/apt/preferences.d/mozilla 2>/dev/null
    fi
    log_success "Browsers removed"
}

do_uninstall_devtools() {
    local packages=(ripgrep fd-find bat fzf xclip shellcheck sqlite3 httpie pipx postgresql-client redis-tools)
    sudo apt remove --purge -y "${packages[@]}" 2>/dev/null || true
    log_success "Dev tools removed"
}

do_uninstall_ai() {
    read -p "Remove AI venv ($AI_VENV)? [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]] && [ -d "$AI_VENV" ]; then
        rm -rf "$AI_VENV"
        log_success "AI venv removed"
    fi

    if command -v pipx &>/dev/null; then
        pipx uninstall aider-chat 2>/dev/null || true
        pipx uninstall pre-commit 2>/dev/null || true
    fi

    if command -v docker &>/dev/null && docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "open-webui"; then
        read -p "Remove Open WebUI container and data? [y/N]: " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker stop open-webui 2>/dev/null || true
            docker rm open-webui 2>/dev/null || true
            read -p "Remove Open WebUI data volume? [y/N]: " -n 1 -r; echo
            [[ $REPLY =~ ^[Yy]$ ]] && docker volume rm open-webui-data 2>/dev/null || true
            docker image rm ghcr.io/open-webui/open-webui:main 2>/dev/null || true
        fi
    fi

    if command -v ollama &>/dev/null; then
        read -p "Uninstall Ollama? [y/N]: " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemctl stop ollama 2>/dev/null || true
            sudo systemctl disable ollama 2>/dev/null || true
            sudo rm -f /etc/systemd/system/ollama.service 2>/dev/null
            sudo rm -f /usr/local/bin/ollama 2>/dev/null
            read -p "Remove Ollama models (~/.ollama, may be several GB)? [y/N]: " -n 1 -r; echo
            [[ $REPLY =~ ^[Yy]$ ]] && rm -rf "$HOME/.ollama" /usr/share/ollama
            log_success "Ollama removed"
        fi
    fi

    log_success "AI tools removed"
}

do_uninstall_docker() {
    if ! is_installed docker; then
        log_info "Docker not installed"
        return 0
    fi

    read -p "Remove Docker Engine? This stops all containers. [y/N]: " -n 1 -r; echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Remove ALL Docker data (containers, images, volumes)? THIS IS IRREVERSIBLE. [y/N]: " -n 1 -r; echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker system prune -a --volumes -f 2>/dev/null || true
        fi

        sudo apt remove --purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/docker.list /etc/apt/keyrings/docker.asc 2>/dev/null
        sudo delgroup docker 2>/dev/null || true
        read -p "Remove /var/lib/docker and /var/lib/containerd? [y/N]: " -n 1 -r; echo
        [[ $REPLY =~ ^[Yy]$ ]] && sudo rm -rf /var/lib/docker /var/lib/containerd
        manifest_update_field ".docker_group_added" "false"
        log_success "Docker removed"
    fi
}

do_uninstall_all() {
    print_header "Uninstalling All Managed Components"

    echo "The following components were installed by this script:"
    if [ -f "$MANIFEST_FILE" ] && command -v jq &>/dev/null; then
        jq -r '.installed_components[] | "\(.name) (\(.status) - \(.date))"' "$MANIFEST_FILE" 2>/dev/null
    else
        log_warn "Cannot read manifest"
        return 1
    fi

    echo ""
    log_warn "This will remove only components installed by this script"
    read -p "Type 'UNINSTALL' to confirm full removal: " confirm
    if [ "$confirm" != "UNINSTALL" ]; then
        log_info "Uninstallation cancelled"
        return 0
    fi

    for comp in "${COMPONENTS_ALL[@]}"; do
        if manifest_is_component "$comp"; then
            uninstall_component "$comp" || true
        fi
    done

    sudo apt autoremove -y 2>/dev/null || true
    sudo apt autoclean -y 2>/dev/null || true
    if command -v flatpak &>/dev/null; then
        flatpak uninstall --unused -y 2>/dev/null || true
    fi

    log_success "Full uninstallation complete"
}

# ==============================================================================
# STATUS
# ==============================================================================

do_status() {
    print_header "Lab Manager Status"

    detect_os

    echo -e "${BOLD}System:${NC}       $OS_NAME $OS_VERSION_ID ($OS_ARCH)"
    echo -e "${BOLD}Ubuntu base:${NC}  ${OS_UBUNTU_BASE:-N/A}"
    echo ""

    if [ ! -f "$MANIFEST_FILE" ]; then
        echo -e "${YELLOW}No manifest found. No components installed by this script.${NC}"
        return 0
    fi

    echo -e "${BOLD}Installed components:${NC}"
    if command -v jq &>/dev/null; then
        jq -r '.installed_components[] | "  \(.name): \(.status) (\(.date))"' "$MANIFEST_FILE" 2>/dev/null
    else
        log_warn "jq not available; cannot parse manifest"
    fi

    echo ""
    echo -e "${BOLD}Venvs:${NC}"
    [ -d "$JUPYTER_VENV" ] && echo "  jupyter:  $JUPYTER_VENV" || echo "  jupyter:  not created"
    [ -d "$AI_VENV" ] && echo "  ai-tools: $AI_VENV" || echo "  ai-tools: not created"

    echo ""
    echo -e "${BOLD}Shell:${NC}"
    echo "  current:  $SHELL"
    [ -f "$HOME/.zshrc" ] && echo "  zshrc:    present" || echo "  zshrc:    not found"
    [ -d "$HOME/.oh-my-zsh" ] && echo "  oh-my-zsh:installed" || echo "  oh-my-zsh:not installed"

    echo ""
    echo -e "${BOLD}Manifest:${NC}    $MANIFEST_FILE"
    echo -e "${BOLD}Log:${NC}         $LOG_FILE"
}

# ==============================================================================
# GENERATE SAMPLES
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMPLES_SCRIPT="$SCRIPT_DIR/projetos_por_linguagem.py"

do_generate_samples() {
    local force="${1:-}"
    print_header "Generating Pedagogical Sample Projects"

    if [ ! -f "$SAMPLES_SCRIPT" ]; then
        log_error "projetos_por_linguagem.py not found at: $SAMPLES_SCRIPT"
        log_info "Make sure the script is in the same directory as lab_manager.sh"
        return 1
    fi

    if ! command -v python3 &>/dev/null; then
        log_error "python3 is required to generate sample projects"
        return 1
    fi

    local args=""
    if [ "$force" == "--force" ]; then
        args="--force"
        log_info "Force mode: existing files will be overwritten"
    else
        log_info "Safe mode: existing files will be preserved"
    fi

    python3 "$SAMPLES_SCRIPT" $args
    if [ $? -eq 0 ]; then
        manifest_set_component "samples"
        log_success "Sample projects generated"
    else
        log_error "Failed to generate sample projects"
        return 1
    fi
}

# ==============================================================================
# INTERACTIVE MENU
# ==============================================================================

show_main_menu() {
    clear
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║             LAB MANAGER - Dev Environment Setup            ║${NC}"
    echo -e "${BOLD}║                      v$SCRIPT_VERSION                          ║${NC}"
    echo -e "${BOLD}║  Ubuntu | Linux Mint | Zorin OS | Pop!_OS | Derivatives    ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  1) Install components"
    echo "  2) Configure (shell, git)"
    echo "  3) Test installed components"
    echo "  4) Validate & generate JSON report"
    echo "  5) Uninstall components"
    echo "  6) Restore config files"
    echo "  7) Generate sample projects"
    echo "  8) Status"
    echo ""
    echo "  0) Exit"
    echo ""
    echo -e "  ${CYAN}────────────────────────────────────────────────────────────${NC}"
}

show_install_menu() {
    echo ""
    echo -e "${BOLD}Install Components${NC}"
    echo ""
    echo "  1) Base system   (curl, git, flatpak, build-essential...)"
    echo "  2) Shell         (zsh, oh-my-zsh optional)"
    echo "  3) C/C++ & HPC   (gcc, clang, cmake, mpi, openmp)"
    echo "  4) Python        (python3, jupyter, numpy, pandas...)"
    echo "  5) Java          (OpenJDK 21)"
    echo "  6) .NET          (SDK $DOTNET_VERSION)"
    echo "  7) Node.js       (node 22 LTS, npm, ts, eslint...)"
    echo "  8) Rust          (rustc, cargo, rustup)"
    echo "  9) IDEs          (VS Code, NetBeans, Eclipse, IntelliJ...)"
    echo " 10) Browsers      (Firefox, Chromium, Chrome optional)"
    echo " 11) Dev tools     (ripgrep, fzf, bat, shellcheck, pipx...)"
    echo " 12) AI tools      (ollama, open-webui, torch, transformers...)"
    echo " 13) Docker        (Docker Engine + compose)"
    echo ""
    echo "  A) Install ALL"
    echo "  0) Back"
    echo ""
}

show_uninstall_menu() {
    echo ""
    echo -e "${BOLD}Uninstall Components${NC}"
    echo -e "${YELLOW}  Only components installed by this script will be removed${NC}"
    echo ""
    echo "  1) Base      7) Node.js"
    echo "  2) Shell     8) Rust"
    echo "  3) C/C++     9) IDEs"
    echo "  4) Python   10) Browsers"
    echo "  5) Java     11) Dev tools"
    echo "  6) .NET     12) AI tools"
    echo "             13) Docker"
    echo ""
    echo "  A) Uninstall ALL (safe)"
    echo "  0) Back"
    echo ""
}

menu_install() {
    while true; do
        show_install_menu
        read -p "Choose [0-13,A]: " choice
        case "$choice" in
            1)  do_install_base; read -p "ENTER to continue..." ;;
            2)  do_install_shell; read -p "ENTER to continue..." ;;
            3)  do_install_cpp; read -p "ENTER to continue..." ;;
            4)  do_install_python; read -p "ENTER to continue..." ;;
            5)  do_install_java; read -p "ENTER to continue..." ;;
            6)  do_install_dotnet; read -p "ENTER to continue..." ;;
            7)  do_install_nodejs; read -p "ENTER to continue..." ;;
            8)  do_install_rust; read -p "ENTER to continue..." ;;
            9)  do_install_ides; read -p "ENTER to continue..." ;;
            10) do_install_browsers; read -p "ENTER to continue..." ;;
            11) do_install_devtools; read -p "ENTER to continue..." ;;
            12) do_install_ai; read -p "ENTER to continue..." ;;
            13) do_install_docker; read -p "ENTER to continue..." ;;
            [aA])
                do_install_base
                do_install_shell
                do_install_cpp
                do_install_python
                do_install_java
                do_install_dotnet
                do_install_nodejs
                do_install_rust
                do_install_ides
                do_install_browsers
                do_install_devtools
                do_install_ai
                do_install_docker
                configure_git
                read -p "ENTER to continue..."
                ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

menu_uninstall() {
    while true; do
        show_uninstall_menu
        read -p "Choose [0-13,A]: " choice
        case "$choice" in
            1)  uninstall_component "base"; read -p "ENTER to continue..." ;;
            2)  uninstall_component "shell"; read -p "ENTER to continue..." ;;
            3)  uninstall_component "cpp"; read -p "ENTER to continue..." ;;
            4)  uninstall_component "python"; read -p "ENTER to continue..." ;;
            5)  uninstall_component "java"; read -p "ENTER to continue..." ;;
            6)  uninstall_component "dotnet"; read -p "ENTER to continue..." ;;
            7)  uninstall_component "nodejs"; read -p "ENTER to continue..." ;;
            8)  uninstall_component "rust"; read -p "ENTER to continue..." ;;
            9)  uninstall_component "ides"; read -p "ENTER to continue..." ;;
            10) uninstall_component "browsers"; read -p "ENTER to continue..." ;;
            11) uninstall_component "devtools"; read -p "ENTER to continue..." ;;
            12) uninstall_component "ai"; read -p "ENTER to continue..." ;;
            13) uninstall_component "docker"; read -p "ENTER to continue..." ;;
            [aA]) do_uninstall_all; read -p "ENTER to continue..." ;;
            0) return ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

menu_restore() {
    echo ""
    echo -e "${BOLD}Restore Configuration Files${NC}"
    echo ""
    echo "  1) Restore .bashrc"
    echo "  2) Restore .zshrc"
    echo "  3) Restore .profile"
    echo "  0) Back"
    echo ""
    read -p "Choose: " choice
    case "$choice" in
        1) restore_config ".bashrc" ;;
        2) restore_config ".zshrc" ;;
        3) restore_config ".profile" ;;
        0) return ;;
    esac
}

interactive_mode() {
    while true; do
        show_main_menu
        read -p "Choose [0-8]: " choice
        case "$choice" in
            1) menu_install ;;
            2) configure_shell; configure_git; read -p "ENTER to continue..." ;;
            3) do_test; read -p "ENTER to continue..." ;;
            4) do_validate; read -p "ENTER to continue..." ;;
            5) menu_uninstall ;;
            6) menu_restore; read -p "ENTER to continue..." ;;
            7) do_generate_samples; read -p "ENTER to continue..." ;;
            8) do_status; read -p "ENTER to continue..." ;;
            0) log_info "Bye"; exit 0 ;;
            *) log_error "Invalid option"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# CLI PARSER
# ==============================================================================

show_help() {
    cat << 'HELP'
Lab Manager - Unified Development Environment Setup

USAGE:
    ./lab_manager.sh [COMMAND] [COMPONENTS...] [OPTIONS]

COMMANDS:
    (none)              Interactive menu
    install             Install components
    configure           Apply shell/git configuration
    test                Run smoke tests
    validate            Validate and generate JSON report
    uninstall           Remove components (safe by default)
    generate-samples    Generate pedagogical test projects (from projetos_por_linguagem.py)
    status              Show manifest and system status
    restore             Restore backed-up config files
    help                Show this help

COMPONENTS:
    base  shell  cpp  python  java  dotnet  nodejs  rust
    ides  browsers  devtools  ai  docker  all

OPTIONS:
    --json          Output JSON report (validate)
    --safe          Safe uninstall, confirm destructive actions (default)
    --force         Skip confirmations (use with caution)
    -h, --help      Show this help
    -v, --version   Show version

EXAMPLES:
    ./lab_manager.sh
    ./lab_manager.sh install all
    ./lab_manager.sh install python nodejs rust
    ./lab_manager.sh configure shell
    ./lab_manager.sh test python ai
    ./lab_manager.sh validate --json
    ./lab_manager.sh uninstall ai --safe
    ./lab_manager.sh uninstall all
    ./lab_manager.sh generate-samples
    ./lab_manager.sh generate-samples --force
    ./lab_manager.sh status
    ./lab_manager.sh restore bashrc
HELP
}

parse_args() {
    local cmd=""
    local -a comp_args=()
    local json_output=false

    if [ $# -eq 0 ]; then
        interactive_mode
        exit 0
    fi

    cmd="$1"
    shift

    while [ $# -gt 0 ]; do
        case "$1" in
            --json)  json_output=true; shift ;;
            --safe)  shift ;;
            --force) shift ;;
            -h|--help) show_help; exit 0 ;;
            -v|--version) echo "v$SCRIPT_VERSION"; exit 0 ;;
            all) comp_args=("${COMPONENTS_ALL[@]}"); shift ;;
            *) comp_args+=("$1"); shift ;;
        esac
    done

    [ ${#comp_args[@]} -eq 0 ] && comp_args=("${COMPONENTS_ALL[@]}")

    case "$cmd" in
        install)
            for c in "${comp_args[@]}"; do
                case "$c" in
                    base)     do_install_base ;;
                    shell)    do_install_shell ;;
                    cpp)      do_install_cpp ;;
                    python)   do_install_python ;;
                    java)     do_install_java ;;
                    dotnet)   do_install_dotnet ;;
                    nodejs)   do_install_nodejs ;;
                    rust)     do_install_rust ;;
                    ides)     do_install_ides ;;
                    browsers) do_install_browsers ;;
                    devtools) do_install_devtools ;;
                    ai)       do_install_ai ;;
                    docker)   do_install_docker ;;
                    all)
                        do_install_base; do_install_shell; do_install_cpp
                        do_install_python; do_install_java; do_install_dotnet
                        do_install_nodejs; do_install_rust; do_install_ides
                        do_install_browsers; do_install_devtools; do_install_ai
                        do_install_docker; configure_git
                        ;;
                    *) log_error "Unknown component: $c" ;;
                esac
            done
            ;;
        configure)
            configure_shell
            configure_git
            ;;
        test)
            do_test "${comp_args[@]}"
            ;;
        validate)
            do_validate "${comp_args[@]}"
            ;;
        generate-samples)
            force_flag=""
            for a in "$@"; do [ "$a" = "--force" ] && force_flag="--force"; done
            do_generate_samples "$force_flag"
            ;;
        uninstall)
            if [[ " ${comp_args[*]} " == *" all "* ]]; then
                do_uninstall_all
            else
                for c in "${comp_args[@]}"; do
                    uninstall_component "$c" || true
                done
            fi
            ;;
        status)
            do_status
            ;;
        restore)
            for c in "${comp_args[@]}"; do
                case "$c" in
                    bashrc) restore_config ".bashrc" ;;
                    zshrc)  restore_config ".zshrc" ;;
                    profile) restore_config ".profile" ;;
                    *) log_warn "Unknown restore target: $c" ;;
                esac
            done
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $cmd"
            show_help
            exit 1
            ;;
    esac
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    setup_logging
    detect_os
    manifest_init

    if [ $# -eq 0 ]; then
        if ! run_preflight; then
            log_error "Preflight checks failed"
            exit 1
        fi
        create_backup
        interactive_mode
    else
        if [[ "$1" != "status" && "$1" != "help" && "$1" != "-h" && "$1" != "--help" && "$1" != "-v" && "$1" != "--version" && "$1" != "restore" && "$1" != "generate-samples" ]]; then
            if ! run_preflight; then
                log_error "Preflight checks failed"
                exit 1
            fi
            if [[ "$1" == "install" ]]; then
                create_backup
            fi
        fi
        parse_args "$@"
    fi
}

main "$@"