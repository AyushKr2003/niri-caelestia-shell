#!/usr/bin/env bash

# Color generation script using matugen (no Python dependencies required)
# Generates material_colors.scss compatible with applycolor.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell/user"
OUTPUT_DIR="$STATE_DIR/generated"

# Default values
IMAGE_PATH=""
MODE="dark"
SCHEME_TYPE="scheme-tonal-spot"
TERM_SCHEME="$SCRIPT_DIR/terminal/scheme-base.json"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --path)
            IMAGE_PATH="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --scheme)
            SCHEME_TYPE="$2"
            shift 2
            ;;
        --termscheme)
            TERM_SCHEME="$2"
            shift 2
            ;;
        --cache)
            # Ignored for compatibility
            shift 2
            ;;
        --blend_bg_fg)
            # Ignored for compatibility
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ -z "$IMAGE_PATH" ]]; then
    echo "Usage: $0 --path <image_path> [--mode dark|light] [--scheme scheme-type]" >&2
    exit 1
fi

if [[ ! -f "$IMAGE_PATH" ]]; then
    echo "Error: Image not found: $IMAGE_PATH" >&2
    exit 1
fi

# Check for matugen
if ! command -v matugen &>/dev/null; then
    echo "Error: matugen not found. Please install it first." >&2
    exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Please install it first." >&2
    exit 1
fi

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Run matugen and get JSON output
MATUGEN_OUTPUT=$(matugen image "$IMAGE_PATH" --dry-run --json hex --mode "$MODE" --type "$SCHEME_TYPE" 2>/dev/null)

if [[ -z "$MATUGEN_OUTPUT" ]]; then
    echo "Error: matugen produced no output" >&2
    exit 1
fi

# Extract colors from matugen output
get_color() {
    local color_name="$1"
    echo "$MATUGEN_OUTPUT" | jq -r ".colors.${color_name}.${MODE} // .colors.${color_name}.default // empty"
}

# Get palette color (for key colors)
get_palette_color() {
    local palette_name="$1"
    local tone="$2"
    echo "$MATUGEN_OUTPUT" | jq -r ".palettes.${palette_name}.\"${tone}\" // empty"
}

# Start generating SCSS output
DARKMODE="true"
[[ "$MODE" == "light" ]] && DARKMODE="false"

echo "\$darkmode: $DARKMODE;"
echo "\$transparent: false;"

# Material colors from matugen
declare -A COLOR_MAP=(
    ["background"]="background"
    ["onBackground"]="on_background"
    ["surface"]="surface"
    ["surfaceDim"]="surface_dim"
    ["surfaceBright"]="surface_bright"
    ["surfaceContainerLowest"]="surface_container_lowest"
    ["surfaceContainerLow"]="surface_container_low"
    ["surfaceContainer"]="surface_container"
    ["surfaceContainerHigh"]="surface_container_high"
    ["surfaceContainerHighest"]="surface_container_highest"
    ["onSurface"]="on_surface"
    ["surfaceVariant"]="surface_variant"
    ["onSurfaceVariant"]="on_surface_variant"
    ["inverseSurface"]="inverse_surface"
    ["inverseOnSurface"]="inverse_on_surface"
    ["outline"]="outline"
    ["outlineVariant"]="outline_variant"
    ["shadow"]="shadow"
    ["scrim"]="scrim"
    ["surfaceTint"]="surface_tint"
    ["primary"]="primary"
    ["onPrimary"]="on_primary"
    ["primaryContainer"]="primary_container"
    ["onPrimaryContainer"]="on_primary_container"
    ["inversePrimary"]="inverse_primary"
    ["secondary"]="secondary"
    ["onSecondary"]="on_secondary"
    ["secondaryContainer"]="secondary_container"
    ["onSecondaryContainer"]="on_secondary_container"
    ["tertiary"]="tertiary"
    ["onTertiary"]="on_tertiary"
    ["tertiaryContainer"]="tertiary_container"
    ["onTertiaryContainer"]="on_tertiary_container"
    ["error"]="error"
    ["onError"]="on_error"
    ["errorContainer"]="error_container"
    ["onErrorContainer"]="on_error_container"
    ["primaryFixed"]="primary_fixed"
    ["primaryFixedDim"]="primary_fixed_dim"
    ["onPrimaryFixed"]="on_primary_fixed"
    ["onPrimaryFixedVariant"]="on_primary_fixed_variant"
    ["secondaryFixed"]="secondary_fixed"
    ["secondaryFixedDim"]="secondary_fixed_dim"
    ["onSecondaryFixed"]="on_secondary_fixed"
    ["onSecondaryFixedVariant"]="on_secondary_fixed_variant"
    ["tertiaryFixed"]="tertiary_fixed"
    ["tertiaryFixedDim"]="tertiary_fixed_dim"
    ["onTertiaryFixed"]="on_tertiary_fixed"
    ["onTertiaryFixedVariant"]="on_tertiary_fixed_variant"
)

for camel_name in "${!COLOR_MAP[@]}"; do
    snake_name="${COLOR_MAP[$camel_name]}"
    color=$(get_color "$snake_name")
    if [[ -n "$color" ]]; then
        echo "\$${camel_name}: ${color};"
    fi
done

# Palette key colors
primary_key=$(get_palette_color "primary" "40")
secondary_key=$(get_palette_color "secondary" "40")
tertiary_key=$(get_palette_color "tertiary" "40")
neutral_key=$(get_palette_color "neutral" "40")
neutral_variant_key=$(get_palette_color "neutral_variant" "40")

[[ -n "$primary_key" ]] && echo "\$primary_paletteKeyColor: ${primary_key};"
[[ -n "$secondary_key" ]] && echo "\$secondary_paletteKeyColor: ${secondary_key};"
[[ -n "$tertiary_key" ]] && echo "\$tertiary_paletteKeyColor: ${tertiary_key};"
[[ -n "$neutral_key" ]] && echo "\$neutral_paletteKeyColor: ${neutral_key};"
[[ -n "$neutral_variant_key" ]] && echo "\$neutral_variant_paletteKeyColor: ${neutral_variant_key};"

# Extended material - success colors
if [[ "$MODE" == "dark" ]]; then
    echo "\$success: #B5CCBA;"
    echo "\$onSuccess: #213528;"
    echo "\$successContainer: #374B3E;"
    echo "\$onSuccessContainer: #D1E9D6;"
else
    echo "\$success: #4F6354;"
    echo "\$onSuccess: #FFFFFF;"
    echo "\$successContainer: #D1E8D5;"
    echo "\$onSuccessContainer: #0C1F13;"
fi

# Terminal colors - generate dynamically from matugen palette
# The palette provides different tones (0-100) for each color family
# We map terminal colors to appropriate palette tones for the selected variant

if [[ "$MODE" == "dark" ]]; then
    # Dark mode: use lighter tones for visibility
    term0=$(get_palette_color "neutral" "10")        # Background (very dark)
    term1=$(get_color "error")                        # Red - error color
    term2=$(get_palette_color "tertiary" "60")        # Green - tertiary
    term3=$(get_palette_color "secondary" "70")       # Yellow - secondary bright
    term4=$(get_palette_color "primary" "60")         # Blue - primary
    term5=$(get_palette_color "tertiary" "70")        # Magenta - tertiary bright
    term6=$(get_palette_color "secondary" "60")       # Cyan - secondary
    term7=$(get_palette_color "neutral" "80")         # White - neutral light
    term8=$(get_palette_color "neutral" "30")         # Bright black
    term9=$(get_color "error_container")              # Bright red
    term10=$(get_palette_color "tertiary" "70")       # Bright green
    term11=$(get_palette_color "secondary" "80")      # Bright yellow
    term12=$(get_palette_color "primary" "70")        # Bright blue
    term13=$(get_palette_color "tertiary" "80")       # Bright magenta
    term14=$(get_palette_color "secondary" "70")      # Bright cyan
    term15=$(get_palette_color "neutral" "95")        # Bright white
else
    # Light mode: use darker tones for visibility
    term0=$(get_palette_color "neutral" "99")         # Background (very light)
    term1=$(get_color "error")                        # Red - error color
    term2=$(get_palette_color "tertiary" "40")        # Green - tertiary
    term3=$(get_palette_color "secondary" "30")       # Yellow - secondary dark
    term4=$(get_palette_color "primary" "40")         # Blue - primary
    term5=$(get_palette_color "tertiary" "30")        # Magenta - tertiary dark
    term6=$(get_palette_color "secondary" "40")       # Cyan - secondary
    term7=$(get_palette_color "neutral" "20")         # Black - neutral dark
    term8=$(get_palette_color "neutral" "70")         # Bright black
    term9=$(get_color "error_container")              # Bright red
    term10=$(get_palette_color "tertiary" "30")       # Bright green
    term11=$(get_palette_color "secondary" "20")      # Bright yellow
    term12=$(get_palette_color "primary" "30")        # Bright blue
    term13=$(get_palette_color "tertiary" "20")       # Bright magenta
    term14=$(get_palette_color "secondary" "30")      # Bright cyan
    term15=$(get_palette_color "neutral" "5")         # Bright white (darkest)
fi

# Output terminal colors with fallbacks
[[ -n "$term0" ]] && echo "\$term0: ${term0};" || echo "\$term0: #282828;"
[[ -n "$term1" ]] && echo "\$term1: ${term1};" || echo "\$term1: #CC241D;"
[[ -n "$term2" ]] && echo "\$term2: ${term2};" || echo "\$term2: #98971A;"
[[ -n "$term3" ]] && echo "\$term3: ${term3};" || echo "\$term3: #D79921;"
[[ -n "$term4" ]] && echo "\$term4: ${term4};" || echo "\$term4: #458588;"
[[ -n "$term5" ]] && echo "\$term5: ${term5};" || echo "\$term5: #B16286;"
[[ -n "$term6" ]] && echo "\$term6: ${term6};" || echo "\$term6: #689D6A;"
[[ -n "$term7" ]] && echo "\$term7: ${term7};" || echo "\$term7: #A89984;"
[[ -n "$term8" ]] && echo "\$term8: ${term8};" || echo "\$term8: #928374;"
[[ -n "$term9" ]] && echo "\$term9: ${term9};" || echo "\$term9: #FB4934;"
[[ -n "$term10" ]] && echo "\$term10: ${term10};" || echo "\$term10: #B8BB26;"
[[ -n "$term11" ]] && echo "\$term11: ${term11};" || echo "\$term11: #FABD2F;"
[[ -n "$term12" ]] && echo "\$term12: ${term12};" || echo "\$term12: #83A598;"
[[ -n "$term13" ]] && echo "\$term13: ${term13};" || echo "\$term13: #D3869B;"
[[ -n "$term14" ]] && echo "\$term14: ${term14};" || echo "\$term14: #8EC07C;"
[[ -n "$term15" ]] && echo "\$term15: ${term15};" || echo "\$term15: #EBDBB2;"
