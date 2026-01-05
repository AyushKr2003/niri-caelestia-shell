#!/usr/bin/env bash

# Wallpaper color generation script for niri-caelestia-shell
# Generates Material You colors from wallpaper using matugen and custom scripts

QUICKSHELL_CONFIG_NAME="niri-caelestia-shell"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell/user"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$CONFIG_DIR/shell.json"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"

# Ensure directories exist
mkdir -p "$STATE_DIR/generated"

pre_process() {
    local mode_flag="$1"
    # Set GNOME color-scheme if mode_flag is dark or light
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null || true
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3' 2>/dev/null || true
    fi
}

post_process() {
    # Run VS Code color script if it exists
    if [ -f "$SCRIPT_DIR/code/material-code-set-color.sh" ]; then
        "$SCRIPT_DIR/code/material-code-set-color.sh" &
    fi
}

get_max_monitor_resolution() {
    local width=1920
    local height=1080
    # Try Niri first
    if command -v niri >/dev/null 2>&1 && niri msg outputs >/dev/null 2>&1; then
        local res=$(niri msg outputs 2>/dev/null | grep -oP 'Current mode: \K\d+x\d+' | sort -t'x' -k1 -nr | head -1)
        if [[ -n "$res" ]]; then
            width=$(echo "$res" | cut -d'x' -f1)
            height=$(echo "$res" | cut -d'x' -f2)
        fi
    fi
    echo "$width $height"
}

switch() {
    local imgpath="$1"
    local mode_flag="$2"
    local type_flag="$3"

    if [[ -z "$imgpath" ]]; then
        echo "No image path provided"
        exit 1
    fi

    if [[ ! -f "$imgpath" ]]; then
        echo "Image not found: $imgpath"
        exit 1
    fi

    # Determine mode if not set
    if [[ -z "$mode_flag" ]]; then
        current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$current_mode" == "prefer-dark" ]]; then
            mode_flag="dark"
        else
            mode_flag="light"
        fi
    fi

    # Default scheme type
    if [[ -z "$type_flag" ]]; then
        type_flag="scheme-tonal-spot"
    fi

    local matugen_args=(image "$imgpath")
    local generate_colors_args=(--path "$imgpath")

    [[ -n "$mode_flag" ]] && matugen_args+=(--mode "$mode_flag")
    generate_colors_args+=(--mode "$mode_flag")

    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag")
    generate_colors_args+=(--scheme "$type_flag")

    generate_colors_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_args+=(--cache "$STATE_DIR/generated/color.txt")

    pre_process "$mode_flag"

    # Run matugen for GTK/Qt/other apps
    if command -v matugen &>/dev/null; then
        matugen "${matugen_args[@]}" &
    else
        echo "matugen not found, skipping matugen color generation"
    fi

    # Run Python color generator for terminal colors and material_colors.scss
    if [ -f "$SCRIPT_DIR/generate_colors_material.py" ]; then
        # Check if we have a virtual environment or use system python
        if [[ -n "$ILLOGICAL_IMPULSE_VIRTUAL_ENV" ]] && [ -f "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate" ]; then
            source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate"
            python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_args[@]}" \
                > "$STATE_DIR/generated/material_colors.scss"
            deactivate
        else
            # Try with system python (needs materialyoucolor package)
            python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_args[@]}" \
                > "$STATE_DIR/generated/material_colors.scss" 2>/dev/null || \
            echo "Python color generation failed. Install materialyoucolor: pip install materialyoucolor"
        fi
    fi

    # Apply colors to terminal and apps
    if [ -f "$SCRIPT_DIR/applycolor.sh" ]; then
        "$SCRIPT_DIR/applycolor.sh"
    fi

    # Generate Vesktop theme if script exists
    if [ -f "$SCRIPT_DIR/system24_palette.py" ]; then
        python3 "$SCRIPT_DIR/system24_palette.py" 2>/dev/null &
    fi

    post_process
}

main() {
    local imgpath=""
    local mode_flag=""
    local type_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --image)
                imgpath="$2"
                shift 2
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate type_flag
    allowed_types=(scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot)
    if [[ -n "$type_flag" ]]; then
        valid_type=0
        for t in "${allowed_types[@]}"; do
            if [[ "$type_flag" == "$t" ]]; then
                valid_type=1
                break
            fi
        done
        if [[ $valid_type -eq 0 ]]; then
            echo "Warning: Invalid type '$type_flag', defaulting to 'scheme-tonal-spot'" >&2
            type_flag="scheme-tonal-spot"
        fi
    fi

    if [[ -z "$imgpath" ]]; then
        echo "Usage: switchwall.sh [--mode dark|light] [--type scheme-type] <image_path>"
        echo "Or: switchwall.sh --image <image_path>"
        exit 1
    fi

    switch "$imgpath" "$mode_flag" "$type_flag"
}

main "$@"
