#!/usr/bin/env bash

## sddm-theme-apply.sh — applies colors + wallpaper into installed theme
## Workflow matched to ii-sddm-theme with Matugen integration

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

# --- Colors.qml source ---
COLORS_QML_SOURCE="$CONFIG_DIR/Colors.qml"

if [ ! -f "$COLORS_QML_SOURCE" ]; then
    echo "Error: Colors.qml not found at: $COLORS_QML_SOURCE" >&2
    exit 3
fi

# --- Extract wallpaper path (line 5) ---
WALLPAPER_PATH=$(sed -n '5p' "$COLORS_QML_SOURCE" | sed 's/^\/\/\s*//' | xargs || echo "")

# Fallback to assets/background.jpg if extraction fails or file missing
if [ -z "$WALLPAPER_PATH" ] || [ ! -f "${WALLPAPER_PATH/#\~/$USER_HOME}" ]; then
    if [ -f "$THEME_DIR/assets/background.jpg" ]; then
        WALLPAPER_PATH="$THEME_DIR/assets/background.jpg"
    fi
fi

# Expand ~ to home dir
WALLPAPER_PATH="${WALLPAPER_PATH/#\~/$USER_HOME}"

# Validate wallpaper file
if ! WALLPAPER_PATH=$(validate_path "$WALLPAPER_PATH" "wallpaper"); then
    echo "Warning: wallpaper path invalid or missing, using default if possible" >&2
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

IMAGE_EXTS=("png" "jpg" "jpeg" "webp" "gif")
VIDEO_EXTS=("avi" "mp4" "mov" "mkv" "m4v" "webm")

IS_IMAGE=false
IS_VIDEO=false
for ext in "${IMAGE_EXTS[@]}"; do
    [[ "$WALLPAPER_EXT_LOWER" == "$ext" ]] && IS_IMAGE=true
done
for ext in "${VIDEO_EXTS[@]}"; do
    [[ "$WALLPAPER_EXT_LOWER" == "$ext" ]] && IS_VIDEO=true
done

if [ "$IS_IMAGE" = false ] && [ "$IS_VIDEO" = false ]; then
    echo "Error: unsupported wallpaper type: .$WALLPAPER_EXT_LOWER" >&2
    exit 6
fi

# --- Copy to destination with optional conversion ---
echo "Copying necessary files to SDDM..."

sudo mkdir -p -m 755 "$THEME_DIR/Components"
sudo mkdir -p -m 755 "$THEME_DIR/Backgrounds"

sudo cp --no-dereference --preserve=mode,timestamps "$CONFIG_DIR/Colors.qml" "$THEME_DIR/Components/Colors.qml"
sudo cp --no-dereference --preserve=mode,timestamps "$CONFIG_DIR/Settings.qml" "$THEME_DIR/Components/Settings.qml"

BACKGROUND_FILENAME="wallpaper.jpg" # Default to jpg for best compatibility

if [ "$IS_IMAGE" = true ]; then
    # Use magick to convert to optimized jpg if possible
    if command -v magick &>/dev/null; then
        sudo magick "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
    elif command -v convert &>/dev/null; then
        sudo convert "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
    else
        # Direct copy if no ImageMagick
        BACKGROUND_FILENAME="wallpaper.${WALLPAPER_EXT_LOWER}"
        sudo cp "$WALLPAPER_PATH" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME"
    fi
else
    # Video wallpaper
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

sudo chmod 644 "$THEME_DIR/Components/Colors.qml" "$THEME_DIR/Components/Settings.qml" "$THEME_DIR/Backgrounds/$BACKGROUND_FILENAME" "$THEME_DIR/theme.conf"

echo "[caelestia-sddm] Applied successfully (background: $BACKGROUND_FILENAME)"
