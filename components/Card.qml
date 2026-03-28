import qs.services
import qs.config
import QtQuick

StyledRect {
    id: root

    enum Variant {
        Elevated,
        Filled,
        Outlined
    }

    property int variant: Card.Variant.Filled
    property alias contentItem: contentArea
    property int padding: Appearance.padding.md

    radius: Appearance.rounding.normal

    color: {
        switch (variant) {
        case Card.Variant.Elevated:
            return Colours.tPalette.m3surfaceContainerLow;
        case Card.Variant.Outlined:
            return Colours.tPalette.m3surface;
        case Card.Variant.Filled:
        default:
            return Colours.tPalette.m3surfaceContainerHighest;
        }
    }

    border.width: variant === Card.Variant.Outlined ? 1 : 0
    border.color: variant === Card.Variant.Outlined ? Colours.palette.m3outlineVariant : "transparent"

    Item {
        id: contentArea

        anchors.fill: parent
        anchors.margins: root.padding
    }
}
