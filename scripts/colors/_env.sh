# _env.sh — Shared constants and utilities for niri-caelestia-shell color scripts
#
# Source this file at the top of every color script in this directory:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

QUICKSHELL_CONFIG_NAME="niri-caelestia-shell"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell/user"
SHELL_CONFIG_FILE="$CONFIG_DIR/shell.json"
GENERATED_DIR="$STATE_DIR/generated"
SCSS_FILE="$GENERATED_DIR/material_colors.scss"

# Python virtual environment for materialyoucolor and friends
PYTHON_VENV="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-}"

mkdir -p "$GENERATED_DIR"

# Read a JSON value from shell.json. Falls back to $2 if jq or file is missing.
# Usage: config_get '.some.json.path' 'default_value'
config_get() {
    local jq_path="$1" default="${2:-true}"
    if [[ -f "$SHELL_CONFIG_FILE" ]] && command -v jq &>/dev/null; then
        jq -r "${jq_path} // \"${default}\"" "$SHELL_CONFIG_FILE" 2>/dev/null || echo "$default"
    else
        echo "$default"
    fi
}

log()  { echo "[${0##*/}] $*" >&2; }
warn() { echo "[${0##*/}] WARNING: $*" >&2; }
die()  { echo "[${0##*/}] ERROR: $*" >&2; exit 1; }
