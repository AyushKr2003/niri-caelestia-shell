#!/usr/bin/env bash

# applycolor.sh — Apply generated Material You colors to terminal
#
# Reads $GENERATED_DIR/material_colors.scss and applies:
#   - Terminal escape sequences (live color update via /dev/pts/*)

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

term_alpha=$(config_get '.appearance.wallpaperTheming.terminalAlpha' '100')

if [ ! -d "$GENERATED_DIR" ]; then
  mkdir -p "$GENERATED_DIR"
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

colornames=$(cut -d: -f1 "$SCSS_FILE")
colorstrings=$(cut -d: -f2 "$SCSS_FILE" | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_term() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    warn "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$GENERATED_DIR"/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$GENERATED_DIR"/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$GENERATED_DIR"/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$GENERATED_DIR/terminal/sequences.txt"

  for file in /dev/pts/*; do
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]]; then
      {
      cat "$GENERATED_DIR"/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

# Apply terminal theming (enabled by default)
enable_terminal=$(config_get '.appearance.wallpaperTheming.enableTerminal' 'true')
if [ "$enable_terminal" = "true" ]; then
  apply_term &
fi
