#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="niri-caelestia-shell"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$CONFIG_DIR/shell.json"

term_alpha=100 #Set this to < 100 make all your terminals transparent

if [ ! -d "$STATE_DIR"/generated ]; then
  mkdir -p "$STATE_DIR"/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

# Check if material_colors.scss exists
if [ ! -f "$STATE_DIR/generated/material_colors.scss" ]; then
  echo "material_colors.scss not found. Run color generation first."
  exit 1
fi

colornames=$(cat $STATE_DIR/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/generated/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$STATE_DIR"/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_gtk_kde() {
  local scss_file="$STATE_DIR/generated/material_colors.scss"
  if [ ! -f "$scss_file" ]; then
    return
  fi
  
  # Extract colors from scss (format: $colorname: #hex;)
  get_color() {
    grep "^\$$1:" "$scss_file" | cut -d: -f2 | tr -d ' ;'
  }
  
  local bg=$(get_color "background")
  local fg=$(get_color "onBackground")
  local primary=$(get_color "primary")
  local on_primary=$(get_color "onPrimary")
  local surface=$(get_color "surface")
  local surface_dim=$(get_color "surfaceDim")
  
  # Call apply-gtk-theme.sh with extracted colors
  "$SCRIPT_DIR/apply-gtk-theme.sh" "$bg" "$fg" "$primary" "$on_primary" "$surface" "$surface_dim"
}

# Read config from shell.json if it exists
enable_terminal="true"
enable_apps_shell="true"
enable_qt_apps="true"

if [ -f "$SHELL_CONFIG_FILE" ] && command -v jq &>/dev/null; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
  enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
  enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps // true' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "true")
fi

# Apply terminal theming
if [ "$enable_terminal" != "false" ]; then
  apply_term &
fi

# Apply GTK/KDE theming
if [ "$enable_apps_shell" != "false" ] || [ "$enable_qt_apps" != "false" ]; then
  apply_gtk_kde &
fi

# Wait for background jobs
wait
