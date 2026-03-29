#!/usr/bin/env bash
# setup.sh — interactive installer for niri-caelestia-sddm

set -e
THEME_NAME="niri-caelestia-sddm"
THEME_INSTALL_DIR="/usr/share/sddm/themes/$THEME_NAME"
REAL_USER="${SUDO_USER:-$USER}"                          
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)   
CONFIG_DIR="$REAL_HOME/.config/$THEME_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[setup]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

echo ""
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}  niri-caelestia-sddm installer${NC}"
echo -e "${CYAN}  SDDM theme matching niri-caelestia-shell lockscreen${NC}"
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
info "Installing for user: $REAL_USER (home: $REAL_HOME)"
echo ""

# ── Dependency check ──────────────────────────────────────────────────────
info "Checking dependencies..."
MISSING=()
command -v sddm-greeter-qt6 &>/dev/null || MISSING+=("sddm")
command -v jq &>/dev/null || MISSING+=("jq")
if command -v pacman &>/dev/null; then
    for pkg in qt6-svg qt6-declarative qt6-multimedia-ffmpeg qt6-quickeffects; do
        pacman -Q "$pkg" &>/dev/null || MISSING+=("$pkg")
    done
fi
if [[ ${#MISSING[@]} -gt 0 ]]; then
    warn "Missing: ${MISSING[*]}"
    warn "Install: yay -S --needed ${MISSING[*]}"
    read -rp "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || die "Aborted."
fi
ok "Dependencies OK"

# ── Integration mode ──────────────────────────────────────────────────────
echo ""
echo "Select integration mode:"
echo "  1) Shell Integrate — pull colors directly from niri-caelestia-shell state (recommended)"
echo "  2) Matugen — colors auto-sync when wallpaper changes"
echo "  3) Manual  — edit Colors.qml yourself"
echo ""
read -rp "Choice [1/2/3]: " MODE_CHOICE

# ── Install theme files ───────────────────────────────────────────────────
info "Installing theme to $THEME_INSTALL_DIR ..."
sudo mkdir -p "$THEME_INSTALL_DIR"
sudo cp -rf "$SCRIPT_DIR"/. "$THEME_INSTALL_DIR/"

# Ensure assets folder exists in destination for fallback
if [[ -d "$SCRIPT_DIR/assets" ]]; then
    sudo mkdir -p "$THEME_INSTALL_DIR/assets"
    sudo cp -f "$SCRIPT_DIR/assets/"* "$THEME_INSTALL_DIR/assets/"
fi

# Create initial theme.conf if missing
if [[ ! -f "$THEME_INSTALL_DIR/theme.conf" ]]; then
    sudo tee "$THEME_INSTALL_DIR/theme.conf" > /dev/null << CONF
[General]
background=assets/background.jpg
CONF
fi
ok "Theme files installed"

# ── Config dir (owned by real user, not root) ─────────────────────────────
sudo -u "$REAL_USER" mkdir -p "$CONFIG_DIR"

if [[ "$MODE_CHOICE" == "1" ]]; then
    # ── Shell Integrate mode ──────────────────────────────────────────────
    sudo -u "$REAL_USER" bash -c "
        cp    '$SCRIPT_DIR/Integrate/shell-sync.sh'     '$CONFIG_DIR/shell-sync.sh'
        cp    '$SCRIPT_DIR/Matugen/sddm-theme-apply.sh' '$CONFIG_DIR/sddm-theme-apply.sh'
        cp -n '$SCRIPT_DIR/Components/Settings.qml'    '$CONFIG_DIR/Settings.qml'
        chmod +x '$CONFIG_DIR/shell-sync.sh'
        chmod +x '$CONFIG_DIR/sddm-theme-apply.sh'
    "

    # Set up passwordless sudo for both sync and apply scripts
    SUDOERS_FILE="/etc/sudoers.d/${THEME_NAME}-${REAL_USER}"
    {
        echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/sddm-theme-apply.sh"
        echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/shell-sync.sh"
    } | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
    ok "Passwordless sudo configured"

    info "Applying initial colors from shell..."
    sudo -u "$REAL_USER" "$CONFIG_DIR/shell-sync.sh" || \
        warn "Sync script failed — check if shell scheme exists at ~/.local/state/caelestia/scheme.json"

elif [[ "$MODE_CHOICE" == "2" ]]; then
    # ── Matugen mode ──────────────────────────────────────────────────────
    sudo -u "$REAL_USER" bash -c "
        cp    '$SCRIPT_DIR/Matugen/SddmColors.qml'     '$CONFIG_DIR/SddmColors.qml'
        cp -n '$SCRIPT_DIR/Matugen/Colors.qml'         '$CONFIG_DIR/Colors.qml'
        cp    '$SCRIPT_DIR/Matugen/sddm-theme-apply.sh' '$CONFIG_DIR/sddm-theme-apply.sh'
        cp -n '$SCRIPT_DIR/Components/Settings.qml'    '$CONFIG_DIR/Settings.qml'
        chmod +x '$CONFIG_DIR/sddm-theme-apply.sh'
    "

    # Set up passwordless sudo for the apply script
    SUDOERS_FILE="/etc/sudoers.d/${THEME_NAME}-${REAL_USER}"
    echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/sddm-theme-apply.sh" \
        | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"
    ok "Passwordless sudo configured"

    MATUGEN_CONF="$REAL_HOME/.config/matugen/config.toml"
    if [[ -f "$MATUGEN_CONF" ]]; then
        if ! grep -q "caelestia-sddm" "$MATUGEN_CONF"; then
            cat "$SCRIPT_DIR/Matugen/matugen-config.toml" >> "$MATUGEN_CONF"
            ok "Matugen hook added to $MATUGEN_CONF"
        else
            ok "Matugen hook already present"
        fi
    else
        warn "No matugen config at $MATUGEN_CONF — add hook manually from Matugen/matugen-config.toml"
    fi

    info "Applying initial colors..."
    # Ensure line 5 of Colors.qml has a wallpaper for the first run if Matugen hasn't run yet
    if [[ -f "$CONFIG_DIR/Colors.qml" ]] && ! grep -q "//" "$CONFIG_DIR/Colors.qml"; then
        sed -i '5i // assets/background.jpg' "$CONFIG_DIR/Colors.qml"
    fi
    sudo -u "$REAL_USER" "$CONFIG_DIR/sddm-theme-apply.sh" || \
        warn "Apply script failed — check if you have a wallpaper set."

else
    # ── Manual mode ───────────────────────────────────────────────────────
    sudo -u "$REAL_USER" bash -c "
        cp -n '$SCRIPT_DIR/noMatugen/Colors.qml'            '$CONFIG_DIR/Colors.qml'
        cp -n '$SCRIPT_DIR/noMatugen/Settings.qml'          '$CONFIG_DIR/Settings.qml'
        cp    '$SCRIPT_DIR/noMatugen/sddm-theme-apply.sh'   '$CONFIG_DIR/sddm-theme-apply.sh'
        chmod +x '$CONFIG_DIR/sddm-theme-apply.sh'
    "

    SUDOERS_FILE="/etc/sudoers.d/${THEME_NAME}-${REAL_USER}"
    echo "$REAL_USER ALL=(ALL) NOPASSWD: $CONFIG_DIR/sddm-theme-apply.sh" \
        | sudo tee "$SUDOERS_FILE" > /dev/null
    sudo chmod 0440 "$SUDOERS_FILE"

    ok "Config files installed"
    info "Edit $CONFIG_DIR/Colors.qml and Settings.qml to customize"
    info "Then run: $CONFIG_DIR/sddm-theme-apply.sh"
fi

# ── /etc/sddm.conf ────────────────────────────────────────────────────────
SDDM_CONF="/etc/sddm.conf"
info "Configuring $SDDM_CONF ..."
[[ -f "$SDDM_CONF" ]] && sudo cp "$SDDM_CONF" "${SDDM_CONF}.bak" && ok "Backup: ${SDDM_CONF}.bak"

sudo tee "$SDDM_CONF" > /dev/null << CONF
[General]
# Set InputMethod=qtvirtualkeyboard if you want a virtual keyboard
InputMethod=

[Theme]
Current=$THEME_NAME
CONF
ok "sddm.conf configured"

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  Done! Reboot to activate SDDM theme.${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
