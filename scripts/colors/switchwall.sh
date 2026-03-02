#!/usr/bin/env bash

# switchwall.sh — Generate Material You colors from a wallpaper image
#
# Orchestrates the full color pipeline:
#   1. Set GNOME color-scheme (dark/light)
#   2. Run matugen for GTK/Qt theming
#   3. Generate material_colors.scss (terminal + shell palette)
#   4. Apply colors to terminals, GTK, KDE
#
# Usage: switchwall.sh [--mode dark|light] [--type scheme-type] <image_path>

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

TERMINAL_SCHEME="$SCRIPT_DIR/terminal/scheme-base.json"
PIDFILE="/run/user/$(id -u)/switchwall.pid"
VALID_SCHEME_TYPES=(
    scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad
    scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot
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

# Run the color generator, producing material_colors.scss.
generate_colors() {
    local -a args=("$@")

    if ! command -v matugen &>/dev/null; then
        die "matugen not found — install it to generate colors"
    fi
    if ! command -v jq &>/dev/null; then
        die "jq not found — install it to generate colors"
    fi

    if ! bash "$SCRIPT_DIR/generate_colors_matugen.sh" "${args[@]}" > "$SCSS_FILE" 2>/dev/null; then
        die "Color generation failed"
    fi
}

switch() {
    local imgpath="$1" mode="$2" scheme_type="$3"

    [[ -n "$imgpath" ]] || die "No image path provided"
    [[ -f "$imgpath" ]] || die "Image not found: $imgpath"

    acquire_lock

    # Resolve mode from GNOME settings when not provided
    if [[ -z "$mode" ]]; then
        local current
        current=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        mode=$( [[ "$current" == "prefer-dark" ]] && echo dark || echo light )
    fi

    : "${scheme_type:=scheme-tonal-spot}"

    # -- 1. Desktop theme mode --
    set_desktop_mode "$mode"

    # -- 2. Matugen (GTK / Qt templates) --
    local matugen_pid=""
    if command -v matugen &>/dev/null; then
        matugen image "$imgpath" --mode "$mode" --type "$scheme_type" &
        matugen_pid=$!
    else
        log "matugen not found, skipping GTK/Qt template generation"
    fi

    # -- 3. Generate material_colors.scss --
    generate_colors \
        --path   "$imgpath" \
        --mode   "$mode" \
        --scheme "$scheme_type" \
        --termscheme "$TERMINAL_SCHEME" \
        --blend_bg_fg \
        --cache  "$GENERATED_DIR/color.txt" \
    || true

    # -- 4. Wait for matugen before applying --
    if [[ -n "$matugen_pid" ]]; then
        wait "$matugen_pid" 2>/dev/null || true
    fi

    # -- 5. Apply colours (terminal, GTK, KDE) --
    if [[ -f "$SCRIPT_DIR/applycolor.sh" ]]; then
        "$SCRIPT_DIR/applycolor.sh"
    fi
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
