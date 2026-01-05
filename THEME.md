# Niri Caelestia Shell - Dynamic Color Theming

This guide explains how to set up automatic color generation from wallpapers for your shell and applications.

## Overview

The system uses **Matugen** to generate Material You colors from your wallpaper, then applies them to:
- **Terminal** - Live color updates via escape sequences
- **GTK3/GTK4** - Application theming
- **KDE/Qt** - File manager and application colors
- **Custom Apps** - Fuzzel launcher, Tmux, Starship, etc.

When you change your wallpaper, colors automatically regenerate and apply to all these applications.

## Prerequisites

### Required Packages

```bash
# Arch Linux
sudo pacman -S matugen python python-pillow python-materialyoucolor jq
```

### Optional Packages

For terminal color application:
```bash
# For live terminal theming
# Usually already installed, but verify:
ls /dev/pts/
```

For application integration:
```bash
# GTK theme support (auto-installed with GNOME)
# KDE Plasma (auto-installed with KDE)
# Fuzzel launcher (AUR: fuzzel-bin or fuzzel-git)
# Tmux (optional, for tmux theming)
# Starship (optional, for shell prompt theming)
```

## Setup Instructions

### Step 1: Install Matugen

Choose one method based on your system:

**Arch Linux (Recommended):**
```bash
sudo pacman -S matugen
```

**Build from source:**
```bash
git clone https://github.com/InioX/matugen.git
cd matugen
cargo build --release
sudo install -Dm755 target/release/matugen /usr/local/bin/
```

**Verify installation:**
```bash
matugen --version
```

### Step 2: Configure Matugen

Copy the example configuration to your home directory:

```bash
cp -r ~/.config/quickshell/niri-caelestia-shell/example_config/matugen ~/.config/
```

Or manually create `~/.config/matugen/config.toml`:

```toml
[config]
version_check = false

# Colors for Quickshell
[templates.m3colors]
input_path = '~/.config/matugen/templates/colors.json'
output_path = '~/.local/state/quickshell/user/generated/colors.json'

# GTK3 theme
[templates.gtk3]
input_path = '~/.config/matugen/templates/gtk-3.0/gtk.css'
output_path = '~/.config/gtk-3.0/gtk.css'

# GTK4 theme
[templates.gtk4]
input_path = '~/.config/matugen/templates/gtk-4.0/gtk.css'
output_path = '~/.config/gtk-4.0/gtk.css'

# KDE colors
[templates.kde_colors]
input_path = '~/.config/matugen/templates/kde/color.txt'
output_path = '~/.local/state/quickshell/user/generated/color.txt'

# Fuzzel launcher
[templates.fuzzel]
input_path = '~/.config/matugen/templates/fuzzel/fuzzel_theme.ini'
output_path = '~/.config/fuzzel/fuzzel_theme.ini'
```

### Step 3: Set Up Matugen Templates

Copy template files from the example config:

```bash
mkdir -p ~/.config/matugen/templates/{gtk-3.0,gtk-4.0,kde,fuzzel}
cp ~/.config/quickshell/niri-caelestia-shell/example_config/matugen/templates/* \
   ~/.config/matugen/templates/
```

**Key templates:**

#### colors.json (For Material Design colors)
```json
{
  "background": "{{colors.background.default.hex}}",
  "primary": "{{colors.primary.default.hex}}",
  "on_primary": "{{colors.on_primary.default.hex}}",
  "surface": "{{colors.surface.default.hex}}",
  "surface_dim": "{{colors.surface_dim.default.hex}}"
}
```

#### gtk.css (For GTK theme)
```css
@define-color accent_color {{colors.primary.dark.hex}};
@define-color window_bg_color {{colors.background.dark.hex}};
@define-color window_fg_color {{colors.on_background.dark.hex}};
```

### Step 4: Install Python Dependencies

The color generation scripts need `materialyoucolor`:

```bash
pip install materialyoucolor
# or for Arch:
sudo pacman -S python-materialyoucolor
```

### Step 5: Update Fish Shell Config (Optional)

To apply terminal colors when opening Fish shell, add to `~/.config/fish/config.fish`:

```bash
# Load generated terminal colors
if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
end
```

### Step 6: Create Required Directories

```bash
mkdir -p ~/.local/state/quickshell/user/generated/{terminal,wallpaper}
mkdir -p ~/.config/{gtk-3.0,gtk-4.0}
touch ~/.local/state/quickshell/user/generated/material_colors.scss
```

## Usage

### Automatic (When Changing Wallpaper)

When you change your wallpaper through the Quickshell UI:
1. The wallpaper path is saved
2. `switchwall.sh` is automatically invoked
3. Colors are generated and applied to all applications

### Manual (Using switchwall.sh)

Generate colors from a specific wallpaper:

```bash
# Dark mode (default)
bash ~/.config/quickshell/niri-caelestia-shell/scripts/colors/switchwall.sh /path/to/wallpaper.jpg

# Light mode
bash ~/.config/quickshell/niri-caelestia-shell/scripts/colors/switchwall.sh \
  --mode light /path/to/wallpaper.jpg

# Custom scheme variant
bash ~/.config/quickshell/niri-caelestia-shell/scripts/colors/switchwall.sh \
  --mode dark --type scheme-vibrant /path/to/wallpaper.jpg
```

### Manual (Using Matugen directly)

```bash
# Generate colors and update all configured apps
matugen image /path/to/wallpaper.jpg

# Light mode
matugen image --mode light /path/to/wallpaper.jpg

# Custom color scheme
matugen image --type scheme-vibrant /path/to/wallpaper.jpg
```

## Color Generation Scripts

### switchwall.sh
Main orchestration script that:
1. Runs `matugen` for GTK/Qt/other app colors
2. Runs Python color generator for terminal colors
3. Applies terminal escape sequences
4. Updates all configured applications

**Location:** `scripts/colors/switchwall.sh`

### applycolor.sh
Applies colors to:
- Terminal (escape sequences)
- GTK/KDE applications

**Location:** `scripts/colors/applycolor.sh`

### generate_colors_material.py
Python script that:
- Extracts dominant color from image
- Generates Material You palette
- Harmonizes terminal colors
- Outputs SCSS variables

**Location:** `scripts/colors/generate_colors_material.py`

### apply-gtk-theme.sh
Generates and applies GTK theme files from extracted colors

**Location:** `scripts/colors/apply-gtk-theme.sh`

## Scheme Types

Available Material Design schemes:

- `scheme-tonal-spot` (default) - Balanced, modern look
- `scheme-vibrant` - Saturated, bold colors
- `scheme-expressive` - Artistic, varied saturation
- `scheme-monochrome` - Single hue variations
- `scheme-neutral` - Muted, professional
- `scheme-content` - Based on content analysis
- `scheme-fidelity` - Most accurate to source
- `scheme-fruit-salad` - Multiple accent colors
- `scheme-rainbow` - Wide color spectrum

## Output Locations

Generated files are stored in:

```
~/.local/state/quickshell/user/generated/
├── colors.json              # Material You colors in JSON
├── material_colors.scss     # SCSS variables for terminal
├── color.txt                # KDE color specification
└── terminal/
    └── sequences.txt        # Terminal escape sequences
```

## Troubleshooting

### Colors not applying to terminal
```bash
# Verify sequences file exists
test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt && echo "OK" || echo "Missing"

# Manually source the file
cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
```

### GTK/Fuzzel colors not updating
```bash
# Verify Matugen runs successfully
matugen image ~/Pictures/Wallpapers/example.jpg --debug

# Check output files
ls -la ~/.config/gtk-4.0/gtk.css
ls -la ~/.config/fuzzel/fuzzel_theme.ini
```

### Python dependencies missing
```bash
# Install materialyoucolor
pip install materialyoucolor

# Verify installation
python3 -c "from materialyoucolor import *; print('OK')"
```

### Matugen not found
```bash
# Verify installation
which matugen

# If not found, reinstall:
sudo pacman -S matugen  # Arch
# or build from source
```

## Configuration Files Reference

### shell.json
Main shell configuration file at `~/.config/quickshell/niri-caelestia-shell/shell.json`

Color theming options (add to your config):
```json
{
  "appearance": {
    "wallpaperTheming": {
      "enableTerminal": true,
      "enableAppsAndShell": true,
      "enableQtApps": true,
      "enableVesktop": true
    }
  }
}
```

### Matugen config.toml
Location: `~/.config/matugen/config.toml`

Add custom application theming:
```toml
[templates.custom_app]
input_path = '~/.config/matugen/templates/custom_app.template'
output_path = '~/.config/custom_app/theme.conf'
post_hook = 'systemctl --user reload custom_app'
```

## Integration with Other Applications

### Tmux
1. Create template: `~/.config/matugen/templates/custom/tmux.conf`
2. Add to `config.toml`:
   ```toml
   [templates.tmux]
   input_path = '~/.config/matugen/templates/custom/tmux.conf'
   output_path = '~/.config/tmux/matugen.conf'
   post_hook = 'tmux source-file ~/.config/tmux/matugen.conf'
   ```

### Starship
1. Create template: `~/.config/matugen/templates/custom/starship.toml`
2. Add to `config.toml`:
   ```toml
   [templates.starship]
   input_path = '~/.config/matugen/templates/custom/starship.toml'
   output_path = '~/.config/starship/matugen.toml'
   ```

## Performance

Color generation typically takes 2-3 seconds:
- Matugen runs in background
- Terminal colors apply immediately
- GTK apps reload on next launch
- No performance impact on shell

## Tips

1. **Speed up GTK app updates**: Close and reopen applications after wallpaper change
2. **Terminal transparency**: Edit `applycolor.sh`, change `term_alpha=100` to lower value (0-100)
3. **Custom colors**: Use `--color` flag instead of `--image`:
   ```bash
   matugen color hex "#FF5733"
   ```
4. **Dark/Light mode**: System automatically detects, override with `--mode light/dark`

## Additional Resources

- [Matugen GitHub](https://github.com/InioX/matugen)
- [Material Design 3](https://m3.material.io/)
- [Material You Color Library](https://github.com/material-foundation/material-color-utilities)

## Credits

This color generation system is adapted from:
- **End4** - Original `ii` shell implementation
- **Material You** - Google's design system
- **Matugen** - Automatic Material Design theming

