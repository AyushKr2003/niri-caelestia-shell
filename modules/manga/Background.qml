import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property var wrapper
    readonly property real rounding: Config.border.rounding
    readonly property real realRounding: (wrapper?.width ?? 0) > 0 ? rounding : 0

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // startX and startY are properties of ShapePath, set in Backgrounds.qml (sidebar edge)
    
    // Top-right corner bridge
    PathLine {
        x: root.startX + (root.wrapper?.width ?? 0) + root.realRounding
        y: root.startY
    }
    PathArc {
        x: root.startX + (root.wrapper?.width ?? 0)
        y: root.startY + root.realRounding
        radiusX: root.realRounding; radiusY: root.realRounding
        direction: PathArc.Counterclockwise // Flipped back to Counterclockwise
    }
    
    // Bottom-right corner bridge
    PathLine {
        x: root.startX + (root.wrapper?.width ?? 0)
        y: (root.wrapper?.height ?? 0) - root.realRounding
    }
    PathArc {
        x: root.startX + (root.wrapper?.width ?? 0) + root.realRounding
        y: (root.wrapper?.height ?? 0)
        radiusX: root.realRounding; radiusY: root.realRounding
        direction: PathArc.Counterclockwise // Flipped back to Counterclockwise
    }
    
    PathLine { x: root.startX; y: (root.wrapper?.height ?? 0) }
    PathLine { x: root.startX; y: root.startY }

    Behavior on fillColor {
        CAnim {}
    }
}
