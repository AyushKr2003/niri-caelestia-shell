#!/usr/bin/env bash
# test.sh — preview niri-caelestia-sddm without locking your session
# Creates a temporary theme copy with patched properties — never touches source files.

THEME_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors and formatting
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info() { echo -e "${CYAN}[test]${NC} $*"; }
ok()   { echo -e "${GREEN}[✓]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
die()  { echo -e "${RED}[✗]${NC} $*"; exit 1; }

usage() {
cat << HELP
${BOLD}niri-caelestia-sddm test runner${NC}
  Usage: ./test.sh [OPTIONS]

Options:
  -w, --wallpaper PATH   Path to a custom wallpaper image
  -u, --user NAME        Test with a specific username (default: current user)
  -n, --no-blur          Disable background blur
  -f, --fast             Disable animations (instant transitions)
  -h, --help             Show this help message

Environment:
  Requires 'sddm-greeter-qt6' (Qt6 greeter) to be installed.
HELP
}

# ── Parse arguments ───────────────────────────────────────────────────────
WALLPAPER=""; TEST_USER="$USER"; NO_BLUR=false; FAST=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -w|--wallpaper) WALLPAPER="$2"; shift 2 ;;
        -u|--user)      TEST_USER="$2"; shift 2 ;;
        -n|--no-blur)   NO_BLUR=true;   shift   ;;
        -f|--fast)      FAST=true;      shift   ;;
        -h|--help)      usage; exit 0           ;;
        *) warn "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Check for required tools
command -v sddm-greeter-qt6 &>/dev/null || die "sddm-greeter-qt6 not found. Please install SDDM (Qt6 version)."

# ── Auto-detect wallpaper ─────────────────────────────────────────────────
if [[ -z "$WALLPAPER" ]]; then
    # Try theme config hint (Integrated mode uses line 5)
    WP_HINT="$HOME/.config/niri-caelestia-sddm/Colors.qml"
    if [[ -f "$WP_HINT" ]]; then
        # Try both line 5 (integrated) and standard grep (manual)
        WALLPAPER=$(sed -n '5p' "$WP_HINT" | sed 's/^\/\/\s*//' | xargs)
        if [[ ! -f "${WALLPAPER/#\~/$HOME}" ]]; then
             # Fallback to grep for manual mode
             WALLPAPER=$(grep "wallpaperPath:" "$HOME/.config/niri-caelestia-sddm/Settings.qml" | cut -d'"' -f2 || echo "")
        fi
        WALLPAPER="${WALLPAPER/#\~/$HOME}"
    fi
fi

if [[ -z "$WALLPAPER" || ! -f "$WALLPAPER" ]]; then
    # Fallback search
    for dir in "$HOME/Pictures/Wallpapers" "$HOME/Pictures" "$HOME/.local/share/wallpapers" "/usr/share/backgrounds"; do
        [[ -d "$dir" ]] && WALLPAPER=$(find "$dir" -maxdepth 2 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | head -1) && [[ -n "$WALLPAPER" ]] && break
    done
fi

# ── Create temporary theme copy ──────────────────────────────────────────
# We copy to /tmp so the greeter loads from an isolated path
TMP_THEME=$(mktemp -d /tmp/caelestia-sddm-test.XXXXXX)
cp -r "$THEME_DIR/." "$TMP_THEME/"

# Copy user config if available
CONFIG_DIR="$HOME/.config/niri-caelestia-sddm"
if [[ -d "$CONFIG_DIR" ]]; then
    cp -f "$CONFIG_DIR/Colors.qml" "$TMP_THEME/Components/Colors.qml" 2>/dev/null || true
    cp -f "$CONFIG_DIR/Settings.qml" "$TMP_THEME/Components/Settings.qml" 2>/dev/null || true
fi

# ── Set defaults for testing ─────────────────────────────────────────────
if [[ -n "$WALLPAPER" && -f "$WALLPAPER" ]]; then
    info "Using detected wallpaper: $WALLPAPER"
    cp "$WALLPAPER" "$TMP_THEME/Backgrounds/wallpaper.jpg"
    WP_REL="Backgrounds/wallpaper.jpg"
else
    WP_REL="assets/background.jpg"
    info "Using theme default assets (no search)."
fi

# Patch theme.conf in the temporary directory
sed -i "s|background=.*|background=$WP_REL|" "$TMP_THEME/theme.conf"

# Configuration values
BLUR_V="true"; BLUR_R="64"
$NO_BLUR && { BLUR_V="false"; BLUR_R="0"; }
ANIM_MS="300"
$FAST && ANIM_MS="0"

# ── Patch Main.qml with test overrides using Python ──────────────────────
python3 - << PY
import re, os

path = "$TMP_THEME/Main.qml"
with open(path, "r") as f:
    content = f.read()

# Patch Settings overrides
# Handle the (settings && settings.key) || default pattern
content = re.sub(r'(readonly property bool\s+blurWallpaper:\s*).*', r'\1 $BLUR_V', content)
content = re.sub(r'(readonly property int\s+blurRadius:\s*).*', r'\1 $BLUR_R', content)
content = re.sub(r'(readonly property int\s+animMs:\s*).*', r'\1 $ANIM_MS', content)

with open(path, "w") as f:
    f.write(content)
PY


cleanup() {
    rm -rf "$TMP_THEME"
    info "Cleaned up temporary files."
}
trap cleanup EXIT INT TERM

# ── Run Greeter ───────────────────────────────────────────────────────────
echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  niri-caelestia-sddm — Qt6 Test Mode${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  User       : ${BLUE}$TEST_USER${NC}"
echo -e "  Blur       : $( $NO_BLUR && echo -e "${RED}Off${NC}" || echo -e "${GREEN}On (radius $BLUR_R)${NC}" )"
echo -e "  Animations : $( $FAST && echo -e "${RED}Disabled${NC}" || echo -e "${GREEN}Enabled ($ANIM_MS ms)${NC}" )"
echo -e ""
echo -e "  ${YELLOW}Note: Password authentication is disabled in test mode.${NC}"
echo -e "  ${YELLOW}Close the window or press Ctrl+C to exit.${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ok "Launching greeter..."

# Run sddm-greeter-qt6
export QML2_IMPORT_PATH="$TMP_THEME/Components/:$QML2_IMPORT_PATH"

sddm-greeter-qt6 \
    --test-mode \
    --theme "$TMP_THEME" \
    2>&1 | grep -Ev "^[[:space:]]*$|QObject::startTimer|QBasicTimer|Reading from|High-DPI|cursor.available|Loading qrc"
