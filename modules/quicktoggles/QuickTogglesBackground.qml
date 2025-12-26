import qs.components
import qs.services
import qs.config
import Quickshell
import QtQuick
import QtQuick.Shapes

ShapePath {
    id: root

    required property Wrapper wrapper
    readonly property real rounding: Config.border.rounding
    readonly property bool flatten: wrapper.height < rounding * 2
    readonly property real roundingY: flatten ? wrapper.height / 2 : rounding

    strokeWidth: -1
    fillColor: Colours.palette.m3surface

    // Draw from bottom-right (startX: root.width, startY: root.height)
    // Going clockwise
    
    // Bottom-right inner arc going up (connects to bottom border)
    PathArc {
        relativeX: root.rounding
        relativeY: -root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
    }
    // Right edge going up
    PathLine {
        relativeX: 0
        relativeY: -(root.wrapper.height - root.rounding * 2)
    }
    // Top-right inner arc going left (connects to right border)
    PathArc {
        relativeX: -root.rounding
        relativeY: -root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
    }
    // Top edge going left
    PathLine {
        relativeX: -(root.wrapper.width - root.rounding * 2)
        relativeY: 0
    }
    // Top-left outer arc going down
    PathArc {
        relativeX: -root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: PathArc.Counterclockwise
    }
    // Left edge going down
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.roundingY * 2
    }
    // Bottom-left outer arc going right
    PathArc {
        relativeX: -root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: PathArc.Clockwise
    }
    // Bottom edge going right back to start, extend past panel for inner corner
    PathLine {
        relativeX: root.wrapper.width - root.rounding
        relativeY: 0
    }

    Behavior on fillColor {
        CAnim {}
    }
}
