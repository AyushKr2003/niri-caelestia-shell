#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_env.sh"

color=$(tr -d '\n' < "$GENERATED_DIR/color.txt")

current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
if [[ "$current_mode" == "prefer-dark" ]]; then
    mode_flag="-d"
else
    mode_flag="-l"
fi

# Parse --scheme-variant flag
scheme_variant_str=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --scheme-variant)
            scheme_variant_str="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Map string variant to integer
case "$scheme_variant_str" in
    scheme-content) sv_num=0 ;;
    scheme-expressive) sv_num=1 ;;
    scheme-fidelity) sv_num=2 ;;
    scheme-monochrome) sv_num=3 ;;
    scheme-neutral) sv_num=4 ;;
    scheme-tonal-spot) sv_num=5 ;;
    scheme-vibrant) sv_num=6 ;;
    scheme-rainbow) sv_num=7 ;;
    scheme-fruit-salad) sv_num=8 ;;
    "") sv_num=5 ;;
    *)
        echo "Unknown scheme variant: $scheme_variant_str" >&2
        exit 1
        ;;
esac

if [[ -n "$PYTHON_VENV" ]]; then
    venv_path=$(eval echo "$PYTHON_VENV")
    if [[ -f "$venv_path/bin/activate" ]]; then
        source "$venv_path/bin/activate"
    fi
fi

# Run the patched version of the script to avoid crashes when KWin is not present
# and to avoid noisy stty warnings that occur in non-interactive shells.
# We redirect stderr to stdout (2>&1) so Quickshell logs these as DEBUG instead of WARN.
python3 "$SCRIPT_DIR/kde/patched-kmyc.py" "$mode_flag" --color "$color" -sv "$sv_num" 2>&1

deactivate 2>/dev/null || true
