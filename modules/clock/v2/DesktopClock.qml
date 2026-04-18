pragma ComponentBehavior: Bound

import qs.components
import qs.services
import qs.config
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property Item wallpaper
    property real absX
    property real absY

    property real mScale: Config.background.desktopClock.scale
    readonly property bool invertColors: Config.background.desktopClock.invertColors
    readonly property bool useLightSet: Colours.light ? !invertColors : invertColors

    // ── Dynamic colors from your M3 scheme ──
    readonly property color colorDate:    useLightSet ? Colours.palette.m3primaryContainer    : Colours.palette.m3primary
    readonly property color colorMonth:   useLightSet ? Colours.palette.m3tertiaryContainer   : Colours.palette.m3tertiary
    readonly property color colorTime:    useLightSet ? Colours.palette.m3primaryContainer    : Colours.palette.m3primary
    readonly property color colorWeekday: useLightSet ? Colours.palette.m3onSurface           : Colours.palette.m3onSurfaceVariant
    readonly property color colorDivider: useLightSet ? Colours.palette.m3outlineVariant      : Colours.palette.m3outline

    implicitWidth: 420 * root.mScale
    implicitHeight: 420 * root.mScale

    // ── Big background date ──
    Text {
        id: backgroundDay
        anchors.centerIn: parent
        text: Time.format("dd")
        font.pixelSize: 700 * root.mScale
        font.weight: Font.Black
        font.family: Appearance.font.family.sans
        font.letterSpacing: -20 * root.mScale
        color: root.colorDate
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.NativeRendering
        visible: false
        layer.enabled: true
        layer.smooth: true
        layer.samples: 8
        layer.textureSize: Qt.size(backgroundDay.width * 2, backgroundDay.height * 2)
    }

    // ── Gradient mask: solid top → transparent bottom ──
    Item {
        id: gradientMask
        width: backgroundDay.width
        height: backgroundDay.height
        anchors.centerIn: parent
        visible: false
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0;  color: "#ff000000" }
                GradientStop { position: 0.50; color: "#dc000000" }
                GradientStop { position: 0.85; color: "#01000000" }
                GradientStop { position: 1.0;  color: "#00000000" }
            }
        }
    }

    MultiEffect {
        source: backgroundDay
        anchors.fill: backgroundDay
        maskEnabled: true
        maskSource: gradientMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        z: 0
    }

    // ── Foreground ──
    ColumnLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 0
        z: 1

        // Month — tertiary color
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("MMMM").toUpperCase()
            font.pixelSize: 56 * root.mScale
            font.weight: Font.Black
            font.family: Appearance.font.family.sans
            font.letterSpacing: 4 * root.mScale
            renderType: Text.NativeRendering
            color: root.colorMonth
        }

        // Time — primary color
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * root.mScale
            text: Time.format(Config.services.useTwelveHourClock ? "h:mm A" : "HH:mm")
            font.pixelSize: 38 * root.mScale
            font.weight: Font.Bold
            font.family: Appearance.font.family.sans
            renderType: Text.NativeRendering
            color: root.colorTime
        }

        // Divider
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * root.mScale
            Layout.preferredWidth: 180 * root.mScale
            Layout.preferredHeight: 2 * root.mScale
            color: root.colorDivider
            radius: 1
        }

        // Weekday — onSurfaceVariant
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10 * root.mScale
            text: Time.format("dddd").toUpperCase()
            font.pixelSize: 18 * root.mScale
            font.weight: Font.Medium
            font.family: Appearance.font.family.sans
            font.letterSpacing: 10 * root.mScale
            renderType: Text.NativeRendering
            color: root.colorWeekday
        }
    }

    // ── Drag ──
    MouseArea {
        anchors.fill: parent
        cursorShape: containsMouse ? (pressed ? Qt.SizeAllCursor : Qt.OpenHandCursor) : Qt.ArrowCursor
        hoverEnabled: true
        property real lastX: 0
        property real lastY: 0
        onPressed: mouse => { lastX = mouse.x; lastY = mouse.y }
        onPositionChanged: mouse => {
            if (pressed) {
                Config.background.desktopClock.xOffset += mouse.x - lastX
                Config.background.desktopClock.yOffset += mouse.y - lastY
            }
        }
        onWheel: wheel => { wheel.accepted = false }
    }

    // ── Scroll to resize ──
    WheelHandler {
        acceptedModifiers: Qt.NoModifier
        property real sensitivity: 0.05
        onWheel: event => {
            let delta = event.angleDelta.y > 0 ? sensitivity : -sensitivity
            Config.background.desktopClock.scale = Math.max(0.4, Math.min(5.0, Config.background.desktopClock.scale + delta))
        }
    }

    Behavior on mScale {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    Behavior on implicitWidth {
        Anim { duration: Appearance.anim.durations.small }
    }

    Behavior on implicitHeight {
        Anim { duration: Appearance.anim.durations.small }
    }
}