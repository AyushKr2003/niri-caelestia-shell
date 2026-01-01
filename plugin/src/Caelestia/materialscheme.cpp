#include "materialscheme.hpp"

#include "cutils.hpp"
#include <qimage.h>
#include <qqmlengine.h>
#include <qthreadpool.h>
#include <cmath>

namespace caelestia {

// ===== HCT Color Space Conversion =====

// CAM16 viewing conditions (simplified for Material You)
struct Cam16 {
    double j; // lightness
    double c; // chroma
    double h; // hue

    static Cam16 fromColor(const QColor& color) {
        double r = color.redF();
        double g = color.greenF();
        double b = color.blueF();

        // Convert to XYZ
        double x = 0.41233895 * r + 0.35762064 * g + 0.18051042 * b;
        double y = 0.21263901 * r + 0.71516868 * g + 0.07219232 * b;
        double z = 0.01933082 * r + 0.11919478 * g + 0.95053215 * b;

        // Simplified CAM16 (skipping adaptation, using direct conversion)
        double fy = (y > 0.008856) ? std::cbrt(y) : (7.787 * y + 16.0 / 116.0);
        double fx = (x > 0.008856) ? std::cbrt(x) : (7.787 * x + 16.0 / 116.0);
        double fz = (z > 0.008856) ? std::cbrt(z) : (7.787 * z + 16.0 / 116.0);

        double l = 116.0 * fy - 16.0;
        double a = 500.0 * (fx - fy);
        double b_val = 200.0 * (fy - fz);

        Cam16 cam;
        cam.j = l; // lightness approximation
        cam.c = std::sqrt(a * a + b_val * b_val); // chroma approximation
        cam.h = std::atan2(b_val, a) * 180.0 / M_PI; // hue
        if (cam.h < 0) cam.h += 360.0;

        return cam;
    }

    QColor toColor() const {
        // Simplified inverse (direct Lab-like conversion)
        double fy = (j + 16.0) / 116.0;
        double fx = fy + (c * std::cos(h * M_PI / 180.0)) / 500.0;
        double fz = fy - (c * std::sin(h * M_PI / 180.0)) / 200.0;

        auto finv = [](double t) {
            if (t > 0.206893) return t * t * t;
            return (t - 16.0 / 116.0) / 7.787;
        };

        double x = finv(fx);
        double y = finv(fy);
        double z = finv(fz);

        // XYZ to RGB
        double r = 3.24096994 * x - 1.53738318 * y - 0.49861076 * z;
        double g = -0.96924364 * x + 1.8759675 * y + 0.04155506 * z;
        double b = 0.05563008 * x - 0.20397696 * y + 1.05697151 * z;

        auto clamp = [](double v) {
            return std::max(0.0, std::min(1.0, v));
        };

        return QColor::fromRgbF(clamp(r), clamp(g), clamp(b));
    }
};

HctColor HctColor::fromColor(const QColor& color) {
    Cam16 cam = Cam16::fromColor(color);
    return HctColor(cam.h, cam.c, cam.j);
}

QColor HctColor::toColor() const {
    Cam16 cam;
    cam.h = hue;
    cam.c = chroma;
    cam.j = tone;
    return cam.toColor();
}

HctColor HctColor::withTone(double newTone) const {
    return HctColor(hue, chroma, newTone);
}

HctColor HctColor::withChroma(double newChroma) const {
    return HctColor(hue, newChroma, tone);
}

// ===== MaterialScheme Implementation =====

QString MaterialScheme::toHex(const QColor& color) const {
    return QString("%1%2%3")
        .arg(color.red(), 2, 16, QChar('0'))
        .arg(color.green(), 2, 16, QChar('0'))
        .arg(color.blue(), 2, 16, QChar('0'));
}

HctColor MaterialScheme::harmonize(const HctColor& from, const HctColor& to, double amount) const {
    // Rotate hue towards target
    double fromHue = from.hue;
    double toHue = to.hue;

    double diff = toHue - fromHue;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;

    double newHue = fromHue + diff * amount;
    if (newHue < 0) newHue += 360.0;
    if (newHue >= 360.0) newHue -= 360.0;

    return HctColor(newHue, from.chroma, from.tone);
}

QVariantMap MaterialScheme::buildFullScheme(const HctColor& primary, const HctColor& secondary,
    const HctColor& tertiary, const HctColor& neutral, const HctColor& neutralVariant, bool isDark) const {
    QVariantMap scheme;

    // Tones for Material 3 roles
    const double bg = isDark ? 6 : 98;
    const double onBg = isDark ? 90 : 10;
    const double surf = isDark ? 6 : 98;
    const double surfDim = isDark ? 6 : 87;
    const double surfBright = isDark ? 24 : 98;
    const double surfContainerLowest = isDark ? 4 : 100;
    const double surfContainerLow = isDark ? 10 : 96;
    const double surfContainer = isDark ? 12 : 94;
    const double surfContainerHigh = isDark ? 17 : 92;
    const double surfContainerHighest = isDark ? 22 : 90;

    // Key colors
    scheme["primary_paletteKeyColor"] = toHex(primary.toColor());
    scheme["secondary_paletteKeyColor"] = toHex(secondary.toColor());
    scheme["tertiary_paletteKeyColor"] = toHex(tertiary.toColor());
    scheme["neutral_paletteKeyColor"] = toHex(neutral.toColor());
    scheme["neutral_variant_paletteKeyColor"] = toHex(neutralVariant.toColor());

    // Background/Surface
    scheme["background"] = toHex(neutral.withTone(bg).toColor());
    scheme["onBackground"] = toHex(neutral.withTone(onBg).toColor());
    scheme["surface"] = toHex(neutral.withTone(surf).toColor());
    scheme["surfaceDim"] = toHex(neutral.withTone(surfDim).toColor());
    scheme["surfaceBright"] = toHex(neutral.withTone(surfBright).toColor());
    scheme["surfaceContainerLowest"] = toHex(neutral.withTone(surfContainerLowest).toColor());
    scheme["surfaceContainerLow"] = toHex(neutral.withTone(surfContainerLow).toColor());
    scheme["surfaceContainer"] = toHex(neutral.withTone(surfContainer).toColor());
    scheme["surfaceContainerHigh"] = toHex(neutral.withTone(surfContainerHigh).toColor());
    scheme["surfaceContainerHighest"] = toHex(neutral.withTone(surfContainerHighest).toColor());
    scheme["onSurface"] = toHex(neutral.withTone(onBg).toColor());
    scheme["surfaceVariant"] = toHex(neutralVariant.withTone(isDark ? 30 : 90).toColor());
    scheme["onSurfaceVariant"] = toHex(neutralVariant.withTone(isDark ? 80 : 30).toColor());
    scheme["inverseSurface"] = toHex(neutral.withTone(isDark ? 90 : 20).toColor());
    scheme["inverseOnSurface"] = toHex(neutral.withTone(isDark ? 20 : 95).toColor());
    scheme["outline"] = toHex(neutralVariant.withTone(isDark ? 60 : 50).toColor());
    scheme["outlineVariant"] = toHex(neutralVariant.withTone(isDark ? 30 : 80).toColor());
    scheme["shadow"] = toHex(QColor(0, 0, 0));
    scheme["scrim"] = toHex(QColor(0, 0, 0));
    scheme["surfaceTint"] = toHex(primary.withTone(isDark ? 80 : 40).toColor());

    // Primary
    scheme["primary"] = toHex(primary.withTone(isDark ? 80 : 40).toColor());
    scheme["onPrimary"] = toHex(primary.withTone(isDark ? 20 : 100).toColor());
    scheme["primaryContainer"] = toHex(primary.withTone(isDark ? 30 : 90).toColor());
    scheme["onPrimaryContainer"] = toHex(primary.withTone(isDark ? 90 : 10).toColor());
    scheme["inversePrimary"] = toHex(primary.withTone(isDark ? 40 : 80).toColor());

    // Secondary
    scheme["secondary"] = toHex(secondary.withTone(isDark ? 80 : 40).toColor());
    scheme["onSecondary"] = toHex(secondary.withTone(isDark ? 20 : 100).toColor());
    scheme["secondaryContainer"] = toHex(secondary.withTone(isDark ? 30 : 90).toColor());
    scheme["onSecondaryContainer"] = toHex(secondary.withTone(isDark ? 90 : 10).toColor());

    // Tertiary
    scheme["tertiary"] = toHex(tertiary.withTone(isDark ? 80 : 40).toColor());
    scheme["onTertiary"] = toHex(tertiary.withTone(isDark ? 20 : 100).toColor());
    scheme["tertiaryContainer"] = toHex(tertiary.withTone(isDark ? 30 : 90).toColor());
    scheme["onTertiaryContainer"] = toHex(tertiary.withTone(isDark ? 90 : 10).toColor());

    // Error
    HctColor error(25, 84, isDark ? 80 : 40);
    scheme["error"] = toHex(error.toColor());
    scheme["onError"] = toHex(error.withTone(isDark ? 20 : 100).toColor());
    scheme["errorContainer"] = toHex(error.withTone(isDark ? 30 : 90).toColor());
    scheme["onErrorContainer"] = toHex(error.withTone(isDark ? 90 : 10).toColor());

    // Success (custom, not in M3 spec)
    HctColor success(140, 40, isDark ? 70 : 50);
    scheme["success"] = toHex(success.toColor());
    scheme["onSuccess"] = toHex(success.withTone(isDark ? 20 : 100).toColor());
    scheme["successContainer"] = toHex(success.withTone(isDark ? 30 : 90).toColor());
    scheme["onSuccessContainer"] = toHex(success.withTone(isDark ? 90 : 10).toColor());

    // Fixed colors (for always-light or always-dark surfaces)
    scheme["primaryFixed"] = toHex(primary.withTone(90).toColor());
    scheme["primaryFixedDim"] = toHex(primary.withTone(80).toColor());
    scheme["onPrimaryFixed"] = toHex(primary.withTone(10).toColor());
    scheme["onPrimaryFixedVariant"] = toHex(primary.withTone(30).toColor());

    scheme["secondaryFixed"] = toHex(secondary.withTone(90).toColor());
    scheme["secondaryFixedDim"] = toHex(secondary.withTone(80).toColor());
    scheme["onSecondaryFixed"] = toHex(secondary.withTone(10).toColor());
    scheme["onSecondaryFixedVariant"] = toHex(secondary.withTone(30).toColor());

    scheme["tertiaryFixed"] = toHex(tertiary.withTone(90).toColor());
    scheme["tertiaryFixedDim"] = toHex(tertiary.withTone(80).toColor());
    scheme["onTertiaryFixed"] = toHex(tertiary.withTone(10).toColor());
    scheme["onTertiaryFixedVariant"] = toHex(tertiary.withTone(30).toColor());

    // Add terminal and accent colors
    addTerminalColors(scheme, primary, isDark);
    addAccentColors(scheme, primary, isDark);

    // Legacy compatibility colors
    scheme["text"] = scheme["onBackground"];
    scheme["subtext1"] = scheme["onSurfaceVariant"];
    scheme["subtext0"] = scheme["outline"];
    scheme["overlay2"] = toHex(neutral.withTone(isDark ? 40 : 60).toColor());
    scheme["overlay1"] = toHex(neutral.withTone(isDark ? 35 : 65).toColor());
    scheme["overlay0"] = toHex(neutral.withTone(isDark ? 30 : 70).toColor());
    scheme["surface2"] = toHex(neutral.withTone(isDark ? 22 : 88).toColor());
    scheme["surface1"] = toHex(neutral.withTone(isDark ? 18 : 92).toColor());
    scheme["surface0"] = toHex(neutral.withTone(isDark ? 14 : 96).toColor());
    scheme["base"] = scheme["surface"];
    scheme["mantle"] = toHex(neutral.withTone(isDark ? 5 : 99).toColor());
    scheme["crust"] = toHex(neutral.withTone(isDark ? 4 : 100).toColor());

    return scheme;
}

void MaterialScheme::addTerminalColors(QVariantMap& scheme, const HctColor& primary, bool isDark) const {
    // Terminal color palette harmonized to the primary color
    struct TermColor {
        const char* name;
        double baseHue;
        double chroma;
    };

    const TermColor termColors[] = {
        { "term0", 0, 5 }, // black/gray
        { "term1", 15, 80 }, // red
        { "term2", 160, 70 }, // green
        { "term3", 45, 80 }, // yellow
        { "term4", 240, 60 }, // blue
        { "term5", 300, 70 }, // magenta
        { "term6", 190, 60 }, // cyan
        { "term7", 0, 15 }, // white/gray
        { "term8", 0, 10 }, // bright black
        { "term9", 15, 90 }, // bright red
        { "term10", 160, 80 }, // bright green
        { "term11", 45, 90 }, // bright yellow
        { "term12", 240, 70 }, // bright blue
        { "term13", 300, 80 }, // bright magenta
        { "term14", 190, 70 }, // bright cyan
        { "term15", 0, 20 }, // bright white
    };

    for (const auto& tc : termColors) {
        HctColor termColor(tc.baseHue, tc.chroma, isDark ? 70 : 50);
        if (tc.chroma > 15) { // Only harmonize colorful colors
            termColor = harmonize(termColor, primary, 0.15);
        }

        // Adjust tone for light/dark
        if (tc.name[4] >= '8') { // bright colors (8-15)
            termColor.tone = isDark ? 80 : 40;
        } else {
            termColor.tone = isDark ? 60 : 60;
        }

        scheme[tc.name] = toHex(termColor.toColor());
    }
}

void MaterialScheme::addAccentColors(QVariantMap& scheme, const HctColor& primary, bool isDark) const {
    // Catppuccin-inspired accent colors
    struct AccentColor {
        const char* name;
        double baseHue;
        double chroma;
    };

    const AccentColor accents[] = {
        { "rosewater", 10, 30 },
        { "flamingo", 5, 40 },
        { "pink", 340, 60 },
        { "mauve", 280, 70 },
        { "red", 0, 80 },
        { "maroon", 10, 70 },
        { "peach", 30, 70 },
        { "yellow", 60, 80 },
        { "green", 140, 60 },
        { "teal", 180, 50 },
        { "sky", 200, 50 },
        { "sapphire", 210, 60 },
        { "blue", 230, 70 },
        { "lavender", 260, 60 },
    };

    for (const auto& ac : accents) {
        HctColor accentColor(ac.baseHue, ac.chroma, isDark ? 75 : 55);
        accentColor = harmonize(accentColor, primary, 0.2);
        scheme[ac.name] = toHex(accentColor.toColor());
    }

    // KDE colors
    const AccentColor kcolors[] = {
        { "klink", 210, 60 },
        { "klinkSelection", 210, 60 },
        { "kvisited", 270, 60 },
        { "kvisitedSelection", 270, 60 },
        { "knegative", 0, 80 },
        { "knegativeSelection", 0, 80 },
        { "kneutral", 30, 70 },
        { "kneutralSelection", 30, 70 },
        { "kpositive", 140, 60 },
        { "kpositiveSelection", 140, 60 },
    };

    for (const auto& kc : kcolors) {
        HctColor kcolor(kc.baseHue, kc.chroma, isDark ? 70 : 50);
        kcolor = harmonize(kcolor, primary, 0.15);
        scheme[kc.name] = toHex(kcolor.toColor());
    }
}

// ===== Variant Generators =====

QVariantMap MaterialScheme::generateTonalSpot(const HctColor& seed, bool isDark) const {
    // Tonal Spot: low chroma, harmonious palette
    HctColor primary = seed.withChroma(36);
    HctColor secondary = HctColor(seed.hue, 16, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 60, 24, seed.tone);
    HctColor neutral = HctColor(seed.hue, 4, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 8, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateVibrant(const HctColor& seed, bool isDark) const {
    // Vibrant: maximum chroma
    HctColor primary = seed.withChroma(std::min(seed.chroma * 1.5, 120.0));
    HctColor secondary = HctColor(seed.hue + 30, primary.chroma * 0.6, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 120, primary.chroma * 0.8, seed.tone);
    HctColor neutral = HctColor(seed.hue, 6, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 12, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateExpressive(const HctColor& seed, bool isDark) const {
    // Expressive: shifted hues, medium chroma
    HctColor primary = HctColor(seed.hue + 240, 40, seed.tone);
    HctColor secondary = HctColor(seed.hue, 24, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 120, 32, seed.tone);
    HctColor neutral = HctColor(seed.hue + 15, 8, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue + 15, 12, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateFidelity(const HctColor& seed, bool isDark) const {
    // Fidelity: keeps seed color exactly
    HctColor primary = seed;
    HctColor secondary = HctColor(seed.hue + 30, seed.chroma * 0.5, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 60, seed.chroma * 0.7, seed.tone);
    HctColor neutral = HctColor(seed.hue, 6, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 10, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateContent(const HctColor& seed, bool isDark) const {
    // Content: almost identical to fidelity
    return generateFidelity(seed, isDark);
}

QVariantMap MaterialScheme::generateFruitSalad(const HctColor& seed, bool isDark) const {
    // Fruit Salad: shifted hues, playful
    HctColor primary = HctColor(seed.hue + 90, 40, seed.tone);
    HctColor secondary = HctColor(seed.hue + 180, 36, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 270, 32, seed.tone);
    HctColor neutral = HctColor(seed.hue, 6, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 10, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateRainbow(const HctColor& seed, bool isDark) const {
    // Rainbow: evenly distributed hues
    HctColor primary = HctColor(seed.hue, 48, seed.tone);
    HctColor secondary = HctColor(seed.hue + 120, 40, seed.tone);
    HctColor tertiary = HctColor(seed.hue + 240, 44, seed.tone);
    HctColor neutral = HctColor(seed.hue, 6, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 10, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateNeutral(const HctColor& seed, bool isDark) const {
    // Neutral: very low chroma, almost grayscale
    HctColor primary = seed.withChroma(12);
    HctColor secondary = HctColor(seed.hue, 8, seed.tone);
    HctColor tertiary = HctColor(seed.hue, 10, seed.tone);
    HctColor neutral = HctColor(seed.hue, 2, seed.tone);
    HctColor neutralVariant = HctColor(seed.hue, 4, seed.tone);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateMonochrome(const HctColor& seed, bool isDark) const {
    // Monochrome: zero chroma, pure grayscale
    HctColor primary = seed.withChroma(0);
    HctColor secondary = seed.withChroma(0);
    HctColor tertiary = seed.withChroma(0);
    HctColor neutral = seed.withChroma(0);
    HctColor neutralVariant = seed.withChroma(0);

    return buildFullScheme(primary, secondary, tertiary, neutral, neutralVariant, isDark);
}

QVariantMap MaterialScheme::generateScheme(const QColor& seedColor, const QString& variant, bool isDark) const {
    HctColor seed = HctColor::fromColor(seedColor);

    if (variant == "vibrant")
        return generateVibrant(seed, isDark);
    if (variant == "expressive")
        return generateExpressive(seed, isDark);
    if (variant == "fidelity")
        return generateFidelity(seed, isDark);
    if (variant == "content")
        return generateContent(seed, isDark);
    if (variant == "fruitsalad")
        return generateFruitSalad(seed, isDark);
    if (variant == "rainbow")
        return generateRainbow(seed, isDark);
    if (variant == "neutral")
        return generateNeutral(seed, isDark);
    if (variant == "monochrome")
        return generateMonochrome(seed, isDark);

    // Default: tonalspot
    return generateTonalSpot(seed, isDark);
}

void MaterialScheme::generateSchemeFromImage(
    const QString& imagePath, const QString& variant, bool isDark, QJSValue callback) {
    if (imagePath.isEmpty()) {
        qWarning() << "MaterialScheme::generateSchemeFromImage: given path is empty";
        return;
    }

    QThreadPool::globalInstance()->start([imagePath, variant, isDark, callback, this]() {
        QImage image(imagePath);

        if (image.isNull()) {
            qWarning() << "MaterialScheme::generateSchemeFromImage: failed to load image" << imagePath;
            return;
        }

        // Find dominant color (simple implementation)
        QImage img = image.scaled(128, 128, Qt::KeepAspectRatio, Qt::FastTransformation);
        if (img.format() != QImage::Format_ARGB32) {
            img = img.convertToFormat(QImage::Format_ARGB32);
        }

        std::unordered_map<uint32_t, int> colours;
        const uchar* data = img.bits();
        const int width = img.width();
        const int height = img.height();
        const qsizetype bytesPerLine = img.bytesPerLine();

        for (int y = 0; y < height; ++y) {
            const uchar* line = data + y * bytesPerLine;
            for (int x = 0; x < width; ++x) {
                const uchar* pixel = line + x * 4;
                if (pixel[3] == 0) continue;

                uint32_t r = static_cast<uint32_t>(pixel[0] & 0xF8);
                uint32_t g = static_cast<uint32_t>(pixel[1] & 0xF8);
                uint32_t b = static_cast<uint32_t>(pixel[2] & 0xF8);

                uint32_t colour = (r << 16) | (g << 8) | b;
                ++colours[colour];
            }
        }

        uint32_t dominantColour = 0;
        int maxCount = 0;
        for (const auto& [colour, count] : colours) {
            if (count > maxCount) {
                dominantColour = colour;
                maxCount = count;
            }
        }

        QColor seedColor((0xFFu << 24) | dominantColour);
        QVariantMap scheme = generateScheme(seedColor, variant, isDark);

        if (callback.isCallable()) {
            QMetaObject::invokeMethod(
                this,
                [scheme, callback, this]() {
                    callback.call({ qmlEngine(this)->toScriptValue(scheme) });
                },
                Qt::QueuedConnection);
        }
    });
}

} // namespace caelestia
