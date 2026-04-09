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

    readonly property color accentColor: "#F5C518"
    readonly property color bgDateColor: "#AA1800"

    implicitWidth: 420 * root.mScale
    implicitHeight: 420 * root.mScale

    // ── Step 1: The big date text — hidden, MultiEffect renders it ──
    Text {
        id: backgroundDay
        anchors.centerIn: parent
        text: Time.format("dd")
        font.pixelSize: 520 * root.mScale
        font.weight: Font.Black
        font.family: Appearance.font.family.sans
        color: root.bgDateColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        visible: false
        layer.enabled: true
    }

    // ── Step 2: Mask — MUST be Item wrapper with layer.enabled, gradient child ──
    // Alpha channel drives MultiEffect: opaque = show, transparent = hide
    Item {
        id: gradientMask
        width: backgroundDay.width
        height: backgroundDay.height
        anchors.centerIn: parent
        visible: false
        layer.enabled: true
        layer.smooth: true   // required for smooth gradient edges

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0;  color: "#ff000000" }  // opaque black = SHOW
                GradientStop { position: 0.5;  color: "#ff000000" }  // stays visible
                GradientStop { position: 1.0;  color: "#00000000" }  // transparent = HIDE
            }
        }
    }

    // ── Step 3: MultiEffect — applies gradient mask to date text ──
    MultiEffect {
        source: backgroundDay
        anchors.fill: backgroundDay
        maskEnabled: true
        maskSource: gradientMask
        maskThresholdMin: 0.5   // per Qt forum: needed for smooth gradient
        maskSpreadAtMin: 1.0    // per Qt forum: needed for smooth gradient
        z: 0
    }

    // ── Foreground ──
    ColumnLayout {
        id: layout
        anchors.centerIn: parent
        spacing: 0
        z: 1

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("MMMM").toUpperCase()
            font.pixelSize: 56 * root.mScale
            font.weight: Font.Black
            font.family: Appearance.font.family.sans
            font.letterSpacing: 4 * root.mScale
            color: root.accentColor
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * root.mScale
            text: Time.format(Config.services.useTwelveHourClock ? "h:mm A" : "HH:mm")
            font.pixelSize: 38 * root.mScale
            font.weight: Font.Bold
            font.family: Appearance.font.family.sans
            color: root.accentColor
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8 * root.mScale
            Layout.preferredWidth: 180 * root.mScale
            Layout.preferredHeight: 2 * root.mScale
            color: root.accentColor
            radius: 1
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10 * root.mScale
            text: Time.format("dddd").toUpperCase()
            font.pixelSize: 18 * root.mScale
            font.weight: Font.Medium
            font.family: Appearance.font.family.sans
            font.letterSpacing: 10 * root.mScale
            color: root.accentColor
        }
    }

    // ── Drag to reposition ──
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
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    Behavior on implicitWidth {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }
}