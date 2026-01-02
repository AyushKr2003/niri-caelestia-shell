import qs.config
import QtQuick

// Reusable opacity animation behavior
// Usage: Behavior on opacity { OpacityBehavior {} }
// Or directly: OpacityBehavior { target: myItem; property: "opacity" }

NumberAnimation {
    property: "opacity"
    duration: Appearance.anim.durations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.standard
}
