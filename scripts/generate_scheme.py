#!/usr/bin/env python3
"""
Generate Material You color scheme from an image using materialyoucolor library.
This matches exactly the implementation in caelestia-dots/cli.
"""

import json
import sys
from pathlib import Path

from materialyoucolor.blend.blend import Blend
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct.hct import Hct
from materialyoucolor.quantize.celebi import QuantizeCelebi
from materialyoucolor.score.score import Score
from materialyoucolor.scheme.scheme_content import SchemeContent
from materialyoucolor.scheme.scheme_expressive import SchemeExpressive
from materialyoucolor.scheme.scheme_fidelity import SchemeFidelity
from materialyoucolor.scheme.scheme_fruit_salad import SchemeFruitSalad
from materialyoucolor.scheme.scheme_monochrome import SchemeMonochrome
from materialyoucolor.scheme.scheme_neutral import SchemeNeutral
from materialyoucolor.scheme.scheme_rainbow import SchemeRainbow
from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot
from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant
from materialyoucolor.utils.color_utils import argb_from_rgb
from materialyoucolor.utils.math_utils import difference_degrees, rotation_direction, sanitize_degrees_double
from PIL import Image


def hex_to_hct(hex_color: str) -> Hct:
    """Convert hex color string to HCT."""
    return Hct.from_int(int(f"0xFF{hex_color}", 16))


# Terminal colors - gruvbox palette
light_gruvbox = [
    hex_to_hct("FDF9F3"),
    hex_to_hct("FF6188"),
    hex_to_hct("A9DC76"),
    hex_to_hct("FC9867"),
    hex_to_hct("FFD866"),
    hex_to_hct("F47FD4"),
    hex_to_hct("78DCE8"),
    hex_to_hct("333034"),
    hex_to_hct("121212"),
    hex_to_hct("FF6188"),
    hex_to_hct("A9DC76"),
    hex_to_hct("FC9867"),
    hex_to_hct("FFD866"),
    hex_to_hct("F47FD4"),
    hex_to_hct("78DCE8"),
    hex_to_hct("333034"),
]

dark_gruvbox = [
    hex_to_hct("282828"),
    hex_to_hct("CC241D"),
    hex_to_hct("98971A"),
    hex_to_hct("D79921"),
    hex_to_hct("458588"),
    hex_to_hct("B16286"),
    hex_to_hct("689D6A"),
    hex_to_hct("A89984"),
    hex_to_hct("928374"),
    hex_to_hct("FB4934"),
    hex_to_hct("B8BB26"),
    hex_to_hct("FABD2F"),
    hex_to_hct("83A598"),
    hex_to_hct("D3869B"),
    hex_to_hct("8EC07C"),
    hex_to_hct("EBDBB2"),
]

# Catppuccin accent colors
light_catppuccin = [
    hex_to_hct("dc8a78"),
    hex_to_hct("dd7878"),
    hex_to_hct("ea76cb"),
    hex_to_hct("8839ef"),
    hex_to_hct("d20f39"),
    hex_to_hct("e64553"),
    hex_to_hct("fe640b"),
    hex_to_hct("df8e1d"),
    hex_to_hct("40a02b"),
    hex_to_hct("179299"),
    hex_to_hct("04a5e5"),
    hex_to_hct("209fb5"),
    hex_to_hct("1e66f5"),
    hex_to_hct("7287fd"),
]

dark_catppuccin = [
    hex_to_hct("f5e0dc"),
    hex_to_hct("f2cdcd"),
    hex_to_hct("f5c2e7"),
    hex_to_hct("cba6f7"),
    hex_to_hct("f38ba8"),
    hex_to_hct("eba0ac"),
    hex_to_hct("fab387"),
    hex_to_hct("f9e2af"),
    hex_to_hct("a6e3a1"),
    hex_to_hct("94e2d5"),
    hex_to_hct("89dceb"),
    hex_to_hct("74c7ec"),
    hex_to_hct("89b4fa"),
    hex_to_hct("b4befe"),
]

# KDE colors
kcolours = [
    {"name": "klink", "hct": hex_to_hct("2980b9")},
    {"name": "kvisited", "hct": hex_to_hct("9b59b6")},
    {"name": "knegative", "hct": hex_to_hct("da4453")},
    {"name": "kneutral", "hct": hex_to_hct("f67400")},
    {"name": "kpositive", "hct": hex_to_hct("27ae60")},
]

colour_names = [
    "rosewater",
    "flamingo",
    "pink",
    "mauve",
    "red",
    "maroon",
    "peach",
    "yellow",
    "green",
    "teal",
    "sky",
    "sapphire",
    "blue",
    "lavender",
]


def grayscale(colour: Hct, light: bool) -> Hct:
    """Convert color to grayscale."""
    colour = darken(colour, 0.35) if light else lighten(colour, 0.65)
    colour.chroma = 0
    return colour


def mix(a: Hct, b: Hct, w: float) -> Hct:
    """Mix two colors using CAM16 UCS."""
    return Hct.from_int(Blend.cam16_ucs(a.to_int(), b.to_int(), w))


def harmonize(from_hct: Hct, to_hct: Hct, tone_boost: float) -> Hct:
    """Harmonize a color towards another color."""
    difference_degrees_ = difference_degrees(from_hct.hue, to_hct.hue)
    rotation_degrees = min(difference_degrees_ * 0.8, 100)
    output_hue = sanitize_degrees_double(from_hct.hue + rotation_degrees * rotation_direction(from_hct.hue, to_hct.hue))
    return Hct.from_hct(output_hue, from_hct.chroma, from_hct.tone * (1 + tone_boost))


def lighten(colour: Hct, amount: float) -> Hct:
    """Lighten a color."""
    diff = (100 - colour.tone) * amount
    return Hct.from_hct(colour.hue, colour.chroma + diff / 5, colour.tone + diff)


def darken(colour: Hct, amount: float) -> Hct:
    """Darken a color."""
    diff = colour.tone * amount
    return Hct.from_hct(colour.hue, colour.chroma + diff / 5, colour.tone - diff)


def get_scheme_class(variant: str):
    """Get the scheme class for a variant."""
    schemes = {
        "content": SchemeContent,
        "expressive": SchemeExpressive,
        "fidelity": SchemeFidelity,
        "fruitsalad": SchemeFruitSalad,
        "monochrome": SchemeMonochrome,
        "neutral": SchemeNeutral,
        "rainbow": SchemeRainbow,
        "tonalspot": SchemeTonalSpot,
        "vibrant": SchemeVibrant,
    }
    return schemes.get(variant, SchemeVibrant)


def get_primary_from_image(image_path: str) -> Hct:
    """Extract the primary color from an image using quantization and scoring."""
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        img.thumbnail((128, 128))
        pixels = list(img.getdata())

    # Convert to list of [r, g, b] lists for QuantizeCelebi
    pixel_rgb = [[r, g, b] for r, g, b in pixels]

    # Quantize colors
    result = QuantizeCelebi(pixel_rgb, 128)

    # Score and get the best color (result is dict[int, int] where keys are ARGB)
    scored = Score.score(result)
    primary_argb = scored[0] if scored else 0xFF4285F4  # Default to Google Blue

    return Hct.from_int(primary_argb)


def gen_scheme(variant: str, mode: str, primary: Hct) -> dict[str, str]:
    """Generate a complete Material You color scheme."""
    light = mode == "light"
    colours = {}

    # Get Material colors from DynamicScheme
    scheme_class = get_scheme_class(variant)
    primary_scheme = scheme_class(primary, not light, 0)

    for colour in vars(MaterialDynamicColors).keys():
        colour_obj = getattr(MaterialDynamicColors, colour)
        if hasattr(colour_obj, "get_hct"):
            colours[colour] = colour_obj.get_hct(primary_scheme)

    # Harmonize terminal colours
    for i, hct in enumerate(light_gruvbox if light else dark_gruvbox):
        if variant == "monochrome":
            colours[f"term{i}"] = grayscale(hct, light)
        else:
            colours[f"term{i}"] = harmonize(
                hct, colours["primary_paletteKeyColor"], (0.35 if i < 8 else 0.2) * (-1 if light else 1)
            )

    # Harmonize named colours (catppuccin-style)
    for i, hct in enumerate(light_catppuccin if light else dark_catppuccin):
        if variant == "monochrome":
            colours[colour_names[i]] = grayscale(hct, light)
        else:
            colours[colour_names[i]] = harmonize(hct, colours["primary_paletteKeyColor"], (-0.2 if light else 0.05))

    # KDE Colors
    for colour in kcolours:
        colours[colour["name"]] = harmonize(colour["hct"], colours["primary"], 0.1)
        colours[f"{colour['name']}Selection"] = harmonize(colour["hct"], colours["onPrimaryFixedVariant"], 0.1)
        if variant == "monochrome":
            colours[colour["name"]] = grayscale(colours[colour["name"]], light)
            colours[f"{colour['name']}Selection"] = grayscale(colours[f"{colour['name']}Selection"], light)

    # Reduce chroma for neutral variant
    if variant == "neutral":
        for name, hct in colours.items():
            colours[name].chroma -= 15

    # Legacy/deprecated colors for compatibility
    colours["text"] = colours["onBackground"]
    colours["subtext1"] = colours["onSurfaceVariant"]
    colours["subtext0"] = colours["outline"]
    colours["overlay2"] = mix(colours["surface"], colours["outline"], 0.86)
    colours["overlay1"] = mix(colours["surface"], colours["outline"], 0.71)
    colours["overlay0"] = mix(colours["surface"], colours["outline"], 0.57)
    colours["surface2"] = mix(colours["surface"], colours["outline"], 0.43)
    colours["surface1"] = mix(colours["surface"], colours["outline"], 0.29)
    colours["surface0"] = mix(colours["surface"], colours["outline"], 0.14)
    colours["base"] = colours["surface"]
    colours["mantle"] = darken(colours["surface"], 0.03)
    colours["crust"] = darken(colours["surface"], 0.05)

    # Convert HCT to hex strings
    colours = {k: hex(v.to_int())[4:] for k, v in colours.items()}

    # Extended material - success colors
    if light:
        colours["success"] = "4F6354"
        colours["onSuccess"] = "FFFFFF"
        colours["successContainer"] = "D1E8D5"
        colours["onSuccessContainer"] = "0C1F13"
    else:
        colours["success"] = "B5CCBA"
        colours["onSuccess"] = "213528"
        colours["successContainer"] = "374B3E"
        colours["onSuccessContainer"] = "D1E9D6"

    return colours


def main():
    if len(sys.argv) < 4:
        print(json.dumps({"error": "Usage: generate_scheme.py <image_path> <variant> <mode>"}))
        sys.exit(1)

    image_path = sys.argv[1]
    variant = sys.argv[2].lower()
    mode = sys.argv[3].lower()

    if not Path(image_path).exists():
        print(json.dumps({"error": f"Image not found: {image_path}"}))
        sys.exit(1)

    if mode not in ("light", "dark"):
        print(json.dumps({"error": f"Invalid mode: {mode}. Use 'light' or 'dark'"}))
        sys.exit(1)

    try:
        primary = get_primary_from_image(image_path)
        colours = gen_scheme(variant, mode, primary)
        print(json.dumps(colours))
    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)


if __name__ == "__main__":
    main()
