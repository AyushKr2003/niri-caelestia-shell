#!/usr/bin/env bash

## sddm-theme-apply.sh (Manual Mode) — applies colors + wallpaper into installed theme
## Workflow matched to ii-sddm-theme

set -euo pipefail

# --- Security: Validate and sanitize paths ---
validate_path() {
    local path="$1"
    local description="$2"

    if [ ! -e "$path" ]; then
        return 1
    fi

    if [ -L "$path" ]; then
        echo "Error: $description is a symbolic link (not allowed): $path" >&2
        return 1
    fi

    realpath "$path"
}

# --- Local user name ---
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"

if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo "Error: invalid user home directory" >&2
    exit 1
fi

# --- Directories ---
THEME_NAME="niri-caelestia-sddm"
THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"
CONFIG_DIR="$USER_HOME/.config/$THEME_NAME"

# --- Extract wallpaper path from Settings.qml or Colors.qml ---
SETTINGS_QML="$CONFIG_DIR/Settings.qml"
COLORS_QML="$CONFIG_DIR/Colors.qml"

WALLPAPER_PATH=""
if [ -f "$SETTINGS_QML" ]; then
    WALLPAPER_PATH=$(grep "wallpaperPath:" "$SETTINGS_QML" | cut -d'"' -f2 || echo "")
fi

if [ -z "$WALLPAPER_PATH" ] && [ -f "$COLORS_QML" ]; then
    WALLPAPER_PATH=$(sed -n '5p' "$COLORS_QML" | sed 's/^\/\/\s*//' | xargs || echo "")
fi

# Fallback to assets/background.jpg
if [ -z "$WALLPAPER_PATH" ] || [ ! -f "${WALLPAPER_PATH/#\~/$USER_HOME}" ]; then
    if [ -f "$THEME_DIR/assets/background.jpg" ]; then
        WALLPAPER_PATH="$THEME_DIR/assets/background.jpg"
    fi
fi

# Expand ~ to home dir
WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$USER_HOME}"

# Validate wallpaper file
if ! WALLPAPER_PATH=$(validate_path "$WALLPAPER_PATH" "wallpaper"); then
    if [ -f "$THEME_DIR/assets/background.jpg" ]; then
        WALLPAPER_PATH="$THEME_DIR/assets/background.jpg"
    else
        echo "Error: no wallpaper available" >&2
        exit 5
    fi
fi

echo "[sddm-apply] Applying wallpaper: $WALLPAPER_PATH"

# --- Determine type and extension ---
WALLPAPER_BASENAME="$(basename "$WALLPAPER_PATH")"
WALLPAPER_EXT="${WALLPAPER_BASENAME##*.}"
WALLPAPER_EXT_LOWER=$(echo "$WALLPAPER_EXT" | tr '[:upper:]' '[:lower:]')

# --- Copy to destination ---
echo "Copying necessary files to SDDM..."

sudo mkdir -p -m 755 "$THEME_DIR/Components"
sudo mkdir -p -m 755 "$THEME_DIR/Backgrounds"

[ -f "$COLORS_QML" ] && sudo cp --no-dereference --preserve=mode,timestamps "$COLORS_QML" "$THEME_DIR/Components/Colors.qml"
[ -f "$SETTINGS_QML" ] && sudo cp --no-dereference --preserve=mode,timestamps "$SETTINGS_QML" "$THEME_DIR/Components/Settings.qml"

BACKGROUND_FILENAME="wallpaper.jpg"

if command -v magick &>/dev/null; then
    sudo magick "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
elif command -v convert &>/dev/null; then
    sudo convert "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
else
    BACKGROUND_FILENAME="wallpaper.${WALLPAPER_EXT_LOWER}"
    sudo cp "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
fi

# --- Modify theme.conf dynamically ---
CONF_FILE="$THEME_DIR/theme.conf"
if [ ! -f "$CONF_FILE" ]; then
    sudo tee "$CONF_FILE" > /dev/null << EOF
[General]
background=Backgrounds/wallpaper.jpg
EOF
fi

sudo sed -i -E \
    -e "s|^background=.*|background=Backgrounds/${BACKGROUND_FILENAME}|" \
    "$CONF_FILE"

sudo chmod 644 "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME" "$THEME_DIR/theme.conf"
[ -f "$THEME_DIR/Components/Colors.qml" ] && sudo chmod 644 "$THEME_DIR/Components/Colors.qml"
[ -f "$THEME_DIR/Components/Settings.qml" ] && sudo chmod 644 "$THEME_DIR/Components/Settings.qml"

echo "[caelestia-sddm] Applied successfully (background: $BACKGROUND_FILENAME)"
