#!/usr/bin/env bash

# switchwall.sh — Generate Material You colors from a wallpaper image
#
# Orchestrates the full color pipeline (same as end-4 dotfiles):
#   1. Set GNOME color-scheme (dark/light)
#   2. Generate material_colors.scss via Python materialyoucolor
#   3. Run matugen templates (~/.config/matugen/config.toml)
#   4. Apply terminal escape sequences
#   5. Apply Kvantum Qt theme colors
#   6. Apply VS Code accent color
#
# Shell-side matugen JSON is handled by QML (Schemes.qml dynamicSchemeGenerator).
#
# Usage: switchwall.sh [--mode dark|light] [--type scheme-type] <image_path>

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

TERMINAL_SCHEME="$SCRIPT_DIR/terminal/scheme-base.json"
PIDFILE="/run/user/$(id -u)/switchwall.pid"
VALID_SCHEME_TYPES=(
    scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad
    scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot
    scheme-vibrant
)

# Set GNOME desktop color-scheme to match the selected mode.
set_desktop_mode() {
    local mode="$1"
    case "$mode" in
        dark)
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'  2>/dev/null || true
            gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3-dark' 2>/dev/null || true
            ;;
        light)
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
            gsettings set org.gnome.desktop.interface gtk-theme    'adw-gtk3'      2>/dev/null || true
            ;;
    esac
}

# Kill any previous instance to avoid concurrent color generation.
acquire_lock() {
    if [[ -f "$PIDFILE" ]]; then
        local oldpid
        oldpid=$(cat "$PIDFILE" 2>/dev/null) || true
        if [[ -n "$oldpid" ]] && kill -0 "$oldpid" 2>/dev/null; then
            kill "$oldpid" 2>/dev/null || true
            wait "$oldpid" 2>/dev/null || true
        fi
    fi
    echo $$ > "$PIDFILE"
    trap 'rm -f "$PIDFILE"' EXIT
}

# Activate Python virtual environment
activate_venv() {
    if [[ -n "$PYTHON_VENV" ]]; then
        local venv_path
        venv_path=$(eval echo "$PYTHON_VENV")
        if [[ -f "$venv_path/bin/activate" ]]; then
            source "$venv_path/bin/activate"
            return 0
        fi
    fi
    warn "Python venv not found at $PYTHON_VENV; using system Python"
    return 0
}

# Run the Python color generator, producing material_colors.scss.
generate_colors() {
    local -a py_args=("$@")

    activate_venv

    if ! python3 "$SCRIPT_DIR/generate_colors_material.py" "${py_args[@]}" > "$SCSS_FILE" 2>/dev/null; then
        die "Color generation failed"
    fi
}

# Run matugen to process user templates from ~/.config/matugen/config.toml
run_matugen_templates() {
    local imgpath="$1" mode="$2" scheme_type="$3"

    if ! command -v matugen &>/dev/null; then
        warn "matugen not found — skipping template processing"
        return
    fi

    matugen image "$imgpath" --mode "$mode" --type "$scheme_type" --source-color-index 0 &>/dev/null &
}

# Post-processing: KDE/Dolphin colors + VS Code accent color
post_process() {
    local scheme_type="$1"

    # Apply KDE Material You colors (Dolphin, kdeglobals, etc.)
    local kde_wrapper="$SCRIPT_DIR/kde/kde-material-you-colors-wrapper.sh"
    if [[ -f "$kde_wrapper" ]]; then
        "$kde_wrapper" --scheme-variant "$scheme_type" &
    fi

    "$SCRIPT_DIR/code/material-code-set-color.sh" &

    # Sync SDDM if shell-integrate was chosen
    local sddm_sync="$HOME/.config/niri-caelestia-sddm/shell-sync.sh"
    if [[ -f "$sddm_sync" ]]; then
        echo "[switchwall] Triggering SDDM color sync..."
        bash "$sddm_sync"
    fi
}

switch() {
    local imgpath="$1" mode="$2" scheme_type="$3"

    [[ -n "$imgpath" ]] || die "No image path provided"
    [[ -f "$imgpath" ]] || die "Image not found: $imgpath"

    acquire_lock

    # Extract frame if video
    local actual_img="$imgpath"
    if [[ "$imgpath" =~ \.(mp4|mkv|webm|mov|avi|m4v|MP4|MKV|WEBM|MOV|AVI|M4V)$ ]]; then
        local frames_dir="$GENERATED_DIR/video_frames"
        mkdir -p "$frames_dir"
        local hash
        if command -v md5sum &>/dev/null; then
            # Use printf %s to avoid echo nuances and ensure hash matches Qt.md5
            hash=$(printf %s "$imgpath" | md5sum | cut -d' ' -f1)
        else
            hash=$(basename "$imgpath" | tr -cd '[:alnum:]')
        fi
        local frame_path="$frames_dir/${hash}.png"
        
        if [[ ! -f "$frame_path" ]]; then
            if command -v ffmpeg &>/dev/null; then
                # -ss 0 for fast seek, -an to ignore audio, -vframes 1 for a single frame
                # try hardware then software, completely silent
                ffmpeg -y -ss 0 -hwaccel auto -i "$imgpath" -an -vframes 1 "$frame_path" &>/dev/null || \
                ffmpeg -y -ss 0 -hwaccel none -i "$imgpath" -an -vframes 1 "$frame_path" &>/dev/null || true
            fi
        fi
        
        if [[ -f "$frame_path" ]]; then
            actual_img="$frame_path"
        fi
    fi

    # Resolve mode from GNOME settings when not provided
    if [[ -z "$mode" ]]; then
        local current
        current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        mode=$( [[ "$current" == "prefer-dark" ]] && echo dark || echo light )
    fi

    : "${scheme_type:=scheme-tonal-spot}"

    # -- 1. Desktop theme mode --
    set_desktop_mode "$mode"

    # Build args for Python generate_colors_material.py
    local -a py_args=(
        --path "$actual_img"
        --mode "$mode"
        --scheme "$scheme_type"
        --termscheme "$TERMINAL_SCHEME"
        --blend_bg_fg
        --cache "$GENERATED_DIR/color.txt"
    )

    # -- 2. Generate material_colors.scss via Python --
    generate_colors "${py_args[@]}" || true

    # -- 3. Run matugen templates (user define matugen templates) --
    run_matugen_templates "$actual_img" "$mode" "$scheme_type"

    # -- 4. Apply terminal escape sequences --
    if [[ -f "$SCRIPT_DIR/applycolor.sh" ]]; then
        "$SCRIPT_DIR/applycolor.sh"
    fi

    # -- 5. Apply Kvantum Qt theme colors --
    if [[ -f "$SCRIPT_DIR/kvantum/materialQT.sh" ]]; then
        bash "$SCRIPT_DIR/kvantum/materialQT.sh" &
    fi

    # -- 6. KDE/Dolphin colors + VS Code --
    post_process "$scheme_type"
}

parse_args() {
    local imgpath=""
    local mode=""
    local scheme_type=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)   mode="$2";        shift 2 ;;
            --type)   scheme_type="$2";  shift 2 ;;
            --image)  imgpath="$2";      shift 2 ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate scheme type
    if [[ -n "$scheme_type" ]]; then
        local valid=0
        for t in "${VALID_SCHEME_TYPES[@]}"; do
            [[ "$scheme_type" == "$t" ]] && { valid=1; break; }
        done
        if (( !valid )); then
            warn "Invalid scheme type '$scheme_type', using 'scheme-tonal-spot'"
            scheme_type="scheme-tonal-spot"
        fi
    fi

    [[ -n "$imgpath" ]] || die "Usage: switchwall.sh [--mode dark|light] [--type scheme-type] <image_path>"
    [[ -f "$imgpath" ]] || die "Image not found: $imgpath"

    switch "$imgpath" "$mode" "$scheme_type"
}

parse_args "$@"
