import qs.config
import QtQuick

// Reusable position animation behavior for x/y coordinates
// Usage: Behavior on x { PositionBehavior {} }

NumberAnimation {
    duration: Appearance.anim.durations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.emphasized
}
