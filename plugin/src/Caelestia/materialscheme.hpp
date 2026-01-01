#pragma once

#include <qcolor.h>
#include <qjsvalue.h>
#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariant.h>

namespace caelestia {

// HCT (Hue, Chroma, Tone) color space for Material You
struct HctColor {
    double hue;    // 0-360
    double chroma; // 0-150+
    double tone;   // 0-100 (lightness)

    HctColor(double h = 0, double c = 0, double t = 0)
        : hue(h)
        , chroma(c)
        , tone(t) { }

    static HctColor fromColor(const QColor& color);
    QColor toColor() const;

    // Adjust tone while maintaining hue and chroma
    HctColor withTone(double newTone) const;
    HctColor withChroma(double newChroma) const;
};

class MaterialScheme : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    // Generate a complete Material You color scheme from a seed color
    Q_INVOKABLE QVariantMap generateScheme(const QColor& seedColor, const QString& variant, bool isDark) const;

    // Generate scheme from dominant color of an image path
    Q_INVOKABLE void generateSchemeFromImage(const QString& imagePath, const QString& variant, bool isDark,
        QJSValue callback);

private:
    // Scheme generators for different variants
    QVariantMap generateTonalSpot(const HctColor& seed, bool isDark) const;
    QVariantMap generateVibrant(const HctColor& seed, bool isDark) const;
    QVariantMap generateExpressive(const HctColor& seed, bool isDark) const;
    QVariantMap generateFidelity(const HctColor& seed, bool isDark) const;
    QVariantMap generateContent(const HctColor& seed, bool isDark) const;
    QVariantMap generateFruitSalad(const HctColor& seed, bool isDark) const;
    QVariantMap generateRainbow(const HctColor& seed, bool isDark) const;
    QVariantMap generateNeutral(const HctColor& seed, bool isDark) const;
    QVariantMap generateMonochrome(const HctColor& seed, bool isDark) const;

    // Helper: create full color scheme with surface, primary, secondary, tertiary palettes
    QVariantMap buildFullScheme(const HctColor& primary, const HctColor& secondary, const HctColor& tertiary,
        const HctColor& neutral, const HctColor& neutralVariant, bool isDark) const;

    // Helper: harmonize color towards target
    HctColor harmonize(const HctColor& from, const HctColor& to, double amount) const;

    // Catppuccin-inspired accent colors harmonized to scheme
    void addAccentColors(QVariantMap& scheme, const HctColor& primary, bool isDark) const;

    // Terminal colors
    void addTerminalColors(QVariantMap& scheme, const HctColor& primary, bool isDark) const;

    // Helper: convert color to hex string without #
    QString toHex(const QColor& color) const;
};

} // namespace caelestia
