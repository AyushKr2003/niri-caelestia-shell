#!/usr/bin/env bash

# applycolor.sh — Apply generated Material You colors to terminal, GTK, KDE and Qt
#
# Reads $STATE_DIR/generated/material_colors.scss and applies:
#   - Terminal escape sequences (live color update via /dev/pts/*)
#   - GTK 3/4 CSS overrides
#   - KDE globals + Darkly color scheme for Qt

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_env.sh"

# --- Configuration ---------------------------------------------------------

TERM_ALPHA=$(config_get '.appearance.wallpaperTheming.terminalAlpha' '100')

GTK4_CSS="$HOME/.config/gtk-4.0/gtk.css"
GTK3_CSS="$HOME/.config/gtk-3.0/gtk.css"
KDEGLOBALS="$HOME/.config/kdeglobals"
DARKLY_COLORS="$HOME/.local/share/color-schemes/Darkly.colors"

# --- SCSS parsing ----------------------------------------------------------

declare -A COLORS=()

parse_scss() {
    [[ -f "$SCSS_FILE" ]] || die "material_colors.scss not found — run color generation first"

    while IFS= read -r line; do
        # Match lines like: $varName: #hexval;
        [[ "$line" == \$* ]] || continue
        local name="${line%%:*}"    # everything before first :
        local value="${line#*: }"   # everything after ": "
        name="${name#\$}"           # strip leading $
        value="${value%;}"           # strip trailing ;
        value="${value# }"           # strip leading space
        [[ -n "$name" && -n "$value" ]] && COLORS["$name"]="$value"
    done < "$SCSS_FILE"
}

# --- Shared helpers --------------------------------------------------------

adjust_color() {
    local hex="${1#\#}"
    local amount="$2"
    local r=$((0x${hex:0:2} + amount))
    local g=$((0x${hex:2:2} + amount))
    local b=$((0x${hex:4:2} + amount))
    ((r < 0)) && r=0; ((r > 255)) && r=255
    ((g < 0)) && g=0; ((g > 255)) && g=255
    ((b < 0)) && b=0; ((b > 255)) && b=255
    printf "#%02x%02x%02x" $r $g $b
}

hex_to_rgb() {
    local hex="${1#\#}"
    local r=$((0x${hex:0:2}))
    local g=$((0x${hex:2:2}))
    local b=$((0x${hex:4:2}))
    echo "$r,$g,$b"
}

# --- Terminal colors -------------------------------------------------------

apply_term() {
    local template="$SCRIPT_DIR/terminal/sequences.txt"
    [[ -f "$template" ]] || { warn "Terminal sequence template not found, skipping"; return; }

    mkdir -p "$GENERATED_DIR/terminal"

    # Build sed expression from color map
    local sed_expr=""
    for name in "${!COLORS[@]}"; do
        local val="${COLORS[$name]#\#}"  # strip # prefix
        sed_expr+="s/\\\$${name} #/${val}/g;"
    done
    sed_expr+="s/\\\$alpha/${TERM_ALPHA}/g;"

    sed "$sed_expr" "$template" > "$GENERATED_DIR/terminal/sequences.txt"

    # Write sequences to all owned PTYs
    local seq_file="$GENERATED_DIR/terminal/sequences.txt"
    for pty in /dev/pts/[0-9]*; do
        [[ -c "$pty" ]] || continue
        if [[ -O "$pty" && -w "$pty" ]]; then
            cat "$seq_file" > "$pty" 2>/dev/null &
        fi
    done
    disown -a 2>/dev/null || true
}

# --- GTK / KDE / Qt -------------------------------------------------------

apply_gtk_kde() {
    local BG="${COLORS[background]:-}"
    local FG="${COLORS[onBackground]:-}"
    local PRIMARY="${COLORS[primary]:-}"
    local ON_PRIMARY="${COLORS[onPrimary]:-}"
    local SURFACE="${COLORS[surface]:-}"
    local SURFACE_DIM="${COLORS[surfaceDim]:-}"

    if [[ -z "$BG" || -z "$FG" || -z "$PRIMARY" ]]; then
        warn "Missing required colors for GTK/KDE theming"
        return
    fi

    local BG_ALT BG_DARK FG_INACTIVE
    BG_ALT=$(adjust_color "$BG" 20)
    BG_DARK=$(adjust_color "$BG" -20)
    FG_INACTIVE=$(adjust_color "$FG" -60)

    # --- GTK 3/4 CSS ---
    local gtk_css
    gtk_css=$(cat << GTKEOF
@define-color accent_color ${PRIMARY};
@define-color accent_fg_color ${ON_PRIMARY};
@define-color accent_bg_color ${PRIMARY};
@define-color window_bg_color ${BG};
@define-color window_fg_color ${FG};
@define-color headerbar_bg_color ${SURFACE_DIM};
@define-color headerbar_fg_color ${FG};
@define-color view_bg_color ${SURFACE};
@define-color view_fg_color ${FG};
@define-color sidebar_bg_color ${BG};
@define-color sidebar_fg_color ${FG};
@define-color sidebar_backdrop_color ${BG};

placessidebar, placessidebar list { background-color: ${BG} !important; color: ${FG} !important; }
placessidebar row:selected { background-color: ${PRIMARY} !important; color: ${ON_PRIMARY} !important; }
.nautilus-window headerbar, .nautilus-window .view { background-color: ${BG} !important; color: ${FG} !important; }

/* Backdrop (unfocused) state */
placessidebar:backdrop, placessidebar list:backdrop { background-color: ${BG} !important; color: ${FG} !important; }
.nautilus-window:backdrop headerbar, .nautilus-window:backdrop .view { background-color: ${BG} !important; color: ${FG} !important; }
.nautilus-window:backdrop placessidebar { background-color: ${BG} !important; }
window:backdrop { background-color: ${BG} !important; }
GTKEOF
    )

    mkdir -p "$(dirname "$GTK4_CSS")" "$(dirname "$GTK3_CSS")"
    [[ -L "$GTK4_CSS" ]] && rm "$GTK4_CSS"
    [[ -L "$GTK3_CSS" ]] && rm "$GTK3_CSS"
    echo "$gtk_css" > "$GTK4_CSS"
    echo "$gtk_css" > "$GTK3_CSS"

    # --- KDE globals ---
    local icon_theme
    icon_theme=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'")
    [[ -z "$icon_theme" ]] && icon_theme="Adwaita"

    cat > "$KDEGLOBALS" << KDEEOF
[ColorEffects:Disabled]
Color=${BG}
ColorAmount=0.5
ColorEffect=3
ContrastAmount=0
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=${BG_DARK}
ColorAmount=0.025
ColorEffect=0
ContrastAmount=0.1
ContrastEffect=0
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${SURFACE}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Selection]
BackgroundAlternate=${PRIMARY}
BackgroundNormal=${PRIMARY}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${ON_PRIMARY}
ForegroundInactive=${ON_PRIMARY}
ForegroundLink=${ON_PRIMARY}
ForegroundNegative=${ON_PRIMARY}
ForegroundNeutral=${ON_PRIMARY}
ForegroundNormal=${ON_PRIMARY}
ForegroundPositive=${ON_PRIMARY}
ForegroundVisited=${ON_PRIMARY}

[Colors:Tooltip]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:View]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Window]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Complementary]
BackgroundAlternate=${BG_DARK}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Header]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Header][Inactive]
BackgroundAlternate=${BG}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[Colors:Menu]
BackgroundAlternate=${BG_ALT}
BackgroundNormal=${BG}
DecorationFocus=${PRIMARY}
DecorationHover=${PRIMARY}
ForegroundActive=${FG}
ForegroundInactive=${FG_INACTIVE}
ForegroundLink=${PRIMARY}
ForegroundNegative=#ff6b6b
ForegroundNeutral=#ffa94d
ForegroundNormal=${FG}
ForegroundPositive=#69db7c
ForegroundVisited=${PRIMARY}

[General]
ColorScheme=Darkly

[Icons]
Theme=${icon_theme}

[KDE]
widgetStyle=Darkly

[WM]
activeBackground=${BG}
activeBlend=${FG}
activeForeground=${FG}
inactiveBackground=${BG}
inactiveBlend=${FG_INACTIVE}
inactiveForeground=${FG_INACTIVE}
KDEEOF

    # --- Darkly color scheme for Qt ---
    if [[ "$enable_qt" != "false" ]]; then
        local bg_rgb bg_alt_rgb bg_dark_rgb fg_rgb fg_inactive_rgb primary_rgb on_primary_rgb surface_rgb
        bg_rgb=$(hex_to_rgb "$BG")
        bg_alt_rgb=$(hex_to_rgb "$BG_ALT")
        bg_dark_rgb=$(hex_to_rgb "$BG_DARK")
        fg_rgb=$(hex_to_rgb "$FG")
        fg_inactive_rgb=$(hex_to_rgb "$FG_INACTIVE")
        primary_rgb=$(hex_to_rgb "$PRIMARY")
        on_primary_rgb=$(hex_to_rgb "$ON_PRIMARY")
        surface_rgb=$(hex_to_rgb "$SURFACE")

        mkdir -p "$(dirname "$DARKLY_COLORS")"
        cat > "$DARKLY_COLORS" << DARKEOF
[ColorEffects:Disabled]
Color=${bg_rgb}
ColorAmount=0.5
ColorEffect=3
ContrastAmount=0.5
ContrastEffect=0
IntensityAmount=0
IntensityEffect=0

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=${bg_dark_rgb}
ColorAmount=0.4
ColorEffect=3
ContrastAmount=0.4
ContrastEffect=0
Enable=true
IntensityAmount=-0.2
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${surface_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:Complementary]
BackgroundAlternate=${bg_dark_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=237,21,21
ForegroundNeutral=201,206,59
ForegroundNormal=${fg_rgb}
ForegroundPositive=17,209,22
ForegroundVisited=${primary_rgb}

[Colors:Selection]
BackgroundAlternate=${primary_rgb}
BackgroundNormal=${primary_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${on_primary_rgb}
ForegroundInactive=${on_primary_rgb}
ForegroundLink=${on_primary_rgb}
ForegroundNegative=${on_primary_rgb}
ForegroundNeutral=${on_primary_rgb}
ForegroundNormal=${on_primary_rgb}
ForegroundPositive=${on_primary_rgb}
ForegroundVisited=${on_primary_rgb}

[Colors:Tooltip]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:View]
BackgroundAlternate=${bg_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[Colors:Window]
BackgroundAlternate=${bg_alt_rgb}
BackgroundNormal=${bg_rgb}
DecorationFocus=${primary_rgb}
DecorationHover=${primary_rgb}
ForegroundActive=${fg_rgb}
ForegroundInactive=${fg_inactive_rgb}
ForegroundLink=${primary_rgb}
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=${fg_rgb}
ForegroundPositive=36,173,89
ForegroundVisited=${primary_rgb}

[General]
ColorScheme=Darkly
Name=Darkly
shadeSortColumn=true

[KDE]
contrast=0

[WM]
activeBackground=${bg_rgb}
activeBlend=255,255,255
activeForeground=${fg_rgb}
inactiveBackground=${bg_rgb}
inactiveBlend=${fg_inactive_rgb}
inactiveForeground=${fg_inactive_rgb}
DARKEOF
    fi

    # Restart Nautilus to pick up new colors
    nautilus -q 2>/dev/null &
}

# --- Main ------------------------------------------------------------------

parse_scss

enable_terminal=$(config_get '.appearance.wallpaperTheming.enableTerminal' 'true')
enable_apps=$(config_get     '.appearance.wallpaperTheming.enableAppsAndShell' 'true')
enable_qt=$(config_get       '.appearance.wallpaperTheming.enableQtApps' 'true')

if [[ "$enable_terminal" != "false" ]]; then
    apply_term &
fi

if [[ "$enable_apps" != "false" || "$enable_qt" != "false" ]]; then
    apply_gtk_kde &
fi

wait
