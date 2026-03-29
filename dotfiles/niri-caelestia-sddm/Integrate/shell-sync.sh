#!/usr/bin/env bash

# shell-sync.sh — syncs SDDM colors and wallpaper with niri-caelestia-shell state
# Pulls from ~/.local/state/caelestia/scheme.json and ~/.local/state/caelestia/wallpaper/path.txt

set -euo pipefail

echo "[sddm-sync] Starting synchronization script..."

# --- User and Directories ---
REAL_USER="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
echo "[sddm-sync] Running as $REAL_USER, Home: $USER_HOME"
STATE_DIR="$USER_HOME/.local/state/caelestia"
CONFIG_DIR="$USER_HOME/.config/niri-caelestia-sddm"
SCHEME_JSON="$STATE_DIR/scheme.json"
WALLPAPER_TXT="$STATE_DIR/wallpaper/path.txt"
OUTPUT_QML="$CONFIG_DIR/Colors.qml"
APPLY_SCRIPT="$CONFIG_DIR/sddm-theme-apply.sh"

if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    echo "Error: invalid user home directory" >&2
    exit 1
fi

if [ ! -f "$SCHEME_JSON" ]; then
    echo "Error: Shell scheme not found at $SCHEME_JSON" >&2
    exit 1
fi

echo "[caelestia-sddm] Syncing colors from $SCHEME_JSON..."

# --- Get wallpaper path ---
WALL_PATH=""
if [ -f "$WALLPAPER_TXT" ]; then
    WALL_PATH=$(cat "$WALLPAPER_TXT")
fi

# --- Use jq to extract colors ---
if ! command -v jq &>/dev/null; then
    echo "Error: 'jq' is required for shell integration." >&2
    exit 1
fi

get_color() {
    local key="$1"
    local fallback="${2:-#ffffff}"
    local val
    val=$(jq -r ".colours.$key // empty" "$SCHEME_JSON")
    if [ -n "$val" ]; then
        [[ "$val" =~ ^# ]] && echo "$val" || echo "#$val"
    else
        echo "$fallback"
    fi
}

cat > "$OUTPUT_QML" << EOF
// Colors.qml — Integrated from shell state
import QtQuick

// ${WALL_PATH}

QtObject {
    // Basic Surfaces
    readonly property color background:          "$(get_color background "#111118")"
    readonly property color surface:             "$(get_color surface "#1c1b1f")"
    readonly property color surfaceVariant:      "$(get_color surfaceVariant "#49454f")"
    
    // Advanced Surfaces (Material 3)
    readonly property color surfaceContainer:    "$(get_color surfaceContainer "$(get_color surfaceVariant)")"
    readonly property color surfaceContainerHigh: "$(get_color surfaceContainerHigh "$(get_color surfaceVariant)")"
    readonly property color surfaceContainerHighest: "$(get_color surfaceContainerHighest "$(get_color surfaceVariant)")"

    // Accents
    readonly property color primary:             "$(get_color primary "#d0bcff")"
    readonly property color primaryContainer:    "$(get_color primaryContainer "#381e72")"
    readonly property color secondary:           "$(get_color secondary "#cbc2db")"
    readonly property color secondaryContainer:  "$(get_color secondaryContainer "#4a4458")"
    readonly property color tertiary:            "$(get_color tertiary "#efb8c8")"
    readonly property color tertiaryContainer:   "$(get_color tertiaryContainer "#633b48")"
    readonly property color error:               "$(get_color error "#f2b8b5")"

    // Text / On-colors (SDDM naming convention)
    readonly property color colSurface:          "$(get_color onSurface "#e6e1e5")"
    readonly property color colSurfaceVariant:   "$(get_color onSurfaceVariant "#cac4d0")"
    readonly property color colPrimary:          "$(get_color onPrimary "#21005d")"
    readonly property color colSecondary:        "$(get_color onSecondary "#332d41")"
    readonly property color colTertiary:         "$(get_color onTertiary "#492532")"
    readonly property color colError:            "$(get_color onError "#601410")"
    
    // Outlines
    readonly property color outline:             "$(get_color outline "#938f99")"
    readonly property color outlineVariant:      "$(get_color outlineVariant "#49454f")"
}
EOF

# --- Apply the theme ---
if [ -f "$APPLY_SCRIPT" ]; then
    sudo "$APPLY_SCRIPT"
    echo "[sddm-sync] Theme colors and wallpaper applied successfully."
fi
