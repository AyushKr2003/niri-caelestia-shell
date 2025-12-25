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

    // Draw from top-right (startX: root.width, startY: 0)
    // Going counter-clockwise
    
    // Top edge going left, past the panel to leave room for inner corner
    PathLine {
        relativeX: -(root.wrapper.width + root.rounding)
        relativeY: 0
    }
    // Top-left inner arc going down (connects to bar)
    PathArc {
        relativeX: root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
    }
    // Left edge going down
    PathLine {
        relativeX: 0
        relativeY: root.wrapper.height - root.roundingY * 2
    }
    // Bottom-left outer arc going right
    PathArc {
        relativeX: root.rounding
        relativeY: root.roundingY
        radiusX: root.rounding
        radiusY: Math.min(root.rounding, root.wrapper.height)
        direction: PathArc.Counterclockwise
    }
    // Bottom edge going right, past the panel to leave room for inner corner
    PathLine {
        relativeX: root.wrapper.width - root.rounding * 2
        relativeY: 0
    }
    // Bottom-right inner arc going up (connects to right border)
    PathArc {
        relativeX: root.rounding
        relativeY: root.rounding
        radiusX: root.rounding
        radiusY: root.rounding
    }

    Behavior on fillColor {
        CAnim {}
    }
}
