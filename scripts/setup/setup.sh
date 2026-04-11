#!/usr/bin/env bash
# setup.sh — Setup script for niri-caelestia-shell (Arch Linux)
#
# This script installs all system packages, creates the Python virtual environment,
# installs Python dependencies, and sets up directories and services needed by
# the shell and its color generation pipeline.
#
# Usage: ./scripts/setup/setup.sh [--skip-deps] [--skip-python] [--skip-services]

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
CYAN='\e[36m'
BOLD='\e[1m'
RST='\e[0m'

info()  { printf "${CYAN}[setup]${RST} %s\n" "$*"; }
ok()    { printf "${GREEN}[setup]${RST} %s\n" "$*"; }
warn()  { printf "${YELLOW}[setup]${RST} WARNING: %s\n" "$*"; }
err()   { printf "${RED}[setup]${RST} ERROR: %s\n" "$*" >&2; }
die()   { err "$*"; exit 1; }
ask()   { printf "${BOLD}%s${RST} " "$*"; }

# ─── Paths ────────────────────────────────────────────────────────────────────
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETUP_DIR="$SCRIPT_DIR"

VENV_DIR="$XDG_STATE_HOME/quickshell/.venv"
GENERATED_DIR="$XDG_STATE_HOME/quickshell/user/generated"

# ─── Flags ────────────────────────────────────────────────────────────────────
SKIP_DEPS=false
SKIP_PYTHON=false
SKIP_SERVICES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-deps)     SKIP_DEPS=true;     shift ;;
        --skip-python)   SKIP_PYTHON=true;   shift ;;
        --skip-services) SKIP_SERVICES=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--skip-deps] [--skip-python] [--skip-services]"
            exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
done

# ─── Pre-checks ──────────────────────────────────────────────────────────────
if [[ $EUID -eq 0 ]]; then
    die "Do not run this script as root. It will ask for sudo when needed."
fi

if ! command -v pacman &>/dev/null; then
    die "pacman not found — this setup script is for Arch Linux only."
fi

# ─── 1. System Dependencies ──────────────────────────────────────────────────
install_system_deps() {
    info "Installing system packages..."

    # Ensure yay is available for AUR packages
    if ! command -v yay &>/dev/null; then
        warn "yay not found. Installing yay..."
        sudo pacman -S --needed --noconfirm base-devel git
        local tmpdir
        tmpdir=$(mktemp -d)
        git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
        (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$tmpdir"
    fi

    # Core system packages (from official repos)
    local pacman_pkgs=(
        # Build tools
        base-devel cmake clang git

        # Core utilities
        bc coreutils curl wget jq ripgrep xdg-user-dirs rsync

        # Audio
        cava pavucontrol-qt wireplumber pipewire-pulse libdbusmenu-gtk3 playerctl

        # Brightness & hardware
        brightnessctl ddcutil geoclue

        # KDE/Qt integration
        bluedevil gnome-keyring networkmanager networkmanager-qt plasma-nm polkit-kde-agent
        dolphin systemsettings breeze

        # Desktop portals
        xdg-desktop-portal xdg-desktop-portal-kde xdg-desktop-portal-gtk

        # Screen capture
        slurp swappy tesseract tesseract-data-eng wf-recorder

        # Toolkit
        upower wtype ydotool

        # Widgets & misc
        fuzzel glib2 imagemagick hypridle hyprlock hyprpicker
        translate-shell libqalculate cliphist

        # Terminal & fonts
        kitty fish fontconfig eza starship
        ttf-jetbrains-mono-nerd

        # Python build deps
        gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection

        # Color generation
        imagemagick
    )

    info "Installing official repo packages..."
    sudo pacman -S --needed --noconfirm "${pacman_pkgs[@]}" || true

    # AUR packages
    local aur_pkgs=(
        adw-gtk-theme-git
        matugen
        ttf-material-symbols-variable-git
        ttf-readex-pro
        ttf-rubik-vf
        ttf-twemoji
        otf-space-grotesk
        darkly-bin
        breeze-plus
        hyprshot
        uv
    )

    info "Installing AUR packages..."
    yay -S --needed --noconfirm "${aur_pkgs[@]}" || true

    ok "System packages installed."
}

# ─── 2. Python Virtual Environment ───────────────────────────────────────────
setup_python_venv() {
    info "Setting up Python virtual environment at $VENV_DIR ..."

    if ! command -v uv &>/dev/null; then
        info "Installing uv..."
        bash <(curl -LJs "https://astral.sh/uv/install.sh")
        export PATH="$HOME/.local/bin:$PATH"
    fi

    mkdir -p "$VENV_DIR"

    # Create venv with Python 3.12 (required for Pillow compatibility)
    uv venv --prompt caelestia "$VENV_DIR" -p 3.12

    # Install Python packages
    source "$VENV_DIR/bin/activate"
    uv pip install -r "$SETUP_DIR/requirements.txt"
    deactivate

    ok "Python venv created at $VENV_DIR"
}

# ─── 3. Directories & State ──────────────────────────────────────────────────
setup_directories() {
    info "Creating required directories..."

    mkdir -p "$GENERATED_DIR"
    mkdir -p "$GENERATED_DIR/terminal"
    mkdir -p "$GENERATED_DIR/wallpaper"
    mkdir -p "$XDG_CONFIG_HOME/gtk-3.0"
    mkdir -p "$XDG_CONFIG_HOME/gtk-4.0"
    mkdir -p "$XDG_CONFIG_HOME/Kvantum"

    ok "Directories ready."
}

# ─── 4. Environment Variable ─────────────────────────────────────────────────
setup_env_var() {
    info "Setting up CAELESTIA_VIRTUAL_ENV environment variable..."

    local env_line="export CAELESTIA_VIRTUAL_ENV=\"$VENV_DIR\""
    local env_set=false

    # Fish shell
    local fish_conf="$XDG_CONFIG_HOME/fish/conf.d/caelestia.fish"
    mkdir -p "$(dirname "$fish_conf")"
    echo "set -gx CAELESTIA_VIRTUAL_ENV \"$VENV_DIR\"" > "$fish_conf"
    ok "Fish: $fish_conf"

    # Bash
    for rc in "$HOME/.bashrc" "$HOME/.bash_profile"; do
        if [[ -f "$rc" ]]; then
            if ! grep -q 'CAELESTIA_VIRTUAL_ENV' "$rc"; then
                echo "" >> "$rc"
                echo "# niri-caelestia-shell Python venv" >> "$rc"
                echo "$env_line" >> "$rc"
                ok "Added to $rc"
                env_set=true
            else
                ok "Already in $rc"
                env_set=true
            fi
        fi
    done

    # Zsh
    if [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q 'CAELESTIA_VIRTUAL_ENV' "$HOME/.zshrc"; then
            echo "" >> "$HOME/.zshrc"
            echo "# niri-caelestia-shell Python venv" >> "$HOME/.zshrc"
            echo "$env_line" >> "$HOME/.zshrc"
            ok "Added to ~/.zshrc"
        else
            ok "Already in ~/.zshrc"
        fi
    fi

    # Also export for current session
    export CAELESTIA_VIRTUAL_ENV="$VENV_DIR"

    # Environment.d for systemd user sessions (picked up by graphical session)
    local envd_dir="$XDG_CONFIG_HOME/environment.d"
    mkdir -p "$envd_dir"
    echo "CAELESTIA_VIRTUAL_ENV=$VENV_DIR" > "$envd_dir/caelestia.conf"
    ok "Systemd: $envd_dir/caelestia.conf"
}

# ─── 5. Services ─────────────────────────────────────────────────────────────
setup_services() {
    info "Enabling services..."

    if command -v systemctl &>/dev/null; then
        # i2c-dev module
        echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf > /dev/null

        # User groups
        if [[ -z $(getent group i2c 2>/dev/null) ]]; then
            sudo groupadd i2c 2>/dev/null || true
        fi
        sudo usermod -aG video,i2c,input "$(whoami)" 2>/dev/null || true

        # ydotool
        if [[ -e "/usr/lib/systemd/user/ydotool.service" ]] || \
           [[ -e "/usr/lib/systemd/system/ydotool.service" ]]; then
            if [[ ! -e "/usr/lib/systemd/user/ydotool.service" ]]; then
                sudo ln -sf /usr/lib/systemd/{system,user}/ydotool.service
            fi
            systemctl --user enable ydotool --now 2>/dev/null || true
        fi

        # Bluetooth
        sudo systemctl enable bluetooth --now 2>/dev/null || true
    fi

    # GNOME settings
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Rubik 11' 2>/dev/null || true

    # KDE widget style
    kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly 2>/dev/null || true

    ok "Services configured."
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    printf "\n${BOLD}${CYAN}╔══════════════════════════════════════════╗${RST}\n"
    printf "${BOLD}${CYAN}║   niri-caelestia-shell  —  Arch Setup    ║${RST}\n"
    printf "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RST}\n\n"

    info "Shell directory: $SHELL_DIR"
    info "Venv directory:  $VENV_DIR"
    echo ""

    # 1. System deps
    if [[ "$SKIP_DEPS" != true ]]; then
        install_system_deps
    else
        warn "Skipping system dependencies (--skip-deps)"
    fi

    echo ""

    # 2. Directories
    setup_directories

    # 3. Python venv
    if [[ "$SKIP_PYTHON" != true ]]; then
        setup_python_venv
    else
        warn "Skipping Python setup (--skip-python)"
    fi

    echo ""

    # 4. Environment variable
    setup_env_var

    echo ""

    # 5. Services
    if [[ "$SKIP_SERVICES" != true ]]; then
        setup_services
    else
        warn "Skipping services setup (--skip-services)"
    fi

    echo ""
    printf "${BOLD}${GREEN}╔══════════════════════════════════════════╗${RST}\n"
    printf "${BOLD}${GREEN}║            Setup complete!               ║${RST}\n"
    printf "${BOLD}${GREEN}╚══════════════════════════════════════════╝${RST}\n\n"

    info "You may need to log out and back in for:"
    info "  - Group changes (i2c, input, video) to take effect"
    info "  - CAELESTIA_VIRTUAL_ENV to be available in your session"
    echo ""
    info "To manually test color generation:"
    info "  bash $SHELL_DIR/scripts/colors/switchwall.sh --mode dark <wallpaper_path>"
    echo ""
}

main
