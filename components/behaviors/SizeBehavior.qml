import qs.config
import QtQuick

// Reusable size animation behavior for width/height/implicitWidth/implicitHeight
// Usage: Behavior on implicitHeight { SizeBehavior {} }

NumberAnimation {
    duration: Appearance.anim.durations.normal
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Appearance.anim.curves.standard
}
